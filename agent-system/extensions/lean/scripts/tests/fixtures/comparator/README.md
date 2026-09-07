# Comparator test fixtures -- provenance

Fixtures for `test-lean-comparator-run.sh`, covering `lean-comparator-run.sh`'s verdict
classification and sandbox/guard routing. Most are vendored from upstream
`leanprover/comparator` (Apache-2.0); one is authored for this task because no upstream fixture
covers the case.

## Upstream source

- Repository: https://github.com/leanprover/comparator
- License: Apache-2.0 (see the repository's own `LICENSE` file)
- Commit vendored from: `2312244ac716564a61cc0bf4e107d9abf1757a61` (default branch `master`,
  last push 2026-08-30, as measured 2026-09-07)

## Vendored files (verbatim, with an added attribution header comment)

| File | Upstream path | License |
|------|----------------|---------|
| `fake-landrun.sh` | `scripts/fake-landrun.sh` | Apache-2.0 |
| `simple_match/Challenge.lean` | `tests/projects/simple_match/Challenge.lean` | Apache-2.0 |
| `simple_match/Solution.lean` | `tests/projects/simple_match/Solution.lean` | Apache-2.0 |
| `def_hole_axiom_issue/Challenge.lean` | `tests/projects/def_hole_axiom_issue/Challenge.lean` | Apache-2.0 |
| `def_hole_axiom_issue/Solution.lean` | `tests/projects/def_hole_axiom_issue/Solution.lean` | Apache-2.0 |

`simple_match/config.json`, `simple_match/test.json`, `def_hole_axiom_issue/config.json`, and
`def_hole_axiom_issue/test.json` are also vendored verbatim from the same upstream paths (JSON
has no comment syntax, so no inline attribution header is possible for these four files --
provenance is recorded here instead). Each `test.json`'s original `exit_code` field (upstream's
own oracle shape, `{"exit_code": N}`) is preserved; this repo additionally appends its own
`lean_comparator_run_verdict` field naming the verdict `lean-comparator-run.sh` itself is expected
to report, since this wrapper's verdict vocabulary and exit codes are not Comparator's own.

## What each fixture demonstrates

- **`simple_match`** -- a genuine matching Challenge/Solution pair (`comm` proved two different
  ways, `sorry` vs `grind`). Demonstrates the `verified` direction.
- **`def_hole_axiom_issue`** -- an adversarial Solution that hides `sorryAx` (an axiom outside
  `permitted_axioms`) inside a definition-hole body, laundered through a β-reduction so the
  dependent theorem's stored term never syntactically references the hole. Demonstrates
  `axiom_violation` reached TRANSITIVELY (via `Axioms.loop`'s full closure walk), not via a
  literal `axiom` declaration -- the case the existing `grep "^axiom "` heuristic already
  catches and is therefore not evidence of anything new. See the fixture's own Solution.lean
  comment (preserved verbatim from upstream) for the exact gaming mechanism.
- **`statement_weakened`** -- **authored for this task**, not vendored. No upstream
  `tests/projects/` fixture isolates a PURE same-kind statement weakening: `simple_mismatch`,
  `simple_axiom_issue`, and `simple_kind_mismatch` all conflate a theorem-vs-axiom KIND mismatch
  with the statement difference. This fixture keeps the declaration kind identical (`theorem` on
  both sides) and only adds a hypothesis (`h : n = m`) that strictly weakens the statement,
  isolating Comparator's `"Challenge and solution theorem statement do not match"` arm from the
  kind-mismatch code path entirely.
- **`fake-landrun.sh`** -- upstream's own development substitute for `landrun` (an
  argument-swallowing shim that execs its trailing command unsandboxed after discarding
  recognised landrun flags, printing a loud `WARNING: THIS IS NOT REAL LANDRUN!` line before
  exec-ing). Used as `COMPARATOR_LANDRUN` in a dev/CI environment lacking real `landrun`.

## Oracle format

Each fixture directory contains `Challenge.lean`, `Solution.lean`, `config.json`, and `test.json`
(`{"exit_code": N, "lean_comparator_run_verdict": "<verdict>"}`), following upstream's own
`runtests.lean` test-runner convention (see the design record's References section) so the
suite can be data-driven rather than one function per case.
