import XCTest
@testable import Shouxia

final class PickupParserTests: XCTestCase {
    private let parser = PickupParser()
    private let imageExtractor = ImagePickupExtractor()
    private let imageBatchMerger = ImagePickupBatchMerger()

    func testParsesZTOSharedLabelCodeListAndLocation() throws {
        let text = "【中通快递】您有2个包裹在老六号楼（新4号楼）二单元106妈妈驿站，取货码9-4-0178、5-1-2889"
        for requiresLabel in [false, true] {
            let results = try parser.parseAll(text, requiresLabel: requiresLabel)
            XCTAssertEqual(results.map(\.code), ["9-4-0178", "5-1-2889"])
            XCTAssertEqual(results.map(\.location), Array(repeating: "老六号楼（新4号楼）二单元106妈妈驿站", count: 2))
            XCTAssertEqual(results.map(\.platform), ["中通", "中通"])
            XCTAssertEqual(Set(results.map(\.fingerprint)).count, 2)
        }
    }

    func testLabelledListsSupportSeparatorsAndDeduplicateCodes() throws {
        for separator in ["、", "，", ", "] {
            let results = try parser.parseAll("取货码9-4-0178" + separator + "5-1-2889" + separator + "9-4-0178")
            XCTAssertEqual(results.map(\.code), ["9-4-0178", "5-1-2889"])
        }
        XCTAssertEqual(try parser.parseAll("取件码829146、729915").map(\.code), ["829146", "729915"])
        XCTAssertEqual(try parser.parseAll("取件码A-12-08、b-23-09").map(\.code), ["A-12-08", "B-23-09"])
        XCTAssertEqual(try parser.parseAll("取货码9-4-0178、取货码5-1-2889").map(\.code), ["9-4-0178", "5-1-2889"])
    }

    func testLabelledListDoesNotCollectPhoneTrackingOrAddressNumbers() throws {
        for suffix in ["、13800138000", "，76543210987654", "，106妈妈驿站", "，客服电话13800138000"] {
            XCTAssertEqual(try parser.parseAll("取货码9-4-0178、5-1-2889" + suffix).map(\.code), ["9-4-0178", "5-1-2889"])
        }
        XCTAssertThrowsError(try parser.parseAll("验证码829146、729915", requiresLabel: true))
        XCTAssertThrowsError(try parser.parseAll("   "))
    }

    func testParsesCainiaoNotification() throws {
        let result = try parser.parse("【菜鸟驿站】您的包裹已到北门菜鸟驿站，取件码3-2-4012，请凭码取件。")

        XCTAssertEqual(result.code, "3-2-4012")
        XCTAssertEqual(result.location, "北门菜鸟驿站")
        XCTAssertEqual(result.platform, "菜鸟")
    }

    func testParsesFengchaoNotification() throws {
        let result = try parser.parse("【丰巢】快件已存入1号柜，取件码829146，请及时领取。")

        XCTAssertEqual(result.code, "829146")
        XCTAssertEqual(result.location, "1号柜")
        XCTAssertEqual(result.platform, "丰巢")
    }

    func testParsesFengchaoCodeBeforeLocationNotification() throws {
        let result = try parser.parse(
            "【丰巢】凭取件码81234567至云朵大厦北侧丰巢柜1号柜取件。快递员及畅存规则p.fcbox.com/demo"
        )

        XCTAssertEqual(result.code, "81234567")
        XCTAssertEqual(result.location, "云朵大厦北侧丰巢柜1号柜")
        XCTAssertEqual(result.platform, "丰巢")
    }

    func testFengchaoHeaderIsNotUsedAsLocation() throws {
        let result = try parser.parse("丰巢】凭取件码81234567取件。")

        XCTAssertEqual(result.code, "81234567")
        XCTAssertNil(result.location)
        XCTAssertEqual(result.platform, "丰巢")
    }

    func testParsesShelfCode() throws {
        let result = try parser.parse("您的快递已到幸福里快递超市，货架号A-12-08，取件码6688。")

        XCTAssertEqual(result.code, "6688")
        XCTAssertEqual(result.location, "幸福里快递超市")
    }

    func testParsesJingdongAlphanumericCode() throws {
        let result = try parser.parse("【京东物流】包裹送至东区代收点，取件码为JD-9321，请及时领取。")

        XCTAssertEqual(result.code, "JD-9321")
        XCTAssertEqual(result.location, "东区代收点")
        XCTAssertEqual(result.platform, "京东")
    }

    func testParsesPostalServiceStation() throws {
        let result = try parser.parse("【邮政】您的邮件已到达东门邮政综合服务站，请凭取件码 5-18-662 领取。")

        XCTAssertEqual(result.code, "5-18-662")
        XCTAssertEqual(result.location, "东门邮政综合服务站")
        XCTAssertEqual(result.platform, "邮政")
    }

    func testParsesPickupCodeWithoutLocation() throws {
        let result = try parser.parse("包裹已到，请使用领取码：P668899 完成取件。")

        XCTAssertEqual(result.code, "P668899")
        XCTAssertNil(result.location)
    }

