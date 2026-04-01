import SwiftUI

struct ContentView: View {
    @StateObject private var tideVM = TideViewModel()
    @StateObject private var weatherService = WeatherService()
    @StateObject private var catchStore = CatchRecordStore()

    var body: some View {
        TabView {
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

            InfoView()
                .tabItem {
                    Label("情報", systemImage: "info.circle.fill")
                }
        }
        .task {
            await weatherService.fetchWeather()
        }
    }
}
