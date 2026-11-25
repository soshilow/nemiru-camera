import Foundation

/// 各サービスの検索URLを組み立てる。
///
/// パラメータは 2026-11 時点で各サイトの検索画面から確認したもの:
/// - メルカリ: status=on_sale / sold_out|trading、除外は exclude_keyword
/// - ラクマ: transaction=selling / soldout、除外は excluded_query
/// - Yahoo!フリマ: open=1 / sold=1、キーワード内の「-ワード」で除外可
/// - ヤフオク: 出品中は /search/search、落札相場は /closedsearch/closedsearch
/// - 楽天市場: 除外は nitem、中古品のみは used=1
/// - ヨドバシカメラ: sorttyp で並び順、除外ワード非対応（検索ページのみ）
/// - ビックカメラ: キーワードは Shift_JIS で送る、sort で並び順、除外ワード非対応（検索ページのみ）
/// - マップカメラ: /search?keyword=、sell=used で中古、sort=priceasc / pricedesc / dateasc（新着）（カメラページのみ）
/// - カメラのキタムラ: /ec/list?keyword=、type=u で中古、sort=price_asc / price_desc / update_date（カメラページのみ）
/// - フジヤカメラ: /shop/goods/search.aspx?keyword=、category=20 で中古、sort=1 / 4 / 5（カメラページのみ）
/// - カメラのナニワ: キーワード（pb_keyword）は Shift_JIS、pb_salestype=2 で中古、sort=3 / 2 / 1（カメラページのみ）
///
/// カメラページの種類（カテゴリ）・中古品のみは CameraParameters を参照
/// （ヤフオクはカメラページではアプリ内ブラウザで Web 版を開く）。
struct SearchURLBuilder {
    /// メルカリアンバサダーの ID（メルカリの検索リンクに afid として付ける）
    static let mercariAffiliateID = "8455126641"
    /// Amazon アソシエイトの ID（Amazon の検索リンクに tag として付ける）
    static let amazonAssociateTag = "soshilow-22"
    /// 楽天アフィリエイトの ID（楽天市場の検索リンクを hb.afl.rakuten.co.jp 経由にする）
    static let rakutenAffiliateID = "59ec8aa8.7be83402.59ec8aa9.3402fcc7"

    /// - Parameter includesAffiliateID: メルカリ・Amazon・楽天市場のリンクにアフィリエイト ID を付けるか。
    ///   「検索URLをコピー」では付けない（ID 付きのリンクが他の場所に貼られないように）。
    ///   Amazon はアプリ内ブラウザで開くときも付けない（アソシエイトの規約で、アプリ内ブラウザでの表示が禁止されているため）
    static func buildURL(
        for service: MarketplaceService,
        filter: SearchFilterState,
        context: SearchContext = .general,
        includesAffiliateID: Bool = true
    ) -> URL? {
        let query = Query(filter: filter, context: context, service: service)
        guard !query.keyword.includeTerms.isEmpty else { return nil }

        switch service {
        case .mercari:
            return buildMercariURL(query, includesAffiliateID: includesAffiliateID)
        case .rakuma:
            return buildRakumaURL(query)
        case .yahooFleamarket:
            return buildYahooFleamarketURL(query)
        case .yahooAuctions:
            return buildYahooAuctionsURL(query)
        case .amazon:
            return buildAmazonURL(query, includesAffiliateID: includesAffiliateID)
        case .rakuten:
            return buildRakutenURL(query, includesAffiliateID: includesAffiliateID)
        case .yodobashi:
            return buildYodobashiURL(query)
        case .bicCamera:
            return buildBicCameraURL(query)
        case .mapCamera:
            return buildMapCameraURL(query)
        case .kitamura:
            return buildKitamuraURL(query)
        case .fujiya:
            return buildFujiyaURL(query)
        case .naniwa:
            return buildNaniwaURL(query)
        }
    }

