import FirebaseAuth
import FirebaseFirestore
import HealthKit
import StoreKit
import SwiftUI

// MARK: - Settings View (Strict Design System)
struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @AppStorage("isPro") private var isPro: Bool = false

    @Environment(\.requestReview) private var requestReview
    @StateObject private var healthKit = HealthKitService.shared

    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingProfileEdit = false
    @State private var showingPrivacyPolicy = false
    @State private var profileRefreshID = UUID()  // Forces avatar refresh

    var body: some View {
        NavigationStack {
            ZStack {
                // Background: Standard App Background
                Color.all1FitBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Layout.lg) {
                        // Profile Header
                        profileHeroSection
                            .padding(.top, Layout.sm)

                        // Settings Groups

                        // EXPERIENCE
                        VStack(spacing: Layout.md) {
                            sectionHeader("EXPERIENCIA")

                            VStack(spacing: 1) {
                                SettingsRow(icon: "moon.fill", title: "Tema", color: .all1FitPurple)
                                {
                                    Picker("", selection: $appTheme) {
                                        ForEach(AppTheme.allCases) { theme in
                                            Text(theme.displayName).tag(theme)
                                        }
                                    }
                                    .tint(.secondary)
                                }

                                Divider().overlay(Color.all1FitBackground)

                                SettingsRow(icon: "globe", title: "Idioma", color: .all1FitBlue) {
                                    Text("Español")
                                        .font(.all1FitBody)
                                        .foregroundStyle(.secondary)
                                }

                                Divider().overlay(Color.all1FitBackground)

                                SettingsRow(
                                    icon: "scalemass.fill", title: "Unidades", color: .all1FitOrange
                                ) {
                                    Picker("", selection: $weightUnit) {
                                        ForEach(WeightUnit.allCases) { unit in
                                            Text(unit.displayName).tag(unit)
                                        }
                                    }
                                    .tint(.secondary)
                                }
                            }
                            .background(Color.all1FitBackgroundSecondary)
                            .clipShape(
                                RoundedRectangle(cornerRadius: Layout.radiusMd, style: .continuous))
                        }

                        // DATA
                        VStack(spacing: Layout.md) {
                            sectionHeader("DATOS")

                            Button {
                                UserDefaults.standard.removeObject(forKey: "hiddenWorkoutIds")
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } label: {
                                SettingsRow(
                                    icon: "eye.fill", title: "Restaurar Ocultos",
                                    color: .all1FitCyan, showChevron: false
                                ) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .background(Color.all1FitBackgroundSecondary)
                            .clipShape(
                                RoundedRectangle(cornerRadius: Layout.radiusMd, style: .continuous))
                        }

                        // SALUD
                        VStack(spacing: Layout.md) {
                            sectionHeader("SALUD")

                            VStack(spacing: 1) {
                                SettingsRow(
                                    icon: "heart.fill", title: "Apple Health",
                                    color: .red, showChevron: false
                                ) {
                                    if healthKit.isAuthorized {
                                        Text("Conectado")
                                            .font(.all1FitSmall)
                                            .foregroundStyle(.all1FitSuccess)
                                    } else {
                                        Button("Conectar") {
                                            Task { await healthKit.requestAuthorization() }
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }
                                        .font(.all1FitSmall.weight(.semibold))
                                        .foregroundStyle(.all1FitBlue)
                                    }
                                }

                                Divider().overlay(Color.all1FitBackground)

                                SettingsRow(
                                    icon: "figure.run", title: "Guardar entrenos",
                                    color: .all1FitOrange, showChevron: false
                                ) {
                                    Image(systemName: healthKit.isAuthorized ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundStyle(healthKit.isAuthorized ? .all1FitSuccess : .secondary)
                                }

                                Divider().overlay(Color.all1FitBackground)

                                SettingsRow(
                                    icon: "flame.fill", title: "Calorias activas",
                                    color: .all1FitRed, showChevron: false
                                ) {
                                    Image(systemName: healthKit.isAuthorized ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundStyle(healthKit.isAuthorized ? .all1FitSuccess : .secondary)
                                }
                            }
                            .background(Color.all1FitBackgroundSecondary)
                            .clipShape(
                                RoundedRectangle(cornerRadius: Layout.radiusMd, style: .continuous))

                            if healthKit.isAuthorized {
                                Text("Los entrenos completados se guardan automaticamente en Apple Health.")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .padding(.horizontal, 8)
                            }
                        }

                        // SUPPORT
                        VStack(spacing: Layout.md) {
                            sectionHeader("SOPORTE")

                            VStack(spacing: 1) {
                                Button {
                                    requestReview()
                                } label: {
                                    SettingsRow(
                                        icon: "star.fill", title: "Valorar All1Fit",
                                        color: .all1FitWarning, showChevron: false
                                    ) {
                                        Image(systemName: "star.leadinghalf.filled")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)

                                Divider().overlay(Color.all1FitBackground)

                                Link(destination: URL(string: "mailto:support@all1fit.com")!) {
                                    SettingsRow(
                                        icon: "envelope.fill", title: "Contactar",
                                        color: .all1FitSuccess
                                    ) {
                                        Image(systemName: "paperplane")
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Divider().overlay(Color.all1FitBackground)

                                Button {
                                    showingPrivacyPolicy = true
                                } label: {
                                    SettingsRow(
                                        icon: "hand.raised.fill", title: "Privacidad",
                                        color: .indigo
                                    ) {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .background(Color.all1FitBackgroundSecondary)
                            .clipShape(
                                RoundedRectangle(cornerRadius: Layout.radiusMd, style: .continuous))
                        }

                        // ACCOUNT
                        VStack(spacing: Layout.md) {
                            sectionHeader("CUENTA")

                            VStack(spacing: 1) {
                                Button {
                                    showingLogoutConfirmation = true
                                } label: {
                                    SettingsRow(
                                        icon: "rectangle.portrait.and.arrow.right",
                                        title: "Cerrar Sesión", color: .all1FitRed
                                    ) {
                                        EmptyView()
                                    }
                                }

                                Divider().overlay(Color.all1FitBackground)

                                Button {
                                    showingDeleteAccountConfirmation = true
                                } label: {
                                    SettingsRow(
                                        icon: "trash.fill", title: "Eliminar Cuenta",
                                        color: .all1FitRed.opacity(0.8)
                                    ) {
                                        EmptyView()
                                    }
                                }
                            }
                            .background(Color.all1FitBackgroundSecondary)
                            .clipShape(
                                RoundedRectangle(cornerRadius: Layout.radiusMd, style: .continuous))
                        }

                        // Footer
                        VStack(spacing: 8) {
                            Text("All1Fit v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0")")
                                .font(.all1FitSmall)
                                .foregroundStyle(Color.gray)

                            Text("Designed in Madrid")
                                .font(.caption2)
                                .foregroundStyle(Color.gray.opacity(0.6))
                        }
                        .padding(.top, Layout.xl)

                        Color.clear.frame(height: 80)
                    }
                    .padding()
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingProfileEdit, onDismiss: { profileRefreshID = UUID() }) {
                ProfileEditView()
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .confirmationDialog(
                "¿Cerrar Sesión?",
                isPresented: $showingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Cerrar Sesión", role: .destructive) {
                    try? authService.signOut()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                Button("Cancelar", role: .cancel) {}
            }
            .confirmationDialog(
                "¿Eliminar Cuenta?",
                isPresented: $showingDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button("Eliminar Permanentemente", role: .destructive) {
                    Task {
                        try? await authService.deleteAccount()
                    }
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    // MARK: - Components

    // 1. Profile Hero (Consistent with RMListView's dark theme)
    private var profileHeroSection: some View {
        Button {
            showingProfileEdit = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: Layout.md) {
                // Large Avatar
                ZStack {
                    Circle()
                        .fill(Color.all1FitBackground)
                        .frame(width: 84, height: 84)

                    if let photoURL = authService.user?.photoURL {
                        CachedAsyncImage(url: photoURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            avatarPlaceholder
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .id(profileRefreshID)
                    } else {
                        avatarPlaceholder
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    }

                    // Edit Badge
                    Image(systemName: "pencil.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.primary)
                        .font(.system(size: 24))
                        .offset(x: 28, y: 28)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(authService.user?.displayName ?? "Atleta")
                        .font(.all1FitHeaderMedium)
                        .foregroundStyle(.white)

                    Text(authService.user?.email ?? "Sin email")
                        .font(.all1FitBody)
                        .foregroundStyle(.gray)

                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.all1FitBodyBold)
                    .foregroundStyle(.gray)
            }
            .padding(Layout.lg)
            .background(Color.all1FitBackgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Layout.radiusLg, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(
            "Perfil de \(authService.user?.displayName ?? "Usuario"). Toca para editar."
        )
        .accessibilityHint("Edita tu foto, nombre y preferencias de cuenta.")

    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.all1FitBackgroundTertiary)
            .overlay(
                Text(authService.user?.displayName?.prefix(1).uppercased() ?? "A")
                    .font(.all1FitHeaderLarge)
                    .foregroundStyle(.white)
            )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Color.gray)
            .padding(.leading, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Reusable Row (Strict Layout)
struct SettingsRow<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    var showChevron: Bool = true  // Parameter to toggle chevron visibility for simple rows
    @ViewBuilder let content: Content

    init(
        icon: String, title: String, color: Color, showChevron: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.color = color
        self.showChevron = showChevron  // Initialize the property
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 30, height: 30)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            Text(title)
                .font(.all1FitBody)
                .foregroundStyle(.white)

            Spacer()

            content

            // Only add default chevron if it wasn't already added by the content (check implementation)
            // Actually, for simplicity, let's leave the content to provide the visual queue if needed
            // But usually rows have chevrons if actionable.
        }
        .padding(16)
        .background(Color.all1FitBackgroundSecondary)  // Row color matches group
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService())
}
