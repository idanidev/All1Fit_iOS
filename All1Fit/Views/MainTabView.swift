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
    
    var body: some View {
        ZStack(alignment: .top) {
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
            
            // Offline indicator banner
            OfflineBanner()
                .animation(.spring(duration: 0.3), value: NetworkMonitor.shared.isConnected)
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
    @State private var showingDeleteConfirmation = false
    @State private var showingProfileEdit = false
    @State private var profileRefreshID = UUID() // Forces avatar refresh
    
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

// MARK: - Profile Edit View
struct ProfileEditView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName = ""
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var photoURL: String?
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile Section
                Section {
                    // Avatar with PhotosPicker
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack {
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else if let photoURL = photoURL, let url = URL(string: photoURL) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        avatarPlaceholder
                                    }
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                } else {
                                    avatarPlaceholder
                                }
                                
                                // Camera badge
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                    )
                                    .offset(x: 35, y: 35)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                profileImage = uiImage
                            }
                        }
                    }
                }
                
                // Editable Fields
                Section("Información Personal") {
                    HStack {
                        Label("Nombre", systemImage: "person")
                        Spacer()
                        TextField("Tu nombre", text: $displayName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Label("Email", systemImage: "envelope")
                        Spacer()
                        Text(authService.user?.email ?? "")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Stats Section (read-only)
                Section("Estadísticas") {
                    HStack {
                        Label("Usuario desde", systemImage: "calendar")
                        Spacer()
                        Text(authService.user?.metadata.creationDate?.formatted(date: .abbreviated, time: .omitted) ?? "")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Error message (hide "does not exist" errors as they're expected for new users)
                if let error = errorMessage, !error.contains("does not exist") {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Editar Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Guardar")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(displayName.isEmpty || isSaving)
                }
            }
            .onAppear {
                displayName = authService.user?.displayName ?? ""
                photoURL = authService.user?.photoURL?.absoluteString
            }
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
        }
    }
    
    // MARK: - Success Overlay
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                
                Text("¡Guardado!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }
    
    // MARK: - Avatar Placeholder
    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
            
            Text(displayName.prefix(1).uppercased())
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Save Profile
    private func saveProfile() {
        guard let user = authService.user else { return }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                var newPhotoURL: String? = nil
                
                // Upload image if selected
                if let profileImage = profileImage,
                   let imageData = profileImage.jpegData(compressionQuality: 0.7) {
                    let storageRef = Storage.storage().reference()
                        .child("users/\(user.uid)/profile.jpg")
                    
                    _ = try await storageRef.putDataAsync(imageData)
                    newPhotoURL = try await storageRef.downloadURL().absoluteString
                }
                
                // Update Firebase Auth profile
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                if let photoURLString = newPhotoURL, let url = URL(string: photoURLString) {
                    changeRequest.photoURL = url
                    // Invalidate old cached image
                    if let oldPhotoURL = user.photoURL {
                        ImageCacheManager.shared.invalidate(url: oldPhotoURL)
                    }
                    // Also invalidate new URL to force fresh download
                    ImageCacheManager.shared.invalidate(url: url)
                }
                try await changeRequest.commitChanges()
                
                // Update Firestore user document
                var updateData: [String: Any] = ["displayName": displayName]
                if let photoURLString = newPhotoURL {
                    updateData["photoURL"] = photoURLString
                }
                try await db.collection("users").document(user.uid).setData(updateData, merge: true)
                
                // Show success and dismiss
                showSuccess = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
                try? await Task.sleep(nanoseconds: 800_000_000)
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

