import Foundation
import Observation
import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case page(SearchScope)
    case settings
}

/// 検索ページの種類。保存済み項目と検索履歴はページごとに分けて記録する。
enum SearchScope: String, CaseIterable, Identifiable, Codable {
    case general
    case iphone

    var id: String { rawValue }

    var tabTitle: String {
        switch self {
        case .general: return "検索"
        case .iphone: return "iPhone"
        }
    }

    var tabSymbol: String {
        switch self {
        case .general: return "magnifyingglass"
        case .iphone: return "iphone"
        }
    }

    var placeholder: String {
        switch self {
        case .general: return "商品名・型番・ISBNなどを入力"
        case .iphone: return "機種名・色など（例：iPhone 15 ブルー）"
        }
    }

    /// 保存データの値から変換（不明な値は「検索」ページ扱い）
    static func from(_ rawValue: String?) -> SearchScope {
        rawValue.flatMap(SearchScope.init(rawValue:)) ?? .general
    }
}

enum SortOption: String, Codable, CaseIterable, Identifiable {
    /// 各サイトの「おすすめ順」「人気順」など（検索語に近い商品が上に出やすい）
    case recommended = "おすすめ"
    case newest = "新着"
    case priceAsc = "安い順"
    case priceDesc = "高い順"

    var id: String { rawValue }
}

/// 販売状況。「売り切れ」は売れた価格（相場）を確認するモード。
enum SaleStatus: String, Codable, CaseIterable, Identifiable {
    case onSale = "販売中"
    case all = "すべて"
    case soldOut = "売り切れ"

    var id: String { rawValue }

    var pickerTitle: String {
        switch self {
        case .onSale: return "販売中"
        case .all: return "すべて"
        case .soldOut: return "売り切れ"
        }
    }

    /// 旧データ（onlyOnSale の Bool）からの変換
    static func legacy(onlyOnSale: Bool) -> SaleStatus {
        onlyOnSale ? .onSale : .all
    }
}

/// 除外ワードを各サービスへどう渡すか
enum ExclusionSupport {
    /// 専用パラメータで渡す（メルカリ: exclude_keyword / ラクマ: excluded_query / 楽天市場: nitem / イオシス: not / ゲオ: q_not）
    case parameter
    /// キーワード内の「-ワード」をそのまま解釈してくれる
    case inlineMinus
    /// 除外に非対応。「-ワード」を渡すと逆にそのワードで検索されるため、取り除いて送る
    case unsupported
}

enum MarketplaceService: String, Codable, CaseIterable, Identifiable {
    case mercari = "メルカリ"
    case rakuma = "楽天ラクマ"
    case yahooFleamarket = "Yahoo!フリマ"
    case yahooAuctions = "Yahoo!オークション"
    case amazon = "Amazon"
    case rakuten = "楽天市場"
    case yodobashi = "ヨドバシカメラ"
    case bicCamera = "ビックカメラ"
    case iosys = "イオシス"
    case janpara = "じゃんぱら"
    case sofmap = "ソフマップ"
    case geo = "ゲオ"
    case backMarket = "Back Market"

    var id: String { rawValue }

    /// ページに表示するサービス。中古スマホ店は iPhone ページのみ、家電量販店は検索ページのみ
    static func services(for scope: SearchScope) -> [MarketplaceService] {
        switch scope {
        case .general:
            return allCases.filter { !$0.isPhoneShop }
        case .iphone:
            return allCases.filter { !$0.isGeneralOnly }
        }
    }

    /// 検索ページだけに出すサービス（家電量販店）
    var isGeneralOnly: Bool {
        self == .yodobashi || self == .bicCamera
    }

    /// iPhone ページだけに出すサービス（中古スマホ店）
    var isPhoneShop: Bool {
        [.iosys, .janpara, .sofmap, .geo, .backMarket].contains(self)
    }

    /// 除外ワードを入力したとき、ボタンに「除外ワード非対応」と表示するか
    var showsExclusionWarning: Bool {
        exclusionSupport == .unsupported && (isPhoneShop || isGeneralOnly)
    }

    /// 常にアプリ内ブラウザで開くサービス（中古スマホ店はアプリがないか、検索URLに対応していない）
    var alwaysOpensInAppBrowser: Bool {
        isPhoneShop
    }

