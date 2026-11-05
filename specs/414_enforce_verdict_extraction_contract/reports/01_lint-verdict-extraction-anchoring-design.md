# Research Report: Task #414

**Task**: 414 - Enforce the gate verdict-line extraction contract mechanically
**Started**: 2026-11-05
**Completed**: 2026-11-05
**Effort**: Small-to-medium (one new lint script, one new test suite, three small edits to
existing in-scope files)
**Dependencies**: Task 413, Task 411 (per state.json)
**Sources/Inputs**: Codebase inspection of `agent-system/extensions/core/scripts/**`,
`agent-system/extensions/core/context/standards/shell-script-testing.md`, live execution of
`verify-deploy.sh --only-gate 24`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- The three "already done" items the dispatch names are all confirmed accurate by direct
  inspection: the helper (`gate-verdict-extract-lib.sh`), the prose contract (`shell-script-
  testing.md`'s "Verdict-line extraction contract" section), and all 14 `verify-deploy.sh`
  extraction sites routing through it. No rework needed there.
- The residual gap is real: no lint exists under `scripts/lint/` for this contract, and
  `scripts/gate-registry.data` tops out at id 24 (`lint-dead-command-recommendations.sh`).
  `lint-gate-registry.sh` (the closest structural sibling) and `lib/gate-registry-lib.sh`
  (field resolution) are confirmed as the right prior art to clone from, and
  `lint-state-writer-boundary.sh` / `lint-hook-registration-paths.sh` are confirmed as the right
  structural template for a "Layer 1 structural shape + Layer 2 file-level allowlist" lint.
- **Critical scoping finding, not anticipated by the dispatch's own exemption list**: a
  whole-extensions or whole-`scripts/` corpus scan for this detection shape produces many false
  positives beyond the four named exemptions — dozens of ordinary test-assertion lines across
  `scripts/tests/*.sh` that legitimately grep a test subject's own `[FAIL]`/`[VIOLATION]` output
  for assertion purposes, plus at least one real pre-existing extraction site
  (`orchestrate-cycle-postflight.sh:788`) that is outside this task's declared `file_scope`. The
  recommended fix is a narrow, hand-picked scan corpus (detailed below) that naturally excludes
  all of this without inventing new allowlist entries beyond the four the dispatch named.
- **Second concrete finding, independently verified by live execution**: `verify-deploy.sh`'s
  `--only-gate` validation is hardcoded to the range 1-23 and already rejects the existing gate
  24 (`bash verify-deploy.sh --only-gate 24` → `ERROR: ... out of range (must be 1-23)`, confirmed
  live). This bound must be widened (ideally derived from `gate_registry_ids` rather than
  re-hardcoded to 25, to avoid a third recurrence) as part of this task's `verify-deploy.sh`
  edit, or the new gate 25 inherits the identical defect and cannot be selected individually.
- `scripts/tests/test-gate-registry-resolution.sh` hardcodes "24" at three call sites (lines 69,
  71, 259) that must become "25", plus a separately-stale "23-gate registry" comment at line 265
  (already wrong today, predating this task) that should be corrected to "25-gate" in the same
  pass.

## Context & Scope

Researched: the existing verdict-extraction helper and its 14 call sites in `verify-deploy.sh`;
the prose contract in `shell-script-testing.md`; the gate registry file format and its lint
(`lint-gate-registry.sh`); five structurally similar "boundary" lints
(`lint-state-writer-boundary.sh`, `lint-hook-registration-paths.sh`,
`lint-scoped-commit-boundary.sh`, `lint-directory-pathspec-boundary.sh`,
`lint-json-channel-discipline.sh`) and their fixture test suites, to extract the established
detection-model and exemption-discipline conventions; and a repo-wide (not just core-extension)
search for every live occurrence of a `grep` call combined with the literal `[FAIL]`/
`[VIOLATION]` tokens, to pressure-test what a naive broad-corpus implementation of the new lint
would actually flag.

Not researched (out of scope for this phase): writing the lint or test code itself; the lean
extension's own `lean-mcp-preflight-check.sh:253` naive-anchor site (flagged below as informational
only — it lives under `agent-system/extensions/lean/`, entirely outside this task's declared
`file_scope`, and is not touched by any recommendation here).

