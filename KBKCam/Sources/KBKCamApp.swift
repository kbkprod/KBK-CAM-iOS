import SwiftUI

@main
struct KBKCamApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("gatePassed") private var passed = false

    var body: some View {
        if passed {
            MainView(model: model, stream: model.stream)
        } else {
            GateView()
        }
    }
}

// MARK: - shared styling
enum Palette {
    static let accent = Color(red: 0.07, green: 0.63, blue: 0.51)
    static let red = Color(red: 0.91, green: 0.28, blue: 0.23)
    static let yellow = Color(red: 0.84, green: 0.95, blue: 0.02)
    static let muted = Color(red: 0.56, green: 0.63, blue: 0.67)
    static let panel = Color(red: 0.043, green: 0.067, blue: 0.086)
    static let card = Color(red: 0.07, green: 0.10, blue: 0.13)
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct ToastView: View {
    let text: String?
    var body: some View {
        if let text {
            Text(text)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Capsule().fill(Color.black.opacity(0.85)))
                .foregroundColor(.white)
                .padding(.bottom, 24)
                .transition(.opacity)
        }
    }
}
