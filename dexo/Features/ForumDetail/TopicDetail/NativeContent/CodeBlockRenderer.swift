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
        badge.font = FontManager.shared.font(size: 11, weight: .medium)
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

        // Code view — a single UITextView that internally scrolls in both axes.
        //
        // Why not UILabel-in-UIScrollView? `UILabel.numberOfLines = 0` computes its
        // intrinsicContentSize by running a full TextKit layout over the whole
        // string. For a ~350-line code block this pushed `sizeFitting` to 2.6s and
        // the resulting cell height to 11000+pt — catastrophic. UITextView's layout
        // manager is incremental: it only lays out glyphs in (and slightly around)
        // the visible bounds, so initial-render cost is bounded by the visible
        // window, independent of the code length.
        //
        // Sizing strategy:
        // - No word wrap (`textContainer.size.width = .greatestFiniteMagnitude`) so
        //   long lines trigger horizontal scrolling instead of reflowing.
        // - The view height is capped at `Self.maxVisibleLines × lineHeight`.
        //   Short blocks (≤ cap lines) size to their natural height; long blocks
        //   are clamped and the user scrolls vertically inside the box.
        let codeView = UITextView()
        codeView.isEditable = false
        codeView.isSelectable = true          // allow select/copy
        codeView.isScrollEnabled = true
        codeView.backgroundColor = .clear
        codeView.textContainerInset = .zero
        codeView.textContainer.lineFragmentPadding = 0
        codeView.textContainer.widthTracksTextView = false
        codeView.textContainer.size = CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        codeView.showsHorizontalScrollIndicator = true
        codeView.showsVerticalScrollIndicator = true
        codeView.alwaysBounceHorizontal = false
        codeView.alwaysBounceVertical = false
        codeView.dataDetectorTypes = []
        codeView.translatesAutoresizingMaskIntoConstraints = false
        codeView.attributedText = NSAttributedString(string: code, attributes: [
            .font: config.codeFont,
            .foregroundColor: config.baseColor,
        ])
        container.addSubview(codeView)

        // Count newlines cheaply (no array allocation) and clamp at the visible cap.
        var newlineCount = 0
        for ch in code.unicodeScalars where ch == "\n" { newlineCount += 1 }
        let lineCount = newlineCount + 1
        let visibleLines = min(lineCount, Self.maxVisibleLines)
        let codeHeight = ceil(config.codeFont.lineHeight * CGFloat(visibleLines)) + 6

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),

            codeView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 2),
            codeView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            codeView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            codeView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            codeView.heightAnchor.constraint(equalToConstant: codeHeight),
        ])

        return container
    }

    /// Upper bound on the visible code rows — anything longer scrolls inside the box.
    private static let maxVisibleLines = 20
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