    /// 画面に表示する名前（rawValue は保存データとの互換のため変えない）
    var displayName: String {
        switch self {
        case .yahooAuctions: return "ヤフオク"
        default: return rawValue
        }
    }

    var brandColor: Color {
        switch self {
        case .mercari:
            return Color(red: 1.0, green: 0.23, blue: 0.29)
        case .rakuma:
            return Color(red: 0.18, green: 0.45, blue: 0.96)
        case .yahooFleamarket:
            return Color(red: 0.04, green: 0.72, blue: 0.36)
        case .yahooAuctions:
            return Color(red: 0.96, green: 0.65, blue: 0.05)
        case .amazon:
            return Color(red: 0.05, green: 0.56, blue: 0.78)
        case .rakuten:
            return Color(red: 0.75, green: 0.0, blue: 0.0)
        case .yodobashi:
            return Color(red: 0.80, green: 0.0, blue: 0.10)
        case .bicCamera:
            return Color(red: 0.95, green: 0.45, blue: 0.0)
        case .iosys:
            return Color(red: 0.0, green: 0.45, blue: 0.75)
        case .janpara:
            return Color(red: 0.90, green: 0.30, blue: 0.10)
        case .sofmap:
            return Color(red: 0.0, green: 0.30, blue: 0.60)
        case .geo:
            return Color(red: 0.0, green: 0.25, blue: 0.55)
        case .backMarket:
            return Color(red: 0.10, green: 0.10, blue: 0.10)
        }
    }

    /// 売り切れ（相場）検索に対応しているか。Amazon・楽天市場・中古スマホ店は販売中の価格のみ。
    var supportsSoldSearch: Bool {
        switch self {
        case .mercari, .rakuma, .yahooFleamarket, .yahooAuctions: return true
        case .amazon, .rakuten, .yodobashi, .bicCamera, .iosys, .janpara, .sofmap, .geo, .backMarket: return false
        }
    }

    /// 売り切れ（相場）検索をアプリ内ブラウザで開くか。
    /// メルカリはアプリに渡すと売り切れの指定が効かず、ヤフオクはアプリが落札相場のリンクに対応していないため。
    var opensSoldSearchInAppBrowser: Bool {
        self == .mercari || self == .yahooAuctions
    }

    var exclusionSupport: ExclusionSupport {
        switch self {
        case .mercari, .rakuma, .rakuten, .iosys, .geo: return .parameter
        case .yahooFleamarket, .yahooAuctions: return .inlineMinus
        case .amazon, .yodobashi, .bicCamera, .janpara, .sofmap, .backMarket: return .unsupported
        }
    }
}

/// キーワードを「検索語」と「除外ワード」に分解したもの
struct ParsedKeyword: Equatable {
    var includeTerms: [String]
    var excludeTerms: [String]

    var includeText: String { includeTerms.joined(separator: " ") }
    var excludeText: String { excludeTerms.joined(separator: " ") }

    /// 「-ワード」を含めたキーワード（除外を -記法 で解釈するサービス向け）
    var inlineText: String {
        (includeTerms + excludeTerms.map { "-\($0)" }).joined(separator: " ")
    }

    init(_ raw: String) {
        var includes: [String] = []
        var excludes: [String] = []
        for token in raw.split(whereSeparator: \.isWhitespace).map(String.init) {
            if let first = token.first, first == "-" || first == "－", token.count > 1 {
                let term = String(token.dropFirst())
                if !excludes.contains(term) {
                    excludes.append(term)
                }
            } else {
                includes.append(token)
            }
        }
        includeTerms = includes
        excludeTerms = excludes
    }
}

struct SearchFilterState: Equatable {
    var keyword: String = ""
    var saleStatus: SaleStatus = .onSale
    var sortOption: SortOption = .recommended
    /// iPhone ページの容量（nil は指定なし）
    var storage: PhoneStorage?
    /// iPhone ページで SIMフリーのみを探すか
    var simFreeOnly: Bool = false

    var trimmedKeyword: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var parsedKeyword: ParsedKeyword {
        ParsedKeyword(keyword)
    }

    /// 除外ワードを除いた検索語があるか（「-ジャンク」だけでは検索できない）
    var hasSearchableKeyword: Bool {
        !parsedKeyword.includeTerms.isEmpty
    }

