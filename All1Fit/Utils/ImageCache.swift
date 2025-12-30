import SwiftUI
import CryptoKit

// MARK: - Image Cache Manager (Memory + Disk)
@MainActor
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private var downloadTasks: [URL: Task<UIImage?, Never>] = [:]
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Configure memory cache limits
        memoryCache.countLimit = 100 // Max 100 images in memory
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB in memory
        
        // Setup disk cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("ImageCache", isDirectory: true)
        
        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // Get cached image (memory -> disk -> network)
    func image(for url: URL) async -> UIImage? {
        let key = cacheKey(for: url)
        
        // 1. Check memory cache first
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        
        // 2. Check disk cache
        if let diskImage = loadFromDisk(key: key) {
            // Store in memory for faster access
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }
        
        // 3. Check if already downloading
        if let existingTask = downloadTasks[url] {
            return await existingTask.value
        }
        
        // 4. Download from network
        let task = Task<UIImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                
                // Cache in memory
                memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
                
                // Cache to disk
                saveToDisk(data: data, key: key)
                
                return image
            } catch {
                return nil
            }
        }
        
        downloadTasks[url] = task
        let result = await task.value
        downloadTasks.removeValue(forKey: url)
        
        return result
    }
    
    // Generate cache key from URL
    private func cacheKey(for url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Load image from disk
    private func loadFromDisk(key: String) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    // Save image to disk
    private func saveToDisk(data: Data, key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? data.write(to: fileURL)
    }
    
    // Invalidate specific URL
    func invalidate(url: URL) {
        let key = cacheKey(for: url)
        memoryCache.removeObject(forKey: key as NSString)
        
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? fileManager.removeItem(at: fileURL)
    }
    
    // Clear all cache (memory + disk)
    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // Get disk cache size in bytes
    func diskCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }
}

// MARK: - Cached Image View
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        isLoading = true
        
        Task {
            image = await ImageCacheManager.shared.image(for: url)
            isLoading = false
        }
    }
}

// Convenience initializer
extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url
        self.content = content
        self.placeholder = { ProgressView() }
    }
}
