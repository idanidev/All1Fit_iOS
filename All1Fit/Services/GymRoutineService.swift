import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Gym Routine Service (CRUD de rutinas con cache y updates optimistas)
@MainActor
class GymRoutineService: ObservableObject {
    @Published var routines: [GymRoutine] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 30

    private func routinesCollection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("gymRoutines")
    }

    // MARK: - Fetch
    func fetchRoutines(forceRefresh: Bool = false) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Usuario no autenticado"
            return
        }

        if !forceRefresh,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheTimeout,
           !routines.isEmpty {
            return
        }

        isLoading = true

        do {
            let snapshot = try await routinesCollection(userId: userId)
                .order(by: "updatedAt", descending: true)
                .getDocuments()

            routines = snapshot.documents.compactMap { doc in
                try? doc.data(as: GymRoutine.self)
            }
            lastFetchTime = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Create (Optimistic)
    func createRoutine(_ routine: GymRoutine) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GymServiceError.notAuthenticated
        }

        var tempRoutine = routine
        tempRoutine.id = UUID().uuidString
        routines.insert(tempRoutine, at: 0)

        let docRef = try routinesCollection(userId: userId).addDocument(from: routine)

        if let index = routines.firstIndex(where: { $0.id == tempRoutine.id }) {
            routines[index].id = docRef.documentID
        }
    }

    // MARK: - Update (Optimistic)
    func updateRoutine(_ routine: GymRoutine) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GymServiceError.notAuthenticated
        }
        guard let id = routine.id else { throw GymServiceError.notFound }

        var updated = routine
        updated.updatedAt = Date()

        if let index = routines.firstIndex(where: { $0.id == id }) {
            routines[index] = updated
        }

        try routinesCollection(userId: userId).document(id).setData(from: updated)
    }

    // MARK: - Delete (Optimistic)
    func deleteRoutine(id: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GymServiceError.notAuthenticated
        }

        routines.removeAll { $0.id == id }

        try await routinesCollection(userId: userId).document(id).delete()
    }

    func invalidateCache() {
        lastFetchTime = nil
    }
}

// MARK: - Errors
enum GymServiceError: LocalizedError {
    case notAuthenticated
    case notFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Usuario no autenticado"
        case .notFound: return "Elemento no encontrado"
        }
    }
}
