import XCTest
@testable import Shouxia

final class PickupImageShareTests: XCTestCase {
    func testSharedTextKeepsCodesAndPlaceWithoutPrivateRawText() throws {
        let candidates = try PickupSharedTextParser().candidates(
            from: "【菜鸟】包裹已到北门驿站，取件码 3-2-4012、829146，电话13812345678，运单98765432109876"
        )
        XCTAssertEqual(candidates.map(\.code), ["3-2-4012", "829146"])
        XCTAssertEqual(candidates.map(\.location), ["北门驿站", "北门驿站"])
        for candidate in candidates {
            XCTAssertFalse(candidate.sanitizedImportText.contains("13812345678"))
            XCTAssertFalse(candidate.sanitizedImportText.contains("98765432109876"))
        }
    }

    func testSharedTextNotificationsDoNotBorrowEachOthersPlace() throws {
        let candidates = try PickupSharedTextParser().candidates(
            from: "【菜鸟】包裹已到北门驿站，取件码 829146\n【丰巢】快递已到南门快递柜，取件码 654321\n取件码 123456"
        )
        XCTAssertEqual(candidates.map(\.location), ["北门驿站", "南门快递柜", nil])
        XCTAssertEqual(candidates.map(\.platform), ["菜鸟", "丰巢", nil])
    }

    func testMultilineSingleNotificationKeepsPlace() throws {
        let candidates = try PickupSharedTextParser().candidates(from: "包裹已到北门驿站\n取件码：AB1234")
        XCTAssertEqual(candidates.first?.code, "AB1234")
        XCTAssertEqual(candidates.first?.location, "北门驿站")
    }

    func testExplicitBareCodeAcceptedWithoutIncidentalNumberFallback() throws {
        let parser = PickupSharedTextParser()
        XCTAssertEqual(try parser.candidates(from: "AB1234").first?.code, "AB1234")
        XCTAssertEqual(try parser.candidates(from: "3-2-4012").first?.code, "3-2-4012")
        XCTAssertThrowsError(try parser.candidates(from: "会议室 829146，下周见"))
        XCTAssertThrowsError(try parser.candidates(from: "13812345678"))
        XCTAssertThrowsError(try parser.candidates(from: "hello"))
        XCTAssertThrowsError(try parser.candidates(from: String(repeating: "a", count: 65537)))
    }

