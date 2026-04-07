import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore
    @State private var keywordInput = ""
    @State private var showUnlockField = false
    @State private var unlockFailed = false
    @State private var showLockConfirm = false

    @State private var adminKeywordInput = ""
    @State private var showAdminUnlockField = false
    @State private var adminUnlockFailed = false
    @State private var showAdminLockConfirm = false

    var body: some View {
        NavigationStack {
            List {
                appSection
                featureSection
                adminSection
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
            LabeledContent("対象エリア", value: "横浜・横須賀・湘南")
        }
    }

    // MARK: - 特別機能

    private var featureSection: some View {
        Section {
            if berthUnlockStore.isUnlocked {
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

            } else {
                Button {
                    showUnlockField.toggle()
                    unlockFailed = false
                    keywordInput = ""
                } label: {
                    Label("特別機能を解除する", systemImage: "lock.fill")
                }

                if showUnlockField {
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

                        Button("確認") { attemptUnlock() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("特別機能")
        } footer: {
            if !berthUnlockStore.isUnlocked {
                Text("キーワードを知っている方のみ利用できる機能です。")
            }
        }
    }

    // MARK: - 管理者

    private var adminSection: some View {
        Section {
            if berthUnlockStore.isAdminUnlocked {
                HStack {
                    Label("管理者モード", systemImage: "wrench.and.screwdriver.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("有効").font(.caption).foregroundStyle(.orange)
                }

                Button(role: .destructive) {
                    showAdminLockConfirm = true
                } label: {
                    Label("管理者モードを終了", systemImage: "lock.fill")
                }
                .confirmationDialog("管理者モードを終了しますか？", isPresented: $showAdminLockConfirm, titleVisibility: .visible) {
                    Button("終了する", role: .destructive) { berthUnlockStore.adminLock() }
                    Button("キャンセル", role: .cancel) {}
                }

            } else {
                Button {
                    showAdminUnlockField.toggle()
                    adminUnlockFailed = false
                    adminKeywordInput = ""
                } label: {
                    Label("管理者モードに入る", systemImage: "wrench.and.screwdriver")
                }

                if showAdminUnlockField {
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("管理者キーワード", text: $adminKeywordInput)
                            .textContentType(.none)
                            .autocorrectionDisabled()
                            .onSubmit { attemptAdminUnlock() }

                        if adminUnlockFailed {
                            Text("キーワードが違います")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button("確認") { attemptAdminUnlock() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("管理者")
        } footer: {
            if !berthUnlockStore.isAdminUnlocked {
                Text("メンテナンス用の管理者機能です。")
            }
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

    private func attemptAdminUnlock() {
        if berthUnlockStore.tryAdminUnlock(keyword: adminKeywordInput) {
            showAdminUnlockField = false
            adminKeywordInput = ""
        } else {
            adminUnlockFailed = true
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
}
