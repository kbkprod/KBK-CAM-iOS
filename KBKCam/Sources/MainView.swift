import AVFoundation
import HaishinKit
import SwiftUI

/// Screen = [ live preview (exactly what is broadcast) | control panel ] — panel on the right by default.
struct MainView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var stream: StreamController

    @State private var showSettings = false
    @State private var confirmStopLive = false
    @State private var confirmResetClock = false
    @State private var confirmNewMatch = false
    @State private var confirmExit = false
    @State private var editNames = false
    @State private var nameA = ""
    @State private var nameB = ""
    @State private var setClock = false
    @State private var clockMin = ""
    @State private var clockSec = ""
    @State private var showClockMode = false
    @State private var showRemote = false

    private var s: Settings { model.settings }
    private var sc: CGFloat { CGFloat(model.settings.buttonScale) / 100 }
    private var kind: Kind { model.engine.rules.sport.kind }

    var body: some View {
        let _ = model.tick
        HStack(spacing: 0) {
            if s.panelSide == "LEFT" && !model.panelHidden { panel }
            PreviewPane(model: model, stream: stream)
            if s.panelSide != "LEFT" && !model.panelHidden { panel }
        }
        .environment(\.layoutDirection, .leftToRight)
        .background(Color(white: 0.02).ignoresSafeArea())
        .overlay(alignment: .bottom) { ToastView(text: model.toast) }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(model) }
        .confirmationDialog(T.r("إيقاف البث؟"), isPresented: $confirmStopLive, titleVisibility: .visible) {
            Button(T.r("إيقاف"), role: .destructive) { Task { await model.toggleLive() } }
            Button(T.r("إلغاء"), role: .cancel) { }
        }
        .confirmationDialog(T.r("تصفير المؤقت؟"), isPresented: $confirmResetClock, titleVisibility: .visible) {
            Button(T.r("تصفير"), role: .destructive) { model.clockReset() }
            Button(T.r("إلغاء"), role: .cancel) { }
        }
        .confirmationDialog(T.r("مباراة جديدة؟"), isPresented: $confirmNewMatch, titleVisibility: .visible) {
            Button(T.r("نعم"), role: .destructive) { model.newMatch() }
            Button(T.r("إلغاء"), role: .cancel) { }
        } message: { Text(T.r("سيتم تصفير النتيجة والمؤقت.")) }
        .confirmationDialog(T.r("وضع المؤقت"), isPresented: $showClockMode, titleVisibility: .visible) {
            Button(T.r("تصاعدي (00:00 ←)")) { model.setClockMode(0) }
            ForEach([10, 12, 20, 25, 30, 40, 45], id: \.self) { m in
                Button(T.r("تنازلي \(m) د")) { model.setClockMode(m) }
            }
            Button(T.r("إلغاء"), role: .cancel) { }
        }
        .alert(T.r("أسماء الفريقين"), isPresented: $editNames) {
            TextField(T.r("الفريق أ"), text: $nameA)
            TextField(T.r("الفريق ب"), text: $nameB)
            Button(T.r("حفظ")) {
                model.settings.nameA = nameA.trimmingCharacters(in: .whitespaces).isEmpty ? "TEAM A" : nameA
                model.settings.nameB = nameB.trimmingCharacters(in: .whitespaces).isEmpty ? "TEAM B" : nameB
            }
            Button(T.r("إلغاء"), role: .cancel) { }
        }
        .alert(T.r("ضبط الوقت (دقائق : ثواني)"), isPresented: $setClock) {
            TextField("mm", text: $clockMin).keyboardType(.numberPad)
            TextField("ss", text: $clockSec).keyboardType(.numberPad)
            Button(T.r("ضبط")) {
                if let m = Int(clockMin), let sec = Int(clockSec) { model.clockSet(minutes: m, seconds: sec) }
                else { model.say(T.r("قيمة غير صحيحة")) }
            }
            Button(T.r("إلغاء"), role: .cancel) { }
        }
        .alert(T.r("التحكم عن بعد"), isPresented: $showRemote) {
            Button(T.r("حسناً"), role: .cancel) { }
        } message: { Text(remoteMessage) }
        .task { await startCamera() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            Task { await stream.updateOrientation() }
        }
    }

    private func startCamera() async {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        await stream.start(model.settings)
        model.refresh()
    }

    private var remoteMessage: String {
        if !s.remoteEnabled { return T.r("التحكم عن بعد معطّل. فعّله من الإعدادات.") }
        guard let url = model.remoteURL else { return T.r("اتصل بشبكة Wi-Fi (أو شغّل نقطة الاتصال) أولاً.") }
        return T.r("على هاتف آخر متصل بنفس شبكة Wi-Fi افتح المتصفح واكتب:") + "\n\n" + url + "\n\n"
            + T.r("ستظهر أزرار للنقاط والمؤقت والتراجع واللقطات.")
    }

    // MARK: - control panel
    private var panel: some View {
        ScrollView {
            VStack(spacing: 8) {
                header
                if s.clockOnTop { clockSection; teamsSection } else { teamsSection; clockSection }
                setsSection
                HStack(spacing: 6) {
                    small(T.r("↶ تراجع")) { model.undo() }
                    small(T.r("⟲ كاميرا")) { Task { await stream.switchCamera() } }
                    small(stream.highlightCount == 0 ? T.r("★ لقطة") : "★ \(stream.highlightCount)", fg: Palette.yellow) { model.markHighlight() }
                }
                HStack(spacing: 6) {
                    Button { Task { await model.toggleRecording() } } label: {
                        Text(stream.isRecording ? "■  REC" : "●  REC")
                            .font(.system(size: 14 * sc, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 54 * sc)
                            .background(Capsule().fill(stream.isRecording ? Palette.red : Color.white.opacity(0.13)))
                            .foregroundColor(stream.isRecording ? .white : Color(red: 1, green: 0.54, blue: 0.5))
                    }
                    .buttonStyle(PressStyle())
                    Button {
                        if stream.isLive || stream.isConnecting { confirmStopLive = true } else { Task { await model.toggleLive() } }
                    } label: {
                        Text(stream.isLive || stream.isConnecting ? T.r("■  إيقاف البث") : T.r("●  بث مباشر"))
                            .font(.system(size: 15 * sc, weight: .heavy))
                            .frame(maxWidth: .infinity, minHeight: 54 * sc)
                            .background(Capsule().fill(stream.isLive ? Color(red: 0.48, green: 0.12, blue: 0.09) : Palette.red))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PressStyle())
                    .layoutPriority(1)
                }
            }
            .padding(10)
        }
        .frame(width: 330 * sc)
        .background(Palette.panel.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("KBK-CAM").font(.headline.weight(.heavy)).foregroundColor(Palette.accent).kerning(1)
            Spacer()
            matchMenu
            Button { showSettings = true } label: { circleIcon("gearshape.fill") }
        }
    }

    private var matchMenu: some View {
        Menu {
            Button(T.r("الفترة / الشوط التالي")) { model.nextPeriod() }
            Button(T.r("تبديل الإرسال")) { model.swapServer() }
            Button(T.r("تعديل أسماء الفريقين")) { nameA = s.nameA; nameB = s.nameB; editNames = true }
            Button(T.r("وضع المؤقت")) { showClockMode = true }
            Button(s.showClock ? T.r("إخفاء المؤقت") : T.r("إظهار المؤقت")) { model.settings.showClock.toggle() }
            Button(s.showScoreboard ? T.r("إخفاء لوحة النتيجة") : T.r("إظهار لوحة النتيجة")) { model.settings.showScoreboard.toggle() }
            Button(s.showLogos ? T.r("إخفاء شعارات الرعاة") : T.r("إظهار شعارات الرعاة")) { model.settings.showLogos.toggle() }
            Menu(T.r("شكل لوحة النتيجة...")) {
                Picker("", selection: $model.settings.style) {
                    ForEach(Settings.styles.indices, id: \.self) { i in Text(T.r(Settings.styleNames[i])).tag(Settings.styles[i]) }
                }
            }
            Menu(T.r("موضع لوحة النتيجة...")) {
                Picker("", selection: $model.settings.position) {
                    ForEach(Settings.positions.indices, id: \.self) { i in Text(T.r(Settings.positionNames[i])).tag(Settings.positions[i]) }
                }
            }
            Button(T.r("التحكم عن بعد (هاتف آخر)")) { showRemote = true }
            Button(T.r("مباراة جديدة"), role: .destructive) { confirmNewMatch = true }
            Divider()
            Button(T.r("⇄ نقل لوحة التحكم إلى ") + (s.panelSide == "LEFT" ? T.r("اليمين") : T.r("اليسار"))) {
                model.settings.panelSide = s.panelSide == "LEFT" ? "RIGHT" : "LEFT"
            }
            Button(T.r("⇄ تبديل أماكن أزرار الفريقين")) { model.settings.swapTeamButtons.toggle() }
            Button(s.clockOnTop ? T.r("↓ المؤقت تحت أزرار النقاط") : T.r("↑ المؤقت فوق أزرار النقاط")) { model.settings.clockOnTop.toggle() }
            Menu(T.r("حجم الأزرار...")) {
                Picker("", selection: $model.settings.buttonScale) {
                    Text(T.r("صغير")).tag(85); Text(T.r("عادي")).tag(100); Text(T.r("كبير")).tag(120)
                }
            }
            Button(T.r("إخفاء لوحة التحكم (شاشة كاملة)")) { model.panelHidden = true }
            Menu(T.r("🌐 اللغة / Language")) {
                Picker("", selection: $model.lang) {
                    ForEach(T.langs.indices, id: \.self) { i in Text(T.langNames[i]).tag(T.langs[i]) }
                }
            }
        } label: { circleIcon("ellipsis") }
    }

    private func circleIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 42, height: 42)
            .background(Circle().fill(Color.white.opacity(0.1)))
            .overlay(Circle().stroke(Color.white.opacity(0.2)))
            .foregroundColor(.white)
    }

    // MARK: sections
    private var teamsSection: some View {
        section(T.r("النقاط  (اضغط على الفريق)")) {
            HStack(alignment: .top, spacing: 8) {
                let order = s.swapTeamButtons ? [1, 0] : [0, 1]
                ForEach(order, id: \.self) { i in
                    VStack(spacing: 6) {
                        teamCard(i)
                        HStack(spacing: 4) {
                            if kind == .racket {
                                small(T.r("− شوط")) { model.adjustGames(i, -1) }
                                small(T.r("+ شوط")) { model.adjustGames(i, 1) }
                            } else {
                                small("−1") { model.minus(i) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func teamCard(_ i: Int) -> some View {
        let color = Color(s.uiColor(i))
        let logo = i == 0 ? model.renderer.logoA : model.renderer.logoB
        let serving = kind != .goals && model.engine.s.server == i && s.showServe
        return Button { model.point(i) } label: {
            VStack(spacing: 4) {
                Capsule().fill(color).frame(width: 40, height: 4)
                HStack(spacing: 5) {
                    if let logo, s.showTeamLogos {
                        Image(uiImage: logo).resizable().scaledToFit().frame(width: 22, height: 22)
                    }
                    Text(i == 0 ? s.nameA : s.nameB).font(.system(size: 13 * sc, weight: .bold)).lineLimit(1)
                }
                Text(model.engine.pointLabel(i)).font(.system(size: 38 * sc, weight: .heavy))
                Text(model.subText(i)).font(.system(size: 10)).foregroundColor(Palette.muted).lineLimit(1)
                Text(T.r("● إرسال")).font(.system(size: 10)).foregroundColor(Palette.yellow).opacity(serving ? 1 : 0)
                Text(T.r("+ نقطة"))
                    .font(.system(size: 13 * sc, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 34 * sc)
                    .background(Capsule().fill(Palette.accent))
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
            .background(RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [color.opacity(0.35), Color(white: 0.09)], startPoint: .top, endPoint: .bottom)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.8), lineWidth: 2))
        }
        .buttonStyle(PressStyle())
    }

    private var clockSection: some View {
        section(T.r("المؤقت")) {
            HStack(spacing: 4) {
                tapLong("−10", tap: { model.clockAdjust(-10_000) }, long: { model.clockAdjust(-60_000); model.say(T.r("−1 دقيقة")) })
                small(model.engine.clockRunning ? "❚❚" : "▶", bg: model.engine.clockRunning ? Color.white.opacity(0.2) : Palette.accent) { model.clockToggle() }
                Text(model.clockText)
                    .font(.system(size: 24 * sc, weight: .heavy, design: .monospaced))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundColor(model.engine.clockRunning ? .white : (model.engine.clockMs > 0 ? Color(red: 0.95, green: 0.79, blue: 0.3) : Palette.muted))
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
                    .onTapGesture { model.clockToggle() }
                    .onLongPressGesture {
                        let ms = Int(s.shownClock(model.engine) / 1000)
                        clockMin = "\(ms / 60)"; clockSec = String(format: "%02d", ms % 60)
                        setClock = true
                    }
                tapLong("+10", tap: { model.clockAdjust(10_000) }, long: { model.clockAdjust(60_000); model.say(T.r("+1 دقيقة")) })
                small("⟲") { confirmResetClock = true }
            }
            Text(s.clockMode == "DOWN" ? T.r("تنازلي · ") + "\(s.periodMinutes)" + T.r(" د   (تغيير)") : T.r("تصاعدي   (تغيير)"))
                .font(.caption2)
                .foregroundColor(Palette.muted)
                .frame(maxWidth: .infinity)
                .onTapGesture { showClockMode = true }
        }
    }

    private var setsSection: some View {
        section(T.r("الأشواط / المجموعات")) {
            if kind == .goals {
                HStack(spacing: 4) {
                    small("◀") { model.prevPeriod() }
                    Text(model.periodText).font(.system(size: 17 * sc, weight: .bold)).frame(maxWidth: .infinity).layoutPriority(1)
                    small("▶") { model.nextPeriod() }
                }
            } else {
                Text(model.setText).font(.system(size: 15 * sc, weight: .bold)).frame(maxWidth: .infinity)
                HStack(spacing: 6) {
                    small(T.r("✓ إنهاء المجموعة")) { model.closeSet() }
                    small(T.r("↩ إرجاع آخر مجموعة")) { model.reopenSet() }
                }
            }
        }
    }

    // MARK: building blocks
    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(Palette.muted)
                .frame(maxWidth: .infinity, alignment: T.isRTL ? .trailing : .leading)
            content()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12)))
    }

    private func small(_ title: String, fg: Color = .white, bg: Color = Color.white.opacity(0.13), action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13 * sc, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, minHeight: 44 * sc)
                .background(Capsule().fill(bg))
                .foregroundColor(fg)
        }
        .buttonStyle(PressStyle())
    }

    /// Button with a different action on long press (used for −10/+10 → −1/+1 minute).
    private func tapLong(_ title: String, tap: @escaping () -> Void, long: @escaping () -> Void) -> some View {
        Text(title)
            .font(.system(size: 13 * sc, weight: .bold))
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 44 * sc)
            .background(Capsule().fill(Color.white.opacity(0.13)))
            .foregroundColor(.white)
            .contentShape(Capsule())
            .onTapGesture(perform: tap)
            .onLongPressGesture(perform: long)
    }
}

