import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Ejercicio Service (iOS 26 Optimized with Cache)
@MainActor
@Observable
class EjercicioService: ObservableObject {
    var ejercicios: [Ejercicio] = []
    var isLoading = false
    var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 30
    
    // MARK: - Collection Reference
    private func ejerciciosCollection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("ejercicios")
    }
    
    // MARK: - Fetch
    func fetchEjercicios(forceRefresh: Bool = false) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Usuario no autenticado"
            return
        }
        
        // Check cache
        if !forceRefresh,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheTimeout,
           !ejercicios.isEmpty {
            return
        }
        
        isLoading = true
        
        do {
            let snapshot = try await ejerciciosCollection(userId: userId)
                .order(by: "name")
                .getDocuments()
            
            ejercicios = snapshot.documents.compactMap { doc in
                try? doc.data(as: Ejercicio.self)
            }
            lastFetchTime = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Create (Optimistic)
    func createEjercicio(name: String, rm: Double) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }
        
        let ejercicio = Ejercicio(
            name: name,
            rmHistory: [RMEntry(valor: rm)]
        )
        
        // Optimistic update
        var tempEjercicio = ejercicio
        tempEjercicio.id = UUID().uuidString
        ejercicios.append(tempEjercicio)
        ejercicios.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        // Persist
        let docRef = try ejerciciosCollection(userId: userId).addDocument(from: ejercicio)
        
        // Update with real ID
        if let index = ejercicios.firstIndex(where: { $0.id == tempEjercicio.id }) {
            ejercicios[index].id = docRef.documentID
        }
    }
    
    // MARK: - Add RM (Optimistic)
    func addRM(ejercicioId: String, valor: Double) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }
        
        // Optimistic update
        if let index = ejercicios.firstIndex(where: { $0.id == ejercicioId }) {
            ejercicios[index].rmHistory.append(RMEntry(valor: valor))
        }
        
        // Persist
        let docRef = ejerciciosCollection(userId: userId).document(ejercicioId)
        let document = try await docRef.getDocument()
        
        guard var ejercicio = try? document.data(as: Ejercicio.self) else {
            throw EjercicioError.notFound
        }
        
        ejercicio.rmHistory.append(RMEntry(valor: valor))
        try docRef.setData(from: ejercicio)
    }
    
    // MARK: - Delete (Optimistic)
    func deleteEjercicio(id: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }
        
        // Optimistic update
        ejercicios.removeAll { $0.id == id }
        
        // Persist
        try await ejerciciosCollection(userId: userId).document(id).delete()
    }
    
    // MARK: - Invalidate Cache
    func invalidateCache() {
        lastFetchTime = nil
    }
}

// MARK: - Errors
enum EjercicioError: LocalizedError {
    case notAuthenticated
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Usuario no autenticado"
        case .notFound: return "Ejercicio no encontrado"
        }
    }
}