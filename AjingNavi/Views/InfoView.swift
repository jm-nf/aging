import SwiftUI

struct InfoView: View {
    var body: some View {
        NavigationStack {
            List {
                tackleSection
                techniqueSection
                ruleSection
                safetySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("アジング情報")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var tackleSection: some View {
        Section {
            NavigationLink {
                TackleGuideView()
            } label: {
                Label("タックル・ルアーガイド", systemImage: "wrench.and.screwdriver.fill")
            }
        } header: {
            Text("タックル")
        }
    }

    private var techniqueSection: some View {
        Section {
            NavigationLink {
                TechniqueView()
            } label: {
                Label("釣り方・テクニック", systemImage: "figure.fishing")
            }
            NavigationLink {
                FieldGuideView()
            } label: {
                Label("横浜・横須賀 フィールドガイド", systemImage: "map.fill")
            }
        } header: {
            Text("テクニック")
        }
    }

    private var ruleSection: some View {
        Section {
            NavigationLink {
                RulesView()
            } label: {
                Label("スポットルールとマナー", systemImage: "checkmark.shield.fill")
            }
        } header: {
            Text("マナー・ルール")
        }
    }

    private var safetySection: some View {
        Section {
            NavigationLink {
                SafetyView()
            } label: {
                Label("夜釣りの安全対策", systemImage: "flashlight.on.fill")
            }
        } header: {
            Text("安全")
        }
    }
}

struct TackleGuideView: View {
    struct TackleItem: Identifiable {
        let id = UUID()
        let category: String
        let items: [(name: String, detail: String, beginner: Bool)]
    }

    let guides: [TackleItem] = [
        TackleItem(category: "ロッド", items: [
            ("アジングロッド 5〜7ft", "感度が高くアジのアタリを取りやすい専用ロッド", true),
            ("ライトロッド 6〜8ft", "メバリングロッドでも代用可。汎用性あり", true),
        ]),
        TackleItem(category: "リール", items: [
            ("スピニングリール 1000〜2000番", "軽量・高感度が重要。ダイワ・シマノの上位機種推奨", true),
        ]),
        TackleItem(category: "ライン", items: [
            ("エステルライン 0.2〜0.4号", "感度が高く主流。根ズレに弱いので注意", false),
            ("フロロライン 0.4〜0.6号", "初心者に扱いやすく耐久性あり", true),
            ("PEライン 0.2〜0.4号", "高感度・飛距離あり。リーダー必須", false),
        ]),
        TackleItem(category: "ジグヘッド", items: [
            ("0.3〜0.5g", "無風・流れが少ないとき。ゆっくり落とせる", false),
            ("0.8〜1.0g", "最もスタンダードな重さ。万能", true),
            ("1.5〜2.0g", "風が強いとき・深場・速い流れ向け", true),
        ]),
        TackleItem(category: "ワーム", items: [
            ("アジリンガー（エコギア）", "定番。ナチュラルな動きでアジに効く", true),
            ("アジリンガーPro", "アジリンガーの上位版。高アピール", true),
            ("バグアンツ（レインズ）", "甲殻類系。底付近で使うと効果的", false),
            ("ガルプ!ベビーサーディン", "集魚効果の高いエサ系ワーム", true),
        ]),
    ]

    var body: some View {
        List {
            ForEach(guides) { guide in
                Section(guide.category) {
                    ForEach(guide.items, id: \.name) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.name)
                                    .font(.subheadline.bold())
                                Spacer()
                                if item.beginner {
                                    Text("初心者向け")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundStyle(.green)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("タックルガイド")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TechniqueView: View {
    var body: some View {
        List {
            Section("基本の釣り方") {
                TechniqueRow(
                    title: "表層〜中層ただ巻き",
                    description: "キャスト後、ラインスラックを取りゆっくり一定速度でリトリーブ。アジが浮いているときに有効。",
                    level: "初心者"
                )
                TechniqueRow(
                    title: "カーブフォール",
                    description: "テンションを張ったまま沈める方法。フォール中のアタリを取りやすい。",
                    level: "中級者"
                )
                TechniqueRow(
                    title: "リフト&フォール",
                    description: "ロッドを上げてワームを持ち上げ、フォールさせる動作の繰り返し。縦の動きでアピール。",
                    level: "中級者"
                )
                TechniqueRow(
                    title: "ダートアクション",
                    description: "ロッドをチョンチョンと小刻みに動かしワームをダートさせる。活性が高いときに効果的。",
                    level: "上級者"
                )
            }

            Section("時間帯別の狙い方") {
                InfoTextRow(title: "朝マヅメ（夜明け前後）", text: "表層〜中層を中心に広くサーチ。マヅメ時のゴールデンタイム。")
                InfoTextRow(title: "日中", text: "潮の流れが速いポイントの底付近を狙う。渋くなりがち。")
                InfoTextRow(title: "夕マヅメ（日没前後）", text: "朝と同様に高活性。常夜灯周りも始まってくる。")
                InfoTextRow(title: "夜間", text: "常夜灯の明暗境界線が最大の狙い目。光と影の境界にワームを流し込む。")
            }

            Section("常夜灯攻略") {
                Text("アジは夜間、光に集まるプランクトンを捕食するために常夜灯周りに集まります。\n\n「明暗の境界線」を意識し、暗い側からワームを流し込むように、やや上流にキャストしてナチュラルドリフトさせましょう。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("アタリの取り方") {
                Text("アジのアタリは「コン」という小さな感触。ラインに少しテンションをかけた状態（カーブフォール中）でティップ（穂先）の動きを見ながら待ちましょう。アタリがあったら素早くアワセを入れます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("釣り方・テクニック")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TechniqueRow: View {
    let title: String
    let description: String
    let level: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                Spacer()
                let color: Color = level == "初心者" ? .green : level == "中級者" ? .orange : .red
                Text(level)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.15))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct InfoTextRow: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct FieldGuideView: View {
    var body: some View {
        List {
            Section("横浜エリア") {
                InfoTextRow(
                    title: "東京湾奥のアジング",
                    text: "横浜港周辺は比較的穏やかな海況。常夜灯が多く夜釣りに最適。水温が上がる5月以降がシーズン本番。"
                )
                InfoTextRow(
                    title: "八景島・野島エリア",
                    text: "金沢漁港や野島公園周辺は魚影が濃くアクセスも良好。夜の常夜灯周りが特に実績あり。"
                )
            }

            Section("横須賀エリア") {
                InfoTextRow(
                    title: "東京湾口のアジング",
                    text: "横須賀から走水にかけては東京湾の潮流が集まるポイント。大型アジの実績が高いが潮が速い。"
                )
                InfoTextRow(
                    title: "観音崎・走水",
                    text: "潮通しが抜群。上げ潮・下げ潮の潮変わりを狙う。釣り方の基本はカーブフォール＆ただ巻き。"
                )
            }

            Section("シーズンカレンダー") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("4〜5月").bold()
                        Text("シーズン開幕。小アジが多い")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("🌱").font(.title2)
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text("6〜9月").bold()
                        Text("最盛期。数・サイズとも期待大")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("☀️").font(.title2)
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text("10〜11月").bold()
                        Text("良型アジの季節。食いが渋くなり始める")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("🍂").font(.title2)
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text("12〜3月").bold()
                        Text("オフシーズン。水温低下で難しい")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("❄️").font(.title2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("フィールドガイド")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RulesView: View {
    var body: some View {
        List {
            Section("必ず守るべきルール") {
                RuleRow(icon: "trash.slash.fill", text: "ゴミは必ず持ち帰る（スポット閉鎖を防ぐため最重要）")
                RuleRow(icon: "person.2.fill", text: "他の釣り人との間隔を十分に空ける")
                RuleRow(icon: "dock.arrow.down.rectangle", text: "立入禁止区域・釣り禁止区域には入らない")
                RuleRow(icon: "fish.fill", text: "地域の漁業調整規則を確認する")
            }

            Section("マナー") {
                RuleRow(icon: "speaker.slash.fill", text: "夜間は騒がない（近隣住民への配慮）")
                RuleRow(icon: "flashlight.off.fill", text: "ライトで海面を照らしすぎない")
                RuleRow(icon: "car.fill", text: "駐車場以外への駐車禁止")
                RuleRow(icon: "checkmark.seal.fill", text: "スポットの設備（柵・トイレ等）を大切に使う")
            }

            Section("神奈川県の釣り規則") {
                Text("神奈川県では一部の魚種（マダコ等）に禁漁期間が設けられています。アジは基本的に通年釣ることができますが、漁業権の設定されている区域では内水面での釣りに許可が必要な場合があります。\n\nスポットの案内板を必ず確認しましょう。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("ルール・マナー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RuleRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct SafetyView: View {
    var body: some View {
        List {
            Section("必需品チェックリスト") {
                CheckRow(item: "ライフジャケット（義務化が進んでいます）")
                CheckRow(item: "ヘッドライト（両手が使える）")
                CheckRow(item: "スマートフォン（バッテリー充電済み）")
                CheckRow(item: "雨具・防寒着（季節により）")
                CheckRow(item: "救急セット")
                CheckRow(item: "フィッシュグリップ・フォーセップ")
            }

            Section("夜釣りの注意事項") {
                RuleRow(icon: "eye.slash.fill", text: "単独行動は避け、できるだけ複数人で")
                RuleRow(icon: "water.waves.and.arrow.up", text: "足元を常に確認。濡れた護岸は非常に滑りやすい")
                RuleRow(icon: "antenna.radiowaves.left.and.right", text: "天気予報・潮位変化を事前に確認する")
                RuleRow(icon: "phone.fill.arrow.up.right", text: "家族や知人に場所と帰宅時間を伝える")
                RuleRow(icon: "exclamationmark.triangle.fill", text: "突風・高波・雷の場合は即座に退避")
            }

            Section("緊急時の連絡先") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("海上での緊急事態")
                        .font(.subheadline.bold())
                    Text("海上保安庁: **118**")
                        .font(.subheadline)
                    Text("警察: **110**")
                        .font(.subheadline)
                    Text("消防・救急: **119**")
                        .font(.subheadline)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("夜釣りの安全対策")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CheckRow: View {
    let item: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.green)
                .frame(width: 24)
            Text(item)
                .font(.subheadline)
        }
    }
}