/// The camera preview at the stream's aspect ratio (shows exactly what viewers see), with status and full-screen toggle.
struct PreviewPane: View {
    @ObservedObject var model: AppModel
    @ObservedObject var stream: StreamController
    @State private var zoomStart: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
            CameraPreview(stream: stream)
                .equatable()
                .aspectRatio(CGFloat(model.settings.width) / CGFloat(model.settings.height), contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(MagnificationGesture()
                    .onChanged { v in stream.setZoom(zoomStart * v) }
                    .onEnded { _ in zoomStart = stream.zoom })
            Text(model.statusText)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(stream.isLive ? Palette.red : Color.black.opacity(0.7)))
                .foregroundColor(.white)
                .padding(10)
            VStack {
                HStack {
                    Spacer()
                    Button { model.panelHidden.toggle() } label: {
                        Image(systemName: model.panelHidden ? "sidebar.right" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                            .foregroundColor(.white)
                    }
                }
                Spacer()
            }
            .padding(8)
        }
    }
}

/// Wraps HaishinKit's Metal preview view once: Equatable so SwiftUI never rebuilds it on score/clock refreshes.
struct CameraPreview: View, Equatable {
    let stream: StreamController
    static func == (a: CameraPreview, b: CameraPreview) -> Bool { a.stream === b.stream }
    var body: some View {
        MTHKViewRepresentable(previewSource: stream, videoGravity: .resizeAspect)
    }
}
