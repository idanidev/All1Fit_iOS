import SwiftUI

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

    /// Inversa de `convert`: valor introducido en esta unidad → kg (unidad de almacenamiento)
    func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kg: return value
        case .lbs: return value / 2.20462
        }
    }
}

// MARK: - App Theme
enum AppTheme: String, CaseIterable {
    case system, light, dark
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var displayName: String {
        switch self {
        case .system: return "Automático"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }
}
