import XCTest
@testable import Shouxia

final class PickupShareTextTests: XCTestCase {
    func testGroupsSelectedRecordsByLocationInFirstAppearanceOrder() {
        let records = [
            record("3-2-4012", location: " 北门驿站 ", platform: "淘宝"),
            record("829146", location: "丰巢"),
            record("1-3-5066", location: "北门驿站", platform: "拼多多"),
        ]
        XCTAssertEqual(PickupShareText.make(records: records), """
        帮忙取这 3 件快递：

        北门驿站
        取件码：3-2-4012（淘宝）
        取件码：1-3-5066（拼多多）

        丰巢
        取件码：829146
        """)
    }

    func testMissingLocationsStayUnknownAndCommonDefaultRemainsQualified() {
        let records = [
            record("1001", location: nil),
            record("1002", location: " \n ", platform: " "),
            record("1003", location: "北门驿站", locationSource: .commonDefault),
        ]
        XCTAssertEqual(PickupShareText.make(records: records), """
        帮忙取这 3 件快递：

        地点待确认
        取件码：1001
        取件码：1002

        北门驿站
        取件码：1003 · 常用取件点，请确认
        """)
    }

    func testSameCodeAtDifferentLocationsIsNotDroppedAndRawTextNeverAppears() {
        let records = [record("1234", location: "北门"), record("1234", location: "南门")]
        let text = PickupShareText.make(records: records)
        XCTAssertEqual(text.components(separatedBy: "取件码：1234").count - 1, 2)
        XCTAssertTrue(text.contains("2 件"))
        XCTAssertFalse(text.contains("13800138000"))
        XCTAssertFalse(text.contains("隐私商品"))
        XCTAssertFalse(text.contains(records[0].fingerprint))
        XCTAssertFalse(text.contains(records[0].id.uuidString))
        XCTAssertFalse(text.contains("https://"))
    }

    func testEmptySelectionHasNoShareTextAndMaximumSelectionIsComplete() {
        XCTAssertEqual(PickupShareText.make(records: []), "")
        let records = (1000..<1100).map { record(String($0), location: "北门") }
        let text = PickupShareText.make(records: records)
        XCTAssertTrue(text.hasPrefix("帮忙取这 100 件快递："))
        XCTAssertEqual(text.components(separatedBy: "取件码：").count - 1, 100)
        XCTAssertTrue(text.contains("取件码：1099"))
    }

    func testOnlySuccessfulPackageShareFinishesHandoff() {
        let records = [record("1234", location: "北门")]
        let url = URL(fileURLWithPath: "/tmp/example.shouxia")
        let content = HandoffShareContent(url: url, records: records)
        XCTAssertEqual(content.activityItems.first as? URL, url)
        XCTAssertEqual(content.recordsToHandOff(completed: true, error: nil), records)
        XCTAssertTrue(content.recordsToHandOff(completed: false, error: nil).isEmpty)
        XCTAssertTrue(content.recordsToHandOff(completed: true, error: shareError).isEmpty)
    }

    private var shareError: NSError { NSError(domain: "ShareTest", code: 1) }

    private func record(
        _ code: String,
        location: String?,
        platform: String? = nil,
        locationSource: PickupLocationSource? = nil
    ) -> PickupRecord {
        PickupRecord(
            id: UUID(), rawText: "手机号13800138000，隐私商品及运单信息",
            code: code, location: location, platform: platform, createdAt: Date(),
            source: .paste, fingerprint: "private-fingerprint", locationSource: locationSource,
            completedAt: nil, archivedAt: nil
        )
    }
}
