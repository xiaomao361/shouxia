import CryptoKit
import Foundation

struct PickupParser: Sendable {
    func parse(_ input: String) throws -> ParsedPickup {
        let rawText = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else {
            throw PickupImportError.emptyText
        }

        guard let code = extractCode(from: rawText) else {
            throw PickupImportError.missingCode
        }

        return ParsedPickup(
            rawText: rawText,
            code: code.uppercased(),
            location: extractLocation(from: rawText),
            platform: detectPlatform(in: rawText),
            fingerprint: fingerprint(for: rawText)
        )
    }

    private func extractCode(from text: String) -> String? {
        let labelledPatterns = [
            #"(?:取件码|提货码|取货码|领取码|取件编号)[\s：:为是]*([A-Za-z0-9]+(?:-[A-Za-z0-9]+){0,4})"#,
            #"(?:凭码|凭取件码)[\s：:为是]*([A-Za-z0-9]+(?:-[A-Za-z0-9]+){0,4})"#,
        ]

        for pattern in labelledPatterns {
            if let match = firstCapture(pattern: pattern, in: text) {
                return match
            }
        }

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
            #"(?:已到达|已到|送达|送至|存放在|存放于|已存入|请到|领取地点[：:]?)[\s]*([^，。；;\n]{2,32})"#,
            #"([^，。；;\n]{2,28}(?:菜鸟驿站|快递超市|快递柜|代收点|服务站|丰巢))"#,
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
        let platforms = ["菜鸟", "丰巢", "京东", "淘宝", "天猫", "拼多多", "顺丰", "邮政"]
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
