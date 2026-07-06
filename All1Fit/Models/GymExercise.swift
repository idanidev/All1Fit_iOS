import SwiftUI

// MARK: - Gym Equipment
enum GymEquipment: String, Codable, CaseIterable, Identifiable {
    case barbell = "Barra"
    case dumbbell = "Mancuernas"
    case machine = "Máquina"
    case cable = "Polea"
    case bodyweight = "Corporal"
    case kettlebell = "Kettlebell"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .barbell:    return "figure.strengthtraining.traditional"
        case .dumbbell:   return "dumbbell.fill"
        case .machine:    return "gearshape.2.fill"
        case .cable:      return "cable.connector"
        case .bodyweight: return "figure.core.training"
        case .kettlebell: return "scalemass.fill"
        }
    }
}

// MARK: - Gym Exercise (catálogo)
struct GymExercise: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let primaryMuscle: BodyPart
    let secondaryMuscles: [BodyPart]
    let equipment: GymEquipment
    let instructions: [String]
    var isCustom: Bool = false

    init(name: String, primaryMuscle: BodyPart, secondaryMuscles: [BodyPart], equipment: GymEquipment, instructions: [String], isCustom: Bool = false) {
        self.name = name
        self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.instructions = instructions
        self.isCustom = isCustom
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        primaryMuscle = (try? c.decode(BodyPart.self, forKey: .primaryMuscle)) ?? .none
        secondaryMuscles = try c.decodeIfPresent([BodyPart].self, forKey: .secondaryMuscles) ?? []
        equipment = (try? c.decode(GymEquipment.self, forKey: .equipment)) ?? .machine
        instructions = try c.decodeIfPresent([String].self, forKey: .instructions) ?? []
        isCustom = try c.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
    }

    /// Asset de MuscleImages para el músculo primario
    var muscleImageName: String? { primaryMuscle.muscleImageName }

    /// Búsqueda sin tildes ni mayúsculas
    func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let normalized = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let q = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return normalized.contains(q)
    }
}

extension BodyPart {
    /// Asset en Assets.xcassets/MuscleImages
    var muscleImageName: String? {
        switch self {
        case .chest: return "chest"
        case .back: return "back"
        case .shoulders: return "shoulders"
        case .biceps, .triceps: return "arms"
        case .abs: return "abs"
        case .quads, .hamstrings, .glutes, .calves: return "legs"
        case .none: return nil
        }
    }

    var icon: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.climbing"
        case .shoulders: return "figure.wave"
        case .biceps, .triceps: return "figure.strengthtraining.functional"
        case .abs: return "figure.core.training"
        case .quads, .hamstrings, .glutes, .calves: return "figure.walk"
        case .none: return "figure.mixed.cardio"
        }
    }
}

// MARK: - Catálogo
enum GymExerciseCatalog {

    static func exercise(named name: String) -> GymExercise? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    static let all: [GymExercise] = pecho + espalda + hombros + biceps + triceps + piernas + gluteos + abs

