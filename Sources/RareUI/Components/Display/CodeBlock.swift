//
//  CodeBlock.swift
//  A port of upstream's `components/ui/code-block.tsx`.
//
//  A framed panel of source code with a header, a line-number gutter and a copy button.
//  The whole syntax theme is built from one colour: see CodeBlockTheme.
//

import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// Which appearance a ``CodeBlock`` draws in.
public enum CodeBlockMode: String, Sendable, CaseIterable {
    /// Follow the page.
    case automatic
    /// Always dark.
    case dark
    /// Always light.
    case light
}

/// A panel of source code, coloured from a single accent.
///
/// ```swift
/// CodeBlock(code: source, language: .swift, filename: "ContentView.swift")
/// ```
///
/// Under Reduce Motion the copy button swaps its icon without springing.
public struct CodeBlock: View {
    private let code: String
    private let language: CodeLanguage
    private let accent: Color
    private let mode: CodeBlockMode
    private let filename: String?
    private let showsFrame: Bool
    private let showsHeader: Bool
    private let showsLineNumbers: Bool
    private let showsCopyButton: Bool
    private let highlightedLines: Set<Int>

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var copied = false
    @State private var resetting: Task<Void, Never>?

    /// How long the button says it has copied, before going back to offering to.
    private static var copyReset: Double {
        1.8
    }

    /// Creates a code block.
    ///
    /// - Parameters:
    ///   - code: The source.
    ///   - language: What it is written in.
    ///   - accent: The colour the whole theme is built from.
    ///   - mode: Which appearance to draw in.
    ///   - filename: The name in the header. Falls back to the language's own.
    ///   - showsFrame: Whether to draw the panel, its border and its header at all.
    ///   - showsHeader: Whether to draw the header. Ignored when the frame is off.
    ///   - showsLineNumbers: Whether to draw the gutter.
    ///   - showsCopyButton: Whether to offer to copy.
    ///   - highlightedLines: One-based line numbers to wash with the accent.
    public init(
        code: String,
        language: CodeLanguage = .swift,
        accent: Color = Color(hex: "#F75001"),
        mode: CodeBlockMode = .automatic,
        filename: String? = nil,
        showsFrame: Bool = true,
        showsHeader: Bool = true,
        showsLineNumbers: Bool = true,
        showsCopyButton: Bool = true,
        highlightedLines: Set<Int> = []
    ) {
        self.code = code
        self.language = language
        self.accent = accent
        self.mode = mode
        self.filename = filename
        self.showsFrame = showsFrame
        self.showsHeader = showsHeader
        self.showsLineNumbers = showsLineNumbers
        self.showsCopyButton = showsCopyButton
        self.highlightedLines = highlightedLines
    }

    private var isDark: Bool {
        switch mode {
        case .dark: true
        case .light: false
        case .automatic: colorScheme == .dark
        }
    }

    private var theme: CodeBlockTheme {
        CodeBlockTheme(accent: accent, dark: isDark)
    }

    private var lines: [[CodeToken]] {
        codeTokenise(code, language: language)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showsFrame, showsHeader { header }
            source
        }
        .background {
            if showsFrame {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.background)
            }
        }
        .overlay {
            if showsFrame {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onDisappear { resetting?.cancel() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(filename ?? language.displayName)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.muted)
            Spacer(minLength: 8)
            if showsCopyButton { copyButton }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(theme.headerBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }

    private var source: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { number, tokens in
                    line(number: number + 1, tokens: tokens)
                }
            }
            .padding(.vertical, 14)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .overlay(alignment: .topTrailing) {
            // With no header there is nowhere to put the button, so it floats over the code.
            if showsCopyButton, !showsFrame || !showsHeader {
                copyButton
                    .padding(10)
                    .background(theme.headerBackground, in: .rect(cornerRadius: 8))
                    .padding(6)
            }
        }
    }

    private func line(number: Int, tokens: [CodeToken]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if showsLineNumbers {
                Text("\(number)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.gutter)
                    .frame(width: 34, alignment: .trailing)
                    .padding(.trailing, 12)
            }

            Text(attributed(tokens))
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)

            Spacer(minLength: 14)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 1)
        .background(highlightedLines.contains(number) ? theme.lineWash : .clear)
    }

    /// One line, coloured a run at a time.
    private func attributed(_ tokens: [CodeToken]) -> AttributedString {
        var line = AttributedString()
        for token in tokens {
            var run = AttributedString(token.text)
            run.foregroundColor = theme.color(for: token.kind)
            if token.kind.isItalic {
                run.font = .system(size: 13, design: .monospaced).italic()
            }
            line.append(run)
        }
        // An empty line still needs a height, so it gets a space rather than nothing.
        return line.characters.isEmpty ? AttributedString(" ") : line
    }

    private var copyButton: some View {
        Button {
            copy()
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(copied ? theme.accent : theme.muted)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 20, height: 20)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(
            reduceMotion ? nil : .spring(duration: copied ? 0.4 : 0.3, bounce: copied ? 0.35 : 0),
            value: copied
        )
        .accessibilityLabel(copied ? "Copied" : "Copy code")
    }

    private func copy() {
        #if canImport(UIKit)
            UIPasteboard.general.string = code
        #elseif canImport(AppKit)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
        #endif

        copied = true
        resetting?.cancel()
        resetting = Task {
            try? await Task.sleep(for: .seconds(Self.copyReset))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }
}
