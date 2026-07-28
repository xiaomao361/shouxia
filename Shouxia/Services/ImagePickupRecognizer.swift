import Foundation
import UIKit
import Vision

struct RecognizedTextLine: Equatable, Sendable {
    let text: String
    let confidence: Float
    let minX: Double
    let midY: Double
}

struct ImagePickupCandidate: Equatable, Hashable, Identifiable, Sendable {
    let code: String
    let location: String?
    let platform: String?
    let confidence: Float
    let isLabelled: Bool

    var id: String {
        [code, location ?? "", platform ?? ""].joined(separator: "|")
    }

    var sanitizedImportText: String {
        var parts: [String] = []
        if let platform {
            parts.append("【\(platform)】")
        }
        if let location {
            parts.append("已到\(location)")
        }
        parts.append("取件码 \(code)")
        return parts.joined(separator: "，")
    }

    var isHighConfidence: Bool {
        isLabelled && confidence >= 0.35
    }
}

enum ImagePickupRecognitionError: LocalizedError, Equatable {
    case unreadableImage
    case noText
    case noPickupCode

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "这张图片暂时无法读取，请换一张再试"
        case .noText:
            "图片里没有识别到文字"
        case .noPickupCode:
            "没有找到明确的取件码，请换一张更清晰的图片"
        }
    }
}

struct ImageTextRecognizer: Sendable {
    func recognize(in imageData: Data) async throws -> [RecognizedTextLine] {
        try await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: imageData),
                  let cgImage = image.cgImage
            else {
                throw ImagePickupRecognitionError.unreadableImage
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: CGImagePropertyOrientation(image.imageOrientation)
            )
            try handler.perform([request])

            let lines = (request.results ?? [])
                .compactMap { observation -> RecognizedTextLine? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }
                    return RecognizedTextLine(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        minX: observation.boundingBox.minX,
                        midY: observation.boundingBox.midY
                    )
                }
                .sorted { left, right in
                    if abs(left.midY - right.midY) > 0.018 {
                        return left.midY > right.midY
                    }
                    return left.minX < right.minX
                }

            guard !lines.isEmpty else {
                throw ImagePickupRecognitionError.noText
            }
            return lines
        }.value
    }
}

struct ImagePickupExtractor: Sendable {
    func candidates(from lines: [RecognizedTextLine]) throws -> [ImagePickupCandidate] {
        let normalizedLines = lines.map {
            RecognizedTextLine(
                text: normalizePunctuation(in: $0.text),
                confidence: $0.confidence,
                minX: $0.minX,
                midY: $0.midY
            )
        }
        let platform = detectPlatform(in: normalizedLines)
        var labelled: [ImagePickupCandidate] = []

        for (index, line) in normalizedLines.enumerated() {
            let matches = captures(
                pattern: #"(?:取件码|提货码|取货码|领取码|取件编号)\s*[:：为是]?\s*([A-Za-z0-9]+(?:\s*-\s*[A-Za-z0-9]+){0,4})"#,
                in: line.text
            )
            for match in matches {
                guard let code = normalizedCode(match) else { continue }
                labelled.append(
                    makeCandidate(
                        code: code,
                        lineIndex: index,
                        confidence: line.confidence,
                        isLabelled: true,
                        lines: normalizedLines,
                        platform: platform
                    )
                )
            }

            guard containsPickupLabel(line.text), matches.isEmpty else { continue }
            for neighborIndex in neighboringIndices(after: index, count: normalizedLines.count) {
                guard let code = firstLikelyCode(in: normalizedLines[neighborIndex].text) else {
                    continue
                }
                labelled.append(
                    makeCandidate(
                        code: code,
                        lineIndex: index,
                        confidence: min(line.confidence, normalizedLines[neighborIndex].confidence),
                        isLabelled: true,
                        lines: normalizedLines,
                        platform: platform
                    )
                )
                break
            }
        }

        let labelledResults = deduplicated(labelled)
        if !labelledResults.isEmpty {
            return labelledResults
        }

        var fallback: [ImagePickupCandidate] = []
        for (index, line) in normalizedLines.enumerated() {
            guard !containsExcludedNumberContext(line.text) else { continue }
            for match in captures(
                pattern: #"(?<![A-Za-z0-9])([A-Za-z]?\d{1,4}(?:\s*-\s*[A-Za-z0-9]{1,8}){1,4})(?![A-Za-z0-9])"#,
                in: line.text
            ) {
                guard let code = normalizedCode(match) else { continue }
                fallback.append(
                    makeCandidate(
                        code: code,
                        lineIndex: index,
                        confidence: line.confidence,
                        isLabelled: false,
                        lines: normalizedLines,
                        platform: platform
                    )
                )
            }
        }

        let fallbackResults = deduplicated(fallback)
        guard !fallbackResults.isEmpty else {
            throw ImagePickupRecognitionError.noPickupCode
        }
        return fallbackResults
    }

