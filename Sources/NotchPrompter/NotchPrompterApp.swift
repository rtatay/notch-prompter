import SwiftUI
import AppKit

/// Handles dock-icon reopen so a closed (hidden) main window can come back,
/// and forces foreground activation when the app is launched from a terminal
/// (`swift run`). Without this the Terminal keeps keyboard focus and Space
/// doesn't reach the prompter.
final class NotchAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Never show the system tab bar — we're a single-script teleprompter.
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotchWindowBridge.shared.showMainWindow()
        }
        return true
    }
}

@main
struct NotchPrompterApp: App {
    @NSApplicationDelegateAdaptor(NotchAppDelegate.self) private var appDelegate
    @StateObject private var state = PrompterState()
    // Finder lives at the app level so its query/cursor survive closing and
    // reopening the Find window.
    @StateObject private var finder = Finder()

    var body: some Scene {
        Window("NotchPrompter", id: "main") {
            ContentView()
                .environmentObject(state)
                .background(WindowAccessor { window in
                    NotchWindow.configure(window, state: state)
                })
                .ignoresSafeArea()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 280)
        .commands {
            // Wipe the default Window menu — no Minimize/Zoom/Fill/Bring All
            // To Front/window list. We re-add only the items we want below
            // (inside the windowArrangement replacement).
            CommandGroup(replacing: .windowList) { }
            CommandGroup(replacing: .windowSize) { }
            CommandGroup(replacing: .singleWindowList) { }
            CommandGroup(replacing: .windowArrangement) {
                Button("Show Prompter") {
                    NotchWindowBridge.shared.showMainWindow()
                }
                .keyboardShortcut("1", modifiers: .command)
                Button("Toggle Toolbar") {
                    ToolbarWindowHolder.shared.toggle()
                }
                .keyboardShortcut("2", modifiers: .command)
                ShortcutsMenuButton()
            }
            CommandGroup(replacing: .newItem) {
                Button("Open Script…") { state.openFile() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Reload Script") { state.reloadCurrent() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .disabled(state.currentFileURL == nil)
                RecentScriptsMenu(state: state)
            }
            CommandGroup(after: .textEditing) {
                FindMenuButton()
            }
            CommandMenu("Prompter") {
                Button(state.isPlaying ? "Pause" : "Play") { state.togglePlay() }
                    .keyboardShortcut(.return, modifiers: .command)
                // A second button so spacebar (no modifier) is owned by SwiftUI's
                // menu system in addition to the NSEvent monitor.
                Button("Play / Pause (Space)") { state.togglePlay() }
                    .keyboardShortcut(KeyEquivalent(" "), modifiers: [])
                Button("Restart") { state.restart() }
                    .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Faster") { state.adjustSpeed(10) }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                Button("Slower") { state.adjustSpeed(-10) }
                    .keyboardShortcut(.downArrow, modifiers: .command)
                Divider()
                Button("Taller") { state.adjustHeight(40) }
                    .keyboardShortcut("]", modifiers: .command)
                Button("Shorter") { state.adjustHeight(-40) }
                    .keyboardShortcut("[", modifiers: .command)
                Divider()
                Button("Bigger Text") { state.adjustFontSize(2) }
                    .keyboardShortcut("=", modifiers: [.command, .shift])
                Button("Smaller Text") { state.adjustFontSize(-2) }
                    .keyboardShortcut("-", modifiers: [.command, .shift])
                Divider()
                Button("Reposition Under Notch") { state.repositionRequested = UUID() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button(state.mirrorText ? "Unmirror Text" : "Mirror Text") {
                    state.mirrorText.toggle()
                }
                .keyboardShortcut("m", modifiers: .command)
            }
        }

        Window("Appearance", id: "settings") {
            SettingsPanel()
                .environmentObject(state)
                .background(WindowAccessor { window in
                    // Match the main window's level so the panel isn't buried.
                    window.level = NSWindow.Level(
                        rawValue: NSWindow.Level.floating.rawValue + 1
                    )
                    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                    window.makeKeyAndOrderFront(nil)
                })
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" || $0.title == "Appearance" }) {
                        window.orderFrontRegardless()
                        window.makeKey()
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 640)

        Window("Toolbar", id: "toolbar") {
            ToolbarWindowContent(state: state)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topLeading)

        Window("Shortcuts", id: "shortcuts") {
            ShortcutsView()
                .background(WindowAccessor { window in
                    // Non-modal utility window — let the user close and reopen
                    // it freely, but keep it above the floating prompter.
                    window.level = NSWindow.Level(
                        rawValue: NSWindow.Level.floating.rawValue + 1
                    )
                    window.isReleasedWhenClosed = false
                })
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 420)

        Window("Find", id: "find") {
            FindView(finder: finder)
                .environmentObject(state)
                .background(WindowAccessor { window in
                    FindWindow.configure(window)
                })
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 120)

        MenuBarExtra("NotchPrompter", systemImage: "text.bubble") {
            MenuBarControls(state: state)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Wraps `ControlsOverlay` with the environment plumbing the Toolbar scene
/// needs (`openWindow` for Settings/Shortcuts + WindowAccessor for styling).
private struct ToolbarWindowContent: View {
    @ObservedObject var state: PrompterState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ControlsOverlay(
            onOpenSettings: {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            },
            onOpenShortcuts: {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "shortcuts")
            }
        )
        .environmentObject(state)
        .padding(6)
        .background(WindowAccessor { window in
            NotchWindow.configureToolbar(window)
        })
        .fixedSize()
    }
}

/// A helper view that lets the "Shortcuts…" Window menu item use SwiftUI's
/// `openWindow` environment (which isn't available inside `.commands` directly).
private struct ShortcutsMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Shortcuts…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "shortcuts")
        }
        .keyboardShortcut("?", modifiers: [.command])
    }
}

/// Edit → Find… (⌘F). Uses its own openWindow environment so the floating
/// Find palette can be opened from a command.
private struct FindMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Find…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "find")
        }
        .keyboardShortcut("f", modifiers: .command)
    }
}

/// File → Open Recent submenu. Observes the state so it updates as new files
/// are loaded, and uses `state.loadFile` so the same markdown-only guard runs.
private struct RecentScriptsMenu: View {
    @ObservedObject var state: PrompterState

    var body: some View {
        Menu("Open Recent") {
            if state.recentFiles.isEmpty {
                Text("No Recent Scripts")
            } else {
                ForEach(state.recentFiles, id: \.self) { url in
                    Button(url.lastPathComponent) { state.loadFile(url) }
                }
                Divider()
                Button("Clear Menu") { state.clearRecent() }
            }
        }
    }
}

/// Menu-bar dropdown. Uses its own `@Environment(\.openWindow)` so it can
/// summon the Appearance panel from anywhere.
private struct MenuBarControls: View {
    @ObservedObject var state: PrompterState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(state.isPlaying ? "Pause" : "Play") { state.togglePlay() }
        Button("Restart") { state.restart() }
        Divider()
        Button("Show Prompter") {
            NotchWindowBridge.shared.showMainWindow()
        }
        Button("Toggle Toolbar") {
            ToolbarWindowHolder.shared.toggle()
        }
        Button("Snap Under Notch") {
            NotchWindowBridge.shared.showMainWindow()
            state.repositionRequested = UUID()
        }
        Divider()
        Button("Open Script…") { state.openFile() }
        Button("Appearance…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
        Button("Shortcuts…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "shortcuts")
        }
        Divider()
        Button("Quit NotchPrompter") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
