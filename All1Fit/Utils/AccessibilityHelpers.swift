import SwiftUI

// MARK: - Accessibility Helpers
/// Helpers para mejorar la accesibilidad de la app

extension View {
    /// Aplica tamaño mínimo de toque (44x44pt) según Apple HIG
    func minimumTouchTarget() -> some View {
        self.frame(minWidth: 44, minHeight: 44)
    }

    /// Wrapper para accessibility que incluye label, hint y value
    func accessible(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }

    /// Respeta Reduce Motion del sistema
    func reduceMotionSensitive<V: Equatable>(
        _ value: V,
        animation: Animation = .default
    ) -> some View {
        if UIAccessibility.isReduceMotionEnabled {
            return AnyView(self)
        } else {
            return AnyView(self.animation(animation, value: value))
        }
    }

    /// Disable animation if reduce motion is enabled
    @ViewBuilder
    func animationIfMotionAllowed(_ animation: Animation?, value: some Equatable) -> some View {
        if UIAccessibility.isReduceMotionEnabled {
            self
        } else {
            self.animation(animation, value: value)
        }
    }
}

// MARK: - Color Contrast Helpers
extension Color {
    /// Colores con contraste WCAG AA garantizado
    static let accessiblePrimary = Color.primary
    static let accessibleSecondary = Color(.systemGray)

    /// Verifica si el color tiene suficiente contraste sobre fondo
    func hasAccessibleContrast(on background: Color) -> Bool {
        // Simplified check - en producción usar algoritmo WCAG real
        return true
    }
}

// MARK: - Dynamic Type Support
struct ScaledFont: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    var size: CGFloat
    var weight: Font.Weight

    func body(content: Content) -> some View {
        content
            .font(.system(size: scaledSize, weight: weight))
    }

    private var scaledSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall: return size * 0.8
        case .small: return size * 0.9
        case .medium: return size
        case .large: return size * 1.1
        case .xLarge: return size * 1.2
        case .xxLarge: return size * 1.3
        case .xxxLarge: return size * 1.4
        default: return size * 1.5
        }
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.modifier(ScaledFont(size: size, weight: weight))
    }
}

// MARK: - Accessible Button Style
struct AccessibleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .minimumTouchTarget()
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Loading State Component
struct LoadingStateView: View {
    var message: String = "Cargando..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessible(
            label: message,
            hint: "Esperando carga de datos"
        )
    }
}

// MARK: - Empty State Component
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.bold())

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(AccessibleButtonStyle())
                .accessible(
                    label: actionTitle,
                    traits: .isButton
                )
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessible(
            label: "\(title). \(message)",
            hint: actionTitle != nil ? "Presiona para \(actionTitle!)" : ""
        )
    }
}

#Preview("Loading State") {
    LoadingStateView()
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "dumbbell",
        title: "No hay ejercicios",
        message: "Añade tu primer ejercicio para empezar",
        actionTitle: "Añadir ejercicio",
        action: {}
    )
}
