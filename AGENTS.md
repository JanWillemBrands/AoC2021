## Default Working Mode

- Use fast mode by default.
- Keep file reads minimal and targeted.
- Make only targeted edits for the requested task.
- Do not run full builds or test suites unless explicitly requested.
- If any command runs longer than 90 seconds, stop and replan with a lighter approach.

## Collaboration Preferences (Learned)

- Ask before exploring newly added directories or broad workspace areas (example: `grammars/`).
- When discussing grammar details, verify claims against the local reference grammar file before finalizing conclusions.
- If the user asks for design discussion only, do not modify code; produce a concrete, resumable design note instead.
- For regex performance work, preserve longest-token correctness first: alternation is first-successful-branch, not automatic longest-branch.
- For mixed ASCII/Unicode identifiers, prefer scanner-level ASCII fast paths; if regex alternation is used, guard the ASCII branch with a negative lookahead so it cannot steal shorter matches (e.g. before trailing Unicode-continue characters).
- For feature activation driven by grammar syntax (e.g. layout injection), distinguish declaration from use: terminal existence in `symbolToID` is not enough when the symbol can appear quoted in the meta-grammar.
- Prefer parser-level `usesX` flags when activation depends on unquoted grammar constructs actually used by a specific grammar.
- For broad replacement requests ("all source files, documentation, and grammars"), scan and verify the whole repository scope, not only files currently visible in the Xcode project navigator.
- After bulk replacements, run a full-repo verification grep and report any remaining out-of-scope matches explicitly.
- Treat pasted project structure as session context; do not require repeated full listings for follow-up edits unless scope actually changes.

## Execution Reliability (Thread Learnings)

- If a tool command is blocked, rejected, or interrupted, report it immediately and switch to a smaller fallback command.
- During long-running operations, provide brief "I'm alive" progress updates at least once per minute.
- Prefer short, narrowly scoped commands over large multi-file dumps to reduce interruption risk.
- For shell snippets intended for zsh paste/run, prefer quoted heredocs (`<<'EOF'`) and disable history expansion first (`set +H`) when needed.
- Avoid mixing structural reorganization work with feature/code changes in the same command sequence or commit batch.

## Repository Layout Rule

- Treat `Advent/` as the canonical project subtree for source, tests, grammars, docs, generated output, and research assets.
- Avoid maintaining duplicate active copies of the same content at both repository root and under `Advent/`.
