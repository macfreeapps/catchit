import Foundation

struct RecognizedLine: Equatable, Sendable {
    let text: String
    let bounds: CGRect

    init(text: String, bounds: CGRect) {
        self.text = text
        self.bounds = bounds
    }
}

enum TextPostProcessor {
    private struct Row {
        var lines: [RecognizedLine]
        var bounds: CGRect {
            lines.reduce(.null) { $0.union($1.bounds) }
        }
        var centerY: CGFloat { bounds.midY }
    }

    private struct Gap {
        let location: CGFloat
        let size: CGFloat
    }

    private struct ColumnBoundary {
        let boundary: CGFloat
    }

    static func format(_ input: [RecognizedLine], keepLineBreaks: Bool) -> String {
        let lines = input.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !lines.isEmpty else { return "" }

        let typicalHeight = median(lines.map { max($0.bounds.height, 0.001) })
        let rows = makeRows(lines, typicalHeight: typicalHeight)
        let columns = detectColumns(in: rows, typicalHeight: typicalHeight)
        let orderedRows: [[Row]]

        if let columns {
            let left = rows.compactMap { row -> Row? in
                let lines = row.lines.filter { $0.bounds.midX < columns.boundary }
                return lines.isEmpty ? nil : Row(lines: lines)
            }
                .sorted { $0.centerY > $1.centerY }
            let right = rows.compactMap { row -> Row? in
                let lines = row.lines.filter { $0.bounds.midX >= columns.boundary }
                return lines.isEmpty ? nil : Row(lines: lines)
            }
                .sorted { $0.centerY > $1.centerY }
            orderedRows = [left, right].filter { !$0.isEmpty }
        } else {
            orderedRows = [rows.sorted { $0.centerY > $1.centerY }]
        }

        let paragraphs = orderedRows.flatMap { rowsInColumn in
            makeParagraphs(from: rowsInColumn, typicalHeight: typicalHeight)
        }

        return paragraphs.map { paragraph in
            let orderedLines = paragraph.flatMap { row in
                row.lines.sorted { $0.bounds.minX < $1.bounds.minX }.map(\.text)
            }
            if keepLineBreaks {
                return orderedLines.joined(separator: "\n")
            }
            return joinLines(orderedLines)
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    private static func makeRows(_ lines: [RecognizedLine], typicalHeight: CGFloat) -> [Row] {
        let sorted = lines.sorted {
            if $0.bounds.midY != $1.bounds.midY {
                return $0.bounds.midY > $1.bounds.midY
            }
            return $0.bounds.minX < $1.bounds.minX
        }

        var rows: [Row] = []
        for line in sorted {
            if let rowIndex = rows.indices.min(by: { abs(rows[$0].centerY - line.bounds.midY) < abs(rows[$1].centerY - line.bounds.midY) }),
               abs(rows[rowIndex].centerY - line.bounds.midY) <= typicalHeight * 0.55 {
                rows[rowIndex].lines.append(line)
            } else {
                rows.append(Row(lines: [line]))
            }
        }

        return rows.map { row in
            Row(lines: row.lines.sorted { $0.bounds.minX < $1.bounds.minX })
        }
    }

    private static func detectColumns(in rows: [Row], typicalHeight: CGFloat) -> ColumnBoundary? {
        let gaps = rows.flatMap { row -> [Gap] in
            guard row.lines.count > 1 else { return [] }
            return zip(row.lines, row.lines.dropFirst()).compactMap { left, right in
                let size = right.bounds.minX - left.bounds.maxX
                guard size > max(0.07, typicalHeight * 1.8) else { return nil }
                return Gap(location: (left.bounds.maxX + right.bounds.minX) / 2, size: size)
            }
        }
        guard let largest = gaps.max(by: { $0.size < $1.size }),
              gaps.filter({ abs($0.location - largest.location) < 0.07 }).count >= 2 else {
            return nil
        }
        return ColumnBoundary(boundary: largest.location)
    }

    private static func makeParagraphs(from rows: [Row], typicalHeight: CGFloat) -> [[Row]] {
        guard let first = rows.first else { return [] }
        var paragraphs: [[Row]] = [[first]]

        for row in rows.dropFirst() {
            guard let previous = paragraphs[paragraphs.count - 1].last else { continue }
            let verticalGap = previous.bounds.minY - row.bounds.maxY
            if verticalGap > typicalHeight * 0.85 {
                paragraphs.append([row])
            } else {
                paragraphs[paragraphs.count - 1].append(row)
            }
        }
        return paragraphs
    }

    private static func joinLines(_ lines: [String]) -> String {
        var result = ""
        for rawLine in lines {
            let line = rawLine.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !line.isEmpty else { continue }
            guard !result.isEmpty else {
                result = line
                continue
            }

            if shouldJoinHyphenatedWord(previous: result, next: line) {
                result.removeLast()
                result += line
            } else {
                result += " " + line
            }
        }
        return result
    }

    private static func shouldJoinHyphenatedWord(previous: String, next: String) -> Bool {
        guard previous.last == "-",
              let preceding = previous.dropLast().last,
              preceding.isLetter || preceding.isNumber,
              let leading = next.first,
              leading.isLowercase else {
            return false
        }
        return true
    }

    private static func median(_ values: [CGFloat]) -> CGFloat {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0.01 }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