    func testSharedTextSourceAndMixedBatchRoundTripWithMinimumFields() async throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        let repository = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        let textItem = PickupImageShareBatch.Item(code: "829146", location: "北门驿站", platform: "菜鸟", source: .sharedText)
        let imageItem = PickupImageShareBatch.Item(code: "654321", location: nil, platform: nil)
        try queue.enqueue(.init(items: [textItem, imageItem]))
        _ = try await repository.receiveSharedImages(from: queue)
        let records = try await repository.records()
        XCTAssertEqual(records.first { $0.code == "829146" }?.source, .sharedText)
        XCTAssertEqual(records.first { $0.code == "654321" }?.source, .imageRecognition)
        XCTAssertEqual(PickupSource.sharedText.displayName, "文字分享")
        let decoded = try JSONDecoder().decode([PickupRecord].self, from: Data(contentsOf: root.appendingPathComponent("pickups.json")))
        XCTAssertEqual(decoded, records)
        XCTAssertTrue(try queue.pendingFiles().isEmpty)
    }

    func testLegacyQueueWithoutSourceStillImportsAsImage() throws {
        let legacy = batch()
        let data = try JSONEncoder().encode(legacy)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("source"))
        let decoded = try JSONDecoder().decode(PickupImageShareBatch.self, from: data).validated()
        XCTAssertEqual(decoded.items.first?.effectiveSource, .imageRecognition)
        let spoofed = PickupImageShareBatch.Item(code: "829146", location: nil, platform: nil, source: .smsAutomation)
        XCTAssertThrowsError(try PickupImageShareBatch(items: [spoofed]).validated())
    }

    func testMissingContextDoesNotSilentlyMergeWithKnownLocation() throws {
        let text = try PickupSharedTextParser().candidates(from: "取件码829146")
        let image = ImagePickupCandidate(code: "829146", location: "北门驿站", platform: "菜鸟", confidence: 0.8, isLabelled: true)
        let merged = ImagePickupBatchMerger().merge([text, [image]])
        XCTAssertEqual(merged.count, 2)
        XCTAssertNil(merged.first?.location)
        XCTAssertEqual(merged.last?.location, "北门驿站")
    }

    func testPartialImportFailureRemainsVisibleWhenWidgetRefreshAlsoFails() async throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        try queue.enqueue(batch())
        try Data("bad batch".utf8).write(to: queue.directory.appendingPathComponent("bad.json"))
        let repository = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        let receipt = try await repository.receiveSharedImages(from: queue)
        let message = try XCTUnwrap(receipt.message(surfaceRefreshFailed: true))
        XCTAssertTrue(message.contains("已从分享添加 1 个"))
        XCTAssertTrue(message.contains("1 批分享未处理完成"))
        XCTAssertTrue(message.contains("已保留"))
        XCTAssertTrue(message.contains("小组件暂时无法更新"))
        XCTAssertEqual(try queue.pendingFiles().count, 1)
    }

    func testAllFailedReceiptDoesNotClaimZeroItemsWereAdded() {
        let receipt = PickupImageShareReceipt(failedBatchCount: 2)
        let message = receipt.message(surfaceRefreshFailed: false)
        XCTAssertFalse(message?.contains("已添加") ?? true)
        XCTAssertTrue(message?.contains("2 批分享未处理完成") ?? false)
        XCTAssertNil(PickupImageShareReceipt().message(surfaceRefreshFailed: false))
        XCTAssertEqual(PickupImageShareReceipt(duplicateCount: 1).message(surfaceRefreshFailed: false),
                       "分享的取件码已在收下中")
    }

    func testRecognitionFailuresDistinguishRecoveryAndHideProviderDetails() {
        let oversized = PickupShareFeedback.recognitionFailure(PickupImageShareError.oversizedImage, isImage: true)
        let longText = PickupShareFeedback.recognitionFailure(PickupSharedTextParser.SharedTextError.tooLong, isImage: false)
        let noCode = PickupShareFeedback.recognitionFailure(ImagePickupRecognitionError.noPickupCode, isImage: true)
        XCTAssertTrue(oversized.contains("图片过大"))
        XCTAssertTrue(longText.contains("文字太长"))
        XCTAssertTrue(noCode.contains("没有找到明确的取件码"))
        let providerError = NSError(domain: "private-provider-path", code: 99,
                                    userInfo: [NSLocalizedDescriptionKey: "/private/source/message"])
        let failure = PickupShareFeedback.recognitionFailure(providerError, isImage: false)
        XCTAssertTrue(failure.contains("重新分享"))
        XCTAssertFalse(failure.contains("/private/"))
        let grouped = PickupShareFeedback.groupedFailures([oversized, longText, oversized])
        XCTAssertEqual(grouped, ["2 项：\(oversized)", "1 项：\(longText)"])
    }

    func testQueueFailureGivesRecoveryWithoutExposingSystemError() throws {
        let root = try workspace()
        let blocked = root.appendingPathComponent("blocked")
        try Data("existing file".utf8).write(to: blocked)
        let queue = PickupImageShareQueue(directory: blocked)
        do {
            try queue.enqueue(batch())
            XCTFail("Saving into a file must fail")
        } catch {
            let message = PickupShareFeedback.saveFailure(error)
            XCTAssertTrue(message.contains("已保留当前勾选"))
            XCTAssertFalse(message.contains(root.path))
        }
        XCTAssertEqual(try Data(contentsOf: blocked), Data("existing file".utf8))
        XCTAssertTrue(PickupShareFeedback.saveFailure(CocoaError(.fileWriteOutOfSpace)).contains("存储空间不足"))
        XCTAssertTrue(PickupShareFeedback.saveFailure(PickupImageShareError.queueFull).contains("先打开收下"))
    }

    func testSameCodeDifferentPlacesSurvivesQueueCommitReopenAndRetry() async throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        let file = root.appendingPathComponent("records.json")
        let items = [
            PickupImageShareBatch.Item(code: "1234", location: "北门驿站", platform: "中通"),
            PickupImageShareBatch.Item(code: "1234", location: "南门便利店", platform: "圆通"),
        ]
        XCTAssertEqual(Set(items.map(\.id)).count, 2)
        let batch = PickupImageShareBatch(items: items)
        try queue.enqueue(batch)
        let repository = PickupRepository(fileURL: file)
        let first = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(first.addedCount, 2)
        let saved = try await PickupRepository(fileURL: file).records()
        XCTAssertEqual(saved.map(\.location), ["北门驿站", "南门便利店"])
        for record in saved { _ = try await repository.complete(id: record.id) }
        try queue.enqueue(batch)
        let retry = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(retry.duplicateCount, 2)
        XCTAssertEqual(retry.addedCount, 0)
        XCTAssertTrue(try queue.pendingFiles().isEmpty)
    }

    func testLegacyCompletedQueueRetryKeepsOldFingerprint() async throws {
        let root = try workspace()
        let file = root.appendingPathComponent("records.json")
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        let package = batch()
        let legacyFingerprint = try PickupParser().parse("取件码 3-2-4012\n分享批次 \(package.id.uuidString)").fingerprint
        let legacy = PickupRecord(id: UUID(), rawText: "取件码 3-2-4012", code: "3-2-4012",
                                  location: "已更正地点", platform: "菜鸟", createdAt: Date(),
                                  source: .imageRecognition, fingerprint: legacyFingerprint,
                                  importBatchID: package.id, completedAt: Date(), archivedAt: nil)
        let original = try JSONEncoder().encode([legacy])
        try original.write(to: file)
        try queue.enqueue(package)
        let receipt = try await PickupRepository(fileURL: file).receiveSharedImages(from: queue)
        XCTAssertEqual(receipt.addedCount, 0)
        XCTAssertEqual(receipt.duplicateCount, 1)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    func testReviewDefaultsAndAlternativeSelectionAreSharedPolicy() throws {
        let candidates = try PickupSharedTextParser().candidates(from: "取件码1234或取件码5678，已到北门驿站")
        var review = PickupCandidateReview(candidates: candidates)
        XCTAssertEqual(review.selectedCount, 0)
        let first = review.items[0].id, second = review.items[1].id
        review.setSelected(true, id: first)
        XCTAssertEqual(try review.validatedSelection().map { $0.candidate.code }, ["1234"])
        review.setSelected(true, id: second)
        XCTAssertEqual(try review.validatedSelection().map { $0.candidate.code }, ["5678"])
        var forged = candidates
        for index in forged.indices { forged[index].userConfirmed = true }
        XCTAssertThrowsError(try PickupCandidateReview.validate(forged))

        let strong = ImagePickupCandidate(code: "1111", location: "北门驿站", platform: "中通", confidence: 0.95, isLabelled: true)
        let weak = ImagePickupCandidate(code: "2222", location: "南门驿站", platform: "中通", confidence: 0.4, isLabelled: true)
        let implicit = ImagePickupCandidate(code: "3333", location: "南门驿站", platform: nil, confidence: 0.95, isLabelled: false)
        let mixed = PickupCandidateReview(candidates: [strong, weak, implicit])
        XCTAssertEqual(try mixed.validatedSelection().map { $0.candidate.code }, ["1111", "2222", "3333"])
    }

    func testBatchDefaultsSelectFiveIncludingLowConfidenceAndMissingLocation() throws {
        let candidates = (1...5).map { i in
            ImagePickupCandidate(code: "5-5-123" + String(i), location: i == 5 ? nil : "北门驿站",
                                 platform: "圆通", confidence: 0.3, isLabelled: true)
        }
        var review = PickupCandidateReview(candidates: candidates)
        XCTAssertEqual(review.selectedCount, 5)
        XCTAssertEqual(try review.validatedSelection().count, 5)
        XCTAssertTrue(review.items.allSatisfy { $0.candidate.confirmationHint != nil })
        let id = review.items[2].id
        review.setSelected(false, id: id)
        XCTAssertEqual(review.selectedCount, 4)
        XCTAssertFalse(try review.validatedSelection().contains { $0.id == id })
        try review.update(id: review.items[0].id, code: "5-5-4321", location: "南门驿站")
        XCTAssertFalse(review.items.first { $0.id == id }!.selected)
    }

    func testRiskyCandidatesRemainUnselectedBesideDefaultSelectedParcels() throws {
        let normal = ImagePickupCandidate(code: "1234", location: nil, platform: nil, confidence: 0.2, isLabelled: true)
        var truncated = normal
        truncated.reviewIssue = .truncated
        truncated.userConfirmed = true // A flag alone must not bypass an unresolved risk.
        var conflict = normal
        conflict.locationRequiresConfirmation = true
        let alternatives = try PickupSharedTextParser().candidates(from: "取件码5678或829146")
        var review = PickupCandidateReview(candidates: [normal, truncated, conflict] + alternatives)
        XCTAssertEqual(review.selectedCount, 1)
        XCTAssertEqual(try review.validatedSelection().map { $0.candidate.code }, ["1234"])
        for item in review.items where item.candidate.reviewIssue == .truncated || item.candidate.locationRequiresConfirmation {
            review.setSelected(true, id: item.id)
        }
        XCTAssertEqual(review.selectedCount, 1)
        XCTAssertThrowsError(try PickupCandidateReview.validate([normal, truncated]))
    }

    func testReviewEditsPreserveIdentitySourceAndAreAtomicOnValidationFailure() throws {
        let candidate = ImagePickupCandidate(code: "1234", location: "北门驿站", platform: "中通", confidence: 0.95, isLabelled: true)
        var review = PickupCandidateReview(candidates: [candidate], sources: [candidate.id: .sharedText])
        let original = review.items
        let id = original[0].id
        for invalid in ["", "123", "13812345678", "错误码", "12/34"] {
            XCTAssertThrowsError(try review.update(id: id, code: invalid, location: "南门便利店"))
            XCTAssertEqual(review.items, original)
        }
        XCTAssertThrowsError(try review.update(id: id, code: "5678", location: "电话13812345678"))
        XCTAssertEqual(review.items, original)
        try review.update(id: id, code: " ａｂ－１２３４ ", location: " 南门便利店 ")
        XCTAssertEqual(review.items[0].id, id)
        XCTAssertEqual(review.items[0].source, .sharedText)
        XCTAssertEqual(review.items[0].candidate.code, "AB-1234")
        XCTAssertEqual(review.items[0].candidate.location, "南门便利店")
        XCTAssertEqual(review.selectedCount, 1)
        XCTAssertEqual(original[0].candidate.code, "1234")
    }

    func testReviewDuplicateEditRejectedButSameCodeDifferentLocationRemains() throws {
        let first = ImagePickupCandidate(code: "1234", location: "北门驿站", platform: "中通", confidence: 0.95, isLabelled: true)
        let second = ImagePickupCandidate(code: "1234", location: "南门驿站", platform: "中通", confidence: 0.95, isLabelled: true)
        var review = PickupCandidateReview(candidates: [first, second])
        XCTAssertEqual(try review.validatedSelection().count, 2)
        let before = review.items
        XCTAssertThrowsError(try review.update(id: review.items[1].id, code: "1234", location: "北门驿站"))
        XCTAssertEqual(review.items, before)
    }

    func testReviewedTextEditSavesMinimumFieldsAndOriginalSourceThroughQueue() async throws {
        let root = try workspace()
        let input = "【菜鸟】取件码1234或5678，已到北门驿站，电话13812345678"
        let candidates = try PickupSharedTextParser().candidates(from: input)
        let sources = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, PickupSource.sharedText) })
        var review = PickupCandidateReview(candidates: candidates, sources: sources)
        let id = review.items[1].id
        try review.update(id: id, code: "7890", location: "南门便利店")
        let selected = try review.validatedSelection()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        try queue.enqueue(.init(items: selected.map {
            .init(code: $0.candidate.code, location: $0.candidate.location,
                  platform: $0.candidate.platform, source: $0.source)
        }))
        let data = try Data(contentsOf: XCTUnwrap(queue.pendingFiles().first))
        let payload = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(payload.contains("13812345678"))
        XCTAssertFalse(payload.contains("alternativeGroup"))
        XCTAssertFalse(payload.contains("reviewIssue"))
        let repository = PickupRepository(fileURL: root.appendingPathComponent("records.json"))
        let receipt = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(receipt.addedCount, 1)
        let records = try await repository.records()
        XCTAssertEqual(records.first?.code, "7890")
        XCTAssertEqual(records.first?.location, "南门便利店")
        XCTAssertEqual(records.first?.source, .sharedText)
    }

    private func workspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    private func batch(id: UUID = UUID(), code: String = "3-2-4012", location: String? = "北门驿站") -> PickupImageShareBatch {
        PickupImageShareBatch(id: id, items: [.init(code: code, location: location, platform: "菜鸟")])
    }

    func testQueueContainsOnlySelectedMinimumFields() throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        let expected = batch()
        try queue.enqueue(expected)
        let file = try XCTUnwrap(queue.pendingFiles().first)
        XCTAssertEqual(try queue.read(file), expected)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["version", "id", "items"])
        let items = try XCTUnwrap(json["items"] as? [[String: Any]])
        XCTAssertEqual(Set(items[0].keys), ["code", "location", "platform"])
    }

    func testInvalidAndEmptyBatchesCannotEnterQueue() throws {
        let queue = PickupImageShareQueue(directory: try workspace().appendingPathComponent("queue"))
        XCTAssertThrowsError(try queue.enqueue(.init(items: [])))
        XCTAssertThrowsError(try queue.enqueue(batch(code: "13812345678")))
        XCTAssertThrowsError(try queue.enqueue(batch(location: "联系电话13812345678")))
        XCTAssertThrowsError(try queue.enqueue(batch(location: "北门\n取件码 9999")))
        let item = batch().items[0]
        XCTAssertThrowsError(try queue.enqueue(.init(items: [item, item])))
        XCTAssertEqual(try queue.pendingFiles().count, 0)
    }

    func testReceiveSavesSourceFieldsAndAcknowledgesAfterCommit() async throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        let repository = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        let expected = batch(location: "一号柜")
        try queue.enqueue(expected)
        let receipt = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(receipt.addedCount, 1)
        XCTAssertEqual(receipt.failedBatchCount, 0)
        XCTAssertTrue(try queue.pendingFiles().isEmpty)
        let records = try await repository.records()
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.location, "一号柜")
        XCTAssertEqual(record.locationSource, .recognized)
        XCTAssertEqual(record.source, .imageRecognition)
        XCTAssertEqual(record.importBatchID, expected.id)
        let reopened = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        let persisted = try await reopened.records()
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted.first?.code, expected.items.first?.code)
    }

    func testRetryAfterCompletionDoesNotRestoreConsumedPackage() async throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        let repository = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        let package = batch()
        try queue.enqueue(package)
        _ = try await repository.receiveSharedImages(from: queue)
        let records = try await repository.records()
        _ = try await repository.complete(id: XCTUnwrap(records.first).id)
        // Models a crash after database commit and before queue acknowledgement.
        try queue.enqueue(package)
        let retried = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(retried.addedCount, 0)
        XCTAssertEqual(retried.duplicateCount, 1)
        let after = try await repository.records()
        XCTAssertEqual(after.count, 1)
        XCTAssertTrue(try XCTUnwrap(after.first).isCompleted)
    }

    func testFuturePackageMayReuseCompletedCodeAndDefaultLocation() async throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        let repository = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        try queue.enqueue(batch())
        _ = try await repository.receiveSharedImages(from: queue)
        let first = try await repository.records()
        _ = try await repository.complete(id: XCTUnwrap(first.first).id)
        try queue.enqueue(batch(location: nil))
        let next = try await repository.receiveSharedImages(from: queue, defaultLocation: "南门驿站")
        XCTAssertEqual(next.addedCount, 1)
        let records = try await repository.records()
        let pending = try XCTUnwrap(records.first { !$0.isCompleted })
        XCTAssertEqual(pending.location, "南门驿站")
        XCTAssertEqual(pending.locationSource, .commonDefault)
    }

    func testBrokenPackageRetainedWhileValidPackageContinues() async throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        try queue.enqueue(batch())
        let corrupt = queue.directory.appendingPathComponent("bad.json")
        try Data("invalid json".utf8).write(to: corrupt)
        let repository = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        let receipt = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(receipt.addedCount, 1)
        XCTAssertEqual(receipt.failedBatchCount, 1)
        XCTAssertEqual(try queue.pendingFiles().map { $0.resolvingSymlinksInPath() }, [corrupt.resolvingSymlinksInPath()])
    }

    func testDatabaseFailureDoesNotAcknowledgeOrOverwriteOldData() async throws {
        let root = try workspace()
        let file = root.appendingPathComponent("pickups.json")
        let original = Data("broken existing records".utf8)
        try original.write(to: file)
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        try queue.enqueue(batch())
        let repository = PickupRepository(fileURL: file)
        let receipt = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(receipt.addedCount, 0)
        XCTAssertEqual(receipt.failedBatchCount, 1)
        XCTAssertEqual(try queue.pendingFiles().count, 1)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    func testSameCodeWithNewContextIsNotDiscarded() async throws {
        let root = try workspace()
        let repository = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        _ = try await repository.importText("取件码 3-2-4012", source: .smsAutomation)
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        try queue.enqueue(batch())
        let receipt = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(receipt.addedCount, 1)
        XCTAssertEqual(receipt.duplicateCount, 0)
        let records = try await repository.records()
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.first?.source, .smsAutomation)
    }
}
