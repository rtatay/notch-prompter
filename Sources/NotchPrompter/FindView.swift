import SwiftUI
import AppKit
import Combine

/// Search engine backing the floating Find window. Keeps a cache of match
/// ranges keyed by query + case-sensitivity + script text so hitting Enter
/// repeatedly just advances through the existing list.
final class Finder: ObservableObject {
    enum Direction { case next, previous }

    @Published var query: String = ""
    @Published var caseSensitive: Bool = false
    @Published var notFound: Bool = false
    @Published private(set) var totalMatches: Int = 0
    @Published private(set) var currentIndex: Int = 0

    private var cachedMatches: [NSRange] = []
    private var cachedQuery: String = ""
    private var cachedCase: Bool = false
    private var cachedText: String = ""

    /// Reset the cursor so the next `search` starts from the first occurrence.
    /// Called when the query field changes.
    func resetCursor() {
        notFound = false
        cachedMatches = []
        cachedQuery = ""
        cachedText = ""
        totalMatches = 0
        currentIndex = 0
    }

    func search(direction: Direction, in state: PrompterState) {
        guard !query.isEmpty else {
            notFound = false
            totalMatches = 0
            state.highlightQuery = ""
            return
        }

        if cachedQuery != query || cachedCase != caseSensitive || cachedText != state.rawText {
            rebuild(from: state.rawText)
        }

        // Paint every match like a selection. Kept in sync with the current
        // query/case on every search invocation.
        state.highlightQuery = query
        state.highlightCaseSensitive = caseSensitive

        totalMatches = cachedMatches.count

        guard !cachedMatches.isEmpty else {
            notFound = true
            currentIndex = 0
            return
        }
        notFound = false

        if currentIndex < 0 {
            currentIndex = (direction == .next) ? 0 : cachedMatches.count - 1
        } else {
            switch direction {
            case .next:
                currentIndex = (currentIndex + 1) % cachedMatches.count
            case .previous:
                currentIndex = (currentIndex - 1 + cachedMatches.count) % cachedMatches.count
            }
        }

        let match = cachedMatches[currentIndex]
        state.scrollTo.send(Self.centerScroll(for: match, state: state))
    }

    // MARK: - Internals

    private func rebuild(from text: String) {
        let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        var matches: [NSRange] = []
        let ns = text as NSString
        var searchRange = NSRange(location: 0, length: ns.length)
        while searchRange.length > 0 {
            let found = ns.range(of: query, options: options, range: searchRange)
            if found.location == NSNotFound { break }
            matches.append(found)
            let nextStart = found.location + max(1, found.length)
            if nextStart >= ns.length { break }
            searchRange = NSRange(location: nextStart, length: ns.length - nextStart)
        }
        cachedMatches = matches
        cachedQuery = query
        cachedCase = caseSensitive
        cachedText = text
        currentIndex = -1
    }

    /// Approximate y-offset in the teleprompter scroll coordinate space where
    /// the given character range sits, centered in the current viewport.
    /// Uses NSLayoutManager on an attributed string with the same font/line
    /// spacing the teleprompter currently shows. This doesn't perfectly match
    /// the markdown renderer's output but is close enough to land the match
    /// inside the visible region.
    static func centerScroll(for range: NSRange, state: PrompterState) -> CGFloat {
        let fontSize = CGFloat(state.fontSize)
        let font = NSFont(name: state.fontName, size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)
        let windowWidth = NotchWindowBridge.shared.teleprompterWindow?.frame.width ?? 900
        // Mirror TeleprompterView's horizontal padding (48pt on each side).
        let width = max(100, windowWidth - 96)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = CGFloat(state.lineSpacing)

        let attr = NSAttributedString(string: state.rawText, attributes: [
            .font: font,
            .paragraphStyle: paragraph
        ])

        let storage = NSTextStorage(attributedString: attr)
        let layout = NSLayoutManager()
        let container = NSTextContainer(
            size: NSSize(width: width, height: .greatestFiniteMagnitude)
        )
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = 0
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)

        let clamped = NSRange(
            location: min(range.location, storage.length),
            length: min(range.length, max(0, storage.length - range.location))
        )
        let glyphRange = layout.glyphRange(forCharacterRange: clamped, actualCharacterRange: nil)
        let rect = layout.boundingRect(forGlyphRange: glyphRange, in: container)

        // TeleprompterView uses a 60pt top padding before its content starts.
        let topPadding: CGFloat = 60
        let viewportHeight = CGFloat(state.windowHeight)
        let target = rect.midY + topPadding - viewportHeight / 2
        return max(0, target)
    }
}

/// Compact floating Find panel — textfield, case-match toggle, Previous/Next,
/// and a status line that shows "X of Y" or "No matches".
struct FindView: View {
    @EnvironmentObject var state: PrompterState
    @ObservedObject var finder: Finder
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Find in script", text: $finder.query)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit {
                        finder.search(direction: .next, in: state)
                    }
                Toggle(isOn: $finder.caseSensitive) {
                    Text("Aa")
                        .font(.system(size: 12, weight: .semibold))
                }
                .toggleStyle(.button)
                .help("Match case")
            }

            HStack(spacing: 8) {
                statusText
                Spacer(minLength: 8)
                Button("Previous") {
                    finder.search(direction: .previous, in: state)
                }
                .keyboardShortcut(.return, modifiers: .shift)
                .disabled(finder.query.isEmpty)

                Button("Next") {
                    finder.search(direction: .next, in: state)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(finder.query.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 380)
        .onAppear {
            focused = true
            // Coming back with an existing query? Re-paint the highlight.
            if !finder.query.isEmpty {
                state.highlightQuery = finder.query
                state.highlightCaseSensitive = finder.caseSensitive
            }
        }
        .onDisappear {
            // Closing the Find window removes any "selection" styling.
            state.highlightQuery = ""
        }
        .onChange(of: finder.query) { newValue in
            // Any edit resets the cursor so the next Enter lands on the first
            // occurrence of the new query, and updates the live highlight.
            finder.resetCursor()
            if newValue.isEmpty {
                state.highlightQuery = ""
            } else {
                state.highlightQuery = newValue
                state.highlightCaseSensitive = finder.caseSensitive
            }
        }
        .onChange(of: finder.caseSensitive) { newValue in
            finder.resetCursor()
            if !finder.query.isEmpty {
                state.highlightCaseSensitive = newValue
                state.highlightQuery = finder.query
            }
        }
    }

    @ViewBuilder
    private var statusText: some View {
        if finder.notFound {
            Text("No matches")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if finder.totalMatches > 0 {
            Text("\(finder.currentIndex + 1) of \(finder.totalMatches)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text(" ").font(.caption)
        }
    }
}

/// Configure the Find NSWindow as a floating palette — keeps its titlebar so
/// the user can drag it around, hides minimize/zoom, and sits above the
/// floating teleprompter.
enum FindWindow {
    static func configure(_ window: NSWindow) {
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        if window.frameAutosaveName.isEmpty {
            window.setFrameAutosaveName("NotchPrompter.Find")
        }
    }
}
