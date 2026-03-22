import Foundation

struct DiscourseNotificationList: Decodable {
    let notifications: [DiscourseNotification]
}

struct DiscourseNotification: Decodable, Identifiable {
    let id: Int
    let notificationType: Int
    let read: Bool
    let createdAt: String
    let topicId: Int?
    let slug: String?
    let data: NotificationData

    enum CodingKeys: String, CodingKey {
        case id, read, slug, data
        case notificationType = "notification_type"
        case createdAt = "created_at"
        case topicId = "topic_id"
    }

    struct NotificationData: Decodable {
        let topicTitle: String?
        let displayUsername: String?

        enum CodingKeys: String, CodingKey {
            case topicTitle = "topic_title"
            case displayUsername = "display_username"
        }
    }
}
