import Foundation
import UIKit
import Vision

struct RecognizedTextLine: Equatable, Sendable {
    let text: String
    let confidence: Float
    let minX: Double
    let midY: Double
    var width: Double = 0
    var height: Double = 0
}

struct ImagePickupCandidate: Equatable, Hashable, Identifiable, Sendable {
    let code: String
    let location: String?
    let platform: String?
    let confidence: Float
    let isLabelled: Bool
    var unresolvedNotificationCount = 0
    var reviewIssue: PickupReviewIssue? = nil
    var alternativeGroup: String? = nil
    var userConfirmed = false
    var locationRequiresConfirmation = false

    var id: String {
        PickupIdentity.key(code: code, location: location, platform: platform)
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

    // Review is an opt-out batch workflow. OCR confidence and missing location
    // remain visible hints, not reasons to make the user select every parcel.
    var shouldSelectByDefault: Bool {
        reviewIssue == nil && !locationRequiresConfirmation
            && (alternativeGroup == nil || userConfirmed)
    }

    var confirmationHint: String? {
        if locationRequiresConfirmation { return "取件地点有歧义，请先点“更正”核对" }
        if let reviewIssue { return reviewIssue.message }
        if confidence < 0.8 { return "文字可能不清晰，请核对取件码" }
        if !isLabelled { return "请核对取件码" }
        if location == nil { return "请补充或确认取件地点" }
        return nil
    }

    var isHighConfidence: Bool {
        !locationRequiresConfirmation && reviewIssue == nil && isLabelled && confidence >= 0.8 && location != nil
    }
}

/// One review model for the app and share extension. IDs survive edits; source does too.
struct PickupCandidateReview: Sendable {
    struct Item: Identifiable, Equatable, Sendable {
        let id: UUID
        var candidate: ImagePickupCandidate
        let source: PickupSource
        var selected: Bool
    }
    private(set) var items: [Item]

    init(candidates: [ImagePickupCandidate] = [], sources: [String: PickupSource] = [:]) {
        items = candidates.map {
            Item(id: UUID(), candidate: $0, source: sources[$0.id] ?? .imageRecognition,
                 selected: $0.shouldSelectByDefault)
        }
    }

    var selectedCount: Int { items.filter(\.selected).count }

    mutating func setSelected(_ selected: Bool, id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        // A truncated token isn't a usable code until the user replaces it.
        guard !selected || (items[index].candidate.reviewIssue != .truncated && !items[index].candidate.locationRequiresConfirmation) else { return }
        if selected, let group = items[index].candidate.alternativeGroup {
            for other in items.indices where other != index && items[other].candidate.alternativeGroup == group {
                items[other].selected = false
            }
        }
        items[index].selected = selected
        if selected { items[index].candidate.userConfirmed = true }
    }

    mutating func update(id: UUID, code: String, location: String) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { throw PickupCandidateReviewError.missingItem }
        let normalizedCode = PickupRecognitionCore.normalize(code).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PickupRecognitionCore.validCode(normalizedCode) else { throw PickupCandidateReviewError.invalidCode }
        guard normalizedLocation.count <= 80,
              normalizedLocation.rangeOfCharacter(from: .controlCharacters) == nil,
              !PickupRecognitionCore.matches(#"\d{10,}|电话|手机|快递员"#, in: normalizedLocation) else {
            throw PickupCandidateReviewError.invalidLocation
        }
        let original = items[index].candidate
        let candidate = ImagePickupCandidate(
            code: normalizedCode, location: normalizedLocation.isEmpty ? nil : normalizedLocation,
            platform: original.platform, confidence: original.confidence, isLabelled: original.isLabelled,
            unresolvedNotificationCount: original.unresolvedNotificationCount,
            alternativeGroup: original.alternativeGroup, userConfirmed: true)
        guard !items.contains(where: { $0.id != id && $0.selected && $0.candidate.id == candidate.id }) else {
            throw PickupCandidateReviewError.duplicateSelection
        }
        // Commit only after all validation passes; a rejected edit keeps draft/original separate.
        items[index].candidate = candidate
        setSelected(true, id: id)
    }

    func validatedSelection() throws -> [Item] {
        let selected = items.filter(\.selected)
        try Self.validate(selected.map(\.candidate))
        return selected
    }

