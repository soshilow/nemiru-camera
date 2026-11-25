import Foundation

/// カメラページで使う、カメラのカテゴリ・中古品のみの検索パラメータ。
///
/// ID は 2026-11 時点で各サイトの検索画面から確認したもの。
/// サイト側で ID が変わると絞り込みが効かなくなるので、その場合はここを更新する。
/// カメラページでは各サイトの「カメラ」全体のカテゴリで探す。検索ページ（.general）ではカテゴリを指定しない。
enum CameraParameters {
    /// メルカリ：テレビ・オーディオ・カメラ > カメラ=97
    static func mercariCategory(scope: SearchScope) -> String? {
        scope == .camera ? "97" : nil
    }

    /// ラクマ：スマホ/家電/カメラ > カメラ=682
    static func rakumaCategory(scope: SearchScope) -> String? {
        scope == .camera ? "682" : nil
    }

    /// Yahoo!フリマ：テレビ、オーディオ、カメラ=2504 > カメラ=2443（親からの道のりで指定する）
    static func yahooFleamarketCategoryIDs(scope: SearchScope) -> String? {
        scope == .camera ? "2504,2443" : nil
    }

    /// ヤフオク：家電、AV、カメラ > カメラ、光学機器=23636（出品中・落札相場のどちらでも効く）
    static func yahooAuctionsCategory(scope: SearchScope) -> String? {
        scope == .camera ? "23636" : nil
    }

    /// Amazon：カメラ=16462091。中古品のみのときは コンディション：中古品=2249603051
    static func amazonRefinement(scope: SearchScope, usedOnly: Bool) -> String? {
        guard scope == .camera else { return nil }
        return usedOnly ? "n:16462091,p_n_condition-type:2249603051" : "n:16462091"
    }

    /// アールイーカメラ：カメラ・光学機器=1001_1（カメラ専門店なので常にこのカテゴリで探す）
    static let reCameraCategory = "1001_1"

    /// 楽天市場：カメラ・ビデオカメラ・光学機器=100212。検索URLのキーワードの後ろに付けるパス
    static func rakutenPath(scope: SearchScope) -> String {
        scope == .camera ? "100212/" : ""
    }
}
