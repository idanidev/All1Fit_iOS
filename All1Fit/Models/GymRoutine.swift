import Foundation
import FirebaseFirestore

// MARK: - Routine Exercise (ejercicio dentro de una rutina)
struct RoutineExercise: Codable, Identifiable, Hashable {
    var id: String
    var exerciseName: String
    var sets: Int
    var reps: Int
    var restSeconds: Int
    /// Ejercicios con el mismo número forman una superserie
    var supersetGroup: Int?

    init(id: String = UUID().uuidString, exerciseName: String, sets: Int = 3, reps: Int = 10, restSeconds: Int = 90, supersetGroup: Int? = nil) {
        self.id = id
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.supersetGroup = supersetGroup
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        exerciseName = try c.decode(String.self, forKey: .exerciseName)
        sets = try c.decodeIfPresent(Int.self, forKey: .sets) ?? 3
        reps = try c.decodeIfPresent(Int.self, forKey: .reps) ?? 10
        restSeconds = try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
        supersetGroup = try c.decodeIfPresent(Int.self, forKey: .supersetGroup)
    }

    var catalogExercise: GymExercise? {
        GymExerciseCatalog.exercise(named: exerciseName)
    }
}

// MARK: - Gym Routine (plantilla de entrenamiento)
struct GymRoutine: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var notes: String?
    /// Programa al que pertenece (ej: "Push Pull Legs"). nil = sin programa
    var folder: String?
    var exercises: [RoutineExercise]
    var createdAt: Date
    var updatedAt: Date

    init(name: String, notes: String? = nil, folder: String? = nil, exercises: [RoutineExercise] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.name = name
        self.notes = notes
        self.folder = folder
        self.exercises = exercises
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        _id = try c.decode(DocumentID<String>.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        folder = try c.decodeIfPresent(String.self, forKey: .folder)
        exercises = try c.decodeIfPresent([RoutineExercise].self, forKey: .exercises) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    /// Copia para duplicar (sin id, fechas nuevas)
    func duplicated() -> GymRoutine {
        GymRoutine(name: "\(name) (copia)", notes: notes, folder: folder, exercises: exercises.map { ex in
            var copy = ex
            copy.id = UUID().uuidString
            return copy
        })
    }

    /// Músculos primarios implicados en la rutina (sin repetir, en orden)
    var muscleGroups: [BodyPart] {
        var seen = Set<BodyPart>()
        return exercises.compactMap { ex in
            guard let muscle = ex.catalogExercise?.primaryMuscle, !seen.contains(muscle) else { return nil }
            seen.insert(muscle)
            return muscle
        }
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets }
    }
}

// MARK: - Sample Data
extension GymRoutine {
    static let sample = starterRoutines[0]

    /// Rutinas de ejemplo ofrecidas cuando el usuario aún no tiene ninguna
    static let starterRoutines: [GymRoutine] = [
        GymRoutine(
            name: "Push (Empuje)",
            folder: "Push Pull Legs",
            exercises: [
                RoutineExercise(exerciseName: "Press Banca", sets: 4, reps: 8, restSeconds: 120),
                RoutineExercise(exerciseName: "Press Militar", sets: 3, reps: 10, restSeconds: 90),
                RoutineExercise(exerciseName: "Press Mancuernas Inclinado", sets: 3, reps: 10, restSeconds: 90),
                RoutineExercise(exerciseName: "Elevaciones Laterales", sets: 3, reps: 15, restSeconds: 60),
                RoutineExercise(exerciseName: "Extensión con Cuerda", sets: 3, reps: 12, restSeconds: 60)
            ]
        ),
        GymRoutine(
            name: "Pull (Tirón)",
            folder: "Push Pull Legs",
            exercises: [
                RoutineExercise(exerciseName: "Peso Muerto", sets: 3, reps: 5, restSeconds: 180),
                RoutineExercise(exerciseName: "Dominadas", sets: 4, reps: 8, restSeconds: 120),
                RoutineExercise(exerciseName: "Remo con Barra", sets: 3, reps: 10, restSeconds: 90),
                RoutineExercise(exerciseName: "Face Pull", sets: 3, reps: 15, restSeconds: 60),
                RoutineExercise(exerciseName: "Curl con Barra", sets: 3, reps: 12, restSeconds: 60)
            ]
        ),
        GymRoutine(
            name: "Legs (Pierna)",
            folder: "Push Pull Legs",
            exercises: [
                RoutineExercise(exerciseName: "Sentadilla", sets: 4, reps: 6, restSeconds: 180),
                RoutineExercise(exerciseName: "Peso Muerto Rumano", sets: 3, reps: 10, restSeconds: 120),
                RoutineExercise(exerciseName: "Prensa de Piernas", sets: 3, reps: 12, restSeconds: 90),
                RoutineExercise(exerciseName: "Curl Femoral Tumbado", sets: 3, reps: 12, restSeconds: 60),
                RoutineExercise(exerciseName: "Elevación de Gemelos de Pie", sets: 4, reps: 15, restSeconds: 45)
            ]
        ),
        GymRoutine(
            name: "Full Body",
            exercises: [
                RoutineExercise(exerciseName: "Sentadilla", sets: 3, reps: 8, restSeconds: 120),
                RoutineExercise(exerciseName: "Press Banca", sets: 3, reps: 8, restSeconds: 120),
                RoutineExercise(exerciseName: "Remo con Barra", sets: 3, reps: 10, restSeconds: 90),
                RoutineExercise(exerciseName: "Press Militar", sets: 3, reps: 10, restSeconds: 90),
                RoutineExercise(exerciseName: "Plancha", sets: 3, reps: 1, restSeconds: 60)
            ]
        )
    ]
}
