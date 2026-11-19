import Foundation

// MARK: - 設定（@AppStorage のキー）

enum AppSettingsKey {
    /// マイ機種。PhoneModel の rawValue で保存（未設定は空文字）
    static let myModel = "settings.myModel"
    /// マイ容量。PhoneStorage の rawValue で保存（未設定は空文字）
    static let myStorage = "settings.myStorage"
    /// SIMフリーのみを最初から選んでおくか
    static let mySimFreeOnly = "settings.mySimFreeOnly"
}

// MARK: - 機種

/// iPhone の機種。選ぶと検索キーワードの先頭に機種名が入る。
/// rawValue は検索に使うキーワード（各サイトの商品名でよく使われる表記）。
enum PhoneModel: String, CaseIterable, Identifiable {
    case se2 = "iPhone SE 第2世代"
    case se3 = "iPhone SE 第3世代"
    case iphone11 = "iPhone 11"
    case iphone11Pro = "iPhone 11 Pro"
    case iphone11ProMax = "iPhone 11 Pro Max"
    case iphone12Mini = "iPhone 12 mini"
    case iphone12 = "iPhone 12"
    case iphone12Pro = "iPhone 12 Pro"
    case iphone12ProMax = "iPhone 12 Pro Max"
    case iphone13Mini = "iPhone 13 mini"
    case iphone13 = "iPhone 13"
    case iphone13Pro = "iPhone 13 Pro"
    case iphone13ProMax = "iPhone 13 Pro Max"
    case iphone14 = "iPhone 14"
    case iphone14Plus = "iPhone 14 Plus"
    case iphone14Pro = "iPhone 14 Pro"
    case iphone14ProMax = "iPhone 14 Pro Max"
    case iphone15 = "iPhone 15"
    case iphone15Plus = "iPhone 15 Plus"
    case iphone15Pro = "iPhone 15 Pro"
    case iphone15ProMax = "iPhone 15 Pro Max"
    case iphone16e = "iPhone 16e"
    case iphone16 = "iPhone 16"
    case iphone16Plus = "iPhone 16 Plus"
    case iphone16Pro = "iPhone 16 Pro"
    case iphone16ProMax = "iPhone 16 Pro Max"
    case iphone17e = "iPhone 17e"
    case iphone17 = "iPhone 17"
    case iphoneAir = "iPhone Air"
    case iphone17Pro = "iPhone 17 Pro"
    case iphone17ProMax = "iPhone 17 Pro Max"
    case iphone18Pro = "iPhone 18 Pro"
    case iphone18ProMax = "iPhone 18 Pro Max"
    case iphoneDuo = "iPhone Duo"

    var id: String { rawValue }

    /// 検索キーワードに入れる文字列
    var keyword: String { rawValue }

    /// にこスマの機種ページのパス（例：「iphone-15-pro」）。扱いのない機種は nil
    var nicosumaSlug: String? {
        switch self {
        case .se2: return "iphone-se-2nd-gen"
        case .se3: return "iphone-se-3rd-gen"
        case .iphone17e, .iphone18Pro, .iphone18ProMax, .iphoneDuo: return nil
        default: return rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
        }
    }

    /// メニューの見出しに使う世代
    var generation: String {
        switch self {
        case .se2, .se3: return "iPhone SE"
        case .iphone11, .iphone11Pro, .iphone11ProMax: return "iPhone 11"
        case .iphone12Mini, .iphone12, .iphone12Pro, .iphone12ProMax: return "iPhone 12"
        case .iphone13Mini, .iphone13, .iphone13Pro, .iphone13ProMax: return "iPhone 13"
        case .iphone14, .iphone14Plus, .iphone14Pro, .iphone14ProMax: return "iPhone 14"
        case .iphone15, .iphone15Plus, .iphone15Pro, .iphone15ProMax: return "iPhone 15"
        case .iphone16e, .iphone16, .iphone16Plus, .iphone16Pro, .iphone16ProMax: return "iPhone 16"
        case .iphone17e, .iphone17, .iphoneAir, .iphone17Pro, .iphone17ProMax: return "iPhone 17・Air"
        case .iphone18Pro, .iphone18ProMax, .iphoneDuo: return "iPhone 18・Duo"
        }
    }

