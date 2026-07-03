# CLAUDE.md — AjingNavi Project Context

## このファイルについて
Claude Codeがこのプロジェクトを支援する際に参照するコンテキストファイル。

## プロジェクトの場所
- 本体: `~/code/AjingNavi`（2026-07-02 にGoogle Driveから移設。git管理、Driveの旧コピーは廃止済み）
- リモート: origin/main と同期して運用する

---

## 開発者プロフィール

- **氏名**：関 真平（Shimpei Seki）
- **プログラミングスキル**：ほぼゼロ。Claude Codeのサポートに全面依存して開発中
- **デバイス**：iPhone 17 Pro（実機テスト）、M5 MacBook Air（開発環境）
- **目標**：神奈川エリア向けアジング特化iOSアプリとして完成後、有料アプリ化・収益化。将来的に他地域版も展開予定

---

## アプリ概要

**アプリ名**：AjingNavi（Bundle ID: com.shimpei.AjingNavi）
**プラットフォーム**：iOS（Swift / Xcode / SwiftUI）
**対象ユーザー**：神奈川・横浜・相模湾エリアのアジングアングラー
**開発者自身もヘビーユーザー**：陸っぱりジグ単アジング歴あり、ホームはコスモ（鶴見川河口）

## 主要機能

1. **ポイント別潮汐情報**：Canvasベースの CustomTideChart、WorldTides API v3、潮回りバッジ
2. **天気予報**：WeatherKit + Open-Meteo(ECMWF)フォールバック
3. **釣り場ナビ**：18ポイント（横浜〜湘南）
4. **タックル登録**：ロッド/リール/ライン/リーダー/ジグヘッド/ワーム
5. **釣果記録 & SNS投稿**
6. **バースモニター**：横浜港MTK0Cバース（住友大阪セメント）の船舶ガントチャート。管理者ロック解除キーワード「勝二郎」

## ディレクトリ構成
- `AjingNavi/App/` エントリーポイント / `Models/` / `ViewModels/` / `Services/` / `Views/`

---

## ビルド・デプロイ（CLI優先）

- **チーム**: SHIMPEI SEKI / Team ID: `4FJ95FTQTH`
- **実機**: iPhone 17 Pro / CoreDevice UUID: `704BA385-FBFC-55E8-A403-C3D877C2D7EE`
- ビルド: `xcodebuild -project AjingNavi.xcodeproj -scheme AjingNavi -destination 'generic/platform=iOS' build`
- 実機インストール: `xcrun devicectl device install app --device <UUID> <path/to/AjingNavi.app>`
- アーカイブ/TestFlightアップロードは `exportOptions.plist` を使用
- **App Store Connect API**: Key ID `5K5BA37ZB6` / Issuer ID `69a6de7a-d6ab-47e3-e053-5b8c7c11a4d1` / AuthKey: `~/.appstoreconnect/private_keys/AuthKey_5K5BA37ZB6.p8`
- TestFlight: build 6 まで（2026-04-14）
- WeatherKit注意: Developer Portalの「App Services」タブでもチェック必須（Capabilitiesタブだけでは不十分）。実機必須・シミュレータ不可

---

## 現在の課題

### 優先度：高
1. **TideCalculator の精度不足**：天文潮位計算（横浜験潮場 JMA定数）の結果が実際と大きくズレる。κ（遅角）の定義の解釈疑惑あり。WorldTides等のAPI取得への一本化を検討中

### 優先度：中
2. **UI構造の再設計**：ポイントを選択したら潮汐・天気・船舶を一画面で見られる構造へ（タブごとのポイント選択重複を解消）

### 解決済み（再発時の参考）
- ガントチャート日付ズレ（2026-04-10修正: Color.clearアンカー + .position化、JST固定）
- WeatherKit動作不良（App Servicesタブのチェックで解決、実データ表示中）

---

## コーディング方針・お作法

- **コードは必ず動くものを提供する**。説明だけで終わらせない
- **変更箇所を明示する**：どのファイルのどの部分を変更するか必ず示す
- **一度に大きく変えすぎない**：1ステップずつ確認しながら進める
- ターミナルコマンドは**コピペすればそのまま動く形**で提供、Xcode操作は画面名・メニュー名を具体的に
- タイムゾーンは必ず明示：`TimeZone(identifier: "Asia/Tokyo")`（SwiftのDateはデフォルトUTC動作）
- DateFormatterは使い回す（生成コストが高い）

## 将来の拡張計画（設計時に意識する）

- 他地域展開前提：エリア・ポイントデータは外部化・差し替え可能な構造に
- 有料アプリ化：App Store審査を意識したコード品質・プライバシーポリシー対応
