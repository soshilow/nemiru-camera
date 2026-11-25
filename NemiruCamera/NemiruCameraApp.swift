import SwiftData
import SwiftUI

@main
struct NemiruCameraApp: App {
    private let modelContainer: ModelContainer
    @State private var selectedTab: AppTab = .page(.camera)
    /// ページごとの入力状態（キーワード・販売状況・並び替え・トースト）
    @State private var coordinators: [SearchScope: SearchCoordinator] = Dictionary(
        uniqueKeysWithValues: SearchScope.allCases.map { ($0, SearchCoordinator(filter: MyCamera.initialFilter(for: $0))) }
    )

    init() {
        // 並び替え（4択）が収まるよう、セグメントの文字を少し小さくする（販売状況などとも揃える）
        let segmentFont = UIFont.systemFont(ofSize: 12.5, weight: .regular)
        let selectedFont = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: segmentFont], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: selectedFont], for: .selected)

        do {
            let schema = Schema([
                SavedSearchItem.self,
                SearchHistoryItem.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.modelContainer = container
            Self.seedInitialSavedItemsIfNeeded(in: container.mainContext)
            Self.cleanUpSavedItems(in: container.mainContext)
        } catch {
            fatalError("SwiftData ModelContainerの初期化に失敗しました: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                ForEach(SearchScope.allCases) { scope in
                    HomeView(coordinator: coordinators[scope]!, scope: scope)
                        .tabItem {
                            Label(scope.tabTitle, systemImage: scope.tabSymbol)
                        }
                        .tag(AppTab.page(scope))
                }

                SettingsView()
                    .tabItem {
                        Label("設定", systemImage: "gearshape")
                    }
                    .tag(AppTab.settings)
            }
        }
        .modelContainer(modelContainer)
    }

    @MainActor
    private static func seedInitialSavedItemsIfNeeded(in context: ModelContext) {
        let seedKey = "hasSeededInitialSearchItems_v1"
        guard !UserDefaults.standard.bool(forKey: seedKey) else { return }

        let descriptor = FetchDescriptor<SavedSearchItem>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0

        if existingCount == 0 {
            let now = Date()
            let samples = [
                SavedSearchItem(
                    keyword: "トラベル三脚",
                    createdAt: now.addingTimeInterval(-300)
                ),
                SavedSearchItem(
                    keyword: "Nikon Z6II",
                    scope: .camera,
                    createdAt: now.addingTimeInterval(-200)
                ),
                SavedSearchItem(
                    keyword: "FUJIFILM X100V",
                    scope: .camera,
                    createdAt: now.addingTimeInterval(-100)
                ),
                SavedSearchItem(
                    keyword: "SIGMA 24-70mm F2.8 DG DN Art",
                    scope: .camera,
                    createdAt: now
                )
            ]

            for sample in samples {
                context.insert(sample)
            }
            try? context.save()
        }

        UserDefaults.standard.set(true, forKey: seedKey)
    }

    /// 保存済み項目の整理（起動のたびに実行。何度実行しても結果は同じ）
    /// - 同じページ内の同じキーワード（＋条件）の重複を最近使った1件にまとめる
    @MainActor
    private static func cleanUpSavedItems(in context: ModelContext) {
        guard let items = try? context.fetch(FetchDescriptor<SavedSearchItem>()) else { return }

        var keptByKey: [String: SavedSearchItem] = [:]
        for item in SavedSearchItem.sortedByRecentUse(items) {
            let key = item.scope.rawValue + "|" + item.groupKey
            if keptByKey[key] == nil {
                keptByKey[key] = item
            } else {
                context.delete(item)
            }
        }

        if context.hasChanges {
            try? context.save()
        }
    }
}
