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
//  that duplication — and lets us state the (near-)exact TSPL code-point ranges.
//
//  Each composed terminal is matched under `.matchingSemantics(.unicodeScalar)` so
//  the code-point ranges compare per Unicode scalar, not per grapheme — the
//  faithful reading of TSPL's lexical structure (e.g. `⚽️` = U+26BD op-head +
//  U+FE0F op-continuation, two scalars, one operator token).
//
//  NOTE on `Character` range bounds: a range bound that is *canonically*
//  decomposable (e.g. U+F900 豈 → U+8C48) is rejected by Swift's regex engine as
//  an "invalid bound for character class range" in EVERY form (string, literal,
//  `CharacterClass` scalar or grapheme). The identifier ranges below work around
//  the one such bound (F900 → F8FF) plus carry two other small deviations from
//  TSPL — all documented at `identifierHead`.
//

import RegexBuilder

enum ApusRegexLibrary {

    // ── Identifier code-point classes ───────────────────────────────────────────
    // Follows TSPL `identifier-head` / `identifier-character` with THREE deliberate
    // deviations (this is the tested-working set; the "faithful" variants either
    // crash or aren't expressible as regex character classes):
    //
    //   1. `F8FF` instead of `F900` as the CJK-compat block start. TSPL starts at
    //      U+F900, but U+F900 (豈) is canonically decomposable → an invalid range
    //      bound (regex engine traps at match time). U+F8FF (last Private-Use char)
    //      is a valid bound. Consequence: the class WRONGLY INCLUDES U+F8FF (a PUA
    //      code point) as an identifier character. (F900…FD3D itself stays covered,
    //      since F8FF…FD3D ⊇ F900…FD3D.)
    //   2. `1681…1DBF` (head) / `1681…1FFF` (continuation) merged across the TSPL
    //      gap `…180D` / `180F…`. Consequence: WRONGLY INCLUDES U+180E (Mongolian
    //      vowel separator), which TSPL excludes.
    //   3. `FE47…FFF8` instead of TSPL `FE47…FFFD`. Consequence: WRONGLY EXCLUDES
    //      U+FFF9…U+FFFD.
    //
    // `_` is folded into the head; bare `_` is the wildcard, excluded at
    // name-consuming sites in Swift.apus via `---("_")`. Unlike coarse `\p{So}`,
    // these do NOT sweep in arbitrary BMP symbols — U+26BD ⚽ (∈ 2500–2775) is an
    // operator-head, not an identifier char, which is what disjoins the two classes.
    static let identifierHead = CharacterClass(
        "A"..."Z", "a"..."z", "_"..."_",
        "\u{00A8}"..."\u{00A8}", "\u{00AA}"..."\u{00AA}", "\u{00AD}"..."\u{00AD}", "\u{00AF}"..."\u{00AF}",
        "\u{00B2}"..."\u{00B5}", "\u{00B7}"..."\u{00BA}", "\u{00BC}"..."\u{00BE}",
        "\u{00C0}"..."\u{00D6}", "\u{00D8}"..."\u{00F6}", "\u{00F8}"..."\u{02FF}",
        "\u{0370}"..."\u{167F}", "\u{1681}"..."\u{1DBF}", "\u{1E00}"..."\u{1FFF}",
        "\u{200B}"..."\u{200D}", "\u{202A}"..."\u{202E}", "\u{203F}"..."\u{2040}",
        "\u{2054}"..."\u{2054}", "\u{2060}"..."\u{20CF}", "\u{2100}"..."\u{218F}",
        "\u{2460}"..."\u{24FF}", "\u{2776}"..."\u{2793}", "\u{2C00}"..."\u{2DFF}",
        "\u{2E80}"..."\u{2FFF}", "\u{3004}"..."\u{3007}", "\u{3021}"..."\u{302F}",
        "\u{3031}"..."\u{D7FF}", "\u{F8FF}"..."\u{FD3D}", "\u{FD40}"..."\u{FDCF}",
        "\u{FDF0}"..."\u{FE1F}", "\u{FE30}"..."\u{FE44}", "\u{FE47}"..."\u{FFF8}",
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
        "\u{00C0}"..."\u{00D6}", "\u{00D8}"..."\u{00F6}", "\u{00F8}"..."\u{167F}",
        "\u{1681}"..."\u{1FFF}", "\u{200B}"..."\u{200D}", "\u{202A}"..."\u{202E}",
        "\u{203F}"..."\u{2040}", "\u{2054}"..."\u{2054}", "\u{2060}"..."\u{218F}",
        "\u{2460}"..."\u{24FF}", "\u{2776}"..."\u{2793}", "\u{2C00}"..."\u{2DFF}",
        "\u{2E80}"..."\u{2FFF}", "\u{3004}"..."\u{3007}", "\u{3021}"..."\u{302F}",
        "\u{3031}"..."\u{D7FF}", "\u{F8FF}"..."\u{FD3D}", "\u{FD40}"..."\u{FDCF}",
        "\u{FDF0}"..."\u{FE44}", "\u{FE47}"..."\u{FFF8}",
        "\u{10000}"..."\u{1FFFD}", "\u{20000}"..."\u{2FFFD}", "\u{30000}"..."\u{3FFFD}",
        "\u{40000}"..."\u{4FFFD}", "\u{50000}"..."\u{5FFFD}", "\u{60000}"..."\u{6FFFD}",
        "\u{70000}"..."\u{7FFFD}", "\u{80000}"..."\u{8FFFD}", "\u{90000}"..."\u{9FFFD}",
        "\u{A0000}"..."\u{AFFFD}", "\u{B0000}"..."\u{BFFFD}", "\u{C0000}"..."\u{CFFFD}",
        "\u{D0000}"..."\u{DFFFD}", "\u{E0000}"..."\u{EFFFD}"
    )