## Findings

### Codebase Patterns

**The helper and its 14 call sites (confirmed, no changes needed)**. `scripts/lib/gate-verdict-
extract-lib.sh` exports exactly one function, `verify_deploy_extract_verdict_lines
<anchor_token> <producer_output>`, matching the dispatch's description exactly (strip SGR, then
anchor on `<token> `, then strip the prefix). `grep -n "verify_deploy_extract_verdict_lines"
scripts/verify-deploy.sh` returns exactly 14 call sites (plus the two degrade-safe-source
declarations at the top of the file) — `grep -n "grep -F\|grep -E '\^\\\["
scripts/verify-deploy.sh` finds zero live unanchored/naive-anchor extraction left in that file
itself (only a prose mention of the placeholder token `[TOKEN]` in a header comment, which is not
one of the two real tokens and would not match any literal-token-based lint pattern).

**The registry and its lint (prior art to clone)**. `scripts/gate-registry.data` is a 9-field
TAB-separated file, ids currently 1-24 contiguous, `lint-gate-registry.sh` validates it (function
existence, dependency-graph acyclicity, field well-formedness, id contiguity, `input_corpus`
grammar). `lint-gate-registry.sh` has no hardcoded max-id assumption — it only requires
contiguity starting at 1 — so adding id 25 requires no change to that lint. The most recently
added row (gate 24, `lint-dead-command-recommendations.sh`) is the best template for the new
row and for `verify-deploy.sh`'s `gate25_run` wiring: source-store existence guard → run with
`--verbose` → capture output+status → on non-zero, `fail` plus, under `--findings`, a
`while...done < <(verify_deploy_extract_verdict_lines '[VIOLATION]' "$output")` loop appending
`FINDING gate25 ...` rows. This is exactly the shape the new lint's own output must satisfy on
the producer side (plain `echo -e "${RED}[VIOLATION]${NC} ..."` rows, no TTY/NO_COLOR guard,
matching every sibling lint already in `scripts/lint/`).

**The structural template for the lint itself (prior art to clone)**. `lint-state-writer-
boundary.sh` and `lint-hook-registration-paths.sh` are the closest structural siblings for a lint
that scans source text for a dangerous shell-command *shape* rather than a data-format violation:
- A `resolve_project_root` helper that is robust to running from either the deployed
  (`.claude/scripts/lint/`) or source-store (`agent-system/extensions/core/scripts/lint/`)
  location (walks up looking for `agent-system/extensions`, falls back to `common_repo_root`).
- `DEFAULT_SCAN` (used when no positional path args are given) plus a `SCAN_PATHS` array
  populated from positional args for everything else — this is also exactly what lets a test
  suite point the lint at a `mktemp` fixture directory instead of the live tree.
- Two detection layers: Layer 1 is a broad `CANDIDATE_PATTERN` regex over `grep -n`, then a
  `classify_line` function that narrows each candidate line into `VIOLATION` or an `EXEMPT:
  <reason>` string; Layer 2 is a file-level `EXCLUDED_FILES`/`is_excluded_file` allowlist where
  **every entry states why it is exempt in a comment** — this is the "exemption-marker
  discipline" the dispatch asks to reuse, and it is a maintained, commented array, not an
  inline per-line marker comment (the inline-marker convention, e.g. `task-ref-ok`, belongs to a
  different lint family — `check-task-references.sh` — and is not what the sibling boundary
  lints use).
- Both lints' own test suites (`test-lint-state-writer-boundary.sh`,
  `test-lint-hook-registration-paths.sh`) build every fixture — both polarities — inside a
  `mktemp -d WORKDIR` at test-run time and pass that directory as an explicit positional path
  argument to the lint under test. **No fixture is committed as a standalone file on disk.**
  This matters directly for the "exemption-marker discipline" and for the new test suite's own
  design (see Recommendations).
- `lib/lint-corpus-scan-lib.sh` provides the shared `lint_corpus_scan_collect_files` file-
  collection wrapper already reused by three of the boundary-lint cluster; it is a candidate for
  the new lint too if the file-collection need is a simple `*.sh` glob walk over an explicit
  path list (see Recommendations for why a *hand-picked path list*, not a directory walk, is the
  right choice here).

### External Resources

