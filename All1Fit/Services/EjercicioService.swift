import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Ejercicio Service (iOS 26 Optimized with Cache)
@MainActor
class EjercicioService: ObservableObject {
    @Published var ejercicios: [Ejercicio] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
            
            // Auto-sync with Apple Watch
            PhoneConnectivityService.shared.sendEjerciciosToWatch(ejercicios)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Create (Optimistic)
    func createEjercicio(name: String, rm: Double, style: EjercicioStyle = .barbell) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }

        let ejercicio = Ejercicio(
            name: name,
            rmHistory: [RMEntry(valor: rm)],
            style: style
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
    func addRM(ejercicioId: String, valor: Double, reps: Int? = nil) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }

        let entry = RMEntry(valor: valor, reps: reps)

        // Optimistic update
        if let index = ejercicios.firstIndex(where: { $0.id == ejercicioId }) {
            ejercicios[index].rmHistory.append(entry)
        }

        // Persist with arrayUnion — single write, no fetch needed
        var entryData: [String: Any] = [
            "valor": entry.valor,
            "fecha": Timestamp(date: entry.fecha)
        ]
        if let reps { entryData["reps"] = reps }
        try await ejerciciosCollection(userId: userId)
            .document(ejercicioId)
            .updateData(["rmHistory": FieldValue.arrayUnion([entryData])])
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

    // MARK: - Update Ejercicio (name + style)
    func updateEjercicio(id: String, name: String, style: EjercicioStyle) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }
        if let index = ejercicios.firstIndex(where: { $0.id == id }) {
            ejercicios[index].name = name
            ejercicios[index].style = style
        }
        ejercicios.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        try await ejerciciosCollection(userId: userId).document(id).updateData([
            "name": name,
            "style": style.rawValue
        ])
    }

    // MARK: - Delete Single RM Entry (rewrites entire array)
    func deleteRMEntry(ejercicioId: String, entryId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }
        if let index = ejercicios.firstIndex(where: { $0.id == ejercicioId }) {
            ejercicios[index].rmHistory.removeAll { $0.id == entryId }
        }
        guard let exIndex = ejercicios.firstIndex(where: { $0.id == ejercicioId }) else { return }
        let historyData: [[String: Any]] = ejercicios[exIndex].rmHistory.map { e in
            var d: [String: Any] = ["valor": e.valor, "fecha": Timestamp(date: e.fecha)]
            if let reps = e.reps { d["reps"] = reps }
            return d
        }
        try await ejerciciosCollection(userId: userId).document(ejercicioId).updateData(["rmHistory": historyData])
    }

    // MARK: - Update Single RM Entry (rewrites entire array)
    func updateRMEntry(ejercicioId: String, entryId: String, newValor: Double, newReps: Int?) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw EjercicioError.notAuthenticated
        }
        if let exIndex = ejercicios.firstIndex(where: { $0.id == ejercicioId }),
           let entryIndex = ejercicios[exIndex].rmHistory.firstIndex(where: { $0.id == entryId }) {
            let old = ejercicios[exIndex].rmHistory[entryIndex]
            ejercicios[exIndex].rmHistory[entryIndex] = RMEntry(valor: newValor, fecha: old.fecha, reps: newReps)
        }
        guard let exIndex = ejercicios.firstIndex(where: { $0.id == ejercicioId }) else { return }
        let historyData: [[String: Any]] = ejercicios[exIndex].rmHistory.map { e in
            var d: [String: Any] = ["valor": e.valor, "fecha": Timestamp(date: e.fecha)]
            if let reps = e.reps { d["reps"] = reps }
            return d
        }
        try await ejerciciosCollection(userId: userId).document(ejercicioId).updateData(["rmHistory": historyData])
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