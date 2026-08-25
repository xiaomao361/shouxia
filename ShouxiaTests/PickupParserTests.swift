import XCTest
@testable import Shouxia

final class PickupParserTests: XCTestCase {
    private let parser = PickupParser()
    private let imageExtractor = ImagePickupExtractor()
    private let imageBatchMerger = ImagePickupBatchMerger()

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

    func testFingerprintIgnoresWhitespace() throws {
        let first = try parser.parse("取件码 123456，已到 北门菜鸟驿站")
        let second = try parser.parse("取件码123456，已到北门菜鸟驿站")

        XCTAssertEqual(first.fingerprint, second.fingerprint)
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

    func testImageBatchMergerDeduplicatesByCodeAndKeepsRicherCandidate() {
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

        XCTAssertEqual(merged.map(\.code), ["3-2-8309", "11-2-1755"])
        XCTAssertEqual(merged.first?.location, "北门驿站")
        XCTAssertEqual(merged.first?.platform, "淘宝")
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
