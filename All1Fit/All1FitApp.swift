import SwiftUI
import FirebaseCore

// MARK: - App Delegate for Firebase - MUST be on main thread
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Firebase MUST be configured on main thread - do NOT move to background
        FirebaseApp.configure()
        return true
    }
}

// MARK: - Main App
@main
struct All1FitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
