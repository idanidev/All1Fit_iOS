import Foundation
import WatchConnectivity
import Combine

// MARK: - Watch Connectivity Service
@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()
    
    @Published var ejercicios: [WatchEjercicio] = []
    @Published var weightUnit: WatchWeightUnit = .kg
    @Published var isConnected = false
    @Published var lastSyncDate: Date?
    
    private var session: WCSession?
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        
        // Load cached data
        loadCachedData()
    }
    
    // MARK: - Request Data from Phone
    func requestDataFromPhone() {
        guard let session = session, session.isReachable else {
            print("📱 iPhone not reachable")
            return
        }
        
        session.sendMessage(["request": "ejercicios"], replyHandler: { [weak self] response in
            Task { @MainActor in
                self?.handleResponse(response)
            }
        }, errorHandler: { error in
            print("❌ Error requesting data: \(error.localizedDescription)")
        })
    }
    
    // MARK: - Send Workout Result to Phone
    func sendWorkoutResult(workoutId: String, timeSeconds: Int, rounds: Int?, notes: String?) {
        guard let session = session else { return }
        
        var message: [String: Any] = [
            "action": "saveWorkoutResult",
            "workoutId": workoutId,
            "timeSeconds": timeSeconds,
            "date": Date().timeIntervalSince1970
        ]
        
        if let rounds = rounds {
            message["rounds"] = rounds
        }
        if let notes = notes {
            message["notes"] = notes
        }
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("❌ Error sending result: \(error.localizedDescription)")
            }
        } else {
            // Queue for later
            session.transferUserInfo(message)
        }
    }
    
    // MARK: - Handle Response
    private func handleResponse(_ response: [String: Any]) {
        // Parse ejercicios
        if let ejerciciosData = response["ejercicios"] as? Data {
            do {
                let decoded = try JSONDecoder().decode([WatchEjercicio].self, from: ejerciciosData)
                self.ejercicios = decoded
                cacheData(ejerciciosData)
            } catch {
                print("❌ Error decoding ejercicios: \(error)")
            }
        }
        
        // Parse weight unit
        if let unitString = response["weightUnit"] as? String,
           let unit = WatchWeightUnit(rawValue: unitString) {
            self.weightUnit = unit
        }
        
        lastSyncDate = Date()
    }
    
    // MARK: - Cache
    private func cacheData(_ data: Data) {
        UserDefaults.standard.set(data, forKey: "cachedEjercicios")
        UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
    }
    
    private func loadCachedData() {
        if let data = UserDefaults.standard.data(forKey: "cachedEjercicios") {
            do {
                ejercicios = try JSONDecoder().decode([WatchEjercicio].self, from: data)
            } catch {
                print("❌ Error loading cache: \(error)")
            }
        }
        
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }
}

// MARK: - WCSession Delegate
extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isConnected = activationState == .activated
            if activationState == .activated {
                self.requestDataFromPhone()
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handleResponse(message)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.handleResponse(applicationContext)
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isConnected = session.isReachable
            if session.isReachable {
                self.requestDataFromPhone()
            }
        }
    }
}