Not applicable — this is a pure in-repo shell-scripting/lint-design task; no external
documentation was consulted or needed.

### Pre-existing false-positive surface for a naive broad-corpus implementation (critical finding)

A repo-wide search for `grep` combined with the literal tokens `[FAIL]` / `[VIOLATION]`
(`grep -rnE "grep[^|&;]*(-F|-E)[^|&;]*(\[FAIL\]|\[VIOLATION\])" --include="*.sh" .` from
`agent-system/extensions/`) surfaces far more than the four exemptions the dispatch names:

1. **`core/scripts/lib/gate-verdict-extract-lib.sh`** (lines 7-8, 17, 73) — explanatory header
   prose. Dispatch-named exemption.
2. **`core/scripts/lint/lint-json-channel-discipline.sh:135`** — explanatory comment. Dispatch-
   named exemption.
3. **`core/scripts/tests/run-all.sh:157`** — a comment (`# verify-deploy.sh's Gate 8 folds every
   \`grep -F '[FAIL]'\` hit...`) containing the literal bad shape as prose. **Not named by the
   dispatch.**
4. **`core/scripts/tests/test-deploy-baseline-lib.sh:336`** — a comment describing the historical
   defect by quoting both bad shapes literally. **Not named by the dispatch** (the dispatch names
   this file only as one of the "three test suites" providing regression coverage, not as a
   comment-exemption case).
5. **`core/scripts/tests/test-lint-json-channel-discipline.sh:131`** — a heredoc-constructed
   fixture (`grep -F '[VIOLATION]'`) inside an *existing, already-committed* test file for a
   **different** lint (`lint-json-channel-discipline.sh`), used as a negative-control fixture
   proving that shape is NOT flagged by that other lint. **Not named by the dispatch at all.**
6. **`core/scripts/orchestrate-cycle-postflight.sh:788`** — a REAL, functional extraction site:
   `printf '%s\n' "$hv_output" | sed -E 's/\x1b\[[0-9;]*m//g' | grep -E '^\[FAIL\]' | sed -E
   's/^\[FAIL\] //'`. This is the exact "naive line-start anchor" shape the dispatch's required
   direction flags — **but** the surrounding code already manually strips SGR first (own comment:
   "Cheap to derive: strip ANSI color codes, then the `[FAIL]` lines' own text"), so it is not
   actually SGR-blind/buggy today — it is a hand-rolled *duplicate* of the helper's own logic,
   consuming `validate-handoff.sh`'s output rather than a `verify-deploy.sh` gate producer's
   output. This file is **not in this task's declared `file_scope`.**
7. A broader search dropping the `-F`/`-E` flag restriction additionally surfaces dozens of
   ordinary test-assertion lines across `scripts/tests/*.sh` (e.g.
   `test-run-all-failure-reporting.sh`, `test-validate-artifact.sh`,
   `test-lint-agent-contracts-handoff-section.sh`, `test-run-all-parallel.sh`,
   `test-run-all-selection.sh`, `test-validate-wiring.sh`, `test-verify-deploy-context-budget.sh`,
   `test-lint-hook-registration-paths.sh`, `test-lint-deploy-caller-wrap.sh`,
   `test-validate-state.sh`, `test-lint-agent-contracts-heartbeat.sh`,
   `test-lint-shellcheck.sh`, `test-detect-noop-bash.sh`), plus
   `hooks/validate-handoff-location.sh:105` and (outside the core extension entirely)
   `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh:253`. Every one of these is
   an ordinary test-harness assertion ("did the subject process under test emit a `[FAIL]` line
   as expected") or an unrelated consumer (`validate-handoff-location.sh`, a different extension's
   preflight check) — none of them is a `verify-deploy.sh` gate folding a producer's output into
   a `FINDING` row, which is the only pattern `shell-script-testing.md`'s contract section
   actually describes ("**Several verify-deploy.sh gates** fold a producer script's own
   `[FAIL]`/`[VIOLATION]` output into `FINDING` rows").

   `core/scripts/orchestrate-cycle-postflight.sh:548`
   (`grep -E '\[FAIL\].*partial_progress'`) is a fifth shape — unanchored but with a required
   trailing substring, matching neither of the two exact shapes the dispatch's required
   direction lists (`grep -F '[...]'` bare, or `grep -E '^\[...\]'` bare) — so a shape-precise
   detector naturally does not flag it regardless of corpus choice.

### `--only-gate` range is already stale and will reject the new gate (verified live)

`scripts/verify-deploy.sh`'s `--only-gate` argument validation (around the flag's case branch)
hardcodes the acceptable range as 1-23 in three places: the non-numeric check's error message,
the `-lt 1 / -gt 23` range check, and its error message. This already rejects gate 24, which
exists and works when run as part of the full battery:

