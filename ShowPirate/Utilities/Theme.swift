import AppKit
import SwiftUI

extension NSColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(nsColor: NSColor(hex: hex, alpha: alpha))
    }

    init(lightHex: UInt32, darkHex: UInt32, alpha: Double = 1) {
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? darkHex : lightHex, alpha: alpha)
        }))
    }
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        resolvedColorScheme
    }

    var resolvedColorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            if Self.macOSIsDark || Self.isEvening {
                return .dark
            }
            return .light
        }
    }

    func applyToApp() {
        let scheme = resolvedColorScheme
        DispatchQueue.main.async {
            NSApplication.shared.appearance = scheme == .dark
                ? NSAppearance(named: .darkAqua)
                : NSAppearance(named: .aqua)
        }
    }

    static var macOSIsDark: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    /// Local evening window so Auto is dark at night even if macOS is set to Light.
    static var isEvening: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 19 || hour < 7
    }
}

enum Theme {
    // ColorHunt: https://colorhunt.co/palette/e62727f3f2ecdcdcdc1e93ab
    static let huntRed = Color(hex: 0xE62727)
    static let huntCream = Color(hex: 0xF3F2EC)
    static let huntGray = Color(hex: 0xDCDCDC)
    static let huntTeal = Color(hex: 0x1E93AB)
    static let watchedGreen = Color(hex: 0x2EBB4A)

    static let ink = Color(lightHex: 0xF3F2EC, darkHex: 0x0B1C21)
    static let navyDeep = Color(lightHex: 0xFFFFFF, darkHex: 0x102830)
    static let navy = Color(lightHex: 0xDCDCDC, darkHex: 0x16586A)
    static let sky = huntTeal
    static let gold = huntRed
    static let goldDim = Color(hex: 0xB01E1E)
    static let lantern = huntRed
    static let crimson = huntRed
    static let cyan = huntTeal
    static let lime = huntTeal
    static let purple = huntGray
    static let pink = huntRed
    static let parchment = Color(lightHex: 0x3A3A3A, darkHex: 0xF3F2EC)
    static let wood = Color(hex: 0x3A3A3A)
    static let cream = Color(lightHex: 0x0B1C21, darkHex: 0xF3F2EC)
    static let hairline = Color(lightHex: 0x000000, darkHex: 0xFFFFFF)

    static let cardRadius: CGFloat = 12
    static let posterAspect: CGFloat = 2.0 / 3.0
    static let bannerAspect: CGFloat = 16.0 / 9.0

    static let mapMarks: [Color] = [huntRed, huntTeal, cream, huntGray]

    static func mapMark(at index: Int) -> Color {
        mapMarks[index % mapMarks.count]
    }
}

struct ScreenBackground: View {
    var body: some View {
        Theme.ink
            .ignoresSafeArea()
    }
}

extension View {
    func pirateCardShadow() -> some View {
        shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
    }

    func pirateScreen() -> some View {
        background { ScreenBackground() }
    }

    func pirateAppearance(_ preference: AppearancePreference) -> some View {
        modifier(PirateAppearanceModifier(preference: preference))
    }
}

private struct PirateAppearanceModifier: ViewModifier {
    var preference: AppearancePreference
    @State private var resolved: ColorScheme = .light

    private let themeChanged = Notification.Name("AppleInterfaceThemeChangedNotification")

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(resolved)
            .onAppear(perform: refresh)
            .onChange(of: preference) { _, _ in refresh() }
            .onReceive(DistributedNotificationCenter.default.publisher(for: themeChanged)) { _ in
                refresh()
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                guard preference == .system else { return }
                refresh()
            }
    }

    private func refresh() {
        let scheme = preference.resolvedColorScheme
        resolved = scheme
        preference.applyToApp()
    }
}
