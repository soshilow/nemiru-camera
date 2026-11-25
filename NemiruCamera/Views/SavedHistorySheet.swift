import SwiftData
import SwiftUI

/// ページ（検索・服・靴）ごとの「保存・履歴」一覧画面。各ページからシートで開く。
struct SavedHistorySheet: View {
    enum Segment: String, CaseIterable, Identifiable {
        case saved = "保存済み項目"
        case history = "検索履歴"

        var id: String { rawValue }
    }

    let scope: SearchScope
    @Bindable var coordinator: SearchCoordinator

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SavedSearchItem.createdAt, order: .reverse)
    private var allSavedItems: [SavedSearchItem]

    @Query(sort: \SearchHistoryItem.searchedAt, order: .reverse)
    private var allHistoryItems: [SearchHistoryItem]

    @State private var selectedSegment: Segment
    @State private var isClearHistoryDialogPresented = false

    init(scope: SearchScope, coordinator: SearchCoordinator, initialSegment: Segment) {
        self.scope = scope
        self.coordinator = coordinator
        _selectedSegment = State(initialValue: initialSegment)
    }

    /// このページの保存済み項目（最近使った順）
    private var savedItems: [SavedSearchItem] {
        SavedSearchItem.sortedByRecentUse(allSavedItems.filter { $0.scope == scope })
    }

    /// このページの検索履歴（キーワードごと・新しい順）
    private var historyGroups: [SearchHistoryGroup] {
        SearchHistoryGroup.make(from: allHistoryItems, scope: scope)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("表示切り替え", selection: $selectedSegment) {
                    ForEach(Segment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 10)

                switch selectedSegment {
                case .saved:
                    savedListView
                case .history:
                    historyListView
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("\(scope.tabTitle)の保存・履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                if selectedSegment == .history && !historyGroups.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("すべて消去", role: .destructive) {
                            isClearHistoryDialogPresented = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .confirmationDialog(
                "\(scope.tabTitle)ページの検索履歴をすべて消去しますか？",
                isPresented: $isClearHistoryDialogPresented,
                titleVisibility: .visible
            ) {
                Button("履歴をすべて消去", role: .destructive) {
                    clearHistory()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private var savedListView: some View {
        if savedItems.isEmpty {
            ContentUnavailableView(
                "保存済みの項目はありません",
                systemImage: "bookmark",
                description: Text("\(scope.tabTitle)ページの「＋ キーワードを保存」をタップすると、入力中のキーワードを登録できます。")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    ForEach(savedItems) { item in
                        Button {
                            coordinator.applySavedItem(item)
                            coordinator.showToast("保存済みの条件を入力しました")
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Text(item.keyword)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Spacer(minLength: 4)

                                if let sizeText = CameraSpec.displayText(item.sizeSpec) {
                                    Text(sizeText)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteSavedItem(item)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    Text("長押しすると削除できます。")
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.top, 0, for: .scrollContent)
        }
    }

    @ViewBuilder
    private var historyListView: some View {
        if historyGroups.isEmpty {
            ContentUnavailableView(
                "検索履歴はありません",
                systemImage: "clock",
                description: Text("\(scope.tabTitle)ページから各サービスを起動すると、検索したキーワードが記録されます。")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    ForEach(historyGroups) { group in
                        Button {
                            coordinator.applyHistory(group)
                            coordinator.showToast("履歴の条件を入力しました")
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Text(group.keyword)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Spacer(minLength: 4)

                                if let sizeText = CameraSpec.displayText(group.sizeSpec) {
                                    Text(sizeText)
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteHistoryGroup(group)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    Text("長押しすると削除できます。")
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.top, 0, for: .scrollContent)
        }
    }

    private func deleteSavedItem(_ item: SavedSearchItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func deleteHistoryGroup(_ group: SearchHistoryGroup) {
        for item in group.items {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    private func clearHistory() {
        for item in allHistoryItems where item.scope == scope {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}
