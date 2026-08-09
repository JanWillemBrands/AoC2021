//
//  OracleDisambiguationTests.swift
//  AdventTests
//
//  Oracle disambiguation pragmas (`@left`, `@right`, `@longest`, `@shortest`,
//  `@prefer`, `@avoid`). Two groups:
//
//  1. `TopLevel` — the pre-existing tests, extracted verbatim from
//     `CoreGrammarTests.OracleDisambiguation`. They lock in the behaviour of a
//     pragma attached to a *nonterminal* (or an OPT/POS immediately under one).
//
//  2. `NestedCluster` — the NEW capability being built on this branch: the same
//     pragmas working when attached inside an inline alternate cluster
//     `( a | b )` / `[ … ]` / `{ … }` / `< … >`, not just at the top level of a
//     nonterminal. See `Oracle Disambiguation Unification.md`.
//
//     Tier A — `@prefer` inside a `( a | b )` selection group. The grammar
//     already LOADS today (`@prefer` sets `isPreferred` on the group's alternate
//     via `selection()`); only the Oracle registration walk ignores the nested
//     cluster, so the parse stays ambiguous. These tests therefore pass their
//     acceptance assertion now, and their `isUnambiguous` assertion is wrapped in
//     `withKnownIssue` — it will start FAILING-as-passing (an unexpected pass)
//     once Tier A lands, prompting removal of the wrapper.
//
//     Tier B — `@longest`/`@shortest`/`@left`/`@right` attached to a cluster.
//     This needs new apus syntax + model plumbing (a `disambiguation` slot on
//     cluster nodes), so the grammar does not even parse today. The provisional
//     syntax under test is "the pragma immediately after the opening bracket
//     annotates the cluster node" (mirroring where `@avoid`/`@prefer` already sit
//     inside brackets). The whole `try` is wrapped in `withKnownIssue`; when the
//     plumbing lands, the grammar parses, the rule fires, and the wrapper flags.
//

import Testing
import Foundation

@Suite("Oracle Disambiguation", .serialized)
struct OracleDisambiguationTests {

    // MARK: - Top-level pragmas (extracted, behaviour lock)

    @Suite("Top-level pragmas", .serialized)
    struct TopLevel {

        @Test("@left prunes ambiguous expression")
        func leftAssocPrunes() throws {
            let (matches, pruned) = try parseAndDisambiguate(
                grammar: #"number - /[0-9]+/ . @left E = E "+" E | number ."#,
                message: "1 + 2 + 3"
            )
            #expect(matches, "1 + 2 + 3 should parse")
            #expect(pruned > 0, "Oracle should prune right-associative derivation")
        }

        @Test("@right prunes ambiguous expression")
        func rightAssocPrunes() throws {
            let (matches, pruned) = try parseAndDisambiguate(
                grammar: #"number - /[0-9]+/ . @right E = E "+" E | number ."#,
                message: "1 + 2 + 3"
            )
            #expect(matches, "1 + 2 + 3 should parse")
            #expect(pruned > 0, "Oracle should prune left-associative derivation")
        }

        @Test("no annotation means no pivot pruning")
        func noAnnotationNoPrune() throws {
            let (matches, pruned) = try parseAndDisambiguate(
                grammar: #"number - /[0-9]+/ . E = E "+" E | number ."#,
                message: "1 + 2 + 3"
            )
            #expect(matches, "1 + 2 + 3 should parse")
            #expect(pruned == 0, "Oracle should not prune without annotation")
        }

        @Test("unambiguous input needs no pruning")
        func unambiguousNoPrune() throws {
            let (matches, pruned) = try parseAndDisambiguate(
                grammar: #"number - /[0-9]+/ . @left E = E "+" E | number ."#,
                message: "1 + 2"
            )
            #expect(matches, "1 + 2 should parse")
            #expect(pruned == 0, "Unambiguous input should not need pruning")
        }

        @Test("@left with four operands")
        func leftAssocFourOperands() throws {
            let (matches, pruned) = try parseAndDisambiguate(
                grammar: #"number - /[0-9]+/ . @left E = E "+" E | number ."#,
                message: "1 + 2 + 3 + 4"
            )
            #expect(matches, "1 + 2 + 3 + 4 should parse")
            #expect(pruned > 0, "Oracle should prune non-left-associative derivations")
        }

