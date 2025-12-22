import SwiftUI
import FirebaseAuth
import CryptoKit

// MARK: - Auth Service (Deferred Init)
@MainActor
class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isReady = false
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    
    // Do NOT setup listener in init - wait for explicit call
    init() {}
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Start Listening (Called from ContentView.onAppear)
    func startListening() {
        guard authStateListener == nil else { return }
        
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
                self?.isAuthenticated = user != nil
                self?.isReady = true
            }
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Introduce email y contraseña"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch let error as NSError {
            errorMessage = mapError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Register
    func register(email: String, password: String, name: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Introduce email y contraseña"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            if !name.isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = name
                try await changeRequest.commitChanges()
            }
        } catch let error as NSError {
            errorMessage = mapError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    // MARK: - Error Mapping
    private func mapError(_ error: NSError) -> String {
        guard let code = AuthErrorCode(rawValue: error.code) else {
            return error.localizedDescription
        }
        switch code {
        case .invalidEmail: return "Email no válido"
        case .emailAlreadyInUse: return "Email ya registrado"
        case .weakPassword: return "Contraseña muy débil"
        case .wrongPassword, .invalidCredential: return "Credenciales incorrectas"
        case .userNotFound: return "Usuario no encontrado"
        case .tooManyRequests: return "Demasiados intentos"
        case .networkError: return "Error de conexión"
        default: return error.localizedDescription
        }
    }
}
