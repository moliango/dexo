import UIKit
import CookedHTML

enum HeadingRenderer: BlockRenderer {
    static func canRender(_ block: ContentBlock) -> Bool {
        if case .heading = block { return true }
        return false
    }

    static func render(_ block: ContentBlock, config: NativeRenderConfig, delegate: PostCellDelegate?) -> UIView {
        guard case .heading(let level, let inlines) = block else { return UIView() }

        let fontSize: CGFloat
        let weight: UIFont.Weight
        switch level {
        case 1: fontSize = 28; weight = .bold
        case 2: fontSize = 24; weight = .bold
        case 3: fontSize = 20; weight = .semibold
        case 4: fontSize = 18; weight = .semibold
        case 5: fontSize = 16; weight = .semibold
        default: fontSize = 16; weight = .medium
        }

        let headingConfig = NativeRenderConfig(
            baseFont: .systemFont(ofSize: fontSize, weight: weight),
            baseColor: config.baseColor,
            linkColor: config.linkColor,
            codeFont: config.codeFont,
            codeBackgroundColor: config.codeBackgroundColor,
            contentWidth: config.contentWidth,
            baseURL: config.baseURL
        )

        let textView = LinkTextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        textView.dataDetectorTypes = []
        textView.attributedText = inlines.attributedString(config: headingConfig.attributedStringConfig)
        textView.linkTextAttributes = [
            .foregroundColor: config.linkColor,
        ]
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }
}
