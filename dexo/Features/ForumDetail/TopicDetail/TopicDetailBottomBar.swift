import UIKit

protocol TopicDetailBottomBarDelegate: AnyObject {
    func bottomBarDidTapScrollToTop()
    func bottomBarDidTapOPOnly()
    func bottomBarDidTapJumpToFloor()
    func bottomBarDidToggleReverseOrder()
    func bottomBarDidToggleSummaryMode()
    func bottomBarDidTapReply()
    /// Whether the reverse / summary modes are currently active (for menu state).
    var bottomBarIsReverseOrder: Bool { get }
    var bottomBarIsSummaryMode: Bool { get }
}

final class TopicDetailBottomBar: UIView {
    weak var delegate: TopicDetailBottomBarDelegate?

    private static let buttonSize: CGFloat = 44

    private lazy var scrollToTopButton = makeCircularButton(icon: "arrow.up", a11yLabel: String(localized: "topic.bottombar.scroll_to_top"))
    private(set) lazy var opOnlyButton = makeCircularButton(icon: "person", a11yLabel: String(localized: "topic.bottombar.op_only"))
    private lazy var jumpToFloorButton = makeCircularButton(icon: "number", a11yLabel: String(localized: "topic.bottombar.jump_to_floor"))
    private lazy var replyButton = makeCircularButton(icon: "arrowshape.turn.up.left", a11yLabel: String(localized: "reply.title"))

    private lazy var stackView: UIStackView = {
        let sv = UIStackView(arrangedSubviews: [scrollToTopButton, opOnlyButton, jumpToFloorButton, replyButton])
        sv.axis = .horizontal
        sv.spacing = 12
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        addSubview(stackView)

        scrollToTopButton.addTarget(self, action: #selector(scrollToTopTapped), for: .touchUpInside)
        opOnlyButton.addTarget(self, action: #selector(opOnlyTapped), for: .touchUpInside)
        jumpToFloorButton.addTarget(self, action: #selector(jumpToFloorTapped), for: .touchUpInside)
        replyButton.addTarget(self, action: #selector(replyTapped), for: .touchUpInside)

        // Long-press menu on jump-to-floor: tap still fires touchUpInside
        // (showsMenuAsPrimaryAction = false), long-press opens the menu.
        jumpToFloorButton.showsMenuAsPrimaryAction = false
        jumpToFloorButton.menu = makeJumpMenu()

        let size = Self.buttonSize
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            scrollToTopButton.widthAnchor.constraint(equalToConstant: size),
            scrollToTopButton.heightAnchor.constraint(equalToConstant: size),
            opOnlyButton.widthAnchor.constraint(equalToConstant: size),
            opOnlyButton.heightAnchor.constraint(equalToConstant: size),
            jumpToFloorButton.widthAnchor.constraint(equalToConstant: size),
            jumpToFloorButton.heightAnchor.constraint(equalToConstant: size),
            replyButton.widthAnchor.constraint(equalToConstant: size),
            replyButton.heightAnchor.constraint(equalToConstant: size),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - State

    func setOPOnlySelected(_ selected: Bool) {
        updateButtonAppearance(opOnlyButton, selected: selected)
    }

    private func updateButtonAppearance(_ button: UIButton, selected: Bool) {
        if selected {
            button.configuration?.baseForegroundColor = .white
            button.backgroundColor = .tintColor
            button.layer.sublayers?
                .filter { $0 is CAShapeLayer || ($0.name == "glassLayer") }
                .forEach { $0.isHidden = true }
            // Hide the effect view when selected
            button.subviews.compactMap { $0 as? UIVisualEffectView }.forEach { $0.isHidden = true }
        } else {
            button.configuration?.baseForegroundColor = .label
            button.backgroundColor = .clear
            button.subviews.compactMap { $0 as? UIVisualEffectView }.forEach { $0.isHidden = false }
        }
    }

    // MARK: - Factory

    private func makeCircularButton(icon: String, a11yLabel: String) -> UIButton {
        let size = Self.buttonSize
        var config = UIButton.Configuration.plain()
        if #available(iOS 26.0, *) {
            config = UIButton.Configuration.glass()
        }
        config.image = UIImage(systemName: icon)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        config.baseForegroundColor = .label
        config.background.backgroundColor = .clear

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = size / 2
        button.clipsToBounds = false
        button.accessibilityLabel = a11yLabel

        if #unavailable(iOS 26.0) {
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = 0.12
            button.layer.shadowOffset = CGSize(width: 0, height: 2)
            button.layer.shadowRadius = 4
            addGlassBackground(to: button, size: size)
        }

        return button
    }

    private func addGlassBackground(to button: UIButton, size: CGFloat) {
        if #available(iOS 26, *) {
            let glassView = UIVisualEffectView(effect: UIGlassEffect())
            glassView.translatesAutoresizingMaskIntoConstraints = false
            glassView.layer.cornerRadius = size / 2
            glassView.clipsToBounds = true
            glassView.isUserInteractionEnabled = false
            button.insertSubview(glassView, at: 0)

            NSLayoutConstraint.activate([
                glassView.topAnchor.constraint(equalTo: button.topAnchor),
                glassView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                glassView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                glassView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            ])
        } else {
            let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
            effectView.translatesAutoresizingMaskIntoConstraints = false
            effectView.layer.cornerRadius = size / 2
            effectView.clipsToBounds = true
            effectView.isUserInteractionEnabled = false
            button.insertSubview(effectView, at: 0)
            NSLayoutConstraint.activate([
                effectView.topAnchor.constraint(equalTo: button.topAnchor),
                effectView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                effectView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                effectView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            ])
        }
    }

    // MARK: - Actions

    @objc private func scrollToTopTapped() {
        delegate?.bottomBarDidTapScrollToTop()
    }

    @objc private func opOnlyTapped() {
        delegate?.bottomBarDidTapOPOnly()
    }

    @objc private func jumpToFloorTapped() {
        delegate?.bottomBarDidTapJumpToFloor()
    }

    /// Refresh the long-press menu so checkmarks reflect current modes.
    func refreshJumpMenu() {
        jumpToFloorButton.menu = makeJumpMenu()
    }

    private func makeJumpMenu() -> UIMenu {
        let isReverse = delegate?.bottomBarIsReverseOrder ?? false
        let isSummary = delegate?.bottomBarIsSummaryMode ?? false
        let reverseAction = UIAction(
            title: String(localized: "topic.bottombar.reverse_order"),
            image: UIImage(systemName: "arrow.up.arrow.down"),
            state: isReverse ? .on : .off
        ) { [weak self] _ in
            self?.delegate?.bottomBarDidToggleReverseOrder()
            self?.refreshJumpMenu()
        }
        let summaryAction = UIAction(
            title: String(localized: "topic.bottombar.summary_view"),
            image: UIImage(systemName: "flame"),
            state: isSummary ? .on : .off
        ) { [weak self] _ in
            self?.delegate?.bottomBarDidToggleSummaryMode()
            self?.refreshJumpMenu()
        }
        return UIMenu(title: "", children: [reverseAction, summaryAction])
    }

    @objc private func replyTapped() {
        delegate?.bottomBarDidTapReply()
    }
}
