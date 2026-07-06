import Foundation
import WatchConnectivity
import FirebaseAuth
import FirebaseFirestore

// MARK: - Phone Connectivity Service (FIXED)
/// Servicio mejorado para sincronización iPhone ↔ Apple Watch
@MainActor
class PhoneConnectivityService: NSObject, ObservableObject {
    static let shared = PhoneConnectivityService()
    
    @Published var isWatchPaired = false
    @Published var isWatchReachable = false
    @Published var isWatchAppInstalled = false
    @Published var lastSyncDate: Date?

    private var session: WCSession?
    private let db = Firestore.firestore()
    private var pendingTabataStart: Tabata?
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        } else {
            debugLog("WCSession no soportado", category: Log.connectivity)
        }
    }
    
    // MARK: - Session State
    private func updateSessionState() {
        guard let session = session else { return }

        isWatchPaired = session.isPaired
        isWatchReachable = session.isReachable
        isWatchAppInstalled = session.isWatchAppInstalled
    }
    
    // MARK: - Send Ejercicios to Watch
    func sendEjerciciosToWatch(_ ejercicios: [Ejercicio]) {
        guard let session = session, session.isPaired else { return }

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
            let weightUnit = UserDefaults.standard.string(forKey: "weightUnit") ?? "kg"

            session.transferUserInfo([
                "ejercicios": data,
                "weightUnit": weightUnit,
                "timestamp": Date().timeIntervalSince1970
            ])

            lastSyncDate = Date()
        } catch {
            debugLog("Error syncing to Watch: \(error.localizedDescription)", category: Log.sync)
        }
    }
    
    // MARK: - Send Tabatas to Watch
    func sendTabatasToWatch(_ tabatas: [Tabata]) {
        guard let session = session, session.isPaired else { return }

        do {
            let data = try JSONEncoder().encode(tabatas)
            session.transferUserInfo([
                "tabatas": data,
                "timestamp": Date().timeIntervalSince1970
            ])
        } catch {
            debugLog("Error syncing tabatas: \(error.localizedDescription)", category: Log.sync)
        }
    }
    
    // MARK: - Send User Workouts to Watch
    func sendUserWorkoutsToWatch(_ workouts: [UserWorkout]) {
        guard let session = session, session.isPaired else { return }

        do {
            let data = try JSONEncoder().encode(workouts)
            session.transferUserInfo([
                "userWorkouts": data,
                "timestamp": Date().timeIntervalSince1970
            ])
        } catch {
            debugLog("Error syncing user workouts: \(error.localizedDescription)", category: Log.sync)
        }
    }

    // MARK: - Send Tabata Start Signal
    func sendTabataStartToWatch(_ tabata: Tabata) {
        guard let session = session, session.isPaired else { return }

        do {
            let tabataData = try JSONEncoder().encode(tabata)
            session.transferUserInfo([
                "action": "startTabata",
                "tabata": tabataData,
                "timestamp": Date().timeIntervalSince1970
            ])
            pendingTabataStart = tabata
        } catch {
            debugLog("Error starting tabata on Watch: \(error.localizedDescription)", category: Log.tabata)
        }
    }
    
    // MARK: - Send Tabata Stop Signal
    func sendTabataStopToWatch() {
        guard let session = session, session.isPaired, session.isWatchAppInstalled else { return }
        
        do {
            try session.updateApplicationContext([
                "action": "stopTabata",
                "timestamp": Date().timeIntervalSince1970
            ])
        } catch {
            debugLog("Error stopping tabata on Watch: \(error.localizedDescription)", category: Log.tabata)
        }
    }
    
    // MARK: - Force Sync All Data
    func forceSyncAllData() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        updateSessionState()
        debugLog("Forcing full sync...", category: Log.sync)
        
        // Fetch ejercicios
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("ejercicios")
                .order(by: "name")
                .getDocuments()
            
            let ejercicios = snapshot.documents.compactMap { doc in
                try? doc.data(as: Ejercicio.self)
            }
            
            sendEjerciciosToWatch(ejercicios)
        } catch {
            debugLog("Error fetching ejercicios: \(error)", category: Log.sync)
        }
        
        // Fetch tabatas (default + custom)
        var allTabatas = Tabata.all
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("tabatas")
                .getDocuments()
            
            let customTabatas = snapshot.documents.compactMap { try? $0.data(as: Tabata.self) }
            allTabatas.append(contentsOf: customTabatas)
            
            sendTabatasToWatch(allTabatas)
        } catch {
            debugLog("Error fetching tabatas: \(error)", category: Log.sync)
        }
    }
    
    // MARK: - Handle Messages from Watch
    private func handleWatchMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        if let request = message["request"] as? String {
            switch request {
            case "ejercicios":
                Task { @MainActor in
                    await fetchAndSendEjercicios(replyHandler: replyHandler ?? { _ in })
                }
            case "tabatas":
                Task { @MainActor in
                    await fetchAndSendTabatas(replyHandler: replyHandler ?? { _ in })
                }
            case "sync":
                Task { @MainActor in
                    await forceSyncAllData()
                    replyHandler?(["status": "syncing"])
                }
            default:
                replyHandler?(["error": "Unknown request"])
            }
        } else if let action = message["action"] as? String {
            switch action {
            case "saveWorkoutResult":
                handleWorkoutResult(message)
                replyHandler?(["status": "saved"])
            case "saveRM":
                handleSaveRM(message, replyHandler: replyHandler)
            default:
                replyHandler?(["error": "Unknown action"])
            }
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
                    debugLog("Error saving Watch result: \(error)", category: Log.sync)
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
            ejerciciosRef.document(existingId).updateData([
                "rmHistory": FieldValue.arrayUnion([rmEntry])
            ]) { error in
                if let error = error {
                    debugLog("Error updating RM from Watch: \(error)", category: Log.sync)
                    replyHandler?(["status": "error"])
                } else {
                    replyHandler?(["status": "saved"])
                    Task { @MainActor in
                        await self.forceSyncAllData()
                    }
                }
            }
        } else {
            let newEjercicio: [String: Any] = [
                "name": ejercicioName,
                "rmHistory": [rmEntry],
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            ejerciciosRef.addDocument(data: newEjercicio) { error in
                if let error = error {
                    debugLog("Error creating ejercicio from Watch: \(error)", category: Log.sync)
                    replyHandler?(["status": "error"])
                } else {
                    replyHandler?(["status": "saved"])
                    Task { @MainActor in
                        await self.forceSyncAllData()
                    }
                }
            }
        }
    }
    
    // MARK: - Fetch and Send Helpers
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
                "weightUnit": UserDefaults.standard.string(forKey: "weightUnit") ?? "kg",
                "count": ejercicios.count
            ])
            
            print("✅ Enviados \(ejercicios.count) ejercicios al Watch via reply")
            
        } catch {
            debugLog("Error fetching ejercicios: \(error)", category: Log.sync)
            replyHandler(["error": error.localizedDescription])
        }
    }
    
    @MainActor
    private func fetchAndSendTabatas(replyHandler: @escaping ([String: Any]) -> Void) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            // Si no hay usuario, enviar solo los default
            if let data = try? JSONEncoder().encode(Tabata.all) {
                replyHandler(["tabatas": data])
            } else {
                replyHandler(["error": "Not authenticated"])
            }
            return
        }
        
        var allTabatas = Tabata.all
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("tabatas")
                .getDocuments()
            
            let customTabatas = snapshot.documents.compactMap { try? $0.data(as: Tabata.self) }
            allTabatas.append(contentsOf: customTabatas)
            
            let data = try JSONEncoder().encode(allTabatas)
            replyHandler(["tabatas": data, "count": allTabatas.count])
            
        } catch {
            debugLog("Error fetching tabatas: \(error)", category: Log.sync)
            if let data = try? JSONEncoder().encode(Tabata.all) {
                replyHandler(["tabatas": data])
            } else {
                replyHandler(["error": error.localizedDescription])
            }
        }
    }
}

