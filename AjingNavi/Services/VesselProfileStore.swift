import Foundation
import Combine
import UIKit

@MainActor
class VesselProfileStore: ObservableObject {
    @Published var profiles: [VesselProfile] = []

    private let storageKey = "vessel_profiles_v1"
    private let photosDir: URL

    init() {
        photosDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("vessel_photos")
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        load()
    }

    func profile(for vesselName: String) -> VesselProfile? {
        profiles.first { $0.vesselName == vesselName }
    }

    func upsertFromFetch(_ vessels: [VesselInfo]) {
        let now = Date()
        for vessel in vessels {
            if let idx = profiles.firstIndex(where: { $0.vesselName == vessel.vesselName }) {
                profiles[idx].lastSeen = now
            } else {
                var p = VesselProfile(vesselName: vessel.vesselName)
                p.firstSeen = now
                p.lastSeen = now
                profiles.append(p)
            }
        }
        persist()
    }

    func save(_ profile: VesselProfile) {
        var updated = profile
        updated.lastUpdated = Date()
        if let idx = profiles.firstIndex(where: { $0.vesselName == profile.vesselName }) {
            profiles[idx] = updated
        } else {
            profiles.append(updated)
        }
        persist()
    }

    func savePhoto(_ image: UIImage, for vesselName: String) -> String {
        let filename = "\(abs(vesselName.hashValue))_\(UUID().uuidString).jpg"
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: photosDir.appendingPathComponent(filename))
        }
        return filename
    }

    func loadPhoto(filename: String) -> UIImage? {
        guard let data = try? Data(contentsOf: photosDir.appendingPathComponent(filename)) else { return nil }
        return UIImage(data: data)
    }

    func deletePhoto(filename: String) {
        try? FileManager.default.removeItem(at: photosDir.appendingPathComponent(filename))
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([VesselProfile].self, from: data) else { return }
        profiles = decoded
    }

    private func persist() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
