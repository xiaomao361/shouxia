import Foundation

struct PickupSharedTextParser: Sendable {
    static let maximumBytes = 64 * 1024

    func candidates(from input: String) throws -> [ImagePickupCandidate] {
        guard input.utf8.count <= Self.maximumBytes else { throw SharedTextError.tooLong }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw SharedTextError.noCode }
        let parser = PickupParser()
        let lines = text.components(separatedBy: .newlines)
            .filter { !parser.extractLabelledCodes(from: $0).isEmpty }
        let parsed: [ParsedPickup]
        if lines.count > 1 {
            // Independent notifications retain their own place. Do not assign the
            // first place in an entire shared note to every code in that note.
            parsed = try lines.flatMap { try parser.parseAll($0, requiresLabel: true) }
        } else if !lines.isEmpty {
            parsed = try parser.parseAll(text, requiresLabel: true)
        } else {
            // Explicitly shared standalone codes are useful; unrelated text containing
            // an incidental number is not a pickup notification.
            let item = PickupImageShareBatch.Item(code: text.uppercased(), location: nil,
                                                platform: nil, source: .sharedText)
            guard item.code.contains(where: \.isNumber),
                  (try? PickupImageShareBatch(items: [item]).validated()) != nil else {
                throw SharedTextError.noCode
            }
            let identity = try parser.parse("取件码 \(item.code)")
            parsed = [ParsedPickup(rawText: text, code: item.code, location: nil,
                                   platform: nil, fingerprint: identity.fingerprint)]
        }
        let candidates = parsed.map { pickup in
            ImagePickupCandidate(code: pickup.code,
                                 location: safeLocation(pickup.location), platform: pickup.platform,
                                 confidence: 1, isLabelled: !lines.isEmpty)
        }
        let merged = ImagePickupBatchMerger().merge([candidates])
        // Use the same limits as persisted image candidates, before offering save.
        _ = try PickupImageShareBatch(items: merged.map {
            .init(code: $0.code, location: $0.location, platform: $0.platform, source: .sharedText)
        }).validated()
        return merged
    }

    private func safeLocation(_ location: String?) -> String? {
        guard let location, location.count <= 80,
              location.rangeOfCharacter(from: .controlCharacters) == nil,
              location.range(of: #"\d{10,}"#, options: .regularExpression) == nil,
              !["手机", "电话", "快递员"].contains(where: location.contains) else { return nil }
        return location
    }

    enum SharedTextError: LocalizedError {
        case tooLong, noCode
        var errorDescription: String? {
            switch self {
            case .tooLong: "分享的文字太长，请只选择取件通知再试"
            case .noCode: "没有找到取件码，请分享完整取件通知或单独的取件码"
            }
        }
    }
}
