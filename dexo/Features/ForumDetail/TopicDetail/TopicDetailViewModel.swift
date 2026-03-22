import Foundation
import UIKit

@Observable
final class TopicDetailViewModel {
    var topic: DiscourseTopicDetail?
    var renderedPosts: [Int: PostContentRenderer.RenderedPost] = [:]
    var isLoading = false
    var isReady = false
    var isLoadingMore = false
    var errorMessage: String?

    private let api: DiscourseAPI
    private var allPostIds: [Int] = []
    private var loadedPostIds: Set<Int> = []
    private var openDetailsPerPost: [Int: Set<Int>] = [:]
    private var reRenderingPostIds: Set<Int> = []

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
        renderedPosts = [:]

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

            // Render progressively — show each post as it finishes
            let _ = await PostContentRenderer.shared.renderPosts(
                postsToRender,
                baseURL: api.baseURL,
                containerWidth: containerWidth
            ) { [self] postId, rendered in
                renderedPosts[postId] = rendered
                if !isReady {
                    isReady = true
                    isLoading = false
                }
            }
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
            }

            // Render progressively — each post appears as it finishes
            let _ = await PostContentRenderer.shared.renderPosts(
                newPosts,
                baseURL: api.baseURL,
                containerWidth: containerWidth
            ) { [self] postId, rendered in
                renderedPosts[postId] = rendered
            }
        } catch {
            // Silently fail; user can scroll again to retry
        }

        isLoadingMore = false
    }

    func toggleDetails(postId: Int, detailsIndex: Int, containerWidth: CGFloat) async {
        guard !reRenderingPostIds.contains(postId) else { return }
        reRenderingPostIds.insert(postId)
        defer { reRenderingPostIds.remove(postId) }

        var indices = openDetailsPerPost[postId] ?? []
        if indices.contains(detailsIndex) {
            indices.remove(detailsIndex)
        } else {
            indices.insert(detailsIndex)
        }
        openDetailsPerPost[postId] = indices

        guard let post = posts.first(where: { $0.id == postId }) else { return }
        let rendered = await PostContentRenderer.shared.reRenderPost(
            cooked: post.cooked,
            baseURL: api.baseURL,
            width: containerWidth,
            openDetailsIndices: indices
        )
        renderedPosts[postId] = rendered
    }
}
