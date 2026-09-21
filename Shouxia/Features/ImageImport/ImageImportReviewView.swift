import SwiftUI

struct ImageImportReview: Identifiable {
    let id = UUID()
    let candidates: [ImagePickupCandidate]
    let imageCount: Int
    let failedImageCount: Int
}


struct ImageImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("commonPickupLocation") private var commonPickupLocation = ""

    let review: ImageImportReview
    let store: PickupStore

    @State private var selectedIDs: Set<String>
    @State private var isSaving = false

    init(review: ImageImportReview, store: PickupStore) {
        self.review = review
        self.store = store
        _selectedIDs = State(initialValue: Set(review.candidates.map(\.id)))
    }

    private var selectedCandidates: [ImagePickupCandidate] {
        review.candidates.filter { selectedIDs.contains($0.id) }
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
                            ForEach(review.candidates) { candidate in
                                Button {
                                    toggle(candidate)
                                } label: {
                                    ImageCandidateRow(
                                        candidate: candidate,
                                        isSelected: selectedIDs.contains(candidate.id)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("不保存原图和未选中的文字。")
                            .font(.caption)
                            .foregroundStyle(ShouxiaPalette.softInk)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)

                        if let normalizedCommonPickupLocation {
                            Label(
                                "地点未识别时，将使用常用取件点“\(normalizedCommonPickupLocation)”",
                                systemImage: "house"
                            )
                            .font(.caption)
                            .foregroundStyle(ShouxiaPalette.mutedInk)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                        }

                        Button {
                            Task {
                                isSaving = true
                                await store.importImageCandidates(
                                    selectedCandidates,
                                    defaultLocation: normalizedCommonPickupLocation
                                )
                                dismiss()
                            }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(
                                    selectedCandidates.count > 1
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
            .navigationTitle("确认图片识别结果")
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
        .tint(ShouxiaPalette.mutedInk)
        .fontDesign(.rounded)
    }

    private var title: String {
        review.candidates.count > 1
            ? "找到了 \(review.candidates.count) 个不重复的取件码"
            : "请确认这个取件码"
    }

    private var detail: String {
        if review.imageCount > 1 {
            let failedDetail = review.failedImageCount > 0
                ? "，其中 \(review.failedImageCount) 张没有识别成功"
                : ""
            return "已合并 \(review.imageCount) 张图片并按取件码去重\(failedDetail)。请选择真正需要收下的取件码。"
        }
        return review.candidates.count > 1
            ? "请选择这张图片里真正需要收下的取件码。"
            : "图片里没有足够明确的标签，请核对后再添加。"
    }

    private var normalizedCommonPickupLocation: String? {
        let normalized = commonPickupLocation
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func toggle(_ candidate: ImagePickupCandidate) {
        if selectedIDs.contains(candidate.id) {
            selectedIDs.remove(candidate.id)
        } else {
            selectedIDs.insert(candidate.id)
        }
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
                        ? ShouxiaPalette.breezePressed
                        : ShouxiaPalette.softInk
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(candidate.code)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(ShouxiaPalette.ink)

                Text(candidate.location ?? "地点没有识别出来")
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let platform = candidate.platform {
                Text(platform)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(ShouxiaPalette.skyWash, in: Capsule())
            }
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
            "\(isSelected ? "已选择" : "未选择")，取件码 \(candidate.code)，\(candidate.location ?? "地点未识别")"
        )
    }
}