    static func validate(_ candidates: [ImagePickupCandidate]) throws {
        if !candidates.isEmpty {
            _ = try PickupImageShareBatch(items: candidates.map {
                .init(code: $0.code, location: $0.location, platform: $0.platform)
            }).validated()
        }
        guard !candidates.contains(where: { $0.locationRequiresConfirmation || $0.reviewIssue == .truncated || ($0.reviewIssue != nil && !$0.userConfirmed) }) else {
            throw PickupCandidateReviewError.confirmationRequired
        }
        guard Set(candidates.map(\.id)).count == candidates.count else {
            throw PickupCandidateReviewError.duplicateSelection
        }
        let groups = candidates.compactMap(\.alternativeGroup)
        guard Set(groups).count == groups.count else { throw PickupCandidateReviewError.alternativeSelection }
    }
}

enum PickupCandidateReviewError: LocalizedError {
    case missingItem, invalidCode, invalidLocation, duplicateSelection, alternativeSelection, confirmationRequired
    var errorDescription: String? {
        switch self {
        case .missingItem: "这条取件信息已不存在，请重新识别"
        case .invalidCode: "请填写完整取件码：4至24个字母、数字或短横线，至少包含一个数字；纯数字为4至8位"
        case .invalidLocation: "地点请控制在80个字符以内，不填写电话或联系人信息"
        case .duplicateSelection: "这条取件信息已在勾选列表中，请保留一条"
        case .alternativeSelection: "备选码只能选择一个，请重新核对"
        case .confirmationRequired: "有取件码需要核对或更正，请先确认再保存"
        }
    }
}

struct ImagePickupBatchMerger: Sendable {
    func merge(_ candidateGroups: [[ImagePickupCandidate]]) -> [ImagePickupCandidate] {
        var orderedIDs: [String] = []
        var bestByIdentity: [String: ImagePickupCandidate] = [:]

        for candidate in candidateGroups.flatMap({ $0 }) {
            if let existing = bestByIdentity[candidate.id] {
                if isBetter(candidate, than: existing) {
                    bestByIdentity[candidate.id] = candidate
                }
            } else {
                orderedIDs.append(candidate.id)
                bestByIdentity[candidate.id] = candidate
            }
        }

        let unresolved = candidateGroups.map { $0.map(\.unresolvedNotificationCount).max() ?? 0 }.reduce(0, +)
        return orderedIDs.compactMap { bestByIdentity[$0] }.map {
            var candidate = $0
            candidate.unresolvedNotificationCount = unresolved
            return candidate
        }
    }

    private func isBetter(
        _ candidate: ImagePickupCandidate,
        than existing: ImagePickupCandidate
    ) -> Bool {
        let candidateScore = score(candidate)
        let existingScore = score(existing)
        return candidateScore > existingScore
    }

