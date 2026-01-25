import SwiftUI

// MARK: - Filter Chip
struct FilterChip: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let systemImage: String?
    
    init(label: String, value: String, systemImage: String? = nil) {
        self.label = label
        self.value = value
        self.systemImage = systemImage
    }
}

// MARK: - Filter Chips View
struct FilterChipsView: View {
    let chips: [FilterChip]
    let accentColor: Color
    let onRemove: (FilterChip) -> Void
    
    var body: some View {
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips) { chip in
                        ChipView(chip: chip, accentColor: accentColor) {
                            withAnimation(.bouncy) {
                                onRemove(chip)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                        .transition(.scaleAndFade)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Individual Chip View
private struct ChipView: View {
    let chip: FilterChip
    let accentColor: Color
    let onRemove: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 6) {
            if let systemImage = chip.systemImage {
                Image(systemName: systemImage)
                    .font(.caption2)
            }
            
            Text(chip.label)
                .font(.caption)
                .fontWeight(.medium)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(accentColor.opacity(0.15))
                .overlay(
                    Capsule()
                        .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
        .foregroundStyle(accentColor)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.smoothSpring, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Filter Summary Badge
struct FilterSummaryBadge: View {
    let activeFiltersCount: Int
    let accentColor: Color
    let onClear: () -> Void
    
    var body: some View {
        if activeFiltersCount > 0 {
            Button {
                withAnimation(.bouncy) {
                    onClear()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.body)
                    
                    Text("\\(activeFiltersCount) filtro\\(activeFiltersCount > 1 ? \"s\" : \"\")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(accentColor)
                )
                .foregroundStyle(.white)
                .shadow(color: accentColor.opacity(0.4), radius: 8, y: 4)
            }
            .transition(.scaleAndFade)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        FilterChipsView(
            chips: [
                FilterChip(label: "Intermedio", value: "intermediate", systemImage: "star.leadinghalf.filled"),
                FilterChip(label: "< 20 min", value: "20", systemImage: "clock"),
                FilterChip(label: "For Time", value: "fortime", systemImage: "stopwatch")
            ],
            accentColor: .orange
        ) { chip in
            print("Removed: \\(chip.label)")
        }
        
        FilterSummaryBadge(
            activeFiltersCount: 3,
            accentColor: .orange
        ) {
            print("Clear all filters")
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
