import Foundation

@Observable
final class NotificationsViewModel {
    var notifications: [DiscourseNotification] = []
    var isLoading = false
    var errorMessage: String?

    private let api: DiscourseAPI

    init(api: DiscourseAPI) {
        self.api = api
    }

    func loadNotifications() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await api.fetchNotifications()
            notifications = result.notifications
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
