import Foundation
import os.log

private let logger = Logger(subsystem: "com.eilgnaw.dexo", category: "DoH")

final class DoHResolver {
    static let shared = DoHResolver()

    private var cache: [String: (ip: String, expiry: Date)] = [:]

    /// Thread-safe storage for IP→hostname mapping, accessed from nonisolated TLS callbacks.
    nonisolated(unsafe) private var _ipToHostname: [String: String] = [:]

    /// Reverse lookup: get the original hostname for a resolved IP.
    /// Called from nonisolated ServerTrustManager callbacks.
    nonisolated func originalHost(for ip: String) -> String? {
        _ipToHostname[ip]
    }

    /// Resolve a hostname to an IP address via DNS over HTTPS.
    /// Returns nil if DoH is disabled or resolution fails (falls back to system DNS).
    func resolve(_ hostname: String) async -> String? {
        let settings = AppSettings.shared
        guard settings.dohEnabled else { return nil }

        // Skip if already an IP address
        if hostname.allSatisfy({ $0.isNumber || $0 == "." || $0 == ":" }) {
            return nil
        }

        // Check cache
        if let cached = cache[hostname], cached.expiry > Date() {
            logger.debug("[DoH] cache hit: \(hostname) → \(cached.ip)")
            return cached.ip
        }

        let serverURL = settings.dohServerURL
        guard !serverURL.isEmpty,
              var components = URLComponents(string: serverURL) else {
            logger.warning("[DoH] invalid server URL, falling back to system DNS")
            return nil
        }

        // Avoid resolving the DoH server's own hostname (infinite loop)
        if let serverHost = components.host, serverHost == hostname {
            return nil
        }

        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "name", value: hostname),
            URLQueryItem(name: "type", value: "A"),
        ]

        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/dns-json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5

        logger.info("[DoH] resolving \(hostname) via \(serverURL)")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let answers = json["Answer"] as? [[String: Any]] else {
                logger.warning("[DoH] no Answer in response for \(hostname)")
                return nil
            }

            for answer in answers {
                if let type = answer["type"] as? Int, type == 1,
                   let ip = answer["data"] as? String {
                    let ttl = answer["TTL"] as? Int ?? 300
                    cache[hostname] = (ip, Date().addingTimeInterval(TimeInterval(ttl)))
                    _ipToHostname[ip] = hostname
                    logger.info("[DoH] resolved \(hostname) → \(ip) (TTL: \(ttl)s)")
                    return ip
                }
            }
            logger.warning("[DoH] no A record found for \(hostname)")
        } catch {
            logger.error("[DoH] resolution failed for \(hostname): \(error.localizedDescription)")
        }
        return nil
    }

    /// Clear all cached DNS entries.
    func clearCache() {
        cache.removeAll()
        _ipToHostname.removeAll()
        logger.info("[DoH] cache cleared")
    }
}
