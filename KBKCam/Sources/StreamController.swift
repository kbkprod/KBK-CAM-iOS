import AVFoundation
import HaishinKit
import RTMPHaishinKit
import UIKit
import VideoToolbox

/// Camera + RTMP live streaming + MP4 recording, built on HaishinKit (BSD-3-Clause).
/// The scoreboard image is an ImageScreenObject composited on top of the camera ("offscreen" mixer mode),
/// so it appears in the preview, the live stream and the recording.
@MainActor
final class StreamController: ObservableObject {
    @Published private(set) var isLive = false
    @Published private(set) var isConnecting = false
    @Published private(set) var isRecording = false
    @Published private(set) var highlightCount = 0
    @Published var lastMessage = ""

    let mixer = MediaMixer()
    private var connection: RTMPConnection?
    private var stream: RTMPStream?
    private var recorder: StreamRecorder?
    @ScreenActor private var overlay: ImageScreenObject?
    private var camera: AVCaptureDevice?
    private(set) var position: AVCaptureDevice.Position = .back
    private var previewView: MTHKView?
    private var started = false

    private var userStopped = false
    private var reconnects = 0
    private(set) var liveStart: Date?
    private(set) var recStart: Date?
    private var recAuto = false
    private var marks: [Date] = []

    /// Called with user-facing messages (toasts).
    var onMessage: ((String) -> Void)?

    // MARK: camera
    func start(_ p: Settings) async {
        guard !started else { return }
        started = true
        await mixer.setSessionPreset(p.resolution >= 1080 ? .hd1920x1080 : .hd1280x720)
        var vms = await mixer.videoMixerSettings
        vms.mode = .offscreen
        await mixer.setVideoMixerSettings(vms)
        await mixer.setVideoOrientation(Self.currentOrientation())
        await configureScreen(CGSize(width: p.width, height: p.height))
        camera = Self.device(position)
        try? await mixer.attachVideo(camera)
        try? await mixer.attachAudio(AVCaptureDevice.default(for: .audio))
        try? await mixer.setFrameRate(Float64(p.fps))
        await mixer.startRunning()
        if let v = previewView { await mixer.addOutput(v) }
    }

    @ScreenActor
    private func configureScreen(_ size: CGSize) async {
        await mixer.screen.size = size
        await mixer.screen.backgroundColor = UIColor.black.cgColor
        if let o = overlay {
            o.size = size
        } else {
            let o = ImageScreenObject()
            o.size = size
            try? await mixer.screen.addChild(o)
            overlay = o
        }
    }

    /// Applies a new resolution / frame rate (only while not streaming or recording).
    func updateVideoFormat(_ p: Settings) async {
        guard started, !isLive, !isRecording else { return }
        await mixer.setSessionPreset(p.resolution >= 1080 ? .hd1920x1080 : .hd1280x720)
        await configureScreen(CGSize(width: p.width, height: p.height))
        try? await mixer.setFrameRate(Float64(p.fps))
    }

    func updateOrientation() async {
        await mixer.setVideoOrientation(Self.currentOrientation())
    }

    func setOverlay(_ image: UIImage) {
        guard let cg = image.cgImage else { return }
        Task { @ScreenActor in self.overlay?.cgImage = cg }
    }

    func switchCamera() async {
        position = position == .back ? .front : .back
        camera = Self.device(position)
        let mirrored = position == .front
        try? await mixer.attachVideo(camera) { unit in unit.isVideoMirrored = mirrored }
    }

    func setZoom(_ factor: CGFloat) {
        guard let d = camera else { return }
        let z = max(1, min(factor, min(d.activeFormat.videoMaxZoomFactor, 10)))
        do {
            try d.lockForConfiguration()
            d.videoZoomFactor = z
            d.unlockForConfiguration()
        } catch { }
    }

    var zoom: CGFloat { camera?.videoZoomFactor ?? 1 }

    // MARK: live (RTMP)
    func goLive(_ p: Settings) async {
        let (server, key) = p.serverAndKey
        guard server.hasPrefix("rtmp://") || server.hasPrefix("rtmps://"), !key.isEmpty else {
            say(T.r("أدخل رابط RTMP ومفتاح البث في الإعدادات أولاً"))
            return
        }
        userStopped = false
        reconnects = 0
        isConnecting = true
        lastMessage = ""
        say(T.r("جارٍ الاتصال بالخادم..."))
        if p.recordWhileStreaming && !isRecording {
            await startRecording()
            recAuto = isRecording
        }
        await connect(p, server, key)
    }

