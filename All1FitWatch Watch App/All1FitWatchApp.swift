import SwiftUI
import WatchKit

@main
struct All1FitWatchApp: App {
    // Handle background tasks
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - App Delegate for Background Tasks
class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        // Schedule initial background refresh
        BackgroundRefreshManager.shared.scheduleBackgroundRefresh()
        
        // Request notification permission
        Task {
            _ = await WorkoutNotificationService.shared.requestAuthorization()
        }
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        BackgroundRefreshManager.shared.handleBackgroundTasks(backgroundTasks)
    }
}

// MARK: - Root View
struct RootView: View {
    @StateObject private var connectivity = WatchConnectivityService.shared
    @StateObject private var healthKit = HealthKitService.shared

    var body: some View {
        ContentView()
            .environmentObject(connectivity)
            .environmentObject(healthKit)
            .task {
                // Todo en background, NO bloqueante
                await initializeApp()
            }
    }

    private func initializeApp() async {
        // Solo inicializar HealthKit
        // WCSession se activa automáticamente y sincroniza cuando está lista
        _ = await healthKit.requestAuthorization()
    }
}

// SplashView eliminado - ContentView maneja su propio estado de carga
