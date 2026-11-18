import PhotosUI
import SwiftUI

/// Settings form (same options as Android), with a live preview of the scoreboard.
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var s = Settings()
    @State private var loaded = false
    @State private var logoVersion = 0
    @State private var itemA: PhotosPickerItem?
    @State private var itemB: PhotosPickerItem?
    @State private var item1: PhotosPickerItem?
    @State private var item2: PhotosPickerItem?
    @State private var portText = ""

    private let presets: [(String, String)] = [
        ("YouTube", "rtmp://a.rtmp.youtube.com/live2"),
        ("Facebook (RTMPS)", "rtmps://live-api-s.facebook.com:443/rtmp"),
        ("Twitch", "rtmp://live.twitch.tv/app")
    ]

    var body: some View {
        let _ = model.lang
        let _ = logoVersion
        NavigationStack {
            Form {
                Section(T.r("اللغة")) {
                    Picker("Language", selection: $model.lang) {
                        ForEach(T.langs.indices, id: \.self) { i in Text(T.langNames[i]).tag(T.langs[i]) }
                    }
                }

                Section {
                    Menu(T.r("اختر منصة...")) {
                        ForEach(presets, id: \.0) { p in Button(p.0) { s.rtmpUrl = p.1 } }
                    }
                    TextField(T.r("رابط الخادم"), text: $s.rtmpUrl)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .environment(\.layoutDirection, .leftToRight)
                    SecureField(T.r("مفتاح البث (Stream key)"), text: $s.streamKey)
                        .environment(\.layoutDirection, .leftToRight)
                    intPicker("الدقة", ["480p", "720p (موصى به)", "1080p"], [480, 720, 1080], $s.resolution)
                    intPicker("الإطارات/ث", ["25", "30"], [25, 30], $s.fps)
                    intPicker("معدل البت", ["1 Mbps", "1.5 Mbps", "2.5 Mbps", "3 Mbps", "4.5 Mbps", "6 Mbps", "8 Mbps"],
                              [1000, 1500, 2500, 3000, 4500, 6000, 8000], $s.bitrateKbps)
                    Toggle(T.r("تسجيل نسخة على الهاتف أثناء البث"), isOn: $s.recordWhileStreaming)
                } header: { Text(T.r("البث المباشر (RTMP)")) }
                footer: { Text(T.r("يعمل مع YouTube وFacebook وTwitch وأي خادم RTMP/RTMPS (مثل OBS أو nginx-rtmp).")) }
                .disabled(model.stream.isLive || model.stream.isRecording)

                Section {
                    Picker(T.r("الرياضة"), selection: $s.sport) {
                        ForEach(Sport.allCases, id: \.self) { sp in Text(T.r(sp.label)).tag(sp) }
                    }
                    TextField(T.r("الفريق / اللاعب أ"), text: $s.nameA).textInputAutocapitalization(.characters)
                    TextField(T.r("الفريق / اللاعب ب"), text: $s.nameB).textInputAutocapitalization(.characters)
                    intPicker("لون الفريق أ", Settings.colorNames, Array(Settings.colors.indices), $s.colorA)
                    intPicker("لون الفريق ب", Settings.colorNames, Array(Settings.colors.indices), $s.colorB)
                    intPicker("عدد المجموعات", ["مجموعة واحدة", "أفضل 3", "أفضل 5"], [1, 3, 5], $s.bestOf)
                    Toggle(T.r("تنس/بادل: شوط فاصل (Tie-break) عند 6-6"), isOn: $s.tiebreak)
                    Toggle(T.r("تنس/بادل: المجموعة الحاسمة = Super tie-break (10)"), isOn: $s.superTiebreak)
                    Toggle(T.r("تنس/بادل: النقطة الذهبية (بدون أفضلية)"), isOn: $s.goldenPoint)
                    intPicker("نقاط المجموعة (رياضات الإرسال)", ["حسب الرياضة", "11", "15", "21", "25"], [0, 11, 15, 21, 25], $s.rallyTarget)
                } header: { Text(T.r("المباراة")) }
                footer: { Text(T.r("تغيير الرياضة يبدأ مباراة جديدة.")) }

                Section {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .background(LinearGradient(colors: [Color(red: 0.23, green: 0.43, blue: 0.56), Color(red: 0.14, green: 0.35, blue: 0.25)],
                                                   startPoint: .top, endPoint: .bottom))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    strPicker("الشكل", Settings.styleNames, Settings.styles, $s.style)
                    strPicker("الموضع", Settings.positionNames, Settings.positions, $s.position)
                    intPicker("الحجم", ["صغير", "عادي", "كبير", "كبير جداً"], [80, 100, 120, 140], $s.sizePct)
                    Toggle(T.r("إظهار لوحة النتيجة"), isOn: $s.showScoreboard)
                    Toggle(T.r("إظهار شعار الفريق بجانب الاسم"), isOn: $s.showTeamLogos)
                    Toggle(T.r("إظهار نتائج المجموعات"), isOn: $s.showSets)
                    Toggle(T.r("إظهار مؤشر الإرسال"), isOn: $s.showServe)
                    Toggle(T.r("إظهار رقم الفترة"), isOn: $s.showPeriod)
                } header: { Text(T.r("لوحة النتيجة على الفيديو")) }
                footer: { Text(T.r("معاينة مباشرة — تتغير مع كل خيار.")) }

                Section {
                    Toggle(T.r("إظهار المؤقت على الفيديو"), isOn: $s.showClock)
                    intPicker("حجم الوقت", ["عادي", "كبير", "كبير جداً"], [100, 140, 180], $s.clockScale)
                    strPicker("الاتجاه", ["تصاعدي (00:00 ← )", "تنازلي (عدّ عكسي)"], ["UP", "DOWN"], $s.clockMode)
                    intPicker("مدة الفترة (للتنازلي)", ["5 د", "8 د", "10 د", "12 د", "15 د", "20 د", "25 د", "30 د", "35 د", "40 د", "45 د"],
                              [5, 8, 10, 12, 15, 20, 25, 30, 35, 40, 45], $s.periodMinutes)
                } header: { Text(T.r("المؤقت")) }
                footer: { Text(T.r("في الشاشة الرئيسية: ▶/❚❚ تشغيل وإيقاف، −10/+10 ثوانٍ (ضغطة طويلة = دقيقة)، ضغطة طويلة على الوقت لضبطه يدوياً، ⟲ تصفير.")) }

                Section {
                    strPicker("مكان لوحة التحكم", ["اليمين", "اليسار"], ["RIGHT", "LEFT"], $s.panelSide)
                    Toggle(T.r("تبديل أماكن أزرار الفريقين (ب يسار، أ يمين)"), isOn: $s.swapTeamButtons)
                    Toggle(T.r("المؤقت فوق أزرار النقاط"), isOn: $s.clockOnTop)
                    intPicker("حجم الأزرار", ["صغير", "عادي", "كبير"], [85, 100, 120], $s.buttonScale)
                } header: { Text(T.r("أماكن الأزرار (لوحة التحكم)")) }

                Section(T.r("شعارات الفريقين")) {
                    logoRow("logoA", T.r("شعار الفريق أ"), $itemA)
                    logoRow("logoB", T.r("شعار الفريق ب"), $itemB)
                }

                Section {
                    logoRow("logo1", T.r("اختيار شعار 1"), $item1)
                    logoRow("logo2", T.r("اختيار شعار 2"), $item2)
                    Toggle(T.r("إظهار الشعارات على الفيديو"), isOn: $s.showLogos)
                } header: { Text(T.r("شعارات الرعاة")) }
                footer: { Text(T.r("استخدم صور PNG بخلفية شفافة لأفضل نتيجة.")) }

                Section {
                    intPicker("المدة قبل الضغط", ["10 ث", "15 ث", "20 ث", "30 ث", "45 ث", "60 ث"], [10, 15, 20, 30, 45, 60], $s.hlBefore)
                    intPicker("المدة بعد الضغط", ["0 ث", "3 ث", "5 ث", "10 ث"], [0, 3, 5, 10], $s.hlAfter)
                } header: { Text(T.r("اللقطات (Highlights)")) }
                footer: { Text(T.r("اضغط ★ أثناء التسجيل؛ عند إيقاف التسجيل يُحفظ كل مقطع منفصلاً في Movies/KBK-CAM/Highlights.")
                    .replacingOccurrences(of: "Movies/KBK-CAM/Highlights", with: "Photos")) }

                Section {
                    Toggle(T.r("تفعيل التحكم من هاتف آخر عبر Wi-Fi"), isOn: $s.remoteEnabled)
                    TextField(T.r("المنفذ"), text: $portText).keyboardType(.numberPad)
                } header: { Text(T.r("التحكم عن بعد")) }
                footer: { Text(T.r("الرابط يظهر من القائمة ⋮ ← التحكم عن بعد. أعد فتح التطبيق بعد تغيير المنفذ.")) }
            }
            .navigationTitle(T.r("إعدادات KBK-CAM"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T.r("إلغاء")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(T.r("حفظ")) { save() } }
            }
        }
        .environment(\.layoutDirection, T.isRTL ? .rightToLeft : .leftToRight)
        .onAppear {
            guard !loaded else { return }
            s = model.settings
            portText = String(s.remotePort)
            loaded = true
        }
    }

    private func save() {
        var out = s
        if let p = Int(portText), (1024...65535).contains(p) { out.remotePort = p }
        if out.nameA.trimmingCharacters(in: .whitespaces).isEmpty { out.nameA = "TEAM A" }
        if out.nameB.trimmingCharacters(in: .whitespaces).isEmpty { out.nameB = "TEAM B" }
        model.settings = out
        dismiss()
    }

    private var previewImage: UIImage {
        let e = ScoreEngine()
        s.apply(to: e)
        switch e.rules.sport.kind {
        case .racket: e.s.points = [2, 3]; e.s.games = [3, 2]; e.s.sets = [[6, 4]]
        case .rally: e.s.points = [18, 16]; e.s.sets = [[25, 21]]
        case .goals: e.s.points = [2, 1]; e.s.period = 2
        }
        if s.clockMode == "DOWN" { e.setElapsed(max(0, Double(s.periodMinutes) * 60_000 - 432_000)) }
        else { e.setElapsed(23 * 60_000 + 41_000) }
        return model.renderer.render(width: 1280, height: 720, engine: e, settings: s)
    }

    // MARK: form helpers
    private func intPicker(_ title: String, _ names: [String], _ values: [Int], _ binding: Binding<Int>) -> some View {
        Picker(T.r(title), selection: binding) {
            ForEach(values.indices, id: \.self) { i in Text(T.r(names[i])).tag(values[i]) }
        }
    }

    private func strPicker(_ title: String, _ names: [String], _ values: [String], _ binding: Binding<String>) -> some View {
        Picker(T.r(title), selection: binding) {
            ForEach(values.indices, id: \.self) { i in Text(T.r(names[i])).tag(values[i]) }
        }
    }

    private func logoRow(_ name: String, _ title: String, _ item: Binding<PhotosPickerItem?>) -> some View {
        HStack {
            if let img = LogoStore.load(name) {
                Image(uiImage: img).resizable().scaledToFit().frame(width: 40, height: 40)
            } else {
                Text(T.r("لا يوجد شعار")).foregroundColor(.secondary)
            }
            Spacer()
            PhotosPicker(selection: item, matching: .images) { Text(title) }
                .buttonStyle(.borderless)
            Button(T.r("حذف"), role: .destructive) {
                LogoStore.remove(name)
                model.loadLogos()
                logoVersion += 1
            }
            .buttonStyle(.borderless)
        }
        .onChange(of: item.wrappedValue) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    LogoStore.save(name, data: data)
                    model.loadLogos()
                    logoVersion += 1
                }
                item.wrappedValue = nil
            }
        }
    }
}
