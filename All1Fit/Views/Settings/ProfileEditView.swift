import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Profile Edit View
struct ProfileEditView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName = ""
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile Section
                Section {
                    // Avatar (read-only for now)
                    HStack {
                        Spacer()
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
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
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
                
                // Error message
                if let error = errorMessage {
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
                        Group {
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Guardar")
                                    .fontWeight(.semibold)
                            }
                        }
                        .animation(.none, value: isSaving)
                    }
                    .disabled(displayName.isEmpty || isSaving)
                }
            }
            .onAppear {
                displayName = authService.user?.displayName ?? ""
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
    
    // MARK: - Save Profile
    private func saveProfile() {
        guard let user = authService.user else { return }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                // Update Firebase Auth profile
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
                
                // Update Firestore user document
                try await db.collection("users").document(user.uid).setData([
                    "displayName": displayName
                ], merge: true)
                
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

#Preview {
    ProfileEditView()
        .environmentObject(AuthService())
}
