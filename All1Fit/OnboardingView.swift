import SwiftUI

// MARK: - Onboarding View (iOS 26 Liquid Glass)
struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    @Namespace private var animation
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "Logo", // Will use Image("Logo") instead of system icon
            title: "Bienvenido a All1Fit",
            description: "Tu app para trackear RMs, workouts y mucho más",
            gradient: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
            useLogo: true
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Visualiza tu Progreso",
            description: "Gráficos interactivos que muestran tu evolución en cada ejercicio",
            gradient: [Color(hex: "7B2FF7"), Color(hex: "F107A3")]
        ),
        OnboardingPage(
            icon: "percent",
            title: "Calcula Porcentajes",
            description: "Tablas automáticas de porcentajes para planificar tus entrenamientos",
            gradient: [Color(hex: "00C9FF"), Color(hex: "92FE9D")]
        )
    ]
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            VStack(spacing: 0) {
                // Pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.smooth, value: currentPage)
                
                // Bottom controls
                bottomControls
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
            }
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: "0a0a0f"),
                Color(hex: "1a1a2e"),
                pages[currentPage].gradient[0].opacity(0.3),
                Color(hex: "16213e"),
                Color(hex: "0a0a0f")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.5), value: currentPage)
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 24) {
            // Page indicators
            HStack(spacing: 12) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Color.orange : Color.white.opacity(0.3))
                        .frame(width: currentPage == index ? 12 : 8, height: currentPage == index ? 12 : 8)
                        .animation(.spring(duration: 0.3), value: currentPage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            
            // Action buttons
            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button {
                        withAnimation(.spring(duration: 0.4)) {
                            currentPage -= 1
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                
                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        if currentPage < pages.count - 1 {
                            currentPage += 1
                        } else {
                            onComplete()
                        }
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    HStack(spacing: 8) {
                        Text(currentPage < pages.count - 1 ? "Siguiente" : "Empezar")
                            .font(.headline)
                        Image(systemName: currentPage < pages.count - 1 ? "chevron.right" : "arrow.right")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                }
            }
            
            // Skip button
            if currentPage < pages.count - 1 {
                Button("Saltar") {
                    withAnimation(.smooth) {
                        onComplete()
                    }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let gradient: [Color]
    var useLogo: Bool = false
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon with glass effect
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.gradient[0].opacity(0.5), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)
                    .scaleEffect(isAnimating ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                
                // Icon or Logo
                if page.useLogo {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 340, height: 340)
                        .scaleEffect(isAnimating ? 1.0 : 0.95)
                        .animation(.spring(duration: 0.8).delay(0.2), value: isAnimating)
                } else {
                    Image(systemName: page.icon)
                        .font(.system(size: 70, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(colors: page.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 140, height: 140)
                        .background(.ultraThinMaterial, in: Circle())
                        .scaleEffect(isAnimating ? 1.0 : 0.95)
                        .animation(.spring(duration: 0.8).delay(0.2), value: isAnimating)
                }
            }
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}