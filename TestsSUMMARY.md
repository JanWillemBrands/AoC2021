# Advent Parser Generator - Complete Test Infrastructure

## 🎯 What's Been Created

A comprehensive test infrastructure for your APUS parser generator with:

- ✅ **70+ torture test cases** for edge cases and regression testing
- ✅ **Organized test categories** (empty, basic, recursion, ambiguity, etc.)
- ✅ **Extensible structure** - easy to add new tests
- ✅ **Documentation** - expectations, setup guides, and README files
- ✅ **Helper functions** - simplify test writing

## 📁 File Structure

```
/repo/
├── Tests/
│   ├── ParserGeneratorTests.swift         # Basic smoke tests
│   ├── TortureSyntaxTests.swift          # Edge case torture tests (70+ cases)
│   ├── TestHelpers.swift                  # Helper functions for parsing
│   ├── README.md                          # Test documentation
│   ├── SETUP.md                           # Xcode setup instructions
│   ├── TortureTestExpectations.md        # Expected behavior reference
│   ├── VerifyTestSetup.swift             # Setup verification script
│   └── RunTortureTest.swift              # Individual test runner (placeholder)
│
├── Grammar Files (Updated):
│   ├── apus.apus                          # Base grammar
│   ├── apusWithAction.apus               # With actions (updated)
│   ├── apusAmbiguous.apus                # Ambiguous (updated with correct grammar)
│   └── TortureSyntax.apus                # Torture tests (updated terminal definitions)
│
└── Package.swift                          # Swift Package config (optional)
```

## 🚀 Quick Start

### 1. Verify Setup
```bash
cd /path/to/your/project
swift Tests/VerifyTestSetup.swift
```

### 2. Set Up in Xcode
Follow the instructions in `Tests/SETUP.md`:
- Create Unit Testing Bundle target
- Add test files to target
- Add source files to target
- Press ⌘U to run tests

### 3. Run Tests
```bash
# All tests
swift test

# Specific suite
swift test --filter TortureSyntaxTests

# In Xcode
⌘U
```

## 📊 Test Categories

### ParserGeneratorTests (Basic Smoke Tests)
- Grammar files exist and are accessible
- Parser generation completes without errors
- Generated files are created and non-empty

**Tested Grammars:**
- `apus.apus` - Meta-grammar for APUS
- `apusWithAction.apus` - Grammar with embedded Swift actions
- `apusAmbiguous.apus` - Intentionally ambiguous grammar

### TortureSyntaxTests (Edge Cases - 70+ Tests)

#### 1. Empty Constructs (S00-S07)
- Empty sequences, selections, groups
- Empty options, iterations
- Undefined references

#### 2. Basic Constructs (S10-S24)
- Literals and regex
- Sequences and selections
- Options `[...]`, iterations `{...}`, one-or-more `<...>`

#### 3. Indirection (S30-S39)
- Simple and nullable indirection
- Shared non-terminals
- Leading/trailing nullable references

#### 4. Recursion (S40-S57)
- Left recursion (direct and indirect)
- Right recursion (direct and indirect)
- Mutual recursion
- Even/odd bracket matching

#### 5. Ambiguity (S60-S83)
- Ambiguous selections
- Multiple parse trees
- Nullable ambiguities
- Iteration ambiguities

#### 6. Sequences (S70-S83)
- One or more patterns
- Two or more patterns
- Iteration with halt symbols

#### 7. Nested & Complex (S90-S95)
- Nested options and iterations
- Context-free languages (matched brackets)
- Highly ambiguous grammars:
  - Γ3 from Capper's thesis
  - Γ5 from Capper's thesis
  - Afroozeh & Izmaylova examples

## 🔧 How to Add New Tests

### For Basic Grammar Tests

In `ParserGeneratorTests.swift`:
```swift
static let basicGrammarTests: [TestCase] = [
    // ... existing tests ...
    TestCase("mygrammar", description: "My new grammar"),
]
```

### For Torture Tests

1. **Add rule to `TortureSyntax.apus`:**
```
S96 = "a" S96 "b" | "".    // my new test
```

2. **Add test case to `TortureSyntaxTests.swift`:**
```swift
static let myNewTests: [TortureTestCase] = [
    TortureTestCase(
        rule: "S96",
        message: "aabb",
        shouldSucceed: true,
        category: .recursion,
        notes: "nested a's and b's"
    ),
]
```

3. **Add to `allTests` array:**
```swift
static let allTests: [TortureTestCase] = 
    emptyTests + basicTests + /* ... */ + myNewTests
```

4. **Create test method:**
```swift
func testMyNewCategory() throws {
    try runTortureTests(Self.myNewTests, category: .recursion)
}
```

5. **Document in `TortureTestExpectations.md`:**
```markdown
## My New Category
S96 | aabb | PASS | recursion | nested a's and b's
```

## 📈 Regression Testing Workflow

1. **Establish Baseline:**
   ```bash
   swift test > baseline_results.txt
   ```

2. **Make Changes:**
   - Modify parser generator
   - Update grammar handling
   - Fix bugs

3. **Run Tests Again:**
   ```bash
   swift test > new_results.txt
   diff baseline_results.txt new_results.txt
   ```

4. **Analyze Differences:**
   - Expected changes? Update expectations
   - Unexpected failures? Fix the bug
   - New passes? Great!

5. **Update Documentation:**
   - Update `TortureTestExpectations.md` if behavior changed intentionally

## 🎓 Test Implementation Details

### Key Functions

**`parseWithRule()`** (in TestHelpers.swift)
- Parses a message with a specific grammar rule
- Returns success status, parse count, and yields
- Handles state reset and cleanup

**`attemptParse()`** (in TortureSyntaxTests.swift)
- Simplified wrapper around `parseWithRule()`
- Returns boolean success/failure
- Used by all torture tests

**`runTortureTests()`** (in TortureSyntaxTests.swift)
- Executes a category of torture tests
- Tracks pass/fail counts
- Provides detailed failure messages

### Global State Management

Tests carefully manage global state:
```swift
override func setUp() {
    super.setUp()
    terminals = [:]
    nonTerminals = [:]
    messages = []
    crf = []
    tokens = []
    symbolTable = []
    yields = []
}
```

## 📚 References

Test cases based on:
- **Capper's thesis**: Standard GLL torture tests
- **Afroozeh & Izmaylova**: "Faster, Practical GLL Parsing" (2015)
- **Scott & Johnstone**: "GLL Parsing" (2010)

## ✨ Future Enhancements

Planned improvements:
- [ ] Parse tree comparison for exact output validation
- [ ] Performance benchmarking
- [ ] Ambiguity counting (number of valid parse trees)
- [ ] Error message validation
- [ ] Code coverage reporting
- [ ] Automated result tracking over time
- [ ] CI/CD integration with JSON output
- [ ] Visual parse tree diff tool

## 🆘 Troubleshooting

### "Cannot find X in scope"
→ Add the source file containing X to your test target

### "Undefined symbol: parseMessage"
→ Add `ClusteredNonterminalParser.swift` to test target

### "Undefined symbol: initScanner"
→ Add `Scanner.swift` to test target

### Tests don't run
→ Check target membership for all test files

### All tests pass but shouldn't
→ Verify `attemptParse()` is properly implemented

## 📞 Support

See detailed documentation in:
- `Tests/README.md` - Comprehensive test documentation
- `Tests/SETUP.md` - Xcode setup instructions
- `Tests/TortureTestExpectations.md` - Expected behavior reference

---

**Ready to test!** 🚀

Run `swift Tests/VerifyTestSetup.swift` to check your setup, then follow `Tests/SETUP.md` to configure Xcode.
