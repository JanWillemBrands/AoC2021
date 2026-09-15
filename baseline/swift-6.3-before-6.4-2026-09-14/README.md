# Swift 6.4 Migration Baseline

Captured: 2026-09-14 15:05 Europe/Rome

## Repository

- Git commit: `97d3a47e010d2134703792577e1f370e4a2e6bca`
- Worktree was dirty before/while capturing this baseline. `git status --short` reported:
  - `M AdventTests/SwiftSyntaxRejects.swift`
  - `M AdventTests/SwiftSyntaxTests.swift`
  - `M TestOutput/apus_output.swift`
  - `M TestOutput/apus_validation_test.swift`
  - `?? baseline/`

## Toolchain

- Swift: `Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)`
- Target: `arm64-apple-macosx27.0.0`
- Xcode: `27.0 (27A266a)`
- Project `swift-syntax` package requirement: `upToNextMajorVersion` from `603.0.1`

## Full Suite Baseline

Command:

```sh
tools/run_tests.sh
```

Saved files:

- `run_tests.log`: wrapper summary output
- `run_tests.full.log`: complete xcodebuild log copied from the wrapper's temp log

Summary:

- Reject failures: `0`
- Accept failures: `0`
- Residual ambiguity: `0`
- Trees differ: `0`
- Crashes: `0`
- Result: `PASS`

## Serial Pinned Baseline

Attempted command:

```sh
TEST_RUNNER_SWIFT_DETERMINISTIC_HASHING=1 xcodebuild test -project Advent.xcodeproj \
  -scheme Advent \
  -destination 'platform=macOS,arch=arm64' \
  -parallel-testing-enabled NO
```

Saved file:

- `xcodebuild-serial-pinned.log`

Result: not captured. The direct `xcodebuild` invocation failed during package resolution because this sandbox could not write SwiftPM/Xcode diagnostic files under `~/Library/Caches` / DerivedData. This is an environment permission failure, not a test failure.

