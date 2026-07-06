import SwiftUI

// MARK: - Confirmación estilo All1Fit
/// Reemplaza los `confirmationDialog` del sistema por un sheet con identidad propia:
/// icono con glow, título grande, mensaje y botones de acción con gradiente.
struct All1FitConfirmation: Identifiable {
    var id: String { title }
    let title: String
    let message: String
    let icon: String
    var tint: Color = .all1FitError
    let confirmTitle: String
    var confirmIsDestructive: Bool = true
    /// Acción alternativa opcional (ej: "Continuar en segundo plano")
    var secondaryTitle: String? = nil
    var cancelTitle: String = "Cancelar"
    let onConfirm: () -> Void
    var onSecondary: (() -> Void)? = nil
}

extension View {
    /// Presenta una confirmación All1Fit ligada a un item opcional
    func all1FitConfirmation(_ item: Binding<All1FitConfirmation?>) -> some View {
        sheet(item: item) { config in
            All1FitConfirmationSheet(config: config) {
                item.wrappedValue = nil
            }
        }
    }
}

// MARK: - Sheet
struct All1FitConfirmationSheet: View {
    let config: All1FitConfirmation
    let close: () -> Void

    private var confirmGradient: [Color] {
        config.confirmIsDestructive ? [.all1FitError, .all1FitPink] : [.all1FitBlue, .all1FitCyan]
    }

    var body: some View {
        VStack(spacing: 20) {
            // Icono con glow
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [config.tint.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 44))
                    .frame(width: 88, height: 88)
                Circle()
                    .fill(config.tint.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: config.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(config.tint)
            }
            .padding(.top, 12)

            VStack(spacing: 8) {
                Text(config.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(config.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    config.onConfirm()
                    close()
                } label: {
                    Text(config.confirmTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(colors: confirmGradient, startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .shadow(color: confirmGradient[0].opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)

                if let secondaryTitle = config.secondaryTitle {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        config.onSecondary?()
                        close()
                    } label: {
                        Text(secondaryTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    close()
                } label: {
                    Text(config.cancelTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .presentationDetents([.height(config.secondaryTitle == nil ? 350 : 414)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        All1FitConfirmationSheet(config: All1FitConfirmation(
            title: "¿Eliminar tabata?",
            message: "\"Tabata 20/10\" se eliminará. Esta acción no se puede deshacer.",
            icon: "trash.fill",
            confirmTitle: "Eliminar",
            onConfirm: {}
        )) {}
    }
    .preferredColorScheme(.dark)
}
