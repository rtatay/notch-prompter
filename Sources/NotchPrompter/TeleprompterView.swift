import SwiftUI
import Combine

/// The scrolling text surface. Uses a Timer publisher to advance the scroll
/// offset frame-by-frame while `isPlaying` is true. Two linear-gradient masks
/// fade the text into the background at the top and bottom.
struct TeleprompterView: View {
    @EnvironmentObject var state: PrompterState
    @State private var scroll: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var lastTick: Date = .now

    private let tick = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Translucent background with rounded corners.
                RoundedRectangle(cornerRadius: CGFloat(state.cornerRadius), style: .continuous)
                    .fill(state.backgroundColor.opacity(state.backgroundOpacity))

                // The scrolling markdown content.
                MarkdownContent(text: state.rawText)
                    .padding(.horizontal, 48)
                    .padding(.top, 60)
                    .padding(.bottom, geo.size.height * 0.85)
                    .frame(width: geo.size.width)
                    .background(
                        GeometryReader { inner in
                            Color.clear
                                .onAppear { contentHeight = inner.size.height }
                                .onChange(of: inner.size.height) { newValue in
                                    contentHeight = newValue
                                }
                        }
                    )
                    .offset(y: -scroll)
                    .scaleEffect(x: state.mirrorText ? -1 : 1, y: 1)

                // Top fade into background color.
                LinearGradient(
                    colors: [
                        state.backgroundColor.opacity(state.backgroundOpacity),
                        state.backgroundColor.opacity(0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: CGFloat(state.fadeAmount))
                .frame(maxWidth: .infinity, alignment: .top)
                .allowsHitTesting(false)

                // Bottom fade into background color.
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            state.backgroundColor.opacity(0),
                            state.backgroundColor.opacity(state.backgroundOpacity)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: CGFloat(state.fadeAmount))
                }
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: CGFloat(state.cornerRadius), style: .continuous))
            .onReceive(tick) { date in
                let dt = date.timeIntervalSince(lastTick)
                lastTick = date
                guard state.isPlaying else { return }
                let step = CGFloat(dt * state.speed)
                let maxScroll = max(0, contentHeight - 60) // stop a touch before the bottom
                let next = scroll + step
                if next >= maxScroll {
                    scroll = maxScroll
                    state.isPlaying = false
                } else {
                    scroll = next
                }
            }
            .onChange(of: state.restartToken) { _ in
                scroll = 0
                lastTick = .now
            }
            .onChange(of: state.isPlaying) { playing in
                if playing { lastTick = .now }
            }
            .onReceive(state.manualScroll) { delta in
                // AppKit reports positive deltaY when the surface moves down
                // (finger up / wheel up). In a teleprompter, "scroll up"
                // should advance forward through the script, i.e. increase
                // the offset — so we subtract.
                let maxScroll = max(0, contentHeight - 60)
                let next = scroll - delta
                scroll = min(max(0, next), maxScroll)
                lastTick = .now
            }
            .onReceive(state.scrollTo) { target in
                // Jump the teleprompter to an absolute y — used by Find so the
                // current match sits in the viewport's vertical center. Pause
                // playback so auto-scroll doesn't immediately steal focus.
                state.isPlaying = false
                let maxScroll = max(0, contentHeight - 60)
                scroll = min(max(0, target), maxScroll)
                lastTick = .now
            }
        }
    }
}
