See new posts

It seems that AI is moving from LLM's to symbolic representations.  Is that a trend that can be used to implement "AI-diven" compilers for programming languages ?

Thought for 33s

The trend is real, but it is not “LLMs out, symbols in.” It is neurosymbolic hybridization: keep neural models for perception, intent, and search, and put explicit structure (ASTs, IRs, grammars, logic, solvers) where correctness, composition, and verification matter. That is an unusually good fit for compilers. 

cacm.acm.org

Symbolic IR — a checkable intermediate object: AST, LLVM/MLIR dialect, Datalog facts, grammar tree, SMT formula.
Deterministic backend — typecheck, optimize, prove, or emit code. Fail loudly if the IR is invalid.

That is the same frontend / IR / backend split compiler engineers adopted decades ago, now applied to AI systems themselves. 

chelseaai.substack.com

There is also evidence that large networks already implement something like symbolic structure internally, which is why intervening on those implicit structures can change model behavior in targeted ways. That does not replace a compiler; it explains why hybrid systems work at all. 

arxiv.org

Yes — this is already a compiler research program“AI-driven compiler” can mean several different systems. All of them are being built.1. Natural language or specs compiled through a formal IRThe LLM never emits the final artifact directly. It emits a constrained intermediate form that a real compiler lowers.Examples:Query compilers that translate natural-language questions into a BNF grammar, parse an AST, then execute the tree symbolically. 

arxiv.org

Hardware generators that force the model to write a checkable circuit IR (not raw Verilog), then lower it with CIRCT. 

arxiv.org

Knowledge-rule compilers that turn English rules into a typed IR, then emit Prolog and Z3 and check consistency. 

sciltp.com

This is the most direct answer to your question: the compiler becomes the contract between fuzzy intent and exact code.2. Existing compilers with learned heuristicsThis is already in production LLVM. MLGO replaces hand-written inlining and register-allocation heuristics with trained models, while the rest of the pipeline stays classical and deterministic. Size reductions of a few percent on real codebases are enough to ship. 

research.google

Newer work goes further: agents that call clang’s frontend, middle-end, and backend as tools, and LLM-guided IR rewrites for symbolic execution. The compiler remains the source of truth; the model only chooses among legal moves. 

arxiv.org

3. Compiling reasoning into a reusable symbolic compilerReaComp is a clean instance of the trend you named. An LLM produces reasoning traces for program-synthesis tasks. Coding agents distill those traces into a standalone symbolic synthesizer over a constrained DSL. At test time there is no LLM: just the induced solver. On hard synthesis benchmarks the distilled solvers can beat test-time-scaled LLMs at zero inference cost, and they also combine with LLMs when needed. 

arxiv.org

That is “move from LLM to symbolic representation” in the literal sense: use the model once to build a compiler-like artifact, then run the artifact.4. Languages whose compiler is neurosymbolicScallop, NeST, COOL, and related systems are programming languages where the program itself mixes neural predicates with logic. The compiler’s job is to lower that mix into differentiable inference, Prolog-like evaluation, or ordinary code. Here the compiler is not just using AI; it is the implementation of hybrid computation. 

dl.acm.org

A related line compiles symbolic scientific programs into frozen differentiable modules that can sit inside a neural net with exact gradients. LLM in the loop can write the symbolic source; the compiler guarantees the module. 

arxiv.org

5. Compilers as tools for coding agents (and vice versa)Giving an LLM a real compiler as a tool sharply increases the rate of programs that even parse and link. Separate work uses LLMs to fuzz compilers and to patch LLVM middle-end bugs. So the loop runs both ways: AI helps build compilers; compilers discipline AI. 

arxiv.org

A 2026 survey already talks about a “new compiler stack” whose design philosophies are selector / translator / generator, and whose most promising path is hybrid systems rather than LLM-only compilation. 

link.springer.com

What this is good for, and what it is notGood fitIntent → verified program (DSLs, hardware, queries, policy rules, math).
Optimization search where the search space is discrete and checkable (inlining, instruction selection, rewrite sequences).
Distilling a general model into a cheap, auditable specialist compiler.
Making generated code fail closed: if the IR is ill-typed, you do not ship.

