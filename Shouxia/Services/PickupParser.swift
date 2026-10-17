import CryptoKit
import Foundation

struct PickupParser: Sendable {
    func parse(_ input: String) throws -> ParsedPickup { try parseAll(input)[0] }

    func parseAutomaticClipboard(_ input: String) throws -> ParsedPickup {
        try parseAll(input, requiresLabel: true)[0]
    }

    /// requiresLabel disallows bare codes. Explicit pickup instructions are accepted too.
    func parseAll(_ input: String, requiresLabel: Bool = false) throws -> [ParsedPickup] {
        let rawText = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else { throw PickupImportError.emptyText }
        guard rawText.utf8.count <= 64 * 1024 else { throw PickupImportError.tooLong }
        let blocks = PickupRecognitionCore().notifications(in: rawText, allowBareCode: !requiresLabel)
        let unresolvedCount = blocks.filter { $0.unresolved || $0.codes.contains { $0.reviewIssue != nil } }.count
        var results: [ParsedPickup] = []
        for block in blocks {
            for (index, code) in block.codes.enumerated() where code.reviewIssue == nil {
                let identityText = blocks.count == 1 ? rawText : block.text
                results.append(ParsedPickup(
                    rawText: blocks.count == 1 ? rawText : block.text, code: code.value, location: block.location,
                    platform: block.roles.displayName,
                    fingerprint: fingerprint(for: index == 0 ? identityText
                        : identityText + "\n取件码:" + code.value),
                    unresolvedNotificationCount: unresolvedCount,
                    locationRequiresConfirmation: block.locationRequiresConfirmation
                ))
            }
        }
        guard !results.isEmpty else {
            if blocks.contains(where: { $0.codes.contains { $0.reviewIssue != nil } }) { throw PickupImportError.ambiguousCode }
            throw PickupImportError.missingCode
        }
        return results
    }

    func extractLabelledCodes(from text: String) -> [String] {
        PickupRecognitionCore().notifications(in: text).flatMap(\.codes)
            .filter { $0.explicit && $0.reviewIssue == nil }.map(\.value)
    }

    func fingerprint(for text: String) -> String {
        let normalized = text.lowercased().components(separatedBy: .whitespacesAndNewlines).joined()
        return SHA256.hash(data: Data(normalized.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
