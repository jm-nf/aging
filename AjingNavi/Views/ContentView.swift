import SwiftUI

struct ContentView: View {
    @StateObject private var catchStore = CatchRecordStore()
    @StateObject private var tackleStore = TackleStore()
    @StateObject private var shareSettings = ShareSettingsStore()
    @StateObject private var berthUnlockStore = BerthUnlockStore()
    @StateObject private var vesselProfileStore = VesselProfileStore()
    @StateObject private var spotStore = SpotSelectionStore()
    @EnvironmentObject private var berthService: BerthMonitorService

    var body: some View {
        TabView {
            SpotDashboardRoot()
                .environmentObject(spotStore)
                .environmentObject(berthUnlockStore)
                .environmentObject(berthService)
                .environmentObject(vesselProfileStore)
                .tabItem {
                    Label("スポット", systemImage: "mappin.and.ellipse")
                }

            CatchLogView()
                .environmentObject(catchStore)
                .environmentObject(tackleStore)
                .environmentObject(shareSettings)
                .environmentObject(berthUnlockStore)
                .environmentObject(berthService)
                .environmentObject(vesselProfileStore)
                .tabItem {
                    Label("釣果", systemImage: "fish.fill")
                }

            TackleView()
                .environmentObject(tackleStore)
                .tabItem {
                    Label("タックル", systemImage: "latch.2.case.fill")
                }

            SettingsView()
                .environmentObject(berthUnlockStore)
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
    }
}
