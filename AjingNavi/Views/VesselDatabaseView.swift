import SwiftUI

struct VesselDatabaseView: View {
    @EnvironmentObject var profileStore: VesselProfileStore
    @EnvironmentObject var berthService: BerthMonitorService
    @EnvironmentObject var berthUnlockStore: BerthUnlockStore

    @State private var searchText = ""

    private var sortedProfiles: [VesselProfile] {
        profileStore.profiles
            .filter {
                searchText.isEmpty || $0.vesselName.contains(searchText)
            }
            .sorted { ($0.lastSeen ?? .distantPast) > ($1.lastSeen ?? .distantPast) }
    }

    var body: some View {
        List {
            if sortedProfiles.isEmpty {
                Text("船舶データなし")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(sortedProfiles) { profile in
                    let vessel = berthService.vessels.first { $0.vesselName == profile.vesselName }
                    NavigationLink {
                        VesselProfileView(vesselName: profile.vesselName, vessel: vessel)
                            .environmentObject(profileStore)
                            .environmentObject(berthUnlockStore)
                    } label: {
                        VesselDatabaseRow(profile: profile, vessel: vessel)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("船舶データベース")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "船名で検索")
    }
}

struct VesselDatabaseRow: View {
    let profile: VesselProfile
    let vessel: VesselInfo?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "ferry.fill")
                .font(.title3)
                .foregroundStyle(.blue.opacity(0.7))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.vesselName)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let first = profile.firstSeen {
                        Label(first.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar.badge.plus")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let last = profile.lastSeen {
                        Label(last.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let vessel {
                    if vessel.isCurrentlyDocked {
                        Label("停泊中", systemImage: "anchor")
                            .font(.caption2.bold())
                            .foregroundStyle(.red)
                    } else if vessel.isUpcoming {
                        Label("入港予定", systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if !profile.photoFilenames.isEmpty {
                    Label("\(profile.photoFilenames.count)", systemImage: "photo.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                if !profile.notes.isEmpty || !profile.brightness.isEmpty {
                    Image(systemName: "note.text")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
