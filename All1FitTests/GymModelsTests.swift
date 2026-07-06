import Testing
import Foundation
@testable import All1Fit

// MARK: - GymSet
@Suite("GymSet")
struct GymSetTests {

    @Test("1RM con una repetición es el propio peso")
    func oneRMSingleRep() {
        #expect(GymSet(reps: 1, weight: 100).estimated1RM == 100)
    }

    @Test("1RM estimado usa la fórmula de Epley")
    func oneRMEpley() {
        let rm = GymSet(reps: 10, weight: 100).estimated1RM
        let expected = 100 * (1 + 10.0 / 30.0)
        #expect(rm != nil)
        #expect(abs((rm ?? 0) - expected) < 0.001)
    }

    @Test("1RM es nil sin peso o sin reps")
    func oneRMInvalid() {
        #expect(GymSet(reps: 0, weight: 100).estimated1RM == nil)
        #expect(GymSet(reps: 5, weight: 0).estimated1RM == nil)
    }
}

// MARK: - GymExerciseLog
@Suite("GymExerciseLog")
struct GymExerciseLogTests {

    /// Calentamiento pesado completado + 2 efectivas (una sin completar)
    private func makeLog() -> GymExerciseLog {
        GymExerciseLog(exerciseName: "Press Banca", sets: [
            GymSet(reps: 5, weight: 200, completed: true, type: .warmup),
            GymSet(reps: 8, weight: 80, completed: true),
            GymSet(reps: 8, weight: 85, completed: false)
        ])
    }

    @Test("Las series efectivas excluyen calentamientos y no completadas")
    func workingSetsFilter() {
        let log = makeLog()
        #expect(log.completedSets.count == 2)
        #expect(log.workingSets.count == 1)
        #expect(log.workingSets.first?.weight == 80)
    }

    @Test("El volumen solo cuenta series efectivas")
    func volumeExcludesWarmup() {
        #expect(makeLog().volume == 80 * 8)
    }

    @Test("La mejor serie ignora calentamientos más pesados")
    func bestSetIgnoresWarmup() {
        #expect(makeLog().bestSet?.weight == 80)
    }

    @Test("El mejor 1RM estimado sale de las series efectivas")
    func best1RM() {
        let expected = 80 * (1 + 8.0 / 30.0)
        let rm = makeLog().bestEstimated1RM
        #expect(rm != nil)
        #expect(abs((rm ?? 0) - expected) < 0.001)
    }
}

// MARK: - GymSession
@Suite("GymSession")
struct GymSessionTests {

    @Test("Totales de volumen y series")
    func totals() {
        let session = GymSession(routineName: "Push", exercises: [
            GymExerciseLog(exerciseName: "Press Banca", sets: [
                GymSet(reps: 10, weight: 60, completed: true),
                GymSet(reps: 10, weight: 60, completed: true)
            ]),
            GymExerciseLog(exerciseName: "Press Militar", sets: [
                GymSet(reps: 8, weight: 40, completed: true),
                GymSet(reps: 8, weight: 40, completed: false)
            ])
        ])
        #expect(session.totalVolume == 60 * 10 * 2 + 40 * 8)
        #expect(session.totalCompletedSets == 3)
    }

    @Test("Formato de duración en minutos y horas")
    func durationFormat() {
        let start = Date(timeIntervalSince1970: 0)
        let short = GymSession(routineName: "X", startDate: start, endDate: start.addingTimeInterval(45 * 60))
        #expect(short.durationFormatted == "45m")

        let long = GymSession(routineName: "X", startDate: start, endDate: start.addingTimeInterval(65 * 60))
        #expect(long.durationFormatted == "1h 5m")
    }

