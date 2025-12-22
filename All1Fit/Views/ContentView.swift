import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        Group {
            if !authService.isReady {
                // Show nothing while Firebase initializes
                Color(red: 0.08, green: 0.08, blue: 0.12)
                    .ignoresSafeArea()
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            // Start Firebase listener AFTER UI is rendered
            authService.startListening()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
}
