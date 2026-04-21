import Foundation

extension String {
    /// Decodes the subset of HTML entities Discourse emits in `fancy_title`
    /// (typographic substitutions + HTML-safe escapes) plus numeric character
    /// references. Returns `self` unchanged if no `&` is present.
    func decodingHTMLEntities() -> String {
        guard contains("&") else { return self }

        var result = ""
        result.reserveCapacity(count)

        var i = startIndex
        while i < endIndex {
            let c = self[i]
            if c != "&" {
                result.append(c)
                i = index(after: i)
                continue
            }

            // Scan up to the next ';' within a small lookahead window.
            let maxEntityLength = 10
            let scanEnd = index(i, offsetBy: maxEntityLength, limitedBy: endIndex) ?? endIndex
            if let semi = self[i..<scanEnd].firstIndex(of: ";") {
                let entity = String(self[index(after: i)..<semi])
                if let decoded = Self.decodeEntity(entity) {
                    result.append(decoded)
                    i = index(after: semi)
                    continue
                }
            }

            result.append(c)
            i = index(after: i)
        }

        return result
    }

    private static let namedEntities: [String: String] = [
        "amp": "&",
        "lt": "<",
        "gt": ">",
        "quot": "\"",
        "apos": "'",
        "nbsp": "\u{00A0}",
        "hellip": "\u{2026}",
        "mdash": "\u{2014}",
        "ndash": "\u{2013}",
        "ldquo": "\u{201C}",
        "rdquo": "\u{201D}",
        "lsquo": "\u{2018}",
        "rsquo": "\u{2019}",
        "laquo": "\u{00AB}",
        "raquo": "\u{00BB}",
        "copy": "\u{00A9}",
        "reg": "\u{00AE}",
        "trade": "\u{2122}",
        "middot": "\u{00B7}",
        "bull": "\u{2022}",
    ]

    private static func decodeEntity(_ entity: String) -> String? {
        if entity.isEmpty { return nil }
        if entity.first == "#" {
            let numeric = entity.dropFirst()
            let scalar: Unicode.Scalar?
            if let first = numeric.first, first == "x" || first == "X" {
                scalar = UInt32(numeric.dropFirst(), radix: 16).flatMap(Unicode.Scalar.init)
            } else {
                scalar = UInt32(numeric).flatMap(Unicode.Scalar.init)
            }
            return scalar.map { String(Character($0)) }
        }
        return namedEntities[entity]
    }
}
