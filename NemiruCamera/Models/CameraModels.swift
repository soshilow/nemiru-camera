import Foundation

// MARK: - 設定（@AppStorage のキー）

enum AppSettingsKey {
    /// マイメーカー。CameraMaker の rawValue で保存（未設定は空文字）
    static let myMaker = "settings.myMaker"
    /// 最初に選んでおく種類。CameraCategory の rawValue で保存（未設定は「すべて」）
    static let myCategory = "settings.myCategory"
    /// 中古品のみを最初から選んでおくか（未設定はオン）
    static let myUsedOnly = "settings.myUsedOnly"
    /// ジャンク品を除くを最初から選んでおくか
    static let myExcludeJunk = "settings.myExcludeJunk"
}

// MARK: - メーカー

/// カメラ・レンズのメーカー。選ぶと検索キーワードの先頭にメーカー名が入る。
/// rawValue は検索に使うキーワード（各サイトの商品名でよく使われる英字表記。
/// カメラ店の商品名は「Nikon ニコン Z6」のように英字とカタカナを併記しているので英字で揃える）。
enum CameraMaker: String, CaseIterable, Identifiable {
    case canon = "Canon"
    case nikon = "Nikon"
    case sony = "SONY"
    case fujifilm = "FUJIFILM"
    case panasonic = "Panasonic"
    case omSystem = "OM SYSTEM"
    case olympus = "OLYMPUS"
    case pentax = "PENTAX"
    case ricoh = "RICOH"
    case leica = "Leica"
    case hasselblad = "HASSELBLAD"
    case sigma = "SIGMA"
    case tamron = "TAMRON"
    case tokina = "Tokina"
    case voigtlander = "Voigtlander"
    case zeiss = "ZEISS"
    case ttartisan = "TTArtisan"
    case viltrox = "VILTROX"
    case minolta = "MINOLTA"
    case contax = "CONTAX"
    case mamiya = "Mamiya"

    var id: String { rawValue }

    /// 検索キーワードに入れる文字列
    var keyword: String { rawValue }

    /// メニューに表示する名前（カタカナを添える）
    var menuTitle: String {
        switch self {
        case .canon: return "Canon（キヤノン）"
        case .nikon: return "Nikon（ニコン）"
        case .sony: return "SONY（ソニー）"
        case .fujifilm: return "FUJIFILM（富士フイルム）"
        case .panasonic: return "Panasonic（パナソニック）"
        case .omSystem: return "OM SYSTEM"
        case .olympus: return "OLYMPUS（オリンパス）"
        case .pentax: return "PENTAX（ペンタックス）"
        case .ricoh: return "RICOH（リコー）"
        case .leica: return "Leica（ライカ）"
        case .hasselblad: return "HASSELBLAD（ハッセルブラッド）"
        case .sigma: return "SIGMA（シグマ）"
        case .tamron: return "TAMRON（タムロン）"
        case .tokina: return "Tokina（トキナー）"
        case .voigtlander: return "Voigtlander（フォクトレンダー）"
        case .zeiss: return "ZEISS（ツァイス）"
        case .ttartisan: return "TTArtisan（銘匠光学）"
        case .viltrox: return "VILTROX（ビルトロックス）"
        case .minolta: return "MINOLTA（ミノルタ）"
        case .contax: return "CONTAX（コンタックス）"
        case .mamiya: return "Mamiya（マミヤ）"
        }
    }

    /// メニューの見出し
    var group: String {
        switch self {
        case .canon, .nikon, .sony, .fujifilm, .panasonic, .omSystem, .olympus, .pentax, .ricoh, .leica, .hasselblad:
            return "カメラメーカー"
        case .sigma, .tamron, .tokina, .voigtlander, .zeiss, .ttartisan, .viltrox:
            return "レンズメーカー"
        case .minolta, .contax, .mamiya:
            return "フィルム時代のメーカー"
        }
    }

    /// メニューに出す順（見出しごと）
    static var groups: [(title: String, makers: [CameraMaker])] {
        var result: [(title: String, makers: [CameraMaker])] = []
        for maker in allCases {
            if let index = result.firstIndex(where: { $0.title == maker.group }) {
                result[index].makers.append(maker)
            } else {
                result.append((maker.group, [maker]))
            }
        }
        return result
    }

    /// キーワードの先頭にあるメーカー名を探す（長い名前を優先。大文字・小文字は区別しない）
    static func detect(in keyword: String) -> CameraMaker? {
        let normalized = KeywordKey.make(keyword)
        return allCases
            .sorted { $0.keyword.count > $1.keyword.count }
            .first { maker in
                let key = maker.keyword.lowercased()
                return normalized == key || normalized.hasPrefix(key + " ")
            }
    }