Still hardFull general-purpose compilers (GCC/LLVM-scale) are enormous stateful systems. Models still struggle with instruction-level IR reasoning (control flow, loops, dynamic execution). 

proceedings.mlr.press

Correctness does not come from the LLM. It comes from the grammar, type system, equivalence checker, or test suite sitting after it.
“Compile English to C++ as well as clang compiles C++” is not the current result. The winning systems narrow the target language or keep a verifier in the loop.

A practical architecture if you wanted to build oneA workable research or product shape today:Source language: natural language, a high-level spec, or a conventional language plus comments/intent.
Frontend: constrained decoding into a typed IR (JSON schema, MLIR dialect, grammar, or AST API). Do not accept free text as the program.
Middle: symbolic analyses and rewrites (classic compiler passes, SMT, Datalog, equality saturation). Optionally a small learned policy that only chooses among legal rewrites.
Backend: existing codegen (LLVM, CIRCT, a VM).
Oracle: tests, equivalence checking, or a reference interpreter. Feed counterexamples back to the frontend (CEGIS).

That is already how the stronger coding agents work in miniature: generate, compile, read the error, repair. The neurosymbolic move is to make the IR first-class instead of treating the compiler as an opaque lint tool.So the short answer: yes. The shift toward symbolic interfaces is not a detour from compilers; compilers are one of the few places that shift is already operational. The useful systems do not replace LLVM with a chatbot. They use the model to get into a well-typed IR, then let a compiler do what compilers already do well.

14 web pages

Explain CEGIS loop

Explore MLIR dialects

Tell me more about this:  "Separate work uses LLMs to fuzz compilers and to patch LLVM middle-end bugs."

Thought for 9s

Those two lines of work sit on opposite sides of the same loop: generate programs that break compilers, then repair the compiler itself. Both are now agent/LLM-shaped, and both still depend on classical compiler tooling for the verdict.Fuzzing: LLMs as generators of compiler testsClassic compiler fuzzers (Csmith, YARPGen) generate valid C from a grammar so that a crash or a wrong answer is the compiler’s fault. Early LLM fuzzers (Fuzz4All, WhiteFox) asked a model to write whole programs. That found front-end crashes, but the programs were often too simple, invalid, or expensive to produce at volume. The newer systems treat the LLM as a block factory or mutator factory, not as a one-shot program writer.LegoFuzz (OOPSLA 2025)LegoFuzz splits the campaign into two phases so the model is not in the inner loop. 

arxiv.org

Offline. Take real C functions. Ask an LLM to rewrite them into small, valid, feature-rich snippets (“blocks”) that exercise interesting language and optimizer features. Store the blocks. Cost is paid once.Online. Compose blocks into larger programs with ordinary code, no further LLM calls (~0.02 s per program). Compile the same program with GCC and LLVM at several -O levels and compare checksums of the outputs. A mismatch is a miscompilation; a crash is a crash. 

themoonlight.io

Results on current GCC/LLVM: 66 reported bugs (23 GCC, 43 LLVM). 58 confirmed as new; 56 already fixed. About 30 were miscompilations — silent wrong code — which prior LLM fuzzers in their comparison did not find. Some bugs had lived in released compilers for years (including pre-GCC-12 and pre-LLVM-18). Coverage rose versus testing the isolated functions: +12.5% lines in GCC, +2.9% in LLVM. Generation was 62–146× faster than Fuzz4All / WhiteFox because the model is not queried per test. 

arxiv.org

The interesting design choice is the same neurosymbolic pattern as before: the LLM only produces pieces; composition, compilation, and the oracle are symbolic and cheap.Code: github.com/cuhk-s3/LegoFuzzWhat came after LegoFuzzA cluster of 2025–2026 papers pushes the same idea further:FeatureFuzz extracts semantic features from historical bug reports with an LLM, interleaves several features, then instantiates a program. In 24 hours it reported 167 unique crashes (2.78× the next-best fuzzer they compared, including LegoFuzz). A 72-hour campaign produced 113 bugs in GCC/LLVM, 97 confirmed; 39 hit middle-end or back-end; 46 came from programs that actually compile. 

