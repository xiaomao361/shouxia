import Foundation

/// Versioned offline vocabulary. A service's owner never implies a parcel's courier.
/// Only literal, observed names are aliases; short Latin codes are not inferred.
enum PickupDirectory {
    struct Entry: Sendable {
        let id: String
        let name: String
        let aliases: [String]
    }
    static let version = 1
    static let couriers: [Entry] = [
        Entry(id: "zto", name: "中通", aliases: ["中通快递", "中通"]),
        Entry(id: "yto", name: "圆通", aliases: ["圆通速递", "圆通快递", "圆通"]),
        Entry(id: "sto", name: "申通", aliases: ["申通快递", "申通"]),
        Entry(id: "yunda", name: "韵达", aliases: ["韵达快递", "韵达"]),
        Entry(id: "sf", name: "顺丰", aliases: ["顺丰速运", "顺丰快递", "顺丰"]),
        Entry(id: "jd", name: "京东", aliases: ["京东物流", "京东快递"]),
        Entry(id: "jtexpress", name: "极兔", aliases: ["极兔速递", "极兔快递", "极兔"]),
        Entry(id: "deppon", name: "德邦", aliases: ["德邦快递", "德邦物流", "德邦"]),
        Entry(id: "post", name: "邮政", aliases: ["中国邮政", "邮政快递", "邮政"]),
        Entry(id: "ems", name: "EMS", aliases: ["EMS"]),
    ]
    static let services: [Entry] = [
        Entry(id: "cainiao", name: "菜鸟", aliases: ["菜鸟驿站", "菜鸟"]),
        Entry(id: "fcbox", name: "丰巢", aliases: ["丰巢智能柜", "丰巢快递柜", "丰巢柜", "丰巢"]),
        Entry(id: "mama", name: "妈妈驿站", aliases: ["妈妈驿站"]),
        Entry(id: "tuxi", name: "兔喜", aliases: ["兔喜生活", "兔喜驿站", "兔喜"]),
        Entry(id: "kuaibao", name: "快宝", aliases: ["快宝驿站", "快宝"]),
    ]

    struct Roles: Equatable, Sendable {
        let courier: String?
        let service: String?
        // Backward-compatible display contract: courier first, otherwise service.
        var displayName: String? { courier ?? service }
    }

    /// `platform` is a historical brand field, not a courier assertion.
    /// Keep stored values/identities stable while making service-only badges explicit.
    static func displayLabel(for brand: String) -> String {
        if let service = services.first(where: { ([ $0.name ] + $0.aliases).contains(brand) }) {
            return "取件服务 · " + service.name
        }
        return brand
    }

    static func roles(in text: String) -> Roles {
        let headerPattern = #"^[\s]*[【\[〖]([^】\]〗]+)[】\]〗]"#
        let header = PickupRecognitionCore.capture(headerPattern, in: text)
        // Names in a station address identify the place, not the courier of this parcel.
        let courierText = text.replacingOccurrences(
            of: #"(?:已到达|已到|包裹到|送至|存放在|领取地点[:：]?|取件地址[:：]?)[^，,。；;\n]+"#,
            with: "", options: .regularExpression)
        func names(_ entries: [Entry], in value: String) -> Set<String> {
            Set(entries.filter { entry in
                entry.aliases.contains { alias in
                    if alias == "EMS" {
                        return value.range(of: #"(?<![A-Za-z0-9])EMS(?![A-Za-z0-9])"#,
                                           options: [.regularExpression, .caseInsensitive]) != nil
                    }
                    return value.contains(alias)
                }
            }.map(\.name))
        }
        let headerCouriers = Set(couriers.filter { entry in
            guard let header else { return false }
            // Exact signatures only: “北门圆通妈妈驿站” is a place/service.
            return ([entry.name] + entry.aliases).contains { $0.caseInsensitiveCompare(header) == .orderedSame }
        }.map(\.name))
        let bodyCouriers = Set(couriers.filter { entry in
            entry.aliases.contains { alias in
                let literal = NSRegularExpression.escapedPattern(for: alias)
                let parcelRole = literal + #"(?:\s*的)?(?:包裹|快件|邮件|己到|已到|[0-9]{4}包裹)"#
                let senderRow = #"(?:^|\n)\s*"# + literal + #"(?:[ \t]+(?:运单号[:：]?)?[A-Z0-9]{6,})?\s*(?:\n|$)"#
                return PickupRecognitionCore.matches(parcelRole, in: text)
                    || PickupRecognitionCore.matches(senderRow, in: courierText)
            }
        }.map(\.name))
        let serviceNames = names(services, in: text)
        let courierNames = headerCouriers.union(bodyCouriers)
        let courier = courierNames.count == 1 ? courierNames.first : nil
        return Roles(courier: courier, service: serviceNames.count == 1 ? serviceNames.first : nil)
    }
}

