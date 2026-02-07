# Test Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ADVENT PARSER GENERATOR                       │
│                           TEST INFRASTRUCTURE                        │
└─────────────────────────────────────────────────────────────────────┘

                                    │
                    ┌───────────────┴────────────────┐
                    │                                │
                    ▼                                ▼
        ┌───────────────────────┐      ┌───────────────────────┐
        │ ParserGeneratorTests  │      │  TortureSyntaxTests   │
        │                       │      │                       │
        │  • Smoke Tests        │      │  • 70+ Edge Cases     │
        │  • File Generation    │      │  • 7 Categories       │
        │  • Basic Validation   │      │  • Regression Tests   │
        └───────────────────────┘      └───────────────────────┘
                    │                                │
                    └───────────────┬────────────────┘
                                    │
                                    ▼
                        ┌───────────────────────┐
                        │    TestHelpers.swift  │
                        │                       │
                        │  • parseWithRule()    │
                        │  • State management   │
                        │  • addDescriptors...  │
                        └───────────────────────┘
                                    │
                    ┌───────────────┴────────────────┐
                    │                                │
                    ▼                                ▼
        ┌───────────────────────┐      ┌───────────────────────┐
        │    Grammar Files      │      │   Parser Components   │
        │                       │      │                       │
        │  • apus.apus          │      │  • Scanner.swift      │
        │  • apusWithAction     │      │  • GrammarParser      │
        │  • apusAmbiguous      │      │  • GrammarNode        │
        │  • TortureSyntax      │      │  • MessageParser      │
        └───────────────────────┘      │  • CallReturnForest   │
                                       │  • Descriptor         │
                                       └───────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                         TEST EXECUTION FLOW                          │
└─────────────────────────────────────────────────────────────────────┘

1. setUp()
   └─> Clear global state (terminals, nonTerminals, crf, tokens, etc.)

2. Test Method (e.g., testRecursion())
   └─> runTortureTests(recursionTests, category: .recursion)
       │
       ├─> Load TortureSyntax.apus grammar
       │   └─> GrammarParser.parseGrammar()
       │
       └─> For each TortureTestCase:
           │
           ├─> Get specific rule (e.g., "S40")
           │   └─> nonTerminals["S40"]
           │
           ├─> attemptParse(rule, message)
           │   └─> parseWithRule(rule, message, terminals)
           │       │
           │       ├─> initScanner(message, terminals)
           │       │   └─> Tokenize input
           │       │
           │       ├─> resetMessageParser()
           │       │   └─> Clear parser state
           │       │
           │       ├─> Setup: currentSlot, currentCluster, crfRoot
           │       │
           │       ├─> addDescriptorsForAlternates()
           │       │   └─> Add initial descriptors
           │       │
           │       ├─> parseMessage()
           │       │   └─> Run GLL parser
           │       │
           │       └─> Check yields for successful parse
           │           └─> yield.i == 0 && yield.j == inputLength
           │
           └─> Compare: actual vs expected
               ├─> PASS: actual == expected ✅
               └─> FAIL: actual != expected ❌


┌─────────────────────────────────────────────────────────────────────┐
│                       TEST CATEGORIES TREE                           │
└─────────────────────────────────────────────────────────────────────┘

TortureSyntaxTests
├── Empty Constructs (S00-S07)
│   ├── Empty sequence, selection, group
│   ├── Empty option, iteration
│   └── Epsilon handling
│
├── Basic Constructs (S10-S24)
│   ├── Literals & regex
│   ├── Sequences & selections
│   └── Options, iterations, groups
│
├── Indirection (S30-S39)
│   ├── Simple references
│   ├── Nullable references
│   └── Shared non-terminals
│
├── Recursion (S40-S57)
│   ├── Left recursion
│   ├── Right recursion
│   ├── Mutual recursion
│   └── Bracket matching
│
├── Ambiguity (S60-S83)
│   ├── Ambiguous selections
│   ├── Nullable ambiguities
│   └── Multiple parse trees
│
├── Sequences (S70-S83)
│   ├── One-or-more patterns
│   ├── Two-or-more patterns
│   └── Iteration with halts
│
└── Nested & Complex (S90-S95)
    ├── Nested options/iterations
    ├── Capper's Γ3 & Γ5
    └── Afroozeh's ambiguous grammars


┌─────────────────────────────────────────────────────────────────────┐
│                        DATA FLOW DIAGRAM                             │
└─────────────────────────────────────────────────────────────────────┘

Grammar File          Test Case              Parser State
(TortureSyntax.apus)  (Swift Code)          (Global Variables)
     │                     │                       │
     │  1. Parse           │                       │
     ├────────────────────>│                       │
     │                     │                       │
     │                     │  2. Get Rule          │
     │                     ├──────────────────────>│
     │                     │      (S40: left recur)│
     │                     │                       │
     │                     │  3. Setup             │
     │                     ├──────────────────────>│
     │                     │      (reset state)    │
     │                     │                       │
     │                     │  4. Scan Message      │
     │                     ├──────────────────────>│
     │                     │      ("aaa")          │
     │                     │                       │
     │                     │  5. Parse             │
     │                     ├──────────────────────>│
     │                     │                       │
     │                     │  6. Check Yields  <───┤
     │                     │<──────────────────────┤
     │                     │      {yields}         │
     │                     │                       │
     │                     │  7. Assertion         │
     │                     │      ✅ or ❌         │
     ▼                     ▼                       ▼


┌─────────────────────────────────────────────────────────────────────┐
│                      FILE DEPENDENCIES                               │
└─────────────────────────────────────────────────────────────────────┘

Tests depend on:

ParserGeneratorTests.swift
├── Foundation
├── XCTest
├── GrammarParser.swift ──┐
├── GenerateParser.swift  │
├── GenerateDiagrams.swift│
└── Global variables      │
                          │
TortureSyntaxTests.swift  │
├── Foundation            │
├── XCTest                │
├── TestHelpers.swift     │
├── GrammarParser ────────┘
├── Scanner.swift ────────┐
├── GrammarNode.swift     │
├── ClusteredNonterm...   │
├── Descriptor.swift      │
├── CallReturnForest      │
├── BinarySubtree...      │
└── SymbolTable.swift     │
                          │
TestHelpers.swift         │
├── Foundation            │
├── XCTest                │
└── All parser files ─────┘


┌─────────────────────────────────────────────────────────────────────┐
│                   ADDING A NEW TEST WORKFLOW                         │
└─────────────────────────────────────────────────────────────────────┘

Step 1: Add Grammar Rule           Step 2: Add Test Case
┌─────────────────────────┐        ┌─────────────────────────┐
│ TortureSyntax.apus      │        │ TortureSyntaxTests.swift│
│                         │        │                         │
│ S96 = "a" S96 "b" | "". │   ┌───>│ TortureTestCase(        │
│                         │   │    │   rule: "S96",          │
└─────────────────────────┘   │    │   message: "aabb",      │
                              │    │   shouldSucceed: true,  │
                              │    │   category: .recursion, │
                              │    │   notes: "..."          │
                              │    │ )                       │
                              │    └─────────────────────────┘
                              │               │
Step 3: Document              │               │
┌─────────────────────────┐   │               │
│ TortureTestExpect...md  │<──┘               │
│                         │                   │
│ S96|aabb|PASS|recursion │                   │
└─────────────────────────┘                   │
                                              │
Step 4: Run Test <────────────────────────────┘
┌─────────────────────────┐
│ swift test --filter ... │
│                         │
│ ✅ S96 PASSED           │
└─────────────────────────┘
```
