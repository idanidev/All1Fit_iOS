import SwiftUI
import AuthenticationServices
import LocalAuthentication

// MARK: - Auth Mode
enum AuthMode: String, CaseIterable {
    case login, register
    
    var title: String {
        self == .login ? "Iniciar Sesión" : "Crear Cuenta"
    }
    
    var buttonTitle: String {
        self == .login ? "Entrar" : "Registrarse"
    }
}

// MARK: - Login View (iOS 26 Premium)
struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @Namespace private var animation
    
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var showingError = false
    @State private var showingPasswordReset = false
    @State private var passwordResetSent = false
    @State private var logoAnimated = false
    @State private var formAppeared = false
    
    var body: some View {
        ZStack {
            // ✅ iOS 26: Animated Mesh Gradient Background
            animatedBackground
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)
                    
                    // Logo Section
                    logoSection
                    
                    // Form Section with Liquid Glass
                    formSection
                    
                    // Divider
                    dividerSection
                    
                    // Social Login with Liquid Glass
                    socialSection
                    
                    // Switch Mode
                    switchModeSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            
            // Loading Overlay
            if authService.isLoading {
                loadingOverlay
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
            Text("Te enviaremos un email para restablecer tu contraseña")
        }
        .alert("Email Enviado ✓", isPresented: $passwordResetSent) {
            Button("OK") {}
        } message: {
            Text("Revisa tu bandeja de entrada")
        }
        .onChange(of: authService.errorMessage) { _, newValue in
            if newValue != nil {
                showingError = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 1.0, bounce: 0.3).delay(0.2)) {
                logoAnimated = true
            }
            withAnimation(.spring(duration: 0.8).delay(0.5)) {
                formAppeared = true
            }
        }
    }
    
    // MARK: - Animated Background
    private var animatedBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: "0a0a0f"),
                Color(hex: "1a1a2e"),
                Color(hex: "16213e"),
                Color(hex: "0a0a0f")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 20) {
            // Glow effect
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 280, height: 280)
                    .blur(radius: 40)
                
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280)
                    .scaleEffect(logoAnimated ? 1.0 : 0.5)
                    .opacity(logoAnimated ? 1.0 : 0)
            }
            
            Text(mode.title)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: 16) {
            // Name field (register only)
            if mode == .register {
                GlassTextField(
                    placeholder: "Nombre",
                    text: $name,
                    icon: "person.fill"
                )
                .textInputAutocapitalization(.words)
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
            
            // Email field
            GlassTextField(
                placeholder: "Email",
                text: $email,
                icon: "envelope.fill"
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            
            // Password field
            GlassSecureField(
                placeholder: "Contraseña",
                text: $password,
                icon: "lock.fill"
            )
            
            // Forgot password
            if mode == .login {
                HStack {
                    Spacer()
                    Button("¿Olvidaste tu contraseña?") {
                        showingPasswordReset = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
            
            // Submit button
            Button {
                submit()
            } label: {
                HStack(spacing: 8) {
                    Text(mode.buttonTitle)
                        .font(.headline)
                    Image(systemName: "arrow.right")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
            }
            .disabled(!isFormValid)
            .opacity(isFormValid ? 1 : 0.6)
            .padding(.top, 8)
        }
        .opacity(formAppeared ? 1 : 0)
        .offset(y: formAppeared ? 0 : 30)
    }
    
    // MARK: - Divider Section
    private var dividerSection: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
            
            Text("o")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
        }
        .opacity(formAppeared ? 1 : 0)
    }
    
    // MARK: - Social Section
    private var socialSection: some View {
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
            .frame(height: 56)
            .clipShape(.capsule)
            
            // Sign in with Google
            Button {
                Task {
                    await authService.signInWithGoogle()
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 10) {
                    // Google G Logo
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 24, height: 24)
                        
                        Text("G")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .yellow, .green, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text("Continuar con Google")
                        .font(.headline)
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.white, in: Capsule())
            }
        }
        .opacity(formAppeared ? 1 : 0)
        .offset(y: formAppeared ? 0 : 20)
    }
    
    // MARK: - Switch Mode Section
    private var switchModeSection: some View {
        HStack(spacing: 4) {
            Text(mode == .login ? "¿No tienes cuenta?" : "¿Ya tienes cuenta?")
                .foregroundStyle(.secondary)
            
            Button(mode == .login ? "Regístrate" : "Inicia sesión") {
                withAnimation(.spring(duration: 0.4)) {
                    mode = mode == .login ? .register : .login
                    password = ""
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .foregroundStyle(.orange)
            .fontWeight(.semibold)
        }
        .font(.subheadline)
        .opacity(formAppeared ? 1 : 0)
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.orange)
                
                Text("Cargando...")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Helpers
    private var isFormValid: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespaces).isEmpty
        let passwordValid = !password.isEmpty
        let nameValid = mode == .login || !name.trimmingCharacters(in: .whitespaces).isEmpty
        return emailValid && passwordValid && nameValid
    }
    
    private func submit() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            if mode == .login {
                await authService.signIn(email: email, password: password)
            } else {
                await authService.register(email: email, password: password, name: name)
            }
        }
    }
}

// MARK: - Glass Text Field (iOS 26)
struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(isFocused ? .orange : .secondary)
                .frame(width: 24)
                .animation(.smooth(duration: 0.2), value: isFocused)
            
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(
            ZStack {
                if isFocused {
                    Color.orange.opacity(0.1)
                }
                Color.white.opacity(0.05)
            }
        )
        .background(.ultraThinMaterial, in: Capsule())
        .animation(.smooth(duration: 0.2), value: isFocused)
    }
}

// MARK: - Glass Secure Field (iOS 26)
struct GlassSecureField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    @State private var isSecure = true
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(isFocused ? .orange : .secondary)
                .frame(width: 24)
                .animation(.smooth(duration: 0.2), value: isFocused)
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .focused($isFocused)
            .autocorrectionDisabled()
            
            Button {
                isSecure.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: isSecure ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(
            ZStack {
                if isFocused {
                    Color.orange.opacity(0.1)
                }
                Color.white.opacity(0.05)
            }
        )
        .background(.ultraThinMaterial, in: Capsule())
        .animation(.smooth(duration: 0.2), value: isFocused)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}