    func testPrefersLabelledCodeOverPhoneNumber() throws {
        let result = try parser.parse("客服电话 13800138000，您的取件码为729915，请及时领取。")

        XCTAssertEqual(result.code, "729915")
    }

    func testRejectsTextWithoutPickupCode() {
        XCTAssertThrowsError(try parser.parse("您的快递正在运输中，请耐心等待。")) { error in
            XCTAssertEqual(error as? PickupImportError, .missingCode)
        }
    }

    func testAutomaticClipboardRequiresExplicitPickupCodeCue() {
        XCTAssertThrowsError(
            try parser.parseAutomaticClipboard("【登录提醒】验证码 829146，5 分钟内有效。")
        ) { error in
            XCTAssertEqual(error as? PickupImportError, .missingCode)
        }
        XCTAssertThrowsError(
            try parser.parseAutomaticClipboard("829146")
        ) { error in
            XCTAssertEqual(error as? PickupImportError, .missingCode)
        }
        XCTAssertThrowsError(
            try parser.parseAutomaticClipboard("取件码已失效，请输入登录验证码 829146")
        ) { error in
            XCTAssertEqual(error as? PickupImportError, .missingCode)
        }
    }

    func testAutomaticClipboardAcceptsExplicitPickupCodeCue() throws {
        let result = try parser.parseAutomaticClipboard(
            "【丰巢】快件已存入1号柜，取件码829146，请及时领取。"
        )

        XCTAssertEqual(result.code, "829146")
    }

    func testManualParsingAcceptsBareSixAndEightDigitCodes() throws {
        XCTAssertEqual(try parser.parse("829146").code, "829146")
        XCTAssertEqual(try parser.parse("82914657").code, "82914657")
    }

    func testFingerprintIgnoresWhitespace() throws {
        let first = try parser.parse("取件码 123456，已到 北门菜鸟驿站")
        let second = try parser.parse("取件码123456，已到北门菜鸟驿站")

        XCTAssertEqual(first.fingerprint, second.fingerprint)
    }

    func testImageExtractorRecognizesSharedLabelCodesOnOneLine() throws {
        let candidates = try imageExtractor.candidates(from: [imageLine(
            "【中通快递】您有2个包裹在老六号楼（新4号楼）二单元106妈妈驿站，取货码9-4-0178、5-1-2889"
        )])
        XCTAssertEqual(candidates.map(\.code), ["9-4-0178", "5-1-2889"])
        XCTAssertEqual(candidates.map(\.location), Array(repeating: "老六号楼（新4号楼）二单元106妈妈驿站", count: 2))
        XCTAssertTrue(candidates.allSatisfy(\.isHighConfidence))
        let spaced = try imageExtractor.candidates(from: [imageLine("取货码9 - 4 - 0178、5 - 1 - 2889，电话13800138000")])
        XCTAssertEqual(spaced.map(\.code), ["9-4-0178", "5-1-2889"])
    }

