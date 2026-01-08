import Foundation
import WatchConnectivity
import Combine

// MARK: - Watch Connectivity Service
@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()
    
    @Published var ejercicios: [WatchEjercicio] = []
    @Published var tabatas: [Tabata] = []
    @Published var weightUnit: WatchWeightUnit = .kg
    @Published var isConnected = false
    @Published var lastSyncDate: Date?
    @Published var activeRemoteTabata: Tabata? // Set when iPhone starts a Tabata
    
    private var session: WCSession?
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        
        // Load cached data asynchronously (don't block app startup)
        Task { @MainActor in
            loadCachedData()
            
            // Request fresh data after a short delay
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            requestDataFromPhone()
        }
    }

    
    // MARK: - Request Data from Phone
    func requestDataFromPhone() {
        guard let session = session else {
            print("📱 WCSession not available")
            return
        }
        
        // Check if reachable before attempting
        guard session.isReachable else {
            print("📱 iPhone not reachable - using cached data only")
            print("📱 Activation state: \(session.activationState.rawValue)")
            print("📱 Has content: \(session.hasContentPending)")
            print("📱 Application context: \(session.applicationContext.keys)")
            return
        }
        
        print("📱 Requesting ejercicios from iPhone...")
        
        session.sendMessage(["request": "ejercicios"], replyHandler: { [weak self] response in
            print("✅ Received ejercicios response from iPhone")
            Task { @MainActor in
                self?.handleResponse(response)
            }
        }, errorHandler: { error in
            print("❌ Error requesting data: \(error.localizedDescription)")
        })
        
        // Also request tabatas
        session.sendMessage(["request": "tabatas"], replyHandler: { [weak self] response in
            print("✅ Received tabatas response from iPhone")
            Task { @MainActor in
                self?.handleResponse(response)
            }
        }, errorHandler: { error in
            print("❌ Error requesting tabatas: \(error.localizedDescription)")
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
    
    // MARK: - Send New RM to Phone
    func sendNewRM(ejercicioId: String?, ejercicioName: String, valor: Double, completion: @escaping (Bool) -> Void) {
        guard let session = session else {
            completion(false)
            return
        }
        
        var message: [String: Any] = [
            "action": "saveRM",
            "ejercicioName": ejercicioName,
            "valor": valor,
            "fecha": Date().timeIntervalSince1970
        ]
        
        if let id = ejercicioId {
            message["ejercicioId"] = id
        }
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] response in
                Task { @MainActor in
                    if response["status"] as? String == "saved" {
                        // Refresh data from phone
                        self?.requestDataFromPhone()
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            }) { error in
                print("❌ Error sending RM: \(error.localizedDescription)")
                Task { @MainActor in
                    completion(false)
                }
            }
        } else {
            // Queue for later when phone becomes reachable
            session.transferUserInfo(message)
            completion(true) // Optimistically assume success
        }
    }
    
    // MARK: - Handle Response
    private func handleResponse(_ response: [String: Any]) {
        // Parse ejercicios
        if let ejerciciosData = response["ejercicios"] as? Data {
            do {

                let decoded = try JSONDecoder().decode([WatchEjercicio].self, from: ejerciciosData)
                self.ejercicios = decoded
                cacheData(ejerciciosData: ejerciciosData, tabatasData: nil)
            } catch {
                print("❌ Error decoding ejercicios: \(error)")
            }
        }
        
        // Parse weight unit
        if let unitString = response["weightUnit"] as? String,
           let unit = WatchWeightUnit(rawValue: unitString) {
            self.weightUnit = unit
        }
        
        // Parse tabatas
        if let tabatasData = response["tabatas"] as? Data {
            do {
                let decoded = try JSONDecoder().decode([Tabata].self, from: tabatasData)
                self.tabatas = decoded
                cacheData(ejerciciosData: nil, tabatasData: tabatasData)
                lastSyncDate = Date()
            } catch {
                print("❌ Error decoding tabatas: \(error)")
            }
        }
        
        // Handle remote Tabata start signal
        if let action = response["action"] as? String, action == "startTabata",
           let tabataData = response["tabata"] as? Data {
            do {
                let decoder = JSONDecoder()
                let tabata = try decoder.decode(Tabata.self, from: tabataData)
                self.activeRemoteTabata = tabata
                print("✅ Received remote Tabata start: \(tabata.name)")
            } catch {
                print("❌ Error decoding remote Tabata: \(error)")
            }
        }
    }
    
    // MARK: - Cache
    private func cacheData(ejerciciosData: Data?, tabatasData: Data?) {
        if let ejerciciosData = ejerciciosData {
            UserDefaults.standard.set(ejerciciosData, forKey: "cachedEjercicios")
        }
        if let tabatasData = tabatasData {
            UserDefaults.standard.set(tabatasData, forKey: "cachedTabatas")
        }
        UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
    }
    
    private func loadCachedData() {
        if let data = UserDefaults.standard.data(forKey: "cachedEjercicios") {
            do {
                ejercicios = try JSONDecoder().decode([WatchEjercicio].self, from: data)
            } catch {
                print("❌ Error loading cached ejercicios: \(error)")
            }
        }
        
        if let data = UserDefaults.standard.data(forKey: "cachedTabatas") {
            do {
                tabatas = try JSONDecoder().decode([Tabata].self, from: data)
            } catch {
                print("❌ Error loading cached tabatas: \(error)")
            }
        } else {
            // Default tabatas if nothing cached
            tabatas = Tabata.all
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
