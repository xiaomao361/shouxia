import Foundation

struct PickupSharedTextParser: Sendable {
    static let maximumBytes = 64 * 1024

    func candidates(from input: String) throws -> [ImagePickupCandidate] {
        guard input.utf8.count <= Self.maximumBytes else { throw SharedTextError.tooLong }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw SharedTextError.noCode }
        let blocks = PickupRecognitionCore().notifications(in: text, allowBareCode: true)
        let unresolved = blocks.filter(\.unresolved).count
        let candidates = blocks.flatMap { block in
            block.codes.map { code in
                ImagePickupCandidate(code: code.value, location: safeLocation(block.location),
                                     platform: block.roles.displayName, confidence: 1,
                                     isLabelled: code.explicit, unresolvedNotificationCount: unresolved,
                                     reviewIssue: code.reviewIssue, alternativeGroup: code.alternativeGroup,
                                     locationRequiresConfirmation: block.locationRequiresConfirmation)
            }
        }
        guard !candidates.isEmpty else { throw SharedTextError.noCode }
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
