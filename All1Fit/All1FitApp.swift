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

// MARK: - Notifications
extension Notification.Name {
    static let openActiveTabata = Notification.Name("openActiveTabata")
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
    @ObservedObject private var phoneConnectivity = PhoneConnectivityService.shared
    @AppStorage("hasCompletedOnboarding") private var localOnboardingComplete = false

    /// Combined onboarding status: local OR Firebase
    private var hasCompletedOnboarding: Bool {
        localOnboardingComplete || authService.hasCompletedOnboarding
    }

    var body: some View {
        Group {
            if !authService.isReady {
                SplashView()
            } else if authService.isAuthenticated {
                // Usuario autenticado → ir directo a la app
                MainTabView()
            } else if !hasCompletedOnboarding {
                // Usuario NO autenticado y NO completó onboarding → mostrar onboarding
                PremiumOnboardingView(onComplete: {
                    Task {
                        await authService.completeOnboarding()
                        localOnboardingComplete = true
                    }
                })
            } else {
                // Usuario NO autenticado pero YA completó onboarding → login
                LoginView()
            }
        }
        .environmentObject(authService)
        .environmentObject(phoneConnectivity)
        .onOpenURL { url in
            if url.scheme == "all1fit" && url.host == "tabata" {
                NotificationCenter.default.post(name: .openActiveTabata, object: nil)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isReady)
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth {
                // Sincronizar con Watch cuando el usuario se autentique
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s delay
                    await phoneConnectivity.forceSyncAllData()
                }
            }
        }
    }
}

// MARK: - Splash View
struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.6
    @State private var glowOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.04, green: 0.04, blue: 0.06)
                .ignoresSafeArea()

            // Glow effects (static if reduce motion enabled)
            if !reduceMotion {
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
            }

            // Logo
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 250)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .accessibilityLabel("All1Fit")
                .accessibilityAddTraits(.isImage)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cargando All1Fit")
        .onAppear {
            if reduceMotion {
                // Sin animación si reduce motion está activado
                logoScale = 1.0
                logoOpacity = 1.0
                glowScale = 1.0
                glowOpacity = 0.8
            } else {
                // Animación única (no infinita) para reducir consumo
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    logoScale = 1.0
                    logoOpacity = 1.0
                    glowScale = 1.0
                    glowOpacity = 0.8
                }
            }
        }
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
