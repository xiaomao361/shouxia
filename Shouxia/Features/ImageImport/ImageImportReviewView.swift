import SwiftUI

struct ImageImportReview: Identifiable {
    let id = UUID()
    let candidates: [ImagePickupCandidate]
    let imageCount: Int
    let failedImageCount: Int
}


struct ImageImportReviewView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @AppStorage("commonPickupLocation") private var commonPickupLocation = ""

    let review: ImageImportReview
    @ObservedObject var store: PickupStore

    @State private var candidateReview: PickupCandidateReview
    @State private var editingItem: PickupCandidateReview.Item?
    @State private var saveMessage: String?
    @State private var isSaving = false

    init(review: ImageImportReview, store: PickupStore) {
        self.review = review
        self.store = store
        _candidateReview = State(initialValue: PickupCandidateReview(candidates: review.candidates))
    }

    private var selectedCandidates: [ImagePickupCandidate] {
        candidateReview.items.filter(\.selected).map(\.candidate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ShouxiaBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 7) {
                            Text(title)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(ShouxiaPalette.ink)

                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(ShouxiaPalette.mutedInk)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 10)

                        VStack(spacing: 10) {
                            ForEach(candidateReview.items) { item in
                                reviewRowLayout {
                                    Button {
                                        candidateReview.setSelected(!item.selected, id: item.id)
                                    } label: {
                                        ImageCandidateRow(candidate: item.candidate, isSelected: item.selected)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(item.candidate.reviewIssue == .truncated || item.candidate.locationRequiresConfirmation || isSaving)
                                    Button("更正") { editingItem = item }
                                        .disabled(isSaving)
                                        .frame(minWidth: 44, minHeight: 44)
                                        .accessibilityLabel("更正取件码 \(item.candidate.code) 的信息")
                                }
                            }
                        }

                        Text("不保存原图和未选中的文字。")
                            .font(.caption)
                            .foregroundStyle(ShouxiaPalette.softInk)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)

                        if selectedCandidates.contains(where: { $0.location == nil && !$0.locationRequiresConfirmation }),
                           let normalizedCommonPickupLocation {
                            Label(
                                "缺少地点的记录将使用常用取件点“\(normalizedCommonPickupLocation)”",
                                systemImage: "house"
                            )
                            .font(.caption)
                            .foregroundStyle(ShouxiaPalette.mutedInk)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                        }

                        if let saveMessage {
                            Text(saveMessage).font(.subheadline).foregroundStyle(ShouxiaPalette.warningInk)
                        }
                        Button {
                            Task {
                                isSaving = true
                                saveMessage = nil
                                do {
                                    let selected = try candidateReview.validatedSelection().map(\.candidate)
                                    let saved = await store.importImageCandidates(selected, defaultLocation: normalizedCommonPickupLocation)
                                    if saved { dismiss() }
                                    else if case let .error(message)? = store.notice { saveMessage = message }
                                    else { saveMessage = "暂时无法保存，请重试" }
                                } catch { saveMessage = error.localizedDescription }
                                isSaving = false
                            }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(
                                    selectedCandidates.isEmpty ? "请先选择取件码"
                                        : selectedCandidates.count > 1
                                            ? "添加 \(selectedCandidates.count) 个取件码"
                                            : "添加这个取件码"
                                )
                            }
                        }
                        .buttonStyle(ShouxiaPrimaryButtonStyle())
                        .disabled(selectedCandidates.isEmpty || isSaving)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("核对取件码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $editingItem) { item in
            PickupCandidateEditView(item: item, review: $candidateReview)
        }
        .tint(ShouxiaPalette.mutedInk)
        .shouxiaRoundedFont()
    }

    private var title: String { "核对取件信息" }

    private var detail: String {
        var parts: [String] = []
        if review.imageCount > 1 { parts.append("共 \(review.imageCount) 张图片，相同取件信息已合并。") }
        if review.failedImageCount > 0 { parts.append("\(review.failedImageCount) 张图片没有识别成功，请单独核对。") }
        let unresolved = review.candidates.map(\.unresolvedNotificationCount).max() ?? 0
        if unresolved > 0 { parts.append("另有 \(unresolved) 条通知未找到明确取件码，请单独核对。") }
        parts.append("默认选中可添加的取件码，可取消不需要的项目。")
        return parts.joined(separator: "\n")
    }

    private var reviewRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    private var normalizedCommonPickupLocation: String? {
        let normalized = commonPickupLocation
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }


}

private struct ImageCandidateRow: View {
    let candidate: ImagePickupCandidate
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(
                    isSelected
                        ? ShouxiaPalette.accentInk
                        : ShouxiaPalette.softInk
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(candidate.code)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(ShouxiaPalette.ink)

                if let hint = candidate.confirmationHint {
                    Label(hint, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(ShouxiaPalette.warningInk)
                }
                Text(candidate.location ?? "地点未识别")
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let brand = candidate.platform {
                    ShouxiaBrandBadge(brand: PickupDirectory.displayLabel(for: brand))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            ShouxiaPalette.paper.opacity(isSelected ? 0.98 : 0.76),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isSelected
                        ? ShouxiaPalette.breezePressed.opacity(0.52)
                        : ShouxiaPalette.line,
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(isSelected ? "已选择" : "未选择")，取件码 \(candidate.code)，\(candidate.location ?? "地点未识别")，\(candidate.confirmationHint ?? "")"
        )
    }
}
