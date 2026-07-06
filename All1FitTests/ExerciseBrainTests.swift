import Testing
@testable import All1Fit

// MARK: - Detección de músculos por nombre
@Suite("ExerciseBrain")
struct ExerciseBrainTests {

    @Test("Sentadillas → cuádriceps", arguments: ["Back Squat", "Sentadilla", "Prensa de piernas"])
    func squatsAreQuads(name: String) {
        #expect(ExerciseBrain.detectTargetMuscles(from: name).primary == .quads)
    }

    @Test("Press de banca → pecho")
    func benchIsChest() {
        let result = ExerciseBrain.detectTargetMuscles(from: "Press Banca")
        #expect(result.primary == .chest)
        #expect(result.secondary.contains(.triceps))
    }

    @Test("Peso muerto convencional → espalda con isquios y glúteos")
    func deadliftIsBack() {
        let result = ExerciseBrain.detectTargetMuscles(from: "Peso Muerto")
        #expect(result.primary == .back)
        #expect(result.secondary.contains(.hamstrings))
    }

    @Test("Peso muerto rumano → isquios")
    func romanianDeadliftIsHamstrings() {
        #expect(ExerciseBrain.detectTargetMuscles(from: "Peso Muerto Rumano").primary == .hamstrings)
    }

    @Test("Curl → bíceps", arguments: ["Curl con Barra", "Curl Martillo", "Curl predicador"])
    func curlsAreBiceps(name: String) {
        #expect(ExerciseBrain.detectTargetMuscles(from: name).primary == .biceps)
    }

    @Test("Tirones → espalda", arguments: ["Remo con Barra", "Dominadas", "Jalón al pecho"])
    func pullsAreBack(name: String) {
        #expect(ExerciseBrain.detectTargetMuscles(from: name).primary == .back)
    }

    @Test("Elevaciones laterales → hombros")
    func lateralRaisesAreShoulders() {
        #expect(ExerciseBrain.detectTargetMuscles(from: "Elevaciones Laterales").primary == .shoulders)
    }

    @Test("Gemelos → gemelos")
    func calvesAreCalves() {
        #expect(ExerciseBrain.detectTargetMuscles(from: "Elevación de gemelos").primary == .calves)
    }

    @Test("Core → abdominales", arguments: ["Plancha", "Crunch abdominal", "Rueda abdominal"])
    func coreIsAbs(name: String) {
        #expect(ExerciseBrain.detectTargetMuscles(from: name).primary == .abs)
    }

    @Test("Nombre desconocido → general")
    func unknownIsNone() {
        #expect(ExerciseBrain.detectTargetMuscles(from: "Cosa rarísima").primary == BodyPart.none)
    }
}
