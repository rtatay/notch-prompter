import SwiftUI

/// Preferences window — typography, background, fade and window sizing.
struct SettingsPanel: View {
    @EnvironmentObject var state: PrompterState

    private let commonFonts: [String] = [
        "Helvetica Neue",
        "Avenir Next",
        "Avenir",
        "Georgia",
        "Times New Roman",
        "Palatino",
        "Baskerville",
        "Optima",
        "Futura",
        "Menlo",
        "Courier New"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("Typography")

                labelled("Font") {
                    Picker("", selection: $state.fontName) {
                        ForEach(commonFonts, id: \.self) { name in
                            Text(name)
                                .font(.custom(name, size: 13))
                                .tag(name)
                        }
                    }
                    .labelsHidden()
                }

                labelled("Weight") {
                    Picker("", selection: $state.fontWeight) {
                        ForEach(NamedFontWeight.allCases) { weight in
                            Text(weight.label).tag(weight)
                        }
                    }
                    .labelsHidden()
                }

                slider("Size", value: $state.fontSize, range: 10...180, decimals: 0, unit: " pt")
                slider("Line Spacing", value: $state.lineSpacing, range: 0...40)
                slider("Letter Spacing", value: $state.letterSpacing, range: -2...10, decimals: 1)

                labelled("Alignment") {
                    Picker("", selection: $state.textAlignment) {
                        Image(systemName: "text.alignleft").tag(TextAlignment.leading)
                        Image(systemName: "text.aligncenter").tag(TextAlignment.center)
                        Image(systemName: "text.alignright").tag(TextAlignment.trailing)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                labelled("Text Color") {
                    ColorPicker("", selection: $state.textColor, supportsOpacity: false)
                        .labelsHidden()
                }

                labelled("Mirror") {
                    Toggle("", isOn: $state.mirrorText)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Divider().padding(.vertical, 4)

                section("Background")

                labelled("Color") {
                    ColorPicker("", selection: $state.backgroundColor, supportsOpacity: false)
                        .labelsHidden()
                }

                slider("Opacity", value: $state.backgroundOpacity, range: 0...1, step: 0.05, decimals: 0, multiplier: 100, unit: "%")
                slider("Corner Radius", value: $state.cornerRadius, range: 0...40)
                slider("Fade Height", value: $state.fadeAmount, range: 0...240, unit: " px")

                Divider().padding(.vertical, 4)

                section("Window")

                slider("Height", value: $state.windowHeight, range: 120...1400, step: 10, unit: " px")
                slider("Width", value: $state.windowWidthFraction, range: 0.25...1.0, step: 0.05, decimals: 0, multiplier: 100, unit: "%")

                Button {
                    state.repositionRequested = UUID()
                } label: {
                    Label("Snap Under Notch", systemImage: "dot.radiowaves.up.forward")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Divider().padding(.vertical, 4)

                section("Toolbar")

                labelled("Orientation") {
                    Picker("", selection: $state.toolbarVertical) {
                        Text("Horizontal").tag(false)
                        Text("Vertical").tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                Divider().padding(.vertical, 4)

                section("Playback")

                slider("Speed", value: $state.speed, range: 5...500, step: 5, unit: " pt/s")

                Divider().padding(.vertical, 4)

                Button(role: .destructive) {
                    state.resetToDefaults()
                } label: {
                    Label("Revert to Default", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                shortcutsFooter

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(minWidth: 460, idealWidth: 480, minHeight: 520, idealHeight: 640)
    }

    @ViewBuilder
    private func section(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func labelled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 110, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }

    private func slider(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        decimals: Int = 0,
        multiplier: Double = 1,
        unit: String = ""
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 110, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(String(format: "%.\(decimals)f%@", value.wrappedValue * multiplier, unit))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
    }

    private var shortcutsFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shortcuts")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.secondary)
            shortcutRow("Space", "Play / Pause")
            shortcutRow("⌘⏎", "Play / Pause (menu)")
            shortcutRow("⌘R", "Restart")
            shortcutRow("⌘O", "Open Script")
            shortcutRow("⌘↑ / ⌘↓", "Faster / Slower")
            shortcutRow("⌘] / ⌘[", "Taller / Shorter")
            shortcutRow("⌘⇧= / ⌘⇧-", "Bigger / Smaller Text")
            shortcutRow("⌘⇧N", "Snap Under Notch")
            shortcutRow("⌘M", "Toggle Mirror")
        }
        .padding(.top, 4)
    }

    private func shortcutRow(_ keys: String, _ desc: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
