import Foundation

@Observable
final class AddForumViewModel {
    var urlString = ""
    var isLoading = false
    var errorMessage: String?

    func addForum() async -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a URL."
            return false
        }

        var normalized = trimmed
        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://" + normalized
        }
        normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard URL(string: normalized) != nil else {
            errorMessage = "Invalid URL."
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let tempForum = ForumInstance.new(title: "", baseURL: normalized)
            let api = DiscourseAPI(forum: tempForum)
            let info = try await api.fetchBasicInfo()

            var forum = ForumInstance.new(
                title: info.title,
                baseURL: normalized,
                iconURL: resolveIconURL(base: normalized, info: info)
            )
            try DatabaseManager.shared.saveForum(&forum)
            isLoading = false
            return true
        } catch {
            errorMessage = "Could not connect: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    private func resolveIconURL(base: String, info: DiscourseBasicInfo) -> String? {
        // Prefer apple touch icon (180x180) > logo > favicon
        guard let path = info.appleTouchIconURL ?? info.logoURL ?? info.faviconURL else { return nil }
        if path.hasPrefix("http") {
            return path
        }
        return base + path
    }
}
