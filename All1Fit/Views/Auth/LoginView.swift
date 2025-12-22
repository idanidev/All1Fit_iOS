import SwiftUI
import AuthenticationServices

// MARK: - Auth Mode
enum AuthMode {
    case login
    case register
    
    var title: String {
        switch self {
        case .login: return "Iniciar Sesión"
        case .register: return "Crear Cuenta"
        }
    }
    
    var buttonTitle: String {
        switch self {
        case .login: return "Entrar"
        case .register: return "Registrarse"
        }
    }
    
    var switchText: String {
        switch self {
        case .login: return "¿No tienes cuenta?"
        case .register: return "¿Ya tienes cuenta?"
        }
    }
    
    var switchButtonText: String {
        switch self {
        case .login: return "Regístrate"
        case .register: return "Inicia sesión"
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var showingError = false
    @State private var showingPasswordReset = false
    @State private var passwordResetSent = false
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, email, password
    }
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)
                    
                    // Logo and Title
                    logoSection
                    
                    // Email/Password Form
                    formSection
                    
                    // Divider
                    dividerSection
                    
                    // Social Login Buttons
                    socialButtonsSection
                    
                    // Switch between login/register
                    switchModeSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 32)
            }
            
            // Loading overlay
            if authService.isLoading {
                loadingOverlay
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {
                authService.errorMessage = nil
            }
        } message: {
            Text(authService.errorMessage ?? "Error desconocido")
        }
        .alert("Restablecer Contraseña", isPresented: $showingPasswordReset) {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            Button("Enviar") {
                Task {
                    await authService.resetPassword(email: email)
                    if authService.errorMessage == nil {
                        passwordResetSent = true
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Te enviaremos un email para restablecer tu contraseña")
        }
        .alert("Email Enviado", isPresented: $passwordResetSent) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Revisa tu bandeja de entrada para restablecer tu contraseña")
        }
        .onChange(of: authService.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .orange.opacity(0.5), radius: 20)
            
            Text("All1Fit")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(mode.title)
                .font(.title3)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: 16) {
            // Name field (only for register)
            if mode == .register {
                CustomTextField(
                    icon: "person.fill",
                    placeholder: "Nombre",
                    text: $name,
                    isSecure: false
                )
                .focused($focusedField, equals: .name)
                .textInputAutocapitalization(.words)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Email field
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                isSecure: false
            )
            .focused($focusedField, equals: .email)
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            
            // Password field
            CustomTextField(
                icon: "lock.fill",
                placeholder: "Contraseña",
                text: $password,
                isSecure: true
            )
            .focused($focusedField, equals: .password)
            .textContentType(mode == .register ? .newPassword : .password)
            
            // Forgot password (only for login)
            if mode == .login {
                HStack {
                    Spacer()
                    Button("¿Olvidaste tu contraseña?") {
                        showingPasswordReset = true
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
            
            // Submit button
            Button {
                Task {
                    focusedField = nil
                    if mode == .login {
                        await authService.signIn(email: email, password: password)
                    } else {
                        await authService.register(email: email, password: password, name: name)
                    }
                }
            } label: {
                Text(mode.buttonTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .disabled(email.isEmpty || password.isEmpty || (mode == .register && name.isEmpty))
            .opacity(email.isEmpty || password.isEmpty || (mode == .register && name.isEmpty) ? 0.6 : 1)
        }
    }
    
    // MARK: - Divider Section
    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            Text("o continúa con")
                .font(.caption)
                .foregroundColor(.gray)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
    }
    
    // MARK: - Social Buttons Section
    private var socialButtonsSection: some View {
        VStack(spacing: 12) {
            // Sign in with Apple
            SignInWithAppleButton(
                onRequest: { request in
                    let nonce = authService.prepareAppleSignIn()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = nonce
                },
                onCompletion: { result in
                    Task {
                        await authService.handleSignInWithApple(result: result)
                    }
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .cornerRadius(12)
            
            // Sign in with Google
            Button {
                Task {
                    await authService.signInWithGoogle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                    Text("Continuar con Google")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(.white)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Switch Mode Section
    private var switchModeSection: some View {
        HStack(spacing: 4) {
            Text(mode.switchText)
                .foregroundColor(.gray)
            
            Button(mode.switchButtonText) {
                withAnimation(.spring(response: 0.3)) {
                    mode = mode == .login ? .register : .login
                    // Clear fields when switching
                    password = ""
                }
            }
            .foregroundColor(.orange)
            .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.orange)
                    .scaleEffect(1.5)
                
                Text("Cargando...")
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - Custom Text Field
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    
    @State private var showPassword = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 24)
            
            if isSecure && !showPassword {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
            }
            
            if isSecure {
                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
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
