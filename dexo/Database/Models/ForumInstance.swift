import Foundation
import GRDB

struct ForumInstance: Sendable, Codable, Identifiable, Equatable, Hashable,
    FetchableRecord, MutablePersistableRecord
{
    nonisolated static let databaseTableName = "forumInstance"

    var id: Int64?
    var title: String
    var baseURL: String
    var iconURL: String?
    var apiKey: String?
    var apiUsername: String?
    var username: String?
    var addedAt: Date
    var sortOrder: Int

    static func new(title: String, baseURL: String, iconURL: String? = nil) -> ForumInstance {
        ForumInstance(
            id: nil,
            title: title,
            baseURL: baseURL,
            iconURL: iconURL,
            apiKey: nil,
            apiUsername: nil,
            username: nil,
            addedAt: Date(),
            sortOrder: 0
        )
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
