import SwiftUI
import FirebaseCore
import GoogleSignIn

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // ✅ Firebase se configura aquí, antes de que la UI cargue
        FirebaseApp.configure()
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - Main App
@main
struct All1FitApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // ✅ CLAVE: No crear AuthService aquí, crearlo lazy en ContentView
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - Root View (Lazy initialization of AuthService)
struct RootView: View {
    // ✅ AuthService se crea cuando la vista aparece, no al inicio de la app
    @StateObject private var authService = AuthService()
    
    var body: some View {
        ContentView()
            .environmentObject(authService)
    }
}
