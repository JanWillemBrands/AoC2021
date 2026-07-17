import Foundation

// The explicit-range NEW regex is NOT viable under Swift Regex (decomposing /
// variation-selector scalars are rejected as char-class range bounds, some fatally
// at match time). So the faithful NEW approach is a scalar-predicate scan — exactly
// what swift-syntax does (isValidIdentifierStartCodePoint / Continuation). This
// benchmark compares:
//   OLD: current \p{XID_*}/\p{So} regex via prefixMatch(of:)   (the scanner's method)
//   NEW: hand-written N1518 scalar-predicate scan
// verbatim ranges from SwiftParser/Lexer/UnicodeScalarExtensions.swift.

// ---- OLD regex (as the scanner compiles it) ----
let oldSrc = #"[\p{XID_Start}_\p{So}][\p{XID_Continue}\p{So}]*"#
let oldRE = try! Regex(oldSrc)

// ---- NEW scalar predicates (N1518) ----
@inline(__always) func isContinue(_ c: UInt32) -> Bool {
    if c < 0x80 { // ASCII fast path
        return (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A)
            || (c >= 0x30 && c <= 0x39) || c == 0x5F
    }
    return c == 0x00A8 || c == 0x00AA || c == 0x00AD || c == 0x00AF
        || (c >= 0x00B2 && c <= 0x00B5) || (c >= 0x00B7 && c <= 0x00BA)
        || (c >= 0x00BC && c <= 0x00BE) || (c >= 0x00C0 && c <= 0x00D6)
        || (c >= 0x00D8 && c <= 0x00F6) || (c >= 0x00F8 && c <= 0x00FF)
        || (c >= 0x0100 && c <= 0x167F) || (c >= 0x1681 && c <= 0x180D)
        || (c >= 0x180F && c <= 0x1FFF) || (c >= 0x200B && c <= 0x200D)
        || (c >= 0x202A && c <= 0x202E) || (c >= 0x203F && c <= 0x2040)
        || c == 0x2054 || (c >= 0x2060 && c <= 0x206F)
        || (c >= 0x2070 && c <= 0x218F) || (c >= 0x2460 && c <= 0x24FF)
        || (c >= 0x2776 && c <= 0x2793) || (c >= 0x2C00 && c <= 0x2DFF)
        || (c >= 0x2E80 && c <= 0x2FFF) || (c >= 0x3004 && c <= 0x3007)
        || (c >= 0x3021 && c <= 0x302F) || (c >= 0x3031 && c <= 0x303F)
        || (c >= 0x3040 && c <= 0xD7FF) || (c >= 0xF900 && c <= 0xFD3D)
        || (c >= 0xFD40 && c <= 0xFDCF) || (c >= 0xFDF0 && c <= 0xFE44)
        || (c >= 0xFE47 && c <= 0xFFF8) || (c >= 0x10000 && c <= 0x1FFFD)
        || (c >= 0x20000 && c <= 0x2FFFD) || (c >= 0x30000 && c <= 0x3FFFD)
        || (c >= 0x40000 && c <= 0x4FFFD) || (c >= 0x50000 && c <= 0x5FFFD)
        || (c >= 0x60000 && c <= 0x6FFFD) || (c >= 0x70000 && c <= 0x7FFFD)
        || (c >= 0x80000 && c <= 0x8FFFD) || (c >= 0x90000 && c <= 0x9FFFD)
        || (c >= 0xA0000 && c <= 0xAFFFD) || (c >= 0xB0000 && c <= 0xBFFFD)
        || (c >= 0xC0000 && c <= 0xCFFFD) || (c >= 0xD0000 && c <= 0xDFFFD)
        || (c >= 0xE0000 && c <= 0xEFFFD)
}
@inline(__always) func isStart(_ c: UInt32) -> Bool {
    if c < 0x80 {
        return (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A) || c == 0x5F
    }
    guard isContinue(c) else { return false }
    if (c >= 0x0300 && c <= 0x036F) || (c >= 0x1DC0 && c <= 0x1DFF)
        || (c >= 0x20D0 && c <= 0x20FF) || (c >= 0xFE20 && c <= 0xFE2F) { return false }
    return true
}

// scan an identifier from the start of a String's scalar view (as the scanner would),
// return matched scalar count (0 = no match)
@inline(__always) func matchIdentifier(_ s: String) -> Int {
    var it = s.unicodeScalars.makeIterator()
    guard let first = it.next(), isStart(first.value) else { return 0 }
    var n = 1
    while let sc = it.next(), isContinue(sc.value) { n += 1 }
    return n
}

// ---- corpus ----
var ids: [String] = []
for i in 0..<1500 {
    ids.append("identifierNumber\(i)")
    ids.append("x")
    ids.append("someLongerCamelCaseIdentifierName\(i % 50)")
    ids.append("_underscorePrefixed\(i)")
}
for _ in 0..<200 {
    ids.append(contentsOf: ["café","straße","résumé","naïve","Ωμέγα","переменная","変数名","🐶","变量","identifierX"])
}
print("corpus identifiers: \(ids.count)")

// correctness cross-check: both operate on the String; compare matched-scalar length.
var mismatch = 0
for s in ids {
    let o = s.prefixMatch(of: oldRE).map { s.unicodeScalars.distance(from: s.unicodeScalars.startIndex, to: $0.range.upperBound.samePosition(in: s.unicodeScalars)!) } ?? 0
    let n = matchIdentifier(s)
    if o != n { mismatch += 1; if mismatch <= 15 { print("  DIFF '\(s)' old=\(o) new=\(n)") } }
}
print("length mismatches: \(mismatch)")

let passes = 60
// Both paths take a `String` and produce a matched length — mirroring the scanner
// (regex.prefixMatch on the input String vs a scalar scan of the input String).
func benchOld() -> Double {
    var cs = 0; let t = clock()
    for _ in 0..<passes { for s in ids { if s.prefixMatch(of: oldRE) != nil { cs &+= 1 } } }
    if cs == Int.min { print() }
    return Double(clock() - t) / Double(CLOCKS_PER_SEC)
}
func benchNew() -> Double {
    var cs = 0; let t = clock()
    for _ in 0..<passes { for s in ids { cs &+= matchIdentifier(s) } }
    if cs == Int.min { print() }
    return Double(clock() - t) / Double(CLOCKS_PER_SEC)
}
_ = benchOld(); _ = benchNew() // warmup
var o = Double.greatestFiniteMagnitude, n = Double.greatestFiniteMagnitude
for _ in 0..<5 { o = min(o, benchOld()); n = min(n, benchNew()) }
print(String(format: "OLD regex   best: %.4f s  (%d passes x %d ids)", o, passes, ids.count))
print(String(format: "NEW scalar  best: %.4f s", n))
print(String(format: "speedup: %.1fx  (OLD/NEW)", o / n))
