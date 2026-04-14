import Foundation

// 気象庁 推算潮汐テキストの1日分データ
struct JMADayData {
    let year: Int
    let month: Int
    let day: Int
    let stationCode: String
    /// JST 0〜23時の毎時潮位（cm）
    let hourlyHeights: [Int]
    /// 満潮（最大4）
    let highTides: [(hour: Int, minute: Int, cm: Int)]
    /// 干潮（最大4）
    let lowTides: [(hour: Int, minute: Int, cm: Int)]
}

/// JMA推算潮汐テキストの取得・解析・年次キャッシュ
/// URL: https://www.data.jma.go.jp/kaiyou/data/db/tide/suisan/txt/{YEAR}/{STN}.txt
actor JMATideLoader {
    static let shared = JMATideLoader()

    private var memoryCache: [String: [String: JMADayData]] = [:]
    private let session: URLSession
    private let fm = FileManager.default

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 15
        cfg.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Public

    /// 指定局・年の全日データを取得（メモリ → ディスク → ネット）
    func load(stationCode: String, year: Int) async throws -> [String: JMADayData] {
        let memKey = "\(stationCode)_\(year)"
        if let mem = memoryCache[memKey] { return mem }

        let cacheURL = cacheFileURL(stationCode: stationCode, year: year)
        if fm.fileExists(atPath: cacheURL.path),
           let text = try? String(contentsOf: cacheURL, encoding: .utf8) {
            let parsed = parse(text: text, stationCode: stationCode)
            memoryCache[memKey] = parsed
            return parsed
        }

        let url = URL(string: "https://www.data.jma.go.jp/kaiyou/data/db/tide/suisan/txt/\(year)/\(stationCode).txt")!
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "JMATideLoader", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "JMA HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"])
        }
        guard let text = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8) else {
            throw NSError(domain: "JMATideLoader", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "decode failed"])
        }

        try? fm.createDirectory(at: cacheURL.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
        try? text.write(to: cacheURL, atomically: true, encoding: .utf8)

        let parsed = parse(text: text, stationCode: stationCode)
        memoryCache[memKey] = parsed
        return parsed
    }

    /// 指定局・日付の1日分データを返す
    func dayData(stationCode: String, date: Date) async throws -> JMADayData? {
        var jst = Calendar(identifier: .gregorian)
        jst.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let c = jst.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return nil }
        let yearMap = try await load(stationCode: stationCode, year: y)
        return yearMap[String(format: "%04d%02d%02d", y, m, d)]
    }

    func clearMemoryCache() { memoryCache.removeAll() }

    // MARK: - Private

    private func cacheFileURL(stationCode: String, year: Int) -> URL {
        fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JMATide/jma_\(stationCode)_\(year).txt")
    }

    // MARK: - Parser

    /// テキスト全体（365行）をパースして日付キー辞書に変換
    func parse(text: String, stationCode: String) -> [String: JMADayData] {
        var result: [String: JMADayData] = [:]
        for raw in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(raw)
            guard line.count >= 80 else { continue }
            guard let day = parseLine(line: line) else { continue }
            result[String(format: "%04d%02d%02d", day.year, day.month, day.day)] = day
        }
        return result
    }

    /// 1行（136桁固定長）を JMADayData に変換
    /// フォーマット:
    ///   Col  1-72: 毎時潮位 24値 × 3桁（cm、右詰め）
    ///   Col 73-74: 年（2桁）
    ///   Col 75-76: 月（2桁右詰め）
    ///   Col 77-78: 日（2桁）
    ///   Col 79-80: 局コード
    ///   Col 81-108: 満潮 4エントリ × 7桁 (HH2桁 + MM2桁 + cm3桁)
    ///   Col 109-136: 干潮 4エントリ × 7桁 (同上)
    ///   データなし: 時刻=9999, cm=999
    private func parseLine(line: String) -> JMADayData? {
        let chars = Array(line)

        // 毎時潮位 24値
        var heights: [Int] = []
        heights.reserveCapacity(24)
        for i in 0..<24 {
            guard let v = parseSpacedInt(substr(chars, i * 3, 3)) else { return nil }
            heights.append(v)
        }

        // 日付・局コード
        guard let yy = parseSpacedInt(substr(chars, 72, 2)),
              let mm = parseSpacedInt(substr(chars, 74, 2)),
              let dd = parseSpacedInt(substr(chars, 76, 2)) else { return nil }

        // 満潮・干潮
        var highs: [(Int, Int, Int)] = []
        var lows:  [(Int, Int, Int)] = []
        for i in 0..<4 {
            if let h = parseTideEntry(substr(chars, 80 + i * 7, 7)) { highs.append(h) }
            if let l = parseTideEntry(substr(chars, 108 + i * 7, 7)) { lows.append(l) }
        }

        let stn = substr(chars, 78, 2).trimmingCharacters(in: .whitespaces)

        return JMADayData(
            year: 2000 + yy,
            month: mm,
            day: dd,
            stationCode: stn,
            hourlyHeights: heights,
            highTides: highs.map { (hour: $0.0, minute: $0.1, cm: $0.2) },
            lowTides:  lows.map  { (hour: $0.0, minute: $0.1, cm: $0.2) }
        )
    }

    /// 7桁エントリ（HH2桁 + MM2桁 + cm3桁）を (h, m, cm) に変換
    /// データなし（9999/999）は nil を返す
    private func parseTideEntry(_ s: String) -> (Int, Int, Int)? {
        guard s.count == 7 else { return nil }
        let chars = Array(s)
        guard let hh = parseSpacedInt(String(chars[0..<2])),
              let mm = parseSpacedInt(String(chars[2..<4])),
              let cm = parseSpacedInt(String(chars[4..<7])) else { return nil }
        if hh == 99 && mm == 99 { return nil }
        if cm == 999 { return nil }
        guard (0...23).contains(hh), (0...59).contains(mm) else { return nil }
        return (hh, mm, cm)
    }

    /// 文字配列から部分文字列を安全に取り出す（範囲外はスペースで埋める）
    private func substr(_ chars: [Character], _ start: Int, _ len: Int) -> String {
        guard start < chars.count else { return String(repeating: " ", count: len) }
        let end = min(start + len, chars.count)
        var s = String(chars[start..<end])
        if s.count < len { s += String(repeating: " ", count: len - s.count) }
        return s
    }

    /// スペースパディング付き整数文字列を Int に変換
    private func parseSpacedInt(_ s: String) -> Int? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }
}
