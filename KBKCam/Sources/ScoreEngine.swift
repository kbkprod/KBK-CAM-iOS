import Foundation

/// Match scoring (port of the Android ScoreEngine):
///  - racket: tennis / padel (0-15-30-40, games, sets, tie-break, super tie-break, golden point)
///  - rally:  volleyball, pickleball, squash, table tennis, badminton (points to N, win by 2)
///  - goals:  football, basketball, handball, hockey... (counter + periods + clock)
enum Kind { case racket, rally, goals }

enum Sport: String, CaseIterable, Codable {
    case PADEL, TENNIS, PICKLEBALL, SQUASH, TABLE_TENNIS, BADMINTON, VOLLEYBALL, BEACH_VOLLEY,
         FOOTBALL, FUTSAL, BASKETBALL, HANDBALL, HOCKEY, OTHER

    var label: String {
        switch self {
        case .PADEL: return "بادل"
        case .TENNIS: return "تنس"
        case .PICKLEBALL: return "بيكلبول"
        case .SQUASH: return "سكواش"
        case .TABLE_TENNIS: return "تنس الطاولة"
        case .BADMINTON: return "الريشة الطائرة"
        case .VOLLEYBALL: return "كرة الطائرة"
        case .BEACH_VOLLEY: return "الطائرة الشاطئية"
        case .FOOTBALL: return "كرة القدم"
        case .FUTSAL: return "كرة القدم المصغرة"
        case .BASKETBALL: return "كرة السلة"
        case .HANDBALL: return "كرة اليد"
        case .HOCKEY: return "الهوكي"
        case .OTHER: return "رياضة أخرى"
        }
    }

    var kind: Kind {
        switch self {
        case .PADEL, .TENNIS: return .racket
        case .PICKLEBALL, .SQUASH, .TABLE_TENNIS, .BADMINTON, .VOLLEYBALL, .BEACH_VOLLEY: return .rally
        default: return .goals
        }
    }

    var target: Int {
        switch self {
        case .PICKLEBALL, .SQUASH, .TABLE_TENNIS: return 11
        case .BADMINTON, .BEACH_VOLLEY: return 21
        case .VOLLEYBALL: return 25
        default: return 0
        }
    }

    var decidingTarget: Int { (self == .VOLLEYBALL || self == .BEACH_VOLLEY) ? 15 : 0 }
}

struct Rules {
    var sport: Sport = .PADEL
    var bestOf = 3
    var tiebreak = true
    var superTiebreak = false
    var goldenPoint = false
    var rallyTarget = 0

    var setsToWin: Int { bestOf / 2 + 1 }
    var target: Int { rallyTarget > 0 ? rallyTarget : sport.target }
}

struct MatchState: Codable, Equatable {
    var points = [0, 0]
    var games = [0, 0]
    var sets: [[Int]] = []
    var server = 0
    var tiebreak = false
    var superTb = false
    var finished = false
    var winner = -1
    var period = 1
    var clockAccumMs: Double = 0
    var clockStartedAt: Double = 0   // epoch ms, 0 = paused
}

final class ScoreEngine {
    var s = MatchState()
    var rules = Rules()
    private var undoStack: [MatchState] = []

    private func now() -> Double { Date().timeIntervalSince1970 * 1000 }
    private func pushUndo() {
        undoStack.append(s)
        if undoStack.count > 300 { undoStack.removeFirst() }
    }

    // MARK: actions
    func point(_ i: Int) {
        guard !s.finished, i == 0 || i == 1 else { return }
        pushUndo()
        let o = 1 - i
        switch rules.sport.kind {
        case .goals:
            s.points[i] += 1
        case .rally:
            s.points[i] += 1
            s.server = i
            var target = rules.target
            if isDecidingSet && rules.sport.decidingTarget > 0 && rules.rallyTarget == 0 { target = rules.sport.decidingTarget }
            if s.points[i] >= target && s.points[i] - s.points[o] >= 2 {
                setWon(s.points)
                s.points = [0, 0]
            }
        case .racket:
            racketPoint(i)
        }
    }

    func minus(_ i: Int) {
        guard rules.sport.kind != .racket, s.points[i] > 0 else { return }
        pushUndo()
        s.points[i] -= 1
    }

    private func racketPoint(_ i: Int) {
        let o = 1 - i
        if s.tiebreak || s.superTb {
            s.points[i] += 1
            let target = s.superTb ? 10 : 7
            if (s.points[0] + s.points[1]) % 2 == 1 { s.server = 1 - s.server }
            if s.points[i] >= target && s.points[i] - s.points[o] >= 2 {
                if s.superTb {
                    s.superTb = false
                    setWon(s.points)
                    s.points = [0, 0]
                } else {
                    gameWon(i)
                }
            }
            return
        }
        if rules.goldenPoint && s.points[i] == 3 && s.points[o] == 3 { gameWon(i); return }
        s.points[i] += 1
        if s.points[i] >= 4 && s.points[i] - s.points[o] >= 2 { gameWon(i) }
        else if s.points[i] == 4 && s.points[o] == 4 { s.points = [3, 3] }
    }

