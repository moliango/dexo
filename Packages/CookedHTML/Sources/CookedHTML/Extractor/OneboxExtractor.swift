import Foundation
import SwiftSoup

/// Extracts Discourse onebox blocks (`aside.onebox`).
enum OneboxExtractor {
    static func extract(from element: Element, options: ParseOptions) -> ContentBlock {
        // Source URL from header > a
        let sourceURL: String? = {
            guard let anchor = try? element.select("header a").first() else { return nil }
            let href = (try? anchor.attr("href")) ?? ""
            return href.isEmpty ? nil : URLResolver.resolve(href, baseURL: options.baseURL)
        }()

        // Title from h3 or h4 in .onebox-body, or article title
        let title: String? = {
            if let h = try? element.select(".onebox-body h3").first() ?? element.select(".onebox-body h4").first() {
                return try? h.text()
            }
            return nil
        }()

        // Description from p in .onebox-body
        let description: String? = {
            guard let p = try? element.select(".onebox-body p").first() else { return nil }
            let text = (try? p.text()) ?? ""
            return text.isEmpty ? nil : text
        }()

        // Image from img in .onebox-body or .thumbnail
        let imageURL: String? = {
            let selectors = [".onebox-body img", ".thumbnail img", "img"]
            for selector in selectors {
                if let img = try? element.select(selector).first() {
                    let src = (try? img.attr("src")) ?? ""
                    if !src.isEmpty {
                        return URLResolver.resolve(src, baseURL: options.baseURL)
                    }
                }
            }
            return nil
        }()

        return .onebox(sourceURL: sourceURL, title: title, description: description, imageURL: imageURL)
    }
}
