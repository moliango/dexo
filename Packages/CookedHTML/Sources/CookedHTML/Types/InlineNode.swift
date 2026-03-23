import Foundation

/// An inline-level node within a paragraph or heading.
public enum InlineNode: Sendable, Equatable {
    case text(String)
    case styledText(String, TextStyle)
    case link(href: String, children: [InlineNode])
    case image(src: String, alt: String?, width: Int?, height: Int?, isEmoji: Bool)
    case code(String)
    case lineBreak
}
