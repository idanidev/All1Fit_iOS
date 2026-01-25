import SwiftUI

// MARK: - Modern Design System (Train/Motra inspired)
/// Fluid animations, glassmorphism, and modern iOS 26 design patterns

// MARK: - Glass Card Modifier
struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let opacity: Double

    init(cornerRadius: CGFloat = 20, opacity: Double = 0.7) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(opacity)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    .shadow(color: .black.opacity(0.05), radius: 20, y: 10)
            }
    }
}

// MARK: - Gradient Glass Card
struct GradientGlassCardModifier: ViewModifier {
    let colors: [Color]
    let cornerRadius: CGFloat

    init(colors: [Color] = [.orange, .red], cornerRadius: CGFloat = 20) {
        self.colors = colors
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Gradient background
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: colors.map { $0.opacity(0.15) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                }
                .shadow(color: colors.first?.opacity(0.2) ?? .clear, radius: 15, y: 8)
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            }
    }
}

// MARK: - Floating Card Modifier
struct FloatingCardModifier: ViewModifier {
    @State private var isPressed = false
    let haptic: Bool

    init(haptic: Bool = true) {
        self.haptic = haptic
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
                // Do nothing
            } onPressingChanged: { pressing in
                isPressed = pressing
                if pressing && haptic {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let gradient: Gradient

    init(gradient: Gradient = Gradient(colors: [.clear, .white.opacity(0.3), .clear])) {
        self.gradient = gradient
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        gradient: gradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: phase * geo.size.width * 2 - geo.size.width)
                    .blur(radius: 3)
                    .blendMode(.screen)
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Bounce Button Style
struct BounceButtonStyle: ButtonStyle {
    let scale: CGFloat
    let haptic: Bool

    init(scale: CGFloat = 0.95, haptic: Bool = true) {
        self.scale = scale
        self.haptic = haptic
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && haptic {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply glass card effect
    func glassCard(cornerRadius: CGFloat = 20, opacity: Double = 0.7) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, opacity: opacity))
    }

    /// Apply gradient glass card effect
    func gradientGlassCard(colors: [Color] = [.orange, .red], cornerRadius: CGFloat = 20) -> some View {
        modifier(GradientGlassCardModifier(colors: colors, cornerRadius: cornerRadius))
    }

    /// Apply floating card effect with press animation
    func floatingCard(haptic: Bool = true) -> some View {
        modifier(FloatingCardModifier(haptic: haptic))
    }

    /// Apply shimmer animation
    func shimmer(gradient: Gradient = Gradient(colors: [.clear, .white.opacity(0.3), .clear])) -> some View {
        modifier(ShimmerModifier(gradient: gradient))
    }


}

// MARK: - Modern Card Component
struct ModernCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    let style: CardStyle

    enum CardStyle {
        case glass
        case gradientGlass(colors: [Color])
        case solid(color: Color)
    }

    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 20,
        style: CardStyle = .glass,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.style = style
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                switch style {
                case .glass:
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)

                case .gradientGlass(let colors):
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: colors.map { $0.opacity(0.15) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                            .opacity(0.6)
                    }
                    .shadow(color: colors.first?.opacity(0.2) ?? .clear, radius: 15, y: 8)

                case .solid(let color):
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(color)
                        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                }
            }
    }
}

// MARK: - Fluid Tab Bar Item
struct FluidTabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 36)
                        .transition(.scale.combined(with: .opacity))
                }

                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? color : .secondary)
                    .symbolEffect(.bounce, value: isSelected)
            }

            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? color : .secondary)
        }
        .animation(.smoothSpring, value: isSelected)
    }
}

// MARK: - Progress Ring
struct ModernProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let colors: [Color]

    init(progress: Double, lineWidth: CGFloat = 8, colors: [Color] = [.orange, .red]) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.colors = colors
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)

            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: colors,
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.smoothSpring, value: progress)
        }
    }
}

// MARK: - Gradient Text
struct GradientText: View {
    let text: String
    let font: Font
    let colors: [Color]

    init(_ text: String, font: Font = .title.bold(), colors: [Color] = [.orange, .red]) {
        self.text = text
        self.font = font
        self.colors = colors
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}