    @Test("Decodifica el snapshot JSON local con valores por defecto")
    func decodeSnapshot() throws {
        let json = """
        {"routineName":"Push","startDate":"2026-07-01T10:00:00Z","exercises":[{"exerciseName":"Press Banca","sets":[{"reps":8,"weight":80,"completed":true}]}]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let session = try decoder.decode(GymSession.self, from: Data(json.utf8))

        #expect(session.routineName == "Push")
        #expect(session.exercises.count == 1)
        let set = try #require(session.exercises.first?.sets.first)
        #expect(set.type == .normal)          // default al faltar la clave
        #expect(set.rpe == nil)
        #expect(session.exercises.first?.restSeconds == 90)
    }

    @Test("El snapshot sobrevive a un ciclo encode/decode")
    func snapshotRoundTrip() throws {
        let original = GymSession(routineName: "Legs", exercises: [
            GymExerciseLog(exerciseName: "Sentadilla", restSeconds: 120, sets: [
                GymSet(reps: 5, weight: 100, completed: true, type: .failure, rpe: 9)
            ], supersetGroup: 1)
        ])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let restored = try decoder.decode(GymSession.self, from: data)

        #expect(restored.routineName == "Legs")
        #expect(restored.exercises.first?.supersetGroup == 1)
        let set = try #require(restored.exercises.first?.sets.first)
        #expect(set.type == .failure)
        #expect(set.rpe == 9)
        #expect(set.weight == 100)
    }
}

// MARK: - GymRoutine
@Suite("GymRoutine")
struct GymRoutineTests {

    @Test("Los músculos de la rutina no se repiten y mantienen orden")
    func muscleGroupsUnique() {
        let routine = GymRoutine(name: "Push", exercises: [
            RoutineExercise(exerciseName: "Press Banca"),
            RoutineExercise(exerciseName: "Press Banca Inclinado"),
            RoutineExercise(exerciseName: "Press Militar")
        ])
        #expect(routine.muscleGroups == [.chest, .shoulders])
    }

    @Test("Total de series suma todos los ejercicios")
    func totalSets() {
        let routine = GymRoutine(name: "X", exercises: [
            RoutineExercise(exerciseName: "A", sets: 4),
            RoutineExercise(exerciseName: "B", sets: 3)
        ])
        #expect(routine.totalSets == 7)
    }

    @Test("Duplicar genera ids nuevos y conserva contenido")
    func duplicate() {
        let original = GymRoutine(name: "Push", folder: "PPL", exercises: [
            RoutineExercise(exerciseName: "Press Banca", sets: 4, reps: 8, restSeconds: 120)
        ])
        let copy = original.duplicated()

        #expect(copy.name == "Push (copia)")
        #expect(copy.folder == "PPL")
        #expect(copy.exercises.count == 1)
        #expect(copy.exercises[0].exerciseName == "Press Banca")
        #expect(copy.exercises[0].id != original.exercises[0].id)
    }
}

// MARK: - Catálogo
@Suite("Catálogo de ejercicios")
struct CatalogTests {

    @Test("No hay nombres duplicados")
    func uniqueNames() {
        let names = GymExerciseCatalog.all.map { $0.name.lowercased() }
        #expect(names.count == Set(names).count)
    }

    @Test("Todas las rutinas de ejemplo referencian ejercicios del catálogo")
    func starterRoutinesResolvable() {
        for routine in GymRoutine.starterRoutines {
            for exercise in routine.exercises {
                #expect(GymExerciseCatalog.exercise(named: exercise.exerciseName) != nil,
                        "No existe en catálogo: \(exercise.exerciseName)")
            }
        }
    }

    @Test("La búsqueda ignora tildes y mayúsculas")
    func searchDiacritics() {
        let press = GymExerciseCatalog.exercise(named: "Press Francés")
        #expect(press?.matches("frances") == true)
        #expect(press?.matches("FRANCÉS") == true)
        #expect(press?.matches("sentadilla") == false)
    }

    @Test("Cada ejercicio tiene músculo primario e instrucciones")
    func catalogIntegrity() {
        for exercise in GymExerciseCatalog.all {
            #expect(exercise.primaryMuscle != BodyPart.none, "\(exercise.name)")
            #expect(!exercise.instructions.isEmpty, "\(exercise.name)")
        }
    }
}

// MARK: - BodyMeasurement
@Suite("BodyMeasurement")
struct BodyMeasurementTests {

    @Test("filledFields solo incluye campos con valor")
    func filledFields() {
        let measurement = BodyMeasurement(weight: 78.5, waist: 82)
        let labels = measurement.filledFields.map(\.label)
        #expect(labels == ["Peso", "Cintura"])
        #expect(measurement.filledFields[0].value == 78.5)
        #expect(measurement.filledFields[0].unit == "kg")
    }
}
