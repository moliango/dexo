import UIKit
import CookedHTML

enum CodeBlockRenderer: BlockRenderer {
    static func canRender(_ block: ContentBlock) -> Bool {
        if case .codeBlock = block { return true }
        return false
    }

    static func render(_ block: ContentBlock, config: NativeRenderConfig, delegate: PostCellDelegate?) -> UIView {
        guard case .codeBlock(let language, let code) = block else { return UIView() }

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = config.codeBackgroundColor
        container.layer.cornerRadius = 8

        // Header row: language badge (left) + copy button (right)
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerStack)

        let badge = UILabel()
        badge.font = .systemFont(ofSize: 11, weight: .medium)
        badge.textColor = .tertiaryLabel
        if let language, !language.isEmpty {
            badge.text = language.uppercased()
        }
        headerStack.addArrangedSubview(badge)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerStack.addArrangedSubview(spacer)

        let copyButton = CopyCodeButton(code: code)
        headerStack.addArrangedSubview(copyButton)

        NSLayoutConstraint.activate([
            copyButton.widthAnchor.constraint(equalToConstant: 30),
            copyButton.heightAnchor.constraint(equalToConstant: 26),
        ])

        // Code scroll view
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.alwaysBounceHorizontal = false
        container.addSubview(scrollView)

        let codeLabel = UILabel()
        codeLabel.translatesAutoresizingMaskIntoConstraints = false
        codeLabel.font = config.codeFont
        codeLabel.textColor = config.baseColor
        codeLabel.numberOfLines = 0
        codeLabel.text = code
        scrollView.addSubview(codeLabel)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),

            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 2),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            codeLabel.topAnchor.constraint(equalTo: scrollView.topAnchor),
            codeLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            codeLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            codeLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            codeLabel.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])

        return container
    }
}

// MARK: - Copy Button

private final class CopyCodeButton: UIButton {
    private let code: String
    private static let copyImage = UIImage(systemName: "doc.on.doc", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium))
    private static let checkImage = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium))

    init(code: String) {
        self.code = code
        super.init(frame: .zero)
        setImage(Self.copyImage, for: .normal)
        tintColor = .tertiaryLabel
        addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    @objc private func copyTapped() {
        UIPasteboard.general.string = code
        setImage(Self.checkImage, for: .normal)
        tintColor = ThemeManager.shared.accentColor
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.25, delay: 1.5) {
            self.alpha = 0.5
        } completion: { _ in
            self.setImage(Self.copyImage, for: .normal)
            self.tintColor = .tertiaryLabel
            self.alpha = 1.0
            self.isUserInteractionEnabled = true
        }
    }
}
