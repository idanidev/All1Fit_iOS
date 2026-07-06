import SwiftUI
import StoreKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - Main Tab View (iOS 26 Liquid Glass TabBar)
struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var userWorkoutService = UserWorkoutService()
    @StateObject private var gymSessionService = GymSessionService()
    @State private var selectedTab = 0
    @State private var showingAddSheet = false
    @State private var showingAddRM = false
    @State private var showingAddWorkout = false
    @State private var showingFullPlayer = false
    @State private var showingGymSession = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab)
                    .environmentObject(authService)
                    .tabItem {
                        Label("Inicio", systemImage: "house.fill")
                    }
                    .tag(0)

                RMListView()
                    .tabItem {
                        Label("RMs", systemImage: "figure.strengthtraining.traditional")
                    }
                    .tag(1)

                TrainingHubView()
                    .environmentObject(userWorkoutService)
                    .tabItem {
                        Label("Entreno", systemImage: "figure.run")
                    }
                    .tag(2)

                NavigationStack {
                    GymHubView(sessionService: gymSessionService)
                }
                .tabItem {
                    Label("Gym", systemImage: "dumbbell.fill")
                }
                .tag(3)

                SettingsView()
                    .tabItem {
                        Label("Ajustes", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .tint(.orange)
            
            // Mini players flotantes sobre la tab bar (tabata + sesión de gym)
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    if !showingGymSession {
                        GymMiniPlayer(sessionService: gymSessionService)
                    }
                    TabataMiniPlayer(showFullPlayer: $showingFullPlayer)
                }
                .padding(.bottom, 50) // Above tab bar
            }
        }
        .fullScreenCover(isPresented: $showingFullPlayer) {
            if let activeTabata = TabataSessionManager.shared.activeTabata {
                TabataTimerView(tabata: activeTabata, syncWithWatch: true)
            }
        }
        .fullScreenCover(isPresented: $showingGymSession) {
            ActiveGymSessionView(sessionService: gymSessionService)
        }
        .onChange(of: gymSessionService.activeSession != nil) { _, hasSession in
            // Al empezar sesión desde cualquier pantalla, abre el logger
            if hasSession { showingGymSession = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openActiveGymSession)) { _ in
            if gymSessionService.activeSession != nil {
                showingGymSession = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openActiveTabata)) { _ in
            if TabataSessionManager.shared.isActive {
                selectedTab = 2
                showingFullPlayer = true
            }
        }
        .task {
            // Restore tabata session if app was killed mid-session
            TabataSessionManager.shared.restoreSessionIfNeeded()
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
            EjercicioFormView(mode: .new) { _, _, _, _ in }
        }
        .sheet(isPresented: $showingAddWorkout) {
            WorkoutFormView()
                .environmentObject(userWorkoutService)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.requestReview) private var requestReview
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingProfileEdit = false
    @State private var showingPrivacyPolicy = false
    @State private var profileRefreshID = UUID()
    @State private var errorMessage: String?

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                userSection
                preferencesSection
                supportSection
                accountSection
                versionFooterSection
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.large)
            .listStyle(.insetGrouped)
            .sheet(isPresented: $showingProfileEdit, onDismiss: { profileRefreshID = UUID() }) {
                ProfileEditView()
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - User Section
    private var userSection: some View {
        Section {
            if let user = authService.user {
                Button {
                    showingProfileEdit = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    HStack(spacing: 16) {
                        Group {
                            if let photoURL = user.photoURL {
                                CachedAsyncImage(url: photoURL) { image in
                                    image.resizable().scaledToFill()
                                        .frame(width: 58, height: 58)
                                        .clipShape(Circle())
                                } placeholder: {
                                    avatarPlaceholder(for: user)
                                }
                            } else {
                                avatarPlaceholder(for: user)
                            }
                        }
                        .id(profileRefreshID)
                        .overlay(
                            Circle().stroke(
                                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2
                            )
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.displayName ?? "Atleta")
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)
                            Text(user.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func avatarPlaceholder(for user: FirebaseAuth.User) -> some View {
        Circle()
            .fill(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 58, height: 58)
            .overlay {
                Text(user.displayName?.prefix(1).uppercased() ?? "A")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
    }

    // MARK: - Preferences
    private var preferencesSection: some View {
        Section("Preferencias") {
            Picker("Tema", selection: $appTheme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }

            Picker("Unidad de peso", selection: $weightUnit) {
                ForEach(WeightUnit.allCases, id: \.self) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }

            Button {
                UserDefaults.standard.removeObject(forKey: "hiddenWorkoutIds")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Label("Restaurar entrenos ocultos", systemImage: "arrow.counterclockwise")
            }
            .foregroundStyle(.primary)
        }
    }

    // MARK: - Support
    private var supportSection: some View {
        Section("Soporte") {
            Button {
                requestReview()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label("Valorar All1Fit", systemImage: "star.fill")
                    .foregroundStyle(.primary)
            }

            ShareLink(
                item: URL(string: "https://apps.apple.com/app/all1fit/id6744387668")!,
                subject: Text("All1Fit - Tu gimnasio en el bolsillo"),
                message: Text("Trackea tus RMs, entrenos WOD y tabatas con All1Fit. Gratis para iPhone y Apple Watch.")
            ) {
                Label("Compartir App", systemImage: "square.and.arrow.up")
            }

            Link(destination: URL(string: "mailto:idanideveloper@gmail.com?subject=All1Fit%20Feedback")!) {
                Label("Contacto", systemImage: "envelope.fill")
                    .foregroundStyle(.primary)
            }

            Button {
                showingPrivacyPolicy = true
            } label: {
                Label("Política de Privacidad", systemImage: "hand.raised.fill")
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Version Footer
    private var versionFooterSection: some View {
        Section {
        } footer: {
            VStack(spacing: 4) {
                Text("All1Fit")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("v\(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
        }
    }

    // MARK: - Account
    private var accountSection: some View {
        Section {
            Button {
                showingLogoutConfirmation = true
            } label: {
                Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.primary)
            }
            .all1FitConfirmation(Binding(
                get: {
                    guard showingLogoutConfirmation else { return nil }
                    return All1FitConfirmation(
                        title: "¿Cerrar sesión?",
                        message: "Tendrás que volver a iniciar sesión para acceder a tus datos.",
                        icon: "rectangle.portrait.and.arrow.right",
                        tint: .all1FitOrange,
                        confirmTitle: "Cerrar sesión"
                    ) {
                        do {
                            try authService.signOut()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                },
                set: { if $0 == nil { showingLogoutConfirmation = false } }
            ))

            Button(role: .destructive) {
                showingDeleteAccountConfirmation = true
            } label: {
                Label("Eliminar Cuenta", systemImage: "trash")
            }
            .all1FitConfirmation(Binding(
                get: {
                    guard showingDeleteAccountConfirmation else { return nil }
                    return All1FitConfirmation(
                        title: "¿Eliminar cuenta?",
                        message: "Esta acción es irreversible. Se eliminarán todos tus datos: RMs, entrenos, tabatas, rutinas y medidas.",
                        icon: "trash.fill",
                        confirmTitle: "Eliminar permanentemente"
                    ) {
                        Task {
                            do {
                                try await authService.deleteAccount()
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } catch {
                                errorMessage = error.localizedDescription
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                            }
                        }
                    }
                },
                set: { if $0 == nil { showingDeleteAccountConfirmation = false } }
            ))
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
}
