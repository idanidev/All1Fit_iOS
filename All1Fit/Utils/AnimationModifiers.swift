import SwiftUI

// MARK: - Animation Modifiers

struct BounceOnTapModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

extension View {
    func bounceOnTap() -> some View {
        modifier(BounceOnTapModifier())
    }
    
    func all1FitPressable() -> some View {
        modifier(BounceOnTapModifier())
    }
}

// MARK: - Transitions

extension AnyTransition {
    static var heroSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}
