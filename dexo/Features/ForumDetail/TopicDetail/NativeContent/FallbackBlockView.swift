import UIKit

/// A placeholder view that asynchronously renders an HTML block via WebView snapshot.
/// Used for content blocks that have no native renderer (e.g. table, onebox, details).
final class FallbackBlockView: UIView {
    private let snapshotImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleToFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let placeholderView: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 8
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var heightConstraint: NSLayoutConstraint!
    private var renderTask: Task<Void, Never>?

    init(html: String, containerWidth: CGFloat, baseURL: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(placeholderView)
        addSubview(snapshotImageView)

        heightConstraint = heightAnchor.constraint(equalToConstant: 80)
        heightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            placeholderView.topAnchor.constraint(equalTo: topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: bottomAnchor),

            snapshotImageView.topAnchor.constraint(equalTo: topAnchor),
            snapshotImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            snapshotImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            snapshotImageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            heightConstraint,
        ])

        renderTask = Task { @MainActor [weak self] in
            let rendered = await PostContentRenderer.shared.renderHTMLBlock(
                html: html,
                baseURL: baseURL,
                width: containerWidth
            )
            guard let self, !Task.isCancelled else { return }
            self.snapshotImageView.image = rendered.snapshot
            self.heightConstraint.constant = rendered.height
            self.placeholderView.isHidden = true

            // Walk up to find the owning UITableView and trigger a height update
            var view: UIView? = self.superview
            while let v = view {
                if let tableView = v as? UITableView {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                    break
                }
                view = v.superview
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func cancelRender() {
        renderTask?.cancel()
        renderTask = nil
    }
}
