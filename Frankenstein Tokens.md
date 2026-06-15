# Frankenstein Tokens: Splitting Longest-Match Tokens in GLL Parsing

> **Superseded (Jun 2026).** The Frankenstein mechanism (`~~~` annotation,
> `Grammar.frankensteinID`, the `≋` sentinel, partial-token prefix matching in
> `tokenMatch()`, `TokenPosition.charOffset`, and `GrammarNode.content`) has been
> removed from the codebase. Different-extent token alternatives (the
> `>>` vs `> >` motivating case) are now expected to be handled either by
> char-level operator assembly in the grammar itself or — once LCNP Phase B
> lands — by per-terminal `lex(at:, terminalID:)` queries which return all
> valid end positions directly.
>
> Kept for historical context. See `articles/Multi-Lex Adoption Design.md`
> §"Mechanisms that LCNP replaces" for the LCNP equivalent.

## Problem

Scanner use longest match. Scanner see `>>`, scanner make one token. Good for operators.

But sometimes `>>` not operator. Sometimes `>>` is two closing brackets:

```swift
Array<Dictionary<String, Int>>
                             ^^— two ">" not one ">>"
```

Scanner not know this. Scanner just see characters, pick longest match. Parser know — parser have grammar context. But by time parser run, token already fused. Token is monster. Frankenstein token.

Problem get worse: the two `>` close *different nesting levels*. Inner generic close first, outer generic close second. In GLL parser, these happen in different descriptors — different execution paths, possibly many thousands of descriptors apart.

## Why This Hard in GLL

GLL parser use integer position `cI` as index into token array. Position is key to everything:

- **Descriptor dedup**: `(grammar_slot, cluster, position)` — same triple means same work, skip it
- **CRF nodes**: `(nonterminal, position)` — shared call stacks keyed by position
- **BSR yields**: `(node, i, k, j)` — parse evidence stored as position spans

When Frankenstein split happen, parser match *part* of token. But position not advance to next token — only part consumed. Need new position that is:

1. **Unique** — different from the un-split position (otherwise descriptor dedup eat it)
2. **Ordered** — must sort between parent token and next token (derivation builder need left-to-right order)
3. **Small** — descriptor stored as Int32, hundreds of thousands of them, no make bigger

## Approaches Considered

### Mutable remainder state (first attempt)

Store `frankenstein: String?` on parser. When partial match happen, store remainder. Next match use remainder instead of token.

**Problem**: GLL is not sequential. Many descriptors explore many paths. Global mutable state get clobbered. Descriptor A set remainder, descriptor B overwrite it, descriptor A resume with wrong remainder. Bad.

### Character-position indexing (LCNP paper)

Elizabeth Scott paper "Multiple Lexicalisation" use character offset as position, not token index. Parser call `lex(charPosition, terminal)` on demand. Different split points naturally get different character positions.

**Problem**: Change every position in entire parser from token-index to char-index. Scanner become integrated into parser. Big change. Frankenstein is rare case — not want to burden hot path for rare case.

### Pre-split tokens in post-scan pass

Before parsing, find Frankenstein-eligible tokens, split them into sub-tokens. Keep original as Schrödinger dual. Parser see clean token array.

**Problem**: Not know *how* to split without grammar context. Need enumerate all possible prefix terminals for every candidate token. Laborious. Also, Schrödinger dual of multi-position original need `span` field — parser must advance by span, not by 1.

### Negative sub-positions

Use negative integers for sub-positions: `-801` means "token 8, sub-offset 1". Hot path (`cI >= 0`) unchanged. Frankenstein state stored in position-keyed dictionary.

**Problem**: Ordering break. `-801 < 8` in integer comparison, but semantically `-801` is *after* position 8. Derivation builder, diagram renderer need left-to-right ordering. Need custom comparator everywhere. Hacky.

### Stride approach with multiply/divide

Multiply all positions by stride (e.g., 4). Token 5 at position 20, sub-positions at 21, 22, 23. Ordering preserved.

**Problem**: Every `tokens[cI]` become `tokens[cI / STRIDE]`. Every `cI += 1` become `cI += STRIDE`. Invasive. Also descriptor use Int32 — multiplying positions by stride reduce max token count.

## Chosen Approach: Bit-Packed Sub-Indexing

Pack token index and sub-index into single integer using bit shift:

```
Int32 layout:
┌─────────────────────────────┬────┐
│  token index  (28 bits)     │sub │
│  max ~268 million tokens    │ 4b │  max 15 sub-positions
└─────────────────────────────┴────┘
```

