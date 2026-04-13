import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

/// All mutable state for the teleprompter. Observed by every view.
final class PrompterState: ObservableObject {
    // MARK: - Content
    @Published var rawText: String = DefaultScript.text
    @Published var currentFileURL: URL?
    /// Most-recently-opened scripts, newest first. Capped at `recentLimit`.
    @Published var recentFiles: [URL] = []

    private let recentLimit = 10

    // MARK: - Playback
    @Published var isPlaying: Bool = false
    /// Tokens that views observe to trigger one-shot events.
    @Published var restartToken: UUID = UUID()
    /// Points per second the text scrolls upward.
    @Published var speed: Double = 40

    // MARK: - Typography
    @Published var fontName: String = "Helvetica Neue"
    @Published var fontSize: Double = 38
    @Published var fontWeight: NamedFontWeight = .medium
    @Published var lineSpacing: Double = 10
    @Published var letterSpacing: Double = 0
    @Published var textColor: Color = .white
    @Published var textAlignment: TextAlignment = .center
    @Published var mirrorText: Bool = false

    // MARK: - Background
    @Published var backgroundColor: Color = .black
    @Published var backgroundOpacity: Double = 0.88
    @Published var cornerRadius: Double = 18
    @Published var fadeAmount: Double = 90

    // MARK: - Window
    @Published var windowHeight: Double = 280
    @Published var windowWidthFraction: Double = 0.43
    /// Bump this UUID to ask the window controller to snap back under the notch.
    @Published var repositionRequested: UUID = UUID()

    // MARK: - Toolbar
    /// When true, the floating toolbar lays itself out vertically.
    @Published var toolbarVertical: Bool = false

    // MARK: - Find highlight
    /// Non-empty while the Find window wants matches highlighted in the
    /// rendered script. Cleared when the query is empty or the window closes.
    @Published var highlightQuery: String = ""
    @Published var highlightCaseSensitive: Bool = false

    /// Fires when the user turns the scroll wheel / two-finger scrolls over the
    /// teleprompter window. The value is the raw `scrollingDeltaY` from AppKit.
    let manualScroll = PassthroughSubject<CGFloat, Never>()

    /// Fires when something (like the Find window) wants the teleprompter to
    /// jump to an absolute y-offset in the content.
    let scrollTo = PassthroughSubject<CGFloat, Never>()

    private var keyMonitor: Any?
    private var scrollMonitor: Any?
    private var persistCancellables = Set<AnyCancellable>()

    init() {
        loadSettings()
        installPersistence()
        installKeyMonitor()
        installScrollMonitor()
    }

