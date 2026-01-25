import Foundation
import HealthKit
import WatchKit
import Combine

// MARK: - HealthKit Service for Watch
/// Manages HealthKit workout sessions and health data
@MainActor
class HealthKitService: NSObject, ObservableObject {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    private var workoutBuilder: HKWorkoutBuilder?
    private var workoutSession: HKWorkoutSession?
    
    @Published var isAuthorized = false
    @Published var isWorkoutActive = false
    @Published var currentHeartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    
    // Heart rate query
    private var heartRateQuery: HKAnchoredObjectQuery?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Authorization
    
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else { return false }
        
        // Types we want to read
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType()
        ]
        
        // Types we want to write
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType()
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            print("✅ HealthKit autorizado")
            return true
        } catch {
            print("❌ Error solicitando HealthKit: \(error)")
            isAuthorized = false
            return false
        }
    }
    
    // MARK: - Start Workout Session
    
    func startWorkout(activityType: HKWorkoutActivityType = .highIntensityIntervalTraining) async throws {
        if !isAuthorized {
            let authorized = await requestAuthorization()
            guard authorized else { throw HealthKitError.notAuthorized }
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            // Set delegates
            workoutSession?.delegate = self
            
            // Start session and builder
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            try await workoutBuilder?.beginCollection(at: startDate)
            
            isWorkoutActive = true
            startHeartRateQuery()
            
            // Haptic feedback
            WKInterfaceDevice.current().play(.start)
            
            print("✅ Workout iniciado")
        } catch {
            print("❌ Error iniciando workout: \(error)")
            throw HealthKitError.failedToStart(error)
        }
    }
    
    // MARK: - End Workout Session
    
    func endWorkout() async throws -> HKWorkout? {
        guard let workoutSession = workoutSession,
              let workoutBuilder = workoutBuilder else {
            return nil
        }
        
        let endDate = Date()
        
        // End session
        workoutSession.end()
        stopHeartRateQuery()
        
        // End collection and finish workout
        try await workoutBuilder.endCollection(at: endDate)
        
        do {
            let workout = try await workoutBuilder.finishWorkout()
            
            self.workoutSession = nil
            self.workoutBuilder = nil
            isWorkoutActive = false
            
            // Reset metrics
            currentHeartRate = 0
            activeCalories = 0
            elapsedTime = 0
            
            // Haptic feedback
            WKInterfaceDevice.current().play(.success)
            
            if let workout = workout {
                print("✅ Workout guardado: \(workout.duration)s, \(workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0) kcal")
            }
            
            return workout
        } catch {
            print("❌ Error finalizando workout: \(error)")
            throw HealthKitError.failedToSave(error)
        }
    }
    
    // MARK: - Pause/Resume
    
    func pauseWorkout() {
        workoutSession?.pause()
        WKInterfaceDevice.current().play(.stop)
    }
    
    func resumeWorkout() {
        workoutSession?.resume()
        WKInterfaceDevice.current().play(.start)
    }
    
    // MARK: - Heart Rate Query
    
    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate),
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.handleHeartRateSamples(samples)
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.handleHeartRateSamples(samples)
        }
        
        healthStore.execute(query)
        heartRateQuery = query
    }
    
    // Non-isolated handler to satisfy Sendable requirements
    nonisolated private func handleHeartRateSamples(_ samples: [HKSample]?) {
        Task { @MainActor in
            self.processHeartRateSamples(samples)
        }
    }
    
    private func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample],
              let lastSample = heartRateSamples.last else { return }
        
        let heartRate = lastSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        
        Task { @MainActor in
            self.currentHeartRate = heartRate
        }
    }
    
    // MARK: - Save Tabata Workout (Manual)
    
    /// Saves a completed Tabata as a workout without live session
    func saveTabataWorkout(
        name: String,
        duration: TimeInterval,
        calories: Double? = nil,
        startDate: Date = Date()
    ) async throws -> HKWorkout? {
        if !isAuthorized {
            let authorized = await requestAuthorization()
            guard authorized else { throw HealthKitError.notAuthorized }
        }
        
        let endDate = startDate.addingTimeInterval(duration)
        
        // Estimate calories if not provided (rough HIIT estimate: 10-15 cal/min)
        let estimatedCalories = calories ?? (duration / 60.0 * 12.0)
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .highIntensityIntervalTraining
        configuration.locationType = .indoor
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        do {
            // Begin collection with explicit continuation
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.beginCollection(withStart: startDate) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            
            let samples: [HKSample] = [
                HKQuantitySample(
                    type: .quantityType(forIdentifier: .activeEnergyBurned)!,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: estimatedCalories),
                    start: startDate,
                    end: endDate
                )
            ]
            
            // Add samples with explicit continuation
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.add(samples) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            
            // End collection with explicit continuation
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.endCollection(withEnd: endDate) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            
            // Add metadata
            let metadata: [String: Any] = [
                HKMetadataKeyWorkoutBrandName: "All1Fit",
                "TabataName": name
            ]
            
            // Add metadata with explicit continuation
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                builder.addMetadata(metadata) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            
            // Finish workout with explicit continuation
            let workout = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout?, Error>) in
                builder.finishWorkout { workout, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: workout)
                    }
                }
            }
            
            print("✅ Tabata guardado en HealthKit: \(name)")
            WKInterfaceDevice.current().play(.success)
            return workout
        } catch {
            print("❌ Error guardando Tabata: \(error)")
            throw HealthKitError.failedToSave(error)
        }
    }
    
    // MARK: - Fetch Past Workouts
    
    func fetchRecentWorkouts(limit: Int = 10) async throws -> [HKWorkout] {
        guard isAuthorized else { return [] }
        
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForWorkouts(with: .highIntensityIntervalTraining)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let workouts = samples as? [HKWorkout] ?? []
                    continuation.resume(returning: workouts)
                }
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitService: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            switch toState {
            case .running:
                isWorkoutActive = true
            case .paused:
                isWorkoutActive = true
            case .ended:
                isWorkoutActive = false
            default:
                break
            }
        }
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("❌ Workout session error: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HealthKitService: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
    
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            Task { @MainActor in
                updateMetrics(from: statistics, for: quantityType)
            }
        }
    }
    
    @MainActor
    private func updateMetrics(from statistics: HKStatistics?, for quantityType: HKQuantityType) {
        guard let statistics = statistics else { return }
        
        switch quantityType {
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            if let value = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                currentHeartRate = value
            }
        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            if let value = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                activeCalories = value
            }
        default:
            break
        }
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAuthorized
    case failedToStart(Error)
    case failedToSave(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "HealthKit no autorizado. Activa permisos en Ajustes."
        case .failedToStart(let error):
            return "Error iniciando workout: \(error.localizedDescription)"
        case .failedToSave(let error):
            return "Error guardando workout: \(error.localizedDescription)"
        }
    }
}
