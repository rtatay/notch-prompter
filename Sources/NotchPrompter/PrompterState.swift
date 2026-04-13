import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

/// All mutable state for the teleprompter. Observed by every view.
final class PrompterState: ObservableObject {
    // MARK: - Content
    @Published var rawText: String = DefaultScript.text
    @Published var currentFileURL: URL?

    // MARK: - Playback
    @Published var isPlaying: Bool = false
    /// Tokens that views observe to trigger one-shot events.
    @Published var restartToken: UUID = UUID()
    /// Points per second the text scrolls upward.
    @Published var speed: Double = 60

    // MARK: - Typography
    @Published var fontName: String = "Helvetica Neue"
    @Published var fontSize: Double = 48
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
    @Published var windowWidthFraction: Double = 0.65
    /// Bump this UUID to ask the window controller to snap back under the notch.
    @Published var repositionRequested: UUID = UUID()

    private var keyMonitor: Any?

    init() {
        installKeyMonitor()
    }

    deinit {
        if let monitor = keyMonitor {
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

    // MARK: - File I/O

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        var types: [UTType] = [.plainText, .text, .utf8PlainText, .rtf]
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        if let markdown = UTType("net.daringfireball.markdown") { types.append(markdown) }
        panel.allowedContentTypes = types
        panel.title = "Choose a Script"
        panel.prompt = "Load"
        if panel.runModal() == .OK, let url = panel.url {
            loadFile(url)
        }
    }

    func loadFile(_ url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            rawText = text
            currentFileURL = url
            restart()
        } catch {
            NSSound.beep()
        }
    }

    func reloadCurrent() {
        guard let url = currentFileURL else { return }
        loadFile(url)
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
