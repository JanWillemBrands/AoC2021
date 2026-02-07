# Test Documentation Index

## 📚 Documentation Files

### Getting Started
1. **[SUMMARY.md](SUMMARY.md)** - Start here! Complete overview of the test infrastructure
2. **[SETUP.md](SETUP.md)** - Step-by-step Xcode setup instructions
3. **[QUICKREF.md](QUICKREF.md)** - Quick reference card for daily use

### Deep Dive
4. **[README.md](README.md)** - Comprehensive testing guide
5. **[ARCHITECTURE.md](ARCHITECTURE.md)** - Visual diagrams and architecture
6. **[TortureTestExpectations.md](TortureTestExpectations.md)** - Expected behavior reference

### Tools
7. **[VerifyTestSetup.swift](VerifyTestSetup.swift)** - Verification script
8. **[RunTortureTest.swift](RunTortureTest.swift)** - Individual test runner

## 🎯 Which File Should I Read?

### "I'm new here, where do I start?"
→ **[SUMMARY.md](SUMMARY.md)** - Complete overview

### "How do I set up tests in Xcode?"
→ **[SETUP.md](SETUP.md)** - Setup instructions

### "I need quick answers while testing"
→ **[QUICKREF.md](QUICKREF.md)** - Quick reference

### "I want to understand the test architecture"
→ **[ARCHITECTURE.md](ARCHITECTURE.md)** - Diagrams and flow

### "How do I add a new test?"
→ **[README.md](README.md)** - See "Adding New Tests" section

### "What should test S42 do?"
→ **[TortureTestExpectations.md](TortureTestExpectations.md)** - Expected behaviors

### "Is my setup correct?"
→ Run **`swift Tests/VerifyTestSetup.swift`**

## 📂 Test File Overview

### Core Test Files
- **ParserGeneratorTests.swift** (~180 lines)
  - Basic smoke tests
  - Tests: apus.apus, apusWithAction.apus, apusAmbiguous.apus

- **TortureSyntaxTests.swift** (~310 lines)
  - 70+ edge case tests
  - 7 categories: empty, basic, indirection, recursion, ambiguity, sequences, nested

- **TestHelpers.swift** (~70 lines)
  - `parseWithRule()` - Main parsing helper
  - `addDescriptorsForAlternates()` - Descriptor setup
  - XCTestCase extensions

## 🚀 Quick Start Paths

### Path 1: Just Want to Run Tests
```bash
1. swift Tests/VerifyTestSetup.swift  # Check setup
2. See SETUP.md for Xcode configuration
3. Press ⌘U in Xcode
```

### Path 2: Understanding Before Running
```bash
1. Read SUMMARY.md (5 min overview)
2. Read ARCHITECTURE.md (visual understanding)
3. Follow SETUP.md
4. Use QUICKREF.md while working
```

### Path 3: Adding New Tests
```bash
1. Read "Adding New Tests" in README.md
2. Use QUICKREF.md for syntax
3. Check TortureTestExpectations.md for patterns
4. Test with: swift test --filter YourTest
```

## 📊 Test Statistics

- **Total Test Cases**: 86+
  - ParserGeneratorTests: 3 basic grammars
  - TortureSyntaxTests: 70+ edge cases
  - Extensible structure for more

- **Test Categories**: 7
  - Empty constructs
  - Basic constructs
  - Indirection
  - Recursion
  - Ambiguity
  - Sequences
  - Nested/complex

- **Grammar Files**: 4
  - apus.apus (meta-grammar)
  - apusWithAction.apus (with actions)
  - apusAmbiguous.apus (intentionally ambiguous)
  - TortureSyntax.apus (70+ test rules)

## 🔗 Related Files

### Grammar Files (in parent directory)
- `../apus.apus` - Base APUS grammar
- `../apusWithAction.apus` - Grammar with actions
- `../apusAmbiguous.apus` - Ambiguous grammar
- `../TortureSyntax.apus` - Torture test rules

### Source Files (in parent directory)
- `../Scanner.swift` - Tokenization
- `../GrammarParser.swift` - Grammar parsing
- `../GrammarNode.swift` - AST nodes
- `../ClusteredNonterminalParser.swift` - Message parsing
- `../Descriptor.swift` - Parser descriptors
- `../CallReturnForest.swift` - CRF/GSS structures
- `../BinarySubtreeRepresentation.swift` - Yields
- `../GenerateParser.swift` - Parser generation
- `../GenerateDiagrams.swift` - Diagram generation

## 💡 Tips

### For Daily Testing
Keep **QUICKREF.md** open - it has:
- Common commands
- Test patterns
- Debugging steps
- State reset checklist

### For Adding Tests
Use this workflow:
1. Add rule to TortureSyntax.apus
2. Add test case to TortureSyntaxTests.swift
3. Document in TortureTestExpectations.md
4. Run: `swift test --filter YourTest`

### For Debugging
1. Check QUICKREF.md "Debugging Failed Tests"
2. Enable tracing: `trace = true`
3. Print tokens: `print(tokens)`
4. Check yields: `print(yields)`

### For Regression Testing
1. Establish baseline: `swift test > baseline.txt`
2. Make changes
3. Compare: `swift test > new.txt; diff baseline.txt new.txt`
4. Update expectations if intentional changes

## 📞 Help & Support

**Can't find something?**
- Check this INDEX.md for pointers
- Use Xcode's search (⇧⌘F) across test files
- All documentation is in Tests/ directory

**Setup issues?**
- Run: `swift Tests/VerifyTestSetup.swift`
- Read: SETUP.md
- Check: Target membership in Xcode

**Test failures?**
- See: QUICKREF.md "Debugging Failed Tests"
- Check: TortureTestExpectations.md for expected behavior
- Enable: `trace = true` for debug output

## 🎓 Learning Path

**Beginner → Intermediate → Advanced**

1. **Beginner**: Read SUMMARY.md, follow SETUP.md, run tests
2. **Intermediate**: Read README.md, understand ARCHITECTURE.md, add simple test
3. **Advanced**: Read all docs, add complex tests, implement regression tracking

---

**Start here:** [SUMMARY.md](SUMMARY.md)

**Need help?** All documentation is in the `Tests/` directory!
