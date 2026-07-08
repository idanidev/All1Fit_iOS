import Foundation
import WatchConnectivity
import Combine
import WatchKit

// MARK: - Watch Connectivity Service (FIXED)
/// Servicio mejorado para sincronización Apple Watch ↔ iPhone
@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()
    
    @Published var ejercicios: [WatchEjercicio] = []
    @Published var tabatas: [Tabata] = []
    @Published var userWorkouts: [WatchUserWorkout] = []
    @Published var weightUnit: WatchWeightUnit = .kg
    @Published var isConnected = false
    @Published var isPhoneReachable = false
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle
    @Published var activeRemoteTabata: Tabata?
    /// Sesión de gym activa espejada desde el iPhone
    @Published var activeGymSession: WatchGymSession?
    /// Toggles locales aún no confirmados por el iPhone (setId → completed).
    /// Evita que un espejo desfasado revierta visualmente un tap reciente.
    private var pendingGymToggles: [String: Bool] = [:]
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success
        case error(String)
    }
    
    private var session: WCSession?
    private var retryCount = 0
    private let maxRetries = 3
    
    override init() {
        super.init()

        // Cargar cache en background para NO bloquear UI
        Task { [weak self] in
            self?.loadCachedDataBackground()
        }

        // Configurar WCSession
        if WCSession.isSupported() {
            let wcSession = WCSession.default
            wcSession.delegate = self
            session = wcSession
            wcSession.activate()
        }
    }
    
    // MARK: - Request Data from Phone (OPTIMIZADO)
    func requestDataFromPhone() {
        // Capturar session localmente para evitar problemas de concurrencia
        guard let session = session else {
            syncStatus = .error("Session no disponible")
            return
        }

        // Ejecutar en background para NO bloquear UI
        Task { [weak self] in
            guard let self = self else { return }

            // Verificar que la sesión esté activada
            guard session.activationState == .activated else {
                print("⚠️ WCSession no activada aún")
                await MainActor.run {
                    self.syncStatus = .error("Esperando activación...")
                }

                // Reintentar en 1 segundo
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.requestDataFromPhone()
                return
            }

            // Primero, verificar si hay datos en applicationContext (RÁPIDO)
            if !session.receivedApplicationContext.isEmpty {
                print("⚚ Usando applicationContext (RÁPIDO)")
                await self.handleReceivedData(session.receivedApplicationContext)
            }

            // Si el iPhone está reachable, solicitar datos frescos EN PARALELO
            if session.isReachable {
                await MainActor.run { self.syncStatus = .syncing }

                // Solicitar ejercicios y tabatas EN PARALELO para máxima velocidad
                session.sendMessage(
                    ["request": "ejercicios"],
                    replyHandler: { [weak self] response in
                        Task { @MainActor in
                            await self?.handleReceivedData(response)
                            self?.syncStatus = .success
                            self?.retryCount = 0
                        }
                    },
                    errorHandler: { [weak self] error in
                        Task { @MainActor in
                            print("❌ Error ejercicios: \(error.localizedDescription)")
                            self?.handleSyncError(error)
                        }
                    }
                )

                session.sendMessage(
                    ["request": "tabatas"],
                    replyHandler: { [weak self] response in
                        Task { @MainActor in
                            await self?.handleReceivedData(response)
                        }
                    },
                    errorHandler: { error in
                        print("⚠️ Error tabatas: \(error.localizedDescription)")
                    }
                )
            } else {
                print("⌚️ iPhone no reachable - usando cache")
                await MainActor.run {
                    self.syncStatus = self.ejercicios.isEmpty ? .error("iPhone no conectado") : .idle
                }
            }
        }
    }
    
    // MARK: - Handle Sync Error
    private func handleSyncError(_ error: Error) {
        retryCount += 1
        
        if retryCount < maxRetries {
            print("⌚️ Reintentando sync (\(retryCount)/\(maxRetries))...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.requestDataFromPhone()
            }
        } else {
            syncStatus = .error("No se pudo conectar")
            retryCount = 0
        }
    }
    
    // MARK: - Handle Received Data (OPTIMIZADO - Background Processing)
    private func handleReceivedData(_ data: [String: Any]) async {
        // Procesar datos (decodificación se hace en background automáticamente)
        var newEjercicios: [WatchEjercicio]?
        var newTabatas: [Tabata]?
        var newUnit: WatchWeightUnit?
        var newRemoteTabata: Tabata?

        // Decodificar ejercicios (CPU intensivo)
        if let ejerciciosData = data["ejercicios"] as? Data {
            if let decoded = try? JSONDecoder().decode([WatchEjercicio].self, from: ejerciciosData) {
                newEjercicios = decoded
                cacheData(ejerciciosData: ejerciciosData, tabatasData: nil)
                print("✅ Decoded \(decoded.count) ejercicios")
            } else if let array = try? JSONSerialization.jsonObject(with: ejerciciosData) as? [[String: Any]] {
                newEjercicios = parseEjerciciosFromDictArray(array)
                print("✅ Parsed \(newEjercicios?.count ?? 0) ejercicios")
            }
        }

        // Decodificar weight unit
        if let unitString = data["weightUnit"] as? String,
           let unit = WatchWeightUnit(rawValue: unitString) {
            newUnit = unit
            UserDefaults.standard.set(unitString, forKey: "weightUnit")
        }

        // Decodificar tabatas
        if let tabatasData = data["tabatas"] as? Data,
           let decoded = try? JSONDecoder().decode([Tabata].self, from: tabatasData) {
            newTabatas = decoded
            cacheData(ejerciciosData: nil, tabatasData: tabatasData)
            print("✅ Decoded \(decoded.count) tabatas")
        }

        // Decodificar user workouts
        if let workoutsData = data["userWorkouts"] as? Data,
           let decoded = try? JSONDecoder().decode([WatchUserWorkout].self, from: workoutsData) {
            await MainActor.run { self.userWorkouts = decoded }
            UserDefaults.standard.set(workoutsData, forKey: "cachedUserWorkouts")
            print("✅ Decoded \(decoded.count) user workouts")
        }

        // Decodificar Tabata remoto
        if let action = data["action"] as? String, action == "startTabata",
           let tabataData = data["tabata"] as? Data,
           let tabata = try? JSONDecoder().decode(Tabata.self, from: tabataData) {
            newRemoteTabata = tabata
            WKInterfaceDevice.current().play(.notification)
            print("📲 Tabata remoto recibido: \(tabata.name)")
        } else if let pendingAction = data["pendingTabataAction"] as? String,
                  pendingAction == "start",
                  let tabataData = data["pendingTabata"] as? Data,
                  let tabata = try? JSONDecoder().decode(Tabata.self, from: tabataData) {
            newRemoteTabata = tabata
            WKInterfaceDevice.current().play(.notification)
            print("📲 Tabata pendiente recibido: \(tabata.name)")
        }
        
        // Sesión de gym espejada (applicationContext = último estado)
        if let gymData = data["gymSession"] as? Data {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if var gymSession = try? decoder.decode(WatchGymSession.self, from: gymData) {
                let isNew = self.activeGymSession == nil
                // Re-aplica toggles locales pendientes y descarta los ya confirmados
                for (exIndex, exercise) in gymSession.exercises.enumerated() {
                    for (setIndex, set) in exercise.sets.enumerated() {
                        guard let pending = pendingGymToggles[set.id] else { continue }
                        if set.completed == pending {
                            pendingGymToggles.removeValue(forKey: set.id)   // confirmado
                        } else {
                            gymSession.exercises[exIndex].sets[setIndex].completed = pending
                        }
                    }
                }
                self.activeGymSession = gymSession
                if isNew { WKInterfaceDevice.current().play(.notification) }
            }
        } else if data["gymSessionCleared"] != nil {
            if self.activeGymSession != nil {
                self.activeGymSession = nil
                pendingGymToggles.removeAll()
                WKInterfaceDevice.current().play(.success)
            }
        }

        // Handle stopTabata action
        if let action = data["action"] as? String, action == "stopTabata" {
            // Clear remote tabata when iPhone stops
            print("📲 iPhone detuvo el Tabata")
            await MainActor.run {
                self.activeRemoteTabata = nil
            }
            WKInterfaceDevice.current().play(.stop)
        }

        // Actualizar @Published (ya estamos en MainActor)
        if let ejercicios = newEjercicios { self.ejercicios = ejercicios }
        if let tabatas = newTabatas { self.tabatas = tabatas }
        if let unit = newUnit { self.weightUnit = unit }
        if let tabata = newRemoteTabata { self.activeRemoteTabata = tabata }

        self.lastSyncDate = Date()
        UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
    }
    
    // MARK: - Parse Ejercicios from Dictionary Array
    private func parseEjerciciosFromDictArray(_ array: [[String: Any]]) -> [WatchEjercicio] {
        return array.compactMap { dict -> WatchEjercicio? in
            guard let name = dict["name"] as? String else { return nil }
            
            var rmHistory: [WatchRMEntry] = []
            
            if let history = dict["rmHistory"] as? [[String: Any]] {
                rmHistory = history.compactMap { rm -> WatchRMEntry? in
                    guard let valor = rm["valor"] as? Double else { return nil }
                    let fecha: Date
                    if let timestamp = rm["fecha"] as? TimeInterval {
                        fecha = Date(timeIntervalSince1970: timestamp)
                    } else {
                        fecha = Date()
                    }
                    return WatchRMEntry(valor: valor, fecha: fecha)
                }
            }
            
            return WatchEjercicio(
                id: dict["id"] as? String,
                name: name,
                rmHistory: rmHistory
            )
        }
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
        
        if let rounds = rounds { message["rounds"] = rounds }
        if let notes = notes { message["notes"] = notes }
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: { response in
                print("✅ Resultado enviado al iPhone")
            }, errorHandler: { error in
                print("⚠️ Error enviando resultado, usando transferUserInfo")
                session.transferUserInfo(message)
            })
        } else {
            // Encolar para cuando conecte
            session.transferUserInfo(message)
            print("📱 Resultado encolado para envío")
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
                        print("✅ RM guardado en iPhone")
                        // Esperar un poco y refrescar datos
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        self?.requestDataFromPhone()
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            }, errorHandler: { error in
                print("⚠️ Error enviando RM: \(error.localizedDescription)")
                // Encolar como backup
                session.transferUserInfo(message)
                Task { @MainActor in
                    completion(true) // Optimista
                }
            })
        } else {
            session.transferUserInfo(message)
            completion(true) // Optimista - se enviará cuando conecte
        }
    }
    
    // MARK: - Gym: marcar serie desde el Watch
    /// Optimista en local; el iPhone confirma reenviando el espejo actualizado.
    func toggleGymSet(exerciseId: String, setId: String, completed: Bool) {
        pendingGymToggles[setId] = completed
        // Update optimista local
        if var gymSession = activeGymSession,
           let exIndex = gymSession.exercises.firstIndex(where: { $0.id == exerciseId }),
           let setIndex = gymSession.exercises[exIndex].sets.firstIndex(where: { $0.id == setId }) {
            gymSession.exercises[exIndex].sets[setIndex].completed = completed
            activeGymSession = gymSession
        }
        WKInterfaceDevice.current().play(completed ? .success : .click)

        guard let session = session else { return }
        let message: [String: Any] = [
            "action": "toggleGymSet",
            "exerciseId": exerciseId,
            "setId": setId,
            "completed": completed
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                // Fallback en cola si el envío directo falla
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
    }

    // MARK: - Clear Remote Tabata
    func clearRemoteTabata() {
        activeRemoteTabata = nil
        
        // Limpiar del applicationContext del iPhone
        if let session = session {
            var context = session.applicationContext
            context.removeValue(forKey: "pendingTabataAction")
            context.removeValue(forKey: "pendingTabata")
            try? session.updateApplicationContext(context)
        }
    }
    
    // MARK: - Cache Management
    private func cacheData(ejerciciosData: Data?, tabatasData: Data?) {
        // Guardar en background thread
        Task.detached(priority: .utility) {
            if let data = ejerciciosData {
                UserDefaults.standard.set(data, forKey: "cachedEjercicios")
            }
            if let data = tabatasData {
                UserDefaults.standard.set(data, forKey: "cachedTabatas")
            }
        }
    }

    // Cargar cache en BACKGROUND (NO bloquea UI)
    private func loadCachedDataBackground() {
        var loadedEjercicios: [WatchEjercicio] = []
        var loadedTabatas: [Tabata] = Tabata.all
        var loadedUnit: WatchWeightUnit = .kg
        var loadedDate: Date?

        // Todo esto corre en background thread
        if let data = UserDefaults.standard.data(forKey: "cachedEjercicios") {
            if let ejercicios = try? JSONDecoder().decode([WatchEjercicio].self, from: data) {
                loadedEjercicios = ejercicios
                print("✅ Cache: \(ejercicios.count) ejercicios")
            } else if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                loadedEjercicios = parseEjerciciosFromDictArray(array)
                print("✅ Cache: \(loadedEjercicios.count) ejercicios (alt)")
            }
        }

        if let data = UserDefaults.standard.data(forKey: "cachedTabatas"),
           let tabatas = try? JSONDecoder().decode([Tabata].self, from: data) {
            loadedTabatas = tabatas
            print("✅ Cache: \(tabatas.count) tabatas")
        }

        var loadedUserWorkouts: [WatchUserWorkout] = []
        if let data = UserDefaults.standard.data(forKey: "cachedUserWorkouts"),
           let workouts = try? JSONDecoder().decode([WatchUserWorkout].self, from: data) {
            loadedUserWorkouts = workouts
        }

        if let unit = UserDefaults.standard.string(forKey: "weightUnit"),
           let weightUnit = WatchWeightUnit(rawValue: unit) {
            loadedUnit = weightUnit
        }

        loadedDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date

        // Actualizar @Published en Main Thread
        Task { @MainActor in
            self.ejercicios = loadedEjercicios
            self.tabatas = loadedTabatas
            self.userWorkouts = loadedUserWorkouts
            self.weightUnit = loadedUnit
            self.lastSyncDate = loadedDate
        }
    }

    @available(*, deprecated, message: "Use loadCachedDataBackground instead")
    private func loadCachedData() {
        // Deprecated - mantener por compatibilidad pero no usar
    }
    
    // MARK: - Clear Cache
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: "cachedEjercicios")
        UserDefaults.standard.removeObject(forKey: "cachedTabatas")
        UserDefaults.standard.removeObject(forKey: "lastSyncDate")
        ejercicios = []
        tabatas = Tabata.all
        lastSyncDate = nil
    }
}