        @Test("@longest still works (extent disambiguation)")
        func longestExtent() throws {
            let (matches, pruned) = try parseAndDisambiguate(
                grammar: #"word - /[a-z]+/ . @longest S = < word > ."#,
                message: "hello world foo"
            )
            #expect(matches)
            // Longest keeps only the maximum extent for each start position
        }

        // A `@prefer` alternate nested inside an `?` OPT must NOT over-prune: the
        // multi-element reading has to survive disambiguation. (Regression: a Swift.apus
        // subscript `a[0, 1]` was thought to hit a `@prefer`+OPT engine limitation; a
        // minimal repro proved `@prefer` under an OPT is sound — this locks that in.)
        @Test("@prefer under an OPT keeps empty / single / multi (flat)")
        func preferUnderOptFlat() throws {
            let g = #"item - /[a-z]/ . S = "[" list? "]" . list = @prefer item | item "," list ."#
            for msg in ["[]", "[a]", "[a, b]", "[a, b, c]"] {
                let r = try parsePostOracle(grammar: g, message: msg)
                #expect(r.postMatch, "@prefer under OPT dropped a valid parse for '\(msg)'")
            }
        }

        @Test("@prefer under an OPT keeps multi under left recursion")
        func preferUnderOptLeftRecursive() throws {
            let g = #"atom - /[a-z]/ . S = atom | S "[" list? "]" . list = @prefer item | item "," list . item = atom ."#
            for msg in ["a[]", "a[b]", "a[b, c]", "a[b][c, d]"] {
                let r = try parsePostOracle(grammar: g, message: msg)
                #expect(r.postMatch, "@prefer under left-recursive OPT dropped a valid parse for '\(msg)'")
            }
        }

        // `@avoid` is the pivot-keyed dual of `@prefer` for an OPT that should be SKIPPED
        // whenever skipping still yields a complete parse. Here `m` is BOTH the modifier `mod`
        // and an `id`, so `m x` parses two ways: take-mod (`mod=m`, `id=x`) or skip (`id=m`,
        // `id=x`). `@avoid` must keep the SKIP reading.
        @Test("@avoid skips the optional when skipping still parses")
        func avoidSkipsOptional() throws {
            let g = #"mod - /m/ . id - /[a-z]/ . S = [ @avoid mod ] id id? ."#
            let r = try parsePostOracle(grammar: g, message: "m x")
            #expect(r.postMatch, "@avoid grammar should still parse 'm x'")
            #expect(r.pruned > 0, "@avoid should prune the take-modifier reading")
        }

        // Edge case (Oracle.swift:116-118): when skipping the @avoid'd optional does NOT lead
        // to a complete parse, the lone "taken" reading must survive. Here `id` can't start at
        // the leading `-`, so the `op` prefix is forced.
        @Test("@avoid keeps the taken reading when skipping cannot parse")
        func avoidKeepsTakenWhenSkipFails() throws {
            let g = #"op - /-/ . id - /[a-z]+/ . S = [ @avoid op ] id ."#
            let r = try parsePostOracle(grammar: g, message: "-x")
            #expect(r.postMatch, "@avoid must keep the forced 'op' reading for '-x'")
        }
    }

    // MARK: - Nested cluster pragmas (new capability)

    @Suite("Nested cluster pragmas", .serialized)
    struct NestedCluster {

        // ---- Tier A: @prefer inside a ( a | b ) selection group ----------------
        //
        // Minimal analogue of the factored `keyPathExpression` that motivated this
        // work: a single token `x` is ambiguous between a "root" reading and a
        // "component" reading, so `[x]` parses two ways that cover the exact same
        // span. `@prefer` on the first alternate of the group should keep only the
        // root reading. The group LOADS today; the Oracle just never scans it, so
        // the ambiguity currently survives (hence the `withKnownIssue` on
        // `isUnambiguous`).

