import AVFoundation
import Photos

/// Saving videos to Photos and cutting highlight clips (no re-encoding).
enum MediaSaver {
    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized || status == .limited
    }

    static func saveVideo(_ url: URL) async -> Bool {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            return true
        } catch {
            return false
        }
    }

    /// Copies [from, to] seconds of the source into a new MP4 (passthrough).
    static func cut(_ src: URL, from: Double, to: Double) async -> URL? {
        let asset = AVURLAsset(url: src)
        let duration = (try? await asset.load(.duration))?.seconds ?? to
        let start = max(0, from)
        let end = min(to, duration)
        guard end > start,
              let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else { return nil }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("HL_\(UUID().uuidString).mp4")
        export.outputURL = out
        export.outputFileType = .mp4
        export.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                       end: CMTime(seconds: end, preferredTimescale: 600))
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            export.exportAsynchronously { cont.resume() }
        }
        return export.status == .completed ? out : nil
    }
}