// MARK: - WCSession Delegate
extension PhoneConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            guard error == nil else { return }

            self.updateSessionState()

            if activationState == .activated && session.isPaired {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self.forceSyncAllData()
            }
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // Session became inactive
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            debugLog("Watch reachability changed: \(session.isReachable)", category: Log.connectivity)
            
            if session.isReachable {
                // Resend pending Tabata start
                if let pending = self.pendingTabataStart {
                    debugLog("Reenviando Tabata pendiente al Watch", category: Log.tabata)
                    self.sendTabataStartToWatch(pending)
                    self.pendingTabataStart = nil
                }
                
                // Check if there's an active Tabata session and resync
                let sessionManager = TabataSessionManager.shared
                if sessionManager.isActive, let activeTabata = sessionManager.activeTabata {
                    debugLog("Resincronizando Tabata activo al Watch", category: Log.tabata)
                    self.sendTabataStartToWatch(activeTabata)
                }
            }
        }
    }
    
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.updateSessionState()

            if session.isPaired {
                await self.forceSyncAllData()
            }
        }
    }
    
    // Handle messages WITH reply
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            self.handleWatchMessage(message, replyHandler: replyHandler)
        }
    }
    
    // Handle messages WITHOUT reply
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handleWatchMessage(message, replyHandler: nil)
        }
    }
    
    // Handle user info transfers
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.handleWatchMessage(userInfo, replyHandler: nil)
        }
    }
    
    // Handle application context updates from Watch
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.handleWatchMessage(applicationContext, replyHandler: nil)
        }
    }
}
