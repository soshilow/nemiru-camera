import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettingsKey.myMaker) private var myMakerText = ""
    @AppStorage(AppSettingsKey.myUsedOnly) private var myUsedOnly = true

    private var myMaker: CameraMaker? {
        CameraMaker(rawValue: myMakerText)
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

                    Toggle("中古品のみ", isOn: $myUsedOnly)
                } header: {
                    Text("マイ設定")
                } footer: {
                    Text("アプリを起動したとき、カメラページで最初から選ばれた状態になります。カメラページでは、各サイトのカメラのカテゴリで検索します。「中古品のみ」はAmazon・楽天市場・中古カメラ店で効きます（フリマ・オークションはもともと中古が中心です）。")
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
