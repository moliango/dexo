import Foundation

/// A single item in a list, storing all content blocks in document order.
public struct ListItem: Sendable, Equatable {
    public let blocks: [ContentBlock]

    public init(blocks: [ContentBlock]) {
        self.blocks = blocks
    }
}

/// A content block annotated with its original source HTML.
public struct AnnotatedBlock: Sendable {
    public let block: ContentBlock
    public let sourceHTML: String

    public init(block: ContentBlock, sourceHTML: String) {
        self.block = block
        self.sourceHTML = sourceHTML
    }
}

/// A block-level content element extracted from Discourse `cooked` HTML.
public enum ContentBlock: Sendable, Equatable {
    case paragraph([InlineNode])
    case heading(level: Int, content: [InlineNode])
    case codeBlock(language: String?, code: String)
    case blockquote(blocks: [ContentBlock])
    case discourseQuote(username: String?, avatarURL: String?, topicTitle: String?, topicURL: String?, categoryName: String?, categoryURL: String?, content: [ContentBlock])
    case image(src: String, alt: String?, width: Int?, height: Int?, href: String? = nil)
    case onebox(sourceURL: String?, title: String?, description: String?, imageURL: String?, imageWidth: Int?, imageHeight: Int?, faviconURL: String? = nil)
    case video(url: String, thumbnailURL: String?, title: String?, width: Int?, height: Int?, videoId: String?, provider: String?)
    case list(ordered: Bool, items: [ListItem])
    case table(headers: [[ContentBlock]], rows: [[[ContentBlock]]])
    case details(summary: [InlineNode], content: [ContentBlock])
    case spoiler(blocks: [ContentBlock])
    case poll(name: String)
    case divider
    case rawHTML(String)
}
