import SwiftUI

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

// MARK: - Login View (Simplified for Performance)
struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var showingError = false
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Logo
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260)
                
                Text(mode.title)
                    .font(.title3)
                    .foregroundColor(.gray)
                
                // Form
                VStack(spacing: 16) {
                    if mode == .register {
                        TextField("Nombre", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                    }
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    
                    SecureField("Contraseña", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(mode == .register ? .newPassword : .password)
                    
                    // Submit Button
                    Button {
                        Task {
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
                            .frame(height: 50)
                            .background(Color.orange)
                            .cornerRadius(10)
                    }
                    .disabled(email.isEmpty || password.isEmpty)
                    .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                }
                .padding(.horizontal, 32)
                
                // Switch mode
                HStack {
                    Text(mode == .login ? "¿No tienes cuenta?" : "¿Ya tienes cuenta?")
                        .foregroundColor(.gray)
                    Button(mode == .login ? "Regístrate" : "Inicia sesión") {
                        mode = mode == .login ? .register : .login
                        password = ""
                    }
                    .foregroundColor(.orange)
                }
                .font(.subheadline)
                
                Spacer()
            }
            
            // Loading
            if authService.isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.orange)
                    .scaleEffect(2)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { authService.errorMessage = nil }
        } message: {
            Text(authService.errorMessage ?? "")
        }
        .onChange(of: authService.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}
