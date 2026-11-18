import Foundation

/// Translation helper — same approach as the Android app: the Arabic text is the key,
/// French / English come from LangData. Unknown keys fall back to Arabic.
enum T {
    static let langs = ["ar", "fr", "en"]
    static let langNames = ["العربية", "Français", "English"]

    static var lang: String {
        get { UserDefaults.standard.string(forKey: "lang") ?? deviceLang() }
        set { UserDefaults.standard.set(newValue, forKey: "lang") }
    }

    static var isRTL: Bool { lang == "ar" }

    static func deviceLang() -> String {
        let code = Locale.preferredLanguages.first ?? "en"
        if code.hasPrefix("ar") { return "ar" }
        if code.hasPrefix("fr") { return "fr" }
        return "en"
    }

    /// iOS-only strings (not in the Android table).
    private static let extra: [String: (String, String)] = [
        "ادعمنا بالاشتراك في قناة KBK PROD على يوتيوب (اختياري).":
            ("Soutenez-nous en vous abonnant à la chaîne YouTube KBK PROD (facultatif).",
             "Support us by subscribing to the KBK PROD YouTube channel (optional)."),
        "متابعة إلى التطبيق": ("Continuer vers l'application", "Continue to the app")
    ]

    static func r(_ ar: String) -> String {
        let l = lang
        if l == "ar" { return ar }
        if let v = extra[ar] ?? LangData.table[ar] { return l == "fr" ? v.0 : v.1 }
        let trimmed = ar.trimmingCharacters(in: .whitespaces)
        if let v = LangData.table[trimmed], let range = ar.range(of: trimmed) {
            return ar.replacingCharacters(in: range, with: l == "fr" ? v.0 : v.1)
        }
        return ar
    }
}
