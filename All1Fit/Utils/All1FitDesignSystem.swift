import SwiftUI

// MARK: - All1Fit Design System
/// Professional Design System inspired by Nike Training Club, Hevy, and Strong
/// Dark-mode first, athlete-focused, premium feel

// MARK: - Color Palette
extension Color {
    // MARK: Primary Brand Colors
    static let all1FitOrange = Color(red: 1.0, green: 0.58, blue: 0.0) // #FF9500
    static let all1FitRed = Color(red: 1.0, green: 0.27, blue: 0.23) // #FF453A
    static let all1FitPurple = Color(red: 0.75, green: 0.35, blue: 0.95) // #BF5AF2
    static let all1FitBlue = Color(red: 0.04, green: 0.52, blue: 1.0) // #0A84FF

    // MARK: Semantic Colors
    static let all1FitSuccess = Color(red: 0.19, green: 0.82, blue: 0.35) // #30D158
    static let all1FitWarning = Color(red: 1.0, green: 0.8, blue: 0.0) // #FFD000
    static let all1FitError = Color(red: 1.0, green: 0.27, blue: 0.23) // #FF453A

    // MARK: Background Colors (Dark Mode First)
    static let all1FitBackground = Color(red: 0.0, green: 0.0, blue: 0.0) // Pure black
    static let all1FitBackgroundSecondary = Color(red: 0.11, green: 0.11, blue: 0.12) // #1C1C1E
    static let all1FitBackgroundTertiary = Color(red: 0.17, green: 0.17, blue: 0.18) // #2C2C2E

