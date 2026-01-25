import SwiftUI

// MARK: - Animation Extensions
extension Animation {
    /// Smooth spring animation for UI transitions
    static var smoothSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)
    }
    
    /// Bouncy spring for playful interactions
    static var bouncy: Animation {
        .spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
    }
    
    /// Gentle spring for subtle animations
    static var gentle: Animation {
        .spring(response: 0.3, dampingFraction: 0.9, blendDuration: 0)
    }
}

// MARK: - Transition Extensions
extension AnyTransition {
    /// Scale and fade transition
    static var scaleAndFade: AnyTransition {
        .scale(scale: 0.8).combined(with: .opacity)
    }
    
    /// Slide from bottom with fade
    static var slideFromBottom: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
    
    /// Slide from top with fade
    static var slideFromTop: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
}

// MARK: - View Extensions for Animations
extension View {
    /// Adds a subtle scale effect on tap
    func scaleOnTap() -> some View {
        modifier(ScaleOnTapModifier())
    }
    
    /// Adds a shimmer loading effect
    func shimmer(isLoading: Bool) -> some View {
        modifier(ShimmerModifier(isLoading: isLoading))
    }
}

// MARK: - Scale on Tap Modifier
private struct ScaleOnTapModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.smoothSpring, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

// MARK: - Shimmer Modifier
private struct ShimmerModifier: ViewModifier {
    let isLoading: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if isLoading {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                .white.opacity(0.3),
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width)
                        .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                        .mask(content)
                    }
                }
            )
            .onAppear {
                if isLoading {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
            }
    }
}

// MARK: - Counter Animation Helper
extension View {
    /// Animates a numeric value with rolling effect
    func counterAnimation<Value: BinaryFloatingPoint>(value: Value) -> some View {
        self.contentTransition(.numericText(value: Double(value)))
    }
}

// MARK: - Skeleton Loading Views
struct SkeletonView: View {
    let cornerRadius: CGFloat
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(uiColor: .systemGray5),
                        Color(uiColor: .systemGray6),
                        Color(uiColor: .systemGray5)
                    ]),
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

struct SkeletonText: View {
    let width: CGFloat
    let height: CGFloat
    
    init(width: CGFloat = 100, height: CGFloat = 12) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        SkeletonView(cornerRadius: height / 2)
            .frame(width: width, height: height)
    }
}

// MARK: - Bounce Animation Helper
extension View {
    func bounceOnAppear() -> some View {
        modifier(BounceOnAppearModifier())
    }
}

private struct BounceOnAppearModifier: ViewModifier {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.bouncy) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
    }
}
