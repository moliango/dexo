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

        // Language badge (reserve for future syntax highlighting)
        if let language, !language.isEmpty {
            let badge = UILabel()
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.font = .systemFont(ofSize: 11, weight: .medium)
            badge.textColor = .tertiaryLabel
            badge.text = language.uppercased()
            container.addSubview(badge)

            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
                badge.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            ])
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            codeLabel.topAnchor.constraint(equalTo: scrollView.topAnchor),
            codeLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            codeLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            codeLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            // Let content determine scroll width; height follows label
            codeLabel.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
        ])

        return container
    }
}
