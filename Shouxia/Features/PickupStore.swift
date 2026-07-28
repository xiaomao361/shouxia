import Foundation
import Observation

@MainActor
@Observable
final class PickupStore {
    private(set) var records: [PickupRecord] = []
    private(set) var notice: Notice?
    private(set) var lastCompleted: PickupRecord?

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
        records
            .filter { $0.isCompleted && !$0.isArchived }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var archivedRecords: [PickupRecord] {
        records
            .filter(\.isArchived)
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    func load() async {
        do {
            records = try await repository.records()
        } catch {
            notice = .error("暂时无法读取本地取件信息")
        }
    }

    func importText(_ text: String, source: PickupSource) async {
        do {
            let result = try await repository.importText(text, source: source)
            records = try await repository.records()
            switch result {
            case let .added(record):
                notice = .success("已收好取件码 \(record.code)")
            case .duplicate:
                notice = .neutral("这条取件通知已经收过了")
            }
        } catch let error as PickupImportError {
            notice = .error(error.localizedDescription)
        } catch {
            notice = .error("没有收好，再试一次")
        }
    }

    func importImageCandidates(_ candidates: [ImagePickupCandidate]) async {
        guard !candidates.isEmpty else { return }

        do {
            var addedCodes: [String] = []
            var duplicateCount = 0

            for candidate in candidates {
                let result = try await repository.importText(
                    candidate.sanitizedImportText,
                    source: .imageRecognition
                )
                switch result {
                case let .added(record):
                    addedCodes.append(record.code)
                case .duplicate:
                    duplicateCount += 1
                }
            }

            records = try await repository.records()
            switch (addedCodes.count, duplicateCount) {
            case (1, _):
                notice = .success("已从图片收好取件码 \(addedCodes[0])")
            case let (count, _) where count > 1:
                notice = .success("已从图片收好 \(count) 个取件码")
            case (0, _):
                notice = .neutral("这些取件码已经收过了")
            default:
                notice = .error("没有收好，再试一次")
            }
        } catch let error as PickupImportError {
            notice = .error(error.localizedDescription)
        } catch {
            notice = .error("图片里的取件码没有收好")
        }
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
            notice = .error("这件包裹还没有成功收下")
        }
    }

    func undoLastCompletion() async {
        guard let lastCompleted else { return }
        do {
            _ = try await repository.undoCompletion(id: lastCompleted.id)
            records = try await repository.records()
            self.lastCompleted = nil
            notice = .neutral("已经放回待取列表")
        } catch {
            notice = .error("暂时无法撤销")
        }
    }

    func restoreToPending(_ record: PickupRecord) async {
        do {
            _ = try await repository.undoCompletion(id: record.id)
            records = try await repository.records()
            notice = .neutral("已经放回待取列表")
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
                notice = .error("这条记录不在归档中")
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
