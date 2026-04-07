import Foundation
import Combine
import SwiftUI

@MainActor
class TackleStore: ObservableObject {
    @Published var rods:     [Rod]          = []
    @Published var reels:    [Reel]         = []
    @Published var lines:    [FishingLine]  = []
    @Published var leaders:  [Leader]       = []
    @Published var jigHeads: [JigHead]      = []
    @Published var worms:    [Worm]         = []

    private enum Keys {
        static let rods      = "tackle_rods"
        static let reels     = "tackle_reels"
        static let lines     = "tackle_lines"
        static let leaders   = "tackle_leaders"
        static let jigHeads  = "tackle_jigheads"
        static let worms     = "tackle_worms"
    }

    init() { load() }

    // MARK: - Rod CRUD
    func add(_ rod: Rod)            { rods.append(rod);     save(rods, key: Keys.rods) }
    func update(_ rod: Rod)         { replace(&rods, rod);  save(rods, key: Keys.rods) }
    func delete(rod at: IndexSet)   { rods.remove(atOffsets: at); save(rods, key: Keys.rods) }

    // MARK: - Reel CRUD
    func add(_ reel: Reel)          { reels.append(reel);   save(reels, key: Keys.reels) }
    func update(_ reel: Reel)       { replace(&reels, reel); save(reels, key: Keys.reels) }
    func delete(reel at: IndexSet)  { reels.remove(atOffsets: at); save(reels, key: Keys.reels) }

    // MARK: - Line CRUD
    func add(_ line: FishingLine)   { lines.append(line);   save(lines, key: Keys.lines) }
    func update(_ line: FishingLine){ replace(&lines, line); save(lines, key: Keys.lines) }
    func delete(line at: IndexSet)  { lines.remove(atOffsets: at); save(lines, key: Keys.lines) }

    // MARK: - Leader CRUD
    func add(_ leader: Leader)      { leaders.append(leader);   save(leaders, key: Keys.leaders) }
    func update(_ leader: Leader)   { replace(&leaders, leader); save(leaders, key: Keys.leaders) }
    func delete(leader at: IndexSet){ leaders.remove(atOffsets: at); save(leaders, key: Keys.leaders) }

    // MARK: - JigHead CRUD
    func add(_ jh: JigHead)         { jigHeads.append(jh);  save(jigHeads, key: Keys.jigHeads) }
    func update(_ jh: JigHead)      { replace(&jigHeads, jh); save(jigHeads, key: Keys.jigHeads) }
    func delete(jigHead at: IndexSet){ jigHeads.remove(atOffsets: at); save(jigHeads, key: Keys.jigHeads) }

    // MARK: - Worm CRUD
    func add(_ worm: Worm)          { worms.append(worm);   save(worms, key: Keys.worms) }
    func update(_ worm: Worm)       { replace(&worms, worm); save(worms, key: Keys.worms) }
    func delete(worm at: IndexSet)  { worms.remove(atOffsets: at); save(worms, key: Keys.worms) }

    // MARK: - Lookup helpers
    func rod(for id: UUID?)      -> Rod?         { id.flatMap { i in rods.first      { $0.id == i } } }
    func reel(for id: UUID?)     -> Reel?        { id.flatMap { i in reels.first     { $0.id == i } } }
    func line(for id: UUID?)     -> FishingLine? { id.flatMap { i in lines.first     { $0.id == i } } }
    func leader(for id: UUID?)   -> Leader?      { id.flatMap { i in leaders.first   { $0.id == i } } }
    func jigHead(for id: UUID?)  -> JigHead?     { id.flatMap { i in jigHeads.first  { $0.id == i } } }
    func worm(for id: UUID?)     -> Worm?        { id.flatMap { i in worms.first     { $0.id == i } } }

    // MARK: - Private
    private func replace<T: Identifiable>(_ array: inout [T], _ item: T) where T.ID == UUID {
        if let idx = array.firstIndex(where: { $0.id == item.id }) {
            array[idx] = item
        }
    }

    private func save<T: Encodable>(_ items: T, key: String) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        rods      = decode([Rod].self,         key: Keys.rods)
        reels     = decode([Reel].self,        key: Keys.reels)
        lines     = decode([FishingLine].self, key: Keys.lines)
        leaders   = decode([Leader].self,      key: Keys.leaders)
        jigHeads  = decode([JigHead].self,     key: Keys.jigHeads)
        worms     = decode([Worm].self,        key: Keys.worms)
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T where T: ExpressibleByArrayLiteral {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(type, from: data)
        else { return [] }
        return decoded
    }
}
