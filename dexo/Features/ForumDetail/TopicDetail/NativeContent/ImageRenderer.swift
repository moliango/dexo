import UIKit
import CookedHTML
import SDWebImage

// MARK: - TappableImageContainer

final class TappableImageContainer: UIView {
    var imageURL: URL?
    weak var delegate: PostCellDelegate?

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private var heightConstraint: NSLayoutConstraint!

    init(url: URL, width: Int?, height: Int?, containerWidth: CGFloat) {
        self.imageURL = url
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .secondarySystemFill
        layer.cornerRadius = 4
        clipsToBounds = true

        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let placeholderHeight: CGFloat
        if let w = width, let h = height, w > 0 {
            let scale = containerWidth / CGFloat(w)
            placeholderHeight = CGFloat(h) * scale
        } else {
            // Default 16:9 ratio
            placeholderHeight = containerWidth * 9.0 / 16.0
        }
        heightConstraint = heightAnchor.constraint(equalToConstant: placeholderHeight)
        heightConstraint.isActive = true

        let hasOriginalSize = width != nil && height != nil

        imageView.sd_setImage(with: url) { [weak self] image, _, _, _ in
            guard let self, let image else { return }
            self.backgroundColor = .clear
            if !hasOriginalSize {
                let ratio = containerWidth / image.size.width
                self.heightConstraint.constant = image.size.height * ratio
            }
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func imageTapped() {
        guard let imageURL else { return }
        delegate?.postCell(didTapImageURL: imageURL)
    }

    func cancelImageLoad() {
        imageView.sd_cancelCurrentImageLoad()
    }
}

// MARK: - ImageRenderer

enum ImageRenderer: BlockRenderer {
    static func canRender(_ block: ContentBlock) -> Bool {
        if case .image = block { return true }
        return false
    }

    static func render(_ block: ContentBlock, config: NativeRenderConfig, delegate: PostCellDelegate?) -> UIView {
        guard case .image(let src, _, let width, let height) = block,
              let url = URL(string: src) else {
            return UIView()
        }

        let container = TappableImageContainer(
            url: url,
            width: width,
            height: height,
            containerWidth: config.contentWidth
        )
        container.delegate = delegate
        return container
    }
}
