import SwiftUI

@main
struct All1FitWatchApp: App {
    @StateObject private var connectivityService = WatchConnectivityService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityService)
        }
    }
}
