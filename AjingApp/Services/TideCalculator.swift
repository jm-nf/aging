import Foundation

// Simplified harmonic tidal prediction for Yokohama
// Based on principal tidal constituents (M2, S2, N2, K1, O1)
struct TideCalculator {

    // Yokohama harmonic constants (approximate)
    // Format: (amplitude in meters, epoch/phase offset in degrees)
    private static let constituentM2 = (amplitude: 0.680, phase: 148.0) // Principal lunar semidiurnal
    private static let constituentS2 = (amplitude: 0.252, phase: 176.0) // Principal solar semidiurnal
    private static let constituentN2 = (amplitude: 0.135, phase: 124.0) // Larger lunar elliptic semidiurnal
    private static let constituentK1 = (amplitude: 0.158, phase:  97.0) // Luni-solar diurnal
    private static let constituentO1 = (amplitude: 0.112, phase:  72.0) // Lunar diurnal
    private static let constituentK2 = (amplitude: 0.070, phase: 180.0) // Luni-solar semidiurnal
    private static let meanSeaLevel = 1.10 // meters above chart datum

    // Angular speeds (degrees/hour)
    private static let speedM2 = 28.9841042
    private static let speedS2 = 30.0000000
    private static let speedN2 = 28.4397295
    private static let speedK1 = 15.0410686
    private static let speedO1 = 13.9430356
    private static let speedK2 = 30.0821373

    // Reference epoch: J2000.0 (2000-01-01 12:00 UTC)
    private static let j2000 = Date(timeIntervalSince1970: 946728000)

    static func height(at date: Date, location: TideLocation) -> Double {
        let hoursSinceJ2000 = date.timeIntervalSince(j2000) / 3600.0

        func component(_ speed: Double, _ constituent: (amplitude: Double, phase: Double)) -> Double {
            let angle = speed * hoursSinceJ2000 - constituent.phase
            return constituent.amplitude * cos(angle * .pi / 180.0)
        }

        let height = meanSeaLevel
            + component(speedM2, constituentM2)
            + component(speedS2, constituentS2)
            + component(speedN2, constituentN2)
            + component(speedK1, constituentK1)
            + component(speedO1, constituentO1)
            + component(speedK2, constituentK2)

        return height * location.heightMultiplier
    }

    static func calculate(for date: Date, location: TideLocation) -> TideInfo {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Sample tide height every 10 minutes for 24 hours
        let intervalSeconds = 10.0 * 60.0 // 10 minutes
        let totalPoints = 144 // 24 hours
        var hourlyPoints: [TidePoint] = []

        for i in 0...totalPoints {
            let t = startOfDay.addingTimeInterval(Double(i) * intervalSeconds)
            let h = height(at: t, location: location)
            hourlyPoints.append(TidePoint(time: t, height: h, type: nil))
        }

        // Find extrema (high/low tides)
        var tidalExtrema: [TidePoint] = []
        for i in 1..<(hourlyPoints.count - 1) {
            let prev = hourlyPoints[i - 1].height
            let curr = hourlyPoints[i].height
            let next = hourlyPoints[i + 1].height

            if curr > prev && curr > next {
                tidalExtrema.append(TidePoint(time: hourlyPoints[i].time, height: curr, type: .high))
            } else if curr < prev && curr < next {
                tidalExtrema.append(TidePoint(time: hourlyPoints[i].time, height: curr, type: .low))
            }
        }

        // Create evenly sampled points for chart (every 30 minutes)
        var chartPoints: [TidePoint] = []
        for i in stride(from: 0, through: totalPoints, by: 3) {
            chartPoints.append(TidePoint(time: hourlyPoints[i].time, height: hourlyPoints[i].height, type: nil))
        }

        let allPoints = chartPoints + tidalExtrema

        let moonInfo = moonPhase(for: date)

        return TideInfo(
            date: date,
            location: location,
            points: allPoints,
            moonPhase: moonInfo.phase,
            moonPhaseName: moonInfo.name,
            moonAge: moonInfo.age
        )
    }

    // Moon phase calculation (simplified)
    static func moonPhase(for date: Date) -> (phase: Double, name: String, age: Double) {
        // Known new moon reference: 2000-01-06 18:14 UTC
        let knownNewMoon = Date(timeIntervalSince1970: 947182440)
        let synodicPeriod = 29.530588853 // days

        let daysSince = date.timeIntervalSince(knownNewMoon) / 86400.0
        let cycles = daysSince / synodicPeriod
        let age = (cycles - floor(cycles)) * synodicPeriod
        let phase = age / synodicPeriod

        let name: String
        switch phase {
        case 0..<0.0625, 0.9375...1.0:
            name = "新月"
        case 0.0625..<0.1875:
            name = "三日月"
        case 0.1875..<0.3125:
            name = "上弦の月"
        case 0.3125..<0.4375:
            name = "十三夜"
        case 0.4375..<0.5625:
            name = "満月"
        case 0.5625..<0.6875:
            name = "十六夜"
        case 0.6875..<0.8125:
            name = "下弦の月"
        default:
            name = "有明の月"
        }

        return (phase: phase, name: name, age: age)
    }

    // Evaluate fishing quality based on tide conditions
    static func fishingScore(for tideInfo: TideInfo, at hour: Int) -> (score: Int, reason: String) {
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: tideInfo.date)!
        let currentHeight = height(at: now, location: tideInfo.location)
        let hourBefore = height(at: now.addingTimeInterval(-3600), location: tideInfo.location)
        let trend = currentHeight - hourBefore

        var score = 50
        var reasons: [String] = []

        // Moon phase (new moon and full moon are best)
        let moonScore = abs(tideInfo.moonPhase - 0.5) // 0 = full moon, 0.5 = new moon... let me recalculate
        // phase 0 = new moon, 0.5 = full moon
        let distFromSyzygy = min(tideInfo.moonPhase, 1.0 - tideInfo.moonPhase) // 0 = syzygy (new/full)
        if distFromSyzygy < 0.1 {
            score += 20
            reasons.append("大潮時期")
        } else if distFromSyzygy < 0.2 {
            score += 10
            reasons.append("中潮時期")
        }

        // Tide change (fish are active when tide is changing)
        if abs(trend) > 0.3 {
            score += 15
            reasons.append(trend > 0 ? "上げ潮" : "下げ潮")
        }

        // Time of day
        if hour >= 18 || hour <= 6 {
            score += 15
            reasons.append("夜間・マヅメ")
        }
        if hour == 5 || hour == 6 || hour == 17 || hour == 18 {
            score += 10
            reasons.append("マヅメ時")
        }

        score = min(score, 100)
        return (score: score, reason: reasons.joined(separator: "・"))
    }
}
