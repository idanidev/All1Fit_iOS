import Foundation

// MARK: - Preferencias del plan

/// Prescripción de una clase de ejercicio (básico o aislamiento)
struct SetScheme {
    let sets: Int
    let reps: Int
    let restSeconds: Int
}

enum GymGoal: String, CaseIterable, Identifiable {
    case fuerza
    case hipertrofia
    case perderGrasa
    case general

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fuerza:      return "Fuerza"
        case .hipertrofia: return "Ganar músculo"
        case .perderGrasa: return "Perder grasa"
        case .general:     return "Forma física general"
        }
    }

    var icon: String {
        switch self {
        case .fuerza:      return "figure.strengthtraining.traditional"
        case .hipertrofia: return "figure.arms.open"
        case .perderGrasa: return "flame.fill"
        case .general:     return "heart.fill"
        }
    }

    // Prescripciones basadas en la evidencia 2024-2026:
    // - Volumen dosis-respuesta con retornos decrecientes (Pelland 2025): 10-20 series/músculo/semana.
    // - Cercanía al fallo: la hipertrofia mejora a RIR 0-2; la fuerza apenas depende del RIR
    //   (Robinson 2024), así que fuerza se programa a RIR 2-3 con cargas altas.
    // - Descansos: <60s penaliza hipertrofia; ≥2 min en básicos ("Give it a rest", 2024).
    // - Superseries antagonistas: mismas ganancias en ~36% menos tiempo (meta-análisis 2025)
    //   → densidad ideal para pérdida de grasa.

    /// Básicos multiarticulares
    var compoundScheme: SetScheme {
        switch self {
        case .fuerza:      return SetScheme(sets: 4, reps: 4, restSeconds: 210)
        case .hipertrofia: return SetScheme(sets: 4, reps: 8, restSeconds: 120)
        case .perderGrasa: return SetScheme(sets: 3, reps: 10, restSeconds: 90)
        case .general:     return SetScheme(sets: 3, reps: 10, restSeconds: 90)
        }
    }

    /// Aislamiento / accesorios
    var isolationScheme: SetScheme {
        switch self {
        case .fuerza:      return SetScheme(sets: 3, reps: 8, restSeconds: 120)
        case .hipertrofia: return SetScheme(sets: 3, reps: 12, restSeconds: 90)
        case .perderGrasa: return SetScheme(sets: 3, reps: 12, restSeconds: 60)
        case .general:     return SetScheme(sets: 3, reps: 12, restSeconds: 60)
        }
    }

    /// Pérdida de grasa entrena en superseries antagonistas (densidad)
    var usesSupersets: Bool { self == .perderGrasa }

    /// Nota de rutina con las pautas de ejecución basadas en evidencia
    var executionNote: String {
        switch self {
        case .fuerza:
            return "Cargas altas dejando 2-3 reps en recámara: la fuerza no exige llegar al fallo. Descansa completo entre series (3+ min en básicos) y sube peso cuando completes todas las series."
        case .hipertrofia:
            return "Termina cada serie a 0-2 reps del fallo y descansa ≥2 min en los básicos. Doble progresión: cuando completes todas las reps en todas las series, sube el peso."
        case .perderGrasa:
            return "Superseries antagonistas: alterna los ejercicios marcados SS sin descanso entre ellos (mismas ganancias en menos tiempo). Mantén las cargas para conservar músculo; el déficit calórico se hace en la dieta."
        case .general:
            return "Técnica primero. Deja ~2 reps en recámara, descansa lo indicado y progresa de forma gradual semana a semana."
        }
    }
}

enum GymExperience: String, CaseIterable, Identifiable {
    case principiante
    case intermedio
    case avanzado

    var id: String { rawValue }

    var label: String {
        switch self {
        case .principiante: return "Principiante"
        case .intermedio:   return "Intermedio"
        case .avanzado:     return "Avanzado"
        }
    }