```
$ bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 24
ERROR: --only-gate: gate id '24' is out of range (must be 1-23)
```

Unless this bound is widened, the new gate 25 inherits the identical defect — it would run as
part of a full-battery invocation but could never be selected individually via `--only-gate 25`,
which is the natural way to exercise it directly during verification. `gate_registry_load` is
already called (line ~278) before this argument-parsing block runs, so `gate_registry_ids` is
available at that point and a dynamic derivation (e.g. taking the last/max token of
`gate_registry_ids`'s ascending space-separated output) is feasible in place of a third
hardcoded literal, closing this class of staleness for good rather than deferring it to whichever
task adds gate 26.

### `test-gate-registry-resolution.sh` hardcodes the current gate count

Three sites need updating when gate 25 is added: line 69 (`expected_ids="$(seq 1 24 ...)"`),
line 71 (assertion message naming "24 migrated ids... gate 24 added for the dead-command-
recommendation lint"), and line 259 (assertion message naming "24 migrated gates"). Additionally,
line 265's comment already says "the real 23-gate registry" — stale *before* this task (it
predates gate 24's own addition and was apparently missed then) — and should be corrected to
"25-gate" in the same edit pass rather than left to drift further.

## Recommendations

1. **New lint file**: `agent-system/extensions/core/scripts/lint/lint-verdict-extraction-
   anchoring.sh`, modeled directly on `lint-state-writer-boundary.sh`'s structure (header
   contract comment incl. KNOWN LIMITATION disclaimer, `resolve_project_root`, `--verbose`/
   `--quiet`/positional-path arg parsing, Layer 1 `classify_line` + Layer 2 `EXCLUDED_FILES`
   allowlist, `echo -e "${RED}[VIOLATION]${NC} $file:$lineno: ..."` emission, a quiet/verbose
   summary block, exit 0/1/2 contract). Two distinct Layer-1 verdicts, not one:
   - `VIOLATION (unanchored)`: a bare `grep -F '[FAIL]'` / `grep -F '[VIOLATION]'`, remedy names
     `verify_deploy_extract_verdict_lines`.
   - `VIOLATION (naive-anchor, SGR-blind)`: a bare `grep -E '^\[FAIL\]'` /
     `grep -E '^\[VIOLATION\]'` with no preceding SGR-strip in the same statement, remedy
     explicitly names the missing SGR-stripping step and the helper. Keep this message text
     distinguishable from the unanchored message in the lint's own source and in the new test
     suite's assertions — the dispatch requires the two be distinguished, not merged into one
     generic "use the helper" message.
   Classification can key off whether the matched grep pattern argument's first character
   (after the anchoring regex literal) is `^` — that alone is sufficient to tell the two shapes
   apart given the candidate-match text already isolates the grep invocation.

2. **Scope the scan corpus to a hand-picked file list, not a directory walk.** This is the
   single highest-leverage decision from this research: default `SCAN_PATHS` to exactly
   `scripts/verify-deploy.sh`, `scripts/lib/gate-verdict-extract-lib.sh`, and
   `scripts/lint/*.sh` (NOT `scripts/tests/*.sh`, NOT `scripts/orchestrate-cycle-postflight.sh`,
   NOT `hooks/*.sh`, NOT a bare `agent-system/extensions` or `@extensions`/`@repo` walk). This
   corpus:
   - Still requires exactly the two exemptions the dispatch names (gate-verdict-extract-lib.sh's
     own header; lint-json-channel-discipline.sh's comment at line 135) plus the lint's own
     source file (self-reference — `CANDIDATE_PATTERN` and example/remedy text will themselves
     contain the literal bad-shape substrings).
   - Naturally excludes every one of the dozens of test-assertion false positives in
     `scripts/tests/*.sh` (item 7 above) and the pre-existing `orchestrate-cycle-postflight.sh:788`
     site (item 6) without needing a single additional allowlist entry — because those files are
     simply never read.
   - Is defensible on the contract's own stated scope (`shell-script-testing.md`'s section is
     scoped to "Several verify-deploy.sh gates", not a codebase-wide rule), so narrowing the
     corpus is a correctness decision, not merely an expedient one.
   - Needs no allowlist entry for the new test suite's own fixtures either, if that suite follows
     the `mktemp -d WORKDIR` fixture convention (below) rather than committing fixture content
     inside a file that falls within this corpus.
   If the plan phase instead prefers a wider corpus (e.g. to also catch a future bad extraction
   site anywhere in `agent-system/extensions/core`), budget for building out the larger,
   un-anticipated allowlist this report's Findings section enumerates, and for a decision on
   whether `orchestrate-cycle-postflight.sh:788` is fixed in-task (expanding `file_scope`),
   allowlisted with a stated reason, or deliberately left as a separately-spawned follow-up task
   — do not let the gate land red on day one by discovering this only at verification time.

3. **New test suite**: `agent-system/extensions/core/scripts/tests/test-lint-verdict-extraction-
   anchoring.sh`, modeled on `test-lint-hook-registration-paths.sh`'s structure
   (`common_test_workdir_init`, `common_test_resolve_candidate` for the lint-under-test, every
   fixture built via heredoc into a `mktemp -d WORKDIR` and passed as an explicit positional path
   argument — **no fixture file committed to the repo**). Minimum cases per the dispatch's
   Verification section: unanchored form flagged; naive-anchor form flagged with the SGR-specific
   remedy text; a correct `verify_deploy_extract_verdict_lines`-routed call NOT flagged; each
   real exemption (the library file itself, the lint-json-channel-discipline.sh comment shape)
   NOT flagged when fed as its own fixture content; and a round-trip check that piping the lint's
   own `[VIOLATION]` stdout through `verify_deploy_extract_verdict_lines '[VIOLATION]'` yields
   exactly the finding set the lint reported (the producer-side self-check the dispatch
   explicitly requires).

4. **Registry row**: new id 25 in `scripts/gate-registry.data`, `invoke=gate25_run`,
   `dependencies=-`, `requires_source_store=true` (mirrors every other source-store-authoring
   lint, e.g. gates 6/7/9/11/12/15/17/18/19/21/23/24), `timeout_s=30`, `cost_class=free` (a
   grep-based structural scan over a handful of files, the same class as the other non-slow
   lints), `serialized=false`, `input_corpus` naming the same hand-picked file list from item 2
   (verify-deploy.sh, gate-verdict-extract-lib.sh, the lint script itself, `@extensions`-style
   `scripts/lint/*.sh` glob entry) rather than `@extensions`/`@repo`, consistent with item 2's
   narrow-scope recommendation. `gate25_run` in `verify-deploy.sh` clones `gate24_run`'s shape
   exactly (source-store existence guard, `--verbose` invocation, capture+status, `fail` plus a
   `verify_deploy_extract_verdict_lines '[VIOLATION]' "$output"` extraction loop into
   `FINDING gate25 ...` rows under `--findings`).

5. **Fix the `--only-gate` range bound in the same `verify-deploy.sh` edit** (already in
   `file_scope`): replace the three hardcoded `23` occurrences (two error messages, one numeric
   comparison) with a value derived from the live registry (e.g. the max token of
   `gate_registry_ids`'s output) rather than a fourth hardcoded literal, since `gate_registry_
  load` has already run by the time this argument is parsed. This is required for `--only-gate
   25` to work at all, and prevents the identical staleness recurring the next time a gate is
   added.

6. **Bump `test-gate-registry-resolution.sh`**: lines 69/71/259 "24" → "25" (including the
   assertion-message prose naming what gate 25 is, mirroring how line 71's message currently
   names gate 24), and correct line 265's already-stale "23-gate registry" to "25-gate registry"
   in the same pass.

7. **`shell-script-testing.md` pointer**: add one sentence to the end of the existing "Verdict-
   line extraction contract (producer/consumer)" section naming the new lint and its gate id
   (e.g. "Mechanically enforced by `scripts/lint/lint-verdict-extraction-anchoring.sh`
   (gate 25 in `scripts/gate-registry.data`)."), confined strictly to that section per the
   dispatch's instruction (a sibling task sequenced after this one also edits this file).

## Decisions

- Treat `shell-script-testing.md`'s contract-scope statement ("Several **verify-deploy.sh**
  gates fold a producer's output into FINDING rows") as the authoritative scope boundary for the
  new lint's corpus, rather than inferring a codebase-wide prohibition on the literal
  `[FAIL]`/`[VIOLATION]` grep shapes. This decision is what keeps the new gate's allowlist to
  exactly the dispatch's four named exemptions plus self-reference, instead of an open-ended list
  grown reactively against dozens of unrelated test-assertion lines.
- Do not fix, allowlist, or otherwise touch `orchestrate-cycle-postflight.sh:788`,
  `hooks/validate-handoff-location.sh:105`, or the lean extension's
  `lean-mcp-preflight-check.sh:253` in this task — none is in the declared `file_scope`, and the
  narrow-corpus recommendation (item 2) makes touching them unnecessary for this task's own
  verification to pass cleanly.
- Recommend the `--only-gate` bound be fixed via dynamic derivation from `gate_registry_ids`
  rather than a fourth hardcoded literal (`25`), since the plan already must touch this exact
  code region to accommodate gate 25 and a hardcoded fix would reintroduce the identical
  staleness class this report found gate 24 already suffering from.

## Risks & Mitigations

- **Risk**: choosing a broad scan corpus (e.g. `@extensions` or all of `scripts/`) produces a
  lint that is red on first landing, against files never intended as this contract's targets.
  **Mitigation**: the narrow, hand-picked corpus in Recommendation 2, justified directly from the
  contract's own stated scope.
- **Risk**: `--only-gate 25` silently fails the same way `--only-gate 24` already does today,
  undermining the new test suite's ability to exercise the gate's `verify-deploy.sh` wiring
  directly. **Mitigation**: Recommendation 5 (fix the bound in the same edit, dynamically
  derived).
- **Risk**: a regex-only, line-oriented lint cannot see a variable-indirected extraction (e.g. a
  pattern string built across two lines, or passed through an intermediate variable) — this is
  the same disclaimed limitation every sibling boundary lint in this cluster already carries in
  its own header ("KNOWN LIMITATION", stated plainly rather than papered over). **Mitigation**:
  carry the identical disclaimer in the new lint's header; this is an accepted, project-standard
  limitation class for this lint family, not a defect unique to this task.

## Context Extension Recommendations

- **Topic**: none — the structural template (boundary-lint cluster: `lint-state-writer-
  boundary.sh`, `lint-hook-registration-paths.sh`, their shared `lint-corpus-scan-lib.sh`
  helpers, and the `mktemp`-fixture test-suite convention) is already fully documented in the
  scripts themselves and needs no new context file; this report's Findings section is sufficient
  pointer material for the implementation phase.

## Appendix

- Search queries used: `grep -n "verify_deploy_extract_verdict_lines" scripts/verify-deploy.sh`;
  `grep -rnE "grep[^|&;]*(-F|-E)[^|&;]*(\[FAIL\]|\[VIOLATION\])" --include="*.sh" .` (from
  `agent-system/extensions/`); a second broader pass dropping the `-F`/`-E` restriction within
  `agent-system/extensions/core`; `grep -n "24\|23-gate"
  scripts/tests/test-gate-registry-resolution.sh`; live execution of
  `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 24`.
- Files read in full or substantially: `scripts/lib/gate-verdict-extract-lib.sh`,
  `context/standards/shell-script-testing.md` (lines 580-660),
  `scripts/lint/lint-gate-registry.sh`, `scripts/gate-registry.data` (header + data rows),
  `scripts/lint/lint-state-writer-boundary.sh`, `scripts/tests/test-lint-hook-registration-
  paths.sh`, `scripts/lint/lint-json-channel-discipline.sh` (relevant sections),
  `scripts/verify-deploy.sh` (gate24_run, --only-gate parsing, degrade-safe-source header),
  `scripts/tests/test-gate-registry-resolution.sh` (relevant sections),
  `context/contracts/territory.md`.
