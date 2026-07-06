import SwiftUI

/// Vista de anatomía usando imágenes profesionales con gradientes
struct ImageAnatomyView: View {
    let muscleGroup: MuscleGroup

    var body: some View {
        GeometryReader { geometry in
            if let imageName = muscleGroup.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

extension MuscleGroup {
    var imageName: String? {
        switch self {
        case .chest:
            return "chest"
        case .back:
            return "back"
        case .shoulders:
            return "shoulders"
        case .arms:
            return "arms"
        case .abs:
            return "abs"
        case .legs:
            return "legs"
        case .none:
            return nil
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        HStack(spacing: 20) {
            VStack {
                Text("Pecho").foregroundStyle(.white).font(.caption)
                ImageAnatomyView(muscleGroup: .chest)
                    .frame(width: 80, height: 120)
            }

            VStack {
                Text("Piernas").foregroundStyle(.white).font(.caption)
                ImageAnatomyView(muscleGroup: .legs)
                    .frame(width: 80, height: 120)
            }

            VStack {
                Text("Brazos").foregroundStyle(.white).font(.caption)
                ImageAnatomyView(muscleGroup: .arms)
                    .frame(width: 80, height: 120)
            }
        }
    }
}
