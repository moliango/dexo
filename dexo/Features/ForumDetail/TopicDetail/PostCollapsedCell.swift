import UIKit
import SDWebImage

/// Compact one-row cell used when a tree-mode parent has its subtree collapsed.
/// Layout: `[avatar] [+] [username · N 条回复]`. Tapping the pill expands the
/// subtree back into the regular `PostNativeCell` rendering. The cell still
/// participates in the tree line spine — `TreeLineView` paints the incoming
/// connector from the parent above so the column stays visually continuous.
final class PostCollapsedCell: UITableViewCell {
    static let reuseIdentifier = "PostCollapsedCell"
    /// Avatar matches the full-cell size so the post doesn't visually shrink
    /// when collapsed — only the surrounding chrome (content, action bar)
    /// disappears.
    private static let baseAvatarSize: CGFloat = 32
    /// Fixed row height: top inset + avatar + bottom inset.
    static let cellHeight: CGFloat = 12 + 32 + 12

    weak var delegate: PostCellDelegate?
    private(set) var postId: Int = 0

    private let treeLineView: TreeLineView = {
        let v = TreeLineView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .secondarySystemFill
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let expandButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = .clear
        b.layer.cornerRadius = 9
        b.layer.borderWidth = 1
        b.tintColor = .secondaryLabel
        let cfg = UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        b.setPreferredSymbolConfiguration(cfg, forImageIn: .normal)
        b.setImage(UIImage(systemName: "plus"), for: .normal)
        b.accessibilityLabel = String(localized: "topic_detail.expand")
        return b
    }()

    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = FontManager.shared.font(size: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private var avatarLeading: NSLayoutConstraint!
    private var avatarWidth: NSLayoutConstraint!
    private var avatarHeight: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        contentView.addSubview(treeLineView)
        contentView.addSubview(avatarImageView)
        contentView.addSubview(expandButton)
        contentView.addSubview(summaryLabel)

        avatarLeading = avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        avatarWidth = avatarImageView.widthAnchor.constraint(equalToConstant: Self.baseAvatarSize)
        avatarHeight = avatarImageView.heightAnchor.constraint(equalToConstant: Self.baseAvatarSize)

        NSLayoutConstraint.activate([
            treeLineView.topAnchor.constraint(equalTo: contentView.topAnchor),
            treeLineView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            treeLineView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            treeLineView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarLeading,
            avatarWidth,
            avatarHeight,

            expandButton.widthAnchor.constraint(equalToConstant: 18),
            expandButton.heightAnchor.constraint(equalToConstant: 18),
            expandButton.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 8),
            expandButton.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),

            summaryLabel.leadingAnchor.constraint(equalTo: expandButton.trailingAnchor, constant: 8),
            summaryLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            summaryLabel.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
        ])

        expandButton.addTarget(self, action: #selector(expandTapped), for: .touchUpInside)

        let avatarTap = UITapGestureRecognizer(target: self, action: #selector(expandTapped))
        avatarImageView.isUserInteractionEnabled = true
        avatarImageView.addGestureRecognizer(avatarTap)
    }

    func configure(
        with post: DiscourseTopicDetail.Post,
        treeDepth: Int,
        treeLineState: TreeLineState?,
        baseURL: String,
        delegate: PostCellDelegate?
    ) {
        postId = post.id
        self.delegate = delegate

        let avatarSize = FontManager.shared.scaled(Self.baseAvatarSize)
        avatarWidth.constant = avatarSize
        avatarHeight.constant = avatarSize
        avatarImageView.layer.cornerRadius = avatarSize / 2

        // Mirror the depth-based avatar indent from PostNativeCell so the line
        // column lines up across both rendering modes.
        let avatarIndent = PostNativeCell.treeAvatarIndent(forDepth: treeDepth)
        avatarLeading.constant = 12 + avatarIndent

        let displayName = post.name ?? post.username
        let replyCount = post.replyCount
        let format = String(localized: "topic_detail.collapsed_summary %@ %lld")
        summaryLabel.text = String.localizedStringWithFormat(format, displayName, replyCount)

        if let template = post.avatarTemplate {
            let sized = template.replacingOccurrences(of: "{size}", with: "96")
            let urlString = sized.hasPrefix("http") ? sized : baseURL + sized
            if let url = URL(string: urlString) {
                avatarImageView.sd_setImage(with: url, context: ImageCacheManager.shared.avatarContext)
            }
        } else {
            avatarImageView.image = nil
        }

        if let treeLineState {
            let drawsIncoming = treeLineState.depth >= 2
            treeLineView.isHidden = !drawsIncoming
            treeLineView.state = treeLineState
            // Avatar is centered vertically — the line's "above" segment ends
            // at the avatar top and the "below" segment (if any) resumes at
            // the avatar bottom.
            let avatarTop = (Self.cellHeight - avatarSize) / 2
            treeLineView.connectorY = avatarTop + avatarSize / 2
            treeLineView.avatarBottomY = avatarTop + avatarSize
        } else {
            treeLineView.isHidden = true
            treeLineView.state = nil
        }
        treeLineView.lineColor = .separator
        expandButton.layer.borderColor = UIColor.separator.cgColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.sd_cancelCurrentImageLoad()
        avatarImageView.image = nil
        postId = 0
        delegate = nil
    }

    @objc private func expandTapped() {
        delegate?.postCell(didToggleCollapseForPostId: postId)
    }
}
