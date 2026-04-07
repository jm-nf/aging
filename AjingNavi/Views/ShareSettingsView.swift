import SwiftUI

struct ShareSettingsView: View {
    @EnvironmentObject var store: ShareSettingsStore
    @Environment(\.dismiss) private var dismiss

    // ローカルコピーで編集し、保存時に反映
    @State private var draft = ShareSettings()
    @State private var showPreview = false

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                contentItemsSection
                tackleSection
                hashtagSection
                footerSection
                previewSection
                resetSection
            }
            .navigationTitle("投稿テキスト設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.settings = draft
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { draft = store.settings }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack {
                Text("テキスト")
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)
                TextField("例: 🎣 アジング釣果", text: $draft.headerText)
            }
        } header: {
            Text("ヘッダー")
        } footer: {
            Text("投稿の先頭に表示されるタイトルです。")
        }
    }

    private var contentItemsSection: some View {
        Section {
            Toggle("釣り場", isOn: $draft.includeSpot)
            Toggle("日付", isOn: $draft.includeDate)
            Toggle("時刻・釣行時間", isOn: $draft.includeTime)
            Toggle("釣果数", isOn: $draft.includeFishCount)
            Toggle("最大サイズ", isOn: $draft.includeMaxSize)
            Toggle("天気", isOn: $draft.includeWeather)
            Toggle("潮回り", isOn: $draft.includeTide)
            Toggle("メモ", isOn: $draft.includeMemo)
        } header: {
            Text("表示する項目")
        }
    }

    private var tackleSection: some View {
        Section {
            Toggle("タックルを含める", isOn: $draft.includeTackle)

            if draft.includeTackle {
                Group {
                    Toggle("ロッド",           isOn: $draft.tackleRod)
                    Toggle("リール",           isOn: $draft.tackleReel)
                    Toggle("ライン",           isOn: $draft.tackleLine)
                    Toggle("ショックリーダー", isOn: $draft.tackleLeader)
                    Toggle("ジグヘッド",       isOn: $draft.tackleJigHead)
                    Toggle("ワーム",           isOn: $draft.tackleWorm)
                }
                .padding(.leading, 8)
                .foregroundStyle(Color.primary.opacity(0.85))
            }
        } header: {
            Text("タックル情報")
        }
    }

    private var hashtagSection: some View {
        Section {
            TextEditor(text: $draft.hashtags)
                .frame(minHeight: 100)
                .font(.body)
        } header: {
            Text("ハッシュタグ")
        } footer: {
            Text("1行に1タグを入力してください。空行は無視されます。")
        }
    }

    private var footerSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if draft.customFooter.isEmpty {
                    Text("投稿末尾に追加するテキスト（任意）")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $draft.customFooter)
                    .frame(minHeight: 60)
            }
        } header: {
            Text("カスタムフッター")
        } footer: {
            Text("ハッシュタグの後に追加されます。")
        }
    }

    private var previewSection: some View {
        Section {
            Button {
                showPreview.toggle()
            } label: {
                HStack {
                    Label("投稿テキストのプレビュー", systemImage: "eye")
                    Spacer()
                    Image(systemName: showPreview ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .foregroundStyle(.primary)

            if showPreview {
                Text(previewText(from: draft))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .textSelection(.enabled)
            }
        } header: {
            Text("プレビュー")
        } footer: {
            Text("実際の釣果データが入ると、上記の項目が置き換わります。")
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                draft = ShareSettings()
            } label: {
                Label("デフォルトに戻す", systemImage: "arrow.counterclockwise")
            }
        }
    }

    // MARK: - Preview generation

    private func previewText(from s: ShareSettings) -> String {
        var lines: [String] = []

        if !s.headerText.isEmpty {
            lines.append(s.headerText)
            lines.append("")
        }

        if s.includeSpot    { lines.append("📍 大黒埠頭（コスモ）") }
        if s.includeDate    {
            var dateLine = "📅 2026/4/1(水)"
            if s.includeTime { dateLine += "  20:00〜23:00（3時間）" }
            lines.append(dateLine)
        }

        var catchParts: [String] = []
        if s.includeFishCount { catchParts.append("15匹") }
        if s.includeMaxSize   { catchParts.append("最大22cm") }
        if !catchParts.isEmpty { lines.append("🐟 " + catchParts.joined(separator: "  ")) }

        var condParts: [String] = []
        if s.includeTide    { condParts.append("中潮") }
        if s.includeWeather { condParts.append("晴れ") }
        if !condParts.isEmpty { lines.append("🌊 " + condParts.joined(separator: " ｜ ")) }

        if s.includeTackle {
            var tackleLines: [String] = []
            if s.tackleRod      { tackleLines.append("ロッド: ダイワ 月下美人 AIR AGS 74L-S") }
            if s.tackleReel     { tackleLines.append("リール: シマノ ソアレ BB 500S") }
            if s.tackleLine     { tackleLines.append("ライン: サンライン エステル 0.3号") }
            if s.tackleLeader   { tackleLines.append("リーダー: クレハ シーガー 0.8号") }
            if s.tackleJigHead  { tackleLines.append("ジグヘッド: 尺ヘッドR 0.5g #6") }
            if s.tackleWorm     { tackleLines.append("ワーム: バークレイ アジリンガー グロー") }
            if !tackleLines.isEmpty {
                lines.append("")
                lines.append("🎣 タックル")
                lines.append(contentsOf: tackleLines)
            }
        }

        if s.includeMemo {
            lines.append("")
            lines.append("（メモの内容がここに入ります）")
        }

        let tag = s.hashtagLine
        if !tag.isEmpty {
            lines.append("")
            lines.append(tag)
        }

        if !s.customFooter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
            lines.append(s.customFooter)
        }

        return lines.joined(separator: "\n")
    }
}
