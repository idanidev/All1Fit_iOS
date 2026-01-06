import Foundation
import WatchConnectivity
import FirebaseAuth
import FirebaseFirestore

// MARK: - Phone Connectivity Service
/// Add this to your iOS app to sync data with Apple Watch
@MainActor
class PhoneConnectivityService: NSObject, ObservableObject {
    static let shared = PhoneConnectivityService()
    
    @Published var isWatchPaired = false
    @Published var isWatchReachable = false
    
    private var session: WCSession?
    private let db = Firestore.firestore()
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    // MARK: - Send Ejercicios to Watch
    func sendEjerciciosToWatch(_ ejercicios: [Ejercicio]) {
        guard let session = session, session.isPaired else { return }
        
        // Convert to WatchEjercicio format
        let watchEjercicios = ejercicios.map { ejercicio -> [String: Any] in
            let rmHistory = ejercicio.rmHistory.map { rm -> [String: Any] in
                ["valor": rm.valor, "fecha": rm.fecha.timeIntervalSince1970]
            }
            return [
                "id": ejercicio.id ?? "",
                "name": ejercicio.name,
                "rmHistory": rmHistory
            ]
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: watchEjercicios)
            
            let context: [String: Any] = [
                "ejercicios": data,
                "weightUnit": UserDefaults.standard.string(forKey: "weightUnit") ?? "kg"
            ]
            
            // Use application context for persistence
            try session.updateApplicationContext(context)
            
            // Also send immediately if reachable
            if session.isReachable {
                session.sendMessage(context, replyHandler: nil, errorHandler: nil)
            }
        } catch {
            print("❌ Error sending ejercicios to watch: \(error)")
        }
    }
    
    // MARK: - Handle Workout Result from Watch
    private func handleWorkoutResult(_ message: [String: Any]) {
        guard let userId = Auth.auth().currentUser?.uid,
              let workoutId = message["workoutId"] as? String,
              let timeSeconds = message["timeSeconds"] as? Int else {
            return
        }
        
        var resultData: [String: Any] = [
            "workoutId": workoutId,
            "userId": userId,
            "timeSeconds": timeSeconds,
            "date": FieldValue.serverTimestamp()
        ]
        
        if let rounds = message["rounds"] as? Int {
            resultData["rounds"] = rounds
        }
        if let notes = message["notes"] as? String {
            resultData["notes"] = notes
        }
        
        db.collection("users")
            .document(userId)
            .collection("workoutResults")
            .addDocument(data: resultData) { error in
                if let error = error {
                    print("❌ Error saving watch workout result: \(error)")
                } else {
                    print("✅ Watch workout result saved")
                }
            }
    }
}

// MARK: - WCSession Delegate
extension PhoneConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isWatchPaired = session.isPaired
            self.isWatchReachable = session.isReachable
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
        }
    }
    
    // Handle messages from watch
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            if message["request"] as? String == "ejercicios" {
                // Watch is requesting data - fetch and send
                await self.fetchAndSendEjercicios(replyHandler: replyHandler)
            } else if message["action"] as? String == "saveWorkoutResult" {
                self.handleWorkoutResult(message)
                replyHandler(["status": "saved"])
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if message["action"] as? String == "saveWorkoutResult" {
                self.handleWorkoutResult(message)
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            if userInfo["action"] as? String == "saveWorkoutResult" {
                self.handleWorkoutResult(userInfo)
            }
        }
    }
    
    // MARK: - Fetch and Send
    @MainActor
    private func fetchAndSendEjercicios(replyHandler: @escaping ([String: Any]) -> Void) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            replyHandler(["error": "Not authenticated"])
            return
        }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("ejercicios")
                .order(by: "name")
                .getDocuments()
            
            let ejercicios: [[String: Any]] = snapshot.documents.compactMap { doc in
                guard let name = doc.data()["name"] as? String else { return nil }
                
                let rmHistory: [[String: Any]]
                if let history = doc.data()["rmHistory"] as? [[String: Any]] {
                    rmHistory = history.map { rm in
                        var entry: [String: Any] = ["valor": rm["valor"] ?? 0]
                        if let fecha = rm["fecha"] as? Timestamp {
                            entry["fecha"] = fecha.dateValue().timeIntervalSince1970
                        } else if let fecha = rm["fecha"] as? Date {
                            entry["fecha"] = fecha.timeIntervalSince1970
                        }
                        return entry
                    }
                } else {
                    rmHistory = []
                }
                
                return [
                    "id": doc.documentID,
                    "name": name,
                    "rmHistory": rmHistory
                ]
            }
            
            let data = try JSONSerialization.data(withJSONObject: ejercicios)
            
            replyHandler([
                "ejercicios": data,
                "weightUnit": UserDefaults.standard.string(forKey: "weightUnit") ?? "kg"
            ])
        } catch {
            print("❌ Error fetching ejercicios for watch: \(error)")
            replyHandler(["error": error.localizedDescription])
        }
    }
}
