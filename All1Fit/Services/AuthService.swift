import SwiftUI
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit
import GoogleSignIn

// MARK: - Auth Service (NON-BLOCKING)
@MainActor
class AuthService: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isReady = false
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    
    init() {
        // ✅ NO bloquear init - hacer setup async
        Task { @MainActor in
            await setupAuthListenerAsync()
        }
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Setup Auth Listener (ASYNC - NON BLOCKING)
    private func setupAuthListenerAsync() async {
        // Pequeño delay para que la UI se renderice primero
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 segundos
        
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.user = firebaseUser
                self.isAuthenticated = firebaseUser != nil
                
                if !self.isReady {
                    self.isReady = true
                }
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
        defer { isLoading = false }
        
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch let error as NSError {
            errorMessage = mapError(error)
        }
    }
    
    // MARK: - Register
    func register(email: String, password: String, name: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Introduce email y contraseña"
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
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
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async -> Bool {
        guard !email.isEmpty else {
            errorMessage = "Introduce tu email"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return true
        } catch let error as NSError {
            errorMessage = mapError(error)
            return false
        }
    }
    
    // MARK: - Sign in with Apple
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }
    
    func handleSignInWithApple(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            guard case .success(let authorization) = result,
                  let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                throw AuthError.invalidCredentials
            }
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            try await Auth.auth().signIn(with: credential)
        } catch {
            if let authError = error as? AuthError {
                errorMessage = authError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Sign in with Google
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Error de configuración"
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Error de ventana"
            return
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.invalidToken
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            try await Auth.auth().signIn(with: credential)
        } catch {
            if (error as NSError).code != GIDSignInError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Sign Out
    func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }
    
    // MARK: - Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func mapError(_ error: NSError) -> String {
        guard let code = AuthErrorCode(rawValue: error.code) else {
            return error.localizedDescription
        }
        switch code {
        case .invalidEmail: return "Email no válido"
        case .emailAlreadyInUse: return "Email ya registrado"
        case .weakPassword: return "Contraseña muy débil (mínimo 6 caracteres)"
        case .wrongPassword, .invalidCredential: return "Credenciales incorrectas"
        case .userNotFound: return "Usuario no encontrado"
        case .tooManyRequests: return "Demasiados intentos. Espera un momento"
        case .networkError: return "Error de conexión"
        default: return error.localizedDescription
        }
    }
}

// MARK: - Auth Errors
private enum AuthError: LocalizedError {
    case invalidCredentials
    case invalidToken
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Credenciales inválidas"
        case .invalidToken: return "Token inválido"
        }
    }
}