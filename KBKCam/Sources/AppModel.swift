import SwiftUI
import UIKit

/// Ties together settings, the score engine, the overlay renderer, the stream and the remote control.
@MainActor
final class AppModel: ObservableObject {
    @Published var settings = Settings.load() {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            settings.apply(to: engine)
            if settings.sport != oldValue.sport { engine.newMatch(); saveMatch() }
            if settings.resolution != oldValue.resolution || settings.fps != oldValue.fps {
                let s = settings
                Task { await stream.updateVideoFormat(s) }
            }
            if settings.remoteEnabled != oldValue.remoteEnabled || settings.remotePort != oldValue.remotePort { setupRemote() }
            refresh()
        }
    }
    @Published var lang = T.lang { didSet { T.lang = lang; refresh() } }
    @Published private(set) var tick = 0
    @Published var toast: String?
    @Published var panelHidden = false

    let engine = ScoreEngine()
    let stream = StreamController()
    let renderer = ScoreboardRenderer()
    private var remote: RemoteServer?
    private var timer: Timer?
    private var toastTask: Task<Void, Never>?

    init() {
        settings.apply(to: engine)
        if let d = UserDefaults.standard.data(forKey: "match"), let m = try? JSONDecoder().decode(MatchState.self, from: d) {
            engine.s = m
        }
        loadLogos()
        stream.onMessage = { [weak self] msg in self?.say(msg) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.onTick() }
        }
        setupRemote()
    }

    // MARK: refresh
    func refresh() {
        tick &+= 1
        renderOverlay()
    }

    func renderOverlay() {
        let img = renderer.render(width: settings.width, height: settings.height, engine: engine, settings: settings)
        stream.setOverlay(img)
    }

    private func onTick() {
        if engine.clockRunning && settings.clockMode == "DOWN" && settings.shownClock(engine) == 0 {
            engine.pauseClock()
            settings.setShownClock(engine, 0)
            saveMatch()
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            say(T.r("⏱ انتهى الوقت"))
        }
        if engine.clockRunning && settings.showClock { renderOverlay() }
        tick &+= 1
    }

    func loadLogos() {
        renderer.logoA = LogoStore.load("logoA")
        renderer.logoB = LogoStore.load("logoB")
        renderer.logo1 = LogoStore.load("logo1")
        renderer.logo2 = LogoStore.load("logo2")
        refresh()
    }

    func say(_ s: String) {
        toast = s
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    private func saveMatch() {
        if let d = try? JSONEncoder().encode(engine.s) { UserDefaults.standard.set(d, forKey: "match") }
    }

    private func changed() {
        saveMatch()
        if engine.s.finished {
            say(T.r("انتهت المباراة — الفائز: ") + (engine.s.winner == 0 ? settings.nameA : settings.nameB))
        }
        refresh()
    }

    private func haptic() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

    // MARK: score actions
    func point(_ i: Int) { engine.point(i); haptic(); changed() }
    func minus(_ i: Int) { engine.minus(i); changed() }
    func undo() { if !engine.undo() { say(T.r("لا يوجد ما يمكن التراجع عنه")) }; changed() }
    func swapServer() { engine.swapServer(); changed() }
    func nextPeriod() { engine.nextPeriod(); changed(); say(periodText + T.r(" — تم تصفير المؤقت")) }
    func prevPeriod() { engine.prevPeriod(); changed() }
    func adjustGames(_ i: Int, _ d: Int) { engine.adjustGames(i, d); changed() }
    func closeSet() { if !engine.closeSet() { say(T.r("النتيجة متعادلة — لا يمكن إنهاء المجموعة")) }; changed() }
    func reopenSet() { if !engine.reopenLastSet() { say(T.r("لا توجد مجموعة منتهية")) }; changed() }
    func newMatch() { engine.newMatch(); changed() }

    // MARK: clock actions
    func clockToggle() {
        if !engine.clockRunning && settings.clockMode == "DOWN" && settings.shownClock(engine) == 0 {
            say(T.r("انتهى الوقت — صفّر المؤقت أو أضف وقتاً"))
            return
        }
        engine.toggleClock(); haptic(); changed()
    }
    func clockAdjust(_ ms: Double) { settings.adjustShownClock(engine, ms); haptic(); changed() }
    func clockReset() { engine.resetClock(); changed() }
    func clockSet(minutes: Int, seconds: Int) { settings.setShownClock(engine, Double(minutes * 60 + min(59, seconds)) * 1000); changed() }
    func setClockMode(_ minutes: Int) {
        if minutes == 0 { settings.clockMode = "UP" } else { settings.clockMode = "DOWN"; settings.periodMinutes = minutes }
        settings.showClock = true
        engine.resetClock()
        changed()
    }

    // MARK: stream actions
    func toggleLive() async {
        if stream.isLive || stream.isConnecting { await stream.stopLive(settings) } else { await stream.goLive(settings) }
    }
    func toggleRecording() async {
        if stream.isRecording { await stream.stopRecording(settings) } else { await stream.startRecording() }
    }
    func markHighlight() {
        if stream.markHighlight() {
            haptic()
            say(T.r("★ لقطة ") + "\(stream.highlightCount)" + T.r(" — آخر ") + "\(settings.hlBefore)" + T.r(" ث"))
        } else {
            say(T.r("اللقطات تُحفظ من التسجيل: ابدأ التسجيل أو البث (مع تفعيل التسجيل أثناء البث)"))
        }
    }

    // MARK: display helpers
    var periodText: String {
        switch engine.rules.sport {
        case .FOOTBALL, .FUTSAL, .HANDBALL:
            return engine.s.period <= 2 ? T.r("الشوط ") + "\(engine.s.period)" : T.r("إضافي ") + "\(engine.s.period - 2)"
        case .BASKETBALL: return T.r("الربع ") + "\(engine.s.period)"
        default: return T.r("الفترة ") + "\(engine.s.period)"
        }
    }

    func subText(_ i: Int) -> String {
        switch engine.rules.sport.kind {
        case .racket: return "SETS \(engine.setsWon(i)) · GAMES \(engine.s.games[i])"
        case .rally: return "SETS \(engine.setsWon(i))"
        case .goals: return engine.periodLabel
        }
    }

    var setText: String {
        let n = engine.s.sets.count + (engine.s.finished ? 0 : 1)
        return (engine.s.finished ? T.r("انتهت المباراة") : T.r("المجموعة ") + "\(n)") + "   ·   \(engine.setsWon(0)) - \(engine.setsWon(1))"
    }

    var clockText: String { ScoreEngine.formatClock(settings.shownClock(engine)) }

    var statusText: String {
        var parts: [String] = []
        if stream.isLive, let s = stream.liveStart { parts.append("● LIVE  " + ScoreEngine.formatClock(Date().timeIntervalSince(s) * 1000)) }
        else if stream.isConnecting { parts.append(stream.lastMessage.isEmpty ? T.r("جارٍ الاتصال بالخادم...") : stream.lastMessage) }
        if stream.isRecording, let s = stream.recStart { parts.append("● REC  " + ScoreEngine.formatClock(Date().timeIntervalSince(s) * 1000)) }
        if parts.isEmpty { return stream.lastMessage.isEmpty ? T.r("معاينة البث — غير متصل") : stream.lastMessage }
        return parts.joined(separator: "    ")
    }

    // MARK: remote control
    func setupRemote() {
        remote?.stop()
        remote = nil
        guard settings.remoteEnabled else { return }
        let r = RemoteServer(port: UInt16(clamping: settings.remotePort)) { [weak self] cmd, arg in
            await self?.remoteCommand(cmd, arg) ?? "{}"
        }
        r.start()
        remote = r
    }

    private func remoteCommand(_ cmd: String, _ arg: String) async -> String {
        let t = arg == "1" ? 1 : 0
        switch cmd {
        case "point": point(t)
        case "minus": minus(t)
        case "undo": undo()
        case "highlight": markHighlight()
        case "clock": clockToggle()
        case "clockplus": clockAdjust(10_000)
        case "clockminus": clockAdjust(-10_000)
        case "clockreset": clockReset()
        case "period": nextPeriod()
        default: break
        }
        return stateJSON()
    }

    private func stateJSON() -> String {
        func sets(_ i: Int) -> String {
            var s = engine.s.sets.map { "\($0[i])" }.joined(separator: " ")
            if engine.rules.sport.kind == .racket { s += (s.isEmpty ? "" : " ") + "[\(engine.s.games[i])]" }
            return s
        }
        let obj: [String: Any] = [
            "nameA": settings.nameA, "nameB": settings.nameB,
            "pA": engine.pointLabel(0), "pB": engine.pointLabel(1),
            "setsA": sets(0), "setsB": sets(1),
            "sport": T.r(engine.rules.sport.label), "phase": engine.phaseLabel, "lang": T.lang,
            "clock": clockText, "clockRunning": engine.clockRunning,
            "live": stream.isLive, "rec": stream.isRecording, "msg": stream.lastMessage
        ]
        guard let d = try? JSONSerialization.data(withJSONObject: obj), let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }

    var remoteURL: String? {
        guard settings.remoteEnabled, let ip = RemoteServer.localIP() else { return nil }
        return "http://\(ip):\(settings.remotePort)"
    }
}