arxiv.org

Mut4All reads bug reports and synthesizes mutators (~$0.08 each with GPT-4o). Those mutators then drive a conventional fuzzer. 96 bugs reported across rustc/gccrs and GCC/Clang; 54 confirmed new. 

arxiv.org

IRFuzzer does not use an LLM as the generator; it mutates LLVM IR directly to hit backends. 78 confirmed new LLVM bugs, 57 fixed. It is the reminder that once you are below the frontend, a grammar/IR mutator can still beat a language model. 

computer.org

Italiano & Cummins (2025) use an LLM to generate and mutate programs, then differential-test code size (-Oz vs other levels, cross-compiler). 24 confirmed missed-optimization bugs, and the same recipe ports from C/C++ to Rust and Swift by changing the prompt and the compiler. 

arxiv.org

So “LLMs fuzz compilers” now means: mine language features or past bugs with a model, then run a high-throughput symbolic campaign (differential compilation + execution or Alive-style validation).Patching: agents that try to fix LLVM’s middle endFinding a reduced IR reproducer is the easy half. Changing InstCombine, LoopVectorize, or SLPVectorizer without breaking thousands of tests is the hard half. Generic SWE-agents that work on GitHub issues collapse here: bug reports are thin, the relevant state lives in SSA IR and pass pipelines, and a “green test” is not the same as a correct optimizer change.llvm-harness / llvm-autofixThis is the paper behind the second half of that sentence. Focus is LLVM middle-end bugs (optimizations on LLVM IR), not Clang’s C++ parser. 

arxiv.org

Three pieces:llvm-bench — 334 reproducible middle-end bugs at first publication, later grown (one writeup says 446). Each issue comes with reduced IR reproducers and a large regression-test net. Hot passes: LoopVectorize, SLPVectorizer, InstCombine. Split into easy / medium / hard and crash vs miscompile. A “live” slice keeps only last-year issues so models cannot have memorized the fix. 

researchgate.net

llvm-harness — agent-facing wrappers around the tools a compiler engineer actually uses: build LLVM, reduce and replay IR, dump pass pipelines, GDB at the failing pass, Alive2 translation validation for miscompiles, run the targeted regression suite. Plus packaged “skills” (LLVM domain knowledge).
llvm-autofix-mini — a small specialized agent: setup → inspect runtime/IR state at the failure → propose a patch → validate. It is deliberately not a giant general agent.

Numbers that matter:Generic mini-SWE-agent on these bugs is weak. Adding the harness improved pass rate by 62% (24.0% → 38.9% in one DeepSeek V3.2 table; miscompiles 14.5% → 31.9%). Hard bugs did not improve — the harness helps you see, not invent missing theory. 

arxiv.org

llvm-autofix-mini then beat the harness-enhanced generic agent by about 22%.
After human LLVM developers reviewed the patches, true fix rate of frontier models was still under 15% in the project’s own summary. The specialized mini-agent reached roughly 21% true fixes after review. Many “passed” patches were incomplete, too narrow, or broke conventions the test suite does not catch. 

github.com

A sibling agent, llvm-autoreview / Archer, reviews open and closed LLVM PRs and has flagged 50+ real bugs that way — useful, but that is review, not end-to-end repair.Repos: dtcxzyw/llvm-harness (also referenced as llvm-autofix) and cuhk-s3/Archer.PeepholeBench — even smaller, still hardPeepholeBench isolates missed InstCombine optimizations (21 issues + 19 merged PRs). Agents get only the pre-fix issue text. No agent matched human developers on both correctness and profitability. Typical failures: overfit to the one example in the bug report; forget hasOneUse; mishandle undef/poison; collide with an existing combine rule. Those are exactly the symbolic constraints a compiler pass is made of. 

arxiv.org

How the two sides connectA realistic pipeline today looks like this:text

LLM / feature mixer  →  C or LLVM IR test
        ↓
GCC vs Clang, several -O levels, execution checksum
        ↓
Alive2 / creduce  →  minimal IR reproducer
        ↓
