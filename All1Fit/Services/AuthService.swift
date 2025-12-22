import SwiftUI
import FirebaseAuth
import AuthenticationServices
import CryptoKit

// MARK: - Auth Service
@MainActor
class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    
    init() {
        listenToAuthState()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Listener
    private func listenToAuthState() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    // MARK: - Email/Password Login
    func signIn(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Por favor, introduce email y contraseña"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch let error as NSError {
            errorMessage = mapFirebaseError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Email/Password Registration
    func register(email: String, password: String, name: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Por favor, introduce email y contraseña"
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "La contraseña debe tener al menos 6 caracteres"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Update display name if provided
            if !name.isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = name
                try await changeRequest.commitChanges()
            }
        } catch let error as NSError {
            errorMessage = mapFirebaseError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "Por favor, introduce tu email"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            errorMessage = nil
        } catch let error as NSError {
            errorMessage = mapFirebaseError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Sign in with Apple
    func handleSignInWithApple(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard case .success(let authorization) = result,
                  let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                throw AuthError.invalidCredential
            }
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            try await Auth.auth().signIn(with: credential)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // Generate nonce for Apple Sign In
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }
    
    // MARK: - Sign in with Google
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        // Note: Google Sign-In requires additional setup
        // For now, show a message
        errorMessage = "Google Sign-In requiere configuración adicional. Usa email o Apple."
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    // MARK: - Helper Functions
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func mapFirebaseError(_ error: NSError) -> String {
        guard let errorCode = AuthErrorCode(rawValue: error.code) else {
            return error.localizedDescription
        }
        
        switch errorCode {
        case .invalidEmail:
            return "El email no es válido"
        case .emailAlreadyInUse:
            return "Este email ya está registrado"
        case .weakPassword:
            return "La contraseña es muy débil"
        case .wrongPassword, .invalidCredential:
            return "Email o contraseña incorrectos"
        case .userNotFound:
            return "No existe una cuenta con este email"
        case .tooManyRequests:
            return "Demasiados intentos. Espera un momento"
        case .networkError:
            return "Error de conexión. Comprueba tu internet"
        default:
            return error.localizedDescription
        }
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidCredential
    case noRootViewController
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Credenciales inválidas"
        case .noRootViewController:
            return "No se pudo obtener la ventana principal"
        case .notImplemented:
            return "Función no implementada"
        }
    }
}
