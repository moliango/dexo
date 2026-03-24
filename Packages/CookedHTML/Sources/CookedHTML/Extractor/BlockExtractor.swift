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
        return mergeInlineImageBlocks(blocks).compactMap { trimBlock($0) }
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
            let raw = textNode.getWholeText()
            // Trim leading whitespace/newlines but preserve meaningful trailing spaces
            // (they serve as word separators when adjacent inline elements are merged).
            let text = raw.replacingOccurrences(of: "^[\\s]+", with: "", options: .regularExpression)
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
           element.textNodes().allSatisfy({ $0.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        {
            let childTag = onlyChild.tagName().lowercased()

            // <p><img></p>
            if childTag == "img" {
                return extractBlockImage(from: onlyChild, options: options)
            }

            // <p><a><img></a></p>
            if childTag == "a",
               onlyChild.children().size() == 1,
               let innerImg = onlyChild.children().first(),
               innerImg.tagName().lowercased() == "img"
            {
                let href = URLResolver.resolve((try? onlyChild.attr("href")) ?? "", baseURL: options.baseURL)
                return extractBlockImage(from: innerImg, options: options, href: href.isEmpty ? nil : href)
            }

            // <p><div class="lightbox-wrapper">...</div></p>
            if childTag == "div" || childTag == "figure" {
                return extractDiv(from: onlyChild, options: options)
            }
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
            summaryInlines = InlineExtractor.extract(from: summaryEl, options: options).trimmedWhitespace()
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

    private static func extractBlockImage(from element: Element, options: ParseOptions, href: String? = nil) -> [ContentBlock] {
        let src = URLResolver.resolve((try? element.attr("src")) ?? "", baseURL: options.baseURL)
        let alt = try? element.attr("alt")
        let width = Int((try? element.attr("width")) ?? "")
        let height = Int((try? element.attr("height")) ?? "")
        return [.image(src: src, alt: alt, width: width, height: height, href: href)]
    }

    private static func extractDiv(from element: Element, options: ParseOptions) -> [ContentBlock] {
        let classAttr = (try? element.attr("class")) ?? ""

        // Lightbox wrapper
        if classAttr.contains("lightbox-wrapper") {
            if let img = try? element.select("img").first() {
                let href: String? = {
                    guard let anchor = try? element.select("a").first() else { return nil }
                    let h = URLResolver.resolve((try? anchor.attr("href")) ?? "", baseURL: options.baseURL)
                    return h.isEmpty ? nil : h
                }()
                return extractBlockImage(from: img, options: options, href: href)
            }
        }

        // Video embed (youtube-onebox, lazy-video-container, etc.)
        if classAttr.contains("lazy-video-container") || classAttr.contains("video-container") {
            return extractVideo(from: element, options: options)
        }

        // Generic div — recurse into children
        let inner = extract(from: element, options: options)
        if inner.isEmpty { return [] }
        return inner
    }

    private static func extractVideo(from element: Element, options: ParseOptions) -> [ContentBlock] {
        let videoId = (try? element.attr("data-video-id")) ?? ""
        let title: String? = {
            let t = (try? element.attr("data-video-title")) ?? ""
            return t.isEmpty ? nil : t
        }()
        let provider: String? = {
            let p = (try? element.attr("data-provider-name")) ?? ""
            return p.isEmpty ? nil : p
        }()

        // URL from <a> href
        let url: String = {
            if let anchor = try? element.select("a").first() {
                let href = (try? anchor.attr("href")) ?? ""
                if !href.isEmpty { return href }
            }
            return ""
        }()

        // Thumbnail from <img>
        var thumbnailURL: String?
        var width: Int?
        var height: Int?
        if let img = try? element.select("img").first() {
            let src = (try? img.attr("src")) ?? ""
            if !src.isEmpty {
                thumbnailURL = URLResolver.resolve(src, baseURL: options.baseURL)
            }
            if let w = try? img.attr("width"), let wInt = Int(w) { width = wInt }
            if let h = try? img.attr("height"), let hInt = Int(h) { height = hInt }
        }

        return [.video(
            url: url,
            thumbnailURL: thumbnailURL,
            title: title,
            width: width,
            height: height,
            videoId: videoId.isEmpty ? nil : videoId,
            provider: provider
        )]
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

    /// Merge small emoji-sized `.image` blocks that immediately follow a `.paragraph`
    /// back into that paragraph as inline image nodes.
    /// This handles cases where text + emoji `<img>` are siblings without `<p>` wrapping.
    private static func mergeInlineImageBlocks(_ blocks: [ContentBlock]) -> [ContentBlock] {
        guard blocks.count > 1 else { return blocks }
        var result: [ContentBlock] = []
        for block in blocks {
            if case .image(let src, let alt, let w, let h, _) = block,
               let w, let h, w <= 80, h <= 80,
               let lastIndex = result.indices.last,
               case .paragraph(let inlines) = result[lastIndex]
            {
                result[lastIndex] = .paragraph(inlines + [.image(src: src, alt: alt, width: w, height: h, isEmoji: true)])
            } else {
                result.append(block)
            }
        }
        return result
    }
}
