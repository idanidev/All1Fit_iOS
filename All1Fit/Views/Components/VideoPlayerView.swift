import SwiftUI
import AVKit
import os

// MARK: - Looping Video Player View
struct LoopingVideoPlayer: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.all1fit", category: "VideoPlayer")
    let videoName: String
    @State private var player: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?
    
    var body: some View {
        VideoPlayer(player: player)
            .disabled(true) // Disable controls for auto-loop
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
    
    private func setupPlayer() {
        // Try to find the video in the bundle
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            logger.error("❌ Video not found: \(videoName).mp4")
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        
        // Create looper for infinite loop
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        
        queuePlayer.isMuted = true
        queuePlayer.play()
        
        player = queuePlayer
    }
}

// MARK: - Simple Video Thumbnail (Static Image from Video)
struct VideoThumbnail: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.all1fit", category: "VideoThumbnail")
    let videoName: String
    @State private var thumbnail: UIImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                // Placeholder while loading
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.2), .red.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange.opacity(0.5))
                    )
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            return
        }
        
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        
        Task {
            do {
                let cgImage = try await imageGenerator.image(at: time).image
                await MainActor.run {
                    thumbnail = UIImage(cgImage: cgImage)
                }
            } catch {
                logger.error("❌ Failed to generate thumbnail: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    VStack {
        LoopingVideoPlayer(videoName: "shoulder_flossing")
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        
        VideoThumbnail(videoName: "shoulder_flossing")
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}
