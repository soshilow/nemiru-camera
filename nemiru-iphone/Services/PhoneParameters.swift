import Foundation

/// iPhone ページで使う、カテゴリ・容量・SIMフリーの検索パラメータ。
///
/// ID は 2026-11 時点で各サイトの検索画面から確認したもの。
/// サイト側で ID が変わると絞り込みが効かなくなるので、その場合はここを更新する。
///
/// 容量・SIMフリーを専用の条件で渡せないサイトでは、キーワードに付け足して検索する
/// （`keywordAdditions` を参照）。
enum PhoneParameters {
    /// 容量・SIMフリーをキーワードとして付け足す語（専用の条件で渡せるものは除く）
    static func keywordAdditions(
        for service: MarketplaceService,
        storage: PhoneStorage?,
        simFreeOnly: Bool
    ) -> [String] {
        var words: [String] = []
        switch service {
        case .rakuten:
            // 楽天市場の容量タグは「512GB～」までなので、1TB・2TB はキーワードでも絞る
            if storage == .tb1 || storage == .tb2 {
                words.append(storage!.rawValue)
            }
        default:
            if let storage {
                words.append(storage.rawValue)
            }
        }
        switch service {
        // メルカリ・楽天市場は SIMフリーを条件で渡す。Back Market・にこスマは全商品が SIMフリー
        case .mercari, .rakuten, .backMarket, .nicosuma:
            break
        default:
            if simFreeOnly {
                words.append("SIMフリー")
            }
        }
        return words
    }

    /// 店の商品名が「iPhone15」のように機種番号を詰めて書く中古スマホ店か。
    /// 「iPhone 15」のまま送ると、別の機種まで検索結果に混ざる。
    static func prefersCompactModelName(_ service: MarketplaceService) -> Bool {
        service == .iosys || service == .sofmap || service == .geo
    }

    /// 「iPhone 15 Pro」→「iPhone15 Pro」のように、iPhone と番号の間の空白を詰める
    static func compactModelName(_ keyword: String) -> String {
        keyword.replacingOccurrences(
            of: #"(?i)\biphone\s+(\d)"#,
            with: "iPhone$1",
            options: .regularExpression
        )
    }

    // MARK: - メルカリ

    /// カテゴリ：スマホ・タブレット・パソコン > スマートフォン・携帯電話 > スマートフォン本体=859
    /// シリーズ：iPhone。SIMフリー：SIMフリー
    static func mercari(scope: SearchScope, simFreeOnly: Bool) -> [URLQueryItem] {
        guard scope == .iphone else { return [] }
        var items = [
            URLQueryItem(name: "category_id", value: "859"),
            URLQueryItem(name: "ce318123-cf86-48ed-b132-d3896ec9a23c", value: "9b36bbee-1abd-414d-8b20-a80a2745621b")
        ]
        if simFreeOnly {
            items.append(URLQueryItem(name: "85b41c1f-b85d-5885-8712-df90e36ca756", value: "a373dd2d-b286-5e31-98d2-93b6ba25c88f"))
        }
        return items
    }

    // MARK: - ラクマ

    /// カテゴリ：スマホ/家電/カメラ > スマートフォン本体=668
    static func rakuma(scope: SearchScope) -> [URLQueryItem] {
        guard scope == .iphone else { return [] }
        return [URLQueryItem(name: "category_id", value: "668")]
    }

    // MARK: - Yahoo!フリマ

    /// カテゴリ：スマホ、タブレット、パソコン=2502 > スマホ=38338 > iPhone=38340
    static func yahooFleamarket(scope: SearchScope) -> [URLQueryItem] {
        guard scope == .iphone else { return [] }
        return [URLQueryItem(name: "categoryIds", value: "2502,38338,38340")]
    }

    // MARK: - ヤフオク

    /// カテゴリ：家電、AV、カメラ > 携帯電話、スマートフォン > スマホ本体 > iPhone=2084317599
    /// （出品中・落札相場のどちらでも効く）
    static func yahooAuctions(scope: SearchScope) -> [URLQueryItem] {
        guard scope == .iphone else { return [] }
        return [URLQueryItem(name: "auccat", value: "2084317599")]
    }

    // MARK: - Amazon

    /// カテゴリ：携帯電話・スマートフォン本体=128187011、
    /// コンディション：中古品=2249603051 または 整備済み品=8514288051
    static func amazonRefinement(scope: SearchScope) -> String? {
        guard scope == .iphone else { return nil }
        return "n:128187011,p_n_condition-type:2249603051|8514288051"
    }

    // MARK: - 楽天市場

    /// 楽天市場のジャンルとタグ。検索URLのキーワードの後ろに付けるパス（例：「560202/tg1002891,1021162/」）。
    /// ジャンル：スマートフォン本体=560202。タグ：iPhone（アップル）=1002891、
    /// 容量 64GB=1021160 / 128GB=1021161 / 256GB=1021162 / 512GB～=1021163、SIMフリー=1021164
    static func rakutenPath(scope: SearchScope, storage: PhoneStorage?, simFreeOnly: Bool) -> String {
        guard scope == .iphone else { return "" }
        var tags = [1002891]
        switch storage {
        case .gb64: tags.append(1021160)
        case .gb128: tags.append(1021161)
        case .gb256: tags.append(1021162)
        case .gb512, .tb1, .tb2: tags.append(1021163)
        case nil: break
        }
        if simFreeOnly {
            tags.append(1021164)
        }
        return "560202/tg" + tags.map(String.init).joined(separator: ",") + "/"
    }
}
