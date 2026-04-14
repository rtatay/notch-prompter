import SwiftUI
import AppKit

/// A paired text/background swatch applied via the Color Themes row at the
/// top of the Appearance panel.
struct ColorTheme: Identifiable {
    let id = UUID()
    let name: String
    let textColor: Color
    let backgroundColor: Color
}

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

    private let themes: [ColorTheme] = [
        .init(name: "Classic",
              textColor: .white,
              backgroundColor: .black),
        .init(name: "Inverted",
              textColor: .black,
              backgroundColor: .white),
        .init(name: "Amber",
              textColor: Color(red: 1.00, green: 0.74, blue: 0.26),
              backgroundColor: Color(red: 0.07, green: 0.05, blue: 0.02)),
        .init(name: "Terminal",
              textColor: Color(red: 0.36, green: 1.00, blue: 0.45),
              backgroundColor: .black),
        .init(name: "Paper",
              textColor: Color(red: 0.22, green: 0.18, blue: 0.12),
              backgroundColor: Color(red: 0.97, green: 0.94, blue: 0.87)),
        .init(name: "Blueprint",
              textColor: .white,
              backgroundColor: Color(red: 0.05, green: 0.22, blue: 0.50)),
        .init(name: "Solarized",
              textColor: Color(red: 0.93, green: 0.91, blue: 0.84),
              backgroundColor: Color(red: 0.00, green: 0.17, blue: 0.21)),
        .init(name: "Ocean",
              textColor: Color(red: 0.74, green: 0.94, blue: 0.98),
              backgroundColor: Color(red: 0.03, green: 0.09, blue: 0.20)),
        .init(name: "Rose",
              textColor: Color(red: 1.00, green: 0.85, blue: 0.87),
              backgroundColor: Color(red: 0.22, green: 0.04, blue: 0.12))
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("Color Theme")
                themeRow

                Divider().padding(.vertical, 4)

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
                    ColorDropdown(color: $state.textColor)
                }

                labelled("Mirror") {
                    Toggle("", isOn: $state.mirrorText)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Divider().padding(.vertical, 4)

                section("Background")

                labelled("Color") {
                    ColorDropdown(color: $state.backgroundColor)
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
                    Label("Revert to Defaults", systemImage: "arrow.uturn.backward")
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

    private var themeRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(themes) { theme in
                    themeSwatch(theme)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 1)
        }
    }

    private func themeSwatch(_ theme: ColorTheme) -> some View {
        let selected = isActiveTheme(theme)
        return Button {
            applyTheme(theme)
        } label: {
            VStack(spacing: 6) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(theme.textColor)
                        .frame(height: 16)
                    Rectangle()
                        .fill(theme.backgroundColor)
                        .frame(height: 16)
                }
                .frame(width: 58, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            selected ? Color.accentColor : Color.secondary.opacity(0.35),
                            lineWidth: selected ? 2 : 0.75
                        )
                )
                Text(theme.name)
                    .font(.caption2)
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Apply \(theme.name)")
    }

    private func isActiveTheme(_ theme: ColorTheme) -> Bool {
        sameColor(state.textColor, theme.textColor)
            && sameColor(state.backgroundColor, theme.backgroundColor)
    }

    private func applyTheme(_ theme: ColorTheme) {
        state.textColor = theme.textColor
        state.backgroundColor = theme.backgroundColor
    }

    /// Compare two SwiftUI colors for near-equality by round-tripping through
    /// NSColor sRGB components. Used to highlight the currently-active theme.
    private func sameColor(_ lhs: Color, _ rhs: Color) -> Bool {
        let a = NSColor(lhs).usingColorSpace(.sRGB) ?? NSColor.white
        let b = NSColor(rhs).usingColorSpace(.sRGB) ?? NSColor.white
        let epsilon: CGFloat = 0.02
        return abs(a.redComponent - b.redComponent) < epsilon
            && abs(a.greenComponent - b.greenComponent) < epsilon
            && abs(a.blueComponent - b.blueComponent) < epsilon
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

/// Compact in-panel color picker. Clicking the swatch opens a popover with a
/// preset palette plus a native ColorPicker escape-hatch for custom colors —
/// no separate NSColorPanel window is required for common choices.
struct ColorDropdown: View {
    @Binding var color: Color
    @State private var popoverVisible = false

    private let palette: [Color] = [
        .white,
        Color(white: 0.85),
        Color(white: 0.6),
        Color(white: 0.35),
        .black,
        Color(red: 1.00, green: 0.23, blue: 0.19),
        Color(red: 1.00, green: 0.58, blue: 0.00),
        Color(red: 1.00, green: 0.80, blue: 0.00),
        Color(red: 0.20, green: 0.78, blue: 0.35),
        Color(red: 0.00, green: 0.78, blue: 0.75),
        Color(red: 0.00, green: 0.48, blue: 1.00),
        Color(red: 0.35, green: 0.34, blue: 0.84),
        Color(red: 0.69, green: 0.32, blue: 0.87),
        Color(red: 1.00, green: 0.18, blue: 0.50),
        Color(red: 0.64, green: 0.52, blue: 0.37)
    ]

    var body: some View {
        Button {
            popoverVisible.toggle()
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color)
                    .frame(width: 28, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.secondary.opacity(0.45), lineWidth: 0.75)
                    )
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $popoverVisible, arrowEdge: .bottom) {
            paletteGrid
        }
    }

    private var paletteGrid: some View {
        let columns = Array(
            repeating: GridItem(.fixed(28), spacing: 6),
            count: 5
        )
        return VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(palette.enumerated()), id: \.offset) { _, swatch in
                    swatchButton(swatch)
                }
            }
            Divider()
            ColorPicker("Custom…", selection: $color, supportsOpacity: false)
                .font(.caption)
        }
        .padding(12)
        .frame(width: 210)
    }

    private func swatchButton(_ swatch: Color) -> some View {
        let selected = isApproximatelyEqual(color, swatch)
        return Button {
            color = swatch
            popoverVisible = false
        } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(swatch)
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(
                            selected ? Color.accentColor : Color.secondary.opacity(0.35),
                            lineWidth: selected ? 2 : 0.75
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func isApproximatelyEqual(_ lhs: Color, _ rhs: Color) -> Bool {
        let a = NSColor(lhs).usingColorSpace(.sRGB) ?? NSColor.white
        let b = NSColor(rhs).usingColorSpace(.sRGB) ?? NSColor.white
        let epsilon: CGFloat = 0.02
        return abs(a.redComponent - b.redComponent) < epsilon
            && abs(a.greenComponent - b.greenComponent) < epsilon
            && abs(a.blueComponent - b.blueComponent) < epsilon
    }
}
