import SwiftUI

// MARK: - Premium Onboarding View
struct PremiumOnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    @State private var isLogoAnimating = false
    @State private var showContent = false
    @Namespace private var animation
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isIPad: Bool { horizontalSizeClass == .regular }
    
    private let pages: [PremiumOnboardingPage] = [
        PremiumOnboardingPage(
            title: "All1Fit",
            subtitle: "Tu compañero de entreno definitivo",
            description: "Trackea RMs, Tabatas y workouts. Todo en un solo lugar.",
            gradient: [Color(hex: "FF6B35"), Color(hex: "F7931E")],
            systemIcon: nil,
            showLogo: true
        ),
        PremiumOnboardingPage(
            title: "Trackea tus RMs",
            subtitle: "Récords personales",
            description: "Guarda y visualiza tu progreso en cada ejercicio. Tablas de porcentajes automáticas para planificar cargas.",
            gradient: [Color(hex: "7B2FF7"), Color(hex: "F107A3")],
            systemIcon: "chart.bar.fill"
        ),
        PremiumOnboardingPage(
            title: "Tabatas HIIT",
            subtitle: "Temporizadores inteligentes",
            description: "13 Tabatas predefinidos + crea los tuyos. Live Activities en Dynamic Island.",
            gradient: [Color(hex: "00C9FF"), Color(hex:  "92FE9D")],
            systemIcon: "flame.fill"
        ),
        PremiumOnboardingPage(
            title: "Sincroniza con Apple Watch",
            subtitle: "Entrena desde tu muñeca",
            description: "HealthKit integrado. Frecuencia cardíaca en tiempo real. Complicaciones personalizadas.",
            gradient: [Color(hex: "FF0844"), Color(hex: "FFB199")],
            systemIcon: "applewatch"
        )
    ]
    
    var body: some View {
        ZStack {
            // Animated background
            AnimatedMeshGradient(colors: currentPageColors)
                .ignoresSafeArea()

            if isIPad {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
    }

    // MARK: - iPhone Layout
    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    PremiumPageView(page: pages[index], isActive: currentPage == index, isIPad: false)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            bottomControls(maxButtonWidth: .infinity, horizontalPadding: 32)
                .padding(.bottom, 50)
        }
    }

    // MARK: - iPad Layout
    private var iPadLayout: some View {
        HStack(spacing: 0) {
            // Left: icon area
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    PremiumPageView(page: pages[index], isActive: currentPage == index, isIPad: true)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity)

            // Right: text + controls
            VStack(alignment: .leading, spacing: 32) {
                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    Text(pages[currentPage].title)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .animation(.spring(response: 0.4), value: currentPage)

                    Text(pages[currentPage].subtitle)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .animation(.spring(response: 0.4), value: currentPage)

                    Text(pages[currentPage].description)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineSpacing(4)
                        .animation(.spring(response: 0.4), value: currentPage)
                }

                Spacer()

                bottomControls(maxButtonWidth: 360, horizontalPadding: 0)

                Spacer()
            }
            .padding(.horizontal, 48)
            .frame(maxWidth: 480)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Shared bottom controls
    @ViewBuilder
    private func bottomControls(maxButtonWidth: CGFloat, horizontalPadding: CGFloat) -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(currentPage == index ? .white : .white.opacity(0.3))
                        .frame(width: currentPage == index ? 32 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    if currentPage < pages.count - 1 {
                        currentPage += 1
                    } else {
                        onComplete()
                    }
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 12) {
                    Text(currentPage < pages.count - 1 ? "Continuar" : "¡Empezar!")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: maxButtonWidth == .infinity ? .infinity : maxButtonWidth)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white)
                        .shadow(color: .white.opacity(0.3), radius: 20, y: 10)
                )
            }
            .padding(.horizontal, horizontalPadding)

            if currentPage < pages.count - 1 {
                Button("Saltar") {
                    withAnimation(.smooth) { onComplete() }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
    
    private var currentPageColors: [Color] {
        pages[currentPage].gradient + [.black.opacity(0.8)]
    }
}

// MARK: - Premium Page Model
struct PremiumOnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let gradient: [Color]
    let systemIcon: String?
    var showLogo: Bool = false
}

