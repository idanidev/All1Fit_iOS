import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Custom Exercise Service (ejercicios creados por el usuario)
@MainActor
class CustomExerciseService: ObservableObject {
    @Published var customExercises: [GymExercise] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 30

    private func collection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("customExercises")
    }

    /// Los IDs de documento de Firestore no admiten "/" ni pueden ser "." o "..".
    /// Deriva un ID estable a partir del nombre del ejercicio.
    static func documentID(for name: String) -> String {
        let sanitized = name
            .replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespaces)
        if sanitized.isEmpty || sanitized == "." || sanitized == ".." {
            // hashValue no es estable entre procesos; hex del nombre sí
            let hex = Data(name.utf8).map { String(format: "%02x", $0) }.joined()
            return "ejercicio-\(hex)"
        }
        return sanitized
    }

    /// Catálogo completo: base + personalizados (sin duplicar nombres)
    var allExercises: [GymExercise] {
        let catalogNames = Set(GymExerciseCatalog.all.map { $0.name.lowercased() })
        let uniqueCustom = customExercises.filter { !catalogNames.contains($0.name.lowercased()) }
        return GymExerciseCatalog.all + uniqueCustom
    }

    func exercise(named name: String) -> GymExercise? {
        allExercises.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    // MARK: - Fetch
    func fetchCustomExercises(forceRefresh: Bool = false) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Usuario no autenticado"
            return
        }

        if !forceRefresh,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheTimeout,
           !customExercises.isEmpty {
            return
        }

        isLoading = true

        do {
            let snapshot = try await collection(userId: userId)
                .order(by: "name")
                .getDocuments()

            customExercises = snapshot.documents.compactMap { doc in
                var exercise = try? doc.data(as: GymExercise.self)
                exercise?.isCustom = true
                return exercise
            }
            lastFetchTime = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Create (Optimistic)
    func createExercise(_ exercise: GymExercise) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GymServiceError.notAuthenticated
        }

        var custom = exercise
        custom.isCustom = true
        customExercises.append(custom)
        customExercises.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        try collection(userId: userId).document(Self.documentID(for: custom.name)).setData(from: custom)
    }

    // MARK: - Delete (Optimistic)
    func deleteExercise(named name: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GymServiceError.notAuthenticated
        }

        customExercises.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }

        try await collection(userId: userId).document(Self.documentID(for: name)).delete()
    }

    func invalidateCache() {
        lastFetchTime = nil
    }
}

// MARK: - Favoritos (locales, por dispositivo)
enum ExerciseFavorites {
    private static let key = "gymFavoriteExercises"

    static func all() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func isFavorite(_ name: String) -> Bool {
        all().contains(name)
    }

    static func toggle(_ name: String) {
        var favorites = all()
        if favorites.contains(name) {
            favorites.remove(name)
        } else {
            favorites.insert(name)
        }
        UserDefaults.standard.set(Array(favorites), forKey: key)
    }
}