    /// 同じキーワードかどうかの判定に使うキー
    var keywordKey: String {
        KeywordKey.make(keyword)
    }

    /// 保存済み・履歴との重複判定に使うキー（キーワード＋そのページの容量・SIM条件）
    func groupKey(scope: SearchScope) -> String {
        keywordKey + "|" + (PhoneSpec.make(scope: scope, filter: self) ?? "")
    }
}

/// 同じキーワードかどうかを判定するためのキー（保存の重複防止・履歴のまとめ表示に使用）。
/// 販売状況や並び替えは含めない。
enum KeywordKey {
    static func make(_ keyword: String) -> String {
        keyword
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }
}

@Model
final class SavedSearchItem {
    var id: UUID
    var keyword: String
    /// 旧バージョン互換用。新しいデータは saleStatusRawValue を使う。
    var onlyOnSale: Bool
    var saleStatusRawValue: String?
    /// 旧バージョンの価格帯。現在は検索にも表示にも使わない（データ互換のため残している）
    var minPrice: Int?
    var maxPrice: Int?
    var sortRawValue: String
    var createdAt: Date
    /// 最後に使った（呼び出した・保存した）日時
    var lastUsedAt: Date?
    /// どのページの保存済み項目か（nil は旧データ＝「検索」ページ）
    var scopeRawValue: String?
    /// iPhone ページの容量・SIM条件（PhoneSpec 形式。nil は指定なし）
    var sizeSpec: String?

    init(
        id: UUID = UUID(),
        keyword: String,
        scope: SearchScope = .general,
        sizeSpec: String? = nil,
        saleStatus: SaleStatus = .onSale,
        sortOption: SortOption = .newest,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.keyword = keyword
        self.scopeRawValue = scope.rawValue
        self.sizeSpec = sizeSpec
        self.onlyOnSale = saleStatus == .onSale
        self.saleStatusRawValue = saleStatus.rawValue
        self.minPrice = nil
        self.maxPrice = nil
        self.sortRawValue = sortOption.rawValue
        self.createdAt = createdAt
        self.lastUsedAt = createdAt
    }

    var scope: SearchScope {
        SearchScope.from(scopeRawValue)
    }

    /// 並び替えに使う日時（一度も使っていない古いデータは保存日時）
    var recentlyUsedDate: Date {
        lastUsedAt ?? createdAt
    }

    func markUsed() {
        lastUsedAt = Date()
        try? modelContext?.save()
    }

    /// 最近使った順に並べる
    static func sortedByRecentUse(_ items: [SavedSearchItem]) -> [SavedSearchItem] {
        items.sorted { $0.recentlyUsedDate > $1.recentlyUsedDate }
    }

    var sortOption: SortOption {
        SortOption(rawValue: sortRawValue) ?? .newest
    }

    var saleStatus: SaleStatus {
        saleStatusRawValue.flatMap(SaleStatus.init(rawValue:)) ?? .legacy(onlyOnSale: onlyOnSale)
    }

    var keywordKey: String {
        KeywordKey.make(keyword)
    }

    /// 重複判定・まとめ表示に使うキー（キーワード＋容量・SIM条件）
    var groupKey: String {
        keywordKey + "|" + (sizeSpec ?? "")
    }
}

@Model
final class SearchHistoryItem {
    var id: UUID
    var keyword: String
    var serviceName: String
    /// 旧バージョン互換用。新しいデータは saleStatusRawValue を使う。
    var onlyOnSale: Bool
    var saleStatusRawValue: String?
    /// 旧バージョンの価格帯。現在は検索にも表示にも使わない（データ互換のため残している）
    var minPrice: Int?
    var maxPrice: Int?
    var sortRawValue: String
    var searchedAt: Date
    /// どのページの検索履歴か（nil は旧データ＝「検索」ページ）
    var scopeRawValue: String?
    /// iPhone ページの容量・SIM条件（PhoneSpec 形式。nil は指定なし）
    var sizeSpec: String?

    init(
        id: UUID = UUID(),
        keyword: String,
        serviceName: String,
        scope: SearchScope = .general,
        sizeSpec: String? = nil,
        saleStatus: SaleStatus = .onSale,
        sortOption: SortOption = .newest,
        searchedAt: Date = Date()
    ) {
        self.id = id
        self.keyword = keyword
        self.serviceName = serviceName
        self.scopeRawValue = scope.rawValue
        self.sizeSpec = sizeSpec
        self.onlyOnSale = saleStatus == .onSale
        self.saleStatusRawValue = saleStatus.rawValue
        self.minPrice = nil
        self.maxPrice = nil
        self.sortRawValue = sortOption.rawValue
        self.searchedAt = searchedAt
    }