llvm-harness agent  →  candidate patch in a middle-end pass
        ↓
regression tests + Alive2 + human review

I am building a Swift front-end to match Swift-Syntax, using a GLL style parser.  I have passed the ~3000 accept/reject test suite from swift-syntax.  My font-end now generates exactly the same AST as swift-syntax.  However, I am using GLL and the Swift grammar I have is ambiguous.  This is brought under control with Oracle annotations.  I want to be sure that the grammar I have is equivalnt to swift-syntax, which uses recursive descent with unconstrained lookahead.  I want to use a fuzzer to check the implementations.  Is Lego the way to go ?



LegoFuzz is built for C compilers, not parser-equivalence. I’ll check what actually works for Swift/swift-syntax and for differential parser fuzzing so the recommendation matches your setup.No. LegoFuzz is the wrong off-the-shelf tool. The *composition idea* is useful; the C-compiler campaign is not.

LegoFuzz exists to find **GCC/LLVM miscompiles**: generate valid C, compile at several `-O` levels, compare execution checksums. Your question is **parser-language and tree equivalence** between an oracle-GLL frontend and SwiftParser’s recursive-descent-plus-unbounded-lookahead. Different oracle, different language, different failure modes.

You also cannot *prove* the two grammars equivalent. Context-free equivalence is undecidable, and SwiftParser is not “the CFG of Swift” anyway: lookahead predicates, recovery, and tree-layout conventions sit outside the productions. Fuzzing is the right *method*; it will give evidence, not a proof.

## What you are actually testing

Three different claims get mixed together:

1. **Language equivalence** — same accept/reject set.
2. **Tree equivalence** — same SwiftSyntax AST (kinds, children, presence of missing/unexpected nodes).
3. **Disambiguation equivalence** — when your GLL grammar has several derivations, the oracle picks the same one lookahead would have committed to.

Your 3000 tests already cover (1) and (2) on a curated suite. The residual risk is almost all in (3), plus error-recovery and “almost valid” inputs. SwiftParser is also **error-tolerant**: it rarely rejects; it inserts missing/unexpected nodes and still builds a tree. “Accept/reject” therefore has to be defined as something like “no missing/unexpected/unknown nodes,” not “parser returned false.” That is how the Swift team compared the new Swift parser to the old C++ one.

## Why LegoFuzz-as-is will miss the interesting bugs

Lego-style *function stitching* exercises combinations of already-valid chunks. Swift parser bugs live in **local choice points**:

- `<` as generic argument list vs comparison
- trailing closures vs subsequent statements
- `if` / `guard` / `while` conditions vs expressions
- `/…/` regex vs division
- `@` attributes vs implicit member / availability
- `#` directives vs expressions
- pack/iteration syntax vs generics
- recovery after a missing `)`, `}`, or `>`

Those are not “glue two well-formed functions together.” They are token-level and production-level conflicts your oracles already exist to resolve. A fuzzer that never perturbs those sites will just reconfirm the test suite.

## What to build instead

A small **differential parser harness** is the whole product. Both sides consume a `String` and you compare a normalized artifact.

```text
input
  ├─ your GLL+oracle  →  SwiftSyntax tree  (or reject)
  └─ SwiftParser.parse →  SwiftSyntax tree
compare:
  - “valid parse?” (no missing/unexpected/unknown)
  - structure (kind + child shape), not source text
  - optionally trivia / diagnostic recovery
```

Normalize before compare: same node kinds, same presence of optional children, ignore identity and maybe trivia unless you claim trivia fidelity. `description` round-trip is a third property (SwiftParser’s own invariant: tree reprints the source). Use it, but do not treat reprint equality as tree equality.

Drive that harness from **four generators**, in this order. Cost goes up; unique findings go up.

### 1. Use SwiftParser’s own mutation first

swift-syntax already records, at each offset, which *other* tokens the RD parser considered (`SWIFTPARSER_ENABLE_ALTERNATE_TOKEN_INTROSPECTION`), then substitutes e.g. `class`↔`struct`. That is lookahead-aware mutation of *exactly* the choice points you care about. Run those mutants through your GLL parser. It is the highest-value hour of work you can do.

