import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Workout Service
@MainActor
class WorkoutService: ObservableObject {
    @Published var results: [String: [WorkoutResult]] = [:] // workoutId -> results
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    // MARK: - Fetch Results for a Workout
    func fetchResults(for workoutId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("workoutResults")
                .whereField("workoutId", isEqualTo: workoutId)
                .order(by: "date", descending: true)
                .getDocuments()
            
            let fetchedResults = snapshot.documents.compactMap { doc in
                try? doc.data(as: WorkoutResult.self)
            }
            
            results[workoutId] = fetchedResults
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Save Result
    func saveResult(workoutId: String, timeSeconds: Int, rounds: Int? = nil, notes: String? = nil) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WorkoutService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        let result = WorkoutResult(
            workoutId: workoutId,
            userId: userId,
            date: Date(),
            timeSeconds: timeSeconds,
            rounds: rounds,
            notes: notes
        )
        
        try db.collection("users")
            .document(userId)
            .collection("workoutResults")
            .addDocument(from: result)
        
        // Add to local cache
        if results[workoutId] == nil {
            results[workoutId] = []
        }
        results[workoutId]?.insert(result, at: 0)
    }
    
    // MARK: - Get Personal Record
    func getPersonalRecord(for workoutId: String) -> WorkoutResult? {
        guard let workoutResults = results[workoutId],
              let workout = Workout.workout(withId: workoutId) else {
            return nil
        }
        
        if workout.isForTime {
            // Lowest time is PR
            return workoutResults.min { $0.timeSeconds < $1.timeSeconds }
        } else {
            // Most rounds is PR
            return workoutResults.max { ($0.rounds ?? 0) < ($1.rounds ?? 0) }
        }
    }
    
    // MARK: - Delete Result
    func deleteResult(_ result: WorkoutResult) async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              let resultId = result.id else { return }
        
        try await db.collection("users")
            .document(userId)
            .collection("workoutResults")
            .document(resultId)
            .delete()
        
        // Remove from local cache
        results[result.workoutId]?.removeAll { $0.id == resultId }
    }
}
