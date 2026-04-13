import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore
    @State private var keywordInput = ""
    @State private var showUnlockField = false
    @State private var unlockFailed = false
    @State private var showLockConfirm = false

    var body: some View {
        NavigationStack {
            List {
                appSection
                if berthUnlockStore.isUnlocked {
                    featureSection
                }
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - アプリ情報

    private var appSection: some View {
        Section("アプリ情報") {
            LabeledContent("バージョン", value: appVersion)
                .onTapGesture(count: 5) {
                    guard !berthUnlockStore.isUnlocked else { return }
                    showUnlockField = true
                }
            LabeledContent("対象エリア", value: "横浜・横須賀・湘南")

            if showUnlockField && !berthUnlockStore.isUnlocked {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("キーワードを入力", text: $keywordInput)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .onSubmit { attemptUnlock() }

                    if unlockFailed {
                        Text("キーワードが違います")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Button("確認") { attemptUnlock() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        Button("キャンセル") {
                            showUnlockField = false
                            unlockFailed = false
                            keywordInput = ""
                        }
                        .controlSize(.small)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 特別機能（解除済みのみ表示）

    private var featureSection: some View {
        Section {
            HStack {
                Label("特別機能", systemImage: "lock.open.fill")
                    .foregroundStyle(.green)
                Spacer()
                Text("有効").font(.caption).foregroundStyle(.green)
            }

            Button(role: .destructive) {
                showLockConfirm = true
            } label: {
                Label("特別機能を無効にする", systemImage: "lock.fill")
            }
            .confirmationDialog("特別機能を無効にしますか？", isPresented: $showLockConfirm, titleVisibility: .visible) {
                Button("無効にする", role: .destructive) { berthUnlockStore.lock() }
                Button("キャンセル", role: .cancel) {}
            }
        } header: {
            Text("特別機能")
        }
    }

    // MARK: - このアプリについて

    private var aboutSection: some View {
        Section("このアプリについて") {
            Text("AjingNaviは神奈川エリアのアジング専用ナビアプリです。潮汐・天気・釣り場情報をまとめて確認できます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func attemptUnlock() {
        if berthUnlockStore.tryUnlock(keyword: keywordInput) {
            showUnlockField = false
            keywordInput = ""
        } else {
            unlockFailed = true
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
}
