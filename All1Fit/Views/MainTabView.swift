import SwiftUI

// MARK: - Main Tab View (iOS 26 Liquid Glass TabBar)
struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RMListView()
                .tabItem {
                    Label("RMs", systemImage: "dumbbell.fill")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .tint(.orange)
    }
}

// MARK: - Settings View (iOS 26)
struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // User Section
                userSection
                
                // Preferences
                preferencesSection
                
                // App Info
                appInfoSection
                
                // Support
                supportSection
                
                // Logout
                logoutSection
            }
            .navigationTitle("Ajustes")
            .listStyle(.insetGrouped)
        }
    }
    
    // MARK: - User Section
    private var userSection: some View {
        Section {
            if let user = authService.user {
                HStack(spacing: 16) {
                    // Avatar with glass effect
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Text(user.displayName?.prefix(1).uppercased() ?? "U")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName ?? "Usuario")
                            .font(.headline)
                        
                        Text(user.email ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Preferences Section
    private var preferencesSection: some View {
        Section("Preferencias") {
            // Theme picker
            Picker("Tema", selection: $appTheme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.menu)
            
            // Weight unit picker
            Picker("Unidad de peso", selection: $weightUnit) {
                ForEach(WeightUnit.allCases, id: \.self) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    // MARK: - App Info Section
    private var appInfoSection: some View {
        Section("Información") {
            HStack {
                Label("Versión", systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Label("Build", systemImage: "hammer")
                Spacer()
                Text("2025.1")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Support Section
    private var supportSection: some View {
        Section("Soporte") {
            // Rate app
            Link(destination: URL(string: "https://apps.apple.com/app/id123456789")!) {
                Label("Valorar en App Store", systemImage: "star.fill")
                    .foregroundStyle(.primary)
            }
            
            // Share app
            ShareLink(
                item: URL(string: "https://apps.apple.com/app/id123456789")!,
                subject: Text("All1Fit - Trackea tus RMs"),
                message: Text("¡Descubre All1Fit, la mejor app para trackear tus repeticiones máximas!")
            ) {
                Label("Compartir App", systemImage: "square.and.arrow.up")
            }
            
            // Contact
            Link(destination: URL(string: "mailto:support@all1fit.com")!) {
                Label("Contacto", systemImage: "envelope")
                    .foregroundStyle(.primary)
            }
            
            // Privacy
            Link(destination: URL(string: "https://all1fit.com/privacy")!) {
                Label("Política de Privacidad", systemImage: "hand.raised")
                    .foregroundStyle(.primary)
            }
        }
    }
    
    // MARK: - Logout Section
    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                showingLogoutConfirmation = true
            } label: {
                Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .confirmationDialog(
                "¿Cerrar sesión?",
                isPresented: $showingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cerrar Sesión", role: .destructive) {
                    try? authService.signOut()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Tendrás que volver a iniciar sesión para acceder a tus datos")
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
}
