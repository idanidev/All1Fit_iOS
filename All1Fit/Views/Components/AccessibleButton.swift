import SwiftUI

// MARK: - Accessible Action Button
/// Botón con tamaño mínimo accesible y feedback apropiado
struct AccessibleActionButton: View {
    let icon: String
    let label: String
    let hint: String?
    let action: () -> Void
    var color: Color = .accentColor
    var size: CGFloat = 44

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Haptic feedback solo para acciones importantes
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )
        }
        .accessible(
            label: label,
            hint: hint,
            traits: .isButton
        )
    }
}

// MARK: - Accessible FAB (Floating Action Button)
struct AccessibleFAB: View {
    let icon: String
    let label: String
    let action: () -> Void
    var color: Color = .accentColor

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(color.gradient)
                        .shadow(color: color.opacity(0.3), radius: 8, y: 4)
                )
        }
        .accessible(
            label: label,
            hint: "Botón de acción flotante",
            traits: .isButton
        )
    }
}

// MARK: - Accessible Card Button
struct AccessibleCardButton<Content: View>: View {
    let label: String
    let hint: String?
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(.plain)
        .accessible(
            label: label,
            hint: hint,
            traits: .isButton
        )
    }
}

// MARK: - Accessible Toggle
struct AccessibleToggle: View {
    let label: String
    let hint: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
        }
        .accessible(
            label: label,
            hint: hint,
            value: isOn ? "Activado" : "Desactivado",
            traits: .isButton
        )
    }
}

#Preview("Action Button") {
    VStack(spacing: 20) {
        AccessibleActionButton(
            icon: "plus.circle.fill",
            label: "Añadir ejercicio",
            hint: "Abre formulario para nuevo ejercicio",
            action: {}
        )

        AccessibleFAB(
            icon: "plus",
            label: "Crear nuevo",
            action: {}
        )
    }
    .padding()
}