// MARK: - WCSession Delegate
extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("❌ WCSession activation error: \(error.localizedDescription)")
                self.syncStatus = .error("Error de activación")
                return
            }
            
            self.isConnected = activationState == .activated
            self.isPhoneReachable = session.isReachable
            
            print("✅ WCSession activada - Estado: \(activationState.rawValue)")
            print("📱 iPhone reachable: \(session.isReachable)")
            print("📦 Has pending content: \(session.hasContentPending)")
            
            if activationState == .activated {
                // Procesar cualquier applicationContext pendiente
                if !session.receivedApplicationContext.isEmpty {
                    print("📥 Procesando applicationContext...")
                    Task { @MainActor in
                        await self.handleReceivedData(session.receivedApplicationContext)
                    }
                }

                // Sincronizar datos automáticamente si no tenemos cache o si iPhone está reachable
                if self.ejercicios.isEmpty || session.isReachable {
                    print("🔄 Sincronización automática INMEDIATA...")
                    Task { @MainActor in
                        // Sin delay - sincronizar inmediatamente
                        self.requestDataFromPhone()
                    }
                } else {
                    print("✅ Usando datos cacheados (iPhone no reachable)")
                }
            }
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
            print("⌚️ Reachability changed: \(session.isReachable ? "REACHABLE ✅" : "NOT REACHABLE ❌")")
        }
    }
    
    // Recibir mensajes
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            print("⌚️ Mensaje recibido (sin reply)")
            await self.handleReceivedData(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            print("⌚️ Mensaje recibido (con reply)")
            await self.handleReceivedData(message)
            replyHandler(["status": "received"])
        }
    }

    // Recibir applicationContext (persistente)
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            print("⌚️ ApplicationContext recibido")
            await self.handleReceivedData(applicationContext)
        }
    }

    // Recibir userInfo (cola garantizada)
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            print("⌚️ UserInfo recibido")
            await self.handleReceivedData(userInfo)
        }
    }
}
