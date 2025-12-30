import SwiftUI

// MARK: - Logo Toolbar Modifier
/// Adds the All1Fit logo to the navigation toolbar
struct LogoToolbarModifier: ViewModifier {
    let height: CGFloat
    
    init(height: CGFloat = 80) {
        self.height = height
    }
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: height)
                        .shadow(color: .white.opacity(0.5), radius: 10)
                }
            }
    }
}

// MARK: - View Extension
extension View {
    /// Adds the All1Fit logo to the navigation toolbar
    /// - Parameter height: Logo height (default: 80)
    func logoToolbar(height: CGFloat = 80) -> some View {
        modifier(LogoToolbarModifier(height: height))
    }
}
