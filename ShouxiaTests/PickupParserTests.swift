import XCTest
@testable import Shouxia

final class PickupParserTests: XCTestCase {
    private let parser = PickupParser()

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
}
