# Setting Up Tests in Xcode

## Quick Setup Guide

### Step 1: Create Test Target

1. In Xcode, go to **File → New → Target...**
2. Choose **Unit Testing Bundle** (under the "Test" section)
3. Name it: `AdventTests`
4. Click **Finish**

### Step 2: Add Test Files to Target

1. Select all files in the `Tests/` directory:
   - `ParserGeneratorTests.swift`
   - `TortureSyntaxTests.swift`
   - `TestHelpers.swift`

2. In the File Inspector (⌥⌘1), check the box for `AdventTests` under "Target Membership"

### Step 3: Configure Test Target

1. Select the `AdventTests` target in Project Settings
2. Go to **Build Settings**
3. Search for "Swift Language Version" and ensure it's set to Swift 5 or later

### Step 4: Link Source Files

The test target needs access to your main source files. You have two options:

#### Option A: Add Source Files to Test Target (Recommended)
1. Select each `.swift` file from your main source (not in Tests folder)
2. In File Inspector, check the `AdventTests` target membership
3. This includes files like:
   - Scanner.swift
   - GrammarParser.swift
   - GrammarNode.swift
   - ClusteredNonterminalParser.swift
   - CallReturnForest.swift
   - BinarySubtreeRepresentation.swift
   - Descriptor.swift
   - SymbolTable.swift
   - GenerateParser.swift
   - GenerateDiagrams.swift
   - OutputTools.swift

#### Option B: Use @testable import (If using frameworks)
If your main target is a framework:
```swift
@testable import Advent
```

### Step 5: Run Tests

- Press **⌘U** to run all tests
- Or click the diamond icon next to individual tests
- Or use Test Navigator (⌘6)

## Troubleshooting

### "Cannot find type X in scope"
→ Make sure the source file containing X is added to the test target (see Step 4)

### "Undefined symbol"
→ Check that all dependent files are included in the test target

### Tests don't appear
→ Make sure test files have the `AdventTests` target membership checked

### Build errors about missing imports
→ Ensure OrderedCollections is available (add to test target if needed)

## What Tests Do

### ParserGeneratorTests
- ✅ Smoke tests that parser generation works
- ✅ Tests all three `.apus` grammar files
- ✅ Verifies output files are created

### TortureSyntaxTests
- ✅ 70+ edge case tests
- ✅ Tests recursion, ambiguity, empty constructs
- ✅ Validates parser handles difficult grammars

## Running Specific Tests

```swift
// Run one test class
⌘U after clicking in that test class

// Run one test method
Click the diamond icon next to the method

// Run from command line
swift test
swift test --filter TortureSyntaxTests.testRecursion
```

## Adding More Tests

See `Tests/README.md` for detailed instructions on adding new test cases.
