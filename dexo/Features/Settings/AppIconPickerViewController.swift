import UIKit

final class AppIconPickerViewController: ObservableViewController {
    override var backgroundStyle: BackgroundStyle { .grouped }

    var onSelectionChanged: (() -> Void)?

    private let themeManager = ThemeManager.shared

    private lazy var tableView: UITableView = {
        let tv = ThemedTableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(AppIconCell.self, forCellReuseIdentifier: AppIconCell.reuseId)
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "settings.app_icon")

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func updateUI() {
        tableView.backgroundColor = themeManager.backgroundColor
        tableView.reloadData()
    }

    private func selectIcon(_ option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else {
            showIconChangeError()
            return
        }

        UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
            Task { @MainActor in
                if error != nil {
                    self.showIconChangeError()
                    return
                }

                self.tableView.reloadData()
                self.onSelectionChanged?()
            }
        }
    }

    private func showIconChangeError() {
        let alert = UIAlertController(
            title: String(localized: "app_icon.error.title"),
            message: String(localized: "app_icon.error.message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "action.ok"), style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension AppIconPickerViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        AppIconOption.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AppIconCell.reuseId, for: indexPath) as! AppIconCell
        let option = AppIconOption.allCases[indexPath.row]
        cell.configure(with: option, isSelected: option == AppIconOption.current)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AppIconPickerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let option = AppIconOption.allCases[indexPath.row]
        guard option != AppIconOption.current else { return }
        selectIcon(option)
    }
}

// MARK: - App Icon Cell

private final class AppIconCell: UITableViewCell {
    static let reuseId = "AppIconCell"

    private let previewImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 10
        iv.layer.cornerCurve = .continuous
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = FontManager.shared.font(size: 17)
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        contentView.addSubview(previewImageView)
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            previewImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previewImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            previewImageView.widthAnchor.constraint(equalToConstant: 44),
            previewImageView.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.leadingAnchor.constraint(equalTo: previewImageView.trailingAnchor, constant: 14),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -44),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
        ])
    }

    func configure(with option: AppIconOption, isSelected: Bool) {
        backgroundColor = ThemeManager.shared.cardBackgroundColor
        previewImageView.image = UIImage(named: option.imageName) ?? UIImage(systemName: "app")
        nameLabel.text = option.title
        nameLabel.font = FontManager.shared.font(size: 17)
        accessoryType = isSelected ? .checkmark : .none
    }
}
