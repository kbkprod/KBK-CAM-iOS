import UIKit

/// All user settings (same options as the Android app), stored as JSON in UserDefaults.
struct Settings: Codable, Equatable {
    // Stream
    var rtmpUrl = "rtmp://a.rtmp.youtube.com/live2"
    var streamKey = ""
    var resolution = 720
    var fps = 30
    var bitrateKbps = 3000
    var recordWhileStreaming = true
    // Match
    var sport: Sport = .PADEL
    var nameA = "TEAM A"
    var nameB = "TEAM B"
    var colorA = 0
    var colorB = 1
    var bestOf = 3
    var rallyTarget = 0
    var tiebreak = true
    var superTiebreak = false
    var goldenPoint = false
    // Overlay
    var position = "TL"
    var style = "DARK"
    var sizePct = 100
    var showScoreboard = true
    var showClock = true
    var showPeriod = true
    var showServe = true
    var showSets = true
    var showLogos = true
    var showTeamLogos = true
    // Clock
    var clockMode = "UP"
    var periodMinutes = 45
    var clockScale = 140
    // Control layout
    var panelSide = "RIGHT"
    var swapTeamButtons = false
    var buttonScale = 100
    var clockOnTop = false
    // Highlights & remote
    var hlBefore = 20
    var hlAfter = 5
    var remoteEnabled = true
    var remotePort = 8080

    static let colors: [UInt32] = [0x2F80ED, 0xF2994A, 0xE8483B, 0x27AE60, 0x9B51E0, 0xF2C94C, 0x00B8D4, 0xEB5797, 0x4F4F4F, 0xFFFFFF]
    static let colorNames = ["أزرق", "برتقالي", "أحمر", "أخضر", "بنفسجي", "أصفر", "سماوي", "وردي", "رمادي", "أبيض"]
    static let positions = ["TL", "TC", "TR", "BL", "BC", "BR"]
    static let positionNames = ["أعلى اليسار", "أعلى الوسط", "أعلى اليمين", "أسفل اليسار", "أسفل الوسط", "أسفل اليمين"]
    static let styles = ["DARK", "LIGHT", "TEAM", "GLASS", "NEON", "MINIMAL", "BAR", "BAR_TEAM"]
    static let styleNames = ["داكن كلاسيكي", "فاتح", "بألوان الفرق", "زجاجي شفاف", "نيون", "بسيط (بدون خلفية)",
                             "شريط بث أفقي", "شريط أفقي بألوان الفرق"]

    var width: Int { resolution == 1080 ? 1920 : resolution == 480 ? 854 : 1280 }
    var height: Int { resolution == 1080 ? 1080 : resolution == 480 ? 480 : 720 }

    func uiColor(_ team: Int) -> UIColor {
        let idx = team == 0 ? colorA : colorB
        let v = Settings.colors[max(0, min(idx, Settings.colors.count - 1))]
        return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    /// Server URL and stream key. If no key is set, the last path part of the URL is used as the key.
    var serverAndKey: (String, String) {
        let u = rtmpUrl.trimmingCharacters(in: .whitespaces)
        let k = streamKey.trimmingCharacters(in: .whitespaces)
        if !k.isEmpty { return (u.hasSuffix("/") ? String(u.dropLast()) : u, k) }
        guard let slash = u.lastIndex(of: "/") else { return (u, "") }
        return (String(u[..<slash]), String(u[u.index(after: slash)...]))
    }

    func apply(to e: ScoreEngine) {
        e.rules.sport = sport
        e.rules.bestOf = bestOf
        e.rules.tiebreak = tiebreak
        e.rules.superTiebreak = superTiebreak
        e.rules.goldenPoint = goldenPoint
        e.rules.rallyTarget = rallyTarget
    }

    func shownClock(_ e: ScoreEngine) -> Double {
        clockMode == "DOWN" ? max(0, Double(periodMinutes) * 60_000 - e.clockMs) : e.clockMs
    }
    func adjustShownClock(_ e: ScoreEngine, _ delta: Double) { e.adjustElapsed(clockMode == "DOWN" ? -delta : delta) }
    func setShownClock(_ e: ScoreEngine, _ ms: Double) {
        e.setElapsed(clockMode == "DOWN" ? Double(periodMinutes) * 60_000 - ms : ms)
    }

    // MARK: storage
    static func load() -> Settings {
        guard let d = UserDefaults.standard.data(forKey: "settings"),
              let s = try? JSONDecoder().decode(Settings.self, from: d) else { return Settings() }
        return s
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: "settings") }
    }
}

/// Logo images saved in the app's Application Support folder.
enum LogoStore {
    static let names = ["logoA", "logoB", "logo1", "logo2"]

    static func url(_ name: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name + ".png")
    }

    static func load(_ name: String) -> UIImage? { UIImage(contentsOfFile: url(name).path) }

    static func save(_ name: String, data: Data) {
        guard let img = UIImage(data: data) else { return }
        let maxSide: CGFloat = 800
        let scale = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        try? resized.pngData()?.write(to: url(name))
    }

    static func remove(_ name: String) { try? FileManager.default.removeItem(at: url(name)) }
}
