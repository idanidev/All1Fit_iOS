import Foundation
import HealthKit

// MARK: - iOS HealthKit Service
@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async {
        guard isAvailable else { return }
        let write: Set<HKSampleType> = [
            HKQuantityType(.activeEnergyBurned),
            HKObjectType.workoutType()
        ]
        let read: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned)
        ]
        do {
            try await healthStore.requestAuthorization(toShare: write, read: read)
            isAuthorized = true
        } catch {
            print("HealthKit auth error: \(error)")
        }
    }

    /// Save a completed workout to HealthKit
    func saveWorkout(
        activityType: HKWorkoutActivityType,
        startDate: Date,
        duration: TimeInterval,
        calories: Double? = nil
    ) async {
        guard isAvailable else { return }
        if !isAuthorized { await requestAuthorization() }

        let endDate = startDate.addingTimeInterval(duration)
        let estimatedCalories = calories ?? (duration / 60.0 * 10.0)

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = activityType == .running ? .outdoor : .indoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

        do {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                builder.beginCollection(withStart: startDate) { _, err in
                    if let err { c.resume(throwing: err) } else { c.resume() }
                }
            }

            let energySample = HKQuantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: estimatedCalories),
                start: startDate, end: endDate
            )
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                builder.add([energySample]) { _, err in
                    if let err { c.resume(throwing: err) } else { c.resume() }
                }
            }

            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                builder.endCollection(withEnd: endDate) { _, err in
                    if let err { c.resume(throwing: err) } else { c.resume() }
                }
            }

            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                builder.addMetadata([HKMetadataKeyWorkoutBrandName: "All1Fit"]) { _, err in
                    if let err { c.resume(throwing: err) } else { c.resume() }
                }
            }

            _ = try await withCheckedThrowingContinuation { (c: CheckedContinuation<HKWorkout?, Error>) in
                builder.finishWorkout { workout, err in
                    if let err { c.resume(throwing: err) } else { c.resume(returning: workout) }
                }
            }
            print("HealthKit workout saved: \(activityType), \(duration)s, \(estimatedCalories) kcal")
        } catch {
            print("HealthKit save error: \(error)")
        }
    }
}
