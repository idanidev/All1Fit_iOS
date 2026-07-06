import Testing
import Foundation
@testable import All1Fit

// MARK: - GymSessionService (lógica local: prefill, PRs, snapshot)
/// No toca la red: siembra `sessions` en memoria y usa UserDefaults para el snapshot.
@Suite("GymSessionService", .serialized)
@MainActor
struct GymSessionServiceTests {

    private static let snapshotKey = "activeGymSessionSnapshot"

    private func makeService(history: [GymSession] = []) -> GymSessionService {
        UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
        let service = GymSessionService()
        service.sessions = history
        service.activeSession = nil
        return service
    }

    /// Historial con una sesión de Press Banca: calentamiento 100kg + efectivas 80×8 y 82.5×6
    private var sampleHistory: [GymSession] {
        [GymSession(routineName: "Push", startDate: Date(timeIntervalSince1970: 1000), exercises: [
            GymExerciseLog(exerciseName: "Press Banca", sets: [
                GymSet(reps: 5, weight: 100, completed: true, type: .warmup),
                GymSet(reps: 8, weight: 80, completed: true),
                GymSet(reps: 6, weight: 82.5, completed: true)
            ])
        ])]
    }

    // MARK: Empezar sesión

    @Test("Sesión libre: sin ejercicios y nombre por defecto")
    func startEmptySession() {
        let service = makeService()
        service.startSession(from: nil)

        #expect(service.activeSession?.routineName == "Entreno libre")
        #expect(service.activeSession?.exercises.isEmpty == true)
        service.discardActiveSession()
    }

    @Test("Desde rutina sin historial: reps objetivo y peso 0")
    func startFromRoutineNoHistory() {
        let service = makeService()
        let routine = GymRoutine(name: "Push", exercises: [
            RoutineExercise(exerciseName: "Press Banca", sets: 4, reps: 8, restSeconds: 120, supersetGroup: 2)
        ])
        service.startSession(from: routine)

        let log = service.activeSession?.exercises.first
        let allDefault: Bool = log?.sets.allSatisfy { $0.reps == 8 && $0.weight == 0 } ?? false
        #expect(service.activeSession?.routineName == "Push")
        #expect(log?.sets.count == 4)
        #expect(allDefault)
        #expect(log?.restSeconds == 120)
        #expect(log?.supersetGroup == 2)
        service.discardActiveSession()
    }

    @Test("Desde rutina con historial: prefill de pesos y reps de la última sesión")
    func startFromRoutineWithHistory() {
        let service = makeService(history: sampleHistory)
        let routine = GymRoutine(name: "Push", exercises: [
            RoutineExercise(exerciseName: "Press Banca", sets: 3, reps: 10)
        ])
        service.startSession(from: routine)

        let sets = service.activeSession?.exercises.first?.sets ?? []
        #expect(sets.count == 3)
        // Prefill posicional sobre TODAS las series previas (incluye calentamiento)
        #expect(sets[0].weight == 100)
        #expect(sets[1].weight == 80)
        #expect(sets[2].weight == 82.5)
        // Ninguna viene completada
        let noneCompleted: Bool = sets.allSatisfy { !$0.completed }
        #expect(noneCompleted)
        service.discardActiveSession()
    }

    @Test("Añadir ejercicio a sesión activa crea 3 series")
    func addExerciseToActive() {
        let service = makeService()
        service.startSession(from: nil)
        let exercise = GymExerciseCatalog.all[0]

        service.addExerciseToActive(exercise)

        #expect(service.activeSession?.exercises.count == 1)
        #expect(service.activeSession?.exercises.first?.sets.count == 3)
        service.discardActiveSession()
    }

    // MARK: Consultas de historial

    @Test("El mejor peso excluye calentamientos")
    func bestWeightExcludesWarmup() {
        let service = makeService(history: sampleHistory)
        #expect(service.bestWeight(for: "Press Banca") == 82.5)
        #expect(service.bestWeight(for: "press banca") == 82.5)   // case-insensitive
        #expect(service.bestWeight(for: "Sentadilla") == 0)
    }

