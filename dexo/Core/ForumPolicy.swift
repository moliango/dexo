import Foundation

/// Per-forum UI/feature toggles that depend on the connected Discourse instance.
/// Centralizes host-specific decisions so call sites don't sprinkle string checks.
enum ForumPolicy {
    /// Hosts where the like affordance should be suppressed in post cells.
    private static let likeButtonSuppressedHosts: Set<String> = []

    /// Hosts that don't want client-side read-tracking POSTs to `/topics/timings`.
    private static let readTimingsSuppressedHosts: Set<String> = ["linux.do"]

    /// True when posts on this forum should hide the heart / like button.
    static func hidesLikeButton(baseURL: String) -> Bool {
        matches(baseURL: baseURL, suppressed: likeButtonSuppressedHosts)
    }

    /// True when this forum opts out of `/topics/timings` reporting.
    static func tracksReadTimings(baseURL: String) -> Bool {
        !matches(baseURL: baseURL, suppressed: readTimingsSuppressedHosts)
    }

    /// Host check that also matches subdomains (e.g. `meta.linux.do` for `linux.do`).
    private static func matches(baseURL: String, suppressed: Set<String>) -> Bool {
        guard let host = URL(string: baseURL)?.host?.lowercased() else { return false }
        return suppressed.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}
