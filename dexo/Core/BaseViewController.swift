import UIKit

class BaseViewController: UIViewController {

    enum BackgroundStyle { case plain, grouped }

    /// Override to return `.grouped` for view controllers that use insetGrouped / grouped table style.
    /// Defaults to `.plain` which maps to `ThemeManager.cardBackgroundColor`.
    var backgroundStyle: BackgroundStyle { .plain }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: ThemeManager.themeDidChangeNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyThemeBackground()
    }

    @objc private func themeDidChange() {
        applyThemeBackground()
    }

    func applyThemeBackground() {
        let theme = ThemeManager.shared
        switch backgroundStyle {
        case .grouped:
            view.backgroundColor = theme.backgroundColor
        case .plain:
            view.backgroundColor = theme.cardBackgroundColor
        }
    }
}