    var sortOption: SortOption {
        SortOption(rawValue: sortRawValue) ?? .newest
    }

    var saleStatus: SaleStatus {
        saleStatusRawValue.flatMap(SaleStatus.init(rawValue:)) ?? .legacy(onlyOnSale: onlyOnSale)
    }

    var scope: SearchScope {
        SearchScope.from(scopeRawValue)
    }

    var service: MarketplaceService? {
        MarketplaceService(rawValue: serviceName)
    }

    var keywordKey: String {
        KeywordKey.make(keyword)
    }

    /// 重複判定・まとめ表示に使うキー（キーワード＋容量・SIM条件）
    var groupKey: String {
        keywordKey + "|" + (sizeSpec ?? "")
    }
}

/// 同じキーワードの検索履歴を1行にまとめたもの
struct SearchHistoryGroup: Identifiable {
    let id: String
    var items: [SearchHistoryItem]

    /// 新しい順に並んでいるので先頭が最新
    var keyword: String { items[0].keyword }

    /// 容量・SIM条件（iPhone ページのみ）
    var sizeSpec: String? { items[0].sizeSpec }

    /// 指定したページの履歴を、同じキーワード（＋容量・SIM条件）ごとにまとめる（items は新しい順で渡す）
    static func make(from items: [SearchHistoryItem], scope: SearchScope) -> [SearchHistoryGroup] {
        var groups: [SearchHistoryGroup] = []
        var indexByKey: [String: Int] = [:]
        for item in items where item.scope == scope {
            let key = item.groupKey
            if let index = indexByKey[key] {
                groups[index].items.append(item)
            } else {
                indexByKey[key] = groups.count
                groups.append(SearchHistoryGroup(id: key, items: [item]))
            }
        }
        return groups
    }
}

// MARK: - Toast

enum ToastStyle {
    case success
    case info
    case warning
    case error

    var symbolName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return .green
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct ToastData: Identifiable {
    let id = UUID()
    let message: String
    let style: ToastStyle
    let actionTitle: String?
    let action: (() -> Void)?
}

@MainActor
@Observable
final class SearchCoordinator {
    var filter: SearchFilterState
    var toast: ToastData?

    init(filter: SearchFilterState = SearchFilterState()) {
        self.filter = filter
    }

    private var toastDismissTask: Task<Void, Never>?

    func showToast(
        _ message: String,
        style: ToastStyle = .success,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        toastDismissTask?.cancel()
        let data = ToastData(message: message, style: style, actionTitle: actionTitle, action: action)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            toast = data
        }
        let duration: Double = action == nil ? 2.2 : 6.0
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.toast?.id == data.id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    self?.toast = nil
                }
            }
        }
    }

    func dismissToast() {
        toastDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            toast = nil
        }
    }

    /// キーワードをリセットする。リセットする内容がなければ false。
    @discardableResult
    func resetAll() -> Bool {
        let previousFilter = filter

        var cleared = filter
        cleared.keyword = ""

        guard cleared != previousFilter else { return false }

        filter = cleared

        showToast(
            "キーワードをリセットしました",
            style: .info,
            actionTitle: "元に戻す"
        ) { [weak self] in
            guard let self else { return }
            self.filter = previousFilter
            self.showToast("元に戻しました")
        }
        return true
    }

    /// 保存済みのキーワードを入力する（販売状況と並び替えは今の設定のまま）
    func applySavedItem(_ item: SavedSearchItem) {
        item.markUsed()
        filter.keyword = item.keyword
        if item.scope == .iphone {
            PhoneSpec.apply(item.sizeSpec, to: &filter)
        }
    }

    /// 履歴のキーワード（iPhone ページは容量・SIM条件も）を入力する（販売状況と並び替えは今の設定のまま）
    func applyHistory(_ group: SearchHistoryGroup) {
        filter.keyword = group.keyword
        if group.items[0].scope == .iphone {
            PhoneSpec.apply(group.sizeSpec, to: &filter)
        }
    }
}
