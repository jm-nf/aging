import Foundation

// 調和分潮による潮汐予報
// 公式: h(t) = Z0 + Σ f_n * H_n * cos(σ_n * t + V0_n + u_n - κ_n)
// t   = 予報日のUTC零時からの経過時間（時間）
// V0  = UTC零時における平衡引数（天文引数から計算）
// u   = 節点補正角
// f   = 節点振幅補正
// κ   = JMA調和定数（エポック）

struct TideCalculator {

    // MARK: - 横浜験潮場 JMA 調和定数
    // 出典: 気象庁 潮汐観測資料
    private struct Constituent {
        let id: String
        let amplitude: Double  // H (m)
        let kappa: Double      // κ (度)
        let speed: Double      // σ (度/時)
    }

    private static let constituents: [Constituent] = [
        Constituent(id: "M2", amplitude: 0.6823, kappa: 134.7, speed: 28.9841042),
        Constituent(id: "S2", amplitude: 0.2528, kappa: 175.6, speed: 30.0000000),
        Constituent(id: "N2", amplitude: 0.1354, kappa: 122.5, speed: 28.4397295),
        Constituent(id: "K1", amplitude: 0.1586, kappa:  96.6, speed: 15.0410686),
        Constituent(id: "O1", amplitude: 0.1120, kappa:  71.6, speed: 13.9430356),
        Constituent(id: "K2", amplitude: 0.0706, kappa: 181.5, speed: 30.0821373),
        Constituent(id: "P1", amplitude: 0.0487, kappa:  97.6, speed: 14.9589314),
        Constituent(id: "Q1", amplitude: 0.0225, kappa:  55.8, speed: 13.3986609),
    ]

    private static let meanSeaLevel = 1.103  // Z0 (基本水準面からの平均海面高さ, m)

    // MARK: - 天文引数

    private static func norm(_ x: Double) -> Double {
        var v = x.truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        return v
    }

    // UTC零時における天文引数 (度)
    private static func astroArgs(midnightUTC: Date) -> (s: Double, h: Double, p: Double, N: Double) {
        // J2000.0 からの経過日数
        let jd = midnightUTC.timeIntervalSince1970 / 86400.0 + 2440587.5
        let dt = jd - 2451545.0
        return (
            s: norm(218.3165 + 13.17639648 * dt),  // 月の平均黄経
            h: norm(280.4665 +  0.98564736 * dt),  // 太陽の平均黄経
            p: norm( 83.3532 +  0.11140408 * dt),  // 月の近地点黄経
            N: norm(125.0445 -  0.05295377 * dt)   // 月の昇交点黄経
        )
    }

    // UTC零時における平衡引数 V0 (Schureman 1958 準拠, T=180° at midnight UTC)
    private static func v0(id: String, s: Double, h: Double, p: Double) -> Double {
        // T = 180° (UTC零時における太陽時角)
        switch id {
        case "M2": return norm(2 * h - 2 * s)            // 2T - 2s + 2h, 2T=0
        case "S2": return 0                               // 2T = 0
        case "N2": return norm(2 * h - 3 * s + p)        // 2T - 3s + p + 2h
        case "K1": return norm(270 + h)                   // T + h + 90, T=180
        case "O1": return norm(90 - 2 * s + h)           // T - 2s + h - 90, T=180
        case "K2": return norm(2 * h)                     // 2T + 2h, 2T=0
        case "P1": return norm(90 - h)                    // T - h + 270, T=180 → 90-h
        case "Q1": return norm(90 - 3 * s + p + h)       // T - 3s + p + h - 90, T=180
        default:   return 0
        }
    }

    // 節点振幅補正 f
    private static func nodalF(id: String, N: Double) -> Double {
        let Nr = N * .pi / 180
        switch id {
        case "M2", "N2": return 1.0 - 0.037 * cos(Nr)
        case "S2", "P1": return 1.0
        case "K1":       return 1.006 + 0.115 * cos(Nr)
        case "O1", "Q1": return 1.009 + 0.187 * cos(Nr)
        case "K2":       return 1.024 + 0.286 * cos(Nr)
        default:         return 1.0
        }
    }

    // 節点補正角 u (度)
    private static func nodalU(id: String, N: Double) -> Double {
        let Nr = N * .pi / 180
        switch id {
        case "M2", "N2": return -2.14 * sin(Nr)
        case "S2", "P1": return 0
        case "K1":       return -8.86 * sin(Nr)
        case "O1", "Q1": return 10.8  * sin(Nr)
        case "K2":       return -17.74 * sin(Nr)
        default:         return 0
        }
    }

    // MARK: - 潮位計算

