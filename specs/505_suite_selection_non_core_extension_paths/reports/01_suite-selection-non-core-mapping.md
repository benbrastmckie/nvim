# Research Report: Task #505

**Task**: 505 - Suite selection fails to resolve a covering suite for non-core extension source paths
**Started**: 2026-11-06T00:00:00Z
**Completed**: 2026-11-06T00:30:00Z
**Effort**: small-medium (one library, one test suite; no new data files)
**Dependencies**: None (ordering-only note with `plan_format_tier_justification_fixes`, no file overlap, no edge filed)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`, `agent-system/extensions/core/scripts/tests/run-all.sh`, `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh`, `agent-system/extensions/core/scripts/tests/suite-classification.data`, `agent-system/extensions/core/context/standards/shell-script-testing.md`, `agent-system/extensions/core/context/formats/plan-format.md`
- Direct measurement of the 9 extension `scripts/`+`tests/` trees in the source store
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The root cause is structural, not a logic bug in any one stratum: `suite-selection-lib.sh`
  derives its scripts/tests roots once, from **its own file location** (two directories up),
  which is always `agent-system/extensions/core/scripts` in the source store. Every mapping
  stratum (self-identity, strict basename pairing, grep reference lookup) is then evaluated only
  against that one tree, regardless of which extension the *touched path argument* actually
  names.
- A touched path under `agent-system/extensions/<non-core-ext>/scripts/**` therefore cannot be
  found by stratum (a) (its paired suite lives under a different extension's `scripts/tests/`,
  never scanned) and usually cannot be found by stratum (b) either (core's own suites rarely
  reference a non-core basename). The result is a false `__FULL_SWEEP__` escalation for a path
  that does have a real, named, cheap covering suite — exactly the task 385 incident.
- The fix is a **per-touched-path extension resolution**, not a cross-extension search: detect
  whether the touched path argument itself contains an `agent-system/extensions/<ext>/scripts/`
  segment, and if so, resolve that ONE call's strata against `<ext>`'s own `scripts/`+`tests/`
  tree instead of the library's own (core) tree. A path with no such segment (every existing core
  path, and every deployed-mode path, which never contains an `extensions/<ext>/` segment at all)
  falls through to exactly the tree already computed today — so the change is additive by
  construction, not a parallel/forked code path.
- Re-measuring the header's carried "0 of 19 non-core suites match the deployed-vs-source
  hazard" figure directly against the corpus shows it does not hold: 5 of 25 real non-core
  suites carry a `$REPO_ROOT/.claude` or `/.claude/` reference. This figure was almost certainly
  itself an artifact of the same core-tree-only lookup — `suite_selection_classify()` cannot
  locate a non-core suite file from the source store either, and silently returns its
  file-not-found fallback (`source-only`) for every one of them, which is indistinguishable from
  a genuine absence of the hazard without this fix. Recommendation: extend classification
  alongside selection (reuse one shared, broadened suite-file lookup for both), and re-derive the
  figure fresh post-fix rather than carry the frozen number forward again.

## Context & Scope

Scope: `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` (the touched-path ->
suite mapping library) and `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh`
(its regression suite) — exactly the two files this task's territory declares. `run-all.sh`
itself, `suite-classification.data`/`suite-cost-hints.txt` (the declarative `--class`/`--tag`/
`--cost-class` axis), and the plan-format Tier Justification convention that calls this library
are read for context only; none are in scope to edit.

The ask, restated precisely from the dispatch: (1) extend the mapping so a non-core touched path
resolves to its own extension's paired suite, with deployed-mode behavior held exactly as it is
today; (2) rule explicitly on whether the `source-only`/`source-first`/`deployed-first`
classification signal should extend to non-core suites too, re-measuring the figure the current
header note rests on; (3) keep `__FULL_SWEEP__` as the correct answer for a genuinely uncovered
path — the defect is a false escalation for a path that DOES have a covering suite, never the
sentinel mechanism itself.

## Findings

### Codebase Patterns

**How the library currently scopes itself** (`suite-selection-lib.sh:117-120`):
```bash
_SSL_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_SSL_SCRIPTS_ROOT="$(cd "${_SSL_SELF_DIR}/.." 2>/dev/null && pwd)"
_SSL_TESTS_DIR="${_SSL_SCRIPTS_ROOT}/tests"
```
In the source store this resolves to `agent-system/extensions/core/scripts` /
`.../core/scripts/tests`. In a deploy it resolves to the single merged `.claude/scripts` /
`.claude/scripts/tests` tree (every extension's scripts flattened together by
`deploy-headless.sh`). `_ssl_resolve_one()` (the function behind every public selection call)
uses only these two fixed variables for every stratum — stratum 0 (self-identity), stratum (a)
(strict basename pairing, including the `lib/` suffix variant), and stratum (b) (grep-based
reference lookup). **The touched path argument's own directory structure is discarded**: only
`basename "$path"` is ever used. This is the exact mechanism that makes the mapping core-only
today — not a missing case, but a design that never looks at where the touched path itself lives.

**`run-all.sh` already solves the general "every extension" problem, and names the exact
detection idiom to reuse** (`tests/run-all.sh:343-353`):
```bash
CANDIDATE_EXT_ROOT="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd || true)"
if [ -n "$CANDIDATE_EXT_ROOT" ] && [ -f "$CANDIDATE_EXT_ROOT/core/manifest.json" ]; then
  MODE="source-store"; EXTENSIONS_ROOT="$CANDIDATE_EXT_ROOT"
  for ext_dir in "$EXTENSIONS_ROOT"/*/; do ... done   # scans every extension's scripts+tests
