import Foundation

/// 各サービスの検索URLを組み立てる。
///
/// パラメータは 2026-11 時点で各サイトの検索画面から確認したもの:
/// - メルカリ: status=on_sale / sold_out|trading、除外は exclude_keyword
/// - ラクマ: transaction=selling / soldout、除外は excluded_query
/// - Yahoo!フリマ: open=1 / sold=1、キーワード内の「-ワード」で除外可
/// - ヤフオク: 出品中は /search/search、落札相場は /closedsearch/closedsearch
/// - 楽天市場: 除外は nitem
/// - ヨドバシカメラ: sorttyp で並び順、除外ワード非対応（検索ページのみ）
/// - ビックカメラ: キーワードは Shift_JIS で送る、sort で並び順、除外ワード非対応（検索ページのみ）
/// - イオシス: sort=l / h で価格順、除外は not、販売中のみ（iPhone ページのみ）
/// - じゃんぱら: OUTCLSCODE=78 で iPhone、ORDER で並び順、販売中のみ・除外ワード非対応（iPhone ページのみ）
/// - ソフマップ: gid=001070 でスマートフォン、product_type=USED で中古、order_by で並び順（iPhone ページのみ）
/// - ゲオ: tree=1001 で iPhone、キーワード・除外（q_not）は Shift_JIS、sort で並び順（iPhone ページのみ）
/// - Back Market: キーワードのみ（並び順・除外は URL で渡せない）（iPhone ページのみ）
///
/// iPhone ページのカテゴリ・容量・SIMフリーは PhoneParameters を参照
/// （ヤフオクは iPhone ページではアプリ内ブラウザで Web 版を開く）。
struct SearchURLBuilder {
    static func buildURL(
        for service: MarketplaceService,
        filter: SearchFilterState,
        context: SearchContext = .general
    ) -> URL? {
        let query = Query(filter: filter, context: context, service: service)
        guard !query.keyword.includeTerms.isEmpty else { return nil }

        switch service {
        case .mercari:
            return buildMercariURL(query)
        case .rakuma:
            return buildRakumaURL(query)
        case .yahooFleamarket:
            return buildYahooFleamarketURL(query)
        case .yahooAuctions:
            return buildYahooAuctionsURL(query)
        case .amazon:
            return buildAmazonURL(query)
        case .rakuten:
            return buildRakutenURL(query)
        case .yodobashi:
            return buildYodobashiURL(query)
        case .bicCamera:
            return buildBicCameraURL(query)
        case .iosys:
            return buildIosysURL(query)
        case .janpara:
            return buildJanparaURL(query)
        case .sofmap:
            return buildSofmapURL(query)
        case .geo:
            return buildGeoURL(query)
        case .backMarket:
            return buildBackMarketURL(query)
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
        let storage: PhoneStorage?
        let simFreeOnly: Bool

        init(filter: SearchFilterState, context: SearchContext, service: MarketplaceService) {
            var keyword = filter.parsedKeyword
            // 容量・SIM条件はそのページのものだけ使う
            let isPhonePage = context.scope == .iphone
            storage = isPhonePage ? filter.storage : nil
            simFreeOnly = isPhonePage && filter.simFreeOnly

            if !keyword.includeTerms.isEmpty {
                // 条件で渡せない容量・SIMフリーはキーワードに付け足す（入力済みの語は重ねない）
                let existing = Set(keyword.includeTerms.map { $0.lowercased() })
                let additions = PhoneParameters.keywordAdditions(for: service, storage: storage, simFreeOnly: simFreeOnly)
                keyword.includeTerms += additions.filter { !existing.contains($0.lowercased()) }

                if PhoneParameters.prefersCompactModelName(service) {
                    keyword = ParsedKeyword(PhoneParameters.compactModelName(keyword.inlineText))
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

    private static func buildMercariURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "https://jp.mercari.com/search")
        var items = [URLQueryItem(name: "keyword", value: query.keywordText(for: .parameter))]

        if !query.keyword.excludeTerms.isEmpty {
            items.append(URLQueryItem(name: "exclude_keyword", value: query.keyword.excludeText))
        }

        switch query.saleStatus {
        case .onSale:
            items.append(URLQueryItem(name: "status", value: "on_sale"))
        case .soldOut:
            items.append(URLQueryItem(name: "status", value: "sold_out|trading"))
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
            items.append(URLQueryItem(name: "sort", value: "score"))
            items.append(URLQueryItem(name: "order", value: "desc"))
        case .newest:
            items.append(URLQueryItem(name: "sort", value: "created_time"))
            items.append(URLQueryItem(name: "order", value: "desc"))
        }

        items.append(contentsOf: PhoneParameters.mercari(scope: query.context.scope, simFreeOnly: query.simFreeOnly))

        components?.queryItems = items
        return makeURL(components)
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

        items.append(contentsOf: PhoneParameters.rakuma(scope: query.context.scope))

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

        items.append(contentsOf: PhoneParameters.yahooFleamarket(scope: query.context.scope))

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

        items.append(contentsOf: PhoneParameters.yahooAuctions(scope: query.context.scope))

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

    private static func buildAmazonURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "https://www.amazon.co.jp/s")
        var items = [URLQueryItem(name: "k", value: query.keywordText(for: .unsupported))]
        if let refinement = PhoneParameters.amazonRefinement(scope: query.context.scope) {
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

        components?.queryItems = items
        return makeURL(components)
    }

    // MARK: - 楽天市場

    private static func buildRakutenURL(_ query: Query) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "search.rakuten.co.jp"
        let genrePath = PhoneParameters.rakutenPath(
            scope: query.context.scope,
            storage: query.storage,
            simFreeOnly: query.simFreeOnly
        )
        components.percentEncodedPath = "/search/mall/\(encodePathSegment(query.keywordText(for: .parameter)))/\(genrePath)"

        var items: [URLQueryItem] = []
        if !query.keyword.excludeTerms.isEmpty {
            items.append(URLQueryItem(name: "nitem", value: query.keyword.excludeText))
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
        return makeURL(components)
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

    // MARK: - イオシス

    private static func buildIosysURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "https://iosys.co.jp/items")
        var items = [URLQueryItem(name: "q", value: query.keywordText(for: .parameter))]

        if !query.keyword.excludeTerms.isEmpty {
            items.append(URLQueryItem(name: "not", value: query.keyword.excludeText))
        }

        switch query.sortOption {
        case .priceAsc:
            items.append(URLQueryItem(name: "sort", value: "l"))
        case .priceDesc:
            items.append(URLQueryItem(name: "sort", value: "h"))
        case .recommended, .newest:
            break // おすすめ順（サイトの初期設定。新着順はない）
        }

        components?.queryItems = items
        return makeURL(components)
    }

    // MARK: - じゃんぱら

    private static func buildJanparaURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "https://www.janpara.co.jp/sale/search/result/")
        var items = [URLQueryItem(name: "KEYWORDS", value: query.keywordText(for: .unsupported))]

        // 商品カテゴリ：iPhone=78
        if query.context.scope == .iphone {
            items.append(URLQueryItem(name: "OUTCLSCODE", value: "78"))
        }

        switch query.sortOption {
        case .priceAsc:
            items.append(URLQueryItem(name: "ORDER", value: "3"))
        case .priceDesc:
            items.append(URLQueryItem(name: "ORDER", value: "2"))
        case .newest:
            items.append(URLQueryItem(name: "ORDER", value: "4"))
        case .recommended:
            break // サイトの初期設定
        }

        components?.queryItems = items
        return makeURL(components)
    }

