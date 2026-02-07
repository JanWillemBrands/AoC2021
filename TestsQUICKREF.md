# Test Quick Reference

## File Overview

| File | Purpose | Lines |
|------|---------|-------|
| `ParserGeneratorTests.swift` | Basic smoke tests | ~180 |
| `TortureSyntaxTests.swift` | Edge case tests (70+) | ~310 |
| `TestHelpers.swift` | Helper functions | ~70 |
| `TortureTestExpectations.md` | Expected behavior docs | ~150 |
| `README.md` | Comprehensive guide | ~175 |
| `SETUP.md` | Xcode setup steps | ~100 |
| `SUMMARY.md` | Complete overview | ~200 |

## Test Execution

```bash
# Verify setup
swift Tests/VerifyTestSetup.swift

# Run all tests
swift test

# Run specific category
swift test --filter TortureSyntaxTests.testRecursion

# In Xcode
⌘U (or click diamond icons)
```

## Test Categories & Counts

| Category | Rules | Test Count | Focus |
|----------|-------|------------|-------|
| Empty | S00-S07 | 7 | Empty constructs, epsilon |
| Basic | S10-S24 | 21 | Literals, sequences, options |
| Indirection | S30-S39 | 13 | Non-terminal references |
| Recursion | S40-S57 | 16 | Left/right/mutual recursion |
| Ambiguity | S60-S83 | 8 | Multiple parse trees |
| Sequences | S70-S83 | 10 | Specific patterns |
| Nested | S90-S95 | 11 | Complex nested structures |
| **TOTAL** | | **86** | |

## Adding a New Test

### 1. Add Grammar Rule
```ebnf
// In TortureSyntax.apus
S96 = "a" S96 "b" | "".
```

### 2. Add Test Case
```swift
// In TortureSyntaxTests.swift
TortureTestCase(
    rule: "S96",
    message: "aabb",
    shouldSucceed: true,
    category: .recursion,
    notes: "balanced a's and b's"
)
```

### 3. Document
```markdown
# In TortureTestExpectations.md
S96 | aabb | PASS | recursion | balanced parens pattern
```

## Common Test Patterns

### Test a Single Message
```swift
TortureTestCase(rule: "S11", message: "a", shouldSucceed: true, category: .basic)
```

### Test Multiple Messages for Same Rule
```swift
TortureTestCase(rule: "S11", message: "a", shouldSucceed: true, category: .basic),
TortureTestCase(rule: "S11", message: "b", shouldSucceed: false, category: .basic),
```

### Test Epsilon/Empty
```swift
TortureTestCase(rule: "S10", message: "", shouldSucceed: true, category: .basic)
```

## Key Grammar Rules to Know

### Empty Constructs (S00-S07)
- `S00 = .` - Empty sequence
- `S01 = |.` - Empty selection
- `S03 = [].` - Empty option
- `S04 = {}.` - Empty iteration

### Recursion (S40-S57)
- `S40 = S40 "a".` - Left recursion
- `S41 = "a" S41.` - Right recursion
- `S56 = ["a" S56 "a"].` - Even brackets
- `S57 = "a" S57 "a" | "a".` - Odd brackets

### Famous Ambiguous Grammars
- `S93 = "b" S93 | "a" S93 "c" | "".` - Γ3 (Capper)
- `S94 = "a" S94 | "a" S94 "c" | "".` - Γ5 (Capper)
- `S95 = "a" S95 "b" | "a" S95 "c" | "a".` - Afroozeh

## Test Results Interpretation

### Success Criteria
- `shouldSucceed: true` + parse succeeds = ✅ PASS
- `shouldSucceed: false` + parse fails = ✅ PASS
- `shouldSucceed: true` + parse fails = ❌ FAIL
- `shouldSucceed: false` + parse succeeds = ❌ FAIL

### Yield Analysis
```swift
let result = parseWithRule(rule, message: "test", terminals: terminals)
// result.success: Bool - did it parse?
// result.parseCount: Int - how many parse trees?
// result.yields: Set<Yield> - all yields/parse nodes
```

## Debugging Failed Tests

### 1. Check Grammar
```swift
// Is the rule defined correctly?
guard let rule = nonTerminals["S13"] else {
    XCTFail("Rule not found")
    return
}
```

### 2. Check Tokens
```swift
// What tokens were scanned?
initScanner(fromString: message, patterns: terminals)
for token in tokens {
    print("\(token.kind): '\(token.image)'")
}
```

### 3. Check Yields
```swift
// What did the parser produce?
let result = parseWithRule(rule, message: message, terminals: terminals)
for yield in result.yields {
    print(yield)
}
```

### 4. Enable Tracing
```swift
// In your code:
trace = true  // Enable debug output
parseMessage()
trace = false
```

## State Reset Checklist

Before each test, reset:
- [ ] `terminals = [:]`
- [ ] `nonTerminals = [:]`
- [ ] `messages = []`
- [ ] `crf = []`
- [ ] `tokens = []`
- [ ] `symbolTable = []`
- [ ] `yields = []`
- [ ] `remainder = []`

## Xcode Setup Checklist

- [ ] Create Unit Testing Bundle target
- [ ] Add all `Tests/*.swift` files to target
- [ ] Add all main `*.swift` files to target
- [ ] Set Swift version to 5+
- [ ] Press ⌘U to run tests
- [ ] Check Test Navigator (⌘6) for results

## Common XCTest Assertions

```swift
XCTAssertTrue(condition)
XCTAssertFalse(condition)
XCTAssertEqual(a, b)
XCTAssertNotEqual(a, b)
XCTAssertGreaterThan(a, b)
XCTAssertNil(optional)
XCTAssertNotNil(optional)
XCTFail("message")
```

## Performance Testing

```swift
func testPerformance() {
    measure {
        // Code to benchmark
        try? testParserGeneration(for: testCase)
    }
}
```

## Continuous Integration

```yaml
# .github/workflows/test.yml
- name: Run tests
  run: swift test --parallel
```

---

For complete documentation, see:
- `Tests/SUMMARY.md` - Complete overview
- `Tests/README.md` - Detailed guide
- `Tests/SETUP.md` - Setup instructions
