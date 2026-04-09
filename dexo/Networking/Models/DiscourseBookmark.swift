import Foundation

struct DiscourseBookmarkList: Decodable {
    let bookmarks: [DiscourseBookmark]

    enum CodingKeys: String, CodingKey {
        case bookmarks = "user_bookmark_list"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let inner = try container.decode(InnerList.self, forKey: .bookmarks)
        self.bookmarks = inner.bookmarks
    }

    private struct InnerList: Decodable {
        let bookmarks: [DiscourseBookmark]
    }
}

struct DiscourseCreateBookmarkResponse: Decodable {
    let id: Int
}

struct DiscourseBookmark: Decodable, Identifiable {
    let id: Int
    let name: String?
    let title: String?
    let topicId: Int?
    let linkedPostNumber: Int?
    let excerpt: String?
    let user: BookmarkUser?
    let createdAt: String?

    var username: String? { user?.username }
    var avatarTemplate: String? { user?.avatarTemplate }

    enum CodingKeys: String, CodingKey {
        case id, name, title, excerpt, user
        case topicId = "topic_id"
        case linkedPostNumber = "linked_post_number"
        case createdAt = "created_at"
    }

    struct BookmarkUser: Decodable {
        let id: Int
        let username: String
        let avatarTemplate: String?

        enum CodingKeys: String, CodingKey {
            case id, username
            case avatarTemplate = "avatar_template"
        }
    }
}