    // MARK: Pecho
    static let pecho: [GymExercise] = [
        GymExercise(name: "Press Banca", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .barbell,
                    instructions: ["Túmbate con los pies firmes en el suelo y agarra la barra algo más ancho que los hombros.", "Baja la barra controlada hasta rozar el pecho.", "Empuja explosivo hasta extender los brazos sin bloquear codos."]),
        GymExercise(name: "Press Banca Inclinado", primaryMuscle: .chest, secondaryMuscles: [.shoulders, .triceps], equipment: .barbell,
                    instructions: ["Ajusta el banco a 30-45º.", "Baja la barra a la parte alta del pecho.", "Empuja manteniendo escápulas retraídas."]),
        GymExercise(name: "Press Mancuernas Plano", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .dumbbell,
                    instructions: ["Túmbate con una mancuerna en cada mano a la altura del pecho.", "Empuja hacia arriba juntando ligeramente las mancuernas.", "Baja controlado abriendo los codos a 45º."]),
        GymExercise(name: "Press Mancuernas Inclinado", primaryMuscle: .chest, secondaryMuscles: [.shoulders, .triceps], equipment: .dumbbell,
                    instructions: ["Banco a 30º, mancuernas a la altura del pecho superior.", "Empuja hacia arriba sin chocar las mancuernas.", "Baja en 2-3 segundos."]),
        GymExercise(name: "Aperturas con Mancuernas", primaryMuscle: .chest, secondaryMuscles: [.shoulders], equipment: .dumbbell,
                    instructions: ["Brazos casi extendidos sobre el pecho, ligera flexión de codo.", "Abre los brazos en arco hasta sentir estiramiento.", "Cierra el arco apretando el pecho."]),
        GymExercise(name: "Cruces en Polea", primaryMuscle: .chest, secondaryMuscles: [.shoulders], equipment: .cable,
                    instructions: ["Poleas altas, un paso al frente con el torso ligeramente inclinado.", "Junta las manos delante del pecho en arco.", "Vuelve controlado sin perder tensión."]),
        GymExercise(name: "Press en Máquina", primaryMuscle: .chest, secondaryMuscles: [.triceps], equipment: .machine,
                    instructions: ["Ajusta el asiento para que los agarres queden a la altura del pecho.", "Empuja hasta extender casi por completo.", "Vuelve lento manteniendo tensión."]),
        GymExercise(name: "Fondos en Paralelas", primaryMuscle: .chest, secondaryMuscles: [.triceps, .shoulders], equipment: .bodyweight,
                    instructions: ["Inclina el torso ligeramente hacia delante.", "Baja hasta que el hombro quede a la altura del codo.", "Empuja hasta extender los brazos."]),
        GymExercise(name: "Flexiones", primaryMuscle: .chest, secondaryMuscles: [.triceps, .abs], equipment: .bodyweight,
                    instructions: ["Manos algo más anchas que los hombros, cuerpo en línea.", "Baja hasta rozar el suelo con el pecho.", "Empuja sin arquear la zona lumbar."])
    ]

    // MARK: Espalda
    static let espalda: [GymExercise] = [
        GymExercise(name: "Dominadas", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .bodyweight,
                    instructions: ["Agarre prono algo más ancho que los hombros.", "Tira hasta pasar la barbilla por encima de la barra.", "Baja controlado hasta extensión completa."]),
        GymExercise(name: "Jalón al Pecho", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .cable,
                    instructions: ["Agarra la barra ancha y fija las piernas bajo el soporte.", "Tira de la barra hacia la parte alta del pecho.", "Sube controlado estirando el dorsal."]),
        GymExercise(name: "Remo con Barra", primaryMuscle: .back, secondaryMuscles: [.biceps, .hamstrings], equipment: .barbell,
                    instructions: ["Torso inclinado 45º con espalda neutra.", "Tira de la barra hacia el abdomen.", "Baja controlado sin redondear la espalda."]),
        GymExercise(name: "Remo con Mancuerna", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .dumbbell,
                    instructions: ["Apoya rodilla y mano en el banco.", "Tira de la mancuerna hacia la cadera.", "Baja estirando el dorsal por completo."]),
        GymExercise(name: "Remo en Polea Baja", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .cable,
                    instructions: ["Siéntate con rodillas semiflexionadas y espalda recta.", "Tira del agarre hacia el abdomen juntando escápulas.", "Vuelve controlado sin encorvarte."]),
        GymExercise(name: "Remo en Máquina", primaryMuscle: .back, secondaryMuscles: [.biceps], equipment: .machine,
                    instructions: ["Pecho apoyado en el soporte.", "Tira de los agarres juntando escápulas.", "Vuelve lento manteniendo tensión."]),
        GymExercise(name: "Pullover en Polea", primaryMuscle: .back, secondaryMuscles: [.chest, .triceps], equipment: .cable,
                    instructions: ["Polea alta, brazos casi extendidos.", "Lleva la barra hacia la cadera en arco.", "Sube controlado sintiendo el dorsal."]),
        GymExercise(name: "Peso Muerto", primaryMuscle: .back, secondaryMuscles: [.hamstrings, .glutes], equipment: .barbell,
                    instructions: ["Barra pegada a las espinillas, espalda neutra.", "Empuja el suelo extendiendo cadera y rodillas a la vez.", "Bloquea arriba con glúteo, baja controlado."]),
        GymExercise(name: "Encogimientos con Barra", primaryMuscle: .back, secondaryMuscles: [.shoulders], equipment: .barbell,
                    instructions: ["Barra colgando con brazos extendidos.", "Encoge los hombros hacia las orejas.", "Baja lento sin rotar los hombros."]),
        GymExercise(name: "Superman", primaryMuscle: .back, secondaryMuscles: [.glutes], equipment: .bodyweight,
                    instructions: ["Boca abajo con brazos extendidos al frente.", "Eleva brazos y piernas a la vez contrayendo la espalda.", "Mantén 1-2 segundos y baja controlado."])
    ]