// MARK: - Premium Page View
struct PremiumPageView: View {
    let page: PremiumOnboardingPage
    let isActive: Bool
    var isIPad: Bool = false

    @State private var animationPhase: AnimationPhase = .idle

    enum AnimationPhase {
        case idle, appearing, active
    }

    private var iconSize: CGFloat { isIPad ? 160 : 120 }
    private var symbolSize: CGFloat { isIPad ? 80 : 60 }
    private var glowSize: CGFloat { isIPad ? 320 : 240 }
    private var logoSize: CGFloat { isIPad ? 260 : 200 }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon/Logo Area
            ZStack {
                // Pulsing glow
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [page.gradient[0].opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: glowSize / 2
                            )
                        )
                        .frame(width: glowSize, height: glowSize)
                        .scaleEffect(animationPhase == .active ? 1.2 : 0.8)
                        .opacity(animationPhase == .active ? 0.6 : 0)
                        .animation(
                            .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                            value: animationPhase
                        )
                }

                // Icon content
                if page.showLogo {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: logoSize, height: logoSize)
                        .shadow(color: .white.opacity(0.5), radius: 30)
                        .scaleEffect(animationPhase == .active ? 1.0 : 0.8)
                        .opacity(animationPhase == .active ? 1.0 : 0)
                } else if let icon = page.systemIcon {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: iconSize, height: iconSize)

                        Image(systemName: icon)
                            .font(.system(size: symbolSize, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: page.gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .scaleEffect(animationPhase == .active ? 1.0 : 0.8)
                    .opacity(animationPhase == .active ? 1.0 : 0)
                    .rotation3DEffect(
                        .degrees(animationPhase == .active ? 0 : -15),
                        axis: (x: 1, y: 1, z: 0)
                    )
                }
            }
            .frame(height: isIPad ? 360 : 280)
            .offset(y: animationPhase == .active ? 0 : 30)

            // Text content — only shown in iPhone layout (iPad shows text on right panel)
            if !isIPad {
                Spacer().frame(height: 60)

                VStack(spacing: 16) {
                    Text(page.title)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .multilineTextAlignment(.center)
                        .offset(y: animationPhase == .active ? 0 : 20)
                        .opacity(animationPhase == .active ? 1 : 0)

                    Text(page.subtitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .offset(y: animationPhase == .active ? 0 : 20)
                        .opacity(animationPhase == .active ? 1 : 0)

                    Text(page.description)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                        .offset(y: animationPhase == .active ? 0 : 20)
                        .opacity(animationPhase == .active ? 1 : 0)
                }
            }

            Spacer()
            if !isIPad { Spacer() }
        }
        .onChange(of: isActive) { _, active in
            if active {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    animationPhase = .appearing
                }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                    animationPhase = .active
                }
            } else {
                animationPhase = .idle
            }
        }
        .onAppear {
            if isActive {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    animationPhase = .active
                }
            }
        }
    }
}

// MARK: - Animated Mesh Gradient Background
struct AnimatedMeshGradient: View {
    let colors: [Color]
    
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base dark background
            Color.black
            
            // Animated gradient layers
            ForEach(0..<3, id: \.self) { index in
                LinearGradient(
                    colors: colors,
                    startPoint: UnitPoint(x: 0.5 + animationOffset * 0.3, y: 0),
                    endPoint: UnitPoint(x: 0.5 - animationOffset * 0.3, y: 1)
                )
                .opacity(0.6 - Double(index) * 0.2)
                .blur(radius: 30 + CGFloat(index) * 20)
                .hueRotation(.degrees(animationOffset * 10 * Double(index + 1)))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: true)) {
                animationOffset = 1.0
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    PremiumOnboardingView(onComplete: {
        print("Onboarding completed!")
    })
}
