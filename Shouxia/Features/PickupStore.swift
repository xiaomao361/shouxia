import Foundation
import Observation

@MainActor
@Observable
final class PickupStore {
    private(set) var records: [PickupRecord] = []
    private(set) var notice: Notice?
    private(set) var lastCompleted: PickupRecord?
    private(set) var loadFailed = false

    private let repository: PickupRepository

    init(repository: PickupRepository = .shared) {
        self.repository = repository
    }

    var pendingRecords: [PickupRecord] {
        records
            .filter { !$0.isCompleted && !$0.isArchived }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var historyRecords: [PickupRecord] {
        PickupHistoryRange.all.records(from: records)
    }

    var archivedRecords: [PickupRecord] {
        records
            .filter(\.isArchived)
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    func load() async {
        do {
            records = try await repository.records()
            loadFailed = false
            PickupLiveActivityController.shared.refresh()
            if await repository.surfaceRefreshFailed {
                notice = .error("取件信息已保存，小组件暂时无法更新")
            }
        } catch {
            loadFailed = true
            PickupLiveActivityController.shared.refresh()
            notice = .error("暂时无法读取本地取件信息")
        }
    }

    func importText(
        _ text: String,
        source: PickupSource,
        defaultLocation: String? = nil
    ) async {
        do {
            let result = try await repository.importText(
                text,
                source: source,
                defaultLocation: defaultLocation
            )
            records = try await repository.records()
            switch result {
            case let .added(record):
                notice = .success("已添加取件码 \(record.code)")
            case .duplicate:
                notice = .neutral("这条取件信息已添加")
            case let .batch(added, duplicateCount):
                notice = added.isEmpty ? .neutral("这些取件码已添加")
                    : .success((duplicateCount > 0
                        ? "已添加 \(added.count) 个取件码，\(duplicateCount) 个已存在"
                        : "已添加 \(added.count) 个取件码"))
            }
        } catch let error as PickupImportError {
            notice = .error(error.localizedDescription)
        } catch {
            notice = .error("添加失败，请重试")
        }
    }

    func importClipboardAutomatically(
        _ text: String,
        defaultLocation: String? = nil
    ) async {
        do {
            guard let result = try await repository.importAutomaticClipboardText(
                text,
                defaultLocation: defaultLocation
            ) else { return }
            let added = result.addedRecords
            guard !added.isEmpty else { return }
            records = try await repository.records()
            notice = .success(added.count == 1
                ? "已添加取件码 \(added[0].code)"
                : "已添加 \(added.count) 个取件码")
        } catch is PickupImportError {
            // Automatic checks stay quiet when the clipboard is unrelated.
        } catch {
            notice = .error("剪贴板导入失败，请重试")
        }
    }

    func importImageCandidates(
        _ candidates: [ImagePickupCandidate],
        defaultLocation: String? = nil
    ) async {
        guard !candidates.isEmpty else { return }

        do {
            var addedCodes: [String] = []
            var duplicateCount = 0
            var seenCodes: Set<String> = []
            let importBatchID = UUID()

            for candidate in candidates where seenCodes.insert(candidate.code).inserted {
                let result = try await repository.importText(
                    candidate.sanitizedImportText,
                    source: .imageRecognition,
                    importBatchID: importBatchID,
                    defaultLocation: defaultLocation
                )
                switch result {
                case let .added(record):
                    addedCodes.append(record.code)
                case .duplicate:
                    duplicateCount += 1
                case let .batch(added, duplicates):
                    addedCodes.append(contentsOf: added.map(\.code))
                    duplicateCount += duplicates
                }
            }

            records = try await repository.records()
            switch (addedCodes.count, duplicateCount) {
            case (1, _):
                notice = .success("已添加取件码 \(addedCodes[0])")
            case let (count, _) where count > 1:
                notice = .success("已添加 \(count) 个取件码")
            case (0, _):
                notice = .neutral("这些取件码已添加")
            default:
                notice = .error("添加失败，请重试")
            }
        } catch let error as PickupImportError {
            notice = .error(error.localizedDescription)
        } catch {
            notice = .error("图片导入失败，请重试")
        }
    }

    func importHandoffPackage(_ package: PickupHandoffPackage) async -> Bool {
        do {
            let summary = try await repository.importHandoffPackage(package)
            records = try await repository.records()
            switch (summary.addedCount, summary.duplicateCount) {
            case let (added, _) where added > 0:
                notice = .success("已添加 \(added) 件代取包裹")
            case (0, _):
                notice = .neutral("这些代取包裹已添加")
            default:
                notice = .error("交接包没有导入成功")
            }
            return true
        } catch let error as PickupHandoffError {
            notice = .error(error.localizedDescription)
        } catch {
            notice = .error("交接包没有导入成功，请重新打开")
        }
        return false
    }

    func showNotice(_ notice: Notice) {
        self.notice = notice
    }

    func beginCompletion(_ record: PickupRecord) {
        var completed = record
        completed.completedAt = Date()
        lastCompleted = completed
        records.removeAll { $0.id == record.id }
        notice = nil
    }

    func persistCompletion(_ record: PickupRecord) async {
        do {
            lastCompleted = try await repository.complete(id: record.id)
            records = try await repository.records()
        } catch {
            records = (try? await repository.records()) ?? records
            lastCompleted = nil
            notice = .error("未能标记为已取到，请重试")
        }
    }

    func handOff(_ selectedRecords: [PickupRecord]) async -> Bool {
        do {
            let handedOff = try await repository.handOff(ids: selectedRecords.map(\.id))
            guard handedOff.count == selectedRecords.count else {
                notice = .error("这些包裹没有成功完成交接")
                return false
            }
            records = try await repository.records()
            notice = .success("已交给别人，完成 \(handedOff.count) 件交接")
            return true
        } catch {
            records = (try? await repository.records()) ?? records
            notice = .error("这些包裹没有成功完成交接")
            return false
        }
    }

    func undoLastCompletion() async {
        guard let lastCompleted else { return }
        do {
            _ = try await repository.undoCompletion(id: lastCompleted.id)
            records = try await repository.records()
            self.lastCompleted = nil
            notice = .neutral("已设为待取")
        } catch {
            notice = .error("暂时无法撤销")
        }
    }

    func update(_ record: PickupRecord, code: String, location: String?) async throws -> PickupRecord {
        guard let updated = try await repository.update(
            id: record.id,
            code: code,
            location: location
        ) else {
            throw PickupRecordEditError.missingRecord
        }
        records = try await repository.records()
        notice = .success("取件信息已更正")
        return updated
    }

    func restoreToPending(_ record: PickupRecord) async {
        do {
            _ = try await repository.undoCompletion(id: record.id)
            records = try await repository.records()
            notice = .neutral("已设为待取")
        } catch {
            notice = .error("暂时无法恢复这条记录")
        }
    }

    func archive(_ record: PickupRecord) async {
        do {
            _ = try await repository.archive(id: record.id)
            records = try await repository.records()
        } catch {
            notice = .error("暂时无法归档这条记录")
        }
    }

    func restoreFromArchive(_ record: PickupRecord) async {
        do {
            _ = try await repository.restoreFromArchive(id: record.id)
            records = try await repository.records()
        } catch {
            notice = .error("暂时无法恢复这条记录")
        }
    }

    func permanentlyDelete(_ record: PickupRecord) async {
        do {
            guard try await repository.permanentlyDelete(id: record.id) else {
                notice = .error("这条记录已不在收下记录中")
                return
            }
            records = try await repository.records()
        } catch {
            notice = .error("暂时无法删除这条记录")
        }
    }

    func dismissNotice() {
        notice = nil
    }

    func dismissUndo(for id: UUID) {
        guard lastCompleted?.id == id else { return }
        lastCompleted = nil
    }

    enum Notice: Equatable {
        case success(String)
        case neutral(String)
        case error(String)

        var message: String {
            switch self {
            case let .success(message), let .neutral(message), let .error(message):
                message
            }
        }
    }
}
