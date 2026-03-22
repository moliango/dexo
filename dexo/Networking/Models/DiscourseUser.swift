import Foundation

struct DiscourseCurrentUserResponse: Decodable {
    let currentUser: DiscourseCurrentUser

    enum CodingKeys: String, CodingKey {
        case currentUser = "current_user"
    }
}

struct DiscourseCurrentUser: Decodable {
    let id: Int
    let username: String
    let name: String?
    let avatarTemplate: String?

    enum CodingKeys: String, CodingKey {
        case id, username, name
        case avatarTemplate = "avatar_template"
    }
}
