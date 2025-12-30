import Foundation
import FirebaseFirestore
import FirebaseAuth
import os

// MARK: - Workout Service
@MainActor
class WorkoutService: ObservableObject {
    @Published var results: [String: [WorkoutResult]] = [:] // workoutId -> results
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "All1Fit", category: "WorkoutService")
    
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
                // .order(by: "date", descending: true) // Disabled: may require composite index
                .getDocuments()
            
            logger.info("Fetched \(snapshot.documents.count) results for workoutId: \(workoutId)")
            
            let fetchedResults = snapshot.documents.compactMap { doc -> WorkoutResult? in
                do {
                    let result = try doc.data(as: WorkoutResult.self)
                    self.logger.info("Decoded result: \(result.workoutId), time: \(result.timeSeconds)")
                    return result
                } catch {
                    self.logger.error("Failed to decode result \(doc.documentID): \(error.localizedDescription)")
                    return nil
                }
            }
            
            results[workoutId] = fetchedResults
            logger.info("Stored \(fetchedResults.count) results for \(workoutId). Total workouts with results: \(self.results.count)")
        } catch {
            logger.error("Error fetching results for \(workoutId): \(error.localizedDescription)")
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
    
    // MARK: - Update Result
    func updateResult(_ result: WorkoutResult, timeSeconds: Int, rounds: Int?, notes: String?) async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              let resultId = result.id else { return }
        
        var updateData: [String: Any] = [
            "timeSeconds": timeSeconds
        ]
        
        if let rounds = rounds {
            updateData["rounds"] = rounds
        }
        
        if let notes = notes {
            updateData["notes"] = notes
        }
        
        try await db.collection("users")
            .document(userId)
            .collection("workoutResults")
            .document(resultId)
            .updateData(updateData)
        
        // Update local cache
        if let index = results[result.workoutId]?.firstIndex(where: { $0.id == resultId }) {

            // Create new result with updated values (since properties may be let)
            results[result.workoutId]?[index] = WorkoutResult(
                id: resultId,
                workoutId: result.workoutId,
                userId: result.userId,
                date: result.date,
                timeSeconds: timeSeconds,
                rounds: rounds,
                notes: notes
            )
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
