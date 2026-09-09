//
//  CodeTokeniser.swift
//  A small syntax highlighter, standing in for the one upstream gets from Prism.
//
//  The scope is deliberately narrow. Prism knows nearly three hundred languages, and
//  pulling in something comparable would break the rule both this library and its Android
//  twin hold to, which is that they have no dependencies at all. What a component gallery
//  actually shows is a handful of languages, so this covers those and falls back to plain
//  text rather than guessing at the rest.
//
//  It is a scanner rather than a grammar: comments, strings, numbers and words, with a
//  word's kind decided by what it is and what follows it. That is enough to read well and
//  little enough to be sure of.
//

import Foundation

/// A language ``CodeBlock`` can colour.
public enum CodeLanguage: String, Sendable, CaseIterable {
    /// Swift.
    case swift
    /// Kotlin.
    case kotlin
    /// TypeScript, and therefore JavaScript.
    case typescript
    /// JSON.
    case json
    /// A shell script.
    case shell
    /// Anything else, drawn without colour.
    case plain

    /// The name shown in the header when no filename is given.
    public var displayName: String {
        switch self {
        case .swift: "Swift"
        case .kotlin: "Kotlin"
        case .typescript: "TypeScript"
        case .json: "JSON"
        case .shell: "Shell"
        case .plain: "Text"
        }
    }

    /// The words the language reserves.
    var keywords: Set<String> {
        switch self {
        case .swift: [
                "actor", "any", "as", "associatedtype", "async", "await", "break", "case", "catch",
                "class", "continue", "default", "defer", "deinit", "do", "else", "enum", "extension",
                "fallthrough", "false", "fileprivate", "final", "for", "func", "guard", "if", "import",
                "in", "indirect", "init", "inout", "internal", "is", "lazy", "let", "mutating", "nil",
                "nonisolated", "open", "operator", "private", "protocol", "public", "repeat", "return",
                "self", "some", "static", "struct", "subscript", "super", "switch", "throw", "throws",
                "true", "try", "typealias", "var", "where", "while"
            ]
        case .kotlin: [
                "as", "break", "by", "catch", "class", "companion", "constructor", "continue", "data",
                "do", "else", "enum", "external", "false", "final", "finally", "for", "fun", "get",
                "if", "import", "in", "infix", "init", "inline", "interface", "internal", "is",
                "lateinit", "null", "object", "open", "operator", "override", "package", "private",
                "protected", "public", "return", "sealed", "set", "super", "suspend", "this", "throw",
                "true", "try", "typealias", "val", "var", "when", "where", "while"
            ]
        case .typescript: [
                "as", "async", "await", "break", "case", "catch", "class", "const", "continue",
                "default", "delete", "do", "else", "enum", "export", "extends", "false", "finally",
                "for", "from", "function", "if", "implements", "import", "in", "instanceof",
                "interface", "let", "new", "null", "of", "return", "satisfies", "static", "super",
                "switch", "this", "throw", "true", "try", "type", "typeof", "undefined", "var",
                "void", "while", "yield"
            ]
        case .json: ["true", "false", "null"]
        case .shell: [
                "case", "cd", "do", "done", "echo", "elif", "else", "esac", "exit", "export", "fi",
                "for", "function", "if", "in", "local", "return", "set", "then", "while"
            ]
        case .plain: []
        }
    }

    /// What starts a comment that runs to the end of the line.
    var lineComment: String? {
        switch self {
        case .swift, .kotlin, .typescript: "//"
        case .shell: "#"
        case .json, .plain: nil
        }
    }

    /// Whether the language has `/* */` comments.
    var hasBlockComments: Bool {
        self == .swift || self == .kotlin || self == .typescript
    }
}

/// One coloured run of source.
public struct CodeToken: Equatable, Sendable {
    /// The text itself.
    public let text: String
    /// What it is.
    public let kind: CodeTokenKind
}

/// Splits source into coloured runs, one array per line.
///
/// Lines are kept apart rather than joined, because the gutter, the highlight wash and the
/// hover all work a line at a time.
///
/// - Parameters:
///   - source: The code.
///   - language: What it is written in.
/// - Returns: One array of tokens per line.
public func codeTokenise(_ source: String, language: CodeLanguage) -> [[CodeToken]] {
    var scanner = CodeScanner(source: Array(source), language: language)
    return scanner.run()
}

/// Walks source code once, emitting runs as it goes.
private struct CodeScanner {
    let source: [Character]
    let language: CodeLanguage