    // MARK: Hombros
    static let hombros: [GymExercise] = [
        GymExercise(name: "Press Militar", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .barbell,
                    instructions: ["Barra a la altura de las clavículas, core firme.", "Empuja vertical hasta extender los brazos.", "Baja controlado a la posición inicial."]),
        GymExercise(name: "Press Arnold", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .dumbbell,
                    instructions: ["Mancuernas frente a los hombros con palmas hacia ti.", "Rota las palmas mientras empujas hacia arriba.", "Invierte el giro al bajar."]),
        GymExercise(name: "Press Hombro Mancuernas", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .dumbbell,
                    instructions: ["Mancuernas a la altura de las orejas.", "Empuja vertical sin arquear la lumbar.", "Baja controlado hasta 90º de codo."]),
        GymExercise(name: "Elevaciones Laterales", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .dumbbell,
                    instructions: ["Mancuernas a los lados, ligera flexión de codos.", "Eleva hasta la altura de los hombros.", "Baja lento resistiendo la caída."]),
        GymExercise(name: "Elevaciones Frontales", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .dumbbell,
                    instructions: ["Mancuernas delante de los muslos.", "Eleva al frente hasta la altura de los ojos.", "Baja controlado sin balanceo."]),
        GymExercise(name: "Pájaros", primaryMuscle: .shoulders, secondaryMuscles: [.back], equipment: .dumbbell,
                    instructions: ["Torso inclinado con espalda neutra.", "Abre los brazos en arco hasta la altura de los hombros.", "Baja lento sin dar impulso."]),
        GymExercise(name: "Face Pull", primaryMuscle: .shoulders, secondaryMuscles: [.back], equipment: .cable,
                    instructions: ["Polea a la altura de la cara con cuerda.", "Tira hacia la frente separando los extremos.", "Vuelve controlado con codos altos."]),
        GymExercise(name: "Elevaciones Laterales en Polea", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .cable,
                    instructions: ["Polea baja al costado, agarre con la mano contraria.", "Eleva el brazo en arco hasta el hombro.", "Baja resistiendo la polea."]),
        GymExercise(name: "Pike Push-Up", primaryMuscle: .shoulders, secondaryMuscles: [.triceps], equipment: .bodyweight,
                    instructions: ["Posición de V invertida con la cadera alta.", "Flexiona los codos llevando la cabeza al suelo.", "Empuja hasta extender los brazos."])
    ]

    // MARK: Bíceps
    static let biceps: [GymExercise] = [
        GymExercise(name: "Curl con Barra", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .barbell,
                    instructions: ["Agarre supino a la anchura de los hombros.", "Sube la barra sin mover los codos.", "Baja lento hasta extensión completa."]),
        GymExercise(name: "Curl con Mancuernas", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell,
                    instructions: ["Palmas al frente, codos pegados al torso.", "Sube alternando o simultáneo sin balanceo.", "Baja en 2-3 segundos."]),
        GymExercise(name: "Curl Martillo", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell,
                    instructions: ["Palmas enfrentadas (agarre neutro).", "Sube sin rotar la muñeca.", "Baja controlado."]),
        GymExercise(name: "Curl Predicador", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .machine,
                    instructions: ["Brazos apoyados por completo en el banco Scott.", "Sube hasta contraer el bíceps.", "Baja lento sin extender de golpe."]),
        GymExercise(name: "Curl en Polea", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .cable,
                    instructions: ["Polea baja con barra recta o cuerda.", "Sube manteniendo los codos fijos.", "Baja manteniendo tensión constante."]),
        GymExercise(name: "Curl Inclinado", primaryMuscle: .biceps, secondaryMuscles: [], equipment: .dumbbell,
                    instructions: ["Banco a 45-60º, brazos colgando.", "Sube sin adelantar los hombros.", "Baja hasta estiramiento completo."])
    ]