    private func score(_ candidate: ImagePickupCandidate) -> Double {
        var result = Double(candidate.confidence)
        if candidate.location != nil { result += 4 }
        if candidate.isLabelled { result += 2 }
        if candidate.platform != nil { result += 1 }
        return result
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
                        midY: observation.boundingBox.midY,
                        width: observation.boundingBox.width,
                        height: observation.boundingBox.height
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
        guard !lines.isEmpty else { throw ImagePickupRecognitionError.noText }
        let core = PickupRecognitionCore()
        // Preserve real spatial gaps as hard boundaries. Zero-height test/legacy rows
        // use semantic boundaries only; a fixed number of neighboring rows isn't evidence.
        var groups: [[RecognizedTextLine]] = [[]]
        for line in lines {
            // A fresh courier/tracking header after a pickup code starts a new card.
            if courierHeader(in: line.text) != nil,
               groups.last?.contains(where: { PickupRecognitionCore.matches(PickupRecognitionCore.label, in: $0.text) }) == true {
                groups.append([])
            }
            if let previous = groups.last?.last,
               line.height > 0, previous.height > 0,
               abs(previous.midY - line.midY) > max(previous.height, line.height) * 3 {
                groups.append([])
            }
            groups[groups.count - 1].append(line)
        }
        var candidates: [ImagePickupCandidate] = []
        var unresolvedCount = 0
        for group in groups {
            let text = addressRows(in: pickupCardRows(in: group)).joined(separator: "\n")
            guard text.utf8.count <= 64 * 1024 else { throw PickupImportError.tooLong }
            let blocks = core.notifications(in: text)
            unresolvedCount += blocks.filter(\.unresolved).count
            for block in blocks {
                let relevantLines = group.filter { block.text.contains(PickupRecognitionCore.normalize($0.text)) }
                let confidence = (relevantLines.isEmpty ? group : relevantLines).map(\.confidence).min() ?? 0
                for code in block.codes {
                    candidates.append(ImagePickupCandidate(
                        code: code.value, location: block.location,
                        platform: block.roles.displayName,
                        confidence: confidence, isLabelled: code.explicit,
                        reviewIssue: code.reviewIssue, alternativeGroup: code.alternativeGroup,
                        locationRequiresConfirmation: block.locationRequiresConfirmation
                    ))
                }
            }
        }
        guard !candidates.isEmpty else { throw ImagePickupRecognitionError.noPickupCode }
        return ImagePickupBatchMerger().merge([candidates]).map {
            var candidate = $0
            candidate.unresolvedNotificationCount = unresolvedCount
            return candidate
        }
    }
    /// Screenshot cards may show an unlabelled shop title and detail above the code.
    /// Require complete local geometry and an address-shaped detail, never a map/store name alone.
    private func pickupCardRows(in lines: [RecognizedTextLine]) -> [RecognizedTextLine] {
        var rows = lines
        for index in lines.indices {
            let row = lines[index]
            // Vision sometimes reads a courier logo as one Latin glyph. A literal courier
            // name plus a tracking number is evidence; a tracking prefix alone is not.
            if let value = courierHeader(in: row.text) {
                rows[index] = replacingText(of: row, with: value)
            }
            guard index >= 2, row.height > 0, row.width > 0,
                  PickupRecognitionCore.matches(PickupRecognitionCore.label, in: row.text) else { continue }
            let detail = lines[index - 1], title = lines[index - 2]
            guard detail.height > 0, detail.width > 0, title.height > 0, title.width > 0,
                  title.midY > detail.midY, detail.midY > row.midY,
                  title.midY - row.midY <= max(row.height, title.height) * 4.5,
                  abs(title.minX - row.minX) <= row.height,
                  abs(detail.minX - title.minX) <= max(title.height, detail.height),
                  PickupRecognitionCore.matches(#"^[\p{Han}A-Za-z0-9（）()·-]{4,60}(?:店|驿站|代收点|快递柜)$"#, in: title.text),
                  PickupRecognitionCore.matches(#"(?:路|街|巷|村|小区|园|区|楼).*[0-9]"#, in: detail.text),
                  !PickupRecognitionCore.matches(#"取件|取货|包裹|收件|收货|旗舰|商品|订单|电话|地址|物流"#, in: title.text + detail.text)
            else { continue }
            rows[index - 2] = replacingText(of: title, with: "取件地点：" + title.text)
        }
        return rows
    }

    private func courierHeader(in text: String) -> String? {
        let names = PickupDirectory.couriers.flatMap(\.aliases).filter { $0.count >= 3 }
            .map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let pattern = #"^[^\p{Han}\d]{0,8}((?:"# + names
            + #")[ \t]+[A-Z]{0,6}[0-9]{8,24})(?:[ \t]*(?:复制|物流电话))*$"#
        return PickupRecognitionCore.capture(pattern, in: text)
    }

    private func replacingText(of line: RecognizedTextLine, with text: String) -> RecognizedTextLine {
        RecognizedTextLine(text: text, confidence: line.confidence, minX: line.minX,
                           midY: line.midY, width: line.width, height: line.height)
    }

    /// A two-column address can contain a shop title followed by its detailed address.
    /// Only join rows in the value column when complete geometry supports the relation.
    private func addressRows(in lines: [RecognizedTextLine]) -> [String] {
        var rows = lines.map(\.text)
        for (index, label) in lines.enumerated() {
            guard ["地址", "取件地址", "领取地点"].contains(label.text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  label.height > 0, label.width > 0 else { continue }
            var values: [Int] = []
            for next in (index + 1)..<lines.count {
                let value = lines[next]
                if PickupRecognitionCore.matches(PickupRecognitionCore.label, in: value.text) { break }
                guard value.height > 0, value.width > 0,
                      value.minX >= label.minX + label.width,
                      abs(label.midY - value.midY) <= max(label.height, value.height) * 3 else { break }
                if let first = values.first,
                   abs(value.minX - lines[first].minX) > label.height { break }
                values.append(next)
            }
            if let detail = values.last {
                rows[index] = "取件地址：" + lines[detail].text
                for value in values { rows[value] = "" }
            }
        }
        return rows
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
