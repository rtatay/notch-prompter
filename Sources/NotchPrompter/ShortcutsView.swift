import SwiftUI

/// Compact, non-modal keyboard-shortcut cheat sheet shown in its own window.
struct ShortcutsView: View {
    private struct Entry: Identifiable {
        let keys: String
        let desc: String
        var id: String { keys }
    }

    private static let entries: [Entry] = [
        .init(keys: "Space",       desc: "Play / Pause"),
        .init(keys: "⌘ ⏎",        desc: "Play / Pause (menu)"),
        .init(keys: "⌘ R",        desc: "Restart"),
        .init(keys: "⌘ O",        desc: "Open Script"),
        .init(keys: "⌘ ⇧ O",     desc: "Reload Script"),
        .init(keys: "⌘ F",        desc: "Find…"),
        .init(keys: "⏎ / ⇧⏎",    desc: "Find Next / Previous"),
        .init(keys: "⌘ ↑  ⌘ ↓",  desc: "Faster / Slower"),
        .init(keys: "⌘ ]  ⌘ [",  desc: "Taller / Shorter"),
        .init(keys: "⌘ ⇧ =  ⌘ ⇧ -", desc: "Bigger / Smaller Text"),
        .init(keys: "⌘ ⇧ N",      desc: "Snap Under Notch"),
        .init(keys: "⌘ M",        desc: "Toggle Mirror"),
        .init(keys: "⌘ 1",        desc: "Show Prompter"),
        .init(keys: "⌘ 2",        desc: "Toggle Toolbar"),
        .init(keys: "Scroll",      desc: "Manually nudge script"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Keyboard Shortcuts")
                    .font(.system(size: 16, weight: .semibold))
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.entries) { entry in
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.keys)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 150, alignment: .leading)
                        Text(entry.desc)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(22)
        .frame(minWidth: 380, idealWidth: 400)
    }
}
