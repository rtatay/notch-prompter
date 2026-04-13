import SwiftUI
import AppKit
import Combine

/// Embeds an invisible NSView into the SwiftUI hierarchy so we can reach up to
/// the hosting `NSWindow` and customise it.
struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

/// Configures the teleprompter's NSWindow: borderless-ish, floating on top,
/// and positioned just below the menu bar / notch.
enum NotchWindow {
    static func configure(_ window: NSWindow, state: PrompterState) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true

        // Make the traffic-light buttons subtle — they'll still show on hover.
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        positionUnderNotch(window: window, state: state)
        NotchWindowBridge.shared.bind(window: window, state: state)
    }

    /// Snaps the window to the width set by `state.windowWidthFraction`, the
    /// height from `state.windowHeight`, and the top of the usable screen area
    /// (which is already below the menu bar / notch on MacBooks).
    static func positionUnderNotch(window: NSWindow, state: PrompterState) {
        guard let screen = NSScreen.main else { return }
        let full = screen.frame
        let visible = screen.visibleFrame

        let width = full.width * CGFloat(state.windowWidthFraction)
        let height = CGFloat(state.windowHeight)

        let x = full.midX - width / 2
        let topY = visible.origin.y + visible.height
        let y = topY - height

        window.setFrame(
            NSRect(x: x, y: y, width: width, height: height),
            display: true,
            animate: false
        )
    }
}

/// Listens to state changes that should move or resize the window.
final class NotchWindowBridge {
    static let shared = NotchWindowBridge()
    private var cancellables = Set<AnyCancellable>()
    private weak var boundWindow: NSWindow?

    func bind(window: NSWindow, state: PrompterState) {
        guard boundWindow !== window else { return }
        boundWindow = window
        cancellables.removeAll()

        let reposition: () -> Void = { [weak window, weak state] in
            guard let window = window, let state = state else { return }
            NotchWindow.positionUnderNotch(window: window, state: state)
        }

        state.$windowHeight
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { _ in reposition() }
            .store(in: &cancellables)

        state.$windowWidthFraction
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { _ in reposition() }
            .store(in: &cancellables)

        state.$repositionRequested
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { _ in reposition() }
            .store(in: &cancellables)
    }
}
