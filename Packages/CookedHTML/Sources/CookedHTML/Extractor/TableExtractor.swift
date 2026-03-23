import Foundation
import SwiftSoup

/// Extracts table content from `<table>` elements.
enum TableExtractor {
    static func extract(from element: Element, options: ParseOptions) -> ContentBlock {
        var headers: [[InlineNode]] = []
        var rows: [[[InlineNode]]] = []

        // Extract headers from thead > tr > th
        if let thead = try? element.select("thead").first() {
            if let tr = try? thead.select("tr").first() {
                let thElements = (try? tr.select("th")) ?? Elements()
                for th in thElements {
                    headers.append(InlineExtractor.extract(from: th, options: options))
                }
            }
        }

        // Extract rows from tbody > tr > td
        let tbody = try? element.select("tbody").first()
        let rowParent = tbody ?? element
        let trElements = (try? rowParent.select("tr")) ?? Elements()

        for tr in trElements {
            // Skip header rows
            if let parent = tr.parent(), parent.tagName().lowercased() == "thead" { continue }

            var row: [[InlineNode]] = []
            let cells = tr.children()
            for cell in cells {
                let tag = cell.tagName().lowercased()
                if tag == "td" || tag == "th" {
                    row.append(InlineExtractor.extract(from: cell, options: options))
                }
            }
            if !row.isEmpty {
                rows.append(row)
            }
        }

        return .table(headers: headers, rows: rows)
    }
}
