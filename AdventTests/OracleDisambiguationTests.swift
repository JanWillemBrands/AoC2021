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
//     All pragmas attach to an ALT node (an alternate) as a prefix — `@prefer`
//     via `isPreferred`, the others via `alt.disambiguation`, both parsed in
//     `sequence()`. Since a nonterminal AND every bracket own an alternate chain,
//     the Oracle reads these annotations off any chain uniformly
//     (`registerPrefer` + `registerAltDisambiguation`), so no pragma is special
//     about "top level". The legacy production-start form (`@longest X = …`) still
//     works via `nt.disambiguation`.
//
//     Tier A — `@prefer` inside a `( a | b )` selection group.
//     Tier B — `@longest`/`@shortest`/`@left`/`@right` attached to a cluster,
//     e.g. `( @left E "+" E | n )`, `< @longest word >`, `{ @longest word }`.
//     Both tiers are implemented; these tests assert them directly.
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
        // span. `@prefer` on the first alternate of the group keeps only the root
        // reading. The Oracle's registration walk now scans bracket alternate chains
        // (`registerPrefer` per bracket node), so the same `PreferRule` fires here.

        @Test("@prefer in ( a | b ) selection group — acceptance preserved, ambiguity removed")
        func preferInSelectionGroup() throws {
            let g = #"x - /x/ . S = "[" ( @prefer root comps? | comps ) "]" . root = x . comps = x ."#
            let r = try parseOracleAmbiguity(grammar: g, message: "[x]")
            #expect(r.postMatch, "@prefer in a selection group must not drop the valid parse")
            #expect(r.isUnambiguous, "@prefer in the group should collapse the root/component ambiguity")
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
        // Provisional syntax (now implemented): the pragma sits immediately after
        // the opening bracket, i.e. it is an alternate-prefix on the cluster's ALT
        // node — the same mechanism as `@prefer`. `sequence()` parses it onto
        // `alt.disambiguation`; the Oracle's `registerAltDisambiguation` reads it off
        // any alternate chain (nonterminal- or bracket-owned).

        // `@left` moved one level down: E's body is a single ( … ) cluster holding
        // both alternates, and `@left` annotates inside it. Mirrors the top-level
        // `leftAssocPrunes` on "1 + 2 + 3".
        @Test("@left on a ( … ) cluster prunes to left-associative")
        func leftOnCluster() throws {
            let g = #"n - /[0-9]+/ . S = E . E = ( @left E "+" E | n ) ."#
            let r = try parseOracleAmbiguity(grammar: g, message: "1 + 2 + 3")
            #expect(r.postMatch)
            #expect(r.isUnambiguous, "@left on the cluster should leave a single left-assoc tree")
        }

        // NOTE the asymmetry with `leftOnCluster`: we assert `pruned > 0`, not
        // `isUnambiguous`. `@right` (RightAssocRule, keep-min-pivot) under-prunes on
        // 3+ operands and leaves a residual ambiguity — verified to be PRE-EXISTING
        // and level-independent: the top-level `@right E = E "+" E | n` on "1 + 2 + 3"
        // gives the same `isUnambiguous: false` (probe, 2026-08-09). This test asserts
        // the cluster path reaches parity with the top-level path (the rule fires),
        // not that it fixes that separate Oracle limitation. Mirrors the top-level
        // `rightAssocPrunes` assertion (matches && pruned > 0).
        @Test("@right on a ( … ) cluster prunes right-associative (parity with top level)")
        func rightOnCluster() throws {
            let g = #"n - /[0-9]+/ . S = E . E = ( @right E "+" E | n ) ."#
            let r = try parseOracleAmbiguity(grammar: g, message: "1 + 2 + 3")
            #expect(r.postMatch)
            #expect(r.pruned > 0, "@right on the cluster should prune the non-right-assoc pivot(s)")
        }

        // `@longest` on a POS closure `< … >`. Faithful nested analogue of the
        // top-level `longestExtent` (which annotates the nonterminal wrapping the
        // POS); here the annotation moves onto the closure itself.
        @Test("@longest on a < … > POS closure")
        func longestOnPOSClosure() throws {
            let g = #"word - /[a-z]+/ . S = < @longest word > ."#
            let r = try parseOracleAmbiguity(grammar: g, message: "hello world foo")
            #expect(r.postMatch)
        }

        // `@longest` on a KLN closure `{ … }`. Distinct from the POS case because
        // KLN/POS re-entry reuses a SINGLE shared CRF cluster ("cluster index is a
        // node ref, not a position") — the yield-identity hazard called out in the
        // plan. This test is the tripwire for verifying repetition yields don't
        // conflate distinct occurrences before we prune them.
        @Test("@longest on a { … } KLN closure (yield-identity hazard probe)")
        func longestOnKLNClosure() throws {
            let g = #"word - /[a-z]+/ . S = { @longest word } ."#
            let r = try parseOracleAmbiguity(grammar: g, message: "hello world foo")
            #expect(r.postMatch)
        }
    }
}
