import Foundation

nonisolated struct DiscourseUploadResponse: Decodable, Sendable {
    let id: Int
    let url: String
    let shortUrl: String
    let shortPath: String
    let originalFilename: String

    enum CodingKeys: String, CodingKey {
        case id, url
        case shortUrl = "short_url"
        case shortPath = "short_path"
        case originalFilename = "original_filename"
    }
}
