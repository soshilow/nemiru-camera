import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettingsKey.myModel) private var myModelText = ""
    @AppStorage(AppSettingsKey.myStorage) private var myStorageText = ""
    @AppStorage(AppSettingsKey.mySimFreeOnly) private var mySimFreeOnly = false

    private var myModel: PhoneModel? {
        PhoneModel(rawValue: myModelText)
    }

    private var myStorage: PhoneStorage? {
        PhoneStorage(rawValue: myStorageText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        Text("機種")

                        Spacer(minLength: 8)

                        Menu {
                            Button("指定なし") { myModelText = "" }
                            ForEach(PhoneModel.generations, id: \.title) { generation in
                                Section(generation.title) {
                                    ForEach(generation.models) { model in
                                        Button(model.keyword) { myModelText = model.rawValue }
                                    }
                                }
                            }
                        } label: {
                            Text(myModel?.keyword ?? "指定なし")
                                .foregroundStyle(myModel == nil ? Color.secondary : Color.blue)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("容量")

                        Spacer(minLength: 8)

                        Menu {
                            Button("指定なし") { myStorageText = "" }
                            ForEach(PhoneStorage.allCases) { storage in
                                Button(storage.rawValue) { myStorageText = storage.rawValue }
                            }
                        } label: {
                            Text(myStorage?.rawValue ?? "指定なし")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(myStorage == nil ? Color.secondary : Color.blue)
                        }
                    }

                    Toggle("SIMフリーのみ", isOn: $mySimFreeOnly)
                } header: {
                    Text("マイ機種")
                } footer: {
                    Text("アプリを起動したとき、iPhoneページで最初から選ばれた状態になります。iPhoneページでは、各サイトのスマホ本体（iPhone）のカテゴリで検索します。容量・SIMフリーは、条件で絞れないサイトではキーワードに付け足して検索します。")
                }

                Section {
                    LabeledContent("バージョン", value: Self.appVersion)
                } footer: {
                    Text("メルカリの検索リンクには、メルカリアンバサダー（アフィリエイト）のIDが含まれています。")
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
