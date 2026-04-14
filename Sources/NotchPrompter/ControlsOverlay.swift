import SwiftUI

/// Floating control strip. Lives in its own window and can be laid out
/// horizontally or vertically. Icon / font sizes are roughly 30% larger than
/// the original HUD so it reads well as a standalone palette.
struct ControlsOverlay: View {
    @EnvironmentObject var state: PrompterState
    var onOpenSettings: () -> Void
    var onOpenShortcuts: () -> Void

    // Scaled from the original HUD (~1.3x) so this works as a dockable palette.
    private let iconFont = Font.system(size: 17, weight: .semibold)
    private let smallIconFont = Font.system(size: 15, weight: .semibold)
    private let buttonSide: CGFloat = 29
    private let readoutFont = Font.system(size: 14, weight: .medium, design: .monospaced)
    private let labelFont = Font.system(size: 14, weight: .semibold)
    private let groupSpacing: CGFloat = 21
    private let horizontalPadding: CGFloat = 20
    private let verticalPadding: CGFloat = 12

    var body: some View {
        Group {
            if state.toolbarVertical {
                // Two columns of stacked buttons separated by a vertical line.
                HStack(alignment: .top, spacing: groupSpacing) {
                    VStack(alignment: .leading, spacing: groupSpacing) {
                        playbackButtons
                    }
                    Rectangle()
                        .fill(.white.opacity(0.22))
                        .frame(width: 1)
                    VStack(alignment: .leading, spacing: groupSpacing) {
                        actionButtons
                    }
                }
            } else {
                // Two rows of buttons separated by a horizontal line.
                VStack(alignment: .leading, spacing: groupSpacing) {
                    HStack(spacing: groupSpacing) {
                        playbackButtons
                    }
                    Rectangle()
                        .fill(.white.opacity(0.22))
                        .frame(height: 1)
                    HStack(spacing: groupSpacing) {
                        actionButtons
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            // Mirror the main prompter's background & opacity so the toolbar
            // visually belongs to the same surface.
            RoundedRectangle(cornerRadius: CGFloat(state.cornerRadius), style: .continuous)
                .fill(state.backgroundColor.opacity(state.backgroundOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: CGFloat(state.cornerRadius), style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
        )
    }

    // MARK: - Groupings

    @ViewBuilder
    private var playbackButtons: some View {
        playPauseButton
        restartButton
        stepperGroup(
            icon: "speedometer",
            value: $state.speed,
            range: 5...500,
            step: 5,
            width: 44,
            help: "Scroll speed (pt/s)"
        )
        stepperGroup(
            icon: "textformat.size",
            value: $state.fontSize,
            range: 10...180,
            step: 2,
            width: 39,
            help: "Font size"
        )
        stepperGroup(
            icon: "arrow.up.and.down.square",
            value: $state.windowHeight,
            range: 120...1400,
            step: 20,
            width: 47,
            help: "Window height"
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        snapButton
        openButton
        settingsButton
        shortcutsButton
        orientationButton
    }

    // MARK: - Buttons

    private var playPauseButton: some View {
        Button {
            state.togglePlay()
        } label: {
            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                .font(iconFont)
                .frame(width: buttonSide, height: buttonSide)
        }
        .buttonStyle(.plain)
        .help("Play / Pause (Space)")
    }

    private var restartButton: some View {
        Button {
            state.restart()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(smallIconFont)
                .frame(width: buttonSide, height: buttonSide)
        }
        .buttonStyle(.plain)
        .help("Restart (⌘R)")
    }

    private var snapButton: some View {
        Button {
            state.repositionRequested = UUID()
        } label: {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(smallIconFont)
                .frame(width: buttonSide, height: buttonSide)
        }
        .buttonStyle(.plain)
        .help("Snap under the notch (⌘⇧N)")
    }

    private var openButton: some View {
        Button {
            state.openFile()
        } label: {
            Image(systemName: "folder")
                .font(smallIconFont)
                .frame(width: buttonSide, height: buttonSide)
        }
        .buttonStyle(.plain)
        .help("Open script… (⌘O)")
    }

    private var settingsButton: some View {
        Button {
            onOpenSettings()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(smallIconFont)
                .frame(width: buttonSide, height: buttonSide)
        }
        .buttonStyle(.plain)
        .help("Appearance")
    }

    private var shortcutsButton: some View {
        Button {
            onOpenShortcuts()
        } label: {
            Image(systemName: "keyboard")
                .font(smallIconFont)
                .frame(width: buttonSide, height: buttonSide)
        }
        .buttonStyle(.plain)
        .help("Keyboard shortcuts")
    }

    private var orientationButton: some View {
        Button {
            state.toolbarVertical.toggle()
        } label: {
            Image(systemName: state.toolbarVertical
                  ? "rectangle.split.3x1"
                  : "rectangle.split.1x2")
                .font(smallIconFont)
                .frame(width: buttonSide, height: buttonSide)
        }
        .buttonStyle(.plain)
        .help(state.toolbarVertical ? "Switch to horizontal" : "Switch to vertical")
    }

    // MARK: - Layout helpers

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
                .font(smallIconFont)
                .opacity(0.85)
            Text("\(Int(value.wrappedValue))")
                .font(readoutFont)
                .frame(width: width, alignment: .trailing)
            // Custom stacked chevrons — native Stepper disappears on our
            // transparent palette background, so we draw our own.
            VStack(spacing: 1) {
                Button {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 2)
        }
        .help(help)
    }
}
