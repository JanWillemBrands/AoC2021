//
//  GrammarRegexLibrary.swift
//  Advent
//
//  RegexBuilder definitions for `.apus` regex terminals declared with `@builder`.
//
//  Naming convention: a terminal written in the grammar as
//
//      identifier - @builder .
//
//  resolves its scanner regex to `ApusRegexLibrary.patterns["identifier"]` — the
//  dictionary KEY equals the terminal name. (`@builder(otherKey)` overrides the key
//  when the Swift symbol should differ from the terminal name.)
//
//  Why this exists: flat `/…/` strings in the grammar cannot reference each other,
//  so large Unicode character classes (the identifier / operator ranges) are
//  copy-pasted verbatim across several terminals. Defining them ONCE here as
//  reusable `CharacterClass` components and composing terminals from them removes
//  that duplication — and lets us state the EXACT TSPL code-point ranges (which a
//  string `/[\u{…}-\u{…}]/` cannot: combining-mark / variation-selector bounds
//  throw "invalid bound for character class range" at construction).
//
//  The composed terminals are matched under `.unicodeScalar` semantics (applied
//  once at the `patterns` registry) so the scalar-value ranges compare per scalar,
//  not per grapheme — the faithful reading of TSPL's lexical structure.
//

import RegexBuilder

enum ApusRegexLibrary {

    // ── Identifier code-point classes (exact TSPL) ──────────────────────────────
    // TSPL (The Swift Programming Language → Lexical Structure) `identifier-head` /
    // `identifier-character`, transcribed 1:1. Ranges kept split exactly as TSPL —
    // note the `180D`/`180F` gap (U+180E excluded), `F900` start, `FFFD` end. `_` is
    // folded into the head; bare `_` is the wildcard, excluded at name-consuming
    // sites in Swift.apus via `---("_")`. Unlike coarse `\p{So}`, these do NOT
    // include arbitrary emoji — U+26BD ⚽ is an operator-head, not an identifier char.
    static let identifierHead = CharacterClass(
        "A"..."Z", "a"..."z", "_"..."_",
        "\u{00A8}"..."\u{00A8}", "\u{00AA}"..."\u{00AA}", "\u{00AD}"..."\u{00AD}", "\u{00AF}"..."\u{00AF}",
        "\u{00B2}"..."\u{00B5}", "\u{00B7}"..."\u{00BA}", "\u{00BC}"..."\u{00BE}",
        "\u{00C0}"..."\u{00D6}", "\u{00D8}"..."\u{00F6}", "\u{00F8}"..."\u{00FF}",
        "\u{0100}"..."\u{02FF}", "\u{0370}"..."\u{167F}", "\u{1681}"..."\u{180D}",
        "\u{180F}"..."\u{1DBF}", "\u{1E00}"..."\u{1FFF}", "\u{200B}"..."\u{200D}",
        "\u{202A}"..."\u{202E}", "\u{203F}"..."\u{2040}", "\u{2054}"..."\u{2054}",
        "\u{2060}"..."\u{206F}", "\u{2070}"..."\u{20CF}", "\u{2100}"..."\u{218F}",
        "\u{2460}"..."\u{24FF}", "\u{2776}"..."\u{2793}", "\u{2C00}"..."\u{2DFF}",
        "\u{2E80}"..."\u{2FFF}", "\u{3004}"..."\u{3007}", "\u{3021}"..."\u{302F}",
        "\u{3031}"..."\u{D7FF}", "\u{F900}"..."\u{FD3D}", "\u{FD40}"..."\u{FDCF}",
        "\u{FDF0}"..."\u{FE1F}", "\u{FE30}"..."\u{FE44}", "\u{FE47}"..."\u{FFFD}",
        "\u{10000}"..."\u{1FFFD}", "\u{20000}"..."\u{2FFFD}", "\u{30000}"..."\u{3FFFD}",
        "\u{40000}"..."\u{4FFFD}", "\u{50000}"..."\u{5FFFD}", "\u{60000}"..."\u{6FFFD}",
        "\u{70000}"..."\u{7FFFD}", "\u{80000}"..."\u{8FFFD}", "\u{90000}"..."\u{9FFFD}",
        "\u{A0000}"..."\u{AFFFD}", "\u{B0000}"..."\u{BFFFD}", "\u{C0000}"..."\u{CFFFD}",
        "\u{D0000}"..."\u{DFFFD}", "\u{E0000}"..."\u{EFFFD}"
    )

