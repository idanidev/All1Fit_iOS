import FirebaseFirestore
import FirebaseAuth
import os

// MARK: - User Workout Service
@MainActor
class UserWorkoutService: ObservableObject {
    @Published var userWorkouts: [UserWorkout] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "All1Fit", category: "UserWorkoutService")
    
    // MARK: - Fetch User Workouts
    func fetchWorkouts() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("workouts")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            logger.info("Fetched \(snapshot.documents.count) workouts for user \(userId)")
            
            userWorkouts = snapshot.documents.compactMap { doc in
                do {
                    let workout = try doc.data(as: UserWorkout.self)
                    self.logger.info("Decoded workout: \(workout.name), category: \(workout.category)")
                    return workout
                } catch {
                    self.logger.error("Failed to decode workout \(doc.documentID): \(error.localizedDescription)")
                    return nil
                }
            }
        } catch {
            logger.error("Error fetching workouts: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Save Workout
    func saveWorkout(_ workout: UserWorkout) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "UserWorkoutService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        var workoutToSave = workout
        workoutToSave.userId = userId
        workoutToSave.createdAt = Date()
        
        if let id = workout.id {
            // Update existing
            try db.collection("users")
                .document(userId)
                .collection("workouts")
                .document(id)
                .setData(from: workoutToSave, merge: true)
        } else {
            // Create new
            let ref = try db.collection("users")
                .document(userId)
                .collection("workouts")
                .addDocument(from: workoutToSave)
            workoutToSave.id = ref.documentID
        }
        
        // Update local cache
        if let index = userWorkouts.firstIndex(where: { $0.id == workoutToSave.id }) {
            userWorkouts[index] = workoutToSave
        } else {
            userWorkouts.insert(workoutToSave, at: 0)
        }
    }
    
    // MARK: - Delete Workout
    func deleteWorkout(_ workout: UserWorkout) async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              let workoutId = workout.id else { return }
        
        try await db.collection("users")
            .document(userId)
            .collection("workouts")
            .document(workoutId)
            .delete()
        
        // Remove from local cache
        userWorkouts.removeAll { $0.id == workoutId }
    }
}

// MARK: - User Workout Model
struct UserWorkout: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var userId: String?
    var name: String
    var description: String
    var category: String // "running", "crossfit", "competition"
    var exercises: [UserWorkoutExercise]
    var timeCapMinutes: Int?
    var isForTime: Bool
    var createdAt: Date?
    
    var workoutCategory: WorkoutCategory {
        // Try exact match
        if let match = WorkoutCategory(rawValue: category) { return match }
        // Try case-insensitive match
        return WorkoutCategory.allCases.first { 
            $0.rawValue.caseInsensitiveCompare(category) == .orderedSame 
        } ?? .crossfit
    }
    
    // Convert to Workout for display
    func toWorkout() -> Workout {
        Workout(
            id: id ?? UUID().uuidString,
            name: name,
            category: workoutCategory,
            description: description,
            exercises: exercises.map { $0.toWorkoutExercise() },
            timeCapMinutes: timeCapMinutes,
            isForTime: isForTime
        )
    }
}

// MARK: - User Workout Exercise
struct UserWorkoutExercise: Codable, Hashable {
    var name: String
    var reps: String
    var notes: String?
    
    func toWorkoutExercise() -> WorkoutExercise {
        WorkoutExercise(name: name, reps: reps, notes: notes)
    }
}
