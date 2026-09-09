import RareUI
import SwiftUI

@MainActor
let codeBlockEntry = CatalogEntry(
    "Code Block",
    summary: "Source code in a framed panel, coloured entirely from one accent.",
    demos: [
        Demo(
            "Any accent",
            note: """
            Every colour in the theme is a shade of the accent: its hue and saturation are \
            kept and its lightness is replaced, one value per token kind. Change the accent \
            above and the whole theme follows.
            """,
            code: """
            CodeBlock(code: source, language: .swift, filename: "ContentView.swift")
            """
        ) { CodeBlockDemo() },

        Demo(
            "Highlighted lines",
            note: "A one-based line number gets a wash of the accent behind it.",
            code: """
            CodeBlock(code: source, highlightedLines: [3, 4])
            """
        ) {
            CodeBlock(
                code: SampleCode.swift,
                language: .swift,
                filename: "Counter.swift",
                highlightedLines: [4, 5]
            )
        },

        Demo(
            "Other languages, and no frame",
            code: """
            CodeBlock(code: json, language: .json, showsFrame: false)
            """
        ) {
            VStack(spacing: 14) {
                CodeBlock(code: SampleCode.kotlin, language: .kotlin, filename: "Counter.kt")
                CodeBlock(code: SampleCode.shell, language: .shell, showsLineNumbers: false)
            }
        }
    ]
) {
    CodeBlock(
        code: "let a = 1",
        language: .swift,
        showsHeader: false,
        showsLineNumbers: false,
        showsCopyButton: false
    )
    .frame(width: 110)
}

private struct CodeBlockDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        CodeBlock(
            code: SampleCode.swift,
            language: .swift,
            accent: settings.accent,
            filename: "Counter.swift"
        )
    }
}

private enum SampleCode {
    static let swift = """
    import RareUI
    import SwiftUI

    /// A number that rolls to its new value.
    struct Total: View {
        @State private var value = 1234.0

        var body: some View {
            AnimatedCounter(value: value, prefix: "$")
                .font(.largeTitle)
                .onTapGesture { value += 111 }
        }
    }
    """

    static let kotlin = """
    package io.github.dim971.rareui

    @Composable
    fun Total(modifier: Modifier = Modifier) {
        var value by remember { mutableStateOf(1234) }
        AnimatedCounter(value = value, prefix = "$", modifier = modifier)
    }
    """

    static let shell = """
    # add it to a project
    swift package add-dependency https://github.com/dim971/rareui-ios --from 0.1.0
    """
}
