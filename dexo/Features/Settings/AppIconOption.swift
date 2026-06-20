import UIKit

enum AppIconOption: CaseIterable {
    case primary
    case black
    case ocean
    case ember
    case forest

    var title: String {
        switch self {
        case .primary: return String(localized: "app_icon.default")
        case .black: return String(localized: "app_icon.black")
        case .ocean: return String(localized: "app_icon.ocean")
        case .ember: return String(localized: "app_icon.ember")
        case .forest: return String(localized: "app_icon.forest")
        }
    }

    var alternateIconName: String? {
        switch self {
        case .primary: return nil
        case .black: return "AppIconBlack"
        case .ocean: return "AppIconOcean"
        case .ember: return "AppIconEmber"
        case .forest: return "AppIconForest"
        }
    }

    var imageName: String {
        switch self {
        case .primary: return "AppIcon"
        case .black: return "AppIconBlack"
        case .ocean: return "AppIconOcean"
        case .ember: return "AppIconEmber"
        case .forest: return "AppIconForest"
        }
    }

    static var current: AppIconOption {
        option(for: UIApplication.shared.alternateIconName)
    }

    static func option(for alternateIconName: String?) -> AppIconOption {
        allCases.first { $0.alternateIconName == alternateIconName } ?? .primary
    }
}
