# Parser Oracle Notes

Date: 2026-04-24

## Scope

Working definition for this project:

- Oracle = lightweight prediction layer that prunes impossible parser continuations
- It should reduce useless descriptor expansion without changing correctness

## Candidate Signals

- FIRST/FOLLOW viability checks
- Scanner token class exclusion sets
- Call-return context feasibility
- SPPF/BSR history constraints

## Design Constraints

- Keep checks cheap on hot path
- Keep logic auditable and testable
- Prefer monotonic "can only prune" conditions

## Open Questions

- Which oracle checks are currently disabled in runtime code paths?
- Can we precompute more viability info in generator phase?
- What benchmark set should gate oracle changes?

---

Update: 2026-04-25

This note is now a legacy overview. Use these newer notes for current context:

- `wiki/notes/00_CONTEXT_MAP.md`
- `wiki/notes/trivia_oracle_decisions.md`
- `wiki/notes/swift_trivia_inventory.md`
- `wiki/notes/annotation_spec_trivia.md`
- `wiki/notes/schrodinger_frankenstein_boundary.md`

---

Update: 2026-09-09

Moved-start bracket extent is now handled in `Oracle.pruneUnproductive`. For bodies
containing an extent-annotated bracket (`@shortest` / `@longest` before `[ ]`, `{ }`,
`< >`, or `( )`), phase 1 enumerates complete body tilings, filters them by the
annotated bracket's consumed length, and marks only the surviving body steps reachable.
This fixes the synthetic `S = [ x ] @shortest [ x ] .` over input `x`, where the
annotated optional's start moves depending on whether the preceding optional consumed
the token.