    // MARK: - ソフマップ

    /// ソフマップは日本語のキーワードを Shift_JIS で受け取る（UTF-8 だとエラーページになる）
    private static func buildSofmapURL(_ query: Query) -> URL? {
        let keyword = encodeShiftJIS(query.keywordText(for: .unsupported))

        let order: String
        switch query.sortOption {
        case .recommended: order = "DEFAULT"
        case .priceAsc: order = "PRICE_ASC"
        case .priceDesc: order = "PRICE_DESC"
        case .newest: order = "DATE_DESC" // 発売日が新しい順（入荷順はない）
        }

        // スマートフォン=001070、中古のみ
        return URL(string: "https://www.sofmap.com/search_result.aspx?keyword=\(keyword)&gid=001070&product_type=USED&order_by=\(order)")
    }

    // MARK: - ゲオ

    /// ゲオは日本語のキーワードを Shift_JIS で受け取る（UTF-8 だと検索結果が0件になる）
    private static func buildGeoURL(_ query: Query) -> URL? {
        var url = "https://ec.geo-online.co.jp/shop/goods/search.aspx?search.x=0"
        url += "&keyword=" + encodeShiftJIS(query.keywordText(for: .parameter))

        // 商品カテゴリ：iPhone=1001
        if query.context.scope == .iphone {
            url += "&tree=1001"
        }
        if !query.keyword.excludeTerms.isEmpty {
            url += "&q_not=" + encodeShiftJIS(query.keyword.excludeText)
        }

        switch query.sortOption {
        case .priceAsc: url += "&sort=sp"
        case .priceDesc: url += "&sort=spd"
        case .newest: url += "&sort=rd" // 発売日が新しい順（入荷順はない）
        case .recommended: break // 人気順（サイトの初期設定）
        }

        return URL(string: url)
    }

    // MARK: - Back Market

    private static func buildBackMarketURL(_ query: Query) -> URL? {
        var components = URLComponents(string: "https://www.backmarket.co.jp/ja-jp/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query.keywordText(for: .unsupported))]
        return makeURL(components)
    }
}
