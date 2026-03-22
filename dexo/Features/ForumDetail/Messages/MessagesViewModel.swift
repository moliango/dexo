import Foundation

@Observable
final class MessagesViewModel {
    var messages: [DiscourseTopicList.Topic] = []
    var isLoading = false
    var errorMessage: String?

    private let api: DiscourseAPI

    init(api: DiscourseAPI) {
        self.api = api
    }

    func loadMessages(username: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await api.fetchPrivateMessages(username: username)
            messages = result.topicList.topics
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
