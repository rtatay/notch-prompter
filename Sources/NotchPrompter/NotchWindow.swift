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
        // Keep the NSWindow alive when SwiftUI thinks it's being closed — the
        // bridge converts close into orderOut so the user can always re-show it.
        window.isReleasedWhenClosed = false
        // Never merge into a tab group. We're a single-script teleprompter.
        window.tabbingMode = .disallowed

        // Make the traffic-light buttons subtle — they'll still show on hover.
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        positionUnderNotch(window: window, state: state)
        NotchWindowBridge.shared.bind(window: window, state: state)
    }

    /// Style the floating Toolbar window so it looks like a detached palette
    /// that belongs with the teleprompter — borderless, draggable, floats on
    /// top, transparent NSWindow background so the SwiftUI content's own
    /// rounded surface shows through.
    static func configureToolbar(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        // Always on top: above Find (floating+2), Settings/Shortcuts (floating+1),
        // and the main prompter (floating).
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 3)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        if window.frameAutosaveName.isEmpty {
            window.setFrameAutosaveName("NotchPrompter.Toolbar")
        }
        ToolbarWindowHolder.shared.window = window
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

/// Minimal holder so the Window menu / dock reopen path can show the toolbar
/// again without needing the SwiftUI `openWindow` environment.
final class ToolbarWindowHolder {
    static let shared = ToolbarWindowHolder()
    weak var window: NSWindow?

    func show() {
        guard let window = window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
    }

    /// Flip visibility — the ⌘2 shortcut and Window menu item both call this
    /// so the same action hides a visible toolbar and shows a hidden one.
    func toggle() {
        guard let window = window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
        }
    }
}

/// Listens to state changes that should move or resize the window, and acts as
/// its `NSWindowDelegate` so we can convert "close" into "hide".
final class NotchWindowBridge: NSObject, NSWindowDelegate {
    static let shared = NotchWindowBridge()
    private var cancellables = Set<AnyCancellable>()
    /// Strong reference — we own the teleprompter window for the lifetime of
    /// the app so it survives the red-light close button.
    private var boundWindow: NSWindow?
    private weak var swiftUIDelegate: NSWindowDelegate?

    /// The teleprompter's NSWindow, once configured. Used by event monitors to
    /// check whether an event originated inside the prompter.
    var teleprompterWindow: NSWindow? { boundWindow }

    func bind(window: NSWindow, state: PrompterState) {
        guard boundWindow !== window else { return }
        boundWindow = window
        cancellables.removeAll()

        // Take over the delegate so we can intercept close. Remember SwiftUI's
        // original delegate and forward any other message it cares about.
        swiftUIDelegate = window.delegate
        window.delegate = self

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

    /// Bring the main teleprompter window back on screen from anywhere in the
    /// app (dock-icon reopen, Window menu, etc.).
    func showMainWindow() {
        guard let window = boundWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide instead of closing so dock-icon reopen + "Show Prompter" menu
        // item can bring it back with all state intact.
        sender.orderOut(nil)
        return false
    }

    // Forward every other delegate message to whichever delegate SwiftUI had
    // originally installed — that way scene-phase and resize tracking keep
    // working even though we've taken over the delegate slot.
    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return swiftUIDelegate?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let forward = swiftUIDelegate, forward.responds(to: aSelector) {
            return forward
        }
        return nil
    }
}
