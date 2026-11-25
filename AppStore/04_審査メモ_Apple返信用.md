# Apple 審査（Guideline 2.1 Information Needed）への返信用

## 使い方
1. 下の「■ メモ欄に貼る英文」を、App Store Connect の Appレビュー情報 →「メモ」に貼り付ける（既存の内容は置き換えてOK）
2. `【動画URL】` を、実機で撮った画面収録のURLに置き換える（撮り方は末尾）
3. 保存 → 解決センターの該当スレッドに「Notes を更新しました」と一言返信 → 再提出

---

## ■ メモ欄に貼る英文

```
Thank you for reviewing Nemiru Camera (ネミル カメラ). Answers to the items requested:

1. SCREEN RECORDING (physical iPhone, latest iOS, starting from app launch):
【動画URL】
The recording shows: launching the app, choosing a maker, typing a model name, tapping a marketplace or used-camera-shop button to open results, switching to sold listings to check sold prices, scanning a barcode with the camera, saving a search, and the Settings tab. The app has no account registration, login, user-generated content, or paid content/features, so none of those flows exist.

2. PURPOSE AND TARGET AUDIENCE
Nemiru Camera is a search launcher for people in Japan who buy or sell used cameras and lenses. Prices for the same camera or lens differ between flea-market sites and used-camera shops, and checking each site one by one is tedious. On the "カメラ" tab the user picks a maker, enters a model name (e.g. "Z6II" or "RF24-70mm"), and taps a button to open that site's search results. The app limits each site's search to its camera category and can restrict results to used items. The app itself does not sell anything and does not display prices; it only builds search URLs.

3. HOW TO USE THE MAIN FEATURES
No login, demo account, or sample files are needed.
- "カメラ" tab: choose a maker from the menu (e.g. "Nikon"), type a model name, then tap a button such as メルカリ, ヤフオク, マップカメラ or キタムラ. Results open in an in-app Safari view (SFSafariViewController); some buttons open the site's official app if it is installed.
- "売り切れ" (sold) mode: shows recently sold listings so the user can see actual selling prices.
- "検索" tab: free keyword search for accessories such as tripods and bags.
- Barcode: tap the barcode icon in the search field and allow camera access, then point the camera at a JAN/EAN barcode. Requires a real device with a camera.
- "+ キーワードを保存": saves the keyword locally. History is also kept locally.
- "設定" (Settings) tab: choose a default maker and the used-only option (マイ設定).

4. EXTERNAL SERVICES USED
- openBD (https://api.openbd.jp): when an ISBN barcode is scanned, only the ISBN is sent to look up the book title. No personal data is sent.
- Websites opened via search URL (Safari View Controller): Mercari, Rakuma, Yahoo! Flea Market, Yahoo! Auctions, Amazon.co.jp, Rakuten Ichiba, Yodobashi Camera, BicCamera, Map Camera, Camera no Kitamura, Fujiya Camera, Camera no Naniwa, RE Camera, ONE SCENE. The app only opens public search pages; it does not use their APIs, log in on the user's behalf, or scrape their content.
- No analytics, advertising, authentication, payment, or AI services are used. No data is sent to the developer's servers. Search history, saved searches, and settings are stored only on the device.

5. REGIONAL DIFFERENCES
The app is intended for Japan. The UI is in Japanese, and the sites listed above are Japanese services. The app behaves the same in every region; there is no region-specific code or content.

6. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
The app is not in a regulated industry and contains no third-party protected content. Service and maker names are used only to label search buttons and filter choices; Nemiru Camera is not affiliated with or endorsed by those companies, and the app description says so. Privacy policy: https://soshilow.github.io/nemiru-camera/privacy.html
Contact: soshiro.app@gmail.com

7. DIFFERENCE FROM THE DEVELOPER'S OTHER APPS (Guideline 4.3)
Nemiru Camera is dedicated to used cameras and lenses. Its filters (camera and lens makers, each site's camera category, and used-only) and its list of used-camera specialty shops (Map Camera, Kitamura, Fujiya Camera, Naniwa, RE Camera, ONE SCENE) do not exist in the developer's other apps, which target different product types and shops.
```

---

## 画面収録の撮り方（実機が必要です）
Apple は **実機での収録** を求めています。シミュレータの録画では通らない可能性が高く、バーコード読み取りもカメラのある実機でしか動きません。

1. iPhone を最新の iOS にし、アプリを Xcode から入れる（またはTestFlightで入れる）
2. 設定 → コントロールセンター →「画面収録」を追加
3. コントロールセンターの録画ボタンで開始（3秒後に始まる）
4. **アプリを起動するところから**撮る。流れの例（1〜2分）
   - カメラタブで型番を入力 → メルカリ・マップカメラ等を1〜2つタップして結果表示 → 戻る
   - バーコードアイコン → カメラ許可 → 本やパッケージのバーコードを読み取る
   - 「＋キーワードを保存」→ 保存済みが増える
   - カメラタブでメーカーを選んで検索、売り切れに切り替えて相場を見る
   - 設定タブでマイ設定を選ぶ
5. 録画を止め、写真アプリから Mac に送る
6. YouTube（限定公開）か Google Drive（リンクを知っている人が閲覧可）にアップロードし、URLを英文の `【動画URL】` に貼る
   - App Store Connect に動画ファイルを添付できる場合は、そちらでも構いません