    // MARK: Tríceps
    static let triceps: [GymExercise] = [
        GymExercise(name: "Press Francés", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .barbell,
                    instructions: ["Tumbado, barra Z sobre la frente.", "Extiende los codos sin mover los hombros.", "Baja controlado hacia la frente."]),
        GymExercise(name: "Extensión de Tríceps en Polea", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .cable,
                    instructions: ["Polea alta, codos pegados al torso.", "Extiende hasta bloquear abajo.", "Sube solo hasta 90º manteniendo los codos fijos."]),
        GymExercise(name: "Extensión con Cuerda", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .cable,
                    instructions: ["Cuerda en polea alta.", "Extiende separando los extremos al final.", "Vuelve controlado sin abrir los codos."]),
        GymExercise(name: "Press Cerrado", primaryMuscle: .triceps, secondaryMuscles: [.chest, .shoulders], equipment: .barbell,
                    instructions: ["Agarre a la anchura de los hombros.", "Baja la barra al pecho con codos pegados.", "Empuja extendiendo los tríceps."]),
        GymExercise(name: "Fondos entre Bancos", primaryMuscle: .triceps, secondaryMuscles: [.chest], equipment: .bodyweight,
                    instructions: ["Manos en el banco por detrás, piernas extendidas.", "Baja flexionando los codos a 90º.", "Empuja hasta extender."]),
        GymExercise(name: "Extensión Trasnuca con Mancuerna", primaryMuscle: .triceps, secondaryMuscles: [], equipment: .dumbbell,
                    instructions: ["Mancuerna a dos manos sobre la cabeza.", "Baja por detrás de la nuca.", "Extiende sin abrir los codos."])
    ]

    // MARK: Piernas
    static let piernas: [GymExercise] = [
        GymExercise(name: "Sentadilla", primaryMuscle: .quads, secondaryMuscles: [.glutes, .hamstrings], equipment: .barbell,
                    instructions: ["Barra sobre trapecios, pies a la anchura de los hombros.", "Baja rompiendo paralela con espalda neutra.", "Empuja el suelo para subir."]),
        GymExercise(name: "Sentadilla Frontal", primaryMuscle: .quads, secondaryMuscles: [.glutes, .abs], equipment: .barbell,
                    instructions: ["Barra apoyada en deltoides frontales, codos altos.", "Baja manteniendo el torso vertical.", "Sube sin dejar caer los codos."]),
        GymExercise(name: "Prensa de Piernas", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .machine,
                    instructions: ["Pies a la anchura de los hombros en la plataforma.", "Baja hasta 90º sin despegar la lumbar.", "Empuja sin bloquear las rodillas."]),
        GymExercise(name: "Zancadas con Mancuernas", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .dumbbell,
                    instructions: ["Paso largo al frente.", "Baja hasta que la rodilla trasera roce el suelo.", "Empuja con el talón delantero para volver."]),
        GymExercise(name: "Sentadilla Búlgara", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .dumbbell,
                    instructions: ["Pie trasero elevado en un banco.", "Baja vertical hasta 90º.", "Empuja con la pierna delantera."]),
        GymExercise(name: "Extensión de Cuádriceps", primaryMuscle: .quads, secondaryMuscles: [], equipment: .machine,
                    instructions: ["Ajusta el rodillo sobre los tobillos.", "Extiende las rodillas por completo.", "Baja lento resistiendo el peso."]),
        GymExercise(name: "Curl Femoral Tumbado", primaryMuscle: .hamstrings, secondaryMuscles: [], equipment: .machine,
                    instructions: ["Rodillo sobre los tobillos, cadera pegada al banco.", "Flexiona llevando los talones al glúteo.", "Baja controlado."]),
        GymExercise(name: "Peso Muerto Rumano", primaryMuscle: .hamstrings, secondaryMuscles: [.glutes, .back], equipment: .barbell,
                    instructions: ["Rodillas semiflexionadas fijas.", "Baja la barra pegada a las piernas empujando la cadera atrás.", "Sube contrayendo glúteo e isquios."]),
        GymExercise(name: "Elevación de Gemelos de Pie", primaryMuscle: .calves, secondaryMuscles: [], equipment: .machine,
                    instructions: ["Puntas de los pies en el escalón.", "Sube de puntillas al máximo.", "Baja lento hasta estirar el gemelo."]),
        GymExercise(name: "Elevación de Gemelos Sentado", primaryMuscle: .calves, secondaryMuscles: [], equipment: .machine,
                    instructions: ["Rodillas bajo el soporte a 90º.", "Eleva los talones al máximo.", "Baja lento hasta estiramiento completo."]),
        GymExercise(name: "Sentadilla sin Peso", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .bodyweight,
                    instructions: ["Pies a la anchura de los hombros, brazos al frente.", "Baja controlado rompiendo paralela.", "Sube empujando con los talones."]),
        GymExercise(name: "Zancadas sin Peso", primaryMuscle: .quads, secondaryMuscles: [.glutes], equipment: .bodyweight,
                    instructions: ["Paso largo al frente con el torso recto.", "Baja hasta que la rodilla trasera roce el suelo.", "Alterna piernas con control."])
    ]

