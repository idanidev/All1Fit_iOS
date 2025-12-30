import SwiftUI

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Política de Privacidad")
                            .font(.largeTitle.bold())
                        Text("Última actualización: Diciembre 2024")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    // Sections
                    policySection(
                        title: "1. Información que Recopilamos",
                        content: """
                        All1Fit recopila la siguiente información para proporcionar y mejorar nuestros servicios:
                        
                        • **Datos de cuenta**: Email, nombre y foto de perfil (opcional) cuando te registras con Apple o Google.
                        • **Datos de entrenamientos**: Tus repeticiones máximas (RMs), resultados de workouts y entrenamientos personalizados.
                        • **Datos técnicos**: Información del dispositivo y uso de la app para mejorar el rendimiento.
                        """
                    )
                    
                    policySection(
                        title: "2. Cómo Usamos tu Información",
                        content: """
                        Utilizamos tu información para:
                        
                        • Crear y gestionar tu cuenta de usuario.
                        • Sincronizar tus datos entre dispositivos.
                        • Mostrarte tu historial de entrenamientos y progreso.
                        • Mejorar la experiencia de la app.
                        
                        No vendemos ni compartimos tu información personal con terceros para fines publicitarios.
                        """
                    )
                    
                    policySection(
                        title: "3. Almacenamiento de Datos",
                        content: """
                        Tus datos se almacenan de forma segura en Firebase (Google Cloud Platform), cumpliendo con los estándares de seguridad de la industria.
                        
                        Los datos se mantienen mientras tu cuenta esté activa. Puedes solicitar la eliminación de tu cuenta y datos en cualquier momento.
                        """
                    )
                    
                    policySection(
                        title: "4. Servicios de Terceros",
                        content: """
                        Utilizamos los siguientes servicios:
                        
                        • **Firebase Authentication**: Para gestionar el inicio de sesión.
                        • **Firebase Firestore**: Para almacenar tus datos de entrenamientos.
                        • **Sign in with Apple / Google**: Para autenticación segura.
                        
                        Estos servicios tienen sus propias políticas de privacidad.
                        """
                    )
                    
                    policySection(
                        title: "5. Tus Derechos",
                        content: """
                        Tienes derecho a:
                        
                        • Acceder a tus datos personales.
                        • Corregir información inexacta.
                        • Solicitar la eliminación de tu cuenta y datos.
                        • Exportar tus datos.
                        
                        Para ejercer estos derechos, contáctanos por email.
                        """
                    )
                    
                    policySection(
                        title: "6. Contacto",
                        content: """
                        Si tienes preguntas sobre esta política de privacidad, puedes contactarnos en:
                        
                        📧 idanideveloper@gmail.com
                        """
                    )
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Policy Section
    private func policySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(LocalizedStringKey(content))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
