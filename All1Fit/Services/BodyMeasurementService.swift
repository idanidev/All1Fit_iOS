import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Body Measurement Service (medidas corporales)
@MainActor
class BodyMeasurementService: ObservableObject {
    @Published var measurements: [BodyMeasurement] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 30

    private func measurementsCollection(userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("bodyMeasurements")
    }

    // MARK: - Fetch
    func fetchMeasurements(forceRefresh: Bool = false) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Usuario no autenticado"
            return
        }

        if !forceRefresh,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheTimeout,
           !measurements.isEmpty {
            return
        }

        isLoading = true

        do {
            let snapshot = try await measurementsCollection(userId: userId)
                .order(by: "date", descending: true)
                .limit(to: 200)
                .getDocuments()

            measurements = snapshot.documents.compactMap { doc in
                try? doc.data(as: BodyMeasurement.self)
            }
            lastFetchTime = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Add (Optimistic)
    func addMeasurement(_ measurement: BodyMeasurement) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GymServiceError.notAuthenticated
        }

        var temp = measurement
        temp.id = UUID().uuidString
        measurements.insert(temp, at: 0)
        measurements.sort { $0.date > $1.date }

        let docRef = try measurementsCollection(userId: userId).addDocument(from: measurement)

        if let index = measurements.firstIndex(where: { $0.id == temp.id }) {
            measurements[index].id = docRef.documentID
        }
    }

    // MARK: - Delete (Optimistic)
    func deleteMeasurement(id: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw GymServiceError.notAuthenticated
        }

        measurements.removeAll { $0.id == id }

        try await measurementsCollection(userId: userId).document(id).delete()
    }

    // MARK: - Consultas

    /// Historial de peso corporal (para gráfica)
    var weightHistory: [(date: Date, weight: Double)] {
        measurements
            .compactMap { m in m.weight.map { (m.date, $0) } }
            .sorted { $0.0 < $1.0 }
    }

    var latestWeight: Double? {
        measurements.sorted { $0.date > $1.date }.first(where: { $0.weight != nil })?.weight
    }

    func invalidateCache() {
        lastFetchTime = nil
    }
}
