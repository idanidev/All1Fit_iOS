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
            
            // Send initial data after a short delay to allow activation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Task { @MainActor in
                    await self.sendInitialDataToWatch()
                }
            }
        }
    }
    
    // MARK: - Send Initial Data
    private func sendInitialDataToWatch() async {
        guard let session = session, session.isPaired else { return }
        
        print("📱 Sending initial data to Watch...")
        
        // Fetch and send ejercicios (no reply needed for initial send)
        await fetchAndSendEjercicios(replyHandler: { _ in })
        
        // Fetch and send tabatas (no reply needed for initial send)
        await fetchAndSendTabatas(replyHandler: { _ in })
    }
    
    // MARK: - Send Ejercicios to Watch
    func sendEjerciciosToWatch(_ ejercicios: [Ejercicio]) {
        guard let session = session, session.isPaired else {
            print("⌚️ Watch not paired - can't send ejercicios")
            return
        }
        
        print("📱 Attempting to send \(ejercicios.count) ejercicios to Watch...")
        print("📱 Session paired: \(session.isPaired), reachable: \(session.isReachable)")
        
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
            
            var context = session.applicationContext
            context["ejercicios"] = data
            context["weightUnit"] = UserDefaults.standard.string(forKey: "weightUnit") ?? "kg"
            
            // Use application context for persistence
            try session.updateApplicationContext(context)
            print("✅ Successfully sent ejercicios via application context")
            
            // Also send immediately if reachable
            if session.isReachable {
                session.sendMessage(context, replyHandler: { response in
                    print("✅ Watch replied to sendMessage")
                }, errorHandler: { error in
                    print("⚠️ Error on sendMessage (not critical): \(error.localizedDescription)")
                })
            } else {
                print("⚠️ Watch not reachable - data sent via context only")
            }
        } catch {
            print("❌ Error sending ejercicios to watch: \(error)")
        }
    }
    
    // MARK: - Send Tabatas to Watch
    func sendTabatasToWatch(_ tabatas: [Tabata]) {
        guard let session = session, session.isPaired else { return }
        
        do {
            let data = try JSONEncoder().encode(tabatas)
            
            var context = session.applicationContext
            context["tabatas"] = data
            
            // Use application context
            try session.updateApplicationContext(context)
            
            // Also send immediately if reachable
            if session.isReachable {
                session.sendMessage(["tabatas": data], replyHandler: nil, errorHandler: nil)
            }
        } catch {
            print("❌ Error sending tabatas to watch: \(error)")
        }
    }
    
    // MARK: - Send Tabata Start Signal to Watch
    func sendTabataStartToWatch(_ tabata: Tabata) {
        guard let session = session, session.isPaired, session.isReachable else {
            print("⌚️ Watch not reachable - can't start Tabata remotely")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            let tabataData = try encoder.encode(tabata)
            
            session.sendMessage(
                ["action": "startTabata", "tabata": tabataData],
                replyHandler: { response in
                    print("✅ Watch received Tabata start command")
                },
                errorHandler: { error in
                    print("❌ Failed to send Tabata to Watch: \(error.localizedDescription)")
                }
            )
        } catch {
            print("❌ Failed to encode Tabata: \(error)")
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
    
    // MARK: - Handle RM Save from Watch
    private func handleSaveRM(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let userId = Auth.auth().currentUser?.uid,
              let ejercicioName = message["ejercicioName"] as? String,
              let valor = message["valor"] as? Double else {
            replyHandler?(["status": "error", "message": "Invalid data"])
            return
        }
        
        let fecha = message["fecha"] as? TimeInterval ?? Date().timeIntervalSince1970
        let ejercicioId = message["ejercicioId"] as? String
        
        let rmEntry: [String: Any] = [
            "valor": valor,
            "fecha": Timestamp(date: Date(timeIntervalSince1970: fecha))
        ]
        
        let ejerciciosRef = db.collection("users").document(userId).collection("ejercicios")
        
        if let existingId = ejercicioId {
            // Update existing ejercicio
            ejerciciosRef.document(existingId).updateData([
                "rmHistory": FieldValue.arrayUnion([rmEntry])
            ]) { error in
                if let error = error {
                    print("❌ Error updating RM from watch: \(error)")
                    replyHandler?(["status": "error"])
                } else {
                    print("✅ RM updated from watch")
                    replyHandler?(["status": "saved"])
                }
            }
        } else {
            // Create new ejercicio with this RM
            let newEjercicio: [String: Any] = [
                "name": ejercicioName,
                "rmHistory": [rmEntry],
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            ejerciciosRef.addDocument(data: newEjercicio) { error in
                if let error = error {
                    print("❌ Error creating ejercicio from watch: \(error)")
                    replyHandler?(["status": "error"])
                } else {
                    print("✅ New ejercicio created from watch")
                    replyHandler?(["status": "saved"])
                }
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
            } else if message["request"] as? String == "tabatas" {
                await self.fetchAndSendTabatas(replyHandler: replyHandler)
            } else if message["action"] as? String == "saveWorkoutResult" {
                self.handleWorkoutResult(message)
                replyHandler(["status": "saved"])
            } else if message["action"] as? String == "saveRM" {
                self.handleSaveRM(message, replyHandler: replyHandler)
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if message["action"] as? String == "saveWorkoutResult" {
                self.handleWorkoutResult(message)
            } else if message["action"] as? String == "saveRM" {
                self.handleSaveRM(message)
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            if userInfo["action"] as? String == "saveWorkoutResult" {
                self.handleWorkoutResult(userInfo)
            } else if userInfo["action"] as? String == "saveRM" {
                self.handleSaveRM(userInfo)
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
    
    @MainActor
    private func fetchAndSendTabatas(replyHandler: @escaping ([String: Any]) -> Void) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            replyHandler(["error": "Not authenticated"])
            return
        }
        
        // Start with default tabatas
        var allTabatas = Tabata.all
        
        do {
            // Fetch custom tabatas
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("tabatas")
                .getDocuments()
            
            let customTabatas = snapshot.documents.compactMap { try? $0.data(as: Tabata.self) }
            allTabatas.append(contentsOf: customTabatas)
            
            let data = try JSONEncoder().encode(allTabatas)
            replyHandler(["tabatas": data])
            
        } catch {
            print("❌ Error fetching tabatas for watch: \(error)")
            // If error, atleast send defaults
            if let data = try? JSONEncoder().encode(Tabata.all) {
                replyHandler(["tabatas": data])
            } else {
                replyHandler(["error": error.localizedDescription])
            }
        }
    }
}
