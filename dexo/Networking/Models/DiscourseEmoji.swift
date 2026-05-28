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
    /// True when Discourse queued the post for moderation review (the
    /// "needs approval" flow), in which case the post isn't published in
    /// the stream yet and `postNumber` is unavailable. The response then
    /// looks like `{"action":"enqueued","success":true,"pending_post":{"id":N,…}}`.
    let enqueued: Bool
    /// Post ID. For the normal path this is the published post's id; for
    /// `enqueued` it falls back to `pending_post.id` so callers that index
    /// by id still have *something* to key on.
    let id: Int
    /// Position of the new post in the topic. Nil when the post is queued
    /// for review — the floor only gets assigned after a moderator approves.
    let postNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id, action
        case postNumber = "post_number"
        case pendingPost = "pending_post"
    }

    private enum PendingKeys: String, CodingKey {
        case id
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let action = (try? c.decodeIfPresent(String.self, forKey: .action)) ?? nil
        if action == "enqueued" {
            enqueued = true
            let pending = try c.nestedContainer(keyedBy: PendingKeys.self, forKey: .pendingPost)
            id = try pending.decode(Int.self, forKey: .id)
            postNumber = nil
        } else {
            enqueued = false
            id = try c.decode(Int.self, forKey: .id)
            postNumber = try? c.decodeIfPresent(Int.self, forKey: .postNumber)
        }
    }
}