    func testImageExtractorPrefersLabelledPickupCodeAndSanitizesPrivateText() throws {
        let lines = [
            imageLine("中通快递 76543210987654"),
            imageLine("待取件 今天 11:20"),
            imageLine("幸福家园北门驿站"),
            imageLine("幸福家园8号楼2单元106"),
            imageLine("取件码：12-4-6789"),
            imageLine("快件已由快递员 13912345678 送达代收点"),
        ]

        let candidates = try imageExtractor.candidates(from: lines)

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].code, "12-4-6789")
        XCTAssertEqual(candidates[0].location, "幸福家园北门驿站")
        XCTAssertEqual(candidates[0].platform, "中通")
        XCTAssertTrue(candidates[0].isHighConfidence)
        XCTAssertFalse(candidates[0].sanitizedImportText.contains("76543210987654"))
        XCTAssertFalse(candidates[0].sanitizedImportText.contains("13912345678"))
        XCTAssertFalse(candidates[0].sanitizedImportText.contains("2单元106"))
    }

    func testImageExtractorReturnsMultipleLabelledCodesForReview() throws {
        let lines = [
            imageLine("北门菜鸟驿站"),
            imageLine("取件码 3-2-4012"),
            imageLine("北门菜鸟驿站"),
            imageLine("取件码 8-5-2031"),
        ]

        let candidates = try imageExtractor.candidates(from: lines)

        XCTAssertEqual(candidates.map(\.code), ["3-2-4012", "8-5-2031"])
        XCTAssertTrue(candidates.allSatisfy(\.isHighConfidence))
    }

    func testImageExtractorJoinsFengchaoLocationSplitAcrossLines() throws {
        let candidates = try imageExtractor.candidates(
            from: [
                imageLine("【丰巢】凭取件码81234567至云"),
                imageLine("朵大厦北侧丰巢柜1号柜取件。"),
                imageLine("快递员及畅存规则p.fcbox.com/demo"),
                imageLine("【丰巢】凭取件码87654321至"),
                imageLine("云朵大厦北侧丰巢柜1号柜取件。"),
            ]
        )

        XCTAssertEqual(candidates.map(\.code), ["81234567", "87654321"])
        XCTAssertEqual(
            candidates.map(\.location),
            ["云朵大厦北侧丰巢柜1号柜", "云朵大厦北侧丰巢柜1号柜"]
        )
        XCTAssertTrue(candidates.allSatisfy { $0.platform == "丰巢" })
        XCTAssertTrue(candidates.allSatisfy(\.isHighConfidence))
    }

    func testImageCandidateWithoutLocationRequiresReview() throws {
        let candidate = try XCTUnwrap(
            imageExtractor.candidates(from: [imageLine("丰巢 取件码 829146")]).first
        )

        XCTAssertEqual(candidate.platform, "丰巢")
        XCTAssertNil(candidate.location)
        XCTAssertFalse(candidate.isHighConfidence)
    }

    func testImageBatchMergerPreservesMissingContextAndDistinctLocations() {
        let first = ImagePickupCandidate(
            code: "3-2-8309",
            location: nil,
            platform: nil,
            confidence: 0.91,
            isLabelled: true
        )
        let overlapping = ImagePickupCandidate(
            code: "3-2-8309",
            location: "北门驿站",
            platform: "淘宝",
            confidence: 0.82,
            isLabelled: true
        )
        let other = ImagePickupCandidate(
            code: "11-2-1755",
            location: nil,
            platform: "淘宝",
            confidence: 0.88,
            isLabelled: true
        )

        let merged = imageBatchMerger.merge([[first, other], [overlapping]])

        XCTAssertEqual(merged.map(\.code), ["3-2-8309", "11-2-1755", "3-2-8309"])
        XCTAssertNil(merged.first?.location)
        XCTAssertEqual(merged.last?.location, "北门驿站")
        XCTAssertEqual(imageBatchMerger.merge([[overlapping], [overlapping]]).count, 1)
    }

    func testImageExtractorMarksUnlabelledHyphenCodeForConfirmation() throws {
        let candidates = try imageExtractor.candidates(
            from: [imageLine("请到北门驿站领取 7-3-0912")]
        )

        XCTAssertEqual(candidates.map(\.code), ["7-3-0912"])
        XCTAssertFalse(candidates[0].isHighConfidence)
    }

    func testImageExtractorRejectsTrackingAndPhoneNumbersWithoutPickupCode() {
        let lines = [
            imageLine("中通快递 运单号 76543210987654"),
            imageLine("物流电话 13912345678"),
        ]

        XCTAssertThrowsError(try imageExtractor.candidates(from: lines)) { error in
            XCTAssertEqual(
                error as? ImagePickupRecognitionError,
                .noPickupCode
            )
        }
    }

    func testRealImageOCRFixtureWhenProvided() async throws {
        guard let fixturePath = ProcessInfo.processInfo.environment[
            "SHOUXIA_OCR_FIXTURE"
        ] else {
            throw XCTSkip("Set SHOUXIA_OCR_FIXTURE to run a real-image OCR check")
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: fixturePath))
        let lines = try await ImageTextRecognizer().recognize(in: data)
        let candidates = try imageExtractor.candidates(from: lines)

        let code = try XCTUnwrap(candidates.first?.code)
        XCTAssertNotNil(
            code.range(
                of: #"^\d{1,3}-\d{1,3}-\d{3,4}$"#,
                options: .regularExpression
            )
        )
        XCTAssertEqual(candidates.first?.platform, "中通")
        XCTAssertTrue(candidates.first?.isHighConfidence ?? false)
        let sanitizedText = try XCTUnwrap(candidates.first?.sanitizedImportText)
        XCTAssertNil(
            sanitizedText.range(
                of: #"\b\d{11,}\b"#,
                options: .regularExpression
            )
        )
    }

    func testRealOverlappingImageBatchWhenProvided() async throws {
        guard let fixtureList = ProcessInfo.processInfo.environment[
            "SHOUXIA_OCR_BATCH_FIXTURES"
        ],
        let expectedList = ProcessInfo.processInfo.environment[
            "SHOUXIA_OCR_BATCH_EXPECTED_CODES"
        ] else {
            throw XCTSkip(
                "Set SHOUXIA_OCR_BATCH_FIXTURES and SHOUXIA_OCR_BATCH_EXPECTED_CODES to run a real batch OCR check"
            )
        }

        let fixturePaths = fixtureList.split(separator: "|").map(String.init)
        let expectedCodes = Set(expectedList.split(separator: ",").map(String.init))
        var groups: [[ImagePickupCandidate]] = []

        for path in fixturePaths {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let lines = try await ImageTextRecognizer().recognize(in: data)
            groups.append(try imageExtractor.candidates(from: lines))
        }

        let merged = imageBatchMerger.merge(groups)
        XCTAssertEqual(Set(merged.map(\.code)), expectedCodes)
        XCTAssertEqual(merged.count, expectedCodes.count)
    }

    func testRejectsIncidentalNumbersMasksAndUnknownCredentials() {
        let negatives = [
            "手机尾号2635，快递已到东门驿站，咨询13000000000",
            "2026-10-15 18:30，包裹到了，请到南门门卫室领取。",
            "【菜鸟】登录验证码583920，客服电话951966。",
            "快递暂存星河苑3-2-4012室，请联系门卫。",
            "【丰巢】取件码829***，已到北门丰巢柜",
            "【丰巢】取件码XX，已到北门丰巢柜",
            "【京东物流】凭手机尾号2635到东门便利店取件。",
            "请凭取件码到北门驿站领取，点击链接查看取件码",
        ]
        for text in negatives {
            XCTAssertThrowsError(try parser.parseAll(text), text)
            XCTAssertThrowsError(try parser.parseAll(text, requiresLabel: true), text)
            XCTAssertThrowsError(try PickupSharedTextParser().candidates(from: text), text)
            XCTAssertThrowsError(try imageExtractor.candidates(from: text.components(separatedBy: .newlines).map { imageLine($0) }), text)
        }
    }

    func testLabelRowSkipsPhoneTailAndListEndsBeforePostfixRole() throws {
        let text = "北门驿站\n取件码\n手机尾号2635\n829146"
        XCTAssertEqual(try parser.parseAll(text).map(\.code), ["829146"])
        let candidates = try imageExtractor.candidates(from: text.components(separatedBy: .newlines).map { imageLine($0) })
        XCTAssertEqual(candidates.map(\.code), ["829146"])
        XCTAssertEqual(candidates.first?.location, "北门驿站")
        XCTAssertEqual(try parser.parseAll("取件码829146，2635为手机尾号").map(\.code), ["829146"])
        XCTAssertEqual(try parser.parseAll("取件码A-1-26-11，手机尾号2635").map(\.code), ["A-1-26-11"])
    }

    func testImplicitInstructionsPreserveWholeAlphanumericCodes() throws {
        for (text, code, location) in [
            ("【极兔速递】请凭A-12-08到晨光便利店取包裹，电话13000000000", "A-12-08", "晨光便利店"),
            ("【快递超市】你的中国邮政己到样例园绿色果园，请凭Y820078来取，联系电话13000000000", "Y820078", "样例园绿色果园"),
            ("【兔喜生活】您的快件已到辉码生鲜超市店,请您取件时佩戴好口罩,凭2-2-4071及时取件", "2-2-4071", "辉码生鲜超市店"),
        ] {
            let parsed = try parser.parseAll(text, requiresLabel: true)
            XCTAssertEqual(parsed.map(\.code), [code])
            XCTAssertEqual(parsed.first?.location, location)
            XCTAssertEqual(try PickupSharedTextParser().candidates(from: text).first?.code, code)
            XCTAssertEqual(try imageExtractor.candidates(from: [imageLine(text)]).first?.code, code)
        }
    }

    func testAllEntrypointsNormalizeFullWidthQuotesAndOCRWraps() throws {
        for text in ["【丰巢】取件码８２９１４６，已到北门丰巢柜", "【丰巢】凭取件码「829146」至北门丰巢柜取件"] {
            XCTAssertEqual(try parser.parse(text).code, "829146")
            XCTAssertEqual(try PickupSharedTextParser().candidates(from: text).first?.code, "829146")
            XCTAssertEqual(try imageExtractor.candidates(from: [imageLine(text)]).first?.code, "829146")
        }
        XCTAssertEqual(try parser.parse("取\n件码041327").code, "041327")
        XCTAssertEqual(try parser.parse("取件码12-\n4-6789至北门1号柜取件").code, "12-4-6789")
        XCTAssertEqual(try parser.parse("取件码３－２－４０１２").code, "3-2-4012")
    }

    func testMultipleNotificationsKeepTheirOwnCompanyAndLocationAcrossEntrypoints() throws {
        let text = "【中通】已到北门菜鸟驿站\n取件码1234\n【圆通】请凭1234到南门便利店取件\n【德邦】取件码829146"
        let parsed = try parser.parseAll(text)
        XCTAssertEqual(parsed.map(\.code), ["1234", "1234", "829146"])
        XCTAssertEqual(parsed.map(\.location), ["北门菜鸟驿站", "南门便利店", nil])
        XCTAssertEqual(parsed.map(\.platform), ["中通", "圆通", "德邦"])
        XCTAssertEqual(Set(parsed.map(\.fingerprint)).count, 3)
        let shared = try PickupSharedTextParser().candidates(from: text)
        let images = try imageExtractor.candidates(from: text.components(separatedBy: .newlines).map { imageLine($0) })
        XCTAssertEqual(shared.map(\.location), parsed.map(\.location))
        XCTAssertEqual(images.map(\.location), parsed.map(\.location))
        XCTAssertEqual(images.map(\.platform), parsed.map(\.platform))
        XCTAssertEqual(Set(shared.map(\.id)).count, 3)
    }

    func testDirectorySeparatesRolesAndNeverInfersCourierFromStationOwner() {
        XCTAssertEqual(PickupDirectory.roles(in: "【妈妈驿站】您的中通包裹已到北门妈妈驿站").courier, "中通")
        XCTAssertEqual(PickupDirectory.roles(in: "【妈妈驿站】您的包裹已到北门妈妈驿站").courier, nil)
        XCTAssertEqual(PickupDirectory.roles(in: "【菜鸟】您的韵达2635包裹到东门超市").service, "菜鸟")
        XCTAssertEqual(PickupDirectory.roles(in: "【菜鸟】您的韵达2635包裹到东门超市").courier, "韵达")
        XCTAssertNil(PickupDirectory.roles(in: "淘宝 天猫 拼多多 京东订单 JD-9321").displayName)
        XCTAssertNil(PickupDirectory.roles(in: "已到北门圆通速递").courier)
        XCTAssertNil(PickupDirectory.roles(in: "中通或圆通，尚未确认").courier)
    }

    func testCodeBeforeLocationAcrossRowsAndConflictingEvidence() throws {
        let text = "【丰巢】取件码829146\n已到北门丰巢柜"
        XCTAssertEqual(try parser.parse(text).location, "北门丰巢柜")
        XCTAssertEqual(try imageExtractor.candidates(from: text.components(separatedBy: .newlines).map { imageLine($0) }).first?.location, "北门丰巢柜")
        XCTAssertThrowsError(try parser.parse("取件码1234或5678，请确认后领取"))
        XCTAssertNil(PickupDirectory.roles(in: "【中通】您的顺丰包裹已到北门驿站").courier)
        XCTAssertEqual(try parser.parse("取件码ABXX1234").code, "ABXX1234")
    }

    func testIndependentNotificationsOnOneLineKeepBothSameCodes() throws {
        let results = try parser.parseAll("已到北门驿站，取件码1234；已到南门便利店，取件码1234")
        XCTAssertEqual(results.map(\.location), ["北门驿站", "南门便利店"])
        XCTAssertEqual(results.map(\.code), ["1234", "1234"])
    }

    func testTwoColumnAddressUsesDetailedValueOnlyWithGeometry() throws {
        let lines = [
            RecognizedTextLine(text: "地址", confidence: 0.95, minX: 0.1, midY: 0.8, width: 0.1, height: 0.03),
            RecognizedTextLine(text: "长兴路北段店", confidence: 0.95, minX: 0.38, midY: 0.8, width: 0.3, height: 0.03),
            RecognizedTextLine(text: "长兴路北段老李超市旁边", confidence: 0.95, minX: 0.38, midY: 0.755, width: 0.4, height: 0.03),
            RecognizedTextLine(text: "取件码", confidence: 0.95, minX: 0.1, midY: 0.70, width: 0.1, height: 0.03),
            RecognizedTextLine(text: "3-7-4162", confidence: 0.95, minX: 0.1, midY: 0.66, width: 0.32, height: 0.04),
        ]
        XCTAssertEqual(try imageExtractor.candidates(from: lines).first?.location, "长兴路北段老李超市旁边")
        XCTAssertNil(try parser.parse(lines.map(\.text).joined(separator: "\n")).location)
    }

    func testConflictingLocationsStayMissingAndStationNameDoesNotInferCourier() throws {
        let result = try parser.parse("已到北门驿站，已到南门便利店，取件码1234")
        XCTAssertNil(result.location)
        XCTAssertNil(PickupDirectory.roles(in: "东门邮政综合服务站\n取件码1234").courier)
        XCTAssertNil(PickupDirectory.roles(in: "【圆通妈妈驿站】取件码1234").courier)
    }

    func testCandidateIdentityCannotCollideAtSeparators() {
        XCTAssertNotEqual(PickupIdentity.key(code: "1234", location: "A|B", platform: "C"),
                          PickupIdentity.key(code: "1234", location: "A", platform: "B|C"))
    }

    func testImplicitPickupRequiresParcelContextAndExcludesRewards() throws {
        for text in ["活动奖励已到账，请点击领取 1234 积分。", "请凭1234领取优惠券", "快递会员活动，领取 1234 元红包"] {
            XCTAssertThrowsError(try parser.parseAll(text), text)
            XCTAssertThrowsError(try parser.parseAll(text, requiresLabel: true), text)
            XCTAssertThrowsError(try PickupSharedTextParser().candidates(from: text), text)
            XCTAssertThrowsError(try imageExtractor.candidates(from: [imageLine(text)]), text)
        }
        XCTAssertEqual(try parser.parse("请到北门驿站领取 7-3-0912").code, "7-3-0912")
        XCTAssertEqual(try parser.parse("请凭A1234到绿色果园取件").code, "A1234")
    }

    func testMaskedNotificationBoundaryDoesNotDependOnSuccessfulCode() throws {
        let text = "北门驿站\n取件码****\n取件码829146"
        for automatic in [true, false] {
            let parsed = try parser.parseAll(text, requiresLabel: automatic)
            XCTAssertEqual(parsed.map(\.code), ["829146"])
            XCTAssertNil(parsed.first?.location)
            XCTAssertEqual(parsed.first?.unresolvedNotificationCount, 1)
        }
        let shared = try PickupSharedTextParser().candidates(from: text)
        let images = try imageExtractor.candidates(from: text.components(separatedBy: .newlines).map { imageLine($0) })
        XCTAssertNil(shared.first?.location)
        XCTAssertNil(images.first?.location)
        XCTAssertEqual(images.first?.unresolvedNotificationCount, 1)
        XCTAssertTrue(images.first?.shouldSelectByDefault ?? false)
    }

    func testObsoleteAndReplacedCodesDoNotBecomeMultipleParcels() throws {
        for text in [
            "原取件码1234已失效，新取件码5678，请到南门便利店领取。",
            "旧取件码1234，新取件码5678，请到南门便利店领取。",
            "取件码1234更正为5678，请到南门便利店领取。",
            "取件码由1234改为5678，请到南门便利店领取。",
            "取件码1234已作废，请凭5678到南门便利店取件。",
        ] {
            XCTAssertEqual(try parser.parseAll(text, requiresLabel: true).map(\.code), ["5678"], text)
            XCTAssertEqual(try parser.parse(text).location, "南门便利店", text)
            XCTAssertEqual(try PickupSharedTextParser().candidates(from: text).map(\.code), ["5678"], text)
            XCTAssertEqual(try imageExtractor.candidates(from: [imageLine(text)]).map(\.code), ["5678"], text)
        }
    }

    func testAlternativesAreReviewOnlyAndCannotAutofillTwoParcels() throws {
        for separator in ["或", "或者取件码", "/取件码"] {
            let text = "取件码1234" + separator + "5678，请到北门驿站取件"
            XCTAssertThrowsError(try parser.parseAll(text)) { error in
                XCTAssertEqual(error as? PickupImportError, .ambiguousCode)
            }
            let candidates = try PickupSharedTextParser().candidates(from: text)
            XCTAssertEqual(candidates.map(\.code), ["1234", "5678"])
            XCTAssertTrue(candidates.allSatisfy { $0.reviewIssue == .alternatives && !$0.shouldSelectByDefault })
            XCTAssertTrue(candidates.allSatisfy { $0.location == "北门驿站" })
            XCTAssertEqual(Set(candidates.compactMap(\.alternativeGroup)).count, 1)
        }
        XCTAssertEqual(try parser.parseAll("取件码1234、5678，请到北门驿站取件").map(\.code), ["1234", "5678"])
    }

    func testPartialAlternativesDoNotPreventIndependentValidNotification() throws {
        let text = "【中通】已到北门驿站，取件码1111\n【丰巢】取件码1234或5678，已到南门快递柜"
        let parsed = try parser.parseAll(text, requiresLabel: true)
        XCTAssertEqual(parsed.map(\.code), ["1111"])
        XCTAssertEqual(parsed.first?.unresolvedNotificationCount, 1)
        let candidates = try PickupSharedTextParser().candidates(from: text)
        let review = PickupCandidateReview(candidates: candidates)
        XCTAssertEqual(try review.validatedSelection().map { $0.candidate.code }, ["1111"])
    }

    func testEllipsisAndBulletTruncationRequireCorrection() throws {
        for mark in ["…", "...", "••"] {
            let text = "【丰巢】取件码8291\(mark)，已到北门丰巢柜"
            XCTAssertThrowsError(try parser.parseAll(text, requiresLabel: true)) { error in
                XCTAssertEqual(error as? PickupImportError, .ambiguousCode)
            }
            let candidate = try XCTUnwrap(imageExtractor.candidates(from: [imageLine(text)]).first)
            XCTAssertEqual(candidate.reviewIssue, .truncated)
            XCTAssertFalse(candidate.shouldSelectByDefault)
            var review = PickupCandidateReview(candidates: [candidate])
            let id = try XCTUnwrap(review.items.first?.id)
            review.setSelected(true, id: id)
            XCTAssertEqual(review.selectedCount, 0)
            try review.update(id: id, code: "829146", location: "北门丰巢柜")
            XCTAssertEqual(try review.validatedSelection().first?.candidate.code, "829146")
        }
    }

    func testAmbiguousPlaceBetweenTwoCodeRowsStaysUnknown() throws {
        let text = "取件码1234\n北门驿站\n取件码5678"
        let parsed = try parser.parseAll(text)
        XCTAssertEqual(parsed.map(\.location), [nil, nil])
        XCTAssertTrue(parsed.last?.locationRequiresConfirmation ?? false)
        let candidates = try PickupSharedTextParser().candidates(from: text)
        XCTAssertFalse(candidates.last?.shouldSelectByDefault ?? true)
    }

    func testChoiceAndCorrectionDoNotExtractUnrelatedURLOrAddressValues() throws {
        XCTAssertThrowsError(try parser.parse("取件码请到 https://example.invalid/829146 查看"))
        XCTAssertEqual(try parser.parseAll("取件码1234，帮助网址 https://example.invalid/829146").map(\.code), ["1234"])
        XCTAssertEqual(try parser.parseAll("取件码1234，地址更正为5678号楼").map(\.code), ["1234"])
    }

    func testObsoleteReferenceIsNotCountedAsAnUnrecognizedNewNotification() throws {
        let result = try parser.parseAll("旧取件码1234\n新取件码5678")
        XCTAssertEqual(result.map(\.code), ["5678"])
        XCTAssertEqual(result.first?.unresolvedNotificationCount, 0)
    }

    // Geometry from the user-reported screenshot; personal names, addresses and numbers replaced.
    private func logisticsCardFixture() -> [RecognizedTextLine] {
        [
            RecognizedTextLine(text: "示例地图小区", confidence: 0.5, minX: 0.6100628942583075, midY: 0.9513081396166425, width: 0.1509433940305548, height: 0.013081395383545247),
            RecognizedTextLine(text: "m 圆通快递 YT0000000000001", confidence: 0.5, minX: 0.05974843179146191, midY: 0.5704873620166673, width: 0.459119479939089, height: 0.018908996164145875),
            RecognizedTextLine(text: "复制", confidence: 1, minX: 0.5628930808718201, midY: 0.5705692487642414, width: 0.06603773731296347, height: 0.01613849765258224),
            RecognizedTextLine(text: "物流电话", confidence: 1, minX: 0.8144317337478257, midY: 0.569767441882697, width: 0.13528747558593746, height: 0.017553199624791294),
            RecognizedTextLine(text: "● 待取件昨天 11:03", confidence: 0.30000001192092896, minX: 0.06289308812418504, midY: 0.5348530134569323, width: 0.3427672822596663, height: 0.020410251915921163),
            RecognizedTextLine(text: "您今天有2个包裹待取件＞", confidence: 0.5, minX: 0.5660377345532296, midY: 0.5341262692601192, width: 0.3805031469312766, height: 0.018956764203282073),
            RecognizedTextLine(text: "示例市实验花园北区4号楼店", confidence: 1, minX: 0.1477987400183374, midY: 0.48909883721586317, width: 0.5094339661679026, height: 0.01889534921899838),
            RecognizedTextLine(text: "实验花园北区新4号楼2单元106", confidence: 1, minX: 0.1477987414661635, midY: 0.4556185628754677, width: 0.3773584915419756, height: 0.016088455868812024),
            RecognizedTextLine(text: "取件码：5-5-1234", confidence: 1, minX: 0.14465409780969352, midY: 0.40270953931008274, width: 0.45283016916048735, height: 0.02634931095702353),
            RecognizedTextLine(text: "复制", confidence: 1, minX: 0.6352201242660062, midY: 0.40261627912427317, width: 0.06918239270226423, height: 0.017441860013911126),
            RecognizedTextLine(text: "联系驿站", confidence: 1, minX: 0.7515723299365984, midY: 0.35895931165361933, width: 0.1415094278626523, height: 0.017605633802816878),
            RecognizedTextLine(text: "您的快件已到达【兔喜生活】（示例市实验花园北区4号", confidence: 0.5, minX: 0.11635219101530585, midY: 0.31241015201793476, width: 0.7987421585341632, height: 0.017621555985046333),
            RecognizedTextLine(text: "楼店）实验花园北区新4号楼2单元106，请及时取件，如…展开", confidence: 0.5, minX: 0.11635219166656253, midY: 0.2906942623132593, width: 0.7955975031448622, height: 0.0203556611504353),
            RecognizedTextLine(text: "查看更多物流信息～", confidence: 0.30000001192092896, minX: 0.11635220392323106, midY: 0.25723787199790343, width: 0.2987421326718088, height: 0.017605633802816878),
            RecognizedTextLine(text: "收 实验花园北区3号楼（新）1单元1503", confidence: 0.5, minX: 0.06583652010827026, midY: 0.2055607101772977, width: 0.6576726881124205, height: 0.02226143599675856),
            RecognizedTextLine(text: "收件人 137******42 号码保护中", confidence: 0.30000001192092896, minX: 0.11635220796922838, midY: 0.17814331083188994, width: 0.7138364630230403, height: 0.0161703427632649),
            RecognizedTextLine(text: "某某图书旗舰店", confidence: 0.30000001192092896, minX: 0.11635220229531065, midY: 0.11700581396398568, width: 0.49371068922139827, height: 0.01889534921899827),
        ]
    }

    func testLogisticsCardRecognizesLogoPrefixedCourierAndUnlabelledShop() throws {
        let results = try imageExtractor.candidates(from: logisticsCardFixture())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.code, "5-5-1234")
        XCTAssertEqual(results.first?.platform, "圆通")
        XCTAssertEqual(results.first?.location, "示例市实验花园北区4号楼店")
        XCTAssertFalse(results.first!.locationRequiresConfirmation)
    }

    func testShopTitleNeedsAlignedDetailAndGeometry() throws {
        let fixture = logisticsCardFixture()
        let withoutGeometry = fixture.map { imageLine($0.text) }
        XCTAssertNil(try imageExtractor.candidates(from: withoutGeometry).first?.location)
        let withoutDetail = fixture.filter { $0.text != "实验花园北区新4号楼2单元106" }
        XCTAssertNil(try imageExtractor.candidates(from: withoutDetail).first?.location)
        let misaligned = fixture.map { row in
            row.text == "示例市实验花园北区4号楼店"
                ? RecognizedTextLine(text: row.text, confidence: row.confidence, minX: 0.7,
                    midY: row.midY, width: row.width, height: row.height) : row
        }
        XCTAssertNil(try imageExtractor.candidates(from: misaligned).first?.location)
    }

    func testLogisticsCardsKeepCouriersAndShopsIndependent() throws {
        func row(_ text: String, _ y: Double) -> RecognizedTextLine {
            RecognizedTextLine(text: text, confidence: 0.95, minX: 0.15, midY: y, width: 0.55, height: 0.02)
        }
        let results = try imageExtractor.candidates(from: [
            row("m 圆通快递 YT0000000000001", 0.9),
            row("示例花园北区4号楼店", 0.86), row("北区4号楼2单元106", 0.82), row("取件码1234", 0.78),
            row("中通快递 0000000000002", 0.74),
            row("示例花园南区5号楼店", 0.70), row("南区5号楼1单元102", 0.66), row("取件码5678", 0.62),
        ])
        XCTAssertEqual(results.map(\.code), ["1234", "5678"])
        XCTAssertEqual(results.map(\.platform), ["圆通", "中通"])
        XCTAssertEqual(results.map(\.location), ["示例花园北区4号楼店", "示例花园南区5号楼店"])
    }

    func testCourierLogoCleanupRequiresLiteralCourierAndTrackingRow() throws {
        for text in ["YT0000000000001", "m 圆通快递旗舰店", "圆通快递客服 0000000000001"] {
            let results = try imageExtractor.candidates(from: [imageLine(text), imageLine("取件码1234")])
            XCTAssertNil(results.first?.platform, text)
        }
    }

    func testServiceSMSShopAndDetailedAddressAreOneLocationAcrossEntrances() throws {
        let text = "【兔喜生活】您有包裹已到达示例花园北区4号楼店，取件码为111-111-111，地址:花园北区新4号楼2单元106"
        for requiresLabel in [false, true] {
            let result = try parser.parseAll(text, requiresLabel: requiresLabel).first!
            XCTAssertEqual(result.code, "111-111-111")
            XCTAssertEqual(result.location, "示例花园北区4号楼店")
            XCTAssertFalse(result.locationRequiresConfirmation)
        }
        for candidate in [try PickupSharedTextParser().candidates(from: text).first!,
                          try imageExtractor.candidates(from: [imageLine(text)]).first!] {
            XCTAssertEqual(candidate.location, "示例花园北区4号楼店")
            XCTAssertFalse(candidate.locationRequiresConfirmation)
            XCTAssertEqual(PickupDirectory.displayLabel(for: candidate.platform!), "取件服务 · 兔喜")
        }
        XCTAssertNil(PickupDirectory.roles(in: text).courier)
        XCTAssertEqual(PickupDirectory.roles(in: text).service, "兔喜")
    }

    func testUnrelatedOrConflictingAddressMustNotBeSilentlyMerged() throws {
        for detail in ["花园北区新5号楼2单元106", "其他小区4号楼2单元106", "花园北区4号楼南门驿站"] {
            let result = try parser.parse("已到示例花园北区4号楼店，取件码1234，地址：" + detail)
            XCTAssertNil(result.location, detail)
            XCTAssertTrue(result.locationRequiresConfirmation, detail)
        }
        let result = try parser.parse("已到北门驿站，取件码1234，收货地址：家园4号楼101")
        XCTAssertEqual(result.location, "北门驿站")
        XCTAssertFalse(result.locationRequiresConfirmation)
    }

    func testServiceBrandLabelsNeverAssertCourierOwnership() {
        for entry in PickupDirectory.services {
            for alias in entry.aliases {
                XCTAssertEqual(PickupDirectory.displayLabel(for: alias), "取件服务 · " + entry.name)
                XCTAssertNil(PickupDirectory.roles(in: "【" + alias + "】取件码1234").courier)
            }
        }
        XCTAssertEqual(PickupDirectory.displayLabel(for: "圆通"), "圆通")
        XCTAssertEqual(PickupDirectory.roles(in: "【兔喜生活】您的圆通包裹已到北门驿站").courier, "圆通")
    }

    private func imageLine(
        _ text: String,
        confidence: Float = 0.92
    ) -> RecognizedTextLine {
        RecognizedTextLine(
            text: text,
            confidence: confidence,
            minX: 0,
            midY: 0
        )
    }
}
