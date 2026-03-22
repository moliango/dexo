import UIKit
import SafariServices
import SDWebImage
import Lightbox

final class TopicDetailViewController: ObservableViewController {
    private let viewModel: TopicDetailViewModel
    private let api: DiscourseAPI
    private let topicId: Int
    private let baseURL: String
    private var hasTitleHeader = false
    private var isTogglingDetails = false

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(PostWebViewCell.self, forCellReuseIdentifier: PostWebViewCell.reuseIdentifier)
        tv.delegate = self
        tv.separatorStyle = .none
        tv.isHidden = true
        return tv
    }()

    private lazy var dataSource: UITableViewDiffableDataSource<Int, Int> = {
        UITableViewDiffableDataSource<Int, Int>(tableView: tableView) { [weak self] tableView, indexPath, postId in
            guard let self,
                  let cell = tableView.dequeueReusableCell(withIdentifier: PostWebViewCell.reuseIdentifier, for: indexPath) as? PostWebViewCell,
                  let post = self.viewModel.posts.first(where: { $0.id == postId }),
                  let rendered = self.viewModel.renderedPosts[postId] else {
                return UITableViewCell()
            }
            let visiblePosts = self.viewModel.visiblePosts
            let floorNumber = (visiblePosts.firstIndex(where: { $0.id == postId }) ?? 0) + 1
            let postLink = "\(self.baseURL)/t/\(self.topicId)/\(post.postNumber)"
            cell.configure(
                with: post,
                snapshot: rendered.snapshot,
                contentHeight: rendered.height,
                interactiveRegions: rendered.interactiveRegions,
                codeBlocks: rendered.codeBlocks,
                baseURL: self.baseURL,
                delegate: self,
                floorNumber: floorNumber,
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

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.numberOfLines = 0
        return label
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let footerSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.hidesWhenStopped = true
        spinner.frame = CGRect(x: 0, y: 0, width: 0, height: 44)
        return spinner
    }()

    private let replyButton: UIButton = {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 16)
        let image = UIImage(systemName: "arrowshape.turn.up.left.fill")
        let button: UIButton
        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.glass()
            config.image = image
            config.cornerStyle = .capsule
            config.preferredSymbolConfigurationForImage = symbolConfig
            button = UIButton(configuration: config)
        } else {
            var config = UIButton.Configuration.filled()
            config.image = image
            config.cornerStyle = .capsule
            config.baseBackgroundColor = .tintColor
            config.baseForegroundColor = .white
            config.preferredSymbolConfigurationForImage = symbolConfig
            button = UIButton(configuration: config)
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    init(api: DiscourseAPI, topicId: Int) {
        self.api = api
        self.viewModel = TopicDetailViewModel(api: api)
        self.topicId = topicId
        self.baseURL = api.baseURL
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(tableView)
        view.addSubview(activityIndicator)
        view.addSubview(errorLabel)
        view.addSubview(replyButton)

        tableView.tableFooterView = footerSpinner

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            replyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            replyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            replyButton.widthAnchor.constraint(equalToConstant: 44),
            replyButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        replyButton.addTarget(self, action: #selector(replyButtonTapped), for: .touchUpInside)

        Task {
            await viewModel.loadTopic(id: topicId, containerWidth: view.bounds.width)
        }
    }

    override func updateUI() {
        // Title header (set once)
        if let topicTitle = viewModel.topic?.title, !hasTitleHeader {
            titleLabel.text = topicTitle
            updateTitleHeader()
            hasTitleHeader = true
        }

        // Loading
        if viewModel.isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }

        // Error
        if let error = viewModel.errorMessage {
            errorLabel.text = error
            errorLabel.isHidden = false
        } else {
            errorLabel.isHidden = true
        }

        // Footer spinner
        if viewModel.isLoadingMore {
            footerSpinner.startAnimating()
        } else {
            footerSpinner.stopAnimating()
        }

        // Show posts progressively — only include visible (non-action) posts that have been rendered
        if viewModel.isReady {
            tableView.isHidden = false
            var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
            snapshot.appendSections([0])
            var seen = Set<Int>()
            let renderedIds = viewModel.visiblePosts.compactMap { post -> Int? in
                guard viewModel.renderedPosts[post.id] != nil, seen.insert(post.id).inserted else { return nil }
                return post.id
            }
            snapshot.appendItems(renderedIds, toSection: 0)
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    private func updateTitleHeader() {
        let container = UIView()
        container.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])
        let targetSize = CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let size = container.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        container.frame.size = size
        tableView.tableHeaderView = container
    }

    // MARK: - Container Access

    @objc private func replyButtonTapped() {
        guard let authGate = findForumContainer() else { return }
        authGate.requireAuth { [weak self] in
            self?.presentReplyComposer()
        }
    }

    private func findForumContainer() -> ForumContainerViewController? {
        var vc: UIViewController? = self
        while let parent = vc?.parent {
            if let container = parent as? ForumContainerViewController {
                return container
            }
            vc = parent
        }
        return nil
    }

    // MARK: - Link Handling

    private func handleLink(_ url: URL) {
        guard let baseHost = URL(string: baseURL)?.host,
              let linkHost = url.host else {
            let safari = SFSafariViewController(url: url)
            present(safari, animated: true)
            return
        }

        if linkHost == baseHost {
            if let topicId = parseTopicId(from: url) {
                let detailVC = TopicDetailViewController(api: api, topicId: topicId)
                navigationController?.pushViewController(detailVC, animated: true)
            } else if let (slug, categoryId) = parseCategoryInfo(from: url) {
                let category = DiscourseCategory(id: categoryId, name: slug, slug: slug)
                let vc = CategoryTopicsViewController(api: api, category: category)
                navigationController?.pushViewController(vc, animated: true)
            } else if let tagName = parseTagName(from: url) {
                let vc = TagTopicsViewController(api: api, tagName: tagName)
                navigationController?.pushViewController(vc, animated: true)
            } else {
                let safari = SFSafariViewController(url: url)
                present(safari, animated: true)
            }
        } else {
            let safari = SFSafariViewController(url: url)
            present(safari, animated: true)
        }
    }

    private func parseTopicId(from url: URL) -> Int? {
        let components = url.pathComponents
        guard let tIndex = components.firstIndex(of: "t") else { return nil }
        for i in (tIndex + 1)..<components.count {
            if let id = Int(components[i]) {
                return id
            }
        }
        return nil
    }

    private func parseCategoryInfo(from url: URL) -> (slug: String, id: Int)? {
        let components = url.pathComponents
        guard let cIndex = components.firstIndex(of: "c"),
              cIndex + 2 < components.count else { return nil }
        let remaining = Array(components[(cIndex + 1)...])
        // Format: /c/slug/id or /c/parent-slug/child-slug/id
        // The last numeric component is the category ID, slug is right before it
        for i in remaining.indices.reversed() {
            let cleaned = remaining[i].replacingOccurrences(of: ".json", with: "")
            if let id = Int(cleaned), i > 0 {
                let slug = remaining[i - 1]
                return (slug, id)
            }
        }
        return nil
    }

    private func parseTagName(from url: URL) -> String? {
        let components = url.pathComponents
        // Format: /tag/{tag_name} or /tags/{tag_name}
        if let tagIndex = components.firstIndex(where: { $0 == "tag" || $0 == "tags" }),
           tagIndex + 1 < components.count {
            return components[tagIndex + 1]
        }
        return nil
    }
}

// MARK: - UITableViewDelegate

extension TopicDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let postId = dataSource.itemIdentifier(for: indexPath),
              let rendered = viewModel.renderedPosts[postId] else {
            return UITableView.automaticDimension
        }
        return PostWebViewCell.headerHeight + rendered.height + PostWebViewCell.bottomBarHeight
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let postId = dataSource.itemIdentifier(for: indexPath),
              let rendered = viewModel.renderedPosts[postId] else {
            return 200
        }
        return PostWebViewCell.headerHeight + rendered.height + PostWebViewCell.bottomBarHeight
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let header = tableView.tableHeaderView else { return }
        let headerBottom = header.frame.maxY
        let offsetY = scrollView.contentOffset.y + scrollView.safeAreaInsets.top
        if offsetY >= headerBottom {
            title = viewModel.topic?.title
        } else {
            title = nil
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let totalRows = tableView.numberOfRows(inSection: 0)
        if indexPath.row >= totalRows - 3 {
            Task {
                await viewModel.loadMorePosts(containerWidth: view.bounds.width)
            }
        }
    }
}