    var detail: String {
        switch self {
        case .principiante: return "Menos de 1 año entrenando"
        case .intermedio:   return "1-3 años entrenando"
        case .avanzado:     return "Más de 3 años entrenando"
        }
    }
}

enum GymEquipmentAccess: String, CaseIterable, Identifiable {
    case gimnasioCompleto
    case mancuernas
    case pesoCorporal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gimnasioCompleto: return "Gimnasio completo"
        case .mancuernas:       return "Mancuernas en casa"
        case .pesoCorporal:     return "Solo peso corporal"
        }
    }

    var icon: String {
        switch self {
        case .gimnasioCompleto: return "building.2.fill"
        case .mancuernas:       return "dumbbell.fill"
        case .pesoCorporal:     return "figure.core.training"
        }
    }

    /// Equipamiento disponible para filtrar el catálogo
    var allowedEquipment: Set<GymEquipment> {
        switch self {
        case .gimnasioCompleto: return Set(GymEquipment.allCases)
        case .mancuernas:       return [.dumbbell, .kettlebell, .bodyweight]
        case .pesoCorporal:     return [.bodyweight]
        }
    }
}

struct GymPlanPreferences {
    var goal: GymGoal = .hipertrofia
    var experience: GymExperience = .principiante
    var daysPerWeek: Int = 3
    var equipment: GymEquipmentAccess = .gimnasioCompleto
}

// MARK: - Generador
/// Genera un programa de rutinas a partir de las preferencias del cuestionario,
/// aplicando las prescripciones de los metaanálisis 2024-2026 (ver GymGoal).
/// Determinista: mismas preferencias → mismo plan (testeable, sin aleatoriedad).
enum GymPlanGenerator {

    static let planFolder = "Plan a medida"

    /// Pares antagonistas para superseries (pérdida de grasa)
    private static let antagonistPairs: [Set<BodyPart>] = [
        [.chest, .back],
        [.biceps, .triceps],
        [.quads, .hamstrings]
    ]

    static func makePlan(from prefs: GymPlanPreferences) -> [GymRoutine] {
        templates(days: prefs.daysPerWeek, experience: prefs.experience).map { template in
            var usedNames = Set<String>()
            var exercises = template.slots.compactMap { slot -> RoutineExercise? in
                guard let exercise = pick(muscle: slot, prefs: prefs, excluding: usedNames) else { return nil }
                usedNames.insert(exercise.name)
                let scheme = scheme(for: exercise, goal: prefs.goal)
                return RoutineExercise(
                    exerciseName: exercise.name,
                    sets: scheme.sets,
                    reps: scheme.reps,
                    restSeconds: scheme.restSeconds
                )
            }
            if prefs.goal.usesSupersets {
                pairAntagonists(&exercises)
            }
            return GymRoutine(
                name: template.name,
                notes: prefs.goal.executionNote,
                folder: planFolder,
                exercises: exercises
            )
        }
    }

    // MARK: Prescripción por ejercicio

    /// Básico = multiarticular (tiene músculos secundarios). Abs y gemelos van a reps altas.
    private static func scheme(for exercise: GymExercise, goal: GymGoal) -> SetScheme {
        if exercise.primaryMuscle == .abs || exercise.primaryMuscle == .calves {
            return SetScheme(sets: 3, reps: 15, restSeconds: 45)
        }
        return exercise.secondaryMuscles.isEmpty ? goal.isolationScheme : goal.compoundScheme
    }

    /// Agrupa en superseries los ejercicios consecutivos con músculos antagonistas
    private static func pairAntagonists(_ exercises: inout [RoutineExercise]) {
        var nextGroup = 1
        var index = 0
        while index < exercises.count - 1 {
            let current = exercises[index]
            let next = exercises[index + 1]
            guard current.supersetGroup == nil, next.supersetGroup == nil,
                  let muscleA = GymExerciseCatalog.exercise(named: current.exerciseName)?.primaryMuscle,
                  let muscleB = GymExerciseCatalog.exercise(named: next.exerciseName)?.primaryMuscle,
                  antagonistPairs.contains([muscleA, muscleB]) else {
                index += 1
                continue
            }
            exercises[index].supersetGroup = nextGroup
            exercises[index + 1].supersetGroup = nextGroup
            nextGroup += 1
            index += 2
        }
    }

