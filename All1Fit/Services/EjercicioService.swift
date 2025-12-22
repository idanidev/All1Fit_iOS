import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Ejercicio Service
@MainActor
class EjercicioService: ObservableObject {
    @Published var ejercicios: [Ejercicio] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Collection Reference
    private func ejerciciosCollection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("ejercicios")
    }
    
    // MARK: - Fetch Ejercicios (Real-time listener)
    func fetchEjercicios() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Usuario no autenticado"
            return
        }
        
        isLoading = true
        
        listener?.remove()
        listener = ejerciciosCollection(userId: userId)
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.ejercicios = []
                        return
                    }
                    
                    self?.ejercicios = documents.compactMap { doc in
                        try? doc.data(as: Ejercicio.self)
                    }
                }
            }
    }
    
    // MARK: - Create Ejercicio
    func createEjercicio(name: String, rm: Double) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }
        
        let ejercicio = Ejercicio(
            name: name,
            rmHistory: [RMEntry(valor: rm)]
        )
        
        try ejerciciosCollection(userId: userId).addDocument(from: ejercicio)
    }
    
    // MARK: - Add RM to existing Ejercicio
    func addRM(ejercicioId: String, valor: Double) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }
        
        let newEntry = RMEntry(valor: valor)
        
        // Get current ejercicio
        let docRef = ejerciciosCollection(userId: userId).document(ejercicioId)
        let document = try await docRef.getDocument()
        
        guard var ejercicio = try? document.data(as: Ejercicio.self) else {
            throw EjercicioError.notFound
        }
        
        ejercicio.rmHistory.append(newEntry)
        
        try docRef.setData(from: ejercicio)
    }
    
    // MARK: - Delete Ejercicio
    func deleteEjercicio(id: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }
        
        try await ejerciciosCollection(userId: userId).document(id).delete()
    }
    
    // MARK: - Stop Listening
    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

// MARK: - Errors
enum EjercicioError: LocalizedError {
    case notAuthenticated
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Usuario no autenticado"
        case .notFound:
            return "Ejercicio no encontrado"
        }
    }
}
