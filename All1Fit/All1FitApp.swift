import SwiftUI
import FirebaseCore
import GoogleSignIn

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    var body: some Scene {
        WindowGroup {
            RootView(hasCompletedOnboarding: $hasCompletedOnboarding)
                .preferredColorScheme(appTheme.colorScheme)
        }
    }
}

// MARK: - Root View
struct RootView: View {
    @StateObject private var authService = AuthService()
    @Binding var hasCompletedOnboarding: Bool
    
    var body: some View {
        Group {
            if !authService.isReady {
                SplashView()
            } else if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environmentObject(authService)
        .animation(.smooth(duration: 0.4), value: authService.isReady)
        .animation(.smooth(duration: 0.4), value: authService.isAuthenticated)
        .animation(.smooth(duration: 0.4), value: hasCompletedOnboarding)
    }
}

// MARK: - App Theme
enum AppTheme: String, CaseIterable {
    case system, light, dark
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var displayName: String {
        switch self {
        case .system: return "Automático"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }
}

// MARK: - Splash View (iOS 26 Liquid Glass)
struct SplashView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // ✅ iOS 26: Mesh gradient background
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    .black, Color(hex: "1a1a2e"), .black,
                    Color(hex: "16213e"), Color(hex: "0f3460"), Color(hex: "1a1a2e"),
                    .black, Color(hex: "1a1a2e"), .black
                ]
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                // ✅ iOS 26: Glass effect en el loader
                ProgressView()
                    .controlSize(.large)
                    .tint(.orange)
                    .padding(20)
                    .glassEffect(.regular.tint(.orange.opacity(0.3)), in: .circle)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.4)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    SplashView()
}