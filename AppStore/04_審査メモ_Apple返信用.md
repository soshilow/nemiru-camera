# Apple 審査（Guideline 2.1 Information Needed）への返信用

## 使い方
1. 下の「■ メモ欄に貼る英文」を、App Store Connect の Appレビュー情報 →「メモ」に貼り付ける（既存の内容は置き換えてOK）
2. `【動画URL】` を、実機で撮った画面収録のURLに置き換える（撮り方は末尾）
3. 保存 → 解決センターの該当スレッドに「Notes を更新しました」と一言返信 → 再提出

---

## ■ メモ欄に貼る英文

```
Thank you for reviewing Nemiru Sumaho (ネミル スマホ). Answers to the items requested:

1. SCREEN RECORDING (physical iPhone, latest iOS, starting from app launch):
【動画URL】
The recording shows: launching the app, typing a keyword, tapping a marketplace button to open results, scanning a barcode with the camera, saving a search, using the iPhone tab (model, storage and SIM-free filters), and the Settings tab. The app has no account registration, login, user-generated content, or paid content/features, so none of those flows exist.

2. PURPOSE AND TARGET AUDIENCE
Nemiru Sumaho is a search launcher for people in Japan who buy or sell used smartphones. Prices for the same item differ between flea-market and shopping sites, and checking each site one by one is tedious. The user enters a keyword (or scans a barcode), picks a sale status and sort order, and taps a button to open that site's search results for the same keyword. On the iPhone tab the user can pick a model, storage size and SIM-free option (and save them once as "My model"); the app then limits each site's search to its smartphone category. The app itself does not sell anything and does not display prices; it only builds search URLs.

3. HOW TO USE THE MAIN FEATURES
No login, demo account, or sample files are needed.
- "検索" tab: type a keyword in the search field (e.g. "Nintendo Switch"), then tap a site button such as メルカリ or Amazon. The results open in an in-app Safari view (SFSafariViewController); some buttons open the site's official app if it is installed.
- Barcode: tap the barcode icon in the search field and allow camera access. Point the camera at a JAN/EAN-13 or EAN-8 barcode (a book ISBN barcode also works). Barcode scanning requires a real device with a camera.
- "iPhone" tab: choose a model from the menu (e.g. "iPhone 15"), optionally a storage size and "SIMフリーのみ", then tap a site button.
- Bookmark/"+ キーワードを保存": saves the keyword locally. History is also kept locally.
- "設定" (Settings) tab: choose "My model" (マイ機種).

4. EXTERNAL SERVICES USED
- openBD (https://api.openbd.jp): when an ISBN barcode is scanned, only the ISBN is sent to look up the book title. No personal data is sent.
- Websites opened via search URL (Safari View Controller): Mercari, Rakuma, Yahoo! Flea Market, Yahoo! Auctions, Amazon.co.jp, Rakuten Ichiba, Yodobashi Camera, BicCamera, iosys, Janpara, Sofmap, GEO, nicosuma, Back Market. The app only opens public search pages; it does not use their APIs, log in on the user's behalf, or scrape their content.
- No analytics, advertising, authentication, payment, or AI services are used. No data is sent to the developer's servers. Search history, saved searches, and settings are stored only on the device.

5. REGIONAL DIFFERENCES
The app is intended for Japan. The UI is in Japanese, and the sites listed above are Japanese services, so the app is most useful in Japan. The app's features behave the same in every region; there is no region-specific code or content. Availability and results depend on each website.

6. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
The app is not in a regulated industry and contains no third-party protected content. Service and product names are used only to label search buttons and model choices; Nemiru Sumaho is not affiliated with or endorsed by those companies, and the app description says so. Privacy policy: https://soshilow.github.io/nemiru-iphone/privacy.html
Contact: soshiro.app@gmail.com
```

---

## 画面収録の撮り方（実機が必要です）
Apple は **実機での収録** を求めています。シミュレータの録画では通らない可能性が高く、バーコード読み取りもカメラのある実機でしか動きません。

1. iPhone を最新の iOS にし、アプリを Xcode から入れる（またはTestFlightで入れる）
2. 設定 → コントロールセンター →「画面収録」を追加
3. コントロールセンターの録画ボタンで開始（3秒後に始まる）
4. **アプリを起動するところから**撮る。流れの例（1〜2分）
   - 検索タブでキーワード入力 → メルカリ等を1〜2つタップして結果表示 → 戻る
   - バーコードアイコン → カメラ許可 → 本やパッケージのバーコードを読み取る
   - 「＋キーワードを保存」→ 保存済みが増える
   - iPhoneタブで機種・容量を選んで検索
   - 設定タブでマイ機種を選ぶ
5. 録画を止め、写真アプリから Mac に送る
6. YouTube（限定公開）か Google Drive（リンクを知っている人が閲覧可）にアップロードし、URLを英文の `【動画URL】` に貼る
   - App Store Connect に動画ファイルを添付できる場合は、そちらでも構いません