        @Test("@prefer in ( a | b ) selection group — acceptance preserved, ambiguity removed")
        func preferInSelectionGroup() throws {
            let g = #"x - /x/ . S = "[" ( @prefer root comps? | comps ) "]" . root = x . comps = x ."#
            let r = try parseOracleAmbiguity(grammar: g, message: "[x]")
            #expect(r.postMatch, "@prefer in a selection group must not drop the valid parse")
            withKnownIssue("nested @prefer in ( | ) not yet unified — Tier A", isIntermittent: false) {
                #expect(r.isUnambiguous, "@prefer in the group should collapse the root/component ambiguity")
            }
        }

        // The multi-element reading under a nested prefer must still survive — the
        // group analogue of `preferUnderOptFlat`. `list` here is inlined into a
        // ( a | b ) group instead of a nonterminal top level.
        @Test("@prefer in ( a | b ) keeps single and multi element readings")
        func preferInGroupKeepsReadings() throws {
            let g = #"item - /[a-z]/ . S = "[" ( @prefer item | item "," S2 )? "]" . S2 = item | item "," S2 ."#
            for msg in ["[]", "[a]", "[a, b]", "[a, b, c]"] {
                let r = try parsePostOracle(grammar: g, message: msg)
                #expect(r.postMatch, "@prefer in a group dropped a valid parse for '\(msg)'")
            }
        }

        // ---- Tier B: extent / associativity pragmas ON a cluster node ----------
        //
        // These require apus syntax + model support that does not exist yet, so the
        // grammar parse itself throws today; the whole `try` is wrapped in
        // `withKnownIssue`. Provisional syntax: the pragma sits immediately after
        // the opening bracket and annotates the cluster node.

        // `@left` moved one level down: E's body is a single ( … ) cluster holding
        // both alternates, and `@left` annotates inside it. Mirrors the top-level
        // `leftAssocPrunes` on "1 + 2 + 3".
        @Test("@left on a ( … ) cluster prunes to left-associative")
        func leftOnCluster() throws {
            withKnownIssue("cluster-attached @left needs parser + model plumbing — Tier B") {
                let g = #"n - /[0-9]+/ . S = E . E = ( @left E "+" E | n ) ."#
                let r = try parseOracleAmbiguity(grammar: g, message: "1 + 2 + 3")
                #expect(r.postMatch)
                #expect(r.isUnambiguous, "@left on the cluster should leave a single left-assoc tree")
            }
        }

        @Test("@right on a ( … ) cluster prunes to right-associative")
        func rightOnCluster() throws {
            withKnownIssue("cluster-attached @right needs parser + model plumbing — Tier B") {
                let g = #"n - /[0-9]+/ . S = E . E = ( @right E "+" E | n ) ."#
                let r = try parseOracleAmbiguity(grammar: g, message: "1 + 2 + 3")
                #expect(r.postMatch)
                #expect(r.isUnambiguous, "@right on the cluster should leave a single right-assoc tree")
            }
        }

        // `@longest` on a POS closure `< … >`. Faithful nested analogue of the
        // top-level `longestExtent` (which annotates the nonterminal wrapping the
        // POS); here the annotation moves onto the closure itself.
        @Test("@longest on a < … > POS closure")
        func longestOnPOSClosure() throws {
            withKnownIssue("cluster-attached @longest needs parser + model plumbing — Tier B") {
                let g = #"word - /[a-z]+/ . S = < @longest word > ."#
                let r = try parseOracleAmbiguity(grammar: g, message: "hello world foo")
                #expect(r.postMatch)
            }
        }

        // `@longest` on a KLN closure `{ … }`. Distinct from the POS case because
        // KLN/POS re-entry reuses a SINGLE shared CRF cluster ("cluster index is a
        // node ref, not a position") — the yield-identity hazard called out in the
        // plan. This test is the tripwire for verifying repetition yields don't
        // conflate distinct occurrences before we prune them.
        @Test("@longest on a { … } KLN closure (yield-identity hazard probe)")
        func longestOnKLNClosure() throws {
            withKnownIssue("cluster-attached @longest on KLN — Tier B + shared-cluster yield-identity") {
                let g = #"word - /[a-z]+/ . S = { @longest word } ."#
                let r = try parseOracleAmbiguity(grammar: g, message: "hello world foo")
                #expect(r.postMatch)
            }
        }
    }
}
