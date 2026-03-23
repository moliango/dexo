import Foundation
import SwiftSoup

/// Extracts a `[ContentBlock]` array from the children of a DOM element.
enum BlockExtractor {
    /// Tags treated as block-level elements.
    private static let blockTags: Set<String> = [
        "p", "h1", "h2", "h3", "h4", "h5", "h6",
        "pre", "blockquote", "aside",
        "ul", "ol",
        "table",
        "details",
        "hr",
        "div", "figure",
    ]

    /// Extract content blocks from a parent element's children.
    static func extract(from parent: Element, options: ParseOptions) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        for child in parent.getChildNodes() {
            blocks.append(contentsOf: extractNode(child, options: options))
        }
        return blocks.compactMap { trimBlock($0) }
    }

    /// Extract annotated blocks (block + source HTML) from a parent element's children.
    static func extractAnnotated(from parent: Element, options: ParseOptions) -> [AnnotatedBlock] {
        var result: [AnnotatedBlock] = []
        for child in parent.getChildNodes() {
            let blocks = extractNode(child, options: options).compactMap { trimBlock($0) }
            guard !blocks.isEmpty else { continue }
            let sourceHTML: String
            if let element = child as? Element {
                sourceHTML = (try? element.outerHtml()) ?? ""
            } else if let textNode = child as? TextNode {
                sourceHTML = textNode.getWholeText()
            } else {
                sourceHTML = ""
            }
            for block in blocks {
                result.append(AnnotatedBlock(block: block, sourceHTML: sourceHTML))
            }
        }
        return result
    }

    /// Extract content blocks from a single DOM node.
    private static func extractNode(_ node: Node, options: ParseOptions) -> [ContentBlock] {
        if let textNode = node as? TextNode {
            let text = textNode.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { return [] }
            return [.paragraph([.text(text)])]
        }

        guard let element = node as? Element else { return [] }
        let tagName = element.tagName().lowercased()

        switch tagName {
        case "p":
            return extractParagraph(from: element, options: options)

        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(String(tagName.last!))!
            let inlines = InlineExtractor.extract(from: element, options: options)
            if inlines.isEmpty { return [] }
            return [.heading(level: level, content: inlines)]

        case "pre":
            return extractCodeBlock(from: element)

        case "blockquote":
            let inner = extract(from: element, options: options)
            if inner.isEmpty { return [] }
            return [.blockquote(blocks: inner)]

        case "aside":
            return extractAside(from: element, options: options)

        case "ul":
            return [ListExtractor.extract(from: element, ordered: false, options: options)]

        case "ol":
            return [ListExtractor.extract(from: element, ordered: true, options: options)]

        case "table":
            return [TableExtractor.extract(from: element, options: options)]

        case "details":
            return extractDetails(from: element, options: options)

        case "hr":
            return [.divider]

        case "img":
            return extractBlockImage(from: element, options: options)

        case "div", "figure", "section", "article":
            // Check for specific div patterns first, otherwise recurse
            return extractDiv(from: element, options: options)

        default:
            // Unknown block-level or inline elements at top level
            if isBlockElement(element) {
                return extract(from: element, options: options)
            }
            // Wrap in paragraph if it has inline content
            let inlines = InlineExtractor.extract(from: element, options: options)
            if inlines.isEmpty { return [] }
            return [.paragraph(inlines)]
        }
    }

    // MARK: - Specific extractors

    private static func extractParagraph(from element: Element, options: ParseOptions) -> [ContentBlock] {
        // Check if paragraph only contains a single image
        let children = element.children()
        if children.size() == 1,
           let onlyChild = children.first(),
           onlyChild.tagName().lowercased() == "img",
           element.textNodes().allSatisfy({ $0.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        {
            return extractBlockImage(from: onlyChild, options: options)
        }

        // Check if paragraph contains a link wrapping a single image
        if children.size() == 1,
           let onlyChild = children.first(),
           onlyChild.tagName().lowercased() == "a",
           onlyChild.children().size() == 1,
           let innerImg = onlyChild.children().first(),
           innerImg.tagName().lowercased() == "img"
        {
            return extractBlockImage(from: innerImg, options: options)
        }

        let inlines = InlineExtractor.extract(from: element, options: options)
        if inlines.isEmpty { return [] }
        return [.paragraph(inlines)]
    }

    private static func extractCodeBlock(from element: Element) -> [ContentBlock] {
        let codeElement = element.children().first { $0.tagName().lowercased() == "code" }
            ?? element

        let language: String? = {
            guard let cls = try? codeElement.attr("class"), !cls.isEmpty else { return nil }
            // Discourse uses class="lang-xxx" or "language-xxx"
            let parts = cls.split(separator: " ")
            for part in parts {
                let s = String(part)
                if s.hasPrefix("lang-") { return String(s.dropFirst(5)) }
                if s.hasPrefix("language-") { return String(s.dropFirst(9)) }
            }
            return nil
        }()

        let code = (try? codeElement.text()) ?? ""
        return [.codeBlock(language: language, code: code)]
    }

    private static func extractAside(from element: Element, options: ParseOptions) -> [ContentBlock] {
        let classAttr = (try? element.attr("class")) ?? ""
        if classAttr.contains("quote") {
            return [QuoteExtractor.extract(from: element, options: options)]
        }
        if classAttr.contains("onebox") {
            return [OneboxExtractor.extract(from: element, options: options)]
        }
        // Generic aside — recurse
        return extract(from: element, options: options)
    }

    private static func extractDetails(from element: Element, options: ParseOptions) -> [ContentBlock] {
        let summaryEl = element.children().first { $0.tagName().lowercased() == "summary" }
        let summaryInlines: [InlineNode]
        if let summaryEl {
            summaryInlines = InlineExtractor.extract(from: summaryEl, options: options)
        } else {
            summaryInlines = [.text("Details")]
        }

        // Content is everything except the summary element
        var contentBlocks: [ContentBlock] = []
        for child in element.getChildNodes() {
            if let el = child as? Element, el.tagName().lowercased() == "summary" { continue }
            contentBlocks.append(contentsOf: extractNode(child, options: options))
        }

        return [.details(summary: summaryInlines, content: contentBlocks)]
    }

    private static func extractBlockImage(from element: Element, options: ParseOptions) -> [ContentBlock] {
        let src = URLResolver.resolve((try? element.attr("src")) ?? "", baseURL: options.baseURL)
        let alt = try? element.attr("alt")
        let width = Int((try? element.attr("width")) ?? "")
        let height = Int((try? element.attr("height")) ?? "")
        return [.image(src: src, alt: alt, width: width, height: height)]
    }

    private static func extractDiv(from element: Element, options: ParseOptions) -> [ContentBlock] {
        // Lightbox wrapper
        if let classAttr = try? element.attr("class"), classAttr.contains("lightbox-wrapper") {
            if let img = try? element.select("img").first() {
                return extractBlockImage(from: img, options: options)
            }
        }
        // Generic div — recurse into children
        let inner = extract(from: element, options: options)
        if inner.isEmpty { return [] }
        return inner
    }

    // MARK: - Helpers

    private static func isBlockElement(_ element: Element) -> Bool {
        blockTags.contains(element.tagName().lowercased())
    }

    /// Trim whitespace-only paragraphs.
    private static func trimBlock(_ block: ContentBlock) -> ContentBlock? {
        switch block {
        case .paragraph(let inlines):
            let trimmed = inlines.filter { node in
                switch node {
                case .text(let t): return !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                case .styledText(let t, _): return !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                default: return true
                }
            }
            return trimmed.isEmpty ? nil : .paragraph(trimmed)
        default:
            return block
        }
    }
}
