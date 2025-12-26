import SwiftUI

// MARK: - Date Extensions
extension Date {
    var formatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: self)
    }
    
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: self)
    }
    
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Double Extensions
extension Double {
    var cleanWeight: String {
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(self))"
        } else {
            return String(format: "%.1f", self)
        }
    }
    
    var weightString: String {
        "\(cleanWeight) kg"
    }
}

// MARK: - View Extensions
extension View {
    /// Applies a glass effect with fallback for older iOS versions
    @ViewBuilder
    func adaptiveGlassEffect() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    /// Haptic feedback helpers
    func hapticLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    func hapticMedium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    func hapticSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    func hapticError() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

// MARK: - Animation Extensions
extension Animation {
    static var smoothSpring: Animation {
        .spring(duration: 0.4, bounce: 0.2)
    }
    
    static var gentleSpring: Animation {
        .spring(duration: 0.6, bounce: 0.1)
    }
}

// MARK: - Conditional Modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - iOS 26 Glass Effect Compatibility

/// Container that provides glass effect on iOS 26+ and fallback on older versions
/// This is a pass-through container - it doesn't add any styling itself
struct GlassEffectContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
    }
}

// MARK: - Glass Button Style (iOS 26 Compatible)
extension View {
    /// Applies a glass-style button background compatible with iOS 17+
    /// On iOS 26+, use native .glassEffect() instead
    @ViewBuilder
    func glassButtonStyle(tint: Color = .clear, cornerRadius: CGFloat = 12) -> some View {
        self
            .background(
                ZStack {
                    if tint != .clear {
                        tint.opacity(0.3)
                    }
                    Color.white.opacity(0.1)
                }
            )
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    /// Applies a capsule glass-style button background
    @ViewBuilder
    func glassCapsuleStyle(tint: Color = .clear) -> some View {
        self
            .background(
                ZStack {
                    if tint != .clear {
                        tint.opacity(0.3)
                    }
                    Color.white.opacity(0.1)
                }
            )
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
    
    /// Applies a circular glass-style background
    @ViewBuilder
    func glassCircleStyle(tint: Color = .clear) -> some View {
        self
            .background(
                ZStack {
                    if tint != .clear {
                        tint.opacity(0.3)
                    }
                    Color.white.opacity(0.1)
                }
            )
            .background(.ultraThinMaterial)
            .clipShape(Circle())
    }
}