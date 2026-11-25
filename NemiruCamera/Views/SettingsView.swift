import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettingsKey.myMaker) private var myMakerText = ""
    @AppStorage(AppSettingsKey.myCategory) private var myCategoryText = CameraCategory.all.rawValue
    @AppStorage(AppSettingsKey.myUsedOnly) private var myUsedOnly = true
    @AppStorage(AppSettingsKey.myExcludeJunk) private var myExcludeJunk = false

    private var myMaker: CameraMaker? {
        CameraMaker(rawValue: myMakerText)
    }

    private var myCategory: Binding<CameraCategory> {
        Binding(
            get: { CameraCategory(rawValue: myCategoryText) ?? .all },
            set: { myCategoryText = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        Text("メーカー")

                        Spacer(minLength: 8)

                        Menu {
                            Button("指定なし") { myMakerText = "" }
                            ForEach(CameraMaker.groups, id: \.title) { group in
                                Section(group.title) {
                                    ForEach(group.makers) { maker in
                                        Button(maker.menuTitle) { myMakerText = maker.rawValue }
                                    }
                                }
                            }
                        } label: {
                            Text(myMaker?.keyword ?? "指定なし")
                                .foregroundStyle(myMaker == nil ? Color.secondary : Color.blue)
                        }
                    }

                    Picker("種類", selection: myCategory) {
                        ForEach(CameraCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }

                    Toggle("中古品のみ", isOn: $myUsedOnly)
                    Toggle("ジャンク品を除く", isOn: $myExcludeJunk)
                } header: {
                    Text("マイ設定")
                } footer: {
                    Text("アプリを起動したとき、カメラページで最初から選ばれた状態になります。カメラページでは、各サイトのカメラ・レンズのカテゴリで検索します。「中古品のみ」はAmazon・楽天市場・中古カメラ店で効きます（フリマ・オークションはもともと中古が中心です）。「ジャンク品を除く」は「ジャンク」を除外ワードとして送ります。")
                }

                Section {
                    LabeledContent("バージョン", value: Self.appVersion)
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("メルカリの検索リンクには、メルカリアンバサダー（アフィリエイト）のIDが含まれています。")
                        Text("Amazonのアソシエイトとして、ネミル カメラは適格販売により収入を得ています。")
                        Text("楽天市場の検索リンクは、楽天アフィリエイトのリンク（PR）です。")
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }
}
