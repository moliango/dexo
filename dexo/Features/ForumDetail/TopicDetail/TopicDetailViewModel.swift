import Foundation
import UIKit
import CookedHTML

@Observable
final class TopicDetailViewModel {
    var topic: DiscourseTopicDetail?
    var parsedBlocks: [Int: [AnnotatedBlock]] = [:]
    var unsupportedPostIds: Set<Int> = []
    var isLoading = false
    var isReady = false
    var isLoadingMore = false
    var errorMessage: String?

    private let api: DiscourseAPI
    private var allPostIds: [Int] = []
    private var loadedPostIds: Set<Int> = []

    init(api: DiscourseAPI) {
        self.api = api
    }

    var posts: [DiscourseTopicDetail.Post] {
        topic?.postStream.posts ?? []
    }

    var visiblePosts: [DiscourseTopicDetail.Post] {
        posts.filter { ($0.actionCode ?? "").isEmpty }
    }

    var canLoadMore: Bool {
        !allPostIds.isEmpty && loadedPostIds.count < allPostIds.count
    }

    func loadTopic(id: Int, containerWidth: CGFloat) async {
        isLoading = true
        isReady = false
        errorMessage = nil
        parsedBlocks = [:]
        unsupportedPostIds = []

        do {
            let detail = try await api.fetchTopic(id: id)
            topic = detail

            // Save the full stream of post IDs
            allPostIds = detail.postStream.stream ?? detail.postStream.posts.map(\.id)
            loadedPostIds = Set(detail.postStream.posts.map(\.id))

            let postsToRender = detail.postStream.posts
            guard !postsToRender.isEmpty else {
                isReady = true
                isLoading = false
                return
            }

            // Parse all posts with annotated blocks
            for post in postsToRender {
                parseAndStore(post: post)
            }

            isReady = true
        } catch {
            #if DEBUG
            print("[TopicDetail] Load failed: \(error)")
            #endif
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMorePosts(containerWidth: CGFloat) async {
        guard canLoadMore, !isLoadingMore, let topicId = topic?.id else { return }
        isLoadingMore = true

        // Find the next batch of unloaded post IDs
        let unloadedIds = allPostIds.filter { !loadedPostIds.contains($0) }
        let batch = Array(unloadedIds.prefix(20))

        guard !batch.isEmpty else {
            isLoadingMore = false
            return
        }

        do {
            let response = try await api.fetchTopicPosts(topicId: topicId, postIds: batch)
            let newPosts = response.postStream.posts.filter { !loadedPostIds.contains($0.id) }

            guard !newPosts.isEmpty else {
                for id in batch { loadedPostIds.insert(id) }
                isLoadingMore = false
                return
            }

            // Add posts to topic first so viewModel.posts includes them
            topic?.postStream.posts.append(contentsOf: newPosts)

            for post in newPosts {
                loadedPostIds.insert(post.id)
                parseAndStore(post: post)
            }
        } catch {
            // Silently fail; user can scroll again to retry
        }

        isLoadingMore = false
    }

    // MARK: - Private

    private func parseAndStore(post: DiscourseTopicDetail.Post) {
        let annotated = CookedHTMLParser.parseAnnotated(html: post.cooked, baseURL: api.baseURL)
        parsedBlocks[post.id] = annotated

        // Check if any block has no native renderer
        let hasUnsupported = annotated.contains { ab in
            !NativeContentRenderer.renderers.contains { $0.canRender(ab.block) }
        }
        if hasUnsupported {
            unsupportedPostIds.insert(post.id)
        }
    }
}