    // MARK: Plantillas por días

    private struct DayTemplate {
        let name: String
        let slots: [BodyPart]
    }

    /// Los slots antagonistas van consecutivos a propósito: en pérdida de grasa
    /// se convierten en superseries (pecho-espalda, cuádriceps-femoral, bíceps-tríceps).
    private static func templates(days: Int, experience: GymExperience) -> [DayTemplate] {
        switch days {
        case ...2:
            return [
                DayTemplate(name: "Full Body A", slots: [.quads, .chest, .back, .shoulders, .abs]),
                DayTemplate(name: "Full Body B", slots: [.hamstrings, .chest, .back, .biceps, .triceps])
            ]
        case 3 where experience == .principiante:
            return [
                DayTemplate(name: "Full Body A", slots: [.quads, .chest, .back, .abs]),
                DayTemplate(name: "Full Body B", slots: [.hamstrings, .shoulders, .back, .biceps]),
                DayTemplate(name: "Full Body C", slots: [.glutes, .chest, .back, .triceps, .abs])
            ]
        case 3:
            return pushPullLegs
        case 4:
            return [
                DayTemplate(name: "Torso A", slots: [.chest, .back, .shoulders, .biceps, .triceps]),
                DayTemplate(name: "Pierna A", slots: [.quads, .hamstrings, .glutes, .calves]),
                DayTemplate(name: "Torso B", slots: [.chest, .back, .shoulders, .triceps]),
                DayTemplate(name: "Pierna B", slots: [.quads, .hamstrings, .glutes, .abs])
            ]
        default:
            return pushPullLegs + [
                DayTemplate(name: "Torso", slots: [.chest, .back, .shoulders, .biceps, .triceps]),
                DayTemplate(name: "Pierna y Core", slots: [.quads, .hamstrings, .glutes, .calves, .abs])
            ]
        }
    }

    private static var pushPullLegs: [DayTemplate] {
        [
            DayTemplate(name: "Push (Empuje)", slots: [.chest, .shoulders, .chest, .triceps]),
            DayTemplate(name: "Pull (Tirón)", slots: [.back, .back, .shoulders, .biceps]),
            DayTemplate(name: "Legs (Pierna)", slots: [.quads, .hamstrings, .glutes, .calves, .abs])
        ]
    }

    // MARK: Selección de ejercicios

    /// Prioridad de equipamiento según experiencia: principiantes empiezan
    /// con máquinas y peso corporal; avanzados priorizan barra libre.
    /// (La evidencia 2025 indica que la selección concreta es flexible;
    /// lo determinante son volumen, RIR y descanso.)
    private static func equipmentPriority(for experience: GymExperience) -> [GymEquipment] {
        switch experience {
        case .principiante: return [.machine, .bodyweight, .cable, .dumbbell, .kettlebell, .barbell]
        case .intermedio:   return [.dumbbell, .barbell, .cable, .machine, .bodyweight, .kettlebell]
        case .avanzado:     return [.barbell, .dumbbell, .bodyweight, .cable, .machine, .kettlebell]
        }
    }

    private static func pick(muscle: BodyPart, prefs: GymPlanPreferences, excluding used: Set<String>) -> GymExercise? {
        let allowed = prefs.equipment.allowedEquipment
        let candidates = GymExerciseCatalog.all.filter {
            $0.primaryMuscle == muscle && allowed.contains($0.equipment) && !used.contains($0.name)
        }
        guard !candidates.isEmpty else { return nil }

        for equipment in equipmentPriority(for: prefs.experience) {
            if let match = candidates.first(where: { $0.equipment == equipment }) {
                return match
            }
        }
        return candidates.first
    }
}
