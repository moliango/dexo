import Foundation

@Observable
final class TopicComposerViewModel {
    var title: String = ""
    var body: String = ""
    var selectedCategory: DiscourseCategory?
    var selectedTags: [String] = []
    var categories: [DiscourseCategory] = []
    var tagSuggestions: [DiscourseTag] = []
    var isSubmitting = false
    var isUploadingImage = false
    var errorMessage: String?

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedCategory != nil
            && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSubmitting
    }

    var hasUnsavedChanges: Bool {
        !title.isEmpty || !body.isEmpty || selectedCategory != nil || !selectedTags.isEmpty
    }

    private let api: DiscourseAPI

    init(api: DiscourseAPI) {
        self.api = api
    }

    func loadCategories() async {
        do {
            let list = try await api.fetchCategories()
            categories = list.categoryList.categories
        } catch {
            // Non-critical — user can retry
        }
    }

    func searchTags(query: String) async {
        do {
            tagSuggestions = try await api.searchTags(query: query)
        } catch {
            tagSuggestions = []
        }
    }

    func submit() async throws -> Int {
        guard let categoryId = selectedCategory?.id else { return -1 }
        let raw = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let topicTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        isSubmitting = true
        defer { isSubmitting = false }

        let response = try await api.createTopic(
            title: topicTitle,
            categoryId: categoryId,
            raw: raw,
            tags: selectedTags
        )
        return response.id
    }

    func uploadImage(data: Data, filename: String) async throws -> DiscourseUploadResponse {
        isUploadingImage = true
        defer { isUploadingImage = false }
        return try await api.uploadImage(data: data, filename: filename)
    }
}
