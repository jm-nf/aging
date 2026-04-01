import SwiftUI

struct ContentView: View {
    @StateObject private var tideVM = TideViewModel()
    @StateObject private var weatherService = WeatherService()
    @StateObject private var catchStore = CatchRecordStore()
    @EnvironmentObject private var berthService: BerthMonitorService

    var body: some View {
        TabView {
            BerthMonitorView()
                .environmentObject(berthService)
                .tabItem {
                    Label("バース", systemImage: "anchor.circle.fill")
                }
                .badge(berthService.isFishingAffected ? "!" : nil)

            TideView()
                .environmentObject(tideVM)
                .tabItem {
                    Label("潮汐", systemImage: "water.waves")
                }

            WeatherView()
                .environmentObject(weatherService)
                .tabItem {
                    Label("天気", systemImage: "cloud.sun.fill")
                }

            SpotsView()
                .tabItem {
                    Label("釣り場", systemImage: "mappin.and.ellipse")
                }

            CatchLogView()
                .environmentObject(catchStore)
                .tabItem {
                    Label("釣果", systemImage: "fish.fill")
                }
        }
        .task {
            await weatherService.fetchWeather()
        }
    }
}
