import Foundation

enum PickupShareText {
    /// Keep every selected record; matching codes alone do not mean the same package.
    static func make(records: [PickupRecord]) -> String {
        guard !records.isEmpty else { return "" }

        var groups: [(key: String?, title: String, records: [PickupRecord])] = []
        for record in records {
            let key = record.normalizedLocation
            if let index = groups.firstIndex(where: { $0.key == key }) {
                groups[index].records.append(record)
            } else {
                groups.append((
                    key: key,
                    title: key == nil ? "地点待确认" : singleLine(record.location ?? ""),
                    records: [record]
                ))
            }
        }

        let sections = groups.map { group in
            let codes = group.records.map { record in
                var line = "取件码：\(record.code)"
                if let platform = record.platform.map(singleLine), !platform.isEmpty {
                    line += "（\(platform)）"
                }
                if record.locationSource == .commonDefault, record.normalizedLocation != nil {
                    line += " · 常用取件点，请确认"
                }
                return line
            }
            return ([group.title] + codes).joined(separator: "\n")
        }
        return (["帮忙取这 \(records.count) 件快递："] + sections).joined(separator: "\n\n")
    }

    private static func singleLine(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