    /// アプリを直接起動するURL。対応するURLスキームがない場合は Web URL を返す
    /// （iOS のユニバーサルリンクにより、インストール済みならアプリで開かれる）。
    static func buildAppLaunchURL(
        for service: MarketplaceService,
        filter: SearchFilterState,
        context: SearchContext = .general
    ) -> URL? {
        let query = Query(filter: filter, context: context, service: service)
        guard !query.keyword.includeTerms.isEmpty else { return nil }

        switch service {
        case .yahooAuctions where query.saleStatus != .soldOut:
            // 落札相場はアプリのURLスキームで開けないため、Web版にフォールバックする
            return buildYahooAuctionsAppURL(query)
        case .yodobashi:
            // ヨドバシの検索ページはユニバーサルリンクの対象外（商品ページのみ）なので、
            // 公式のURLスキームでアプリの検索を開く。並び順などは渡せない
            return buildYodobashiAppURL(query)
        default:
            return buildURL(for: service, filter: filter, context: context)
        }
    }

    // MARK: - Query

    private struct Query {
        let keyword: ParsedKeyword
        let saleStatus: SaleStatus
        let sortOption: SortOption
        let context: SearchContext
        let category: CameraCategory
        let usedOnly: Bool

        init(filter: SearchFilterState, context: SearchContext, service: MarketplaceService) {
            var keyword = filter.parsedKeyword
            // 種類・中古品のみ・ジャンク除外はカメラページのものだけ使う
            let isCameraPage = context.scope == .camera
            category = isCameraPage ? filter.cameraCategory : .all
            usedOnly = isCameraPage && filter.usedOnly

            if isCameraPage && filter.excludeJunk {
                // 「ジャンク」を除外ワードに加える（入力済みなら重ねない）
                if !keyword.excludeTerms.contains(where: { $0.lowercased() == "ジャンク" }) {
                    keyword.excludeTerms.append("ジャンク")
                }
            }

            self.keyword = keyword
            saleStatus = filter.saleStatus
            sortOption = filter.sortOption
            self.context = context
        }

        /// サービスの除外ワード対応状況に合わせたキーワード文字列
        func keywordText(for support: ExclusionSupport) -> String {
            switch support {
            case .inlineMinus:
                return keyword.inlineText
            case .parameter, .unsupported:
                return keyword.includeText
            }
        }
    }

    /// パスに入れるキーワードをエンコードする。
    /// 「+」は楽天市場などで空白として扱われるため、%2B にする（例：「Galaxy S24+」）
    private static func encodePathSegment(_ value: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#+"))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    /// URLComponents から URL を作る。
    /// URLComponents はクエリの「+」をエンコードしないが、多くのサイトは「+」を空白として扱うため、
    /// そのままだと「Galaxy S24+」が「Galaxy S24 」で検索されてしまう。%2B にして送る。
    private static func makeURL(_ components: URLComponents?) -> URL? {
        guard var components else { return nil }
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }

    // MARK: - メルカリ

    /// メルカリの検索URL。メルカリアンバサダーのリンク作成ツールと同じ形にそろえる:
    /// afid → keyword → 残りの条件をアルファベット順。空白は %20、おすすめ順・「すべて」は指定しない。
    /// 例: https://jp.mercari.com/search?afid=8455126641&keyword=iPhone%2011&order=asc&sort=price
    private static func buildMercariURL(_ query: Query, includesAffiliateID: Bool) -> URL? {
        var conditions: [(name: String, value: String)] = []

        if !query.keyword.excludeTerms.isEmpty {
            conditions.append(("exclude_keyword", query.keyword.excludeText))
        }

        switch query.saleStatus {
        case .onSale:
            conditions.append(("status", "on_sale"))
        case .soldOut:
            conditions.append(("status", "sold_out|trading"))
        case .all:
            break
        }

        switch query.sortOption {
        case .priceAsc:
            conditions.append(("sort", "price"))
            conditions.append(("order", "asc"))
        case .priceDesc:
            conditions.append(("sort", "price"))
            conditions.append(("order", "desc"))
        case .newest:
            conditions.append(("sort", "created_time"))
            conditions.append(("order", "desc"))
        case .recommended:
            break // おすすめ順（メルカリの初期設定）
        }

        if let categoryID = CameraParameters.mercariCategory(scope: query.context.scope, category: query.category) {
            conditions.append(("category_id", categoryID))
        }

        var pairs: [(name: String, value: String)] = []
        if includesAffiliateID {
            pairs.append(("afid", mercariAffiliateID))
        }
        pairs.append(("keyword", query.keywordText(for: .parameter)))
        pairs += conditions.sorted { $0.name < $1.name }

        let queryText = pairs
            .map { encodeQueryComponent($0.name) + "=" + encodeQueryComponent($0.value) }
            .joined(separator: "&")
        return URL(string: "https://jp.mercari.com/search?" + queryText)
    }

    /// クエリの値をエンコードする（空白は %20、記号の「+」は %2B、日本語は UTF-8 の %XX）
    private static func encodeQueryComponent(_ value: String) -> String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
    }

