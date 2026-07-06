import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Tabata Service
@MainActor
class TabataService: ObservableObject {
    @Published var customTabatas: [Tabata] = []
    @Published var tabataResults: [String: [TabataResult]] = [:] // tabataId -> results
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    private var lastFetchAll: Date?
    private let cacheInterval: TimeInterval = 30

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - All Tabatas (predefined + custom)
    
    var allTabatas: [Tabata] {
        Tabata.all + customTabatas
    }
    
    var intervalTabatas: [Tabata] {
        allTabatas.filter { $0.type == .intervals }
    }
    
    var treadmillTabatas: [Tabata] {
        allTabatas.filter { $0.type == .treadmill }
    }
    
    // MARK: - Fetch Custom Tabatas
    
    func fetchTabatas() async {
        guard let userId = userId else { return }
        
        isLoading = true
        error = nil
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("tabatas")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            customTabatas = snapshot.documents.compactMap { doc in
                try? doc.data(as: Tabata.self)
            }
        } catch {
            self.error = "Error al cargar tabatas: \(error.localizedDescription)"
            print("❌ Error fetching tabatas: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Save Custom Tabata
    
    func saveTabata(_ tabata: Tabata) async throws {
        guard let userId = userId else {
            throw NSError(domain: "TabataService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no autenticado"])
        }
        
        var newTabata = tabata
        // Ensure it's marked as custom with creation date
        newTabata = Tabata(
            id: tabata.id,
            name: tabata.name,
            type: tabata.type,
            workSeconds: tabata.workSeconds,
            restSeconds: tabata.restSeconds,
            rounds: tabata.rounds,
            sets: tabata.sets,
            setRestSeconds: tabata.setRestSeconds,
            treadmillPhases: tabata.treadmillPhases,
            exercises: tabata.exercises,
            isCustom: true,
            createdAt: Date()
        )
        
        try db.collection("users")
            .document(userId)
            .collection("tabatas")
            .document(newTabata.id)
            .setData(from: newTabata)
        
        // Update local state
        if let index = customTabatas.firstIndex(where: { $0.id == newTabata.id }) {
            customTabatas[index] = newTabata
        } else {
            customTabatas.insert(newTabata, at: 0)
        }
    }
    
    // MARK: - Delete Custom Tabata
    
    func deleteTabata(_ tabata: Tabata) async throws {
        guard let userId = userId else {
            throw NSError(domain: "TabataService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no autenticado"])
        }
        
        guard tabata.isCustom else {
            throw NSError(domain: "TabataService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No se pueden eliminar tabatas predefinidos"])
        }
        
        try await db.collection("users")
            .document(userId)
            .collection("tabatas")
            .document(tabata.id)
            .delete()
        
        customTabatas.removeAll { $0.id == tabata.id }
    }
    
    // MARK: - Save Tabata Result
    
    func saveResult(_ result: TabataResult) async throws {
        guard let userId = userId else {
            throw NSError(domain: "TabataService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Usuario no autenticado"])
        }
        
        try db.collection("users")
            .document(userId)
            .collection("tabataResults")
            .document(result.id)
            .setData(from: result)
        
        // Update local state
        if tabataResults[result.tabataId] == nil {
            tabataResults[result.tabataId] = []
        }
        tabataResults[result.tabataId]?.insert(result, at: 0)
    }
    
    // MARK: - Fetch All Tabata Results (single query)

    func fetchAllResults(forceRefresh: Bool = false) async {
        guard let userId = userId else { return }
        if !forceRefresh, let last = lastFetchAll, Date().timeIntervalSince(last) < cacheInterval { return }

        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("tabataResults")
                .getDocuments()

            var grouped: [String: [TabataResult]] = [:]
            for doc in snapshot.documents {
                guard let result = try? doc.data(as: TabataResult.self) else { continue }
                grouped[result.tabataId, default: []].append(result)
            }
            for key in grouped.keys {
                grouped[key]?.sort { $0.completedAt > $1.completedAt }
            }
            tabataResults = grouped
            lastFetchAll = Date()
        } catch {
            print("❌ fetchAllResults error: \(error)")
        }
    }

    // MARK: - Fetch Results for a Tabata

    func fetchResults(for tabataId: String) async {
        guard let userId = userId else { return }

        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("tabataResults")
                .whereField("tabataId", isEqualTo: tabataId)
                .order(by: "completedAt", descending: true)
                .limit(to: 20)
                .getDocuments()

            let results = snapshot.documents.compactMap { try? $0.data(as: TabataResult.self) }
            tabataResults[tabataId] = results
        } catch {
            print("❌ Error fetching tabata results: \(error)")
        }
    }
    
    // MARK: - Get Last Result
    
    func lastResult(for tabataId: String) -> TabataResult? {
        tabataResults[tabataId]?.first
    }
    
    func resultCount(for tabataId: String) -> Int {
        tabataResults[tabataId]?.count ?? 0
    }
}
