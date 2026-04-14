import UIKit
import CookedHTML

enum BlockquoteRenderer: BlockRenderer {
    static func canRender(_ block: ContentBlock) -> Bool {
        if case .blockquote = block { return true }
        return false
    }

    static func render(_ block: ContentBlock, config: NativeRenderConfig, delegate: PostCellDelegate?) -> UIView {
        guard case .blockquote(let inner) = block else { return UIView() }

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let bar = UIView()
        bar.backgroundColor = ThemeManager.shared.quoteBarColor
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.layer.cornerRadius = 1.5
        container.addSubview(bar)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let quoteConfig = NativeRenderConfig(
            baseFont: config.baseFont,
            baseColor: .secondaryLabel,
            linkColor: config.linkColor,
            codeFont: config.codeFont,
            codeBackgroundColor: config.codeBackgroundColor,
            contentWidth: config.contentWidth - 15,
            baseURL: config.baseURL
        )

        let views = NativeContentRenderer.renderBlocks(inner, config: quoteConfig, delegate: delegate)
        for view in views {
            stack.addArrangedSubview(view)
        }

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.topAnchor.constraint(equalTo: container.topAnchor),
            bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bar.widthAnchor.constraint(equalToConstant: 3),

            stack.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])

        return container
    }
}