    // MARK: Gradient Presets
    static var all1FitCrossFitGradient: LinearGradient {
        LinearGradient(
            colors: [all1FitRed, Color(red: 1.0, green: 0.41, blue: 0.71)], // Red to Pink
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var all1FitRunningGradient: LinearGradient {
        LinearGradient(
            colors: [all1FitOrange, Color(red: 1.0, green: 0.8, blue: 0.0)], // Orange to Yellow
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var all1FitCompetitionGradient: LinearGradient {
        LinearGradient(
            colors: [all1FitPurple, all1FitBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Typography System
extension Font {
    // MARK: Display (Hero Numbers)
    static let all1FitDisplayLarge = Font.system(size: 64, weight: .bold, design: .rounded)
    static let all1FitDisplayMedium = Font.system(size: 48, weight: .bold, design: .rounded)
    static let all1FitDisplaySmall = Font.system(size: 36, weight: .bold, design: .rounded)

    // MARK: Headlines
    static let all1FitHeadlineLarge = Font.system(size: 28, weight: .bold, design: .rounded)
    static let all1FitHeadlineMedium = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let all1FitHeadlineSmall = Font.system(size: 18, weight: .semibold, design: .rounded)

    // MARK: Body
    static let all1FitBodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let all1FitBodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let all1FitBodySmall = Font.system(size: 13, weight: .regular, design: .default)

    // MARK: Labels
    static let all1FitLabelLarge = Font.system(size: 14, weight: .semibold, design: .default)
    static let all1FitLabelMedium = Font.system(size: 12, weight: .semibold, design: .default)
    static let all1FitLabelSmall = Font.system(size: 10, weight: .medium, design: .default)

    // MARK: Caption
    static let all1FitCaption = Font.system(size: 11, weight: .regular, design: .default)
}

// MARK: - Spacing System
enum All1FitSpacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius System
enum All1FitCornerRadius {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let round: CGFloat = 999 // Fully rounded
}

// MARK: - Shadow System
struct All1FitShadow {
    static let small: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (.black.opacity(0.1), 4, 0, 2)
    static let medium: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (.black.opacity(0.15), 8, 0, 4)
    static let large: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (.black.opacity(0.2), 16, 0, 8)

    static func colored(_ color: Color, intensity: Double = 0.3) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        return (color.opacity(intensity), 12, 0, 6)
    }
}

// MARK: - Animation System
extension Animation {
    static let all1FitSpring = Animation.spring(response: 0.4, dampingFraction: 0.7)
    static let all1FitQuick = Animation.easeInOut(duration: 0.2)
    static let all1FitSmooth = Animation.easeInOut(duration: 0.3)
    static let all1FitSlow = Animation.easeInOut(duration: 0.5)
}

// MARK: - Professional Card Style
struct All1FitProCard<Content: View>: View {
    let content: Content
    let gradient: LinearGradient?
    let cornerRadius: CGFloat
    let padding: CGFloat

    init(
        gradient: LinearGradient? = nil,
        cornerRadius: CGFloat = All1FitCornerRadius.lg,
        padding: CGFloat = All1FitSpacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.gradient = gradient
        self.cornerRadius = cornerRadius
        self.padding = padding
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    // Gradient background (if provided)
                    if let gradient = gradient {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(gradient.opacity(0.1))
                    }

                    // Glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                }
                .shadow(
                    color: All1FitShadow.medium.color,
                    radius: All1FitShadow.medium.radius,
                    x: All1FitShadow.medium.x,
                    y: All1FitShadow.medium.y
                )
            }
    }
}

// MARK: - Professional Button Style
struct All1FitPrimaryButtonStyle: ButtonStyle {
    let gradient: LinearGradient
    let isCompact: Bool

    init(gradient: LinearGradient = Color.all1FitRunningGradient, isCompact: Bool = false) {
        self.gradient = gradient
        self.isCompact = isCompact
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isCompact ? .all1FitLabelLarge : .all1FitHeadlineSmall)
            .foregroundStyle(.white)
            .padding(.horizontal, isCompact ? All1FitSpacing.md : All1FitSpacing.lg)
            .padding(.vertical, isCompact ? All1FitSpacing.sm : All1FitSpacing.md)
            .background {
                Capsule()
                    .fill(gradient)
                    .shadow(
                        color: All1FitShadow.colored(.orange).color,
                        radius: All1FitShadow.colored(.orange).radius,
                        x: All1FitShadow.colored(.orange).x,
                        y: All1FitShadow.colored(.orange).y
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.all1FitQuick, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
    }
}

// MARK: - Professional Badge
struct All1FitBadge: View {
    let text: String
    let color: Color
    let style: BadgeStyle

    enum BadgeStyle {
        case solid
        case outlined
        case gradient(LinearGradient)
    }

    init(_ text: String, color: Color = .all1FitOrange, style: BadgeStyle = .solid) {
        self.text = text
        self.color = color
        self.style = style
    }

    var body: some View {
        Text(text)
            .font(.all1FitLabelSmall)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, All1FitSpacing.xs)
            .padding(.vertical, All1FitSpacing.xxs)
            .background {
                Capsule()
                    .fill(backgroundColor)
                    .overlay {
                        if case .outlined = style {
                            Capsule()
                                .strokeBorder(color, lineWidth: 1.5)
                        }
                    }
            }
    }

    private var foregroundColor: Color {
        switch style {
        case .solid, .gradient:
            return .white
        case .outlined:
            return color
        }
    }

    private var backgroundColor: AnyShapeStyle {
        switch style {
        case .solid:
            return AnyShapeStyle(color)
        case .outlined:
            return AnyShapeStyle(color.opacity(0.1))
        case .gradient(let gradient):
            return AnyShapeStyle(gradient)
        }
    }
}

// MARK: - Professional Icon Container
struct All1FitIconContainer: View {
    let icon: String
    let size: CGFloat
    let gradient: LinearGradient

    init(icon: String, size: CGFloat = 56, gradient: LinearGradient = Color.all1FitRunningGradient) {
        self.icon = icon
        self.size = size
        self.gradient = gradient
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(gradient.opacity(0.15))
                .frame(width: size, height: size)

            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(gradient)
        }
    }
}

// MARK: - Professional Stat Display
struct All1FitStatDisplay: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: All1FitSpacing.xxs) {
            Text(value)
                .font(.all1FitDisplaySmall)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(label)
                .font(.all1FitCaption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply professional card style
    func all1FitCard(gradient: LinearGradient? = nil) -> some View {
        All1FitProCard(gradient: gradient) {
            self
        }
    }

    /// Apply professional haptic feedback
    func all1FitHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded {
                UIImpactFeedbackGenerator(style: style).impactOccurred()
            }
        )
    }

    /// Apply professional press animation
    func all1FitPressable(scale: CGFloat = 0.97) -> some View {
        modifier(All1FitPressableModifier(scale: scale))
    }
}

// MARK: - Pressable Modifier
struct All1FitPressableModifier: ViewModifier {
    @State private var isPressed = false
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.all1FitQuick, value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity) {
                // Never completes
            } onPressingChanged: { pressing in
                isPressed = pressing
                if pressing {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}
