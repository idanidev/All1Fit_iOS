import Foundation
import WatchKit

// MARK: - Background Refresh Manager
/// Manages background refresh tasks for Watch app
class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    
    private let refreshInterval: TimeInterval = 30 * 60 // 30 minutes
    
    private init() {}
    
    // MARK: - Schedule Background Refresh
    
    func scheduleBackgroundRefresh() {
        let preferredDate = Date().addingTimeInterval(refreshInterval)
        
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: preferredDate,
            userInfo: nil
        ) { error in
            if let error = error {
                print("❌ Error scheduling background refresh: \(error)")
            } else {
                print("✅ Background refresh scheduled for: \(preferredDate)")
            }
        }
    }
    
    // MARK: - Handle Background Tasks
    
    func handleBackgroundTasks(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                handleRefreshTask(refreshTask)
                
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                handleSnapshotTask(snapshotTask)
                
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                handleURLSessionTask(urlSessionTask)
                
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
    
    // MARK: - Refresh Task Handler
    
    private func handleRefreshTask(_ task: WKApplicationRefreshBackgroundTask) {
        print("🔄 Background refresh started")
        
        // Request data from iPhone
        Task { @MainActor in
            let service = WatchConnectivityService.shared
            service.requestDataFromPhone()
            
            // Wait a bit for sync
            try? await Task.sleep(for: .seconds(2))
            
            // Schedule next refresh
            scheduleBackgroundRefresh()
            
            // Complete task
            task.setTaskCompletedWithSnapshot(true)
            print("✅ Background refresh completed")
        }
    }
    
    // MARK: - Snapshot Task Handler
    
    private func handleSnapshotTask(_ task: WKSnapshotRefreshBackgroundTask) {
        // Update UI snapshot for dock
        task.setTaskCompleted(
            restoredDefaultState: true,
            estimatedSnapshotExpiration: Date().addingTimeInterval(refreshInterval),
            userInfo: nil
        )
    }
    
    // MARK: - URL Session Task Handler
    
    private func handleURLSessionTask(_ task: WKURLSessionRefreshBackgroundTask) {
        // Handle background URL session if needed
        task.setTaskCompletedWithSnapshot(false)
    }
}

// MARK: - Sync Retry Manager
/// Manages retry logic with exponential backoff
class SyncRetryManager {
    static let shared = SyncRetryManager()
    
    private var retryCount = 0
    private let maxRetries = 5
    private var retryTask: Task<Void, Never>?
    
    private init() {}
    
    // MARK: - Exponential Backoff Delays
    
    private func backoffDelay(attempt: Int) -> TimeInterval {
        // 2^attempt seconds: 2, 4, 8, 16, 32 seconds
        return pow(2.0, Double(min(attempt, 5)))
    }
    
    // MARK: - Schedule Retry
    
    func scheduleRetry(action: @escaping () async -> Bool) {
        guard retryCount < maxRetries else {
            print("❌ Max retries reached, giving up")
            resetRetryCount()
            return
        }
        
        let delay = backoffDelay(attempt: retryCount)
        retryCount += 1
        
        print("🔄 Retry \(retryCount)/\(maxRetries) in \(delay)s")
        
        retryTask?.cancel()
        retryTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            
            guard !Task.isCancelled else { return }
            
            let success = await action()
            
            if success {
                print("✅ Retry succeeded")
                resetRetryCount()
            } else {
                scheduleRetry(action: action)
            }
        }
    }
    
    // MARK: - Cancel & Reset
    
    func cancelRetries() {
        retryTask?.cancel()
        retryTask = nil
    }
    
    func resetRetryCount() {
        retryCount = 0
    }
}

// MARK: - Sync Debouncer
/// Debounces frequent sync requests
class SyncDebouncer {
    static let shared = SyncDebouncer()
    
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 1.0 // 1 second
    
    private init() {}
    
    func debounce(action: @escaping () -> Void) {
        debounceTask?.cancel()
        
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(debounceInterval))
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                action()
            }
        }
    }
}

// MARK: - Local Cache Manager
/// Manages local caching for offline mode
class LocalCacheManager {
    static let shared = LocalCacheManager()
    
    private let defaults = UserDefaults.standard
    
    private let ejerciciosCacheKey = "cachedEjercicios"
    private let tabatasCacheKey = "cachedTabatas"
    private let lastCacheTimeKey = "lastCacheTime"
    
    private init() {}
    
    // MARK: - Cache Age
    
    var cacheAge: TimeInterval? {
        guard let lastCache = defaults.object(forKey: lastCacheTimeKey) as? Date else {
            return nil
        }
        return Date().timeIntervalSince(lastCache)
    }
    
    var isCacheStale: Bool {
        guard let age = cacheAge else { return true }
        return age > 60 * 60 // Stale after 1 hour
    }
    
    // MARK: - Save Cache
    
    func cacheEjercicios(_ data: Data) {
        defaults.set(data, forKey: ejerciciosCacheKey)
        defaults.set(Date(), forKey: lastCacheTimeKey)
        print("💾 Ejercicios cached")
    }
    
    func cacheTabatas(_ data: Data) {
        defaults.set(data, forKey: tabatasCacheKey)
        defaults.set(Date(), forKey: lastCacheTimeKey)
        print("💾 Tabatas cached")
    }
    
    // MARK: - Load Cache
    
    func loadCachedEjercicios() -> Data? {
        return defaults.data(forKey: ejerciciosCacheKey)
    }
    
    func loadCachedTabatas() -> Data? {
        return defaults.data(forKey: tabatasCacheKey)
    }
    
    // MARK: - Clear Cache
    
    func clearCache() {
        defaults.removeObject(forKey: ejerciciosCacheKey)
        defaults.removeObject(forKey: tabatasCacheKey)
        defaults.removeObject(forKey: lastCacheTimeKey)
        print("🗑️ Cache cleared")
    }
}
