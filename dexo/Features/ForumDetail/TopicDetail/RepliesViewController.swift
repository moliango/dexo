import UIKit
import SafariServices

final class RepliesViewController: UIViewController {
    private let api: DiscourseAPI
    private let postId: Int
    private let topicId: Int
    private let baseURL: String

    private var replies: [DiscourseTopicDetail.Post] = []
    private var renderedPosts: [Int: PostContentRenderer.RenderedPost] = [:]
    private var openDetailsPerPost: [Int: Set<Int>] = [:]
    private var reRenderingPostIds: Set<Int> = []

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(PostWebViewCell.self, forCellReuseIdentifier: PostWebViewCell.reuseIdentifier)
        tv.delegate = self
        tv.separatorStyle = .none
        return tv
    }()

    private lazy var dataSource: UITableViewDiffableDataSource<Int, Int> = {
        UITableViewDiffableDataSource<Int, Int>(tableView: tableView) { [weak self] tableView, indexPath, postId in
            guard let self,
                  let cell = tableView.dequeueReusableCell(withIdentifier: PostWebViewCell.reuseIdentifier, for: indexPath) as? PostWebViewCell,
                  let post = self.replies.first(where: { $0.id == postId }),
                  let rendered = self.renderedPosts[postId] else {
                return UITableViewCell()
            }
            let postLink = "\(self.baseURL)/t/\(self.topicId)/\(post.postNumber)"
            cell.configure(
                with: post,
                snapshot: rendered.snapshot,
                contentHeight: rendered.height,
                interactiveRegions: rendered.interactiveRegions,
                codeBlocks: rendered.codeBlocks,
                baseURL: self.baseURL,
                delegate: self,
                floorNumber: indexPath.row + 1,
                postLink: postLink
            )
            return cell
        }
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    init(api: DiscourseAPI, postId: Int, topicId: Int) {
        self.api = api
        self.postId = postId
        self.topicId = topicId
        self.baseURL = api.baseURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "回复"

        view.addSubview(tableView)
        view.addSubview(activityIndicator)

        // Push content down to avoid overlapping with the sheet grabber
        tableView.contentInset.top = 16

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        Task {
            await loadReplies()
        }
    }

    private func loadReplies() async {
        activityIndicator.startAnimating()
        do {
            let posts = try await api.fetchPostReplies(postId: postId)
            replies = posts

            let containerWidth = view.bounds.width
            let _ = await PostContentRenderer.shared.renderPosts(
                posts,
                baseURL: baseURL,
                containerWidth: containerWidth
            ) { [weak self] postId, rendered in
                guard let self else { return }
                renderedPosts[postId] = rendered
                applySnapshot()
            }
        } catch {
            // Silently handle — the user can dismiss and retry
        }
        activityIndicator.stopAnimating()
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        var seen = Set<Int>()
        let renderedIds = replies.compactMap { post -> Int? in
            guard renderedPosts[post.id] != nil, seen.insert(post.id).inserted else { return nil }
            return post.id
        }
        snapshot.appendItems(renderedIds, toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Link Handling

    private func handleLink(_ url: URL) {
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }
}

// MARK: - UITableViewDelegate

extension RepliesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let postId = dataSource.itemIdentifier(for: indexPath),
              let rendered = renderedPosts[postId] else {
            return UITableView.automaticDimension
        }
        return PostWebViewCell.headerHeight + rendered.height + PostWebViewCell.bottomBarHeight
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let postId = dataSource.itemIdentifier(for: indexPath),
              let rendered = renderedPosts[postId] else {
            return 200
        }
        return PostWebViewCell.headerHeight + rendered.height + PostWebViewCell.bottomBarHeight
    }
}

// MARK: - PostWebViewCellDelegate

extension RepliesViewController: PostWebViewCellDelegate {
    func postWebViewCell(_ cell: PostWebViewCell, didTapImageURL url: URL) {
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }

    func postWebViewCell(_ cell: PostWebViewCell, didTapLinkURL url: URL) {
        handleLink(url)
    }

    func postWebViewCell(_ cell: PostWebViewCell, didTapShowRepliesForPostId postId: Int) {
        let repliesVC = RepliesViewController(api: api, postId: postId, topicId: topicId)
        if let sheet = repliesVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(repliesVC, animated: true)
    }

    func postWebViewCell(_ cell: PostWebViewCell, didTapToggleDetails detailsIndex: Int, postId: Int) {
        guard !reRenderingPostIds.contains(postId) else { return }
        reRenderingPostIds.insert(postId)

        var indices = openDetailsPerPost[postId] ?? []
        if indices.contains(detailsIndex) {
            indices.remove(detailsIndex)
        } else {
            indices.insert(detailsIndex)
        }
        openDetailsPerPost[postId] = indices

        guard let post = replies.first(where: { $0.id == postId }) else { return }
        Task {
            let rendered = await PostContentRenderer.shared.reRenderPost(
                cooked: post.cooked,
                baseURL: baseURL,
                width: view.bounds.width,
                openDetailsIndices: indices
            )
            renderedPosts[postId] = rendered
            var snapshot = dataSource.snapshot()
            snapshot.reconfigureItems([postId])
            await dataSource.apply(snapshot, animatingDifferences: false)
            tableView.beginUpdates()
            tableView.endUpdates()
            self.reRenderingPostIds.remove(postId)
        }
    }

    func postWebViewCell(_ cell: PostWebViewCell, didTapReplyToPost post: DiscourseTopicDetail.Post) {
        guard let authGate = findAuthGate() else { return }
        authGate.requireAuth { [weak self] in
            guard let self else { return }
            self.presentReplyComposer(for: post)
        }
    }

    private func findAuthGate() -> AuthGating? {
        var vc: UIViewController? = self
        while let parent = vc?.presentingViewController ?? vc?.parent {
            if let gate = parent as? AuthGating {
                return gate
            }
            // Walk through children to find ForumContainerViewController
            for child in parent.children {
                if let gate = child as? AuthGating {
                    return gate
                }
                for grandchild in child.children {
                    if let gate = grandchild as? AuthGating {
                        return gate
                    }
                }
            }
            vc = parent
        }
        return nil
    }

    private func presentReplyComposer(for post: DiscourseTopicDetail.Post) {
        let composer = ReplyComposerViewController(
            api: api,
            topicId: topicId,
            replyToPost: post,
            baseURL: baseURL
        )
        composer.onPostCreated = { [weak self] in
            guard let self else { return }
            Task {
                await self.loadReplies()
            }
        }
        let nav = UINavigationController(rootViewController: composer)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }
}
