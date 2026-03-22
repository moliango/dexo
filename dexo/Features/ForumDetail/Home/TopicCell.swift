import UIKit
import SDWebImage

final class TopicCell: UITableViewCell {
    static let reuseIdentifier = "TopicCell"

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 18
        iv.backgroundColor = .secondarySystemFill
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let replyCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let categoryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(replyCountLabel)
        contentView.addSubview(categoryLabel)
        contentView.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            avatarImageView.widthAnchor.constraint(equalToConstant: 36),
            avatarImageView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: replyCountLabel.leadingAnchor, constant: -10),

            replyCountLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            replyCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            replyCountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),

            categoryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            categoryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            categoryLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 16),
            categoryLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            timeLabel.centerYAnchor.constraint(equalTo: categoryLabel.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: categoryLabel.trailingAnchor, constant: 8),
        ])
    }

    func configure(
        with topic: DiscourseTopicList.Topic,
        avatarURL: URL?,
        categoryName: String?,
        categoryColor: UIColor?
    ) {
        titleLabel.text = topic.title

        // Reply count with gray→orange color
        let replies = max(topic.postsCount - 1, 0)
        replyCountLabel.text = "\(replies)"
        replyCountLabel.textColor = Self.replyCountColor(replies)

        // Category
        if let name = categoryName {
            let attrStr = NSMutableAttributedString()
            if let color = categoryColor {
                let dot = NSTextAttachment()
                let dotConfig = UIImage.SymbolConfiguration(pointSize: 8, weight: .bold)
                dot.image = UIImage(systemName: "circle.fill", withConfiguration: dotConfig)?.withTintColor(color, renderingMode: .alwaysOriginal)
                attrStr.append(NSAttributedString(attachment: dot))
                attrStr.append(NSAttributedString(string: " "))
            }
            attrStr.append(NSAttributedString(string: name, attributes: [
                .foregroundColor: UIColor.secondaryLabel,
                .font: UIFont.systemFont(ofSize: 12),
            ]))
            categoryLabel.attributedText = attrStr
        } else {
            categoryLabel.attributedText = nil
        }

        // Time
        timeLabel.text = Self.formatDate(topic.lastPostedAt ?? topic.createdAt)

        // Avatar
        if let url = avatarURL {
            avatarImageView.sd_setImage(with: url)
        } else {
            avatarImageView.image = nil
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        replyCountLabel.text = nil
        categoryLabel.attributedText = nil
        timeLabel.text = nil
        avatarImageView.sd_cancelCurrentImageLoad()
        avatarImageView.image = nil
    }

    // MARK: - Helpers

    private static func replyCountColor(_ count: Int) -> UIColor {
        // 0 → gray, 50+ → orange, linear in between
        let t = min(CGFloat(count) / 50.0, 1.0)
        return UIColor(
            red: 0.55 + t * 0.45,    // 0.55 → 1.0
            green: 0.55 - t * 0.05,   // 0.55 → 0.50
            blue: 0.58 - t * 0.58,    // 0.58 → 0.0
            alpha: 1.0
        )
    }

    private static func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else { return isoString }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }
}