    private func gameWon(_ i: Int) {
        let o = 1 - i
        s.games[i] += 1
        s.points = [0, 0]
        s.server = 1 - s.server
        let wasTb = s.tiebreak
        s.tiebreak = false
        if (s.games[i] >= 6 && s.games[i] - s.games[o] >= 2) || wasTb {
            setWon(s.games)
            s.games = [0, 0]
        } else if rules.tiebreak && s.games[0] == 6 && s.games[1] == 6 {
            s.tiebreak = true
        }
    }

    private func setWon(_ score: [Int]) {
        s.sets.append(score)
        for t in 0..<2 where setsWon(t) >= rules.setsToWin {
            s.finished = true
            s.winner = t
            return
        }
        if rules.sport.kind == .racket && rules.superTiebreak && isDecidingSet { s.superTb = true }
    }

    func setsWon(_ t: Int) -> Int { s.sets.filter { $0[t] > $0[1 - t] }.count }

    private var isDecidingSet: Bool {
        let need = rules.setsToWin - 1
        return rules.bestOf > 1 && setsWon(0) == need && setsWon(1) == need
    }

    @discardableResult func undo() -> Bool {
        guard let last = undoStack.popLast() else { return false }
        s = last
        return true
    }

    func swapServer() { pushUndo(); s.server = 1 - s.server }

    func nextPeriod() {
        pushUndo()
        s.period += 1
        s.clockAccumMs = 0
        s.clockStartedAt = 0
    }

    func prevPeriod() {
        guard s.period > 1 else { return }
        pushUndo()
        s.period -= 1
    }

    func adjustGames(_ team: Int, _ delta: Int) {
        guard s.games[team] + delta >= 0 else { return }
        pushUndo()
        s.games[team] += delta
        s.points = [0, 0]
        s.tiebreak = rules.tiebreak && s.games[0] == 6 && s.games[1] == 6
    }

    /// Returns false when the score is tied (no winner for the set).
    @discardableResult func closeSet() -> Bool {
        guard !s.finished else { return false }
        let score = rules.sport.kind == .racket ? s.games : s.points
        guard score[0] != score[1] else { return false }
        pushUndo()
        s.tiebreak = false; s.superTb = false
        s.games = [0, 0]; s.points = [0, 0]
        setWon(score)
        return true
    }

    @discardableResult func reopenLastSet() -> Bool {
        guard let last = s.sets.last else { return false }
        pushUndo()
        s.sets.removeLast()
        s.finished = false; s.winner = -1; s.superTb = false
        if rules.sport.kind == .racket { s.games = last; s.points = [0, 0] } else { s.points = last }
        s.tiebreak = rules.sport.kind == .racket && rules.tiebreak && s.games[0] == 6 && s.games[1] == 6
        return true
    }

    func newMatch() { undoStack.removeAll(); s = MatchState() }

    // MARK: clock
    func toggleClock() {
        if s.clockStartedAt == 0 { s.clockStartedAt = now() }
        else { s.clockAccumMs += now() - s.clockStartedAt; s.clockStartedAt = 0 }
    }
    func pauseClock() { if s.clockStartedAt != 0 { toggleClock() } }
    func resetClock() { s.clockAccumMs = 0; s.clockStartedAt = 0 }
    var clockRunning: Bool { s.clockStartedAt != 0 }
    var clockMs: Double { s.clockAccumMs + (s.clockStartedAt == 0 ? 0 : now() - s.clockStartedAt) }
    func setElapsed(_ ms: Double) {
        let running = clockRunning
        s.clockAccumMs = max(0, ms)
        s.clockStartedAt = running ? now() : 0
    }
    func adjustElapsed(_ delta: Double) { setElapsed(clockMs + delta) }

    // MARK: display
    func pointLabel(_ i: Int) -> String {
        if rules.sport.kind != .racket || s.tiebreak || s.superTb { return String(s.points[i]) }
        let o = 1 - i
        if s.points[0] >= 3 && s.points[1] >= 3 {
            if s.points[i] == s.points[o] { return "40" }
            return s.points[i] > s.points[o] ? "AD" : "40"
        }
        return ["0", "15", "30", "40"][min(s.points[i], 3)]
    }

    var phaseLabel: String {
        if s.finished { return "FINAL" }
        if s.superTb { return "SUPER TIE-BREAK" }
        if s.tiebreak { return "TIE-BREAK" }
        if rules.sport.kind == .racket && rules.goldenPoint && s.points == [3, 3] { return "GOLDEN POINT" }
        return ""
    }

    var periodLabel: String {
        switch rules.sport {
        case .FOOTBALL, .FUTSAL, .HANDBALL:
            return s.period == 1 ? "1st HALF" : s.period == 2 ? "2nd HALF" : "ET \(s.period - 2)"
        case .BASKETBALL: return "Q\(s.period)"
        default: return "P\(s.period)"
        }
    }

    static func formatClock(_ ms: Double) -> String {
        let t = max(0, Int(ms / 1000))
        let h = t / 3600, m = (t / 60) % 60, sec = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
}
