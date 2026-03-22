import Foundation

@Observable
final class CategoriesViewModel {
    var categories: [DiscourseCategory] = []
    var isLoading = false
    var errorMessage: String?

    private let api: DiscourseAPI

    init(api: DiscourseAPI) {
        self.api = api
    }

    func loadCategories() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await api.fetchCategories()
            categories = result.categoryList.categories.filter { $0.parentCategoryId == nil }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
