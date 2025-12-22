import SwiftUI
import FirebaseCore

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    static var isFirebaseReady = false
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase on background thread - NO MAIN THREAD BLOCKING
        DispatchQueue.global(qos: .userInitiated).async {
            FirebaseApp.configure()
            DispatchQueue.main.async {
                AppDelegate.isFirebaseReady = true
                NotificationCenter.default.post(name: .firebaseReady, object: nil)
            }
        }
        return true
    }
}

// MARK: - Firebase Ready Notification
extension Notification.Name {
    static let firebaseReady = Notification.Name("firebaseReady")
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
