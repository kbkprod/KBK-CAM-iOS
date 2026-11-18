import SwiftUI

/// Welcome screen (first launch): language choice + an invitation to subscribe to the KBK PROD YouTube channel.
///
/// App Store rule (Review Guideline 3.2.2): an app may not require users to take an action such as
/// subscribing in order to use it. So subscribing is only suggested here — "Continue" always works.
struct GateView: View {
    static let channelURL = URL(string: "https://www.youtube.com/@kbkprod?sub_confirmation=1")!

    @EnvironmentObject var model: AppModel
    @AppStorage("gatePassed") private var passed = false
    @AppStorage("gateOpened") private var opened = false

    var body: some View {
        let _ = model.lang
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(0..<T.langs.count, id: \.self) { i in
                        let selected = model.lang == T.langs[i]
                        Button(T.langNames[i]) { model.lang = T.langs[i] }
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Capsule().fill(selected ? Color.white : Color.white.opacity(0.13)))
                            .foregroundColor(selected ? .black : .white)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)

                ZStack {
                    RoundedRectangle(cornerRadius: 22).fill(Palette.red)
                    Image(systemName: "video.fill").font(.system(size: 38)).foregroundColor(.white)
                }
                .frame(width: 84, height: 84)
                .padding(.top, 12)

                Text(T.r("مرحباً بك في KBK-CAM")).font(.title.bold())
                Text(T.r("بث مباشر للمباريات مع لوحة النتيجة")).foregroundColor(Palette.muted)

                Text(T.r("ادعمنا بالاشتراك في قناة KBK PROD على يوتيوب (اختياري)."))
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)

                Button {
                    UIApplication.shared.open(Self.channelURL)
                    opened = true
                } label: {
                    Text(T.r("▶  الاشتراك في القناة على يوتيوب"))
                        .font(.headline)
                        .frame(maxWidth: 340, minHeight: 54)
                        .background(Capsule().fill(Color(red: 1, green: 0, blue: 0.2)))
                        .foregroundColor(.white)
                }
                .buttonStyle(PressStyle())

                Button {
                    passed = true
                } label: {
                    Text(T.r("متابعة إلى التطبيق"))
                        .font(.headline)
                        .frame(maxWidth: 340, minHeight: 50)
                        .background(Capsule().fill(Palette.accent))
                        .foregroundColor(.white)
                }
                .buttonStyle(PressStyle())

                Text("youtube.com/@kbkprod").font(.footnote).foregroundColor(Palette.muted).padding(.top, 8)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .background(LinearGradient(colors: [Color(red: 0.04, green: 0.07, blue: 0.09), Color(red: 0.06, green: 0.16, blue: 0.14)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .environment(\.layoutDirection, T.isRTL ? .rightToLeft : .leftToRight)
        .overlay(alignment: .bottom) { ToastView(text: model.toast) }
    }
}
