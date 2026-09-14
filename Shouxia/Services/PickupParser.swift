import CryptoKit
import Foundation

struct PickupParser: Sendable {
    func parse(_ input: String) throws -> ParsedPickup {
        try parseAll(input)[0]
    }

    func parseAutomaticClipboard(_ input: String) throws -> ParsedPickup {
        try parseAll(input, requiresLabel: true)[0]
    }

    /// A labelled list belongs to one notification; unrelated numbers are not a list.
    func parseAll(_ input: String, requiresLabel: Bool = false) throws -> [ParsedPickup] {
        let rawText = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else { throw PickupImportError.emptyText }
        var codes = extractLabelledCodes(from: rawText)
        if codes.isEmpty, !requiresLabel, let fallback = extractFallbackCode(from: rawText) {
            codes = [fallback]
        }
        guard !codes.isEmpty else { throw PickupImportError.missingCode }
        return codes.enumerated().map { index, code in
            let parsed = parsedPickup(rawText: rawText, code: code)
            // Keep the first code's legacy fingerprint so existing imports and
            // deletion suppressions still match. Other codes need their own identity.
            return ParsedPickup(
                rawText: parsed.rawText,
                code: parsed.code,
                location: parsed.location,
                platform: parsed.platform,
                fingerprint: index == 0 ? parsed.fingerprint
                    : fingerprint(for: rawText + "\n取件码:" + parsed.code)
            )
        }
    }

    private func parsedPickup(rawText: String, code: String) -> ParsedPickup {
        return ParsedPickup(
            rawText: rawText,
            code: code.uppercased(),
            location: extractLocation(from: rawText),
            platform: detectPlatform(in: rawText),
            fingerprint: fingerprint(for: rawText)
        )
    }

    func extractLabelledCodes(from text: String) -> [String] {
        let code = #"[A-Za-z0-9]+(?:-[A-Za-z0-9]+){0,4}"#
        // Bare continuation numbers are limited to pickup-code lengths, excluding
        // phone/tracking numbers and address fragments after the list.
        let continuation = #"(?:[A-Za-z0-9]+(?:-[A-Za-z0-9]+){1,4}|[A-Za-z]*[0-9]{4,8})(?![A-Za-z0-9-])"#
        let pattern = #"(?:取件码|提货码|取货码|领取码|取件编号|凭码)[\s：:为是]*("#
            + code + #"(?:[ \t]*[、，,][ \t]*"# + continuation + #")*)"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        var seen: Set<String> = []
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).flatMap { match -> [String] in
            guard let range = Range(match.range(at: 1), in: text) else { return [] }
            return text[range].components(separatedBy: CharacterSet(charactersIn: "、，,"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                .filter { seen.insert($0).inserted }
        }
    }

    private func extractFallbackCode(from text: String) -> String? {
        let fallbackPatterns = [
            #"(?<![A-Za-z0-9])([A-Za-z]?\d{1,4}(?:-[A-Za-z0-9]{1,8}){1,3})(?![A-Za-z0-9])"#,
            #"(?<!\d)(\d{4,8})(?!\d)"#,
        ]

        for pattern in fallbackPatterns {
            if let match = firstCapture(pattern: pattern, in: text) {
                return match
            }
        }

        return nil
    }

    private func extractLocation(from text: String) -> String? {
        let arrivalPatterns = [
            #"(?:包裹|快件|快递)(?:已)?在[\s]*([^，。；;\n]{2,80}?(?:妈妈驿站|菜鸟驿站|快递超市|快递柜|丰巢柜|代收点|服务站))"#,
            #"(?:取件码|提货码|取货码|领取码|取件编号)[\s：:为是]*[A-Za-z0-9]+(?:-[A-Za-z0-9]+){0,4}\s*(?:至|到|前往)\s*([^，。；;\n]{2,40}?)(?:取件|领取|$)"#,
            #"(?:已到达|已到|送达|送至|存放在|存放于|已存入|请到|领取地点[：:]?)[\s]*([^，。；;\n]{2,32})"#,
            #"([^，。；;\n]{2,28}(?:菜鸟驿站|快递超市|快递柜|丰巢柜|代收点|服务站))"#,
        ]

        for pattern in arrivalPatterns {
            guard let match = firstCapture(pattern: pattern, in: text) else { continue }
            let cleaned = match
                .replacingOccurrences(of: #"(?:，|。)?(?:取件码|提货码|取货码|领取码).*$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            if !cleaned.isEmpty {
                return cleaned
            }
        }

        return nil
    }

    private func detectPlatform(in text: String) -> String? {
        let platforms = [
            "菜鸟", "丰巢", "京东", "淘宝", "天猫", "拼多多",
            "顺丰", "邮政", "中通", "圆通", "申通", "韵达", "极兔", "德邦",
        ]
        return platforms.first(where: text.contains)
    }

    private func fingerprint(for text: String) -> String {
        let normalized = text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func firstCapture(pattern: String, in text: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let result = expression.firstMatch(in: text, range: fullRange),
              result.numberOfRanges > 1,
              let range = Range(result.range(at: 1), in: text)
        else {
            return nil
        }

        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