    // MARK: Glúteos
    static let gluteos: [GymExercise] = [
        GymExercise(name: "Hip Thrust", primaryMuscle: .glutes, secondaryMuscles: [.hamstrings], equipment: .barbell,
                    instructions: ["Espalda alta apoyada en el banco, barra sobre la cadera.", "Extiende la cadera hasta alinear torso y muslos.", "Aprieta el glúteo arriba 1 segundo."]),
        GymExercise(name: "Puente de Glúteo", primaryMuscle: .glutes, secondaryMuscles: [.hamstrings], equipment: .bodyweight,
                    instructions: ["Tumbado con rodillas flexionadas.", "Eleva la cadera apretando el glúteo.", "Baja controlado sin tocar el suelo."]),
        GymExercise(name: "Patada de Glúteo en Polea", primaryMuscle: .glutes, secondaryMuscles: [.hamstrings], equipment: .cable,
                    instructions: ["Tobillera en polea baja.", "Extiende la pierna atrás sin arquear la lumbar.", "Vuelve controlado."]),
        GymExercise(name: "Abducción en Máquina", primaryMuscle: .glutes, secondaryMuscles: [], equipment: .machine,
                    instructions: ["Siéntate con la espalda pegada al respaldo.", "Abre las piernas contra la resistencia.", "Cierra lento manteniendo tensión."])
    ]

    // MARK: Abs
    static let abs: [GymExercise] = [
        GymExercise(name: "Plancha", primaryMuscle: .abs, secondaryMuscles: [], equipment: .bodyweight,
                    instructions: ["Antebrazos en el suelo, cuerpo en línea recta.", "Aprieta abdomen y glúteo.", "Mantén sin hundir la cadera."]),
        GymExercise(name: "Crunch Abdominal", primaryMuscle: .abs, secondaryMuscles: [], equipment: .bodyweight,
                    instructions: ["Tumbado con rodillas flexionadas.", "Eleva los hombros contrayendo el abdomen.", "Baja sin apoyar del todo."]),
        GymExercise(name: "Elevaciones de Piernas", primaryMuscle: .abs, secondaryMuscles: [], equipment: .bodyweight,
                    instructions: ["Colgado o tumbado, piernas extendidas.", "Eleva las piernas hasta 90º.", "Baja lento sin balanceo."]),
        GymExercise(name: "Crunch en Polea", primaryMuscle: .abs, secondaryMuscles: [], equipment: .cable,
                    instructions: ["De rodillas con la cuerda tras la cabeza.", "Flexiona el torso llevando los codos a las rodillas.", "Sube controlado sin mover la cadera."]),
        GymExercise(name: "Rueda Abdominal", primaryMuscle: .abs, secondaryMuscles: [.shoulders], equipment: .bodyweight,
                    instructions: ["De rodillas con la rueda bajo los hombros.", "Rueda al frente manteniendo el core firme.", "Vuelve tirando desde el abdomen."]),
        GymExercise(name: "Russian Twist", primaryMuscle: .abs, secondaryMuscles: [], equipment: .kettlebell,
                    instructions: ["Sentado con el torso inclinado atrás y pies elevados.", "Rota el peso de lado a lado.", "Controla el giro desde el core."])
    ]
}