```swift
let SHIFT = 4
let MASK  = 0xF

tokens[cI >> SHIFT]      // get token from packed position
cI & MASK                // get sub-index (0 = normal)
cI & MASK != 0           // is Frankenstein? one AND + compare
```

### Why This Good

**Ordering preserved.** Token 5 sub 0 = `80`. Token 5 sub 1 = `81`. Token 6 sub 0 = `96`. Natural integer comparison give correct left-to-right order. No custom comparator needed.

**Descriptor stay 16 bytes.** Packed position fit in Int32. No struct change.

**Hot path cost: one shift.** `tokens[cI >> SHIFT]` instead of `tokens[cI]`. CPU not even notice.

**No remainder dictionary.** Remainder computed on the fly from token image and sub-index:

```swift
let image = tokens[cI >> SHIFT].stripped
let remainder = image.dropFirst(cI & MASK)
```

**Frankenstein check is one bit-mask.** `cI & MASK != 0` — branch predictor always predict "not taken" on hot path.

### How Token Match Work

```swift
func tokenMatch() -> Int? {   // return next position, or nil
    let tokenIdx = cI >> SHIFT
    let subIdx   = cI & MASK

    if subIdx != 0 {
        // RARE: Frankenstein sub-position — match against remainder
        let image = tokens[tokenIdx].stripped
        let remainder = image.dropFirst(subIdx)
        if remainder.hasPrefix(cL.name) {
            let newSub = subIdx + cL.name.count
            if newSub >= image.count {
                return (tokenIdx + 1) << SHIFT   // token fully consumed
            }
            return tokenIdx << SHIFT | newSub    // more remainder
        }
        return nil
    }

    // FAST PATH: exact match + Schrödinger duals (unchanged logic)
    var current = tokens[tokenIdx]
    while true {
        if cL.nameID == current.kindID {
            return (tokenIdx + 1) << SHIFT
        }
        guard let next = current.dual else { break }
        current = next
    }

    // RARE: Frankenstein prefix split
    if cL.frankensteinMatchAllowed {
        let image = tokens[tokenIdx].stripped
        if image.hasPrefix(cL.name) && image.count > cL.name.count {
            return tokenIdx << SHIFT | cL.name.count
        }
    }
    return nil
}
```

### What Change in Parser

| What | Before | After |
|------|--------|-------|
| Token access | `tokens[cI]` | `tokens[cI >> SHIFT]` |
| Normal advance | `cI += 1` | `cI = (cI >> SHIFT + 1) << SHIFT` |
| Terminal match | `if tokenMatch() { cI += 1 }` | `if let next = tokenMatch() { cI = next }` |
| Yield | `addYield(j: cI + 1)` | `addYield(j: next)` |
| testSelect | `tokens[cI]` | Guard: if sub-index != 0, conservative true |
| followCheck | `tokens[cI]` | Same guard |
| Descriptor struct | Int32 | Int32 (unchanged) |
| Derivation builder | `tokens[pos]` | `tokens[pos >> SHIFT]`, ordering works natively |

### What Not Change

- Descriptor size (16 bytes)
- CRF structure
- BSR/yield storage
- Grammar analysis (first/follow sets)
- Scanner
- 99.9% of parse executions (sub-index always 0)

## Relation to Prior Work

Scott's LCNP ("Multiple Lexicalisation", SLE 2019) solve the general multi-lexicalisation problem by indexing positions by character offset and calling lexer on demand. Our approach is a specialization: keep token-level indexing for the common case, use sub-token offsets only when the scanner's longest-match produced a composite token that the grammar needs split. The bit-packing gives us LCNP-style position granularity without LCNP's overhead.

Aycock & Horspool's "Schrödinger's Token" (2001) handle the case where the same lexeme matches multiple token types (e.g., `int` as keyword vs identifier). Our Schrödinger implementation already handles this. Frankenstein is the orthogonal problem: a single token that must be *split* across multiple grammar positions, not just *reclassified*.

## Summary

Scanner make monster. Parser need to cut monster into pieces. Pieces span different nonterminals, different descriptors, different execution paths. Position encoding must keep pieces distinct, ordered, and compact. Bit-packing in Int32 do all three. Hot path not care. Monster only appear when grammar say so. Everybody happy.

## Annotation Update (May 2026)

- Frankenstein literal annotation is now `~~~`.
- Previous marker `=>>` was replaced across source, grammars, tests, and docs.
- Semantics are unchanged: annotation still means "allow prefix split of a longer scanned token at this literal site."
