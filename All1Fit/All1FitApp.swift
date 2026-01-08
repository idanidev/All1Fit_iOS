import SwiftUI
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Configure Firestore offline persistence (100MB cache)
        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: 100 * 1024 * 1024 as NSNumber)
        Firestore.firestore().settings = settings
        
        #if DEBUG
        SimpleTestRunner.run()
        #endif
        
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
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appTheme.colorScheme)
        }
    }
}

// MARK: - Root View
struct RootView: View {
    @StateObject private var authService = AuthService()
    @StateObject private var phoneConnectivity = PhoneConnectivityService.shared
    @AppStorage("hasCompletedOnboarding") private var localOnboardingComplete = false
    
    /// Combined onboarding status: local OR Firebase
    private var hasCompletedOnboarding: Bool {
        localOnboardingComplete || authService.hasCompletedOnboarding
    }
    
    var body: some View {
        Group {
            if !authService.isReady {
                SplashView()
            } else if !hasCompletedOnboarding {
                OnboardingView(onComplete: {
                    Task {
                        await authService.completeOnboarding()
                        localOnboardingComplete = true
                    }
                })
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environmentObject(authService)
        .animation(.easeInOut(duration: 0.3), value: authService.isReady)
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
    }
}

// MARK: - Splash View
struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.6
    @State private var glowOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.04, green: 0.04, blue: 0.06)
                .ignoresSafeArea()
            
            // Animated glow rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.orange.opacity(0.4), .red.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 200 + CGFloat(i * 60), height: 200 + CGFloat(i * 60))
                    .scaleEffect(glowScale)
                    .opacity(glowOpacity * (0.6 - Double(i) * 0.15))
            }
            
            // Main glow effect behind logo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.orange.opacity(0.5), .red.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 350, height: 350)
                .scaleEffect(glowScale)
                .opacity(glowOpacity)
            
            // Logo with dramatic zoom
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 250)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
        }
        .onAppear {
            // Initial dramatic appear animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
                glowScale = 1.0
                glowOpacity = 0.8
            }
            
            // Start breathing pulse after initial animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    logoScale = 1.15
                    glowScale = 1.3
                    glowOpacity = 1.0
                }
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

// MARK: - Runtime Test Runner (Debug)
struct SimpleTestRunner {
    static func run() {
        print("\n🧪 ----- STARTING RUNTIME UNIT TESTS -----")
        
        testEjercicioIcons()
        testRMFormatting()
        
        print("✅ ----- ALL RUNTIME TESTS PASSED -----\n")
    }
    
    // Test 1: Verify dynamic icon logic
    static func testEjercicioIcons() {
        let clean = Ejercicio(name: "Clean", rmHistory: [])
        assert(clean.icon == "figure.strengthtraining.traditional", "❌ TEST FAILED: 'Clean' should have 'figure.strengthtraining.traditional' icon")
        
        let curl = Ejercicio(name: "Bicep Curl", rmHistory: [])
        assert(curl.icon == "dumbbell.fill", "❌ TEST FAILED: 'Bicep Curl' should have 'dumbbell.fill' icon")
        
        print("   ✅ Ejercicio Icons Logic: PASS")
    }
    
    // Test 2: Verify RM formatting or calculations if any
    static func testRMFormatting() {
        let history = [
            RMEntry(valor: 100.0, fecha: Date()),
            RMEntry(valor: 105.5, fecha: Date().addingTimeInterval(100)) // Latest
        ]
        let exercise = Ejercicio(name: "Test", rmHistory: history)
        
        assert(exercise.ultimoRM?.valor == 105.5, "❌ TEST FAILED: ultimoRM should be 105.5")
        
        print("   ✅ RM Calculation Logic: PASS")
    }
}