    private func connect(_ p: Settings, _ server: String, _ key: String) async {
        let conn = RTMPConnection()
        let st = RTMPStream(connection: conn)
        do {
            try await st.setVideoSettings(VideoCodecSettings(
                videoSize: CGSize(width: p.width, height: p.height),
                bitRate: p.bitrateKbps * 1000,
                profileLevel: kVTProfileLevel_H264_High_AutoLevel as String,
                maxKeyFrameIntervalDuration: 2,
                expectedFrameRate: Double(p.fps)))
            try await st.setAudioSettings(AudioCodecSettings(bitRate: 128 * 1000))
            await mixer.addOutput(st)
            connection = conn
            stream = st
            _ = try await conn.connect(server)
            _ = try await st.publish(key)
            isLive = true
            isConnecting = false
            if liveStart == nil { liveStart = Date() }
            lastMessage = ""
            say(T.r("متصل — أنت على الهواء مباشرة"))
            watch(conn, p, server, key)
        } catch {
            await tearDown(conn, st)
            await connectionDropped(p, server, key, reason: "\(error)")
        }
    }

    private func watch(_ conn: RTMPConnection, _ p: Settings, _ server: String, _ key: String) {
        Task { [weak self] in
            for await status in await conn.status {
                if status.code == "NetConnection.Connect.Closed" || status.code == "NetConnection.Connect.Failed" {
                    guard let self else { return }
                    if let st = self.stream, self.connection === conn {
                        await self.tearDown(conn, st)
                        await self.connectionDropped(p, server, key, reason: status.code)
                    }
                    return
                }
            }
        }
    }

    private func tearDown(_ conn: RTMPConnection, _ st: RTMPStream) async {
        await mixer.removeOutput(st)
        _ = try? await st.close()
        try? await conn.close()
        if connection === conn { connection = nil; stream = nil }
    }

    private func connectionDropped(_ p: Settings, _ server: String, _ key: String, reason: String) async {
        guard !userStopped else { return }
        if reconnects < 10 {
            reconnects += 1
            isLive = false
            isConnecting = true
            lastMessage = T.r("إعادة الاتصال...")
            say(T.r("انقطع الاتصال، إعادة المحاولة..."))
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !userStopped { await connect(p, server, key) }
        } else {
            lastMessage = T.r("فشل الاتصال: ") + reason
            say(lastMessage)
            await stopLive(p)
        }
    }

    func stopLive(_ p: Settings) async {
        userStopped = true
        if let conn = connection, let st = stream { await tearDown(conn, st) }
        isLive = false
        isConnecting = false
        liveStart = nil
        if recAuto && isRecording { await stopRecording(p) }
    }

    // MARK: recording + highlights
    func startRecording() async {
        let r = StreamRecorder()
        await mixer.addOutput(r)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("KBK_\(Self.stamp()).mp4")
        do {
            try await r.startRecording(url)
            recorder = r
            isRecording = true
            recAuto = false
            recStart = Date()
            marks = []
            highlightCount = 0
        } catch {
            await mixer.removeOutput(r)
            say(T.r("تعذّر بدء التسجيل: ") + "\(error)")
        }
    }

    func stopRecording(_ p: Settings) async {
        guard let r = recorder, let start = recStart else { return }
        recorder = nil
        isRecording = false
        recAuto = false
        let marksCopy = marks
        marks = []
        highlightCount = 0
        recStart = nil
        say(T.r("جارٍ حفظ الفيديو..."))
        do {
            let url = try await r.stopRecording()
            await mixer.removeOutput(r)
            guard await MediaSaver.requestAccess() else { say(T.r("تعذّر نقل الفيديو إلى المعرض: ") + url.lastPathComponent); return }
            var clips = 0
            for m in marksCopy {
                let t = m.timeIntervalSince(start)
                if let clip = await MediaSaver.cut(url, from: t - Double(p.hlBefore), to: t + Double(p.hlAfter)),
                   await MediaSaver.saveVideo(clip) {
                    clips += 1
                    try? FileManager.default.removeItem(at: clip)
                }
            }
            let ok = await MediaSaver.saveVideo(url)
            if ok { try? FileManager.default.removeItem(at: url) }
            var msg = ok ? T.r("تم حفظ الفيديو في المعرض (Movies/KBK-CAM)").replacingOccurrences(of: "Movies/KBK-CAM", with: "Photos")
                         : T.r("تعذّر نقل الفيديو إلى المعرض: ") + url.lastPathComponent
            if clips > 0 { msg += "\n★ \(clips)" }
            say(msg)
        } catch {
            await mixer.removeOutput(r)
            say(T.r("تعذّر نقل الفيديو إلى المعرض: ") + "\(error)")
        }
    }

    /// Returns false when not recording (highlights are cut from the recording).
    func markHighlight() -> Bool {
        guard isRecording else { return false }
        marks.append(Date())
        highlightCount = marks.count
        return true
    }

    // MARK: helpers
    private func say(_ s: String) { onMessage?(s) }

    static func device(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    static func currentOrientation() -> AVCaptureVideoOrientation {
        let o = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.interfaceOrientation }.first
        return o == .landscapeLeft ? .landscapeLeft : .landscapeRight
    }

    static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}

extension StreamController: MTHKViewRepresentable.PreviewSource {
    nonisolated func connect(to view: MTHKView) {
        Task { @MainActor in
            self.previewView = view
            if self.started { await self.mixer.addOutput(view) }
        }
    }
}