// MARK: - PostWebViewCellDelegate

extension TopicDetailViewController: PostWebViewCellDelegate {
    func postWebViewCell(_ cell: PostWebViewCell, didTapImageURL url: URL) {
        SDWebImageManager.shared.loadImage(with: url, progress: nil) { [weak self] image, _, _, _, _, _ in
            guard let self, let image else { return }
            let controller = LightboxController(images: [LightboxImage(image: image)])
            controller.dynamicBackground = true
            controller.modalPresentationStyle = .fullScreen
            self.present(controller, animated: true)
        }
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
        guard !isTogglingDetails else { return }
        isTogglingDetails = true
        Task {
            await viewModel.toggleDetails(postId: postId, detailsIndex: detailsIndex, containerWidth: view.bounds.width)
            var snapshot = dataSource.snapshot()
            snapshot.reconfigureItems([postId])
            await dataSource.apply(snapshot, animatingDifferences: false)
            tableView.beginUpdates()
            tableView.endUpdates()
            isTogglingDetails = false
        }
    }

    func postWebViewCell(_ cell: PostWebViewCell, didTapReplyToPost post: DiscourseTopicDetail.Post) {
        guard let authGate = findForumContainer() else { return }
        authGate.requireAuth { [weak self] in
            guard let self else { return }
            self.presentReplyComposer(for: post)
        }
    }

    private func presentReplyComposer(for post: DiscourseTopicDetail.Post? = nil) {
        let composer = ReplyComposerViewController(
            api: api,
            topicId: topicId,
            replyToPost: post,
            baseURL: baseURL
        )
        composer.onPostCreated = { [weak self] in
            guard let self else { return }
            Task {
                await self.viewModel.loadTopic(id: self.topicId, containerWidth: self.view.bounds.width)
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
