import Foundation

// MARK: - Weight Unit
enum WeightUnit: String, CaseIterable {
    case kg, lbs
    
    var displayName: String {
        switch self {
        case .kg: return "Kilogramos (kg)"
        case .lbs: return "Libras (lbs)"
        }
    }
    
    var symbol: String {
        rawValue
    }
    
    func convert(_ kg: Double) -> Double {
        switch self {
        case .kg: return kg
        case .lbs: return kg * 2.20462
        }
    }
}