    private func makeCandidate(
        code: String,
        lineIndex: Int,
        confidence: Float,
        isLabelled: Bool,
        lines: [RecognizedTextLine],
        platform: String?
    ) -> ImagePickupCandidate {
        ImagePickupCandidate(
            code: code,
            location: extractLocation(near: lineIndex, from: lines),
            platform: platform,
            confidence: confidence,
            isLabelled: isLabelled
        )
    }

    private func extractLocation(
        near codeLineIndex: Int,
        from lines: [RecognizedTextLine]
    ) -> String? {
        guard !lines.isEmpty else { return nil }
        let lowerBound = max(0, codeLineIndex - 9)
        let upperBound = min(lines.count - 1, codeLineIndex + 2)
        let keywords = ["驿站", "快递柜", "代收点", "快递超市", "服务站", "号楼店"]

        let ranked = (lowerBound...upperBound).compactMap { index -> (String, Int)? in
            let cleaned = cleanLocation(lines[index].text)
            guard cleaned.count >= 4,
                  cleaned.count <= 42,
                  !containsPickupLabel(cleaned),
                  !containsPrivateContact(cleaned),
                  keywords.contains(where: cleaned.contains)
            else {
                return nil
            }

            var score = keywords.reduce(0) { result, keyword in
                result + (cleaned.contains(keyword) ? 4 : 0)
            }
            score -= abs(codeLineIndex - index)
            if cleaned == "已放至代收点" || cleaned == "联系驿站" {
                score -= 20
            }
            if cleaned.contains("地址") {
                score += 2
            }
            return (cleaned, score)
        }

        return ranked.max(by: { $0.1 < $1.1 })?.0
    }

    private func cleanLocation(_ text: String) -> String {
        text
            .replacingOccurrences(
                of: #"^(?:取件地址|领取地点|地址)\s*[:：]?\s*"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private func detectPlatform(in lines: [RecognizedTextLine]) -> String? {
        let text = lines.map(\.text).joined(separator: "\n")
        let platforms = [
            "菜鸟", "丰巢", "京东", "淘宝", "天猫", "拼多多",
            "顺丰", "邮政", "中通", "圆通", "申通", "韵达", "极兔", "德邦",
        ]
        return platforms.first(where: text.contains)
    }

    private func containsPickupLabel(_ text: String) -> Bool {
        text.range(
            of: #"(?:取件码|提货码|取货码|领取码|取件编号)"#,
            options: .regularExpression
        ) != nil
    }

    private func containsExcludedNumberContext(_ text: String) -> Bool {
        ["运单", "物流", "电话", "手机", "距离", "时间", "单元", "地址"]
            .contains(where: text.contains)
    }

    private func containsPrivateContact(_ text: String) -> Bool {
        if ["快递员", "电话", "手机"].contains(where: text.contains) {
            return true
        }
        return text.range(of: #"\d{10,}"#, options: .regularExpression) != nil
    }

    private func neighboringIndices(after index: Int, count: Int) -> [Int] {
        guard index + 1 < count else { return [] }
        return Array((index + 1)...min(index + 3, count - 1))
    }

    private func firstLikelyCode(in text: String) -> String? {
        let patterns = [
            #"(?<![A-Za-z0-9])([A-Za-z]?\d{1,4}(?:\s*-\s*[A-Za-z0-9]{1,8}){1,4})(?![A-Za-z0-9])"#,
            #"(?<!\d)(\d{4,8})(?!\d)"#,
        ]
        for pattern in patterns {
            for match in captures(pattern: pattern, in: text) {
                if let code = normalizedCode(match) {
                    return code
                }
            }
        }
        return nil
    }

    private func normalizedCode(_ value: String) -> String? {
        let code = value
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            .uppercased()
        guard code.count >= 4, code.count <= 24 else { return nil }
        if code.allSatisfy(\.isNumber), code.count > 8 {
            return nil
        }
        return code
    }

    private func normalizePunctuation(in text: String) -> String {
        text
            .replacingOccurrences(of: "[‐‑‒–—﹣－]", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "：", with: ":")
    }

    private func captures(pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap { result in
            guard result.numberOfRanges > 1,
                  let captureRange = Range(result.range(at: 1), in: text)
            else {
                return nil
            }
            return String(text[captureRange])
        }
    }

    private func deduplicated(
        _ candidates: [ImagePickupCandidate]
    ) -> [ImagePickupCandidate] {
        var seen: Set<String> = []
        return candidates.filter { seen.insert($0.code).inserted }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
