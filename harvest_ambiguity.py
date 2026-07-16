#!/usr/bin/env python3
"""
Phase-1 ambiguity harvester (see `Ambiguity Workflow.md`).

Feeds a set of test snippets through the Advent binary with APUS_SIG_DUMP=1, which
emits one canonical signature per residual ambiguity, and clusters them into a
ranked table: `signature -> {count, tests, category-guess}`.

Signature = (ambiguous node, diagnostic kind, sorted competing-alternate bodies).
Fixing by SIGNATURE (not by test) is the efficiency multiplier — one fix clears
every test sharing the signature.

Usage:
    python3 harvest_ambiguity.py [labels_file]
      labels_file: newline-separated test labels to harvest (default: /tmp/amb.txt,
                   the failing `unambiguous` set from the last sweep). Pass "ALL" to
                   harvest every (non-disabled) snippet in the suites.

Writes: ambiguity_signatures.tsv  (count, node, kind, signature, example_labels)
Leaves the grammar's ^^^ block restored.
"""
import re, glob, sys, subprocess, collections, os

ROOT = "/Users/janwillem/Developer/Xcode/AoC2021"
GRAMMAR = f"{ROOT}/apus grammars/Swift.apus"
BIN = "/Users/janwillem/Library/Developer/Xcode/DerivedData/Advent-ctnlmtxiyxptaedefnxgsxptokfx/Build/Products/Release/Advent"

def load_snippets():
    """label -> (source, disabled) for every SwiftSnippet in the suites."""
    out = {}
    for f in glob.glob(f"{ROOT}/AdventTests/SwiftSyntax*.swift"):
        t = open(f).read()
        starts = [m.start() for m in re.finditer(r'SwiftSnippet\(', t)]
        for k, i in enumerate(starts):
            # Bound each snippet's segment at the NEXT SwiftSnippet( so the source
            # regex can't leak forward: a single-line `source: "…"` snippet would
            # otherwise match a LATER multiline `"""…"""` source, mis-associating it.
            end = starts[k + 1] if k + 1 < len(starts) else len(t)
            seg = t[i:end]
            lbl = re.search(r'label:\s*"([^"]+)"', seg)
            if not lbl: continue
            src = re.search(r'source:\s*#*"""(.*?)"""#*', seg, re.S) or \
                  re.search(r'source:\s*(#*)"((?:[^"\\]|\\.)*)"\1', seg)
            if not src: continue
            raw = src.group(1) if '"""' in src.group(0) else src.group(2)
            raw = raw.strip('\n')
            disabled = 'disabledReason:' in seg[:seg.find('),')+2] if '),' in seg else False
            out[lbl.group(1)] = (raw, disabled)
    return out

def unescape(s):
    return (s.replace('\\"', '"').replace("\\\\", "\\")
             .replace("\\u{feff}", "﻿").replace("\\t", "\t"))

def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else "/tmp/amb.txt"
    snips = load_snippets()
    if arg == "ALL":
        labels = [l for l, (_, d) in snips.items() if not d]
    else:
        labels = [l.strip() for l in open(arg) if l.strip()]
    labels = [l for l in labels if l in snips and not snips[l][1]]
    print(f"harvesting {len(labels)} snippets")

    # preserve ^^^ block
    g = open(GRAMMAR).read()
    idx = g.index("^^^"); head, tail = g[:idx], g[idx:]
    # write all snippets as ^^^ messages; message index (1-based) -> label
    ordered = labels
    block = "".join("^^^\n" + unescape(snips[l][0]) + "\n" for l in ordered)
    open(GRAMMAR, "w").write(head + block)
    try:
        env = dict(os.environ, APUS_SIG_DUMP="1")
        r = subprocess.run([BIN], capture_output=True, text=True, env=env)
    finally:
        open(GRAMMAR, "w").write(g)  # restore

    sig_tests = collections.defaultdict(set)
    for line in (r.stdout + r.stderr).splitlines():
        if not line.startswith("SIG\t"): continue
        _, mi, node, kind, sig = line.split("\t", 4)
        mi = int(mi)  # main.swift emits 0-based `enumerated()` index — NOT 1-based
        lbl = ordered[mi] if 0 <= mi < len(ordered) else f"?{mi}"
        sig_tests[(node, kind, sig)].add(lbl)

    rows = sorted(sig_tests.items(), key=lambda kv: -len(kv[1]))
    with open(f"{ROOT}/ambiguity_signatures.tsv", "w") as fh:
        fh.write("count\tnode\tkind\tsignature\texample_tests\n")
        for (node, kind, sig), tests in rows:
            ex = ",".join(sorted(tests)[:4])
            fh.write(f"{len(tests)}\t{node}\t{kind}\t{sig}\t{ex}\n")
    print(f"distinct signatures: {len(rows)}  (written to ambiguity_signatures.tsv)")
    print("\nTop 25 signatures by test-count:")
    for (node, kind, sig), tests in rows[:25]:
        print(f"  {len(tests):4d}  {node}  {kind}  {sig[:70]}")

if __name__ == "__main__":
    main()
