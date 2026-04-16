import UIKit
import CookedHTML

enum ParagraphRenderer: BlockRenderer {
    static func canRender(_ block: ContentBlock) -> Bool {
        if case .paragraph = block { return true }
        return false
    }

    static func render(_ block: ContentBlock, config: NativeRenderConfig, delegate: PostCellDelegate?) -> UIView {
        guard case .paragraph(let inlines) = block else { return UIView() }
        let attr = inlines.attributedString(config: config.attributedStringConfig)
        // Fast path: pure-text paragraphs (no link / mention / hashtag / spoiler /
        // inline image) go to UILabel, which is 5–10× cheaper to instantiate than
        // UITextView. This benefits every nested renderBlocks call too — blockquote,
        // details, discourse-quote, spoiler, table fallback, etc.
        if !NativeContentRenderer.inlinesNeedTextView(inlines) {
            return NativeContentRenderer.makeContentLabel(attributedText: attr)
        }
        return makeTextView(attributedText: attr, config: config)
    }

    /// Creates a configured LinkTextView — also used by NativeContentRenderer for merged paragraphs.
    static func makeTextView(attributedText: NSAttributedString, config: NativeRenderConfig) -> LinkTextView {
        let textView = LinkTextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        textView.dataDetectorTypes = []
        textView.attributedText = attributedText
        textView.linkTextAttributes = [
            .foregroundColor: config.linkColor,
        ]
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }
}
