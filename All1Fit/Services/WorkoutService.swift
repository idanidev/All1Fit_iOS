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
    private var lastFetchAll: Date?
    private var lastFetchPerId: [String: Date] = [:]
    private let cacheInterval: TimeInterval = 30
    
    // MARK: - Fetch All Results (single query, replaces per-workout loop)
    func fetchAllResults(forceRefresh: Bool = false) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        if !forceRefresh, let last = lastFetchAll, Date().timeIntervalSince(last) < cacheInterval { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("workoutResults")
                .getDocuments()

            var grouped: [String: [WorkoutResult]] = [:]
            for doc in snapshot.documents {
                guard let result = try? doc.data(as: WorkoutResult.self) else { continue }
                grouped[result.workoutId, default: []].append(result)
            }
            for key in grouped.keys {
                grouped[key]?.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            }
            results = grouped
            lastFetchAll = Date()
            logger.info("fetchAllResults: \(snapshot.documents.count) docs, \(grouped.count) workouts")
        } catch {
            logger.error("fetchAllResults error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Fetch Results for a Workout
    func fetchResults(for workoutId: String, forceRefresh: Bool = false) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        if !forceRefresh,
           let last = lastFetchPerId[workoutId],
           Date().timeIntervalSince(last) < cacheInterval,
           results[workoutId] != nil { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("workoutResults")
                .whereField("workoutId", isEqualTo: workoutId)
                .getDocuments()

            let fetchedResults = snapshot.documents.compactMap { try? $0.data(as: WorkoutResult.self) }
            results[workoutId] = fetchedResults.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            lastFetchPerId[workoutId] = Date()
            logger.info("fetchResults[\(workoutId)]: \(fetchedResults.count) results")
        } catch {
            logger.error("fetchResults[\(workoutId)] error: \(error.localizedDescription)")
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
