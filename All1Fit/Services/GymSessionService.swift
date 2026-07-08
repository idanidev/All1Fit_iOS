import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Gym Session Service (historial + sesión activa)
@MainActor
class GymSessionService: ObservableObject {
    @Published var sessions: [GymSession] = []
    @Published var activeSession: GymSession?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 30
    private static let activeSnapshotKey = "activeGymSessionSnapshot"

    /// Instancia viva (la de MainTabView) para acciones que llegan del Watch
    static weak var activeInstance: GymSessionService?

    init() {
        restoreActiveSession()
        Self.activeInstance = self
    }

    private func sessionsCollection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("gymSessions")
    }

    // MARK: - Fetch historial
    func fetchSessions(forceRefresh: Bool = false) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Usuario no autenticado"
            return
        }

        if !forceRefresh,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheTimeout,
           !sessions.isEmpty {
            return
        }

        isLoading = true

        do {
            let snapshot = try await sessionsCollection(userId: userId)
                .order(by: "startDate", descending: true)
                .limit(to: 200)
                .getDocuments()

            sessions = snapshot.documents.compactMap { doc in
                try? doc.data(as: GymSession.self)
            }
            lastFetchTime = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Sesión activa

    /// Empieza sesión desde rutina (o vacía si nil). Prefill de pesos desde la última
    /// sesión, aplicando doble progresión: si la sesión anterior completó todas las
    /// series efectivas al objetivo de reps, sube el peso automáticamente.
    func startSession(from routine: GymRoutine?) {
        let logs: [GymExerciseLog]
        if let routine {
            logs = routine.exercises.map { ex in
                let previous = lastLog(for: ex.exerciseName)
                let increment = Self.progressionIncrement(for: ex.exerciseName)
                let applyProgression = increment > 0 && metProgressionTarget(previous, target: ex)

                let sets = (0..<max(ex.sets, 1)).map { i -> GymSet in
                    let prevSet = previous?.sets.indices.contains(i) == true ? previous?.sets[i] : previous?.sets.last
                    let baseWeight = prevSet?.weight ?? 0
                    let weight = (applyProgression && baseWeight > 0) ? baseWeight + increment : baseWeight
                    return GymSet(reps: prevSet?.reps ?? ex.reps, weight: weight)
                }
                return GymExerciseLog(
                    exerciseName: ex.exerciseName,
                    restSeconds: ex.restSeconds,
                    sets: sets,
                    supersetGroup: ex.supersetGroup,
                    progressionApplied: applyProgression
                )
            }
        } else {
            logs = []
        }
        activeSession = GymSession(routineName: routine?.name ?? "Entreno libre", exercises: logs)
        persistActiveSnapshot()
    }

    // MARK: - Doble progresión

    /// Incremento según material: barra/máquina/polea +2.5 kg, mancuernas/kettlebell +2 kg,
    /// peso corporal sin incremento (ahí se progresa en reps).
    static func progressionIncrement(for exerciseName: String) -> Double {
        switch GymExerciseCatalog.exercise(named: exerciseName)?.equipment {
        case .barbell, .machine, .cable: return 2.5
        case .dumbbell, .kettlebell:     return 2.0
        case .bodyweight, nil:           return 0
        }
    }

    /// Objetivo cumplido: la última sesión tiene al menos las series efectivas de la rutina,
    /// todas completadas al objetivo de reps y con peso registrado.
    private func metProgressionTarget(_ previous: GymExerciseLog?, target: RoutineExercise) -> Bool {
        guard let previous else { return false }
        let working = previous.workingSets
        guard working.count >= target.sets else { return false }
        return working.allSatisfy { $0.reps >= target.reps && $0.weight > 0 }
    }

    /// Añade ejercicio a la sesión activa
    func addExerciseToActive(_ exercise: GymExercise) {
        guard activeSession != nil else { return }
        let previous = lastLog(for: exercise.name)
        let sets = (0..<3).map { i -> GymSet in
            let prevSet = previous?.sets.indices.contains(i) == true ? previous?.sets[i] : previous?.sets.last
            return GymSet(reps: prevSet?.reps ?? 10, weight: prevSet?.weight ?? 0)
        }
        activeSession?.exercises.append(GymExerciseLog(exerciseName: exercise.name, sets: sets))
        persistActiveSnapshot()
    }

    /// Termina y guarda la sesión activa en Firestore
    func finishActiveSession(notes: String? = nil) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GymServiceError.notAuthenticated
        }
        guard var session = activeSession else { throw GymServiceError.notFound }

        session.endDate = Date()
        session.notes = notes
        session.restEndDate = nil
        // Descarta ejercicios sin ninguna serie completada
        session.exercises = session.exercises.filter { !$0.completedSets.isEmpty }

        // Optimistic: añade al historial local y limpia activa
        var temp = session
        temp.id = UUID().uuidString
        sessions.insert(temp, at: 0)
        activeSession = nil
        clearActiveSnapshot()
        PhoneConnectivityService.shared.sendGymSessionToWatch(nil)

        // Registrar en Salud como entrenamiento de fuerza (anillos, calorías)
        let healthStart = session.startDate
        let healthDuration = session.duration
        Task {
            await HealthKitService.shared.saveWorkout(
                activityType: .traditionalStrengthTraining,
                startDate: healthStart,
                duration: healthDuration
            )
        }

        let docRef = try sessionsCollection(userId: userId).addDocument(from: session)
        if let index = sessions.firstIndex(where: { $0.id == temp.id }) {
            sessions[index].id = docRef.documentID
        }
    }

    /// Descarta la sesión activa sin guardar
    func discardActiveSession() {
        activeSession = nil
        clearActiveSnapshot()
        PhoneConnectivityService.shared.sendGymSessionToWatch(nil)
    }

    /// El Watch marca/desmarca una serie de la sesión activa.
    /// Al completar arranca también el descanso (misma conducta que el logger del iPhone):
    /// el restEndDate viaja de vuelta en el espejo y ambas pantallas lo muestran.
    func toggleSetFromWatch(exerciseId: String, setId: String, completed: Bool) {
        guard var session = activeSession,
              let exIndex = session.exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = session.exercises[exIndex].sets.firstIndex(where: { $0.id == setId }) else { return }
        session.exercises[exIndex].sets[setIndex].completed = completed

        if completed {
            let restSeconds = session.exercises[exIndex].restSeconds
            if restSeconds > 0 {
                session.restEndDate = Date().addingTimeInterval(TimeInterval(restSeconds))
                GymRestNotifier.schedule(after: TimeInterval(restSeconds),
                                         exerciseName: session.exercises[exIndex].exerciseName)
            }
        }

        activeSession = session
        persistActiveSnapshot()
    }

    // MARK: - Delete sesión del historial
    func deleteSession(id: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GymServiceError.notAuthenticated
        }

        sessions.removeAll { $0.id == id }

        try await sessionsCollection(userId: userId).document(id).delete()
    }

    // MARK: - Consultas de historial

    /// Último log registrado de un ejercicio (para mostrar "anterior" en el logger)
    func lastLog(for exerciseName: String) -> GymExerciseLog? {
        for session in sessions {
            if let log = session.exercises.first(where: {
                $0.exerciseName.caseInsensitiveCompare(exerciseName) == .orderedSame && !$0.completedSets.isEmpty
            }) {
                return log
            }
        }
        return nil
    }

    /// Mejor peso histórico de un ejercicio (detección de PR, sin calentamientos)
    func bestWeight(for exerciseName: String) -> Double {
        sessions.flatMap { session in
            session.exercises
                .filter { $0.exerciseName.caseInsensitiveCompare(exerciseName) == .orderedSame }
                .flatMap(\.workingSets)
                .map(\.weight)
        }.max() ?? 0
    }

    /// Mejor 1RM estimado histórico de un ejercicio
    func best1RM(for exerciseName: String) -> Double? {
        sessions.compactMap { session in
            session.exercises
                .filter { $0.exerciseName.caseInsensitiveCompare(exerciseName) == .orderedSame }
                .compactMap(\.bestEstimated1RM)
                .max()
        }.max()
    }

    /// Mejor volumen en una sesión para un ejercicio
    func bestSessionVolume(for exerciseName: String) -> Double? {
        sessions.compactMap { session in
            let v = session.exercises
                .filter { $0.exerciseName.caseInsensitiveCompare(exerciseName) == .orderedSame }
                .reduce(0.0) { $0 + $1.volume }
            return v > 0 ? v : nil
        }.max()
    }

    /// Historial completo de un ejercicio: (fecha de sesión, log)
    func history(for exerciseName: String) -> [(date: Date, log: GymExerciseLog)] {
        sessions.compactMap { session in
            session.exercises
                .first { $0.exerciseName.caseInsensitiveCompare(exerciseName) == .orderedSame && !$0.completedSets.isEmpty }
                .map { (session.startDate, $0) }
        }
    }

    /// Records globales: mejor 1RM estimado por ejercicio, ordenados de mayor a menor
    func topEstimated1RMs(limit: Int = 5) -> [(exerciseName: String, oneRM: Double)] {
        var best: [String: Double] = [:]
        for session in sessions {
            for log in session.exercises {
                guard let rm = log.bestEstimated1RM else { continue }
                let key = log.exerciseName
                best[key] = max(best[key] ?? 0, rm)
            }
        }
        return best
            .map { (exerciseName: $0.key, oneRM: $0.value) }
            .sorted { $0.oneRM > $1.oneRM }
            .prefix(limit)
            .map { $0 }
    }

    /// Evolución del mejor peso por sesión de un ejercicio (para gráfica)
    func weightHistory(for exerciseName: String) -> [(date: Date, weight: Double)] {
        sessions.compactMap { session in
            let best = session.exercises
                .filter { $0.exerciseName.caseInsensitiveCompare(exerciseName) == .orderedSame }
                .compactMap(\.bestSet?.weight)
                .max()
            guard let best, best > 0 else { return nil }
            return (session.startDate, best)
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Snapshot de sesión activa (sobrevive a cierres de app)

    func persistActiveSnapshot() {
        guard let session = activeSession else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(session) {
            UserDefaults.standard.set(data, forKey: Self.activeSnapshotKey)
        }
        // Espejo en el Apple Watch (applicationContext = último estado)
        PhoneConnectivityService.shared.sendGymSessionToWatch(session)
    }

    private func restoreActiveSession() {
        guard let data = UserDefaults.standard.data(forKey: Self.activeSnapshotKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        activeSession = try? decoder.decode(GymSession.self, from: data)
    }

    private func clearActiveSnapshot() {
        UserDefaults.standard.removeObject(forKey: Self.activeSnapshotKey)
    }

    func invalidateCache() {
        lastFetchTime = nil
    }
}
