import SwiftUI

/// A compact HUD that floats above the teleprompter when the user mouses over.
struct ControlsOverlay: View {
    @EnvironmentObject var state: PrompterState
    var onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Play / Pause
            Button {
                state.togglePlay()
            } label: {
                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Play / Pause (Space)")

            Button {
                state.restart()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Restart (⌘R)")

            divider

            stepperGroup(
                icon: "speedometer",
                value: $state.speed,
                range: 5...500,
                step: 5,
                width: 34,
                help: "Scroll speed (pt/s)"
            )

            stepperGroup(
                icon: "textformat.size",
                value: $state.fontSize,
                range: 10...180,
                step: 2,
                width: 30,
                help: "Font size"
            )

            stepperGroup(
                icon: "arrow.up.and.down.square",
                value: $state.windowHeight,
                range: 120...1400,
                step: 20,
                width: 36,
                help: "Window height"
            )

            divider

            Button {
                state.openFile()
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Open script… (⌘O)")

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Appearance")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(.black.opacity(0.72))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.18))
            .frame(width: 1, height: 18)
    }

    @ViewBuilder
    private func stepperGroup(
        icon: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        width: CGFloat,
        help: String
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .opacity(0.85)
            Text("\(Int(value.wrappedValue))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .frame(width: width, alignment: .trailing)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .controlSize(.mini)
        }
        .help(help)
    }
}