    private var index = 0
    private var lines: [[CodeToken]] = []
    private var current: [CodeToken] = []

    init(source: [Character], language: CodeLanguage) {
        self.source = source
        self.language = language
    }

    mutating func run() -> [[CodeToken]] {
        while index < source.count {
            let character = source[index]

            if character == "\n" {
                lines.append(current)
                current = []
                index += 1
            } else if let comment = language.lineComment, matches(comment) {
                take(while: { $0 != "\n" }, as: .comment)
            } else if language.hasBlockComments, matches("/*") {
                takeBlockComment()
            } else if character == "\"" || character == "'" || character == "`" {
                takeString(quote: character)
            } else if character.isNumber {
                take(while: { $0.isNumber || $0 == "." || $0 == "_" || $0.isLetter }, as: .number)
            } else if character.isLetter || character == "_" || character == "@" || character == "$" {
                takeWord()
            } else if "()[]{},;:".contains(character) {
                emit(String(character), as: .punctuation)
                index += 1
            } else if "+-*/%=<>!&|^~?.".contains(character) {
                take(while: { "+-*/%=<>!&|^~?.".contains($0) }, as: .operator)
            } else {
                take(while: { $0 == " " || $0 == "\t" }, as: .plain)
                // Anything left is something this scanner has no opinion about.
                if index < source.count, source[index] != "\n", !isRecognised(source[index]) {
                    emit(String(source[index]), as: .plain)
                    index += 1
                }
            }
        }

        lines.append(current)
        return lines
    }

    private func isRecognised(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "@"
            || character == "$" || character == "\"" || character == "'" || character == "`"
            || "()[]{},;:".contains(character) || "+-*/%=<>!&|^~?.".contains(character)
            || character == " " || character == "\t"
    }

    private func matches(_ text: String) -> Bool {
        let characters = Array(text)
        guard index + characters.count <= source.count else { return false }
        return Array(source[index ..< index + characters.count]) == characters
    }

    private mutating func emit(_ text: String, as kind: CodeTokenKind) {
        guard !text.isEmpty else { return }
        current.append(CodeToken(text: text, kind: kind))
    }

    private mutating func take(while predicate: (Character) -> Bool, as kind: CodeTokenKind) {
        let start = index
        while index < source.count, predicate(source[index]) {
            index += 1
        }
        emit(String(source[start ..< index]), as: kind)
    }

    /// A block comment, which is the one construct here that spans lines.
    private mutating func takeBlockComment() {
        var text = ""
        while index < source.count {
            if matches("*/") {
                text += "*/"
                index += 2
                break
            }
            if source[index] == "\n" {
                emit(text, as: .comment)
                text = ""
                lines.append(current)
                current = []
                index += 1
                continue
            }
            text.append(source[index])
            index += 1
        }
        emit(text, as: .comment)
    }

    private mutating func takeString(quote: Character) {
        var text = String(quote)
        index += 1
        while index < source.count {
            let character = source[index]
            // An escape takes the next character with it, so a quote inside a string does
            // not end it.
            if character == "\\", index + 1 < source.count {
                text.append(character)
                text.append(source[index + 1])
                index += 2
                continue
            }
            // A string that runs to the end of the line is unterminated, not multi-line.
            if character == "\n" { break }
            text.append(character)
            index += 1
            if character == quote { break }
        }
        emit(text, as: .string)
    }

    private mutating func takeWord() {
        let start = index
        if source[index] == "@" || source[index] == "$" { index += 1 }
        while index < source.count, source[index].isLetter || source[index].isNumber || source[index] == "_" {
            index += 1
        }
        let word = String(source[start ..< index])
        emit(word, as: kind(of: word))
    }

    /// What a word is, decided by the word itself and by what comes after it.
    private func kind(of word: String) -> CodeTokenKind {
        if language.keywords.contains(word) { return .keyword }
        // An attribute or annotation: @Observable, @Composable.
        if word.hasPrefix("@") { return .attributeName }

        var probe = index
        while probe < source.count, source[probe] == " " {
            probe += 1
        }
        // A name followed by a bracket is being called, whatever else it might be.
        if probe < source.count, source[probe] == "(" { return .function }
        // In JSON a word followed by a colon is a key rather than a value.
        if language == .json, probe < source.count, source[probe] == ":" { return .property }

        if let first = word.first, first.isUppercase { return .className }
        return .plain
    }
}
