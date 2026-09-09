//
//  CodeBlockTests.swift
//  The highlighter and the palette it is drawn in. Checked against the `buildTheme`
//  function in `components/ui/code-block.tsx`.
//

@testable import RareUI
import SwiftUI
import Testing

@Suite("Code tokeniser")
struct CodeTokeniserTests {
    private func kinds(_ source: String, _ language: CodeLanguage) -> [CodeTokenKind] {
        codeTokenise(source, language: language).flatMap(\.self)
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(\.kind)
    }

    private func text(_ source: String, _ language: CodeLanguage, of kind: CodeTokenKind) -> [String] {
        codeTokenise(source, language: language).flatMap(\.self)
            .filter { $0.kind == kind }
            .map(\.text)
    }

    @Test("source is split into lines, and an empty line stays a line")
    func lines() {
        let lines = codeTokenise("let a = 1\n\nlet b = 2", language: .swift)
        #expect(lines.count == 3)
        #expect(lines[1].isEmpty)
    }

    @Test("a language's reserved words are picked out and nothing else is")
    func keywords() {
        #expect(text("let value = 1", .swift, of: .keyword) == ["let"])
        #expect(text("val value = 1", .kotlin, of: .keyword) == ["val"])
        #expect(text("const value = 1", .typescript, of: .keyword) == ["const"])
        // A Swift keyword is not a Kotlin one.
        #expect(text("let value = 1", .kotlin, of: .keyword).isEmpty)
    }

    @Test("a string keeps its quotes and survives an escaped one inside it")
    func strings() {
        #expect(text(#"let a = "hello""#, .swift, of: .string) == [#""hello""#])
        #expect(text(#"let a = "say \"hi\"""#, .swift, of: .string) == [#""say \"hi\"""#])
    }

    @Test("an unterminated string stops at the end of its line rather than eating the file")
    func unterminatedString() {
        let lines = codeTokenise("let a = \"oops\nlet b = 2", language: .swift)
        #expect(lines.count == 2)
        #expect(lines[1].contains { $0.kind == .keyword && $0.text == "let" })
    }

    @Test("a line comment runs to the end of the line and no further")
    func lineComments() {
        let lines = codeTokenise("let a = 1 // why\nlet b = 2", language: .swift)
        #expect(lines[0].contains { $0.kind == .comment })
        #expect(!lines[1].contains { $0.kind == .comment })
        // A shell comment starts with a hash instead.
        #expect(!text("# note", .shell, of: .comment).isEmpty)
        #expect(text("// not a comment here", .json, of: .comment).isEmpty)
    }

    @Test("a block comment spans lines and every line of it is a comment")
    func blockComments() {
        let lines = codeTokenise("/* one\n   two */\nlet a = 1", language: .swift)
        #expect(lines[0].allSatisfy { $0.kind == .comment })
        #expect(lines[1].contains { $0.kind == .comment })
        #expect(lines[2].contains { $0.kind == .keyword })
    }

    @Test("a name followed by a bracket is being called")
    func functions() {
        #expect(text("print(value)", .swift, of: .function) == ["print"])
        // Even with a space between, which is how some styles write it.
        #expect(text("print (value)", .swift, of: .function) == ["print"])
    }

    @Test("a capitalised name is a type")
    func types() {
        #expect(text("var body: some View", .swift, of: .className) == ["View"])
    }

    @Test("an annotation is an attribute rather than a plain word")
    func attributes() {
        #expect(text("@State private var value = 1", .swift, of: .attributeName) == ["@State"])
        #expect(text("@Composable fun Total()", .kotlin, of: .attributeName) == ["@Composable"])
    }

    @Test("in JSON a word before a colon is a key")
    func jsonKeys() {
        // Quoted keys are strings, as they should be; a bare word before a colon is the
        // thing worth colouring differently.
        #expect(text("{ name: 1 }", .json, of: .property) == ["name"])
    }

    @Test("numbers are numbers, including the ones with a decimal point in them")
    func numbers() {
        #expect(text("let a = 42", .swift, of: .number) == ["42"])
        #expect(text("let a = 3.14", .swift, of: .number) == ["3.14"])
    }

    @Test("plain text comes back as plain text and loses nothing")
    func plainRoundTrip() {
        for language in CodeLanguage.allCases {
            let source = "let a = 1 // note\nprint(\"hi\")"
            let rebuilt = codeTokenise(source, language: language)
                .map { $0.map(\.text).joined() }
                .joined(separator: "\n")
            #expect(rebuilt == source, "\(language) lost or gained characters")
        }
    }
}

@Suite("Code block theme")
struct CodeBlockThemeTests {
    @Test("every token kind has a colour of its own")
    func complete() {
        let theme = CodeBlockTheme(hsl: HSL(hue: 20, saturation: 100, lightness: 50), dark: true)
        for kind in CodeTokenKind.allCases {
            #expect(theme.tokens[kind] != nil, "\(kind) has no colour")
        }
    }

    @Test("keywords are drawn in the accent itself")
    func keywordsTakeTheAccent() {
        let theme = CodeBlockTheme(hsl: HSL(hue: 20, saturation: 100, lightness: 50), dark: true)
        #expect(theme.color(for: .keyword) == theme.accent)
    }

    @Test("an accent too dark or too pale is brought into a usable range")
    func accentClamped() {
        // Otherwise a nearly black accent makes keywords invisible on a dark panel, and a
        // nearly white one stops reading as a colour at all.
        let black = CodeBlockTheme(hsl: HSL(hue: 20, saturation: 100, lightness: 2), dark: true)
        let white = CodeBlockTheme(hsl: HSL(hue: 20, saturation: 100, lightness: 99), dark: true)
        #expect(black.accent != white.accent)

        let resolved = { (theme: CodeBlockTheme) -> Double in
            let colour = theme.accent.resolve(in: EnvironmentValues())
            return RGBA(
                red: Double(colour.red), green: Double(colour.green), blue: Double(colour.blue)
            ).hsl.lightness
        }
        #expect(resolved(black) >= 55 && resolved(black) <= 71)
        #expect(resolved(white) >= 55 && resolved(white) <= 71)
    }

    @Test("the light appearance is the same ramp upside down")
    func lightIsInverted() {
        let dark = CodeBlockTheme(hsl: HSL(hue: 20, saturation: 60, lightness: 50), dark: true)
        let light = CodeBlockTheme(hsl: HSL(hue: 20, saturation: 60, lightness: 50), dark: false)

        func lightness(_ colour: Color) -> Double {
            let resolved = colour.resolve(in: EnvironmentValues())
            return RGBA(
                red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue)
            ).hsl.lightness
        }

        // A comment is pale on a dark panel and dark on a light one.
        #expect(lightness(dark.color(for: .comment)) < lightness(light.color(for: .comment)))
        #expect(lightness(dark.color(for: .property)) > lightness(light.color(for: .property)))
    }

    @Test("comments and attribute names are the italic ones, as upstream sets them")
    func italics() {
        #expect(CodeTokenKind.comment.isItalic)
        #expect(CodeTokenKind.attributeName.isItalic)
        #expect(!CodeTokenKind.keyword.isItalic)
        #expect(!CodeTokenKind.string.isItalic)
    }
}
