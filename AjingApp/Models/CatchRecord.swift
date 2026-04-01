import Foundation
import Combine

struct CatchRecord: Identifiable, Codable {
    let id: UUID
    var date: Date
    var spotName: String
    var fishCount: Int
    var maxSize: Double // cm
    var weather: String
    var windDirection: String
    var tide: String
    var lure: String
    var memo: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        spotName: String = "",
        fishCount: Int = 0,
        maxSize: Double = 0,
        weather: String = "",
        windDirection: String = "",
        tide: String = "",
        lure: String = "",
        memo: String = ""
    ) {
        self.id = id
        self.date = date
        self.spotName = spotName
        self.fishCount = fishCount
        self.maxSize = maxSize
        self.weather = weather
        self.windDirection = windDirection
        self.tide = tide
        self.lure = lure
        self.memo = memo
    }
}

class CatchRecordStore: ObservableObject {
    @Published var records: [CatchRecord] = []

    private let saveKey = "catchRecords"

    init() {
        load()
    }

    func add(_ record: CatchRecord) {
        records.insert(record, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([CatchRecord].self, from: data) {
            records = decoded
        }
    }
}
