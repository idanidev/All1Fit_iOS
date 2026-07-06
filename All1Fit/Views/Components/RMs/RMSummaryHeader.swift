import SwiftUI

struct RMSummaryHeader: View {
    let totalExercises: Int
    let totalRMs: Int
    let bestLift: String
    
    var body: some View {
        VStack(spacing: Layout.md) {
            // Total Exercises Card
            GradientCard(gradient: nil) {
                VStack(alignment: .leading) {
                    Text("\(totalExercises)")
                        .font(.displayHero(40))
                        .foregroundStyle(.white)
                    Text("Active Exercises")
                        .font(.all1FitSmall)
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 120)
            
            // Best Lift Highlight (Optional)
//            if !bestLift.isEmpty {
//                 GradientCard(gradient: Color.Gradients.rm) {
//                    HStack {
//                        VStack(alignment: .leading) {
//                            Text("STRONGEST LIFT")
//                                .font(.all1FitSmall)
//                                .foregroundStyle(.white.opacity(0.8))
//                            Text(bestLift)
//                                .font(.all1FitHeaderMedium)
//                                .foregroundStyle(.white)
//                        }
//                        Spacer()
//                        Image(systemName: "trophy.fill")
//                            .font(.largeTitle)
//                            .foregroundStyle(.yellow)
//                    }
//                }
//                .frame(height: 80)
//            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        RMSummaryHeader(totalExercises: 12, totalRMs: 48, bestLift: "Deadlift: 180kg")
            .padding()
    }
}