/// Candidate identity is a tuple, not a concatenation with an ambiguous separator.
/// Missing context is not evidence that two observations describe the same parcel.
enum PickupIdentity {
    static func key(code: String, location: String?, platform: String?) -> String {
        let fields: [String?] = [code.uppercased(), normalized(location), normalized(platform)]
        return fields.map { value in value.map { "\($0.utf8.count):\($0)" } ?? "-:" }.joined()
    }
    static func normalized(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum PickupReviewIssue: String, Equatable, Hashable, Sendable {
    case alternatives, truncated, uncertainNumbers, phoneLike

    var message: String {
        switch self {
        case .alternatives: "存在备选码，请核对后只选择一个"
        case .truncated: "取件码可能被截断，请更正后保存"
        case .uncertainNumbers: "有多个用途不明的数字，请核对取件码后选择"
        case .phoneLike: "取件码格式与电话号码相似，请核对后选择"
        }
    }
}

/// Shared by paste, SMS automation, shared text and OCR. No online service required.
struct PickupRecognitionCore: Sendable {
    enum Exclusion: String, Equatable, Sendable {
        case otherNumberRole, invalidFormat, unreadable, notPickup, superseded
    }
    enum Decision: Equatable, Sendable {
        case accepted, requiresReview(PickupReviewIssue), excluded(Exclusion)
    }
    enum AnalysisIssue: String, Sendable { case missingReplacement }
    struct CodeAnalysis: Sendable {
        let observations: [Code]
        let issues: [AnalysisIssue]
        var candidates: [Code] {
            var seen = Set<String>()
            return observations.filter { $0.exclusion == nil && seen.insert($0.value).inserted }
        }
        var requiresReview: Bool { candidates.contains { $0.reviewIssue != nil } }
        var hasUnresolved: Bool {
            !issues.isEmpty || observations.contains {
                $0.exclusion == .unreadable || ($0.explicit && $0.exclusion == .invalidFormat)
            }
        }
    }
    struct Code: Equatable, Sendable {
        let value: String
        let explicit: Bool
        let rule: String
        /// UTF-16 range in this normalized notification, never an original-image coordinate.
        let range: NSRange
        var reviewIssue: PickupReviewIssue? = nil
        var alternativeGroup: String? = nil
        var exclusion: Exclusion? = nil
        var decision: Decision {
            if let exclusion { return .excluded(exclusion) }
            if let reviewIssue { return .requiresReview(reviewIssue) }
            return .accepted
        }
    }
    struct Notification: Sendable {
        let text: String
        let analysis: CodeAnalysis
        var codes: [Code] { analysis.candidates }
        let location: String?
        let roles: PickupDirectory.Roles
        var locationRequiresConfirmation = false
        var requiresReview: Bool { analysis.requiresReview }
        var unresolved: Bool {
            if analysis.hasUnresolved { return true }
            let ns = text as NSString
            let labels = PickupRecognitionCore.regex(PickupRecognitionCore.label)
                .matches(in: text, range: NSRange(location: 0, length: ns.length))
            let unresolvedLabel = labels.enumerated().contains { index, label in
                    let before = ns.substring(to: label.range.location)
                    let end = index + 1 < labels.count ? labels[index + 1].range.location : ns.length
                    let valueRange = NSRange(location: NSMaxRange(label.range), length: end - NSMaxRange(label.range))
                    let after = ns.substring(with: valueRange)
                    if codes.contains(where: { NSIntersectionRange($0.range, valueRange).length > 0 }) { return false }
                    // A repeated known value and “凭码取件” refer to the same parcel.
                    if !codes.isEmpty, ns.substring(with: label.range) == "凭码" { return false }
                    if let value = PickupRecognitionCore.capture(#"^[\s:：为是「『“\"'〖【(（]*("# + PickupRecognitionCore.token + #")(?![A-Za-z0-9*-])"#, in: after),
                       codes.contains(where: { $0.value == value.uppercased() }) { return false }
                    if PickupRecognitionCore.matches(#"(?:原|旧)$"#, in: before) { return false }
                    let obsolete = #"^[\s:：]*(?:"# + PickupRecognitionCore.token + #")?[\s]*(?:已)?(?:失效|作废|过期|停用)"#
                    return !PickupRecognitionCore.matches(obsolete, in: after)
                }
            let instructions = PickupRecognitionCore.regex(#"凭[^，,。；;]{0,40}(?:提货|提取包裹|取件|取货|取包裹|领取)"#)
                .matches(in: text, range: NSRange(location: 0, length: ns.length))
            let unresolvedInstruction = instructions.contains { instruction in
                if !codes.isEmpty, ns.substring(with: instruction.range).hasPrefix("凭码") { return false }
                return !codes.contains { NSIntersectionRange($0.range, instruction.range).length > 0 }
            }
            // An arrival notification with no usable number remains visible as an omission.
            return unresolvedLabel || (PickupRecognitionCore.hasPickupContext(in: text)
                && (unresolvedInstruction || (codes.isEmpty && PickupRecognitionCore.hasArrivalContext(in: text))))
        }
    }
    static let label = #"(?:取件码|提货码|取货码|领取码|提取码|取件密码|取件编号|凭码)"#
    static let observedToken = #"[A-Za-z0-9*×]+(?:-[A-Za-z0-9*×]+){0,4}"#
    static let token = #"[A-Za-z0-9]+(?:-[A-Za-z0-9]+){0,4}"#
    static let placeSuffix = #"(?:驿站|快递超市|快递柜|丰巢柜|代收点|服务站|便利店|超市|门卫室|自提柜)"#

    static func normalize(_ input: String) -> String {
        var text = String(String.UnicodeScalarView(input.unicodeScalars.map { scalar in
            // Normalize code characters, retaining original Chinese address punctuation.
            if scalar.value == 0xFF0A { return UnicodeScalar(0x2A)! }
            if (0xFF10...0xFF19).contains(scalar.value) || (0xFF21...0xFF3A).contains(scalar.value)
                || (0xFF41...0xFF5A).contains(scalar.value) {
                return UnicodeScalar(scalar.value - 0xFEE0)!
            }
            return scalar
        }))
            .replacingOccurrences(of: "[‐‑‒–—﹣－]", with: "-", options: .regularExpression)
            .replacingOccurrences(of: #"(?<=[A-Za-z0-9])\s*-\s*(?=[A-Za-z0-9])"#, with: "-", options: .regularExpression)
        for label in ["取件码", "提货码", "取货码", "领取码", "提取码", "取件密码", "取件编号", "凭码"] {
            let pattern = label.map { String($0) }.joined(separator: #"\s*"#)
            text = text.replacingOccurrences(of: pattern, with: label, options: .regularExpression)
        }
        return text
    }

    func notifications(in input: String, allowBareCode: Bool = false) -> [Notification] {
        let text = Self.normalize(input)
        let rows = text.components(separatedBy: .newlines)
        var ambiguousPlaces = Set<String>()
        for index in rows.indices where index > 0 && index + 1 < rows.count {
            let row = rows[index].trimmingCharacters(in: .whitespaces)
            if Self.matches("^.{2,60}" + Self.placeSuffix + "$", in: row),
               Self.matches(Self.label, in: rows[index - 1]),
               Self.matches(Self.label, in: rows[index + 1]),
               location(in: rows.prefix(index).suffix(5).joined(separator: "\n")) == nil {
                ambiguousPlaces.insert(row)
            }
        }
        return blocks(in: text).map { block in
            let resolution = resolveLocation(in: block)
            let betweenCodes = ambiguousPlaces.contains { block.components(separatedBy: .newlines).contains($0) }
            return Notification(text: block, analysis: analyzeCodes(in: block, allowBareCode: allowBareCode),
                                location: betweenCodes ? nil : resolution.value,
                                roles: PickupDirectory.roles(in: block),
                                locationRequiresConfirmation: betweenCodes || resolution.ambiguous)
        }
    }

    /// Signatures and independent pickup statements are hard context boundaries.
    /// A newline alone is not a boundary: OCR often puts labels and values on different lines.
    func blocks(in text: String) -> [String] {
        let separated = text.replacingOccurrences(
            of: #"(?<=[。；;])\s*(?=(?:您的?|你的?|包裹|快件|快递)?(?:已到|已存|已放|送至|请到|请凭))"#,
            with: "\n", options: .regularExpression)
        // A quoted code is part of its label, not a sender signature.
        let signature = Self.regex(#"[【\[〖]([^】\]〗\n]{1,24})[】\]〗]"#)
        var signed = separated
        let original = separated as NSString
        for match in signature.matches(in: separated, range: NSRange(location: 0, length: original.length)).reversed() {
            let value = original.substring(with: match.range(at: 1))
            let prefix = original.substring(to: match.range.location)
            let quotedValue = Self.matches(#"^[A-Za-z0-9*×-]+$"#, in: value)
                && (value.contains(where: \.isNumber) || value.contains("*") || value.contains("×"))
            guard !quotedValue, !Self.matches(Self.label + #"[\s:：为是]*$"#, in: prefix),
                  let range = Range(match.range, in: signed) else { continue }
            signed.insert(contentsOf: "\n\u{001E}", at: range.lowerBound)
        }
        var result: [String] = []
        for section in signed.components(separatedBy: "\u{001E}") {
            var current: [String] = []
            var currentHasCode = false
            var currentHasLabel = false
            func flush() {
                let value = current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { result.append(value) }
                current = []
                currentHasCode = false
                currentHasLabel = false
            }
            let sectionLines = section.components(separatedBy: .newlines)
            for (lineIndex, line) in sectionLines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                let hasCode = currentHasCode
                let beginsPlace = Self.capture(#"^([^，,。；;\n]{2,60}"# + Self.placeSuffix + #")$"#, in: trimmed) != nil
                let newArrival = Self.matches(#"(?:已到|包裹到|请到|请凭|送至|存放在)"#, in: trimmed)
                let newLabel = Self.matches(Self.label, in: trimmed)
                // A second label-only line starts another record. A shared list stays in its block.
                // A failed/hidden value is still a notification boundary.
                if hasCode || currentHasLabel {
                    let followingLabel = sectionLines.dropFirst(lineIndex + 1).prefix(2).contains {
                        Self.matches(Self.label, in: $0)
                    }
                    let incomingCode = !codes(in: trimmed, allowBareCode: false).isEmpty
                    let previousPlace = (beginsPlace || newArrival)
                        ? location(in: current.joined(separator: "\n")) : nil
                    if newLabel || ((beginsPlace || newArrival)
                        && (previousPlace != nil || incomingCode || followingLabel)) { flush() }
                }
                current.append(trimmed)
                currentHasLabel = currentHasLabel || newLabel
                if !currentHasCode {
                    currentHasCode = !codes(in: current.suffix(5).joined(separator: "\n"), allowBareCode: false).isEmpty
                }
            }
            flush()
        }
        return result
    }

    static func validCode(_ value: String) -> Bool {
        guard (4...24).contains(value.count), value.contains(where: \.isNumber),
              matches("^" + token + "$", in: value) else { return false }
        return !value.allSatisfy(\.isNumber) || value.count <= 8
    }

    /// Extraction preserves observations. Classification and relation resolution decide
    /// usability afterward; adapters never recreate a code from a rejected fragment.
    func analyzeCodes(in text: String, allowBareCode: Bool) -> CodeAnalysis {
        let ns = text as NSString
        var observations: [Code] = []
        var issues: [AnalysisIssue] = []
        let rawToken = Self.observedToken
        let context = ClassificationContext(numberRoles: numberRoleRanges(in: text), phones: phoneNumberRanges(in: text))
        func offer(_ range: NSRange, explicit: Bool, rule: String) {
            guard !observations.contains(where: { $0.range == range }) else { return }
            observations.append(Code(value: ns.substring(with: range).uppercased(),
                                     explicit: explicit, rule: rule, range: range))
        }
        let labels = Self.regex(Self.label).matches(in: text, range: NSRange(location: 0, length: ns.length))
        for (index, label) in labels.enumerated() {
            let end = index + 1 < labels.count ? labels[index + 1].range.location : ns.length
            let remainderRange = NSRange(location: NSMaxRange(label.range), length: end - NSMaxRange(label.range))
            let remainder = ns.substring(with: remainderRange)
            let pattern = #"^[\s:：为是「『“\"'〖【\[(（]*("# + rawToken + #")(?![A-Za-z0-9*×-])"#
            if let match = Self.regex(pattern).firstMatch(in: remainder, range: NSRange(location: 0, length: (remainder as NSString).length)) {
                let range = NSRange(location: remainderRange.location + match.range(at: 1).location, length: match.range(at: 1).length)
                offer(range, explicit: true, rule: "label.direct")
                var cursor = NSMaxRange(range)
                // A bad item is still an item. Advance past it and keep scanning the list.
                while cursor < end {
                    let tail = ns.substring(with: NSRange(location: cursor, length: end - cursor))
                    let list = #"^[ \t]*(?:…|\.\.\.|[•●□]+)?[ \t]*[、，,][ \t]*("# + rawToken + #")(?![A-Za-z0-9*×-])"#
                    guard let next = Self.regex(list).firstMatch(in: tail, range: NSRange(location: 0, length: (tail as NSString).length)) else { break }
                    offer(NSRange(location: cursor + next.range(at: 1).location, length: next.range(at: 1).length),
                          explicit: true, rule: "label.list")
                    cursor += next.range.length
                }
            } else if remainder.trimmingCharacters(in: .whitespaces).hasPrefix("\n") {
                var offset = remainderRange.location
                for line in remainder.components(separatedBy: "\n").prefix(5) {
                    let lineNS = line as NSString
                    if let match = Self.regex(#"^\s*("# + rawToken + #")\s*$"#)
                        .firstMatch(in: line, range: NSRange(location: 0, length: lineNS.length)) {
                        let range = NSRange(location: offset + match.range(at: 1).location, length: match.range(at: 1).length)
                        let observation = Code(value: ns.substring(with: range).uppercased(), explicit: true,
                                               rule: "label.row", range: range)
                        // Identified phone/address rows do not bind to a preceding code label.
                        if classify(observation, in: text, context: context).exclusion != .otherNumberRole {
                            offer(range, explicit: true, rule: "label.row")
                            break
                        }
                    }
                    offset += lineNS.length + 1
                }
            }
        }
        if Self.hasPickupContext(in: text) {
            for pattern in [
                #"凭[\s:：「『“\"']*("# + rawToken + #")(?![A-Za-z0-9*×-])(?=[」』”\"'\s]*(?:及时|尽快|来|到|至|前往|取|领|提货|提取包裹))"#,
                #"(?:领取|取件|取货|提货)[ \t]+("# + rawToken + #")(?![A-Za-z0-9*×-])"#,
            ] {
                for match in Self.regex(pattern).matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                    offer(match.range(at: 1), explicit: false, rule: "instruction.pickup")
                }
            }
        }
        let usesContextFallback = labels.isEmpty && observations.isEmpty
            && Self.hasPickupContext(in: text) && Self.hasArrivalContext(in: text)
        if usesContextFallback {
            for match in Self.regex(#"(?<![A-Za-z0-9*×-])("# + rawToken + #")(?![A-Za-z0-9*×-])"#)
                .matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                offer(match.range(at: 1), explicit: false, rule: "context.candidate")
            }
        }
        // One classifier owns role, whole-token and truncation decisions for every rule.
        observations = observations.map { classify($0, in: text, context: context) }
        if usesContextFallback {
            let usable = observations.indices.filter { observations[$0].exclusion == nil }
            if usable.count > 1 {
                for index in usable where observations[index].reviewIssue == nil {
                    observations[index].reviewIssue = .uncertainNumbers
                }
            }
        }

        if !labels.isEmpty || !observations.isEmpty {
            // Invalidate the previous code when a correction is stated, even if the
            // replacement is absent/masked. An unreadable replacement cannot revive it.
            let markers = Self.regex(#"(?:更正为|更新为|改为|换为)"#)
                .matches(in: text, range: NSRange(location: 0, length: ns.length))
            for marker in markers {
                let old = observations.indices.filter {
                    NSMaxRange(observations[$0].range) <= marker.range.location
                        && observations[$0].exclusion != .otherNumberRole
                        && observations[$0].exclusion != .superseded
                        && observations[$0].exclusion != .notPickup
                }.max { observations[$0].range.location < observations[$1].range.location }
                let prefix = ns.substring(to: marker.range.location)
                    .components(separatedBy: CharacterSet(charactersIn: "，,。；;\n")).last ?? ""
                // A field's own correction must not invalidate an earlier pickup code.
                // Require a code cue or an otherwise neutral correction clause.
                let codeCorrection = Self.matches(Self.label, in: prefix)
                    || Self.matches(#"^\s*(?:现|现已|已)?\s*$"#, in: prefix)
                guard !Self.matches(#"地址|地点|手机|电话|金额|数量|运单"#, in: prefix),
                      codeCorrection, old != nil || Self.matches(Self.label, in: prefix) else { continue }
                if let old { observations[old].exclusion = .superseded }
                let tail = ns.substring(from: NSMaxRange(marker.range))
                let replacement = #"^[\s:：「『“\"'〖【\[(（]*(?:"# + Self.label + #")?[\s:：为是「『“\"'〖【\[(（]*("# + rawToken + #")(?![A-Za-z0-9*×-])"#
                if let match = Self.regex(replacement).firstMatch(in: tail, range: NSRange(location: 0, length: (tail as NSString).length)) {
                    let range = NSRange(location: NSMaxRange(marker.range) + match.range(at: 1).location,
                                        length: match.range(at: 1).length)
                    if !observations.contains(where: { $0.range == range }) {
                        observations.append(classify(Code(value: ns.substring(with: range).uppercased(), explicit: true,
                                                          rule: "label.replacement", range: range), in: text, context: context))
                    }
                } else { issues.append(.missingReplacement) }
            }
            let alternative = #"(?:或(?:者)?|/)[\s]*(?:使用|凭)?(?:"# + Self.label + #")?[\s:：为是「『“\"']*("# + rawToken + #")(?![A-Za-z0-9*×-])"#
            for match in Self.regex(alternative).matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                guard let previous = observations.filter({ $0.exclusion == nil && NSMaxRange($0.range) <= match.range.location })
                    .max(by: { $0.range.location < $1.range.location }) else { continue }
                let between = ns.substring(with: NSRange(location: NSMaxRange(previous.range),
                    length: match.range.location - NSMaxRange(previous.range)))
                guard Self.matches(#"^[\s，,」』”\"']*$"#, in: between) else { continue }
                let range = match.range(at: 1)
                if !observations.contains(where: { $0.range == range }) {
                    observations.append(classify(Code(value: ns.substring(with: range).uppercased(), explicit: false,
                                                      rule: "choice.value", range: range), in: text, context: context))
                }
            }
            observations.sort { $0.range.location < $1.range.location }
            let choices = observations.indices.filter { observations[$0].exclusion == nil || observations[$0].exclusion == .unreadable }
            var choiceStart: Int? = nil
            for pair in zip(choices, choices.dropFirst()) {
                let previousEnd = NSMaxRange(observations[pair.0].range)
                let between = ns.substring(with: NSRange(location: previousEnd, length: observations[pair.1].range.location - previousEnd))
                let connector = #"^[\s，,]*(?:或(?:者)?|/)[\s]*(?:使用|凭)?(?:"# + Self.label + #")?[\s:：为是「『“”」』\"']*$"#
                if Self.matches(connector, in: between) {
                    let first = choiceStart ?? pair.0
                    choiceStart = first
                    let group = PickupIdentity.key(code: "choice-\(observations[first].range.location)", location: text, platform: nil)
                    for index in [pair.0, pair.1] {
                        if observations[index].reviewIssue != .truncated { observations[index].reviewIssue = .alternatives }
                        observations[index].alternativeGroup = group
                    }
                } else { choiceStart = nil }
            }
        }
        let bare = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if observations.isEmpty, allowBareCode, Self.validCode(bare),
           !Self.matches(#"^\d{4}-\d{1,2}-\d{1,2}$"#, in: bare) {
            observations.append(Code(value: bare, explicit: false, rule: "manual.bare", range: NSRange(location: 0, length: ns.length)))
        }
        return CodeAnalysis(observations: observations.sorted { $0.range.location < $1.range.location }, issues: issues)
    }

    func codes(in text: String, allowBareCode: Bool) -> [Code] {
        analyzeCodes(in: text, allowBareCode: allowBareCode).candidates
    }

    private struct ClassificationContext {
        let numberRoles: [NSRange]
        let phones: [NSRange]
    }

    private func classify(_ observation: Code, in text: String, context: ClassificationContext) -> Code {
        var code = observation
        let ns = text as NSString
        let after = ns.substring(from: NSMaxRange(code.range))
        if context.numberRoles.contains(where: { NSIntersectionRange($0, code.range).length > 0 }) {
            code.exclusion = .otherNumberRole
        } else if excluded(code.range, in: text) {
            code.exclusion = .notPickup
        } else if code.value.contains("*") || code.value.contains("×") {
            code.exclusion = .unreadable
        } else if context.phones.contains(where: { NSIntersectionRange($0, code.range).length > 0 }) {
            if code.explicit && code.value.contains("-") { code.reviewIssue = .phoneLike }
            else { code.exclusion = .otherNumberRole }
        } else if !Self.validCode(code.value) {
            code.exclusion = .invalidFormat
        }
        if code.rule == "context.candidate", code.exclusion == nil,
           Self.matches(#"^\d{4}-\d{1,2}-\d{1,2}$"#, in: code.value)
            || Self.matches(#"^[ \t]*(?:包裹|快件|邮件|号|栋|楼|单元|室|米|公里|分钟|小时|天|年|月|日|点|分|秒|件|个|元|积分|红包|优惠券)"#, in: after) {
            code.exclusion = .otherNumberRole
        }
        if code.exclusion == nil {
            let maskedTail = Self.matches(#"^[ \t]*(?:…|\.\.\.|[•●□×])"#, in: after)
            let continuation = Self.matches(#"^\s+[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*[ \t]*(?:\n|$|取件|取货|提货|领取)"#, in: after)
            if maskedTail || continuation { code.reviewIssue = .truncated }
        }
        return code
    }

    static func hasPickupContext(in text: String) -> Bool {
        matches(#"(?:快递|包裹|快件|取件|取货|取包裹|提货|驿站|快递柜|自提柜|代收点|门卫室)"#, in: text)
    }

    static func hasArrivalContext(in text: String) -> Bool {
        matches(#"已到|已送达|包裹到|快件到|已存|已放|送至|暂存|待取件|请.{0,8}(?:取件|取货|提货|领取)"#, in: text)
    }

    private func numberRoleRanges(in text: String) -> [NSRange] {
        let courierNames = PickupDirectory.couriers.flatMap(\.aliases)
            .map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let patterns = [
            #"(?<![A-Za-z0-9])1[3-9][0-9][ \t-]*[*×Xx]{4}[ \t-]*[0-9]{4}(?![A-Za-z0-9])"#,
            #"https?://[^\s，,。；;]+"#,
            #"(?:^|\n)[ \t]*(?:"# + courierNames + #")[ \t]+[A-Za-z0-9]{8,24}(?![A-Za-z0-9])"#,
            #"(?:^|\n)[ \t]*(?:收(?:件人|货人)?[ \t：:]|收货地址|收件地址)(?:(?!"# + Self.label + #")[^，,。；;\n])*"#,
            #"(?:手机(?:号(?:码)?|尾号)?|电话(?:号(?:码)?|尾号)?|客服(?:电话)?|运单(?:号|尾号)?|物流单号|订单(?:号|尾号)|包裹尾号|快件尾号|邮件尾号|尾号|分机(?:号)?|验证码|校验码|房号)[ \t:：为是]*[A-Za-z0-9*×]+(?:[ \t-]+[A-Za-z0-9*×]+)*"#,
            #"(?:于|截止|截至|日期|时间)[ \t:：]*(?:20[0-9]{6})(?:前|之前|日|$)"#,
            #"[0-9]{4}[ \t]*(?:为|是|系)?(?:包裹|快件|邮件|订单)尾号"#,
            #"(?<![0-9])[0-9]{4}[/年.][0-9]{1,2}[/月.][0-9]{1,2}日?(?![0-9])"#,
            #"(?<![0-9])[0-9]{1,2}[:：][0-9]{2}(?:[:：][0-9]{2})?(?![0-9])"#,
        ]
        var ranges = patterns.flatMap { Self.regex($0).matches(in: text, range: NSRange(text.startIndex..., in: text)).map(\.range) }
        let ns = text as NSString
        for phone in phoneNumberRanges(in: text) {
            let tail = ns.substring(from: NSMaxRange(phone))
            if let extra = Self.regex(#"^[ \t]*(?:转|分机(?:号)?)[ \t:：]*[0-9]{3,8}"#)
                .firstMatch(in: tail, range: NSRange(location: 0, length: (tail as NSString).length)) {
                ranges.append(NSRange(location: NSMaxRange(phone), length: extra.range.length))
            }
        }
        return ranges
    }

    private func phoneNumberRanges(in text: String) -> [NSRange] {
        let patterns = [
            // Mainland mobile shape, not an operator-specific prefix allowlist.
            #"(?<![A-Za-z0-9])(?:\+?86[ \t-]?)?1[3-9][0-9](?:[ \t-]?[0-9]){8}(?![A-Za-z0-9])"#,
            #"(?<![A-Za-z0-9])0[0-9]{2,3}[ \t-]?[0-9]{7,8}(?![A-Za-z0-9])"#,
            #"(?<![A-Za-z0-9])(?:400|800)[ \t-]?[0-9]{3}[ \t-]?[0-9]{4}(?![A-Za-z0-9])"#,
        ]
        return patterns.flatMap { Self.regex($0).matches(in: text, range: NSRange(text.startIndex..., in: text)).map(\.range) }
    }

    private func excluded(_ range: NSRange, in text: String) -> Bool {
        let ns = text as NSString
        let start = max(0, range.location - 18)
        let before = ns.substring(with: NSRange(location: start, length: range.location - start))
        let after = ns.substring(from: NSMaxRange(range)).prefix(30)
        if Self.matches(#"(?:原|旧)"# + Self.label + #"[\s:：为是「『“\"']*$"#, in: before) { return true }
        if Self.matches(#"^[\s，,]*(?:已)?(?:失效|作废|过期|停用|不可用)"#, in: String(after)) { return true }
        if Self.matches(#"^[ \t]*(?:积分|红包|优惠券|元(?:红包|补贴|奖励)?)"#, in: String(after)) { return true }
        // Preserve whole tokens. Masks, URLs and address suffixes cannot be truncated into codes.
        if Self.matches(#"^[*×Xx]|^(?:号楼|单元|室|格口|元)|^\s*(?:为|是|系)?\s*(?:手机|电话|运单|单号).*尾号"#, in: String(after)) { return true }
        if Self.matches(#"(?:手机尾号|电话尾号|运单尾号|单号尾号|手机号|电话|运单号|验证码|房号)\s*[:：]?\s*$"#, in: before) { return true }
        return false
    }

    func location(in text: String) -> String? { resolveLocation(in: text).value }

    private func resolveLocation(in text: String) -> (value: String?, ambiguous: Bool) {
        // Join physical OCR wraps inside a sentence; retain separate rows for address-label parsing.
        let joined = text.replacingOccurrences(of: "\n", with: "")
        let patterns = [
            #"(?:领取地点|取件地点|取件地址|(?<!收货)(?<!收件)地址)[ \t]*[:：]?[ \t]*([^\n，,。；;]{2,80})"#,
            Self.label + #"[\s:：为是「『“\"']*"# + Self.token + #"[」』”\"'\s]*(?:到|至|前往)\s*([^，,。；;\n]{2,80})"#,
            #"凭[\s:：「『“\"']*"# + Self.token + #"[」』”\"'\s]*(?:到|至|前往)\s*([^，,。；;\n]{2,80})"#,
            #"(?:已到达|已到|己到|送达|送至|存放在|存放于|存放至|已存放至|已存入|已放入|请到|包裹到|快件到|快递到)\s*([^，,。；;\n]{2,80})"#,
            #"(?:包裹|快件|快递)(?:已)?在\s*([^，,。；;\n]{2,80})"#,
        ]
        if Self.matches(#"(?:或(?:者)?(?:到|至|前往)|也可到|改到|(?:地点|地址)[^，,。；;\n]{0,20}(?:更正为|更正至))"#, in: text) { return (nil, true) }
        var candidates = Set<String>()
        for pattern in patterns {
            let source = pattern.hasPrefix("(?:领取地点") ? text : joined
            for match in Self.regex(pattern).matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                guard let range = Range(match.range(at: 1), in: source),
                      let cleaned = cleanLocation(String(source[range])) else { continue }
                candidates.insert(cleaned)
            }
        }
        if candidates.count > 1 {
            // A shop title and its compatible detailed address are one location.
            // Only resolve this relation with shared address evidence; distinct sites stay ambiguous.
            let detailPattern = #"(?<!取件)(?<!收货)(?<!收件)地址[ \t]*[:：]?[ \t]*([^\n，,。；;]{2,80})"#
            let details = Set(Self.regex(detailPattern).matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match -> String? in
                guard let range = Range(match.range(at: 1), in: text) else { return nil }
                return cleanLocation(String(text[range]))
            })
            let titles = candidates.subtracting(details)
            if details.count == 1, titles.count == 1,
               let title = titles.first, let detail = details.first,
               addressDetail(detail, belongsTo: title) { return (title, false) }
            return (nil, true)
        }
        if let candidate = candidates.first { return (candidate, false) }
        // A standalone station row is useful in screenshots, but a header alone isn't an address.
        let rows = text.components(separatedBy: .newlines).filter {
            !Self.matches(Self.label + #"|(?:凭|电话|快递员|取件手机号)|^[【\[〖]"#, in: $0)
        }
        let places = rows.compactMap { row -> String? in
            guard Self.matches("^.{2,60}" + Self.placeSuffix + "$", in: row) else { return nil }
            return cleanLocation(row)
        }
        let unique = Set(places)
        return (unique.count == 1 ? unique.first : nil, unique.count > 1)
    }

    private func addressDetail(_ detail: String, belongsTo title: String) -> Bool {
        guard !Self.matches(Self.placeSuffix + #"$|店$"#, in: detail),
              Self.matches(#"[0-9].*(?:号|栋|楼|单元|室|[0-9]$)"#, in: detail) else { return false }
        // An explicit title repeated in an address is direct evidence.
        if detail.contains(title) { return true }
        let buildingPattern = #"[0-9]+(?:号)?(?:楼|栋)"#
        func buildings(_ value: String) -> Set<String> {
            Set(Self.regex(buildingPattern).matches(in: value, range: NSRange(value.startIndex..., in: value)).compactMap {
                Range($0.range, in: value).map { String(value[$0]) }
            })
        }
        let titleBuildings = buildings(title)
        guard !titleBuildings.isEmpty, titleBuildings == buildings(detail),
              let titleBuilding = Self.regex(buildingPattern).firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let detailBuilding = Self.regex(buildingPattern).firstMatch(in: detail, range: NSRange(detail.startIndex..., in: detail)),
              let titleRange = Range(titleBuilding.range, in: title),
              let detailRange = Range(detailBuilding.range, in: detail) else { return false }
        let prefix = Array(title[..<titleRange.lowerBound])
        let detailPrefix = String(detail[..<detailRange.lowerBound])
        guard prefix.count >= 4 else { return false }
        // Allow a locality prefix or “新” before the same building number, but require
        // four shared Chinese characters before it; the number alone is insufficient.
        return (0...(prefix.count - 4)).contains { index in
            let anchor = String(prefix[index..<(index + 4)])
            return Self.matches(#"^\p{Han}{4}$"#, in: anchor) && detailPrefix.contains(anchor)
        }
    }

    private func cleanLocation(_ raw: String) -> String? {
        var value = raw
        for delimiter in [Self.label, #"(?:请|及时|尽快|领取|取件|取货|取包裹|来取|电话|联系|咨询|询\d|格口)"#] {
            if let match = Self.regex(delimiter).firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
               let range = Range(match.range, in: value) { value = String(value[..<range.lowerBound]) }
        }
        // A locker compartment is distinct from the locker location.
        value = value.replacingOccurrences(of: #"(?<=号柜)[A-Za-z0-9-]+$"#, with: "", options: .regularExpression)
        value = value.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard (2...80).contains(value.count), !["这里", "那里", "代收点", "到了"].contains(value),
              !Self.matches(#"\d{10,}|https?://|[【】\[\]]|验证码"#, in: value) else { return nil }
        return value
    }

    static func regex(_ pattern: String) -> NSRegularExpression {
        // All expressions are developer-owned constants, never external patterns.
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
    static func capture(_ pattern: String, in text: String) -> String? {
        guard let match = regex(pattern).firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
    static func matches(_ pattern: String, in text: String) -> Bool {
        regex(pattern).firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}