    /// メニューに出す順（新しい世代が上）
    static var generations: [(title: String, models: [PhoneModel])] {
        var result: [(title: String, models: [PhoneModel])] = []
        for model in allCases.reversed() {
            if let index = result.firstIndex(where: { $0.title == model.generation }) {
                result[index].models.insert(model, at: 0)
            } else {
                result.append((model.generation, [model]))
            }
        }
        return result
    }

    /// キーワードの先頭にある機種名を探す（長い名前を優先。「iPhone 15 Pro」を「iPhone 15」と取り違えない）
    static func detect(in keyword: String) -> PhoneModel? {
        let normalized = KeywordKey.make(keyword)
        return allCases
            .sorted { $0.keyword.count > $1.keyword.count }
            .first { model in
                let key = model.keyword.lowercased()
                return normalized == key || normalized.hasPrefix(key + " ")
            }
    }

    /// キーワードの先頭の機種名を入れ替える（nil は機種名を外す）。機種名以外の入力はそのまま残す
    static func replacing(in keyword: String, with model: PhoneModel?) -> String {
        var words = keyword.split(whereSeparator: \.isWhitespace).map(String.init)
        if let current = detect(in: keyword) {
            words.removeFirst(current.keyword.split(separator: " ").count)
        }
        if let model {
            words.insert(model.keyword, at: 0)
        }
        return words.joined(separator: " ")
    }
}

// MARK: - 容量

enum PhoneStorage: String, CaseIterable, Identifiable {
    case gb64 = "64GB"
    case gb128 = "128GB"
    case gb256 = "256GB"
    case gb512 = "512GB"
    case tb1 = "1TB"
    case tb2 = "2TB"

    var id: String { rawValue }
}

// MARK: - 保存・履歴に残す条件

/// iPhone ページの保存済み項目と履歴に記録する条件（容量・SIMフリー）の文字列表現。
/// 例："p:256GB,sim"。条件なしは nil。機種はキーワードに含まれるのでここには入れない。
enum PhoneSpec {
    private static let simToken = "sim"

    static func make(scope: SearchScope, filter: SearchFilterState) -> String? {
        guard scope == .iphone else { return nil }
        var tokens: [String] = []
        if let storage = filter.storage {
            tokens.append(storage.rawValue)
        }
        if filter.simFreeOnly {
            tokens.append(simToken)
        }
        return tokens.isEmpty ? nil : "p:" + tokens.joined(separator: ",")
    }

    /// 画面表示用（例：「256GB・SIMフリー」）
    static func displayText(_ spec: String?) -> String? {
        let (storage, simFreeOnly) = decode(spec)
        let parts = [storage?.rawValue, simFreeOnly ? "SIMフリー" : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: "・")
    }

    /// 保存・履歴の条件を検索条件に反映する
    static func apply(_ spec: String?, to filter: inout SearchFilterState) {
        let (storage, simFreeOnly) = decode(spec)
        filter.storage = storage
        filter.simFreeOnly = simFreeOnly
    }

    private static func decode(_ spec: String?) -> (PhoneStorage?, Bool) {
        guard let spec, spec.hasPrefix("p:") else { return (nil, false) }
        let tokens = spec.dropFirst(2).split(separator: ",").map(String.init)
        return (tokens.compactMap(PhoneStorage.init(rawValue:)).first, tokens.contains(simToken))
    }
}

// MARK: - 検索時のページ情報

/// URL を組み立てるときに使う、ページの情報
struct SearchContext {
    var scope: SearchScope = .general

    static let general = SearchContext()
}

/// 設定画面の「マイ機種」から、ページの初期条件を作る
enum MyPhone {
    static func initialFilter(for scope: SearchScope) -> SearchFilterState {
        var filter = SearchFilterState()
        guard scope == .iphone else { return filter }
        let defaults = UserDefaults.standard
        if let model = PhoneModel(rawValue: defaults.string(forKey: AppSettingsKey.myModel) ?? "") {
            filter.keyword = model.keyword
        }
        filter.storage = PhoneStorage(rawValue: defaults.string(forKey: AppSettingsKey.myStorage) ?? "")
        filter.simFreeOnly = defaults.bool(forKey: AppSettingsKey.mySimFreeOnly)
        return filter
    }
}
