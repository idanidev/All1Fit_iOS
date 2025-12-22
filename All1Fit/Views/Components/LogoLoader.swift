import SwiftUI

// MARK: - Simple Logo Loader (Optimized)
struct LogoLoader: View {
    var body: some View {
        ProgressView()
            .scaleEffect(2.0)
            .tint(.orange)
    }
}

// MARK: - Loading Overlay View
struct LoadingOverlay: View {
    let message: String
    
    init(_ message: String = "Cargando...") {
        self.message = message
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.orange)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - Header Logo (Static - No Animation)
struct HeaderLogo: View {
    var body: some View {
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(height: 48)
    }
}

#Preview("Logo Loader") {
    ZStack {
        Color.black
        LogoLoader()
    }
}

#Preview("Loading Overlay") {
    LoadingOverlay("Guardando...")
}
