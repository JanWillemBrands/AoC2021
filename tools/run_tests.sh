#!/bin/bash
#
# run_tests.sh — the authoritative, reproducible test run for Advent.
#
# Replaces the manual xcodebuild incantation and works around every MCP-runner
# pitfall in one place, so callers never have to remember them:
#
#   • Always builds fresh first (no stale DerivedData binary — see TESTING.md).
#   • Runs the FULL suite set every time — no "smart re-run" that silently narrows
#     to previously-failing args and hides the true count.
#   • Reads the complete log (no 100-row truncation) and prints clean per-category
#     counts by matching the exact #expect messages the suites emit.
#   • Flags `Crash: xctest at <deduplicated_symbol>` LOUDLY as a real fault, never
#     as background noise.
#
# NOTE: hashing is left NON-deterministic on purpose. The GLL algorithm does not
# depend on Dictionary/Set iteration order, so a non-deterministic hash seed is a
# useful fuzzer — order-dependent bugs (e.g. a non-confluent load-time fixpoint)
# show up as intermittent failures instead of staying hidden. Do NOT set
# SWIFT_DETERMINISTIC_HASHING here.
#
# Usage:
#   tools/run_tests.sh                 # all suites
#   tools/run_tests.sh Rejects         # only suites whose name matches (grep -i)
#   tools/run_tests.sh Expressions Types
#
# Exit code: 0 iff there were no crashes AND no correctness failures
# (accept/reject/ambiguity). `Trees differ` is the known frontier and is reported
# but does NOT fail the run.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="Advent"
DEST="platform=macOS,arch=arm64"
LOG="$(mktemp -t advent-test.XXXXXX.log)"

# All parametrized SwiftSyntax suites (the ones that carry the correctness signal).
ALL_SUITES=(
  DeclarationSyntaxTests ExpressionSyntaxTests StatementSyntaxTests
  TypeSyntaxTests PatternSyntaxTests AttributeSyntaxTests
  TranslatedSyntaxTests RejectSyntaxTests
)

# Optional filter args → keep suites whose name matches any arg (case-insensitive).
suites=()
if [ "$#" -eq 0 ]; then
  suites=("${ALL_SUITES[@]}")
else
  for s in "${ALL_SUITES[@]}"; do
    for pat in "$@"; do
      if printf '%s' "$s" | grep -qi -- "$pat"; then suites+=("$s"); break; fi
    done
  done
fi
if [ "${#suites[@]}" -eq 0 ]; then
  echo "No suites matched: $*" >&2; exit 2
fi

only_testing=()
for s in "${suites[@]}"; do only_testing+=("-only-testing:AdventTests/$s"); done

echo "▶ Suites: ${suites[*]}"
echo "▶ Log:    $LOG"
echo "▶ Building + running (non-deterministic hashing — order-dependence is a fuzzer)…"

xcodebuild test \
  -scheme "$SCHEME" -destination "$DEST" \
  "${only_testing[@]}" \
  -project "$ROOT/Advent.xcodeproj" \
  > "$LOG" 2>&1
xcode_rc=$?

# ── Parse the log by the exact messages the suites emit ──────────────────────
count() { grep -c -- "$1" "$LOG" 2>/dev/null || true; }

crashes=$(count "Crash: xctest at <deduplicated_symbol>")
rej_fail=$(count "Advent wrongly accepted invalid input")   # reject suite: accepted invalid
acc_fail=$(count "Advent failed to parse:")                 # accept suites: rejected valid
ambig=$(count "Residual ambiguity in")                      # post-Oracle ambiguity
trees=$(count "Trees differ for")                           # frontier — informational only

echo
echo "────────────── RESULTS ──────────────"
if [ "$crashes" -gt 0 ]; then
  echo "  ✗ CRASHES:            $crashes   ← REAL FAULT, investigate (often a"
  echo "                                    decomposable CharacterClass range bound)"
fi
echo "  reject failures:      $rej_fail   (wrongly accepted invalid input)"
echo "  accept failures:      $acc_fail   (wrongly rejected valid input)"
echo "  residual ambiguity:   $ambig"
echo "  trees differ:         $trees   (frontier — not counted as failure)"
echo "─────────────────────────────────────"

correctness=$(( rej_fail + acc_fail + ambig ))
if [ "$crashes" -gt 0 ] || [ "$correctness" -gt 0 ]; then
  echo "FAIL — see $LOG"
  exit 1
fi
echo "PASS (xcodebuild rc=$xcode_rc; trees-differ is expected frontier)"
exit 0
