import SwiftUI

struct GradientCard<Content: View>: View {
    let gradient: LinearGradient?
    let height: CGFloat?
    let content: Content
    
    init(gradient: LinearGradient? = nil, height: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.gradient = gradient
        self.height = height
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Background Layer
            if let gradient = gradient {
                RoundedRectangle(cornerRadius: Layout.radiusLg, style: .continuous)
                    .fill(gradient)
                    .opacity(0.15)
            } else {
                RoundedRectangle(cornerRadius: Layout.radiusLg, style: .continuous)
                    .fill(Color.all1FitBackgroundSecondary)
            }

            // Content
            content
                .padding(Layout.md)
        }
        .frame(height: height)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.radiusLg, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.all1FitBackground.ignoresSafeArea()
        VStack {
            GradientCard(gradient: Color.Gradients.rm) {
                Text("Olympic Lifts")
                    .font(.all1FitHeaderMedium)
                    .foregroundStyle(.white)
            }
            .frame(height: 100)
            
            GradientCard {
                Text("Standard Card")
                    .foregroundStyle(.white)
            }
        }
        .padding()
    }
}
