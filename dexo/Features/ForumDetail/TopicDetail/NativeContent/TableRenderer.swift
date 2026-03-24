import CookedHTML
import UIKit

enum TableRenderer: BlockRenderer {
    static func canRender(_ block: ContentBlock) -> Bool {
        if case .table = block { return true }
        return false
    }

    static func render(_ block: ContentBlock, config: NativeRenderConfig, delegate: PostCellDelegate?) -> UIView {
        guard case .table(let headers, let rows) = block else { return UIView() }

        let columnCount = max(
            headers.count,
            rows.map(\.count).max() ?? 0
        )
        guard columnCount > 0 else { return UIView() }

        let cellPaddingV: CGFloat = 8
        let cellPaddingH: CGFloat = 12
        let separatorColor = UIColor.separator

        // MARK: - Measure natural column widths

        func makeAttrString(for inlines: [InlineNode], bold: Bool) -> NSAttributedString {
            if bold {
                let boldConfig = AttributedStringConfig(
                    baseFont: config.baseFont.withTraits(.traitBold),
                    baseColor: config.baseColor,
                    linkColor: config.linkColor,
                    codeFont: config.codeFont,
                    codeBackgroundColor: config.codeBackgroundColor
                )
                return inlines.attributedString(config: boldConfig)
            } else {
                return inlines.attributedString(config: config.attributedStringConfig)
            }
        }

        // Build attributed strings and measure natural widths per column
        var attrGrid: [[NSAttributedString]] = []
        var boldGrid: [[Bool]] = []
        var columnMaxWidths: [CGFloat] = Array(repeating: 0, count: columnCount)

        func appendRow(cells: [[InlineNode]], bold: Bool) {
            var attrRow: [NSAttributedString] = []
            var boldRow: [Bool] = []
            for col in 0..<columnCount {
                let inlines = col < cells.count ? cells[col] : []
                let attr = makeAttrString(for: inlines, bold: bold)
                let textWidth = ceil(attr.boundingRect(
                    with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    context: nil
                ).width)
                let naturalWidth = textWidth + cellPaddingH * 2
                columnMaxWidths[col] = max(columnMaxWidths[col], naturalWidth)
                attrRow.append(attr)
                boldRow.append(bold)
            }
            attrGrid.append(attrRow)
            boldGrid.append(boldRow)
        }

        if !headers.isEmpty {
            appendRow(cells: headers, bold: true)
        }
        for row in rows {
            appendRow(cells: row, bold: false)
        }

        // MARK: - Water-filling column width allocation

        let availableWidth = max(config.contentWidth, CGFloat(columnCount) * 40)
        var columnWidths = Array(repeating: CGFloat(0), count: columnCount)
        var flexibleCols = Set(0..<columnCount)
        var remainingWidth = availableWidth

        var changed = true
        while changed {
            changed = false
            guard !flexibleCols.isEmpty else { break }
            let fairShare = remainingWidth / CGFloat(flexibleCols.count)
            for col in flexibleCols {
                if columnMaxWidths[col] <= fairShare {
                    columnWidths[col] = columnMaxWidths[col]
                    remainingWidth -= columnMaxWidths[col]
                    flexibleCols.remove(col)
                    changed = true
                }
            }
        }

        if !flexibleCols.isEmpty {
            let flexTotal = flexibleCols.map({ columnMaxWidths[$0] }).reduce(0, +)
            for col in flexibleCols {
                if flexTotal > 0 {
                    columnWidths[col] = remainingWidth * (columnMaxWidths[col] / flexTotal)
                } else {
                    columnWidths[col] = remainingWidth / CGFloat(flexibleCols.count)
                }
            }
        }

        // Convert to multipliers; last column has no multiplier — it fills remaining space.
        let totalAssigned = columnWidths.reduce(0, +)
        let ratios: [CGFloat] = columnWidths.map {
            totalAssigned > 0 ? $0 / totalAssigned : 1 / CGFloat(columnCount)
        }

        // MARK: - Cell factory

        func makeCell(attr: NSAttributedString) -> UIView {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false

            let textView = LinkTextView()
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            textView.backgroundColor = .clear
            textView.dataDetectorTypes = []
            textView.linkTextAttributes = [.foregroundColor: config.linkColor]
            textView.attributedText = attr
            textView.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(textView)
            NSLayoutConstraint.activate([
                textView.topAnchor.constraint(equalTo: container.topAnchor, constant: cellPaddingV),
                textView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: cellPaddingH),
                textView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -cellPaddingH),
                textView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -cellPaddingV),
            ])

            return container
        }

        func makeSeparator() -> UIView {
            let sep = UIView()
            sep.translatesAutoresizingMaskIntoConstraints = false
            sep.backgroundColor = separatorColor
            sep.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
            return sep
        }

        // MARK: - Assemble table

        let tableStack = UIStackView()
        tableStack.axis = .vertical
        tableStack.spacing = 0
        tableStack.translatesAutoresizingMaskIntoConstraints = false

        for (rowIndex, attrRow) in attrGrid.enumerated() {
            let cells = attrRow.map { makeCell(attr: $0) }

            // Use plain UIView instead of UIStackView to avoid constraint conflicts
            let rowView = UIView()
            rowView.translatesAutoresizingMaskIntoConstraints = false

            for (col, cell) in cells.enumerated() {
                rowView.addSubview(cell)

                cell.topAnchor.constraint(equalTo: rowView.topAnchor).isActive = true
                cell.bottomAnchor.constraint(equalTo: rowView.bottomAnchor).isActive = true

                if col == 0 {
                    cell.leadingAnchor.constraint(equalTo: rowView.leadingAnchor).isActive = true
                } else {
                    cell.leadingAnchor.constraint(equalTo: cells[col - 1].trailingAnchor).isActive = true
                }

                if col < columnCount - 1 {
                    // Fixed ratio for all columns except the last
                    cell.widthAnchor.constraint(equalTo: rowView.widthAnchor, multiplier: ratios[col]).isActive = true
                } else {
                    // Last column fills remaining space — no floating-point sum mismatch
                    cell.trailingAnchor.constraint(equalTo: rowView.trailingAnchor).isActive = true
                }
            }

            if rowIndex == 0 && !headers.isEmpty {
                rowView.backgroundColor = .secondarySystemBackground
            }

            tableStack.addArrangedSubview(rowView)

            if rowIndex < attrGrid.count - 1 {
                tableStack.addArrangedSubview(makeSeparator())
            }
        }

        // MARK: - Bordered container

        let borderedContainer = UIView()
        borderedContainer.translatesAutoresizingMaskIntoConstraints = false
        borderedContainer.layer.borderWidth = 1 / UIScreen.main.scale
        borderedContainer.layer.borderColor = separatorColor.cgColor
        borderedContainer.layer.cornerRadius = 4
        borderedContainer.clipsToBounds = true

        borderedContainer.addSubview(tableStack)
        NSLayoutConstraint.activate([
            tableStack.topAnchor.constraint(equalTo: borderedContainer.topAnchor),
            tableStack.leadingAnchor.constraint(equalTo: borderedContainer.leadingAnchor),
            tableStack.trailingAnchor.constraint(equalTo: borderedContainer.trailingAnchor),
            tableStack.bottomAnchor.constraint(equalTo: borderedContainer.bottomAnchor),
        ])

        return borderedContainer
    }
}

// MARK: - UIFont + Traits Helper

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(traits)) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