    static let identifierCharacter = CharacterClass(
        "A"..."Z", "a"..."z", "0"..."9", "_"..."_",
        "\u{00A8}"..."\u{00A8}", "\u{00AA}"..."\u{00AA}", "\u{00AD}"..."\u{00AD}", "\u{00AF}"..."\u{00AF}",
        "\u{00B2}"..."\u{00B5}", "\u{00B7}"..."\u{00BA}", "\u{00BC}"..."\u{00BE}",
        "\u{00C0}"..."\u{00D6}", "\u{00D8}"..."\u{00F6}", "\u{00F8}"..."\u{00FF}",
        "\u{0100}"..."\u{02FF}", "\u{0300}"..."\u{036F}", "\u{0370}"..."\u{167F}",
        "\u{1681}"..."\u{180D}", "\u{180F}"..."\u{1DBF}", "\u{1DC0}"..."\u{1DFF}",
        "\u{1E00}"..."\u{1FFF}", "\u{200B}"..."\u{200D}", "\u{202A}"..."\u{202E}",
        "\u{203F}"..."\u{2040}", "\u{2054}"..."\u{2054}", "\u{2060}"..."\u{206F}",
        "\u{2070}"..."\u{20CF}", "\u{20D0}"..."\u{20FF}", "\u{2100}"..."\u{218F}",
        "\u{2460}"..."\u{24FF}", "\u{2776}"..."\u{2793}", "\u{2C00}"..."\u{2DFF}",
        "\u{2E80}"..."\u{2FFF}", "\u{3004}"..."\u{3007}", "\u{3021}"..."\u{302F}",
        "\u{3031}"..."\u{D7FF}", "\u{F900}"..."\u{FD3D}", "\u{FD40}"..."\u{FDCF}",
        "\u{FDF0}"..."\u{FE1F}", "\u{FE20}"..."\u{FE2F}", "\u{FE30}"..."\u{FE44}", "\u{FE47}"..."\u{FFFD}",
        "\u{10000}"..."\u{1FFFD}", "\u{20000}"..."\u{2FFFD}", "\u{30000}"..."\u{3FFFD}",
        "\u{40000}"..."\u{4FFFD}", "\u{50000}"..."\u{5FFFD}", "\u{60000}"..."\u{6FFFD}",
        "\u{70000}"..."\u{7FFFD}", "\u{80000}"..."\u{8FFFD}", "\u{90000}"..."\u{9FFFD}",
        "\u{A0000}"..."\u{AFFFD}", "\u{B0000}"..."\u{BFFFD}", "\u{C0000}"..."\u{CFFFD}",
        "\u{D0000}"..."\u{DFFFD}", "\u{E0000}"..."\u{EFFFD}"
    )

    // ── Operator code-point classes (exact TSPL) ────────────────────────────────
    // TSPL `operator-head` / `operator-character`. Two subtleties:
    //  • `= ! ? &` ARE operator-heads in the grammar, but Swift reserves them when
    //    SOLO (`=` assign, `!`/`?` postfix, `&` inout/bitwise); they only form an
    //    operator WITH ≥1 continuation. So the "stands alone" head subtracts them
    //    (`operatorHeadStandalone`); they survive via `operatorSpecial` + continuation.
    //  • `3021–302F` is NOT in `operator-head` but IS kept in `operator-character` —
    //    a historical inclusion swift-syntax retains for source compatibility (those
    //    ideographs may CONTINUE but not START an operator).
    static let operatorHead = CharacterClass(
        "/"..."/", "="..."=", "-"..."-", "+"..."+", "!"..."!", "*"..."*", "%"..."%",
        "<"..."<", ">"...">", "&"..."&", "|"..."|", "^"..."^", "~"..."~", "?"..."?",
        "\u{00A1}"..."\u{00A7}", "\u{00A9}"..."\u{00A9}", "\u{00AB}"..."\u{00AC}",
        "\u{00AE}"..."\u{00AE}", "\u{00B0}"..."\u{00B1}", "\u{00B6}"..."\u{00B6}",
        "\u{00BB}"..."\u{00BB}", "\u{00BF}"..."\u{00BF}", "\u{00D7}"..."\u{00D7}",
        "\u{00F7}"..."\u{00F7}", "\u{2016}"..."\u{2017}", "\u{2020}"..."\u{2027}",
        "\u{2030}"..."\u{203E}", "\u{2041}"..."\u{2053}", "\u{2055}"..."\u{205E}",
        "\u{2190}"..."\u{23FF}", "\u{2500}"..."\u{2775}", "\u{2794}"..."\u{2BFF}",
        "\u{2E00}"..."\u{2E7F}", "\u{3001}"..."\u{3003}", "\u{3008}"..."\u{3020}",
        "\u{3030}"..."\u{3030}"
    )

