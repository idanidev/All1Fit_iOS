import Foundation

// MARK: - Workout Category
enum WorkoutCategory: String, CaseIterable, Identifiable {
    case running = "Running"
    case crossfit = "CrossFit"
    case competition = "Competiciones"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .crossfit: return "dumbbell.fill"
        case .competition: return "trophy.fill"
        }
    }
    
    var color: String {
        switch self {
        case .running: return "orange"
        case .crossfit: return "red"
        case .competition: return "purple"
        }
    }
}

// MARK: - Workout Exercise
struct WorkoutExercise: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let reps: String // Can be "21-15-9", "100", "1 mile", etc.
    let notes: String?
    
    init(name: String, reps: String, notes: String? = nil) {
        self.name = name
        self.reps = reps
        self.notes = notes
    }
}

// MARK: - Workout
struct Workout: Identifiable, Hashable {
    let id: String
    let name: String
    let category: WorkoutCategory
    let description: String
    let exercises: [WorkoutExercise]
    let timeCapMinutes: Int? // Optional time cap
    let isForTime: Bool // true = for time, false = AMRAP or distance
    
    // MARK: - Predefined Workouts
    static let all: [Workout] = [
        // Running
        Workout(
            id: "5k",
            name: "Carrera de 5 km",
            description: "",
            category: .running,
            exercises: [
                WorkoutExercise(name: "Carrera", reps: "5 km", notes: "Ritmo constante")
            ],
            timeCapMinutes: nil,
            isForTime: true
        ),
        Workout(
            id: "10k",
            name: "Carrera de 10 km",
            description: "",
            category: .running,
            exercises: [
                WorkoutExercise(name: "Carrera", reps: "10 km", notes: "Ritmo moderado")
            ],
            timeCapMinutes: nil,
            isForTime: true
        ),
        Workout(
            id: "media-maraton",
            name: "Media Maratón",
            category: .running,
            description: "21.1 kilómetros de carrera. Un desafío serio que requiere preparación y entrenamiento.",
            exercises: [
                WorkoutExercise(name: "Carrera", reps: "21.1 km")
            ],
            timeCapMinutes: nil,
            isForTime: true
        ),
        Workout(
            id: "maraton",
            name: "Maratón",
            category: .running,
            description: "42.195 kilómetros. La prueba reina del running, un logro épico para cualquier corredor.",
            exercises: [
                WorkoutExercise(name: "Carrera", reps: "42.195 km")
            ],
            timeCapMinutes: nil,
            isForTime: true
        ),
        
        // CrossFit
        Workout(
            id: "murph",
            name: "Murph",
            category: .crossfit,
            description: "Hero WOD en honor al teniente Michael Murphy. Se puede particionar los ejercicios del medio. Con chaleco lastrado (9kg/6kg) para Rx.",
            exercises: [
                WorkoutExercise(name: "Run", reps: "1 milla"),
                WorkoutExercise(name: "Pull-ups", reps: "100"),
                WorkoutExercise(name: "Push-ups", reps: "200"),
                WorkoutExercise(name: "Air Squats", reps: "300"),
                WorkoutExercise(name: "Run", reps: "1 milla")
            ],
            timeCapMinutes: nil,
            isForTime: true
        ),
        Workout(
            id: "cindy",
            name: "Cindy",
            category: .crossfit,
            description: "AMRAP clásico de 20 minutos. Benchmark workout que mide tu capacidad en movimientos básicos de calistenia.",
            exercises: [
                WorkoutExercise(name: "Pull-ups", reps: "5"),
                WorkoutExercise(name: "Push-ups", reps: "10"),
                WorkoutExercise(name: "Air Squats", reps: "15")
            ],
            timeCapMinutes: 20,
            isForTime: false
        ),
        Workout(
            id: "fran",
            name: "Fran",
            category: .crossfit,
            description: "El benchmark más famoso de CrossFit. Thrusters a 43/30kg. Objetivo: menos de 5 minutos.",
            exercises: [
                WorkoutExercise(name: "Thrusters", reps: "21-15-9", notes: "43/30 kg"),
                WorkoutExercise(name: "Pull-ups", reps: "21-15-9")
            ],
            timeCapMinutes: nil,
            isForTime: true
        ),
        Workout(
            id: "helen",
            name: "Helen",
            category: .crossfit,
            description: "3 rondas de carrera, kettlebell swings y pull-ups. Un workout que combina cardio y fuerza.",
            exercises: [
                WorkoutExercise(name: "Run", reps: "400m"),
                WorkoutExercise(name: "KB Swings", reps: "21", notes: "24/16 kg"),
                WorkoutExercise(name: "Pull-ups", reps: "12")
            ],
            timeCapMinutes: nil,
            isForTime: true
        ),
        
        // Competitions
        Workout(
            id: "hyrox",
            name: "HYROX",
            category: .competition,
            description: "La competición de fitness racing más grande del mundo. 8 estaciones alternando 1km de carrera con ejercicios funcionales.",
            exercises: [
                WorkoutExercise(name: "Run", reps: "1 km"),
                WorkoutExercise(name: "SkiErg", reps: "1000m"),
                WorkoutExercise(name: "Run", reps: "1 km"),
                WorkoutExercise(name: "Sled Push", reps: "50m", notes: "152/102 kg"),
                WorkoutExercise(name: "Run", reps: "1 km"),
                WorkoutExercise(name: "Sled Pull", reps: "50m", notes: "103/78 kg"),
                WorkoutExercise(name: "Run", reps: "1 km"),
                WorkoutExercise(name: "Burpee Broad Jumps", reps: "80m"),
                WorkoutExercise(name: "Run", reps: "1 km"),
                WorkoutExercise(name: "Row", reps: "1000m"),
                WorkoutExercise(name: "Run", reps: "1 km"),
                WorkoutExercise(name: "Farmers Carry", reps: "200m", notes: "2x24/16 kg"),
                WorkoutExercise(name: "Run", reps: "1 km"),
                WorkoutExercise(name: "Sandbag Lunges", reps: "100m", notes: "20/10 kg"),
                WorkoutExercise(name: "Run", reps: "1 km"),
                WorkoutExercise(name: "Wall Balls", reps: "100", notes: "9/6 kg")
            ],
            timeCapMinutes: nil,
            isForTime: true
        ),
        Workout(
            id: "dekka",
            name: "DEKKA",
            category: .competition,
            description: "Competición de fitness funcional con 10 zonas. Cada zona tiene un ejercicio específico con repeticiones definidas.",
            exercises: [
                WorkoutExercise(name: "Zona 1: Ram Burpees", reps: "20"),
                WorkoutExercise(name: "Zona 2: Box Jump Over", reps: "20"),
                WorkoutExercise(name: "Zona 3: Spartan Lunges", reps: "50"),
                WorkoutExercise(name: "Zona 4: Assault Bike", reps: "25 cal"),
                WorkoutExercise(name: "Zona 5: Dead Ball Over Shoulder", reps: "25"),
                WorkoutExercise(name: "Zona 6: Ski Erg", reps: "500m"),
                WorkoutExercise(name: "Zona 7: Farmers Carry", reps: "100m"),
                WorkoutExercise(name: "Zona 8: Tank Push/Pull", reps: "25m + 25m"),
                WorkoutExercise(name: "Zona 9: Row", reps: "500m"),
                WorkoutExercise(name: "Zona 10: Wall Balls", reps: "25")
            ],
            timeCapMinutes: nil,
            isForTime: true
        )
    ]
    
    static func workouts(for category: WorkoutCategory) -> [Workout] {
        all.filter { $0.category == category }
    }
    
    static func workout(withId id: String) -> Workout? {
        all.first { $0.id == id }
    }
}
