# アジングNavi - 横浜・横須賀アジング情報アプリ

横浜・横須賀エリアでのアジング（アジのルアー釣り）に必要な情報を一覧できるiOSアプリです。

## 機能一覧

### 🌊 潮汐情報
- 横浜・横須賀・久里浜・三崎の潮位グラフ（24時間）
- 満潮・干潮の時刻と潮位
- 月齢・月相表示（大潮/中潮/小潮判定）
- 時合いスコア（現在の釣り好適度を0〜100で表示）
- 日付選択で過去・未来の潮汐を確認

### ☀️ 天気情報
- 現在の気象データ（気温・風速・風向・湿度・視程）
- 5日間天気予報
- 釣り条件評価（風・視程・気圧）
- OpenWeatherMap API対応

### 📍 釣り場情報
- 10か所の釣り場データ（横浜・横須賀エリア）
- リスト表示・マップ表示の切り替え
- 難易度・設備フィルター
- 各スポットの詳細情報（特徴・シーズン・時合い・アクセス）
- Apple Mapsへの連携

### 🐟 釣果記録
- 釣行記録の登録（釣り場・日時・釣果・サイズ・天気・使用ルアー等）
- 統計表示（総釣行数・総釣果・最大サイズ）
- UserDefaultsによるローカル保存

### ℹ️ アジング情報
- タックル・ルアーガイド（ロッド・リール・ライン・ジグヘッド・ワーム）
- 釣り方・テクニック解説（表層ただ巻き・カーブフォール・リフト&フォール等）
- 横浜・横須賀フィールドガイド（エリア特性・シーズンカレンダー）
- 釣り場マナー・ルール
- 夜釣りの安全対策

## Xcodeプロジェクトの作成手順

1. **Xcodeを開く** → `File > New > Project`
2. **iOS** > **App** を選択
3. プロジェクト設定:
   - Product Name: `AjingNavi`
   - Bundle Identifier: `com.yourname.ajingnavi`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Minimum Deployments: **iOS 16.0**
4. 作成後、以下のファイルをすべてプロジェクトに追加:
   - `AjingApp/` フォルダ内のすべての `.swift` ファイル
   - `AjingApp/Info.plist` の内容を既存の Info.plist にマージ

## 天気API設定

[OpenWeatherMap](https://openweathermap.org/api) で無料APIキーを取得し、
`AjingApp/Services/WeatherService.swift` の以下の行を編集してください:

```swift
private let apiKey = "YOUR_OPENWEATHERMAP_API_KEY"
// ↓
private let apiKey = "取得したAPIキー"
```

APIキーなしの場合はサンプルデータが表示されます。

## 使用ライブラリ

- **SwiftUI** - UIフレームワーク
- **Charts** - 潮位グラフ（iOS 16+）
- **MapKit** - 釣り場マップ
- **CoreLocation** - 位置情報
- **Foundation** - データ管理・API通信

## 対応環境

- iOS 16.0以上推奨（Charts使用のため）
- iOS 15.0でも動作（グラフは簡易表示）
- iPhone専用（縦向き固定）

## 潮汐計算について

横浜の調和定数（M2・S2・N2・K1・O1・K2成分）を使用した近似計算です。
正確な潮汐予測には気象庁等の公式データをご参照ください。

## ディレクトリ構成

```
AjingApp/
├── App/
│   └── AjingApp.swift          # アプリエントリーポイント
├── Views/
│   ├── ContentView.swift       # タブバーナビゲーション
│   ├── TideView.swift          # 潮汐情報画面
│   ├── WeatherView.swift       # 天気情報画面
│   ├── SpotsView.swift         # 釣り場情報画面
│   ├── CatchLogView.swift      # 釣果記録画面
│   └── InfoView.swift          # アジング情報画面
├── ViewModels/
│   └── TideViewModel.swift     # 潮汐ViewModel
├── Models/
│   ├── TideData.swift          # 潮汐データモデル
│   ├── FishingSpot.swift       # 釣り場データ
│   └── CatchRecord.swift       # 釣果記録モデル
├── Services/
│   ├── TideCalculator.swift    # 潮汐計算エンジン
│   └── WeatherService.swift    # 天気APIサービス
└── Info.plist
```
