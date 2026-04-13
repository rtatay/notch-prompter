import SwiftUI

/// A lightweight markdown renderer tuned for a teleprompter — headings,
/// paragraphs, bullets, blockquotes and horizontal rules. Inline formatting
/// (**bold**, *italic*, `code`, links) is handled by Foundation's
/// `AttributedString(markdown:)`.
struct MarkdownContent: View {
    let text: String
    @EnvironmentObject var state: PrompterState

    var body: some View {
        VStack(alignment: hAlignment, spacing: CGFloat(state.lineSpacing)) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        }
    }

    private var blocks: [MarkdownBlock] {
        MarkdownParser.parse(text)
    }

    private var hAlignment: HorizontalAlignment {
        switch state.textAlignment {
        case .leading:  return .leading
        case .center:   return .center
        case .trailing: return .trailing
        }
    }

    private var frameAlignment: Alignment {
        switch state.textAlignment {
        case .leading:  return .leading
        case .center:   return .center
        case .trailing: return .trailing
        }
    }

    private var bodyFont: Font {
        .custom(state.fontName, size: CGFloat(state.fontSize))
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(
                    .custom(state.fontName, size: CGFloat(state.fontSize) * headingScale(level))
                        .weight(.bold)
                )
                .foregroundColor(state.textColor)
                .multilineTextAlignment(state.textAlignment)
                .tracking(CGFloat(state.letterSpacing))
                .padding(.vertical, 8)

        case .paragraph(let text):
            Text(inline(text))
                .font(bodyFont.weight(state.fontWeight.swiftUIWeight))
                .foregroundColor(state.textColor)
                .multilineTextAlignment(state.textAlignment)
                .tracking(CGFloat(state.letterSpacing))
                .lineSpacing(CGFloat(state.lineSpacing) * 0.3)
                .fixedSize(horizontal: false, vertical: true)

        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("•")
                    .font(bodyFont)
                    .foregroundColor(state.textColor)
                Text(inline(text))
                    .font(bodyFont.weight(state.fontWeight.swiftUIWeight))
                    .foregroundColor(state.textColor)
                    .multilineTextAlignment(.leading)
                    .tracking(CGFloat(state.letterSpacing))
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .quote(let text):
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(state.textColor.opacity(0.55))
                    .frame(width: 4)
                Text(inline(text))
                    .font(.custom(state.fontName, size: CGFloat(state.fontSize)).italic())
                    .foregroundColor(state.textColor.opacity(0.92))
                    .multilineTextAlignment(.leading)
                    .tracking(CGFloat(state.letterSpacing))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)

        case .divider:
            Rectangle()
                .fill(state.textColor.opacity(0.32))
                .frame(height: 2)
                .padding(.vertical, 12)

        case .blank:
            Text(" ").font(bodyFont)
        }
    }

    private func inline(_ string: String) -> AttributedString {
        var opts = AttributedString.MarkdownParsingOptions()
        opts.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let parsed = try? AttributedString(markdown: string, options: opts) {
            return parsed
        }
        return AttributedString(string)
    }

    private func headingScale(_ level: Int) -> CGFloat {
        switch level {
        case 1:  return 1.65
        case 2:  return 1.38
        case 3:  return 1.2
        default: return 1.08
        }
    }
}

// MARK: - Parser

enum MarkdownBlock {
    case heading(Int, String)
    case paragraph(String)
    case bullet(String)
    case quote(String)
    case divider
    case blank
}

enum MarkdownParser {
    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []

        func flush() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph.removeAll()
            }
        }

        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flush()
                blocks.append(.blank)
                continue
            }

            if line == "---" || line == "***" || line == "___" {
                flush()
                blocks.append(.divider)
                continue
            }

            if line.hasPrefix("### ") {
                flush()
                blocks.append(.heading(3, String(line.dropFirst(4))))
                continue
            }
            if line.hasPrefix("## ") {
                flush()
                blocks.append(.heading(2, String(line.dropFirst(3))))
                continue
            }
            if line.hasPrefix("# ") {
                flush()
                blocks.append(.heading(1, String(line.dropFirst(2))))
                continue
            }

            if line.hasPrefix("> ") {
                flush()
                blocks.append(.quote(String(line.dropFirst(2))))
                continue
            }

            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flush()
                blocks.append(.bullet(String(line.dropFirst(2))))
                continue
            }

            paragraph.append(line)
        }
        flush()
        return blocks
    }
}
