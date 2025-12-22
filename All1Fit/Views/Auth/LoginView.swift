import SwiftUI
import AuthenticationServices

// MARK: - Auth Mode
enum AuthMode {
    case login, register
    
    var title: String {
        self == .login ? "Iniciar Sesión" : "Crear Cuenta"
    }
    
    var buttonTitle: String {
        self == .login ? "Entrar" : "Registrarse"
    }
}

// MARK: - Login View (SIMPLIFIED - for debugging)
struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var showingError = false
    @State private var showingPasswordReset = false
    @State private var passwordResetSent = false
    
    var body: some View {
        ZStack {
            // ✅ SIMPLIFIED: Solid color instead of gradient
            Color(red: 0.08, green: 0.08, blue: 0.12)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)
                    
                    // Logo
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220)
                    
                    Text(mode.title)
                        .font(.title3)
                        .foregroundColor(.gray)
                    
                    // ✅ SIMPLIFIED: Direct text fields with autocorrection disabled
                    VStack(spacing: 16) {
                        if mode == .register {
                            TextField("Nombre", text: $name)
                                .textFieldStyle(LoginTextFieldStyle())
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                        }
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(LoginTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .keyboardType(.asciiCapable)
                            .textContentType(.none)
                            .autocorrectionDisabled()
                        
                        SecureField("Contraseña", text: $password)
                            .textFieldStyle(LoginTextFieldStyle())
                            .textContentType(.none)
                            .autocorrectionDisabled()
                        
                        if mode == .login {
                            Button("¿Olvidaste tu contraseña?") {
                                showingPasswordReset = true
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        
                        // Submit
                        Button {
                            submit()
                        } label: {
                            Text(mode.buttonTitle)
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1 : 0.6)
                    }
                    .padding(.horizontal, 32)
                    
                    // Divider
                    HStack {
                        Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                        Text("o").font(.caption).foregroundColor(.gray)
                        Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                    }
                    .padding(.horizontal, 32)
                    
                    // Social
                    VStack(spacing: 12) {
                        SignInWithAppleButton(
                            onRequest: { request in
                                let nonce = authService.prepareAppleSignIn()
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = nonce
                            },
                            onCompletion: { result in
                                Task { await authService.handleSignInWithApple(result: result) }
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(12)
                        
                        Button {
                            Task { await authService.signInWithGoogle() }
                        } label: {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                Text("Continuar con Google")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(.white)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Switch mode
                    HStack {
                        Text(mode == .login ? "¿No tienes cuenta?" : "¿Ya tienes cuenta?")
                            .foregroundColor(.gray)
                        Button(mode == .login ? "Regístrate" : "Inicia sesión") {
                            withAnimation {
                                mode = mode == .login ? .register : .login
                                password = ""
                            }
                        }
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    
                    Spacer(minLength: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            
            // Loading
            if authService.isLoading {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView()
                    .tint(.orange)
                    .scaleEffect(1.5)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { authService.errorMessage = nil }
        } message: {
            Text(authService.errorMessage ?? "")
        }
        .alert("Restablecer Contraseña", isPresented: $showingPasswordReset) {
            TextField("Email", text: $email)
            Button("Enviar") {
                Task {
                    if await authService.resetPassword(email: email) {
                        passwordResetSent = true
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Te enviaremos un email")
        }
        .alert("Email Enviado", isPresented: $passwordResetSent) {
            Button("OK") {}
        } message: {
            Text("Revisa tu bandeja de entrada")
        }
        .onChange(of: authService.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && (mode == .login || !name.isEmpty)
    }
    
    private func submit() {
        Task {
            if mode == .login {
                await authService.signIn(email: email, password: password)
            } else {
                await authService.register(email: email, password: password, name: name)
            }
        }
    }
}

// MARK: - Simple Text Field Style
struct LoginTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white.opacity(0.1))
            .foregroundColor(.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}