    /// キーワードの先頭のメーカー名を入れ替える（nil はメーカー名を外す）。メーカー名以外の入力はそのまま残す
    static func replacing(in keyword: String, with maker: CameraMaker?) -> String {
        var words = keyword.split(whereSeparator: \.isWhitespace).map(String.init)
        if let current = detect(in: keyword) {
            words.removeFirst(current.keyword.split(separator: " ").count)
        }
        if let maker {
            words.insert(maker.keyword, at: 0)
        }
        return words.joined(separator: " ")
    }
}

// MARK: - 種類

/// カメラページで絞り込む商品の種類。各サイトのカテゴリで検索する（CameraParameters を参照）
enum CameraCategory: String, CaseIterable, Identifiable {
    case all
    case digital
    case lens
    case film

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "すべて"
        case .digital: return "デジカメ"
        case .lens: return "レンズ"
        case .film: return "フィルム"
        }
    }

    /// 保存済み・履歴に表示する名前
    var displayName: String {
        switch self {
        case .all: return "カメラ全般"
        case .digital: return "デジタルカメラ"
        case .lens: return "レンズ"
        case .film: return "フィルムカメラ"
        }
    }
}

// MARK: - 保存・履歴に残す条件

/// カメラページの保存済み項目と履歴に記録する条件（種類・中古品のみ・ジャンク除外）の文字列表現。
/// 例："c:lens,nojunk"。初期状態（すべて・中古品のみ・ジャンク含む）は nil。
/// メーカーはキーワードに含まれるのでここには入れない。
enum CameraSpec {
    private static let newToken = "new"
    private static let noJunkToken = "nojunk"

    static func make(scope: SearchScope, filter: SearchFilterState) -> String? {
        guard scope == .camera else { return nil }
        var tokens: [String] = []
        if filter.cameraCategory != .all {
            tokens.append(filter.cameraCategory.rawValue)
        }
        if !filter.usedOnly {
            tokens.append(newToken)
        }
        if filter.excludeJunk {
            tokens.append(noJunkToken)
        }
        return tokens.isEmpty ? nil : "c:" + tokens.joined(separator: ",")
    }

    /// 画面表示用（例：「レンズ・ジャンク除く」）
    static func displayText(_ spec: String?) -> String? {
        guard let decoded = decode(spec) else { return nil }
        let parts = [
            decoded.category == .all ? nil : decoded.category.displayName,
            decoded.usedOnly ? nil : "新品含む",
            decoded.excludeJunk ? "ジャンク除く" : nil
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: "・")
    }

    /// 保存・履歴の条件を検索条件に反映する
    static func apply(_ spec: String?, to filter: inout SearchFilterState) {
        let decoded = decode(spec) ?? (.all, true, false)
        filter.cameraCategory = decoded.category
        filter.usedOnly = decoded.usedOnly
        filter.excludeJunk = decoded.excludeJunk
    }

    private static func decode(_ spec: String?) -> (category: CameraCategory, usedOnly: Bool, excludeJunk: Bool)? {
        guard let spec, spec.hasPrefix("c:") else { return nil }
        let tokens = spec.dropFirst(2).split(separator: ",").map(String.init)
        return (
            tokens.compactMap(CameraCategory.init(rawValue:)).first ?? .all,
            !tokens.contains(newToken),
            tokens.contains(noJunkToken)
        )
    }
}

// MARK: - 検索時のページ情報

/// URL を組み立てるときに使う、ページの情報
struct SearchContext {
    var scope: SearchScope = .general

    static let general = SearchContext()
}

/// 設定画面の「マイ設定」から、ページの初期条件を作る
enum MyCamera {
    static func initialFilter(for scope: SearchScope) -> SearchFilterState {
        var filter = SearchFilterState()
        guard scope == .camera else { return filter }
        let defaults = UserDefaults.standard
        if let maker = CameraMaker(rawValue: defaults.string(forKey: AppSettingsKey.myMaker) ?? "") {
            filter.keyword = maker.keyword
        }
        filter.cameraCategory = CameraCategory(rawValue: defaults.string(forKey: AppSettingsKey.myCategory) ?? "") ?? .all
        filter.usedOnly = defaults.object(forKey: AppSettingsKey.myUsedOnly) as? Bool ?? true
        filter.excludeJunk = defaults.bool(forKey: AppSettingsKey.myExcludeJunk)
        return filter
    }
}