Also parse the self-parse corpus (all of swift-syntax / swift-format / compiler test `Parse/` files). Those are larger and nastier than the 3000 unit tests.

### 2. Generate from *your* grammar, two ways

This is the Lego idea, applied to a CFG instead of C functions.

- **Oracle on.** Sample derivations from the disambiguated grammar, print concrete syntax, parse with SwiftParser. Any reject or different tree is a false positive of your grammar/oracles (you accept a language SwiftParser does not, or you build a different tree).
- **Oracle off.** Enumerate or sample the GLL SPPF. Every remaining ambiguity is a place the RD parser has a hidden policy. Check that the oracle’s pick equals SwiftParser’s tree. This is the actual “is my disambiguation the same as unbounded lookahead?” test.

Keep expansion bounded (depth, repetition caps). Unbounded generation from a Swift-sized grammar explodes on `expr` and `type`.

Composition belongs here: generate **syntax fragments** (expr, type, pattern, stmt, decl, attribute) and nest them in templates, Lego-style. Do not compose at the file/function level only.

```swift
func f<T>(x: T) { _ = SOURCE }
// SOURCE ∈ { expr fragments }
let x: TYPE = 0
// TYPE ∈ { type fragments }
@ATTR struct S {}
```

That is the reusable part of LegoFuzz: offline fragment bank, online nesting, no LLM in the inner loop.

### 3. Generate *outside* the grammar

Pure generation from your grammar cannot find strings you reject that SwiftParser accepts (missing productions). You need a **super-language**:

- token-stream mutation of valid seeds (insert/delete/replace tokens, swap brackets, move `where` clauses, turn `>` into `>>`, inject newlines where lookahead matters);
- grammar mutation: clone a production, drop a terminal, add an extra alternative, then generate — Gmutator-style, to sit on the boundary of the language;
- byte/Unicode noise last, for recovery and lexer agreement, not for grammar equivalence.

Coverage guidance helps if you can instrument *both* parsers (GLL label/GSS edges on your side; SwiftParser function/edge coverage on theirs). Byte-level libFuzzer alone will spend its life in the lexer. Swift has `-sanitize=fuzzer`; PropertyTestingKit is the same idea inside Swift Testing. Use them as a *second* campaign, seeded with interesting parser inputs, not as the main generator.

### 4. Optional: LLM only as a fragment factory

If you want something Lego-like with an LLM, use it the way LegoFuzz does: **once**, offline, to invent odd but locally grammatical snippets (`some P & Q`, `each t`, `/foo/`, `#/regex/#`, `consuming get`, pack expansions). Then compose and mutate those snippets deterministically. Do not query a model per test. LLM Swift generators aimed at `swiftc` optimizations are solving a different problem and will not systematically hit lookahead conflicts.

## How to score a discrepancy

Classify every mismatch; do not treat all diffs as “grammar bugs.”

| Symptom | Likely cause |
|---|---|
| You accept, SwiftParser has missing/unexpected nodes | Oracle too loose, or extra production |
| SwiftParser valid tree, you reject | Missing production, or oracle too tight |
| Both valid, different tree shape | Disambiguation ≠ lookahead (the important class) |
| Same structure, different trivia / missing nodes on broken input | Recovery policy, not the core grammar |
| Both crash / timeout | Implementation bug, still worth keeping |

Keep a reduced input (token-level delta-debug) and the **list of GLL derivations plus which oracle fired**. That is what you will debug; a 200-line file is not.

## Practical target

A few days of (2)+(3) on top of (1) will tell you more than porting LegoFuzz. You will not get a certificate of equivalence. You will get a growing corpus of lookahead conflicts where GLL+oracle and RD+lookahead disagree — or, if that corpus stays empty after grammar-coverage generation plus alternate-token mutation plus fragment nesting, a much stronger empirical claim than the 3000 tests.

So: steal LegoFuzz’s **offline fragments / online compose** split. Do not steal its C pipeline, its execution oracle, or its assumption that “valid program” is the object of interest. Your object of interest is a **choice point in an ambiguous CFG**.
