# Parser Generator Test Suite

This directory contains comprehensive tests for the APUS parser generator.

## Test Structure

### 1. ParserGeneratorTests.swift
Basic smoke tests that verify the parser generator can process grammar files and produce output.

**Tests:**
- ✅ Grammar files exist and are accessible
- ✅ Parser generation completes without errors
- ✅ Generated files are created and non-empty
- ✅ Generated code has basic structure

**Grammars Tested:**
- `apus.apus` - Base APUS grammar (meta-grammar)
- `apusWithAction.apus` - Grammar with embedded Swift actions
- `apusAmbiguous.apus` - Grammar with intentional ambiguities

### 2. TortureSyntaxTests.swift
Comprehensive edge case testing using the `TortureSyntax.apus` grammar.

**Test Categories:**

#### Empty Constructs (S00-S07)
Tests handling of empty/epsilon productions:
- Empty sequences, selections, groups
- Empty options, iterations
- Explicit end of input
- Undefined rules

#### Basic Constructs (S10-S24)
Tests fundamental grammar elements:
- Literals and regex patterns
- Sequences and selections
- Options `[...]`, iterations `{...}`, one-or-more `<...>`
- Groups `(...)`

#### Indirection (S30-S39)
Tests non-terminal references:
- Simple indirection
- Nullable indirection (options, iterations)
- Shared non-terminals
- Leading/trailing nullable non-terminals

#### Recursion (S40-S57)
Tests recursive grammar patterns:
- Left recursion (direct and indirect)
- Right recursion (direct and indirect)
- Mutual recursion (productive and non-productive)
- Optional recursion

#### Ambiguity (S60-S83)
Tests handling of ambiguous grammars:
- Ambiguous selections
- Ambiguous sequences (multiple parse trees)
- Nullable ambiguities
- Iteration ambiguities

#### Sequences (S70-S83)
Tests specific sequence patterns:
- One or more (`a {a}`)
- Two or more (`a <a>`)
- One or two (`a [a]`)
- Iterations with halt symbols

#### Nested and Complex (S90-S95)
Tests complex nested structures:
- Nested options and iterations
- Matched brackets (context-free languages)
- Highly ambiguous grammars from literature:
  - Γ3 and Γ5 from Capper's thesis
  - Ambiguous grammars from Afroozeh & Izmaylova

## Running Tests

### In Xcode
1. Open the project in Xcode
2. Press **⌘U** to run all tests
3. Or use Test Navigator (⌘6) to run specific test classes/methods

### Command Line
```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter ParserGeneratorTests
swift test --filter TortureSyntaxTests

# Run with verbose output
swift test --verbose
```

## Test Organization

```
Tests/
├── ParserGeneratorTests.swift       # Basic parser generation tests
├── TortureSyntaxTests.swift         # Edge case torture tests
├── TortureTestExpectations.md       # Expected behavior documentation
└── README.md                         # This file
```

## Adding New Tests

### For Basic Grammar Tests
Add a new `TestCase` to `ParserGeneratorTests.basicGrammarTests`:

```swift
TestCase("mygrammar", description: "My custom grammar"),
```

### For Torture Tests
1. Add grammar rules to `TortureSyntax.apus` (e.g., `S96 = ...`)
2. Add test cases to appropriate category in `TortureSyntaxTests.swift`:

```swift
TortureTestCase(
    rule: "S96",
    message: "test input",
    shouldSucceed: true,
    category: .basic,
    notes: "description of what this tests"
)
```

3. Document expected behavior in `TortureTestExpectations.md`

## Regression Testing

The test suite is designed for regression testing:

1. **Baseline**: Run tests to establish current behavior
2. **Changes**: Make changes to parser generator
3. **Compare**: Run tests again to detect regressions
4. **Document**: Update expectations if behavior intentionally changed

### Expected Test Results
See `TortureTestExpectations.md` for documented expected behavior of each torture test.

## Test Output

Tests create output in `TestOutput/` directory:
- Generated parser files (`*_output.swift`)
- Diagram files (`*_ART.gv`)

This directory is excluded from version control but preserved for inspection during debugging.

## Future Enhancements

Planned improvements to the test suite:

- [ ] Parse tree comparison for regression testing
- [ ] Performance benchmarks
- [ ] Ambiguity counting (number of parse trees)
- [ ] Error message validation
- [ ] Code coverage reporting
- [ ] Automated result tracking over time
- [ ] JSON output for CI/CD integration

## References

Torture test cases are based on:
- **Capper's thesis**: Standard torture tests for GLL parsers
- **Afroozeh & Izmaylova**: "Faster, Practical GLL Parsing" (2015)
- **Scott & Johnstone**: "GLL Parsing" (2010)

## Notes

- Tests use XCTest framework (built into Xcode)
- Global state is reset between tests to ensure isolation
- Some torture tests are intentionally ambiguous (multiple valid parses)
- Failed tests include detailed context (rule, message, expected vs actual)
