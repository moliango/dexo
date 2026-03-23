import Foundation
import SwiftSoup

/// Extracts Discourse quote blocks (`aside.quote`).
enum QuoteExtractor {
    static func extract(from element: Element, options: ParseOptions) -> ContentBlock {
        let username = try? element.attr("data-username")
        let effectiveUsername = (username?.isEmpty ?? true) ? nil : username

        // Avatar URL from the img inside .title
        let avatarURL: String? = {
            guard let img = try? element.select(".title img").first() else { return nil }
            let src = (try? img.attr("src")) ?? ""
            return src.isEmpty ? nil : URLResolver.resolve(src, baseURL: options.baseURL)
        }()

        // Content comes from the blockquote inside the aside
        let contentBlocks: [ContentBlock]
        if let blockquote = try? element.select("blockquote").first() {
            contentBlocks = BlockExtractor.extract(from: blockquote, options: options)
        } else {
            contentBlocks = BlockExtractor.extract(from: element, options: options)
        }

        return .discourseQuote(
            username: effectiveUsername,
            avatarURL: avatarURL,
            content: contentBlocks
        )
    }
}
