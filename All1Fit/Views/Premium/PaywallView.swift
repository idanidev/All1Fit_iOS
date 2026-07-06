import SwiftUI

// MARK: - Paywall View (iOS 26 Premium)
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isDetailVisible = false
    
    var body: some View {
        ZStack {
            // Background
            Image("female_fitness_dark") // TODO: Replace with actual asset or generative gradient
                .resizable()
                .scaledToFill()
                .overlay(
                    LinearGradient(
                        colors: [.black, .purple.opacity(0.4), .black.opacity(0.8)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .ignoresSafeArea()
            
            // Or use a generative gradient if image fails
            LinearGradient(
                colors: [Color.all1FitBackground, Color.purple.opacity(0.2)],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding()
                
                Spacer()
                
                // Content
                VStack(spacing: Layout.xl) {
                    VStack(spacing: Layout.xs) {
                        Text("ALL1FIT PRO")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(4)
                            .foregroundStyle(.white.opacity(0.8))

                        Text("Desbloquea Tu Máximo Potencial")
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: Layout.lg) {
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Análisis Avanzado", description: "Profundiza en tu progreso con el tiempo.")
                        FeatureRow(icon: "cloud.fill", title: "Sincronización iCloud", description: "Mantén tus datos seguros y sincronizados.")
                        FeatureRow(icon: "infinity", title: "Entrenos Ilimitados", description: "Crea y guarda tantos entrenos como quieras.")
                        FeatureRow(icon: "crown.fill", title: "Contenido Exclusivo", description: "Accede a entrenos y programas premium.")
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    
                    // CTA Button
                    Button {
                        // TODO: Implement Purchase
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    } label: {
                        Text("Iniciar Prueba Gratis de 7 Días")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                            .shadow(color: .purple.opacity(0.5), radius: 15, y: 5)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }

                    Text("Se renueva automáticamente a $4.99/mes. Cancela cuando quieras.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(24)
                .offset(y: isDetailVisible ? 0 : 100)
                .opacity(isDetailVisible ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                isDetailVisible = true
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: Layout.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.bold())
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

#Preview {
    PaywallView()
}
