import SafariServices
import SwiftData
import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var coordinator: SearchCoordinator
    /// このページの種類（検索・iPhone）。保存済みと履歴はページごとに分ける
    let scope: SearchScope

    @Query(sort: \SavedSearchItem.createdAt, order: .reverse)
    private var allSavedItems: [SavedSearchItem]

    @Query(sort: \SearchHistoryItem.searchedAt, order: .reverse)
    private var allHistoryItems: [SearchHistoryItem]

    @FocusState private var focusedField: FocusField?

    @State private var isDropdownExpanded = false
    @State private var isHistoryExpanded = false
    @State private var isClearHistoryDialogPresented = false
    /// 開いている「保存・履歴」一覧シート（nil は閉じている）
    @State private var savedHistorySheetSegment: SavedHistorySheet.Segment?
    @State private var pullDistance: CGFloat = 0
    @State private var isPullArmed = false
    @State private var isScannerPresented = false
    @State private var activeSafariDestination: SafariDestination?

    private enum FocusField: Hashable {
        case keyword
    }

    /// このページの保存済み項目
    private var savedItems: [SavedSearchItem] {
        allSavedItems.filter { $0.scope == scope }
    }

    /// 最近使った順の保存済み項目
    private var orderedSavedItems: [SavedSearchItem] {
        SavedSearchItem.sortedByRecentUse(savedItems)
    }

    private struct SafariDestination: Identifiable {
        let id = UUID()
        let url: URL
    }

    /// 下に引っ張ってリセットが発動する距離
    private let pullThreshold: CGFloat = 90

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 検索窓と保存済み項目は、スクロールしても画面上部に固定する
                searchAndSavedCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .zIndex(1)

                ScrollView {
                    VStack(spacing: 20) {
                        filterCard

                        serviceGridSection

                        historySection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                    .background(alignment: .top) {
                        PullOffsetMarker()
                    }
                }
                .coordinateSpace(.named(PullOffsetMarker.coordinateSpaceName))
                .modifier(
                    PullToResetModifier(
                        pullDistance: $pullDistance,
                        isArmed: $isPullArmed,
                        threshold: pullThreshold,
                        onTrigger: performPullReset
                    )
                )
                .overlay(alignment: .top) {
                    pullIndicator
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
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
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $isScannerPresented) {
                BarcodeScannerView { scannedText, isBookTitle in
                    coordinator.filter.keyword = scannedText
                    coordinator.showToast(
                        isBookTitle
                            ? "書籍タイトルを入力しました"
                            : "バーコードを入力しました"
                    )
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $savedHistorySheetSegment) { segment in
                SavedHistorySheet(scope: scope, coordinator: coordinator, initialSegment: segment)
            }
            .sheet(item: $activeSafariDestination) { destination in
                SafariWebView(url: destination.url)
                    .ignoresSafeArea()
            }
            .overlay(alignment: .top) {
                if let toast = coordinator.toast {
                    ToastBannerView(toast: toast) {
                        let action = toast.action
                        coordinator.dismissToast()
                        action?()
                    }
                    .id(toast.id)
                    .padding(.top, 6)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - 下に引っ張ってリセット

    @ViewBuilder
    private var pullIndicator: some View {
        if pullDistance > 6 {
            HStack(spacing: 6) {
                Image(systemName: isPullArmed ? "arrow.counterclockwise" : "arrow.down")
                    .font(.system(size: 13, weight: .bold))
                Text(isPullArmed ? "離すとリセット" : "引っ張ってリセット")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isPullArmed ? Color.red : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: pullDistance)
            .opacity(min(1, pullDistance / (pullThreshold * 0.6)))
            .animation(.easeOut(duration: 0.15), value: isPullArmed)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - 検索バー ＆ 保存済み検索項目ドロップダウン（一体型グループカード）

    private var searchAndSavedCard: some View {
        VStack(spacing: 0) {
            searchInputRow

            Divider()
                .padding(.leading, 16)

            savedItemsHeader

            if orderedSavedItems.isEmpty {
                Divider()
                    .padding(.leading, 16)

                Text("保存済みの検索項目はありません")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
            } else {
                ForEach(pinnedSavedItems) { item in
                    Divider()
                        .padding(.leading, 16)

                    savedItemRow(item)
                }

                if !extraSavedItems.isEmpty {
                    if isDropdownExpanded {
                        extraSavedItemsList
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Divider()
                        .padding(.leading, 16)

                    showMoreSavedItemsButton
                }
            }
        }
        // 画面上部に固定するので、うっすら青の背景と縁取りで目立たせる
        .background {
            ZStack {
                Color(.secondarySystemGroupedBackground)
                Color.blue.opacity(0.07)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.45), lineWidth: 1)
        }
    }

    private var searchInputRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(scope.placeholder, text: $coordinator.filter.keyword)
                .focused($focusedField, equals: .keyword)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .onSubmit {
                    focusedField = nil
                }

            if !coordinator.filter.keyword.isEmpty {
                Button {
                    coordinator.filter.keyword = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("キーワードをクリア")
            }

            Button {
                focusedField = nil
                isScannerPresented = true
            } label: {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.blue)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("バーコードを読み取る")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    /// 常に表示する保存済み項目の件数
    private let pinnedSavedItemCount = 3

    /// 常に表示する上位の保存済み項目
    private var pinnedSavedItems: [SavedSearchItem] {
        Array(orderedSavedItems.prefix(pinnedSavedItemCount))
    }

    /// 「さらに表示」で開く保存済み項目
    private var extraSavedItems: [SavedSearchItem] {
        Array(orderedSavedItems.dropFirst(pinnedSavedItemCount))
    }

    private var savedItemsHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "bookmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.blue)

            Text("保存済みの検索項目")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            Text("\(savedItems.count)")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(.tertiarySystemFill), in: Capsule())

            Spacer()

            listButton(for: .saved)
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
    }

    /// 「保存・履歴」一覧シートを開くボタン
    private func listButton(for segment: SavedHistorySheet.Segment) -> some View {
        Button {
            focusedField = nil
            savedHistorySheetSegment = segment
        } label: {
            HStack(spacing: 2) {
                Text("一覧")
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(segment == .saved ? "保存済み項目の一覧を開く" : "検索履歴の一覧を開く")
    }

    private func savedItemRow(_ item: SavedSearchItem) -> some View {
        Button {
            focusedField = nil
            coordinator.applySavedItem(item)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isDropdownExpanded = false
            }
        } label: {
            HStack(spacing: 8) {
                Text(item.keyword)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let sizeText = PhoneSpec.displayText(item.sizeSpec) {
                    Text(sizeText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 36)
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

    /// 4件目以降。5件分を超えたらこの中でスクロールする
    private var extraSavedItemsList: some View {
        let items = extraSavedItems
        let rowHeight: CGFloat = 37
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    Divider()
                        .padding(.leading, 16)

                    savedItemRow(item)
                }
            }
        }
        .frame(height: min(CGFloat(items.count), 5) * rowHeight)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var showMoreSavedItemsButton: some View {
        Button {
            focusedField = nil
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isDropdownExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(isDropdownExpanded ? "閉じる" : "さらに表示（あと\(extraSavedItems.count)件）")
                    .font(.system(size: 13, weight: .medium))

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(isDropdownExpanded ? 180 : 0))
            }
            .foregroundStyle(.blue)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - ③ 常時表示の絞り込み条件カード

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("絞り込み条件")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                if isCurrentConditionSaved {
                    Label("保存済み", systemImage: "checkmark")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        saveCurrentCondition()
                    } label: {
                        Text("＋ キーワードを保存")
                            .font(.footnote.weight(.medium))
                    }
                    .disabled(!searchFilter.hasSearchableKeyword)
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                if scope == .iphone {
                    modelRow

                    Divider()
                        .padding(.leading, 16)

                    storageRow

                    Divider()
                        .padding(.leading, 16)

                    simFreeRow

                    Divider()
                        .padding(.leading, 16)
                }

                saleStatusRow

                Divider()
                    .padding(.leading, 16)

                sortOptionRow
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var saleStatusRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("販売状況")
                    .font(.system(size: 15))

                Spacer(minLength: 8)

                Picker("販売状況", selection: $coordinator.filter.saleStatus) {
                    ForEach(SaleStatus.allCases) { status in
                        Text(status.pickerTitle).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }

            if coordinator.filter.saleStatus == .soldOut {
                Label("売れた価格（相場）を確認するモードです。メルカリとヤフオク（落札相場）はアプリ内のブラウザで開きます。", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .animation(.easeInOut(duration: 0.2), value: coordinator.filter.saleStatus)
    }

    // MARK: - 機種・容量・SIM（iPhone ページ）

    /// キーワードの先頭に入っている機種
    private var selectedModel: PhoneModel? {
        PhoneModel.detect(in: coordinator.filter.keyword)
    }

    /// 機種（1つ選ぶ）。選ぶとキーワードの先頭に機種名が入る
    private var modelRow: some View {
        HStack(spacing: 12) {
            Text("機種")
                .font(.system(size: 15))

            Spacer(minLength: 8)

            Menu {
                Button("指定なし") {
                    coordinator.filter.keyword = PhoneModel.replacing(in: coordinator.filter.keyword, with: nil)
                }
                ForEach(PhoneModel.generations, id: \.title) { generation in
                    Section(generation.title) {
                        ForEach(generation.models) { model in
                            Button(model.keyword) {
                                coordinator.filter.keyword = PhoneModel.replacing(in: coordinator.filter.keyword, with: model)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedModel?.keyword ?? "機種を選択")
                        .font(.system(size: 15))
                        .foregroundStyle(selectedModel == nil ? Color.secondary : Color.primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .accessibilityLabel("機種")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// 容量（1つ選ぶ。選択中をもう一度タップすると解除）
    private var storageRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("容量")
                    .font(.system(size: 15))

                Spacer(minLength: 8)

                if coordinator.filter.storage != nil {
                    Button("クリア") {
                        coordinator.filter.storage = nil
                    }
                    .font(.footnote.weight(.medium))
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(PhoneStorage.allCases) { storage in
                    let isSelected = coordinator.filter.storage == storage
                    Button {
                        coordinator.filter.storage = isSelected ? nil : storage
                    } label: {
                        Text(storage.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.blue : Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// 行のどこをタップしても1回で切り替わるよう、行全体をボタンにする
    private var simFreeRow: some View {
        Button {
            coordinator.filter.simFreeOnly.toggle()
        } label: {
            HStack {
                Text("SIMフリーのみ")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Toggle("SIMフリーのみ", isOn: .constant(coordinator.filter.simFreeOnly))
                    .labelsHidden()
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("SIMフリーのみ")
        .accessibilityValue(coordinator.filter.simFreeOnly ? "オン" : "オフ")
        .accessibilityAddTraits(.isToggle)
    }

    private var sortOptionRow: some View {
        HStack(spacing: 12) {
            Text("並び替え")
                .font(.system(size: 15))

            Spacer(minLength: 8)

            // 4つ並べるので、文字を少し小さくして収める
            Picker("並び替え", selection: $coordinator.filter.sortOption) {
                ForEach(SortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 250)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - ④ サービス起動グリッド（検索ページは8社、iPhone ページは10社）

    private var serviceGridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(coordinator.filter.saleStatus == .soldOut ? "売れた価格（相場）を検索" : "アプリを起動して検索")
                    .font(.footnote)
                    .foregroundStyle(coordinator.filter.saleStatus == .soldOut ? Color.orange : Color.secondary)

                Spacer()
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(MarketplaceService.services(for: scope)) { service in
                    serviceButton(for: service)
                }
            }
        }
    }

    private func serviceButton(for service: MarketplaceService) -> some View {
        let isSoldModeUnsupported = coordinator.filter.saleStatus == .soldOut && !service.supportsSoldSearch
        let isExclusionUnsupported = service.showsExclusionWarning
            && !coordinator.filter.parsedKeyword.excludeTerms.isEmpty
        let soldCaption: String
        if service.isPhoneShop {
            soldCaption = "売り切れ検索なし"
        } else if scope == .iphone && service == .amazon {
            soldCaption = "相場なし・販売価格"
        } else {
            soldCaption = "相場なし・新品価格"
        }
        // 機種名以外の語（色・除外ワードなど）を入れていても、機種・容量だけで検索するサービス
        let isKeywordIgnored = service.searchesByModelOnly
            && !PhoneModel.replacing(in: coordinator.filter.keyword, with: nil).isEmpty
        let isModelUnavailable = service.searchesByModelOnly
            && PhoneModel.detect(in: coordinator.filter.keyword)?.nicosumaSlug == nil
        let caption = [
            isSoldModeUnsupported ? soldCaption : nil,
            isModelUnavailable ? "iPhone全体の一覧" : nil,
            isKeywordIgnored ? "機種・容量のみで検索" : (isExclusionUnsupported ? "除外ワード非対応" : nil)
        ].compactMap { $0 }.joined(separator: "・")

        return Button {
            launchService(service, inAppSafari: false)
        } label: {
            // 3列に並べるため、サービス名の下に補足（最大2行）を置く縦並びにする
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(service.brandColor)
                        .frame(width: 7, height: 7)

                    Text(service.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                if !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 46)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                copySearchURL(for: service)
            } label: {
                Label("検索URLをコピー", systemImage: "doc.on.doc")
            }

            Button {
                launchService(service, inAppSafari: true)
            } label: {
                Label("Safari（Web版）で開く", systemImage: "safari")
            }
        }
    }

    // MARK: - ⑤ 検索履歴（ページごと・キーワード単位）

    /// このページの検索履歴を、同じキーワードごとにまとめたもの（新しい順）
    private var historyGroups: [SearchHistoryGroup] {
        SearchHistoryGroup.make(from: allHistoryItems, scope: scope)
    }

    /// 常に表示する履歴の件数
    private let pinnedHistoryCount = 5

    private var historySection: some View {
        let groups = historyGroups
        let visible = isHistoryExpanded ? groups : Array(groups.prefix(pinnedHistoryCount))
        let hiddenCount = groups.count - pinnedHistoryCount

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("検索履歴")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                if !groups.isEmpty {
                    Button("すべて消去") {
                        isClearHistoryDialogPresented = true
                    }
                    .font(.footnote.weight(.medium))
                    .tint(.red)
                    .padding(.trailing, 8)
                }

                listButton(for: .history)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                if groups.isEmpty {
                    Text("検索履歴はありません")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                } else {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, group in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 16)
                        }
                        historyRow(group)
                    }

                    if hiddenCount > 0 {
                        Divider()
                            .padding(.leading, 16)

                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                isHistoryExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(isHistoryExpanded ? "閉じる" : "さらに表示（あと\(hiddenCount)件）")
                                    .font(.system(size: 13, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .rotationEffect(.degrees(isHistoryExpanded ? 180 : 0))
                            }
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func historyRow(_ group: SearchHistoryGroup) -> some View {
        Button {
            focusedField = nil
            coordinator.applyHistory(group)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Text(group.keyword)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let sizeText = PhoneSpec.displayText(group.sizeSpec) {
                    Text(sizeText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
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

    // MARK: - Actions

    /// 実際に検索に使う条件
    private var searchFilter: SearchFilterState {
        coordinator.filter
    }

    /// URL を組み立てるときのページ情報
    private var searchContext: SearchContext {
        SearchContext(scope: scope)
    }

    /// このページで保存・履歴に残す容量・SIM条件
    private func sizeSpec(for filter: SearchFilterState) -> String? {
        PhoneSpec.make(scope: scope, filter: filter)
    }

    private func performPullReset() {
        focusedField = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if !coordinator.resetAll() {
            coordinator.showToast("リセットする内容はありません", style: .info)
        }
    }

    private var isCurrentConditionSaved: Bool {
        let filter = searchFilter
        guard filter.hasSearchableKeyword else { return false }
        let key = filter.groupKey(scope: scope)
        return savedItems.contains { $0.groupKey == key }
    }

    private func saveCurrentCondition() {
        let filter = searchFilter
        let trimmed = filter.trimmedKeyword
        guard filter.hasSearchableKeyword else {
            coordinator.showToast("検索キーワードを入力してください", style: .warning)
            return
        }

        let key = filter.groupKey(scope: scope)
        if let existing = savedItems.first(where: { $0.groupKey == key }) {
            existing.markUsed()
            coordinator.showToast("この条件は保存済みです（先頭に移動しました）", style: .info)
            return
        }

        // キーワード（iPhone ページは容量・SIM条件も）を保存する。販売状況・並び替えは保存しない
        let newItem = SavedSearchItem(keyword: trimmed, scope: scope, sizeSpec: sizeSpec(for: filter))
        modelContext.insert(newItem)
        try? modelContext.save()

        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        coordinator.showToast("キーワードを保存しました")
    }

    private func launchService(_ service: MarketplaceService, inAppSafari: Bool) {
        focusedField = nil
        let filter = searchFilter
        let trimmed = filter.trimmedKeyword
        guard filter.hasSearchableKeyword else {
            coordinator.showToast(
                trimmed.isEmpty ? "検索キーワードを入力してください" : "除外ワード以外のキーワードを入力してください",
                style: .warning
            )
            return
        }

        guard let webURL = SearchURLBuilder.buildURL(for: service, filter: filter, context: searchContext) else {
            coordinator.showToast("検索URLの生成に失敗しました", style: .error)
            return
        }

        recordHistory(for: service, keyword: trimmed, filter: filter)

        // 売り切れ（相場）検索は、アプリに渡すと指定が効かないサービスがあるため、アプリ内ブラウザで開く。
        // iPhone ページのカテゴリ指定はアプリで開く。
        // ただしヤフオクはアプリにカテゴリを渡せないため、iPhone ページではアプリ内ブラウザで開く。
        let opensInAppBrowser = (filter.saleStatus == .soldOut && service.opensSoldSearchInAppBrowser)
            || (scope != .general && service == .yahooAuctions)
            || service.alwaysOpensInAppBrowser
        if inAppSafari || opensInAppBrowser {
            activeSafariDestination = SafariDestination(url: webURL)
            return
        }

        let targetURL = SearchURLBuilder.buildAppLaunchURL(for: service, filter: filter, context: searchContext) ?? webURL
        UIApplication.shared.open(targetURL, options: [:]) { success in
            guard !success, targetURL != webURL else { return }
            Task { @MainActor in
                UIApplication.shared.open(webURL)
            }
        }
    }

    private func copySearchURL(for service: MarketplaceService) {
        let filter = searchFilter
        guard filter.hasSearchableKeyword else {
            coordinator.showToast("検索キーワードを入力してください", style: .warning)
            return
        }

        guard let url = SearchURLBuilder.buildURL(for: service, filter: filter, context: searchContext) else {
            coordinator.showToast("検索URLの生成に失敗しました", style: .error)
            return
        }

        UIPasteboard.general.string = url.absoluteString
        coordinator.showToast("\(service.displayName)の検索URLをコピーしました")
    }

    private func recordHistory(for service: MarketplaceService, keyword: String, filter: SearchFilterState) {
        let history = SearchHistoryItem(
            keyword: keyword,
            serviceName: service.rawValue,
            scope: scope,
            sizeSpec: sizeSpec(for: filter),
            saleStatus: filter.saleStatus,
            sortOption: filter.sortOption
        )
        modelContext.insert(history)
        try? modelContext.save()
    }

    private func deleteSavedItem(_ item: SavedSearchItem) {
        // 削除・保存した後のモデルのプロパティを読むと、iOS のバージョンによってはクラッシュするので先に取り出す
        let keyword = item.keyword
        withAnimation {
            modelContext.delete(item)
            try? modelContext.save()
        }
        coordinator.showToast("「\(keyword)」を保存済みから削除しました", style: .info)
    }

    private func deleteHistoryGroup(_ group: SearchHistoryGroup) {
        withAnimation {
            for item in group.items {
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }

    private func clearHistory() {
        withAnimation {
            for item in allHistoryItems where item.scope == scope {
                modelContext.delete(item)
            }
            try? modelContext.save()
            isHistoryExpanded = false
        }
        coordinator.showToast("検索履歴を消去しました", style: .info)
    }
}

// MARK: - Helper Views

private struct ToastBannerView: View {
    let toast: ToastData
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.style.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(toast.style.tint)

            Text(toast.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            if let actionTitle = toast.actionTitle {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.blue)
                        .padding(.leading, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(toast.style.tint.opacity(toast.style == .success ? 0 : 0.35), lineWidth: 1))
        .allowsHitTesting(toast.actionTitle != nil)
        .accessibilityElement(children: .combine)
    }
}

private struct SafariWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - 下に引っ張ってリセット

/// スクロール内容の上端位置を測るための目印（iOS 17 用）
private struct PullOffsetMarker: View {
    static let coordinateSpaceName = "homeScroll"

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: PullOffsetPreferenceKey.self,
                value: proxy.frame(in: .named(Self.coordinateSpaceName)).minY
            )
        }
        .frame(height: 0)
    }
}

private struct PullOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 画面を下に引っ張った距離を測り、しきい値を超えて指を離したらリセットを実行する。
private struct PullToResetModifier: ViewModifier {
    @Binding var pullDistance: CGFloat
    @Binding var isArmed: Bool
    let threshold: CGFloat
    let onTrigger: () -> Void

    @State private var legacyBaseline: CGFloat?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
                } action: { _, newValue in
                    update(pull: newValue, canDetectRelease: true)
                }
                .onScrollPhaseChange { oldPhase, newPhase in
                    // 指を離した瞬間（interacting から別の状態へ）に判定する
                    guard oldPhase == .interacting, newPhase != .interacting, isArmed else { return }
                    isArmed = false
                    onTrigger()
                }
        } else {
            content
                .onPreferenceChange(PullOffsetPreferenceKey.self) { minY in
                    if legacyBaseline == nil {
                        legacyBaseline = minY
                    }
                    let pull = max(0, minY - (legacyBaseline ?? minY))
                    update(pull: pull, canDetectRelease: false)
                }
        }
    }

    private func update(pull: CGFloat, canDetectRelease: Bool) {
        pullDistance = pull

        if pull >= threshold {
            if !isArmed {
                isArmed = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else if canDetectRelease {
            // 指を離す前に引っ張りを戻した場合はキャンセル
            if isArmed, pull < threshold * 0.8 {
                isArmed = false
            }
        } else if isArmed, pull < 2 {
            // iOS 17: 指を離して元の位置に戻ったタイミングで実行
            isArmed = false
            onTrigger()
        }
    }
}