    static func height(at date: Date, location: TideLocation) -> Double {
        let adjustedDate = date.addingTimeInterval(-location.timeOffsetMinutes * 60)

        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let midnightUTC = utcCal.startOfDay(for: adjustedDate)

        let t = adjustedDate.timeIntervalSince(midnightUTC) / 3600.0  // UTC零時からの時間数

        let (s, h, p, N) = astroArgs(midnightUTC: midnightUTC)

        var tideH = meanSeaLevel
        for c in constituents {
            let V0 = v0(id: c.id, s: s, h: h, p: p)
            let f  = nodalF(id: c.id, N: N)
            let u  = nodalU(id: c.id, N: N)
            let angle = c.speed * t + V0 + u - c.kappa
            tideH += f * c.amplitude * cos(angle * .pi / 180)
        }

        return tideH * location.heightMultiplier
    }

    // MARK: - 1日分の潮汐情報を計算

    static func calculate(for date: Date, location: TideLocation) -> TideInfo {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)

        // 10分刻みで144点（24時間）
        let intervalSec = 10.0 * 60.0
        let totalPoints = 144
        var points: [TidePoint] = []

        for i in 0...totalPoints {
            let t = startOfDay.addingTimeInterval(Double(i) * intervalSec)
            let h = height(at: t, location: location)
            points.append(TidePoint(time: t, height: h, type: nil))
        }

        // 極値（満潮・干潮）検出
        var extrema: [TidePoint] = []
        for i in 1..<(points.count - 1) {
            let prev = points[i - 1].height
            let curr = points[i].height
            let next = points[i + 1].height
            if curr > prev && curr > next {
                extrema.append(TidePoint(time: points[i].time, height: curr, type: .high))
            } else if curr < prev && curr < next {
                extrema.append(TidePoint(time: points[i].time, height: curr, type: .low))
            }
        }

        // グラフ用: 30分刻み
        var chartPoints: [TidePoint] = []
        for i in stride(from: 0, through: totalPoints, by: 3) {
            chartPoints.append(points[i])
        }

        let moonInfo = moonPhase(for: date)
        return TideInfo(
            date: date,
            location: location,
            points: chartPoints + extrema,
            moonPhase: moonInfo.phase,
            moonPhaseName: moonInfo.name,
            moonAge: moonInfo.age
        )
    }

    // MARK: - 月齢計算

    static func moonPhase(for date: Date) -> (phase: Double, name: String, age: Double) {
        // 既知の新月: 2000-01-06 18:14 UTC
        let knownNewMoon = Date(timeIntervalSince1970: 947182440)
        let synodicPeriod = 29.530588853

        let daysSince = date.timeIntervalSince(knownNewMoon) / 86400.0
        let cycles = daysSince / synodicPeriod
        let age = (cycles - floor(cycles)) * synodicPeriod
        let phase = age / synodicPeriod

        let name: String
        switch phase {
        case 0..<0.0625, 0.9375...1.0: name = "新月"
        case 0.0625..<0.1875:          name = "三日月"
        case 0.1875..<0.3125:          name = "上弦の月"
        case 0.3125..<0.4375:          name = "十三夜"
        case 0.4375..<0.5625:          name = "満月"
        case 0.5625..<0.6875:          name = "十六夜"
        case 0.6875..<0.8125:          name = "下弦の月"
        default:                        name = "有明の月"
        }
        return (phase: phase, name: name, age: age)
    }

    // MARK: - 釣りスコア

    static func fishingScore(for tideInfo: TideInfo, at hour: Int) -> (score: Int, reason: String) {
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: tideInfo.date)!
        let currentHeight = height(at: now, location: tideInfo.location)
        let hourBefore    = height(at: now.addingTimeInterval(-3600), location: tideInfo.location)
        let trend = currentHeight - hourBefore

        var score = 50
        var reasons: [String] = []

        let distFromSyzygy = min(tideInfo.moonPhase, abs(tideInfo.moonPhase - 0.5), 1.0 - tideInfo.moonPhase)
        if distFromSyzygy < 0.1 {
            score += 20; reasons.append("大潮時期")
        } else if distFromSyzygy < 0.2 {
            score += 10; reasons.append("中潮時期")
        }

        if abs(trend) > 0.3 {
            score += 15; reasons.append(trend > 0 ? "上げ潮" : "下げ潮")
        }

        if hour >= 18 || hour <= 6 { score += 15; reasons.append("夜間・マヅメ") }
        if [5, 6, 17, 18].contains(hour) { score += 10; reasons.append("マヅメ時") }

        return (score: min(score, 100), reason: reasons.joined(separator: "・"))
    }
}
