import Foundation

/// Resolves relative URLs against a base URL.
enum URLResolver {
    /// Resolve a potentially relative URL string against a base URL.
    /// Returns the original string if resolution is not possible.
    static func resolve(_ urlString: String, baseURL: String?) -> String {
        guard let baseURL, !baseURL.isEmpty else { return urlString }

        // Already absolute
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") || urlString.hasPrefix("data:") {
            return urlString
        }

        // Protocol-relative
        if urlString.hasPrefix("//") {
            return "https:" + urlString
        }

        guard let base = URL(string: baseURL) else { return urlString }

        if urlString.hasPrefix("/") {
            // Absolute path — resolve against scheme + host, preserving query/fragment.
            var components = URLComponents()
            components.scheme = base.scheme
            components.host = base.host
            components.port = base.port
            if let resolved = URL(string: urlString, relativeTo: components.url)?.absoluteURL {
                return resolved.absoluteString
            }
            components.percentEncodedPath = urlString
            return components.url?.absoluteString ?? urlString
        }

        // Relative path
        if let resolved = URL(string: urlString, relativeTo: base)?.absoluteURL {
            return resolved.absoluteString
        }
        return base.appendingPathComponent(urlString).absoluteString
    }
}