    // MARK: - ラクマ

    private static func buildRakumaURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "https://fril.jp/s")
        var items = [URLQueryItem(name: "query", value: query.keywordText(for: .parameter))]

        if !query.keyword.excludeTerms.isEmpty {
            items.append(URLQueryItem(name: "excluded_query", value: query.keyword.excludeText))
        }

        switch query.saleStatus {
        case .onSale:
            items.append(URLQueryItem(name: "transaction", value: "selling"))
        case .soldOut:
            items.append(URLQueryItem(name: "transaction", value: "soldout"))
        case .all:
            break
        }

        switch query.sortOption {
        case .priceAsc:
            items.append(URLQueryItem(name: "sort", value: "sell_price"))
            items.append(URLQueryItem(name: "order", value: "asc"))
        case .priceDesc:
            items.append(URLQueryItem(name: "sort", value: "sell_price"))
            items.append(URLQueryItem(name: "order", value: "desc"))
        case .recommended:
            items.append(URLQueryItem(name: "sort", value: "relevance"))
            items.append(URLQueryItem(name: "order", value: "desc"))
        case .newest:
            items.append(URLQueryItem(name: "sort", value: "created_at"))
            items.append(URLQueryItem(name: "order", value: "desc"))
        }

        if let categoryID = CameraParameters.rakumaCategory(scope: query.context.scope, category: query.category) {
            items.append(URLQueryItem(name: "category_id", value: categoryID))
        }

        components?.queryItems = items
        return makeURL(components)
    }

    // MARK: - Yahoo!フリマ

    private static func buildYahooFleamarketURL(_ query: Query) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "paypayfleamarket.yahoo.co.jp"
        components.percentEncodedPath = "/search/\(encodePathSegment(query.keywordText(for: .inlineMinus)))"

        var items: [URLQueryItem] = []
        switch query.saleStatus {
        case .onSale:
            items.append(URLQueryItem(name: "open", value: "1"))
        case .soldOut:
            items.append(URLQueryItem(name: "sold", value: "1"))
        case .all:
            break
        }

        switch query.sortOption {
        case .priceAsc:
            items.append(URLQueryItem(name: "sort", value: "price"))
            items.append(URLQueryItem(name: "order", value: "asc"))
        case .priceDesc:
            items.append(URLQueryItem(name: "sort", value: "price"))
            items.append(URLQueryItem(name: "order", value: "desc"))
        case .recommended:
            items.append(URLQueryItem(name: "sort", value: "ranking"))
            items.append(URLQueryItem(name: "order", value: "desc"))
        case .newest:
            items.append(URLQueryItem(name: "sort", value: "openTime"))
            items.append(URLQueryItem(name: "order", value: "desc"))
        }

        if let categoryIDs = CameraParameters.yahooFleamarketCategoryIDs(scope: query.context.scope, category: query.category) {
            items.append(URLQueryItem(name: "categoryIds", value: categoryIDs))
        }

        components.queryItems = items.isEmpty ? nil : items
        return makeURL(components)
    }

    // MARK: - ヤフオク

    private static func buildYahooAuctionsURL(_ query: Query) -> URL? {
        let isClosed = query.saleStatus == .soldOut
        let base = isClosed
            ? "https://auctions.yahoo.co.jp/closedsearch/closedsearch"
            : "https://auctions.yahoo.co.jp/search/search"
        var components = URLComponents(string: base)
        var items = [URLQueryItem(name: "p", value: query.keywordText(for: .inlineMinus))]

        if let category = CameraParameters.yahooAuctionsCategory(scope: query.context.scope, category: query.category) {
            items.append(URLQueryItem(name: "auccat", value: category))
        }

        switch query.sortOption {
        case .priceAsc:
            items.append(URLQueryItem(name: "s1", value: "cbids"))
            items.append(URLQueryItem(name: "o1", value: "a"))
        case .priceDesc:
            items.append(URLQueryItem(name: "s1", value: "cbids"))
            items.append(URLQueryItem(name: "o1", value: "d"))
        case .recommended:
            // 出品中はサイトの初期設定（おすすめ順）。落札相場にはおすすめ順がないので「終了日時が近い順」
            if isClosed {
                items.append(URLQueryItem(name: "s1", value: "end"))
                items.append(URLQueryItem(name: "o1", value: "d"))
            }
        case .newest:
            // 落札相場は「終了日時が近い順」、出品中は「新着順」
            items.append(URLQueryItem(name: "s1", value: isClosed ? "end" : "new"))
            items.append(URLQueryItem(name: "o1", value: "d"))
        }

        components?.queryItems = items
        return makeURL(components)
    }

    private static func buildYahooAuctionsAppURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "yjauctions://searchItem")
        var items = [
            URLQueryItem(name: "keyword", value: query.keywordText(for: .inlineMinus)),
            URLQueryItem(name: "category_id", value: "0")
        ]

        if query.saleStatus == .onSale {
            items.append(URLQueryItem(name: "status", value: "open"))
        }

        switch query.sortOption {
        case .priceAsc:
            items.append(URLQueryItem(name: "sort", value: "cbids"))
            items.append(URLQueryItem(name: "order", value: "asc"))
            items.append(URLQueryItem(name: "s1", value: "cbids"))
            items.append(URLQueryItem(name: "o1", value: "a"))
        case .priceDesc:
            items.append(URLQueryItem(name: "sort", value: "cbids"))
            items.append(URLQueryItem(name: "order", value: "desc"))
            items.append(URLQueryItem(name: "s1", value: "cbids"))
            items.append(URLQueryItem(name: "o1", value: "d"))
        case .recommended:
            // アプリの初期設定（おすすめ順）のまま
            break
        case .newest:
            items.append(URLQueryItem(name: "sort", value: "new"))
            items.append(URLQueryItem(name: "order", value: "desc"))
            items.append(URLQueryItem(name: "s1", value: "new"))
            items.append(URLQueryItem(name: "o1", value: "d"))
        }

        components?.queryItems = items
        return makeURL(components)
    }

    // MARK: - Amazon

    private static func buildAmazonURL(_ query: Query, includesAffiliateID: Bool) -> URL? {
        var components = URLComponents(string: "https://www.amazon.co.jp/s")
        var items = [URLQueryItem(name: "k", value: query.keywordText(for: .unsupported))]
        if let refinement = CameraParameters.amazonRefinement(
            scope: query.context.scope,
            category: query.category,
            usedOnly: query.usedOnly
        ) {
            items.append(URLQueryItem(name: "rh", value: refinement))
        }

        switch query.sortOption {
        case .priceAsc:
            items.append(URLQueryItem(name: "s", value: "price-asc-rank"))
        case .priceDesc:
            items.append(URLQueryItem(name: "s", value: "price-desc-rank"))
        case .recommended:
            items.append(URLQueryItem(name: "s", value: "relevanceblender"))
        case .newest:
            items.append(URLQueryItem(name: "s", value: "date-desc-rank"))
        }

        if includesAffiliateID {
            items.append(URLQueryItem(name: "tag", value: amazonAssociateTag))
        }

        components?.queryItems = items
        return makeURL(components)
    }

    // MARK: - 楽天市場

    private static func buildRakutenURL(_ query: Query, includesAffiliateID: Bool) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "search.rakuten.co.jp"
        let genrePath = CameraParameters.rakutenPath(scope: query.context.scope, category: query.category)
        components.percentEncodedPath = "/search/mall/\(encodePathSegment(query.keywordText(for: .parameter)))/\(genrePath)"

        var items: [URLQueryItem] = []
        if !query.keyword.excludeTerms.isEmpty {
            items.append(URLQueryItem(name: "nitem", value: query.keyword.excludeText))
        }
        if query.usedOnly {
            items.append(URLQueryItem(name: "used", value: "1"))
        }

        switch query.sortOption {
        case .priceAsc:
            items.append(URLQueryItem(name: "s", value: "2"))
        case .priceDesc:
            items.append(URLQueryItem(name: "s", value: "3"))
        case .recommended:
            // 楽天市場の「標準」（並び順を指定しない）
            break
        case .newest:
            items.append(URLQueryItem(name: "s", value: "4"))
        }

        components.queryItems = items.isEmpty ? nil : items
        guard let searchURL = makeURL(components) else { return nil }
        return includesAffiliateID ? rakutenAffiliateURL(for: searchURL) : searchURL
    }

    /// 楽天アフィリエイトのリンク（楽天の計測ページを経由して、pc に入れた検索結果へ移動する）。
    /// 例: https://hb.afl.rakuten.co.jp/hgc/<ID>/?pc=https%3A%2F%2Fsearch.rakuten.co.jp%2Fsearch%2Fmall%2FiPhone%252017%2F
    private static func rakutenAffiliateURL(for destination: URL) -> URL? {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let encoded = destination.absoluteString.addingPercentEncoding(withAllowedCharacters: unreserved) else { return nil }
        return URL(string: "https://hb.afl.rakuten.co.jp/hgc/\(rakutenAffiliateID)/?pc=\(encoded)")
    }

    // MARK: - ヨドバシカメラ

    private static func buildYodobashiURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "https://www.yodobashi.com/")
        var items = [URLQueryItem(name: "word", value: query.keywordText(for: .unsupported))]

        switch query.sortOption {
        case .priceAsc:
            items.append(URLQueryItem(name: "sorttyp", value: "SELL_PRICE_ASC"))
        case .priceDesc:
            items.append(URLQueryItem(name: "sorttyp", value: "SELL_PRICE_DESC"))
        case .recommended:
            // ヨドバシの「人気順」
            items.append(URLQueryItem(name: "sorttyp", value: "COINCIDENCE_RANKING"))
        case .newest:
            items.append(URLQueryItem(name: "sorttyp", value: "NEW_ARRIVAL_RANKING"))
        }
        // 販売終了品は表示しない
        items.append(URLQueryItem(name: "discontinued", value: "false"))

        components?.queryItems = items
        return makeURL(components)
    }

    /// ヨドバシアプリのキーワード検索（App Store の説明に記載の公式スキーム）
    private static func buildYodobashiAppURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "yodobashi://search")
        components?.queryItems = [URLQueryItem(name: "q", value: query.keywordText(for: .unsupported))]
        return makeURL(components)
    }

    // MARK: - ビックカメラ

    /// ビックカメラは日本語のキーワードを Shift_JIS で受け取る（UTF-8 だと文字化けする）
    private static func buildBicCameraURL(_ query: Query) -> URL? {
        let keyword = encodeShiftJIS(query.keywordText(for: .unsupported))

        // 「人気・おすすめ順」は並び順を指定しない（サイトの初期設定）
        let sort: String?
        switch query.sortOption {
        case .recommended: sort = nil
        case .priceAsc: sort = "02"
        case .priceDesc: sort = "03"
        case .newest: sort = "01"
        }

        let sortQuery = sort.map { "&sort=\($0)" } ?? ""
        return URL(string: "https://www.biccamera.com/bc/category/?q=\(keyword)\(sortQuery)")
    }

    /// Shift_JIS でパーセントエンコードする（空白は「+」）。変換できない文字は「?」になる
    private static func encodeShiftJIS(_ text: String) -> String {
        guard let data = text.data(using: .shiftJIS, allowLossyConversion: true) else { return "" }
        let unreserved = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8)
        return data.map { byte -> String in
            if byte == UInt8(ascii: " ") { return "+" }
            if unreserved.contains(byte) { return String(UnicodeScalar(byte)) }
            return String(format: "%%%02X", byte)
        }.joined()
    }

    // MARK: - マップカメラ

    private static func buildMapCameraURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "https://www.mapcamera.com/search")
        var items = [URLQueryItem(name: "keyword", value: query.keywordText(for: .unsupported))]

        if query.usedOnly {
            items.append(URLQueryItem(name: "sell", value: "used"))
        }

        // 不明な値は人気順に戻されるので、サイト内のリンクと同じ値を使う
        // （新着順は「dateasc」。マップカメラの新着中古の一覧リンクがこの値を使っている）
        switch query.sortOption {
        case .priceAsc:
            items.append(URLQueryItem(name: "sort", value: "priceasc"))
        case .priceDesc:
            items.append(URLQueryItem(name: "sort", value: "pricedesc"))
        case .newest:
            items.append(URLQueryItem(name: "sort", value: "dateasc"))
        case .recommended:
            break // 人気順（サイトの初期設定）
        }

        components?.queryItems = items
        return makeURL(components)
    }

    // MARK: - カメラのキタムラ

    private static func buildKitamuraURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "https://shop.kitamura.jp/ec/list")
        var items = [URLQueryItem(name: "keyword", value: query.keywordText(for: .unsupported))]

        if query.usedOnly {
            items.append(URLQueryItem(name: "type", value: "u"))
        }

        switch query.sortOption {
        case .priceAsc:
            items.append(URLQueryItem(name: "sort", value: "price_asc"))
        case .priceDesc:
            items.append(URLQueryItem(name: "sort", value: "price_desc"))
        case .newest:
            items.append(URLQueryItem(name: "sort", value: "update_date"))
        case .recommended:
            break // 一致度順（サイトの初期設定）
        }

        components?.queryItems = items
        return makeURL(components)
    }

    // MARK: - フジヤカメラ

    private static func buildFujiyaURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "https://www.fujiya-camera.co.jp/shop/goods/search.aspx")
        var items = [
            URLQueryItem(name: "search", value: "x"),
            URLQueryItem(name: "keyword", value: query.keywordText(for: .unsupported))
        ]

        // 新品=10、中古=20
        if query.usedOnly {
            items.append(URLQueryItem(name: "category", value: "20"))
        }

        switch query.sortOption {
        case .priceAsc:
            items.append(URLQueryItem(name: "sort", value: "4"))
        case .priceDesc:
            items.append(URLQueryItem(name: "sort", value: "5"))
        case .newest:
            items.append(URLQueryItem(name: "sort", value: "1"))
        case .recommended:
            break // おすすめ順（サイトの初期設定）
        }

        components?.queryItems = items
        return makeURL(components)
    }

    // MARK: - カメラのナニワ

    /// ナニワは日本語のキーワードを Shift_JIS で受け取る
    private static func buildNaniwaURL(_ query: Query) -> URL? {
        var url = "https://cameranonaniwa.jp/shop/goods/search.aspx?search=x&pb_search=x"
        // 買う（新品・中古）=1,2、中古のみ=2
        url += "&pb_salestype=" + (query.usedOnly ? "2" : "1%2C2")
        url += "&pb_keyword=" + encodeShiftJIS(query.keywordText(for: .unsupported))

        switch query.sortOption {
        case .priceAsc: url += "&sort=2"
        case .priceDesc: url += "&sort=1"
        case .newest: url += "&sort=3"
        case .recommended: break // おすすめ順（サイトの初期設定）
        }

        return URL(string: url)
    }
}
