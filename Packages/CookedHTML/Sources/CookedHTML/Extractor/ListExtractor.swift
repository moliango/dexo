import Foundation
import SwiftSoup

/// Extracts list content from `<ul>` and `<ol>` elements.
enum ListExtractor {
    static func extract(from element: Element, ordered: Bool, options: ParseOptions) -> ContentBlock {
        var items: [ListItem] = []

        for child in element.children() {
            guard child.tagName().lowercased() == "li" else { continue }
            items.append(extractItem(from: child, options: options))
        }

        return .list(ordered: ordered, items: items)
    }

    private static func extractItem(from li: Element, options: ParseOptions) -> ListItem {
        var blocks: [ContentBlock] = []
        var pendingInlines: [InlineNode] = []

        func flushInlines() {
            let trimmed = pendingInlines.trimmedWhitespace()
            if !trimmed.isEmpty {
                blocks.append(.paragraph(trimmed))
            }
            pendingInlines.removeAll()
        }

        for child in li.getChildNodes() {
            if let element = child as? Element {
                let tag = element.tagName().lowercased()
                if tag == "ul" {
                    flushInlines()
                    blocks.append(extract(from: element, ordered: false, options: options))
                } else if tag == "ol" {
                    flushInlines()
                    blocks.append(extract(from: element, ordered: true, options: options))
                } else if tag == "p" {
                    flushInlines()
                    // Use BlockExtractor to handle <p> properly (lightbox splitting, block images, etc.)
                    blocks.append(contentsOf: BlockExtractor.extractNode(element, options: options))
                } else {
                    let blockLevelTags: Set<String> = ["pre", "blockquote", "table", "div", "details", "figure", "hr"]
                    if blockLevelTags.contains(tag) {
                        flushInlines()
                        blocks.append(contentsOf: BlockExtractor.extractNode(element, options: options))
                    } else {
                        pendingInlines.append(contentsOf: InlineExtractor.extractNode(element, options: options))
                    }
                }
            } else if let textNode = child as? TextNode {
                let text = textNode.getWholeText()
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    pendingInlines.append(.text(text))
                }
            }
        }

        flushInlines()
        return ListItem(blocks: blocks)
    }
}
