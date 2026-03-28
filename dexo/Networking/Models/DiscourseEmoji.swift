import Foundation

struct DiscourseCustomEmoji: Decodable {
    let name: String
    let url: String
}

struct DiscourseEmojiEntry: Codable {
    let name: String
    let url: String
    let searchAliases: [String]?

    enum CodingKeys: String, CodingKey {
        case name, url
        case searchAliases = "search_aliases"
    }
}

struct DiscourseCreatePostResponse: Decodable {
    let id: Int
    let postNumber: Int

    enum CodingKeys: String, CodingKey {
        case id
        case postNumber = "post_number"
    }
}
