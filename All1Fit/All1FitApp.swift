import SwiftUI
import FirebaseCore

@main
struct All1FitApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
