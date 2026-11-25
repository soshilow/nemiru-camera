import Foundation

/// カメラページで使う、種類（カテゴリ）・中古品のみの検索パラメータ。
///
/// ID は 2026-11 時点で各サイトの検索画面から確認したもの。
/// サイト側で ID が変わると絞り込みが効かなくなるので、その場合はここを更新する。
/// 検索ページ（.general）ではカテゴリを指定しない。
enum CameraParameters {
    // MARK: - メルカリ

    /// カテゴリ：テレビ・オーディオ・カメラ > カメラ=97。
    /// デジタルカメラ=843、レンズ(ズーム)=1255・レンズ(単焦点)=846、フィルムカメラ=844。
    /// メルカリはカンマ区切りで複数のカテゴリを指定できる
    static func mercariCategory(scope: SearchScope, category: CameraCategory) -> String? {
        guard scope == .camera else { return nil }
        switch category {
        case .all: return "97"
        case .digital: return "843"
        case .lens: return "1255,846"
        case .film: return "844"
        }
    }

    // MARK: - ラクマ

    /// カテゴリ：スマホ/家電/カメラ > カメラ=682。
    /// デジタル一眼=1384、フィルムカメラ=684。
    /// レンズは単焦点=1620・ズーム=1621 に分かれていて、ラクマは複数指定できないため「カメラ」全体で探す
    static func rakumaCategory(scope: SearchScope, category: CameraCategory) -> String? {
        guard scope == .camera else { return nil }
        switch category {
        case .all, .lens: return "682"
        case .digital: return "1384"
        case .film: return "684"
        }
    }

    // MARK: - Yahoo!フリマ

    /// カテゴリ：テレビ、オーディオ、カメラ=2504 > カメラ=2443 >
    /// デジタル一眼カメラ=47733 / 交換レンズ=2465 / フィルムカメラ=19792（親からの道のりで指定する）
    static func yahooFleamarketCategoryIDs(scope: SearchScope, category: CameraCategory) -> String? {
        guard scope == .camera else { return nil }
        switch category {
        case .all: return "2504,2443"
        case .digital: return "2504,2443,47733"
        case .lens: return "2504,2443,2465"
        case .film: return "2504,2443,19792"
        }
    }

    // MARK: - ヤフオク

    /// カテゴリ：家電、AV、カメラ > カメラ、光学機器=23636 >
    /// デジタルカメラ=2084261633 / レンズ=23684 / フィルムカメラ=23640
    /// （出品中・落札相場のどちらでも効く）
    static func yahooAuctionsCategory(scope: SearchScope, category: CameraCategory) -> String? {
        guard scope == .camera else { return nil }
        switch category {
        case .all: return "23636"
        case .digital: return "2084261633"
        case .lens: return "23684"
        case .film: return "23640"
        }
    }

    // MARK: - Amazon

    /// カテゴリ：カメラ=16462091、レンズ=675729011。
    /// デジタルカメラは一眼レフ・ミラーレス・コンパクトに分かれ、フィルムカメラの分類はないので「カメラ」で探す。
    /// 中古品のみのときは コンディション：中古品=2249603051
    static func amazonRefinement(scope: SearchScope, category: CameraCategory, usedOnly: Bool) -> String? {
        guard scope == .camera else { return nil }
        let node = category == .lens ? "675729011" : "16462091"
        var refinement = "n:\(node)"
        if usedOnly {
            refinement += ",p_n_condition-type:2249603051"
        }
        return refinement
    }

    // MARK: - 楽天市場

    /// ジャンル：カメラ・ビデオカメラ・光学機器=100212 >
    /// デジタルカメラ=100083 / カメラ用交換レンズ=110335 / フィルムカメラ=565059。
    /// 検索URLのキーワードの後ろに付けるパス（例：「110335/」）
    static func rakutenPath(scope: SearchScope, category: CameraCategory) -> String {
        guard scope == .camera else { return "" }
        switch category {
        case .all: return "100212/"
        case .digital: return "100083/"
        case .lens: return "110335/"
        case .film: return "565059/"
        }
    }
}