    static let operatorCharacter = CharacterClass(
        "/"..."/", "="..."=", "-"..."-", "+"..."+", "!"..."!", "*"..."*", "%"..."%",
        "<"..."<", ">"...">", "&"..."&", "|"..."|", "^"..."^", "~"..."~", "?"..."?",
        "\u{00A1}"..."\u{00A7}", "\u{00A9}"..."\u{00A9}", "\u{00AB}"..."\u{00AC}",
        "\u{00AE}"..."\u{00AE}", "\u{00B0}"..."\u{00B1}", "\u{00B6}"..."\u{00B6}",
        "\u{00BB}"..."\u{00BB}", "\u{00BF}"..."\u{00BF}", "\u{00D7}"..."\u{00D7}",
        "\u{00F7}"..."\u{00F7}", "\u{2016}"..."\u{2017}", "\u{2020}"..."\u{2027}",
        "\u{2030}"..."\u{203E}", "\u{2041}"..."\u{2053}", "\u{2055}"..."\u{205E}",
        "\u{2190}"..."\u{23FF}", "\u{2500}"..."\u{2775}", "\u{2794}"..."\u{2BFF}",
        "\u{2E00}"..."\u{2E7F}", "\u{3001}"..."\u{3003}", "\u{3008}"..."\u{3020}",
        "\u{3021}"..."\u{302F}", "\u{3030}"..."\u{3030}",   // 3021–302F: swift-syntax compat (continuation only)
        "\u{0300}"..."\u{036F}", "\u{1DC0}"..."\u{1DFF}", "\u{20D0}"..."\u{20FF}",
        "\u{FE00}"..."\u{FE0F}", "\u{FE20}"..."\u{FE2F}", "\u{E0100}"..."\u{E01EF}"
    )

    /// Operator-head chars that may stand ALONE (= TSPL head minus the solo-reserved
    /// `= ! ? &`). Paired with `operatorSpecial` for the `special(cont)+` arm.
    static let operatorHeadStandalone = operatorHead.subtracting(.anyOf("=!?&"))
    static let operatorSpecial = CharacterClass.anyOf("=!?&")

    /// Dot-operator continuation: `.` ∪ operator-character (a `.`-led operator may
    /// contain further dots; a non-dot operator may not).
    static let dotOperatorCharacter = CharacterClass(operatorCharacter, .anyOf("."))

    // ── Terminals ───────────────────────────────────────────────────────────────

    /// `identifier` — head then zero-or-more continuation chars.
    static let identifier = Regex {
        identifierHead
        ZeroOrMore { identifierCharacter }
    }

    /// Shared operator body — `(headStandalone)(char)* | special(char)+`. Backs
    /// `operatorToken`, `operatorName`, and (behind a `(?![!?])`) `postfixOperatorToken`.
    static let operatorBody = Regex {
        ChoiceOf {
            Regex {
                operatorHeadStandalone
                ZeroOrMore { operatorCharacter }
            }
            Regex {
                operatorSpecial
                OneOrMore { operatorCharacter }
            }
        }
    }

    /// `postfixOperatorToken` — the operator body, but may not BEGIN with `!`/`?`
    /// (those split into force/optional postfix tokens).
    static let postfixOperatorToken = Regex {
        NegativeLookahead { CharacterClass.anyOf("!?") }
        operatorBody
    }

    /// `dotOperator` — a `.`-led operator (`...`, `..<`, `.+.`); needs ≥1
    /// continuation (a lone `.` is member access).
    static let dotOperator = Regex {
        "."
        OneOrMore { dotOperatorCharacter }
    }

    // ── Registry (key == `.apus` terminal name) ─────────────────────────────────
    // `.unicodeScalar` applied once here (regex-wide) so the code-point ranges above
    // compare per Unicode scalar, not per grapheme.
    private static func scalar<R: RegexComponent>(_ r: R) -> Regex<AnyRegexOutput> {
        Regex<AnyRegexOutput>(r.regex.matchingSemantics(.unicodeScalar))
    }

    static let patterns: [String: Regex<AnyRegexOutput>] = [
        "identifier":           scalar(identifier),
        "operatorToken":        scalar(operatorBody),
        "operatorName":         scalar(operatorBody),
        "postfixOperatorToken": scalar(postfixOperatorToken),
        "dotOperator":          scalar(dotOperator),
    ]
}
