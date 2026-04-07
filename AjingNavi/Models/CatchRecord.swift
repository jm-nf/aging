import Foundation
import Combine
import SwiftUI
import UIKit

struct CatchRecord: Identifiable, Codable {
    let id: UUID
    var date: Date
    var startTime: Date?        // 釣行開始時刻
    var endTime: Date?          // 釣行終了時刻
    var spotName: String
    var fishCount: Int
    var maxSize: Double         // cm
    var weather: String
    var windDirection: String
    var tide: String
    var lure: String
    var memo: String
    var tackleSet: TackleSet?
    var photoFilenames: [String] // Documents ディレクトリ内の JPEG ファイル名
    var dockedVessels: [String]  // 釣行時にバースに停泊していた船舶名

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        startTime: Date? = nil,
        endTime: Date? = nil,
        spotName: String = "",
        fishCount: Int = 0,
        maxSize: Double = 0,
        weather: String = "",
        windDirection: String = "",
        tide: String = "",
        lure: String = "",
        memo: String = "",
        tackleSet: TackleSet? = nil,
        photoFilenames: [String] = [],
        dockedVessels: [String] = []
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.spotName = spotName
        self.fishCount = fishCount
        self.maxSize = maxSize
        self.weather = weather
        self.windDirection = windDirection
        self.tide = tide
        self.lure = lure
        self.memo = memo
        self.tackleSet = tackleSet
        self.photoFilenames = photoFilenames
        self.dockedVessels = dockedVessels
    }

    // MARK: - Computed

    var durationLabel: String? {
        guard let s = startTime, let e = endTime, e > s else { return nil }
        let mins = Int(e.timeIntervalSince(s) / 60)
        let h = mins / 60, m = mins % 60
        if h == 0 { return "\(m)分" }
        return m == 0 ? "\(h)時間" : "\(h)時間\(m)分"
    }

    var timeRangeLabel: String? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "HH:mm"
        guard let s = startTime else { return nil }
        let start = fmt.string(from: s)
        if let e = endTime {
            return "\(start)〜\(fmt.string(from: e))"
        }
        return "\(start)〜"
    }
}

// MARK: - Store

class CatchRecordStore: ObservableObject {
    @Published var records: [CatchRecord] = []

    private let saveKey = "catchRecords"
    private var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init() { load() }

    func add(_ record: CatchRecord) {
        records.insert(record, at: 0)
        save()
    }

    func update(_ record: CatchRecord) {
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx] = record
            save()
        }
    }

    func delete(at offsets: IndexSet) {
        for idx in offsets {
            deletePhotos(filenames: records[idx].photoFilenames)
        }
        records.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Photo management

    /// UIImage を Documents に JPEG 保存し、ファイル名を返す
    func savePhoto(_ image: UIImage, for recordId: UUID) -> String {
        let filename = "\(recordId.uuidString)_\(UUID().uuidString).jpg"
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: docsDir.appendingPathComponent(filename))
        }
        return filename
    }

    func loadPhoto(filename: String) -> UIImage? {
        let url = docsDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadPhotos(for record: CatchRecord) -> [UIImage] {
        record.photoFilenames.compactMap { loadPhoto(filename: $0) }
    }

    func deletePhotos(filenames: [String]) {
        for name in filenames {
            try? FileManager.default.removeItem(at: docsDir.appendingPathComponent(name))
        }
    }

    // MARK: - Persistence

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
