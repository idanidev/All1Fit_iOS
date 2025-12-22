import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Optimized Ejercicio Service (NO LISTENERS, WITH CACHE)
@MainActor
class EjercicioService: ObservableObject {
    @Published var ejercicios: [Ejercicio] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 30 // 30 seconds cache
    
    // MARK: - Collection Reference
    private func ejerciciosCollection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("ejercicios")
    }
    
    // MARK: - Fetch Ejercicios (ONE-TIME with Cache)
    func fetchEjercicios(forceRefresh: Bool = false) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Usuario no autenticado"
            return
        }
        
        // Check cache
        if !forceRefresh, let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheTimeout,
           !ejercicios.isEmpty {
            return // Use cached data
        }
        
        isLoading = ejercicios.isEmpty // Only show loading if no cached data
        
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
    
    // MARK: - Create Ejercicio (Optimistic Update)
    func createEjercicio(name: String, rm: Double) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }
        
        let ejercicio = Ejercicio(
            name: name,
            rmHistory: [RMEntry(valor: rm)]
        )
        
        // Optimistic update - add to local cache immediately
        var tempEjercicio = ejercicio
        tempEjercicio.id = UUID().uuidString
        ejercicios.append(tempEjercicio)
        ejercicios.sort { $0.name < $1.name }
        
        // Then persist to Firestore
        let docRef = try ejerciciosCollection(userId: userId).addDocument(from: ejercicio)
        
        // Update local copy with real ID
        if let index = ejercicios.firstIndex(where: { $0.id == tempEjercicio.id }) {
            ejercicios[index].id = docRef.documentID
        }
    }
    
    // MARK: - Add RM (Optimistic Update)
    func addRM(ejercicioId: String, valor: Double) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }
        
        // Optimistic update
        if let index = ejercicios.firstIndex(where: { $0.id == ejercicioId }) {
            ejercicios[index].rmHistory.append(RMEntry(valor: valor))
        }
        
        // Persist to Firestore
        let docRef = ejerciciosCollection(userId: userId).document(ejercicioId)
        let document = try await docRef.getDocument()
        
        guard var ejercicio = try? document.data(as: Ejercicio.self) else {
            throw EjercicioError.notFound
        }
        
        ejercicio.rmHistory.append(RMEntry(valor: valor))
        try docRef.setData(from: ejercicio)
    }
    
    // MARK: - Delete Ejercicio (Optimistic Update)
    func deleteEjercicio(id: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }
        
        // Optimistic update - remove from local cache immediately
        ejercicios.removeAll { $0.id == id }
        
        // Then delete from Firestore
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
