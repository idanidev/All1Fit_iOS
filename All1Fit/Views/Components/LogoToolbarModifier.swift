import SwiftUI

// MARK: - Logo Toolbar Modifier
/// Adds the All1Fit logo to the navigation toolbar
struct LogoToolbarModifier: ViewModifier {
    let height: CGFloat
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    init(height: CGFloat = 50) {
        self.height = height
    }

    // Adjust height based on Dynamic Type
    private var adjustedHeight: CGFloat {
        let baseHeight = height
        switch dynamicTypeSize {
        case .xxxLarge, .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return baseHeight * 0.7 // Reduce size for large text
        default:
            return baseHeight
        }
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: adjustedHeight)
                        .shadow(color: .white.opacity(0.3), radius: 6)
                        .accessibilityLabel("All1Fit")
                        .accessibilityAddTraits(.isImage)
                        .accessibilityHidden(true) // Logo is decorative
                }
            }
    }
}

// MARK: - View Extension
extension View {
    /// Adds the All1Fit logo to the navigation toolbar
    /// - Parameter height: Logo height (default: 50pt, reduced from 90pt)
    func logoToolbar(height: CGFloat = 50) -> some View {
        modifier(LogoToolbarModifier(height: height))
    }
}
