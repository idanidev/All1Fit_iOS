import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if !authService.isReady {
                // ✅ Splash simple mientras el listener de auth se inicializa
                SplashView()
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authService.isReady)
        .animation(.easeInOut(duration: 0.25), value: authService.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
}
