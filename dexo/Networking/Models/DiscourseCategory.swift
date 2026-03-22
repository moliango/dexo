import Foundation

struct DiscourseCategoryList: Decodable {
    let categoryList: CategoryList

    enum CodingKeys: String, CodingKey {
        case categoryList = "category_list"
    }

    struct CategoryList: Decodable {
        let categories: [DiscourseCategory]
    }
}

struct DiscourseCategory: Decodable, Identifiable {
    let id: Int
    let name: String
    let color: String
    let textColor: String?
    let slug: String
    let topicCount: Int
    let description: String?
    let descriptionExcerpt: String?
    let parentCategoryId: Int?
    let subcategoryList: [DiscourseCategory]?

    enum CodingKeys: String, CodingKey {
        case id, name, color, slug, description
        case textColor = "text_color"
        case topicCount = "topic_count"
        case descriptionExcerpt = "description_excerpt"
        case parentCategoryId = "parent_category_id"
        case subcategoryList = "subcategory_list"
    }

    init(id: Int, name: String, slug: String, color: String = "808080") {
        self.id = id
        self.name = name
        self.color = color
        self.textColor = nil
        self.slug = slug
        self.topicCount = 0
        self.description = nil
        self.descriptionExcerpt = nil
        self.parentCategoryId = nil
        self.subcategoryList = nil
    }
}
