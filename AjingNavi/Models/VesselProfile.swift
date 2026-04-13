import Foundation

struct VesselProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var vesselName: String
    var photoFilenames: [String] = []
    var brightness: String = ""
    var shadowPosition: String = ""
    var notes: String = ""
    var lastUpdated: Date = Date()
    var firstSeen: Date? = nil
    var lastSeen: Date? = nil
}
