import UIKit

final class ForumTabBarController: UITabBarController {
    private let api: DiscourseAPI
    private weak var authGate: AuthGating?

    init(api: DiscourseAPI, authGate: AuthGating? = nil) {
        self.api = api
        self.authGate = authGate
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

//        let navBarAppearance = UINavigationBarAppearance()
//        navBarAppearance.configureWithOpaqueBackground()

        let homeVC = HomeViewController(api: api, authGate: authGate)
        let homeNav = UINavigationController(rootViewController: homeVC)
//        homeNav.navigationBar.standardAppearance = navBarAppearance
//        homeNav.navigationBar.scrollEdgeAppearance = navBarAppearance
        homeNav.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)

        let categoriesVC = CategoriesViewController(api: api)
        let categoriesNav = UINavigationController(rootViewController: categoriesVC)
//        categoriesNav.navigationBar.standardAppearance = navBarAppearance
//        categoriesNav.navigationBar.scrollEdgeAppearance = navBarAppearance
        categoriesNav.tabBarItem = UITabBarItem(title: "Categories", image: UIImage(systemName: "square.grid.2x2"), tag: 1)

        let notificationsVC = NotificationsViewController(api: api, authGate: authGate)
        let notificationsNav = UINavigationController(rootViewController: notificationsVC)
//        notificationsNav.navigationBar.standardAppearance = navBarAppearance
//        notificationsNav.navigationBar.scrollEdgeAppearance = navBarAppearance
        notificationsNav.tabBarItem = UITabBarItem(title: "Notifications", image: UIImage(systemName: "bell"), tag: 2)

        let messagesVC = MessagesViewController(api: api, authGate: authGate)
        let messagesNav = UINavigationController(rootViewController: messagesVC)
//        messagesNav.navigationBar.standardAppearance = navBarAppearance
//        messagesNav.navigationBar.scrollEdgeAppearance = navBarAppearance
        messagesNav.tabBarItem = UITabBarItem(title: "Messages", image: UIImage(systemName: "envelope"), tag: 3)

        viewControllers = [homeNav, categoriesNav, notificationsNav, messagesNav]
    }
}
