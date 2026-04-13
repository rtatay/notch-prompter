import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: PrompterState
    @Environment(\.openWindow) private var openWindow
    @State private var hovering = false

    var body: some View {
        TeleprompterView()
            .overlay(alignment: .bottom) {
                ControlsOverlay {
                    openWindow(id: "settings")
                }
                .padding(.bottom, 14)
                .opacity(hovering ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: hovering)
            }
            .overlay(alignment: .topLeading) {
                if let name = state.currentFileURL?.lastPathComponent {
                    Text(name)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.35), in: Capsule())
                        .padding(10)
                        .opacity(hovering ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: hovering)
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active: hovering = true
                case .ended:  hovering = false
                }
            }
    }
}
