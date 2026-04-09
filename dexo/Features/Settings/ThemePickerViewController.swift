import UIKit

final class ThemePickerViewController: ObservableViewController {
    override var backgroundStyle: BackgroundStyle { .grouped }

    private let themeManager = ThemeManager.shared
    private let settings = AppSettings.shared

    private lazy var tableView: UITableView = {
        let tv = ThemedTableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(ThemePresetCell.self, forCellReuseIdentifier: ThemePresetCell.reuseId)
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "settings.theme")

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

    // MARK: - Sections

    private enum Section: Int, CaseIterable {
        case presets
        case custom
    }
}

// MARK: - UITableViewDataSource

extension ThemePickerViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .presets: return ThemeDefinition.presets.count
        case .custom: return 1
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .presets: return String(localized: "theme.section.presets")
        case .custom: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .presets:
            let cell = tableView.dequeueReusableCell(withIdentifier: ThemePresetCell.reuseId, for: indexPath) as! ThemePresetCell
            let theme = ThemeDefinition.presets[indexPath.row]
            let isSelected = settings.selectedThemeId == theme.id
            cell.configure(with: theme, isSelected: isSelected)

            return cell
        case .custom:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = String(localized: "theme.custom")
            cell.accessoryType = settings.selectedThemeId == "custom" ? .checkmark : .disclosureIndicator

            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension ThemePickerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section)! {
        case .presets:
            let theme = ThemeDefinition.presets[indexPath.row]
            themeManager.selectTheme(id: theme.id)
        case .custom:
            let vc = CustomThemeViewController()
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - Preset Cell

private final class ThemePresetCell: UITableViewCell {
    static let reuseId = "ThemePresetCell"

    private let nameLabel = UILabel()
    private let colorsStack = UIStackView()
    private let lightAccentDot = UIView()
    private let darkAccentDot = UIView()
    private let lightBgDot = UIView()
    private let darkBgDot = UIView()
    private let lightCardDot = UIView()
    private let darkCardDot = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        let dots = [lightAccentDot, darkAccentDot, lightBgDot, darkBgDot, lightCardDot, darkCardDot]
        for dot in dots {
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = 12
            dot.layer.borderWidth = 1
            dot.layer.borderColor = UIColor.separator.cgColor
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 24),
                dot.heightAnchor.constraint(equalToConstant: 24),
            ])
        }

        colorsStack.axis = .horizontal
        colorsStack.spacing = 6
        colorsStack.translatesAutoresizingMaskIntoConstraints = false
        for dot in dots { colorsStack.addArrangedSubview(dot) }

        nameLabel.font = .systemFont(ofSize: 16)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(nameLabel)
        contentView.addSubview(colorsStack)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            colorsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            colorsStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
        ])
    }

    func configure(with theme: ThemeDefinition, isSelected: Bool) {
        nameLabel.text = theme.name
        lightAccentDot.backgroundColor = UIColor(hex: theme.lightAccentHex)
        darkAccentDot.backgroundColor = UIColor(hex: theme.darkAccentHex)
        lightBgDot.backgroundColor = UIColor(hex: theme.lightBackgroundHex)
        darkBgDot.backgroundColor = UIColor(hex: theme.darkBackgroundHex)
        lightCardDot.backgroundColor = UIColor(hex: theme.lightCardBackgroundHex)
        darkCardDot.backgroundColor = UIColor(hex: theme.darkCardBackgroundHex)
        accessoryType = isSelected ? .checkmark : .none
    }
}

// MARK: - Custom Theme ViewController

final class CustomThemeViewController: ObservableViewController {
    override var backgroundStyle: BackgroundStyle { .grouped }

    private let themeManager = ThemeManager.shared
    private let settings = AppSettings.shared

    private lazy var tableView: UITableView = {
        let tv = ThemedTableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "theme.custom")

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

    // MARK: - Data

    private enum Section: Int, CaseIterable {
        case light
        case dark
    }

    private enum Row: Int, CaseIterable {
        case accent
        case background
        case cardBackground
    }

    private func rowTitle(_ row: Row) -> String {
        switch row {
        case .accent: return String(localized: "theme.color.accent")
        case .background: return String(localized: "theme.color.background")
        case .cardBackground: return String(localized: "theme.color.card_background")
        }
    }

    private func currentHex(section: Section, row: Row) -> String {
        switch (section, row) {
        case (.light, .accent): return settings.customLightAccentHex
        case (.light, .background): return settings.customLightBackgroundHex
        case (.light, .cardBackground): return settings.customLightCardBackgroundHex
        case (.dark, .accent): return settings.customDarkAccentHex
        case (.dark, .background): return settings.customDarkBackgroundHex
        case (.dark, .cardBackground): return settings.customDarkCardBackgroundHex
        }
    }

    private func setHex(_ hex: String, section: Section, row: Row) {
        switch (section, row) {
        case (.light, .accent): settings.customLightAccentHex = hex
        case (.light, .background): settings.customLightBackgroundHex = hex
        case (.light, .cardBackground): settings.customLightCardBackgroundHex = hex
        case (.dark, .accent): settings.customDarkAccentHex = hex
        case (.dark, .background): settings.customDarkBackgroundHex = hex
        case (.dark, .cardBackground): settings.customDarkCardBackgroundHex = hex
        }
        themeManager.notifyChange()
    }
}

// MARK: - UITableViewDataSource

extension CustomThemeViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .light: return String(localized: "theme.section.light")
        case .dark: return String(localized: "theme.section.dark")
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = Section(rawValue: indexPath.section)!
        let row = Row(rawValue: indexPath.row)!
        let hex = currentHex(section: section, row: row)

        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = rowTitle(row)
        cell.backgroundColor = themeManager.cardBackgroundColor

        let colorView = UIView()
        colorView.translatesAutoresizingMaskIntoConstraints = false
        colorView.backgroundColor = UIColor(hex: hex)
        colorView.layer.cornerRadius = 12
        colorView.layer.borderWidth = 1
        colorView.layer.borderColor = UIColor.separator.cgColor
        cell.accessoryView = colorView
        NSLayoutConstraint.activate([
            colorView.widthAnchor.constraint(equalToConstant: 24),
            colorView.heightAnchor.constraint(equalToConstant: 24),
        ])

        return cell
    }
}

// MARK: - UITableViewDelegate

extension CustomThemeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let section = Section(rawValue: indexPath.section)!
        let row = Row(rawValue: indexPath.row)!
        let hex = currentHex(section: section, row: row)

        let picker = UIColorPickerViewController()
        picker.selectedColor = UIColor(hex: hex) ?? .systemBlue
        picker.supportsAlpha = false
        picker.title = rowTitle(row)
        picker.delegate = self
        picker.view.tag = indexPath.section * 100 + indexPath.row
        present(picker, animated: true)
    }
}

// MARK: - UIColorPickerViewControllerDelegate

extension CustomThemeViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        guard !continuously else { return }
        let tag = viewController.view.tag
        let section = Section(rawValue: tag / 100)!
        let row = Row(rawValue: tag % 100)!

        // Activate custom theme if not already
        if settings.selectedThemeId != "custom" {
            settings.selectedThemeId = "custom"
        }

        setHex(color.hexString, section: section, row: row)
    }
}
