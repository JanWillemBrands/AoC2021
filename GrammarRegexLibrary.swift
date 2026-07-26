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
//  so large Unicode character classes (e.g. the operator ranges) are copy-pasted
//  verbatim across several terminals. Defining them ONCE here as reusable
//  `CharacterClass` / regex components and composing terminals from them removes
//  that duplication — the payoff a string regex cannot provide.
//

import RegexBuilder

enum ApusRegexLibrary {

    // ── Shared building blocks ──────────────────────────────────────────────
    // Defined once, reused across terminals. (Identifier classes first; the
    // operator ranges — shared by operatorToken/postfixOperatorToken/operatorName/
    // dotOperator — are the next migration and will live here too.)

    /// Identifier head: TR31 `XID_Start`, emoji (`\p{So}`), and `_` folded in
    /// (bare `_` is the wildcard, excluded at name-consuming sites in Swift.apus).
    static let identifierHead     = /[\p{XID_Start}_\p{So}]/

    /// Identifier continuation: TR31 `XID_Continue` plus emoji.
    static let identifierContinue = /[\p{XID_Continue}\p{So}]/

    // Operator classes — the reason this file exists. In the flat grammar these
    // two large Unicode classes were copy-pasted into four terminals; here they
    // are defined ONCE and reused.

    /// ASCII operator head chars (non-reserved): `- + * / % | ^ ~ < >`.
    static let operatorHeadASCII = /[-+*\/%|^~<>]/
    /// Unicode operator chars: math/other-symbol minus ASCII (`\p{Sm}`/`\p{So}` above U+007F).
    static let operatorUnicode   = /[[\p{Sm}\p{So}]--[\u{0}-\u{7F}]]/
    /// Combining marks legal in an operator continuation.
    static let operatorCombining = /[\p{Mn}\p{Me}]/
    /// ASCII operator continuation chars (head set plus the reserved `! ? = &`).
    static let operatorContASCII = /[-+*\/%|^~<>!?=&]/
    /// Reserved chars that may LEAD an infix operator but need ≥1 continuation: `! ? = &`.
    static let operatorSpecial   = /[!?=&]/
    /// Dot-operator ASCII continuation: head set plus `.` and `=` & (no `! ?`).
    static let dotOperatorContASCII = /[.\-+*\/%|^~<>=&]/

    /// One operator continuation char: ASCII, combining mark, or Unicode symbol.
    static let operatorContinuation = ChoiceOf {
        operatorContASCII
        operatorCombining
        operatorUnicode
    }

    // ── Terminals ───────────────────────────────────────────────────────────

    /// `identifier` — equivalent to `/[\p{XID_Start}_\p{So}][\p{XID_Continue}\p{So}]*/`.
    static let identifier = Regex {
        identifierHead
        ZeroOrMore { identifierContinue }
    }

    /// Shared operator body — `(head|unicode)(cont)* | special(cont)+`. Backs
    /// `operatorToken`, `operatorName`, and (behind a `(?![!?])`) `postfixOperatorToken`.
    static let operatorBody = Regex {
        ChoiceOf {
            Regex {
                ChoiceOf { operatorHeadASCII; operatorUnicode }
                ZeroOrMore { operatorContinuation }
            }
            Regex {
                operatorSpecial
                OneOrMore { operatorContinuation }
            }
        }
    }

    /// `postfixOperatorToken` — the operator body, but may not BEGIN with `!`/`?`
    /// (those split into force/optional postfix tokens). Ports the `(?![!?])` prefix.
    static let postfixOperatorToken = Regex {
        NegativeLookahead { /[!?]/ }
        operatorBody
    }

    /// `dotOperator` — a `.`-led operator (`...`, `..<`, `.+.`); a dot-led operator
    /// may contain `.`, and needs ≥1 continuation (a lone `.` is member access).
    /// Reuses the two big Unicode classes; continuation adds `.`, drops `! ?`.
    static let dotOperator = Regex {
        "."
        OneOrMore {
            ChoiceOf {
                dotOperatorContASCII
                operatorCombining
                operatorUnicode
            }
        }
    }

    // ── Registry (key == `.apus` terminal name) ─────────────────────────────
    static let patterns: [String: Regex<AnyRegexOutput>] = [
        "identifier":           Regex<AnyRegexOutput>(identifier.regex),
        "operatorToken":        Regex<AnyRegexOutput>(operatorBody.regex),
        "operatorName":         Regex<AnyRegexOutput>(operatorBody.regex),
        "postfixOperatorToken": Regex<AnyRegexOutput>(postfixOperatorToken.regex),
        "dotOperator":          Regex<AnyRegexOutput>(dotOperator.regex),
    ]
}