    @Test("1RM estimado y mejor volumen de sesión")
    func recordQueries() {
        let service = makeService(history: sampleHistory)

        let expected1RM: Double = max(80 * (1 + 8.0 / 30.0), 82.5 * (1 + 6.0 / 30.0))
        let rm = service.best1RM(for: "Press Banca")
        #expect(rm != nil)
        #expect(abs((rm ?? 0) - expected1RM) < 0.001)

        let expectedVolume: Double = 80.0 * 8.0 + 82.5 * 6.0
        #expect(service.bestSessionVolume(for: "Press Banca") == expectedVolume)
        #expect(service.best1RM(for: "Sentadilla") == nil)
    }

    @Test("weightHistory ordenado ascendente por fecha")
    func weightHistorySorted() {
        var older = sampleHistory[0]
        older.startDate = Date(timeIntervalSince1970: 500)
        var newer = sampleHistory[0]
        newer.startDate = Date(timeIntervalSince1970: 2000)
        // El servicio guarda descendente (más reciente primero)
        let service = makeService(history: [newer, older])

        let history = service.weightHistory(for: "Press Banca")
        #expect(history.count == 2)
        #expect(history[0].date < history[1].date)
    }

    @Test("lastLog ignora ejercicios sin series completadas")
    func lastLogSkipsEmpty() {
        let empty = GymSession(routineName: "X", exercises: [
            GymExerciseLog(exerciseName: "Press Banca", sets: [GymSet(reps: 8, weight: 90, completed: false)])
        ])
        let service = makeService(history: [empty] + sampleHistory)

        #expect(service.lastLog(for: "Press Banca")?.bestSet?.weight == 82.5)
    }

    // MARK: Doble progresión

    @Test("Objetivo cumplido sube el peso automáticamente; incompleto lo mantiene")
    func doubleProgression() {
        let routine = GymRoutine(name: "Push", exercises: [
            RoutineExercise(exerciseName: "Press Banca", sets: 3, reps: 8)
        ])

        // 3 series efectivas completadas al objetivo → progresión +2.5 (barra)
        let completed = GymSession(routineName: "Push", exercises: [
            GymExerciseLog(exerciseName: "Press Banca", sets: [
                GymSet(reps: 8, weight: 80, completed: true),
                GymSet(reps: 8, weight: 80, completed: true),
                GymSet(reps: 9, weight: 80, completed: true)
            ])
        ])
        let service = makeService(history: [completed])
        service.startSession(from: routine)

        let log = service.activeSession?.exercises.first
        #expect(log?.progressionApplied == true)
        #expect(log?.sets.first?.weight == 82.5)
        service.discardActiveSession()

        // Última serie por debajo del objetivo de reps → mismo peso, sin progresión
        let incomplete = GymSession(routineName: "Push", exercises: [
            GymExerciseLog(exerciseName: "Press Banca", sets: [
                GymSet(reps: 8, weight: 80, completed: true),
                GymSet(reps: 8, weight: 80, completed: true),
                GymSet(reps: 6, weight: 80, completed: true)
            ])
        ])
        let service2 = makeService(history: [incomplete])
        service2.startSession(from: routine)

        let log2 = service2.activeSession?.exercises.first
        #expect(log2?.progressionApplied == false)
        #expect(log2?.sets.first?.weight == 80)
        service2.discardActiveSession()
    }

    @Test("El incremento depende del material y peso corporal no progresa en peso")
    func progressionIncrements() {
        #expect(GymSessionService.progressionIncrement(for: "Press Banca") == 2.5)      // barra
        #expect(GymSessionService.progressionIncrement(for: "Curl con Mancuernas") == 2.0)
        #expect(GymSessionService.progressionIncrement(for: "Flexiones") == 0)          // corporal
        #expect(GymSessionService.progressionIncrement(for: "NoExiste") == 0)
    }

    // MARK: Snapshot

    @Test("El snapshot se restaura en una instancia nueva y se limpia al descartar")
    func snapshotLifecycle() {
        let service = makeService()
        service.startSession(from: GymRoutine(name: "Legs", exercises: [
            RoutineExercise(exerciseName: "Sentadilla", sets: 2, reps: 5)
        ]))
        service.activeSession?.exercises[0].sets[0].completed = true
        service.persistActiveSnapshot()

        // Nueva instancia → restaura desde UserDefaults
        let restored = GymSessionService()
        #expect(restored.activeSession?.routineName == "Legs")
        #expect(restored.activeSession?.exercises.first?.sets.first?.completed == true)

        // Descartar limpia el snapshot
        restored.discardActiveSession()
        let afterDiscard = GymSessionService()
        #expect(afterDiscard.activeSession == nil)
    }
}
