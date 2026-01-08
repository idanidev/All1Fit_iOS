import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import PhotosUI

// MARK: - Main Tab View (iOS 26 Liquid Glass TabBar)
struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var userWorkoutService = UserWorkoutService()
    @State private var selectedTab = 0
    @State private var showingAddSheet = false
    @State private var showingAddRM = false
    @State private var showingAddWorkout = false
    @State private var showingFullPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                RMListView()
                    .tabItem {
                        Label("RMs", systemImage: "dumbbell.fill")
                    }
                    .tag(0)
                
                WorkoutsView()
                    .environmentObject(userWorkoutService)
                    .tabItem {
                        Label("Entrenos", systemImage: "figure.run")
                    }
                    .tag(1)
                
                TabataListView()
                    .tabItem {
                        Label("Tabatas", systemImage: "timer")
                    }
                    .tag(2)
                
                // TODO: Mobility - Coming in v1.1
                // if authService.isAdmin {
                //     MobilityView()
                //         .tabItem {
                //             Label("Movilidad", systemImage: "figure.flexibility")
                //         }
                //         .tag(3)
                // }
                
                SettingsView()
                    .tabItem {
                        Label("Ajustes", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .tint(.orange)
            
            // Mini Player for Tabata (floating above tab bar)
            VStack {
                Spacer()
                TabataMiniPlayer(showFullPlayer: $showingFullPlayer)
                    .padding(.bottom, 50) // Above tab bar
            }
        }
        .fullScreenCover(isPresented: $showingFullPlayer) {
            if let activeTabata = TabataSessionManager.shared.activeTabata {
                TabataTimerView(tabata: activeTabata, syncWithWatch: true)
            }
        }
        .confirmationDialog("¿Qué quieres añadir?", isPresented: $showingAddSheet, titleVisibility: .visible) {
            Button("Nuevo RM") {
                showingAddRM = true
            }
            Button("Nuevo Entreno") {
                showingAddWorkout = true
            }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $showingAddRM) {
            EjercicioFormView(mode: .new) { name, rm in
                // This will be handled by RMListView's refresh
            }
        }
        .sheet(isPresented: $showingAddWorkout) {
            WorkoutFormView()
                .environmentObject(userWorkoutService)
        }
    }
}

// MARK: - Settings View (iOS 26)
struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingProfileEdit = false
    @State private var showingPrivacyPolicy = false
    @State private var profileRefreshID = UUID() // Forces avatar refresh
    
    var body: some View {
        NavigationStack {
            List {
                // User Section
                userSection
                
                // Preferences
                preferencesSection
                
                // Support (moved before Info)
                supportSection
                
                // App Info
                appInfoSection
                
                
                // Logout
                logoutSection
                
                // Delete Account
                deleteAccountSection
            }
            .navigationTitle("Ajustes")
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80) // Reduced to fit Dynamic Island
                        .shadow(color: .white.opacity(0.5), radius: 10)
                }
            }
            .sheet(isPresented: $showingProfileEdit, onDismiss: {
                // Force refresh of avatar image when profile is edited
                profileRefreshID = UUID()
            }) {
                ProfileEditView()
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
        }
    }
    
    // MARK: - User Section
    private var userSection: some View {
        Section {
            if let user = authService.user {
                Button {
                    showingProfileEdit = true
                } label: {
                    HStack(spacing: 16) {
                        // Avatar with photo support (cached)
                        Group {
                            if let photoURL = user.photoURL {
                                CachedAsyncImage(url: photoURL) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                } placeholder: {
                                    avatarPlaceholder(for: user)
                                }
                            } else {
                                avatarPlaceholder(for: user)
                            }
                        }
                        .id(profileRefreshID) // Force refresh when photo changes
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName ?? "Usuario")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text(user.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Perfil")
        } footer: {
            Text("Toca para editar tu perfil")
        }
    }
    
    // MARK: - Avatar Placeholder
    private func avatarPlaceholder(for user: FirebaseAuth.User) -> some View {
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
            
            // Restore hidden workouts
            Button {
                UserDefaults.standard.removeObject(forKey: "hiddenWorkoutIds")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Label("Restaurar entrenos ocultos", systemImage: "arrow.counterclockwise")
            }
        }
    }
    
    // MARK: - App Info Section
    private var appInfoSection: some View {
        Section("Información") {
            HStack {
                Label("Versión", systemImage: "info.circle")
                Spacer()
                Text("1.1.0")
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
            Link(destination: URL(string: "mailto:idanideveloper@gmail.com")!) {
                Label("Contacto", systemImage: "envelope")
                    .foregroundStyle(.primary)
            }
            
            // Privacy Policy
            Button {
                showingPrivacyPolicy = true
            } label: {
                Label("Política de Privacidad", systemImage: "hand.raised")
                    .foregroundStyle(.primary)
            }
        }
    }
    
    // MARK: - Logout Section
    private var logoutSection: some View {
        Section {
            Button {
                showingLogoutConfirmation = true
            } label: {
                Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.primary)
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
    
    // MARK: - Delete Account Section
    private var deleteAccountSection: some View {
        Section {
            Button {
                showingDeleteAccountConfirmation = true
            } label: {
                Label("Eliminar Cuenta", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.orange)
            }
            .confirmationDialog(
                "¿Eliminar cuenta?",
                isPresented: $showingDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button("Eliminar permanentemente", role: .destructive) {
                    Task {
                        do {
                            try await authService.deleteAccount()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } catch {
                            // Ideally show error alert, for now simple print/feedback
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Esta acción es irreversible. Se eliminarán todos tus datos, entrenamientos y registros permanentemente.")
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
}