else
  MODE="deployed"; DEPLOY_SCRIPTS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
```
`run-all.sh` is itself discovered at `scripts/tests/run-all.sh`, one directory deeper than
`suite-selection-lib.sh` (`scripts/lib/suite-selection-lib.sh`) — but both are exactly 2
directories under their extension root, so `_SSL_SCRIPTS_ROOT/../..` lands on the same
`agent-system/extensions/` root `run-all.sh`'s `$SCRIPT_DIR/../../..` lands on. The
`core/manifest.json` marker check is the corpus's one existing, shared idiom for "am I looking at
a real extensions root" — reusing it (rather than inventing a second detection convention) is
what HARD CONSTRAINT 3 ("preserve the deployed-mode dual behaviour... do not fork that
convention") calls for.

**Per-extension `scripts/`+`tests/` population** (measured directly against the source store):

| Extension | flat `scripts/*.sh` | `scripts/tests/test-*.sh` |
|---|---|---|
| core | 95 | 143 |
| literature | 32 | 7 |
| lean | 10 | 7 |
| books | 4 | 5 |
| memory | 4 | 0 |
| approvals | 3 | 4 |
| typst | 2 | 2 |
| nix | 2 | 0 |
| email | 1 | 0 |
| nvim | 1 | 0 |

9 non-core extensions carry their own scripts; 5 of them (`approvals`, `books`, `lean`,
`literature`, `typst`) carry their own paired `scripts/tests/` suites — 25 non-core suites total.
`literature` and `typst` also have their own `scripts/lib/` subdirectory, so the existing `lib/`
suffix-variant stratum (`NAME.sh -> test-NAME-lib.sh`) applies to them too, once resolved against
their own tree.

**The task 385 incident reproduces exactly as described.** `lean-challenge-snapshot.sh` pairs
with `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` by plain strict
basename pairing (stratum a) — the simplest possible case, not a grep-stratum edge case. Sourced
today from the source store, `suite_selection_select "agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh"`
looks for `test-lean-challenge-snapshot.sh` under `core/scripts/tests` and `core/scripts`, finds
nothing, finds no core suite grep-referencing the basename either, and returns
`__FULL_SWEEP__` — a false escalation for a path with a real, trivial, one-line-strata covering
suite.

**The "0 of 19" figure does not survive re-measurement.** Direct `grep -E '\$REPO_ROOT/\.claude|/\.claude/'`
against the real `scripts/tests/test-*.sh` files of all 5 extensions that have them finds **5 of
25** non-core suites carrying at least one such reference: `test-approve-classify.sh`,
`test-approve-paths.sh`, `test-approve-refusals.sh`, `test-approve-structural.sh`, and
`test-lean-mcp-preflight-check.sh`. The frozen header claim ("0 of 19... a core-only phenomenon
today") is false under this direct measurement, independent of any mapping fix. The most likely
explanation is that the figure was never a real absence-of-hazard finding: `suite_selection_classify()`
locates its `SUITE_BASENAME` argument via the exact same core-tree-only `_SSL_TESTS_DIR`/
`_SSL_SCRIPTS_ROOT` pair, and its own documented fallback for "suite file not found or unreadable"
is `source-only` (`suite-selection-lib.sh`'s `suite_selection_classify`, the `[ -z
"${_ssl_suite_path}" ] || [ ! -r "${_ssl_suite_path}" ]` branch). From the source store, every
non-core suite basename hits exactly that branch — the function never even opens the file to look
for a `.claude` reference, it just returns the vacuous default. A "0 of N" measurement built by
calling this function from the source store against non-core suite basenames would report exactly
"0" regardless of what those suites' source text actually contains, which is indistinguishable
from — and plausibly the actual origin of — the recorded figure. This is re-derived here, not
carried forward: see the Decisions section for the disposition.

### External Resources

Not applicable — this is a pure codebase/shell-convention task with no external library or API
surface.

## Recommendations

1. **Resolve scripts/tests roots per touched-path argument, not once per library load.** Add one
   new internal helper (`_ssl_` prefixed, unset-on-return, never calling `exit`, matching the
   library's existing discipline) that, given one touched path string, checks whether it contains
   an `agent-system/extensions/<ext>/scripts/` segment. If it does, AND `${_SSL_SCRIPTS_ROOT}/../..`
   (the extensions root implied by the library's own fixed location) carries `core/manifest.json`
   (the same marker `run-all.sh` already uses to distinguish source-store from deployed layout —
   reuse it verbatim rather than adding a second detection idiom), resolve that extension's own
   `scripts/` and `scripts/tests/` directories (if they exist) as the roots for THIS call only.
   Otherwise — no such segment (every core-tree path, and every deployed-mode path, since a
   deployed touched path such as `.claude/scripts/lib/foo.sh` never contains an
   `extensions/<ext>/scripts/` segment at all) — fall through unchanged to the already-computed
   `_SSL_SCRIPTS_ROOT`/`_SSL_TESTS_DIR`. This is why HARD CONSTRAINT 2 ("a path that resolves to a
   suite now must resolve to the same suite after the change") and HARD CONSTRAINT 3 (preserve
   deployed-mode behavior, no forked convention) both hold **by construction**: a core-tree path
   detects `ext=core`, and `core`'s own extension-scoped roots are byte-identical to the roots
   already in use today (the library lives under `core` itself); a deployed path never matches
   the detection case at all, so it is physically impossible for this change to alter deployed
   behavior.
2. **Thread the new per-call roots through every stratum inside `_ssl_resolve_one`** — stratum 0
   self-identity, stratum (a) strict basename + `lib/`-suffix pairing, stratum (b) grep reference
   lookup — replacing the three uses of the fixed `_SSL_TESTS_DIR`/`_SSL_SCRIPTS_ROOT` with the
   per-call resolved pair. `suite_selection_unmapped` and `suite_selection_select` need no change
   beyond this, since they call `_ssl_resolve_one` unchanged.
3. **Extend `suite_selection_classify()`'s own suite-file lookup to search every extension, not
   only core.** `classify()` receives a bare `SUITE_BASENAME` with no path context at all, so the
   per-touched-path detection in recommendation 1 does not apply to it directly; instead, broaden
   its existing single-tree lookup (`_SSL_TESTS_DIR`/`_SSL_SCRIPTS_ROOT`) into a short loop over
   `${_ext_parent}/*/scripts/tests/${suite}` and `${_ext_parent}/*/scripts/${suite}` (mirroring
   `run-all.sh`'s own `for ext_dir in "$EXTENSIONS_ROOT"/*/` discovery idiom), using the first
   match. Suite basenames are suite-corpus-unique by the existing `test-*.sh` discovery
   convention, so there is no real ambiguity to resolve. This is the minimal change that answers
   item (2) of the ask by **extending** the classification signal rather than writing a
   core-only justification for a figure this research shows does not actually hold.
4. **Re-derive the "0 of 19" (now "0 of 25" if left unmeasured) figure fresh, post-fix, in the
   library's own header** — do not simply bump the denominator on the existing frozen claim.
   Run the corrected `suite_selection_classify` across every real non-core suite/touched-basename
   pair discoverable today and record the true count, replacing the "a core-only phenomenon
   today" framing (now false) with whatever the corrected measurement actually shows (this
   research's own direct-grep probe found at least 5 of 25 carrying a `.claude` reference at all,
   which upper-bounds — not determines — how many would classify as `deployed-first`; the
   ordering check itself must be run per-pair to get the real count, which is implementation
   work, not research work).
5. **Keep `__FULL_SWEEP__` semantics completely unchanged.** No stratum is weakened or made more
   permissive; a touched path under a non-core extension with genuinely no paired suite and no
   grep reference anywhere in that extension's own suites must still escalate to the sentinel —
   confirmed correct behavior per HARD CONSTRAINT 2 and item (3) of the ask.

## Decisions

- **Per-touched-path extension resolution, not a cross-extension search.** The ask's own phrasing
  ("a touched non-core script resolves to its own extension's paired suite") and HARD CONSTRAINT
  2 together rule out broadening stratum (b)'s grep lookup to scan every extension's suites for
  every call — that would risk pulling in an unrelated extension's suite that happens to
  textually mention the same basename by coincidence, which is a behavior change for core paths
  too (not just additive). Scoping resolution to the ONE extension the touched path's own
  directory names is both the narrower, safer change and the one the ask actually asks for.
- **Reuse `run-all.sh`'s `core/manifest.json` marker check**, not a new detection mechanism, to
  distinguish "the detected `extensions/<ext>/scripts/` segment is a genuine source-store
  location" from any accidental string collision — satisfies HARD CONSTRAINT 3's "do not fork
  that convention" directly rather than by argument.
- **Extend classification to non-core suites (ruling on item 2 of the ask).** Chosen over
  "document why it stays core-only" because this research's direct re-measurement shows the
  premise of staying core-only (the 0-of-19/25 figure) does not hold, and the fix is cheap (one
  broadened lookup loop, reusing an existing discovery idiom) — there is no structural reason
  left to keep classification narrower than selection once selection itself becomes
  extension-aware.
- **The 0-of-19 figure is CARRIED-UNVERIFIED no longer; it must be re-derived at implementation
  time against the corrected `classify()`**, not reused, bumped, or asserted without re-running
  the actual ordering check per suite/basename pair.

## Risks & Mitigations

- **Risk**: the new path-parsing step (detecting an `agent-system/extensions/<ext>/scripts/`
  segment inside an arbitrary argument string) could mis-parse an unusual path shape (e.g. a path
  containing `extensions` as a directory name for an unrelated reason, or a relative path given
  without the `agent-system/` prefix at all). **Mitigation**: require the literal
  `agent-system/extensions/<name>/scripts/` substring (not a bare `extensions/<name>/scripts/`)
  before treating anything as an extension-scoped path, and gate the whole branch on the
  `core/manifest.json` marker so a false-positive substring match without a real extensions root
  underneath it simply falls through to the pre-existing (safe, already-tested) default
  resolution — never a hard failure, exactly this library's existing "always returns 0, worst
  case falls back to the honest sentinel" posture.
- **Risk**: a touched path belonging to a non-core extension but given as a bare relative path
  with no `agent-system/extensions/<ext>/` segment at all (e.g. a caller `cd`'d into the
  extension directory first and passed `scripts/foo.sh`) will not be detected and will fall back
  to core-tree resolution — unchanged from today's (broken) behavior for that one input shape.
  **Mitigation**: this is a known, documented limitation, not a regression — no caller observed
  in the task 385 incident or in `plan-format.md`'s Tier Justification convention passes paths in
  that shape; every cited example names the full `agent-system/extensions/<ext>/scripts/**`
  prefix. Document the limitation in the library's header rather than silently special-casing it
  away.
- **Risk**: broadening `classify()`'s suite-file lookup to loop over every extension directory
  adds a small, fixed number of extra filesystem stats/directory listings per call (9 extension
  directories today). **Mitigation**: negligible — `classify()` is already called once per
  selected suite in `suite_selection_select_annotated`, a small number per invocation, and the
  loop bound (extension count) is tiny and stable; no measurable cost concern, consistent with
  this library's existing stance that correctness beats a cross-process-call micro-optimization.

## Context Extension Recommendations

- **Topic**: `suite-classification.data`/`suite-cost-hints.txt` staleness for newer non-core
  extensions.
- **Gap**: while verifying the non-core suite population for this task, 7 suites physically filed
  under `books` and `typst` (`test-books-observe.sh`, `test-books-approvals-signal.sh`,
  `test-books-certify.sh`, `test-validate-evidence-append-only.sh`, `test-books-gate.sh`,
  `test-typst-element-lint.sh`, `test-chapter-quality-check.sh`) were found absent from
  `suite-classification.data` entirely, despite that file's own header claiming coverage of every
  suite the deployed merged tree discovers (its "classified against 157 suites... 139 core, 18
  approvals/lean/literature" count does not include books/typst at all). This is a separate
  concern from this task's mapping/classification fix (that file and its lint
  (`lint-unit-integration-boundary.sh`) are not in this task's territory), but is a real,
  directly-observed gap worth a follow-up task.
- **Recommendation**: a small follow-up task (not this one) to re-run
  `lint-unit-integration-boundary.sh` against the current deployed tree and add the 7 missing
  rows to `suite-classification.data` (and corresponding `suite-cost-hints.txt` entries if
  missing), so the `--class`/`--tag`/`--cost-class` selection axes stay accurate as new
  extensions grow their own test suites.

## Appendix

Search queries / commands used:
- `cat agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` (full read of the subject
  library, including its header's documented strata, scope note, and public API)
- `find agent-system/extensions/lean -maxdepth 3 -type d`, `find agent-system/extensions/lean/scripts -maxdepth 2 -type f`
  (confirmed the `lean-challenge-snapshot.sh` / `test-lean-challenge-snapshot.sh` pairing named in
  the dispatch)
- `find agent-system -iname "run-all.sh"`, then a full read of its source-store/deployed detection
  block (`CANDIDATE_EXT_ROOT`/`core/manifest.json`) and per-extension discovery loop
- `grep -rl "suite-selection-lib.sh" agent-system/ --include="*.sh" --include="*.md"` and a read
  of `plan-format.md`'s Tier Justification section and `shell-script-testing.md`'s
  "Mapping a touched file to its suite" subsection (confirmed the only two call-site/reference
  locations, and the convention that `__FULL_SWEEP__` is the honest, non-tool-failure answer for
  an unmapped path)
- `wc -l`/full read of `test-run-all-selection.sh` (confirmed PART 1's library-correctness cases
  run cheaply against the real corpus, not a synthetic fixture, and PART 3's synthetic
  `EXT_ROOT/core/scripts/tests` fixture shape for mechanism-parity cases)
- `grep -n "lean" agent-system/extensions/core/scripts/tests/suite-classification.data`
  `suite-cost-hints.txt` (confirmed non-core suites are already catalogued in the declarative
  `--class`/`--tag`/`--cost-class` axis, independent of the path-mapping library's own scope
  limitation)
- Per-extension `scripts/`/`scripts/tests/` population counts (direct `find` across all 9
  non-core extensions carrying their own `scripts/`)
- Direct `grep -E '\$REPO_ROOT/\.claude|/\.claude/'` against all 25 real non-core suites
  (re-measurement of the header's carried "0 of 19" figure)
- Cross-check of `books`/`typst` suite basenames against `suite-classification.data` (surfaced
  the unrelated staleness gap recorded under Context Extension Recommendations above)
