import CookedHTML
import UIKit

struct NativeRenderConfig {
    let baseFont: UIFont
    let baseColor: UIColor
    let linkColor: UIColor
    let codeFont: UIFont
    let codeBackgroundColor: UIColor
    let contentWidth: CGFloat
    let baseURL: String?

    var attributedStringConfig: AttributedStringConfig {
        AttributedStringConfig(
            baseFont: baseFont,
            baseColor: baseColor,
            linkColor: linkColor,
            codeFont: codeFont,
            codeBackgroundColor: codeBackgroundColor
        )
    }

    static func `default`(contentWidth: CGFloat, baseURL: String? = nil) -> NativeRenderConfig {
        NativeRenderConfig(
            baseFont: .systemFont(ofSize: 16),
            baseColor: .label,
            linkColor: .link,
            codeFont: .monospacedSystemFont(ofSize: 15, weight: .regular),
            codeBackgroundColor: ThemeManager.shared.codeBackgroundColor,
            contentWidth: contentWidth,
            baseURL: baseURL
        )
    }
}

// MARK: - BlockRenderer Protocol

protocol BlockRenderer {
    static func canRender(_ block: ContentBlock) -> Bool
    static func render(_ block: ContentBlock, config: NativeRenderConfig, delegate: PostCellDelegate?) -> UIView
}

// MARK: - NativeContentRenderer

enum NativeContentRenderer {
    static let renderers: [BlockRenderer.Type] = [
        ParagraphRenderer.self,
        HeadingRenderer.self,
        DividerRenderer.self,
        ListRenderer.self,
        BlockquoteRenderer.self,
        ImageRenderer.self,
        CodeBlockRenderer.self,
        DiscourseQuoteRenderer.self,
        DetailsRenderer.self,
        SpoilerRenderer.self,
        OneboxRenderer.self,
        VideoRenderer.self,
        TableRenderer.self,
        PollRenderer.self,
    ]

    static func canRenderNatively(_ blocks: [ContentBlock]) -> Bool {
        blocks.allSatisfy { block in
            renderers.contains { $0.canRender(block) }
        }
    }

    static func renderBlocks(
        _ blocks: [ContentBlock],
        config: NativeRenderConfig,
        delegate: PostCellDelegate?
    ) -> [UIView] {
        blocks.compactMap { block in
            for renderer in renderers where renderer.canRender(block) {
                return renderer.render(block, config: config, delegate: delegate)
            }
            return nil
        }
    }

    static func renderBlocks(
        _ annotatedBlocks: [AnnotatedBlock],
        config: NativeRenderConfig,
        delegate: PostCellDelegate?,
        pollProvider: ((String) -> (poll: DiscourseTopicDetail.Poll, votedOptionIds: Set<String>, post: DiscourseTopicDetail.Post)?)? = nil
    ) -> [UIView] {
        annotatedBlocks.compactMap { annotated in
            // Poll blocks need extra data from the Post model
            if case .poll(let name) = annotated.block,
               let pollData = pollProvider?(name) {
                return PollRenderer.render(
                    poll: pollData.poll,
                    votedOptionIds: pollData.votedOptionIds,
                    post: pollData.post,
                    containerWidth: config.contentWidth,
                    delegate: delegate
                )
            }
            for renderer in renderers where renderer.canRender(annotated.block) {
                return renderer.render(annotated.block, config: config, delegate: delegate)
            }
            return nil
        }
    }
}