    deinit {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Commands

    func togglePlay() { isPlaying.toggle() }

    func restart() {
        isPlaying = false
        restartToken = UUID()
    }

    func adjustSpeed(_ delta: Double) {
        speed = max(5, min(500, speed + delta))
    }

    func adjustHeight(_ delta: Double) {
        windowHeight = max(120, min(1400, windowHeight + delta))
    }

    func adjustFontSize(_ delta: Double) {
        fontSize = max(10, min(180, fontSize + delta))
    }

    /// Restore every appearance/window setting to its compile-time default.
    /// Transient playback fields (isPlaying, currentFileURL, rawText) are left
    /// alone so the user doesn't lose what they're reading.
    func resetToDefaults() {
        speed = 40
        fontName = "Helvetica Neue"
        fontSize = 38
        fontWeight = .medium
        lineSpacing = 10
        letterSpacing = 0
        textColor = .white
        textAlignment = .center
        mirrorText = false
        backgroundColor = .black
        backgroundOpacity = 0.88
        cornerRadius = 18
        fadeAmount = 90
        windowHeight = 280
        windowWidthFraction = 0.43
        toolbarVertical = false
        repositionRequested = UUID()
    }

    // MARK: - File I/O

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsOtherFileTypes = false
        // Markdown only. We try the system-provided UTType first, then fall
        // back to a filename-extension match so directories without any .md
        // files still hide their other contents.
        var types: [UTType] = []
        if let markdown = UTType("net.daringfireball.markdown") { types.append(markdown) }
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        panel.allowedContentTypes = types
        panel.title = "Choose a Markdown Script"
        panel.prompt = "Load"
        // The main window floats, so the default panel would appear under it.
        // Push the panel above .floating and activate the app so it gets focus.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        if panel.runModal() == .OK, let url = panel.url {
            loadFile(url)
        }
    }

    func loadFile(_ url: URL) {
        guard url.pathExtension.lowercased() == "md" else {
            NSSound.beep()
            return
        }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            rawText = text
            currentFileURL = url
            recordRecent(url)
            restart()
        } catch {
            NSSound.beep()
        }
    }

    func reloadCurrent() {
        guard let url = currentFileURL else { return }
        loadFile(url)
    }

    // MARK: - Recent files

    private func recordRecent(_ url: URL) {
        var list = recentFiles
        list.removeAll { $0 == url }
        list.insert(url, at: 0)
        if list.count > recentLimit {
            list = Array(list.prefix(recentLimit))
        }
        recentFiles = list
    }

    func clearRecent() {
        recentFiles = []
    }

    // MARK: - Keyboard

    /// Space = play/pause globally (as long as no text field has focus).
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            // Don't swallow keys when the user is editing text.
            if let responder = NSApp.keyWindow?.firstResponder, responder is NSTextView {
                return event
            }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == 49 && mods.isEmpty { // space
                self.togglePlay()
                return nil
            }
            return event
        }
    }

    // MARK: - Persistence

    private enum Keys {
        static let speed = "np.speed"
        static let fontName = "np.fontName"
        static let fontSize = "np.fontSize"
        static let fontWeight = "np.fontWeight"
        static let lineSpacing = "np.lineSpacing"
        static let letterSpacing = "np.letterSpacing"
        static let textColor = "np.textColor"
        static let textAlignment = "np.textAlignment"
        static let mirrorText = "np.mirrorText"
        static let backgroundColor = "np.backgroundColor"
        static let backgroundOpacity = "np.backgroundOpacity"
        static let cornerRadius = "np.cornerRadius"
        static let fadeAmount = "np.fadeAmount"
        static let windowHeight = "np.windowHeight"
        static let windowWidthFraction = "np.windowWidthFraction"
        static let toolbarVertical = "np.toolbarVertical"
        static let recentFiles = "np.recentFiles"
    }

    /// Populate from `UserDefaults`. Missing keys keep the compiled-in default.
    private func loadSettings() {
        let d = UserDefaults.standard
        if d.object(forKey: Keys.speed) != nil { speed = d.double(forKey: Keys.speed) }
        if let name = d.string(forKey: Keys.fontName) { fontName = name }
        if d.object(forKey: Keys.fontSize) != nil { fontSize = d.double(forKey: Keys.fontSize) }
        if let raw = d.string(forKey: Keys.fontWeight), let weight = NamedFontWeight(rawValue: raw) {
            fontWeight = weight
        }
        if d.object(forKey: Keys.lineSpacing) != nil { lineSpacing = d.double(forKey: Keys.lineSpacing) }
        if d.object(forKey: Keys.letterSpacing) != nil { letterSpacing = d.double(forKey: Keys.letterSpacing) }
        if let color = Self.loadColor(forKey: Keys.textColor) { textColor = color }
        if let alignment = d.string(forKey: Keys.textAlignment) {
            switch alignment {
            case "leading":  textAlignment = .leading
            case "trailing": textAlignment = .trailing
            default:         textAlignment = .center
            }
        }
        if d.object(forKey: Keys.mirrorText) != nil { mirrorText = d.bool(forKey: Keys.mirrorText) }
        if let color = Self.loadColor(forKey: Keys.backgroundColor) { backgroundColor = color }
        if d.object(forKey: Keys.backgroundOpacity) != nil { backgroundOpacity = d.double(forKey: Keys.backgroundOpacity) }
        if d.object(forKey: Keys.cornerRadius) != nil { cornerRadius = d.double(forKey: Keys.cornerRadius) }
        if d.object(forKey: Keys.fadeAmount) != nil { fadeAmount = d.double(forKey: Keys.fadeAmount) }
        if d.object(forKey: Keys.windowHeight) != nil { windowHeight = d.double(forKey: Keys.windowHeight) }
        if d.object(forKey: Keys.windowWidthFraction) != nil {
            windowWidthFraction = d.double(forKey: Keys.windowWidthFraction)
        }
        if d.object(forKey: Keys.toolbarVertical) != nil {
            toolbarVertical = d.bool(forKey: Keys.toolbarVertical)
        }
        if let paths = d.array(forKey: Keys.recentFiles) as? [String] {
            recentFiles = paths.map { URL(fileURLWithPath: $0) }
        }
    }

    /// Debounce writes to UserDefaults so slider drags don't hammer the disk.
    private func installPersistence() {
        objectWillChange
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &persistCancellables)
    }

    private func saveSettings() {
        let d = UserDefaults.standard
        d.set(speed, forKey: Keys.speed)
        d.set(fontName, forKey: Keys.fontName)
        d.set(fontSize, forKey: Keys.fontSize)
        d.set(fontWeight.rawValue, forKey: Keys.fontWeight)
        d.set(lineSpacing, forKey: Keys.lineSpacing)
        d.set(letterSpacing, forKey: Keys.letterSpacing)
        Self.saveColor(textColor, forKey: Keys.textColor)
        switch textAlignment {
        case .leading:  d.set("leading",  forKey: Keys.textAlignment)
        case .center:   d.set("center",   forKey: Keys.textAlignment)
        case .trailing: d.set("trailing", forKey: Keys.textAlignment)
        }
        d.set(mirrorText, forKey: Keys.mirrorText)
        Self.saveColor(backgroundColor, forKey: Keys.backgroundColor)
        d.set(backgroundOpacity, forKey: Keys.backgroundOpacity)
        d.set(cornerRadius, forKey: Keys.cornerRadius)
        d.set(fadeAmount, forKey: Keys.fadeAmount)
        d.set(windowHeight, forKey: Keys.windowHeight)
        d.set(windowWidthFraction, forKey: Keys.windowWidthFraction)
        d.set(toolbarVertical, forKey: Keys.toolbarVertical)
        d.set(recentFiles.map { $0.path }, forKey: Keys.recentFiles)
    }

    /// Encode a SwiftUI Color as an sRGB RGBA array so UserDefaults can hold it.
    private static func saveColor(_ color: Color, forKey key: String) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        let components: [Double] = [
            Double(ns.redComponent),
            Double(ns.greenComponent),
            Double(ns.blueComponent),
            Double(ns.alphaComponent)
        ]
        UserDefaults.standard.set(components, forKey: key)
    }

    private static func loadColor(forKey key: String) -> Color? {
        guard let array = UserDefaults.standard.array(forKey: key) as? [Double],
              array.count == 4 else { return nil }
        return Color(.sRGB, red: array[0], green: array[1], blue: array[2], opacity: array[3])
    }

    /// Forward scroll-wheel events over the teleprompter window so the user can
    /// nudge the script manually. Other windows (Appearance) still scroll normally.
    private func installScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self else { return event }
            guard let target = event.window,
                  target === NotchWindowBridge.shared.teleprompterWindow else {
                return event
            }
            self.manualScroll.send(event.scrollingDeltaY)
            return nil
        }
    }
}

/// A Codable-friendly stand-in for `Font.Weight` (which is not `Hashable` everywhere).
enum NamedFontWeight: String, CaseIterable, Identifiable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
    var id: String { rawValue }

    var swiftUIWeight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin:       return .thin
        case .light:      return .light
        case .regular:    return .regular
        case .medium:     return .medium
        case .semibold:   return .semibold
        case .bold:       return .bold
        case .heavy:      return .heavy
        case .black:      return .black
        }
    }

    var label: String {
        switch self {
        case .ultraLight: return "Ultralight"
        case .thin:       return "Thin"
        case .light:      return "Light"
        case .regular:    return "Regular"
        case .medium:     return "Medium"
        case .semibold:   return "Semibold"
        case .bold:       return "Bold"
        case .heavy:      return "Heavy"
        case .black:      return "Black"
        }
    }
}