    // ── Operator code-point classes (exact TSPL) ────────────────────────────────
    // TSPL `operator-head` / `operator-character`, exact (no decomposable range
    // bounds here, so no workaround needed). Two subtleties:
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

    /// Dot-operator continuation: `.` ∪ operator-character, but MINUS the reserved
    /// `!`/`?`. TSPL's `dot-operator-character` is `. | operator-character`, and
    /// operator-character contains `!`/`?` — but Swift reserves solo `!`/`?` as
    /// postfix (force / optional-chain), so they may NOT be part of a `.`-led
    /// operator either. Without this exclusion, `dotOperator` greedily eats the
    /// optional-chaining `?` in a keypath component like `\.?.foo` (breaks
    /// testKeypathExpression#1/#12/#13). Mirrors the old coarse dot class
    /// `[.\-+*/%|^~<>=&]`, which likewise omitted `!?`.
    static let dotOperatorCharacter = CharacterClass(operatorCharacter, .anyOf(".")).subtracting(.anyOf("!?"))

    // ── Terminals ───────────────────────────────────────────────────────────────
    // `.matchingSemantics(.unicodeScalar)` applied directly on each composed regex.

    /// `identifier` — head then zero-or-more continuation chars.
    static let identifier = Regex {
        identifierHead
        ZeroOrMore { identifierCharacter }
    }.matchingSemantics(.unicodeScalar)

    /// Shared operator body — `(headStandalone)(char)* | special(char)+`. Plain
    /// (no scalar option); the terminals below apply `.unicodeScalar` on the whole.
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

    /// `operatorToken` / `operatorName` — the operator body under scalar semantics.
    static let operatorToken = operatorBody.matchingSemantics(.unicodeScalar)

    /// `postfixOperatorToken` — the operator body, but may not BEGIN with `!`/`?`
    /// (those split into force/optional postfix tokens).
    static let postfixOperatorToken = Regex {
        NegativeLookahead { CharacterClass.anyOf("!?") }
        operatorBody
    }.matchingSemantics(.unicodeScalar)

    /// `dotOperator` — a `.`-led operator (`...`, `..<`, `.+.`); needs ≥1
    /// continuation (a lone `.` is member access).
    static let dotOperator = Regex {
        "."
        OneOrMore { dotOperatorCharacter }
    }.matchingSemantics(.unicodeScalar)

    // ── Registry (key == `.apus` terminal name) ─────────────────────────────────
    static let patterns: [String: Regex<AnyRegexOutput>] = [
        "identifier":           Regex<AnyRegexOutput>(identifier.regex),
        "operatorToken":        Regex<AnyRegexOutput>(operatorToken.regex),
        "operatorName":         Regex<AnyRegexOutput>(operatorToken.regex),
        "postfixOperatorToken": Regex<AnyRegexOutput>(postfixOperatorToken.regex),
        "dotOperator":          Regex<AnyRegexOutput>(dotOperator.regex),
    ]
}
