import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import os

// MARK: - Auth Service
@MainActor
class AuthService: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.all1fit", category: "AuthService")

    @Published private(set) var user: User?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isReady = false
    @Published private(set) var hasCompletedOnboarding = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isAdmin = false
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private let db = Firestore.firestore()
    
    init() {
        // Load initial state from UserDefaults for instant startup
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.isAdmin = false // Safe default
        
        setupAuthListener()
    }
    
    // MARK: - Setup
    private func setupAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.user = firebaseUser
                self.isAuthenticated = firebaseUser != nil
                
                // Set ready immediately to avoid splash screen hang
                // Data will update reactively when fetchUserData completes
                if !self.isReady {
                    self.isReady = true
                }
                
                // Fetch user data in background
                if firebaseUser != nil {
                    // Start background fetch without awaiting block
                    Task {
                        await self.fetchUserData()
                    }
                } else {
                    self.hasCompletedOnboarding = false
                    self.isAdmin = false
                }
            }
        }
    }
    
    // MARK: - User Data
    func fetchUserData() async {
        guard let userId = user?.uid else { return }
        
        // First, ensure user document exists
        await createUserDocumentIfNeeded()
        
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            if let data = doc.data() {
                if let completed = data["hasCompletedOnboarding"] as? Bool {
                    hasCompletedOnboarding = completed
                }
                if let admin = data["isAdmin"] as? Bool {
                    isAdmin = admin
                }
            }
        } catch {
            // If fetch fails, check local storage as fallback
            hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            isAdmin = false
        }
    }
    
    /// Creates the user document in Firestore if it doesn't exist
    private func createUserDocumentIfNeeded() async {
        guard let user = user else { return }
        
        let userRef = db.collection("users").document(user.uid)
        
        do {
            let doc = try await userRef.getDocument()
            
            // Only create if document doesn't exist or has no data
            if !doc.exists || doc.data() == nil {
                let userData: [String: Any] = [
                    "displayName": user.displayName ?? "",
                    "email": user.email ?? "",
                    "photoURL": user.photoURL?.absoluteString ?? "",
                    "createdAt": FieldValue.serverTimestamp(),
                    "isAdmin": false,
                    "hasCompletedOnboarding": false,
                    "preferences": [
                        "weightUnit": "kg",
                        "theme": "system"
                    ],
                    "stats": [
                        "totalExercises": 0,
                        "totalWorkouts": 0
                    ]
                ]
                
                try await userRef.setData(userData, merge: true)
                logger.info("✅ User document created for \(user.uid)")
            }
        } catch {
            logger.error("❌ Error creating user document: \(error.localizedDescription)")
        }
    }
    // ...
    
    func completeOnboarding() async {
        Track.event("onboarding_completado")
        guard let userId = user?.uid else {
            // If not logged in, just save locally
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            hasCompletedOnboarding = true
            return
        }
        
        do {
            try await db.collection("users").document(userId).setData([
                "hasCompletedOnboarding": true
            ], merge: true)
            hasCompletedOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        } catch {
            // Save locally as fallback
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            hasCompletedOnboarding = true
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
            
            // Save credentials for biometric login
            UserDefaults.standard.set(email, forKey: "lastEmail")
            _ = KeychainHelper.savePassword(password, for: email)
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
    
    // MARK: - Apple Sign In
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
    
    // MARK: - Google Sign In
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
    
    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let user = user else { return }
        let userId = user.uid
        
        // 1. Delete user document from Firestore (and subcollections ideally, but simple link is acceptable for V1)
        try await db.collection("users").document(userId).delete()
        
        // 2. Delete user from Firebase Auth
        // Note: This requires recent login. If it fails (requires-recent-login), we handle it in UI/Service.
        try await user.delete()
        
        // 3. Clear local state
        self.user = nil
        self.isAuthenticated = false
        
        logger.info("User account deleted successfully")
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