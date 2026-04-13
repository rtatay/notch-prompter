import SwiftUI
import AppKit

@main
struct NotchPrompterApp: App {
    @StateObject private var state = PrompterState()

    var body: some Scene {
        WindowGroup("NotchPrompter", id: "main") {
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
            CommandGroup(replacing: .newItem) {
                Button("Open Script…") { state.openFile() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Reload Script") { state.reloadCurrent() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .disabled(state.currentFileURL == nil)
            }
            CommandMenu("Prompter") {
                Button(state.isPlaying ? "Pause" : "Play") { state.togglePlay() }
                    .keyboardShortcut(.return, modifiers: .command)
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
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 640)
    }
}
