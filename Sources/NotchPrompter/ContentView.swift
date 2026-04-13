import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: PrompterState
    @Environment(\.openWindow) private var openWindow
    @State private var hovering = false
    @State private var didBootstrapToolbar = false

    var body: some View {
        TeleprompterView()
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
            .onAppear {
                // Open the floating toolbar once on first launch. `openWindow`
                // from inside `onAppear` needs to be deferred a tick so SwiftUI
                // has finished composing the main scene.
                guard !didBootstrapToolbar else { return }
                didBootstrapToolbar = true
                DispatchQueue.main.async {
                    openWindow(id: "toolbar")
                }
            }
    }
}
