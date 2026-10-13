# Implementation Plan: Context-Corpus Reachability Probe

- **Task**: 251 - Context-corpus reachability probe (filename, directory, index.json), then act on dead and overlapping files
- **Status**: [COMPLETED]
- **Effort**: 11.5 hours
- **Dependencies**: Task 127 (routing-ladder collapse) - COMPLETED
- **Research Inputs**: specs/251_context_corpus_reachability_and_overlap_review/reports/01_context-corpus-reachability-probe.md
- **Artifacts**: plans/01_context-reachability-probe.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build a standing, mechanical reachability/inventory probe over the context corpus under
`agent-system/extensions/**/context/**` (the SOURCE STORE, never `.claude/**`), structurally
modelled on `script-inventory.sh` and reusing `measure-eager-context.sh`'s channel model by
invocation rather than reimplementation. The probe reports, per context file: bytes, owning
extension, reachability by each of three independent reference styles (filename, directory,
per-extension `index-entries.json`) computed as a non-short-circuiting union, eager-vs-lazy
classification, and an inbound textual reference count. It is then registered, proven against a
regression property (every file under the two live template-library trees reports reachable),
run against the live tree to produce a ranked disposition record, and the directory-reference
mechanism it formalizes is documented in `context-discovery.md`. Definition of done: the probe
runs clean and reproducibly, is registered in both `manifest.json` and the utility-scripts
inventory, agrees with `measure-eager-context.sh` on what is eager, and every finding class has a
recorded disposition with a cited probe verdict.

### Research Integration

The research report supersedes three figures the dispatch carries, and the plan is built on the
corrected ones:

- The corpus is **591 `.md` files / 4,677,170 B**, not 523 / 3,583,550 B. The probe IS the
  re-measurement; neither number is carried forward as ground truth.
- The naive basename-grep check returns **39** current false-positive orphans, not 16: the 16
  `present/.../talk/contents/**` slide templates plus **23** `founder/.../deck/contents/**` deck
  templates, a second extension exhibiting the identical directory-reference shape. The
  regression property is asserted over both trees.
- There is **no single merged `index.json` in the source store**: reference style 3 must
  enumerate the 22 per-extension `agent-system/extensions/*/index-entries.json` files (577
  entries today) itself. `validate-index.sh` reads only the already-merged DEPLOYED index and
  answers a different question (is this index entry itself orphaned); it is not reusable here.
- Phase 2 of the dispatch (telemetry cross-check) already has a definitive negative answer: no
  telemetry tier records context-file loads at file granularity. `events.jsonl`'s schema carries
  no such `event_type` (only `lifecycle_stage`, `deviation`, `blocker`, `system_defect`),
  `history.jsonl` is prompt-level, and transcripts/`.meta.json` sidecars are a 30-day unstructured
  replay window. Recording that verdict plus the instrumentation design is the deliverable;
  building the instrumentation is out of scope.
- The research also establishes there are **zero confirmed-dead context files today**. Phase 6 is
  therefore written as a decision gate whose expected outcome is an empty removal set, not as a
  deletion phase.

**One deliberate divergence from the research's naming recommendation**: the research recommends
`scripts/context-inventory.sh`. The task's declared `file_scope` names
`scripts/context-reachability.sh` and `scripts/tests/test-context-reachability.sh`. This plan
follows the declared `file_scope` names, so the implementation does not open a file-scope
excursion over a cosmetic naming preference; `context-reachability.sh` is also the more accurate
name for what the probe's primary output actually is.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided to this dispatch; no ROADMAP.md consultation was performed.

## Goals & Non-Goals

**Goals**:
- A standing, re-runnable `context-reachability.sh` probe that answers "what is reachable, how,
  and at what cost" for the whole context corpus, reading only the source store.
- Three independent reference-style checks computed as a union and recorded individually, so a
  file reachable by two styles reports both.
- Eager-vs-lazy classification that cannot drift from `measure-eager-context.sh`, because it is
  derived from that script's own output rather than from a second heuristic.
- A regression property proving the two live directory-referenced template libraries (39 files
  today) report reachable, with a synthetic fixture covering both observed shapes.
- Registration in `agent-system/extensions/core/manifest.json` (`provides.scripts`) and in
  `docs/reference/utility-scripts-inventory.md`.
- A recorded telemetry verdict plus the concrete instrumentation design that would close the gap.
- A ranked disposition record for every finding class, each with a cited probe verdict.
- Directory-reference reachability documented as a sanctioned third mechanism in
  `context/patterns/context-discovery.md`.

**Non-Goals**:
- Deleting, merging, or splitting any context file on the strength of the naive check. The
  research establishes zero confirmed-dead files; Phase 6 acts only on evidence the probe
  actually produces.
- Building the `PostToolUse`-on-`Read` context-load instrumentation. It is designed and recorded,
  not implemented.
- A general clone/near-duplicate detector. Overlap is reported as a ranked candidate list for
  human disposition, not auto-merged.
- Touching `.claude/**` by hand, or running a deploy. The probe and its test resolve the source
  store directly.
- Fixing `founder`'s agent-prose `.context/` path-prefix quirk, or `script-inventory.sh`'s
  `has_test` directory-resolution bug. Both are named in research as out of scope here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Probe short-circuits at the first matching reference style, losing the present-16-vs-founder-23 distinction | M | M | Compute all three style checks unconditionally per file; the test asserts a file reachable by two styles reports both (Phase 2, Phase 4) |
| Probe reads `.claude/**` by accident (default `--root` resolution bug, or a reused merged-index assumption) | H | M | Copy `script-inventory.sh`'s `--root` resolution verbatim; Phase 4 adds a test case asserting no path under `.claude/` is opened even when run from a deployed checkout |
| Eager/lazy classifier is simplified to a hardcoded `lazy` because the answer is trivially 0-eager today | M | M | Derive the eager set from `measure-eager-context.sh`'s own `at_import` rows by invocation; emit JSON `null` (never `false`) when that script is unavailable, mirroring `script-inventory.sh`'s `manifest_registered` nullable pattern |
| A reader treats `inbound_references` counts as proof of safety to delete | H | M | Carry `script-inventory.sh`'s OVER-counting warning verbatim into the new probe's header and into every Phase 6 disposition line; a disposition must open and name the referrer paths |
| Regression assertion hardcodes 39 and goes stale as the template libraries grow | M | H | Assert the PROPERTY (no file under either `contents/**` tree is unreachable, count >= 39), not the literal number; the number lives in the Scope Hypothesis, not the assertion |
| Phase 6 finds a non-empty confirmed-dead set whose paths were never declared in `file_scope` | M | L | Phase 6 is a decision gate: a non-empty set stops and reports rather than editing, since `--file-scope-add` is only valid at research/plan postflight |
| A long gate call (`run-all.sh`, `verify-deploy.sh`) auto-backgrounds and strands the dispatch | H | H | Every gate step below carries the complete bounded-wait idiom: Bash tool `timeout` parameter 600000 AND an inner `timeout 540`, output redirected to a file and read back with `grep`. Never `run_in_background`, never a harness notification wait |
| Concurrent sibling task edits shared paths in this tree | M | M | Re-read every file immediately before editing; stage only this task's own hunks with an explicit file list; never `git-snapshot.sh` in reverting default mode |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 6, 7 | 4 |
| 6 | 8 | 5, 6, 7 |

Phases within the same wave can execute in parallel.

### Phase 1: Probe Scaffold, Enumeration, and Pre-Change Baseline [COMPLETED]

**Goal**: A runnable `context-reachability.sh` that enumerates the context corpus, reports the
cheap per-file fields, and behaves correctly on a degenerate root - plus a captured pre-change
gate baseline so acceptance criterion 6 ("no worse than at task start") is measurable.

**Tasks**:
- [x] Capture the pre-change `verify-deploy.sh --skip-slow` baseline FIRST, before any edit, using
      the bounded-wait idiom. Set the Bash tool's own `timeout` parameter to `600000`; the 120000ms
      default auto-backgrounds a longer call and strands the dispatch:
      ```
      SCRATCH=<this dispatch's own scratchpad directory>
      timeout 540 bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow \
        /home/benjamin/.config/nvim > "$SCRATCH/verify-baseline.log" 2>&1; echo "exit=$?"
      grep -nE "^(FINDING|ERROR|Gate [0-9]+|CHECKS|RESULT)" "$SCRATCH/verify-baseline.log"
      ```
      Record the exit code and the per-gate result lines in `progress-file.md`. Do not pipe the
      command itself through `tail`/`head`.
- [x] Create `agent-system/extensions/core/scripts/context-reachability.sh` with the
      `script-inventory.sh` structural contract: extensive header comment, `set -uo pipefail`,
      `usage()` as a `sed`-extract of the header, `--root PATH` override (git-toplevel default with
      a script-relative fallback), `--check` mode, `-h|--help`, small integer exit codes
      (0 success / 1 usage error or declared finding / 2 required tool missing).
- [x] Write the header's SOURCE STORE ONLY paragraph and carry over, verbatim in substance,
      `script-inventory.sh`'s METHOD WARNING that the inbound-reference count is a textual,
      deliberately OVER-counting proxy that must never be trusted as proof of safety to delete.
- [x] Implement `enumerate_candidates()` by porting `script-inventory.sh`'s version: `git ls-files`
      when `<root>` is a git work tree, a `find` fallback excluding `.git/` otherwise, glob changed
      to `.md` files whose path contains a `context/` component under
      `<root>/agent-system/extensions/**`, sorted with plain lexicographic `sort` for determinism.
- [x] Implement the cheap per-file fields: `path` (repo-root-relative), `bytes` (`wc -c`),
      `lines` (`wc -l`), `extension` (the owning extension directory name parsed from the path).
- [x] Implement the degenerate case: zero candidates emits `files: []` and `summary: null`, exit 0,
      never a crash - the nullable-field pattern `assess-repo-health.sh` and
      `script-inventory.sh` already use.
- [x] Emit one JSON document on stdout via `jq -n` with `--slurpfile` for the large per-file array;
      use a `trap`-cleaned `mktemp -d` scratch directory. Never write a file under the inspected
      tree; never source, eval, or execute a candidate.
- [x] Smoke-verify: `bash -n` clean; `--help` exits 0; `--root` with no argument exits 1; a
      hand-built two-file fixture under `mktemp -d` enumerates exactly the expected candidates;
      a live `--root /home/benjamin/.config/nvim` run emits parseable JSON whose `candidate_count`
      and total bytes are recorded in `progress-file.md`.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the live corpus is expected to be approximately 591 `.md` files totaling
approximately 4,677,170 bytes (research measurement, 2026-10-12). Confirm at implementation time
from this phase's own live run output and record the actual figures; a materially different count
is new information to record, not a probe bug.

**Tier Justification**: the edit creates one new, as-yet-uncalled shell file, so its blast radius
is that file alone and is covered by `bash -n agent-system/extensions/core/scripts/context-reachability.sh`
plus the direct fixture invocations listed above (no suite covers it until Phase 4 creates one).

**Files to modify**:
- `agent-system/extensions/core/scripts/context-reachability.sh` - new file: CLI contract, header, enumeration, cheap per-file fields, degenerate-root handling, JSON emission

**Verification**:
- `bash -n` clean on the new script.
- `--help` exits 0; `--root` missing its argument exits 1.
- A `mktemp -d` fixture with one context `.md` and one non-context `.md` enumerates exactly one candidate.
- An empty fixture reports `candidate_count: 0`, `files: []`, `summary: null`, exit 0.
- A live run against the repo root emits valid JSON (`jq empty` clean) and a recorded candidate count and byte total.
- The pre-change `verify-deploy.sh --skip-slow` baseline exit code and per-gate lines are recorded in `progress-file.md`.

---

### Phase 2: The Three Reference Styles and the Inbound Reference Count [COMPLETED]

**Goal**: Per-file reachability computed as a non-short-circuiting union of three independent
style checks, each recorded individually, plus an inbound textual reference count that makes
single-referrer files visible.

**Tasks**:
- [x] Style 1 (filename): port `script-inventory.sh`'s basename-grep mechanism (`grep -rlF` over
      the source store, excluding the candidate's own matches). Record
      `reachable_by_filename` (boolean) and the distinct referrer paths.
- [x] Style 2 (directory): for each candidate, test every PREFIX DIRECTORY of its path at any
      depth - not only its immediate parent - against referrers outside `context/`. Match on the
      deployed-relative suffix shape (e.g. `talk/contents/methods/`, `deck/contents/closing/`) so
      a referrer's own prefix convention (`founder`'s agent files write `.context/deck/contents/`,
      which is a prose quirk, not unreachability) does not defeat the match. A directory reference
      covers the whole subtree beneath it. Record `reachable_by_directory` and the matched
      referrer paths plus the matched directory.
- [x] Style 3 (index): glob `<root>/agent-system/extensions/*/index-entries.json` and parse each
      with `jq`. Treat an entry whose `path` resolves to the candidate AND which carries a
      non-empty `load_when` (or `always: true`) as a style-3 hit, scoped to that extension's own
      `context/project/<ext>/` subtree. There is no merged `index.json` in the source store - do
      not look for one, and do not call `validate-index.sh`, which reads the deployed merged index
      and answers a different question.
- [x] Compute `reachable` as the OR of the three, and `reachable_styles` as the array of every
      style that fired. Never short-circuit: all three checks run for every candidate even after
      the first hit.
- [x] Record `inbound_references` (integer) and `inbound_reference_paths` (sorted, distinct,
      repo-root-relative), counting referrers anywhere under the source store including `context/`
      files, so a single-referrer file that could be inlined is visible. Keep this distinct from
      the outside-`context/` scoping used by the style checks, and document the distinction in the
      header.
- [x] Record `zero_reference_finding` (boolean, true when `reachable` is false) as the probe's one
      declared finding class, and wire `--check` to print the per-file table and exit non-zero when
      any file carries it - mirroring `measure-eager-context.sh`'s and `script-inventory.sh`'s
      `--check` semantics (report-only, never writes a file).
- [x] Hand-verify against the two live template libraries: every file under
      `present/context/project/present/talk/contents/**` and
      `founder/context/project/founder/deck/contents/**` reports `reachable: true` with
      `directory` among its `reachable_styles`, and the founder files additionally report
      `filename` (their basenames appear in `slidev-deck-template.md`, itself a `context/` file).

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: style 3 is expected to enumerate 22 `index-entries.json` files carrying 577
entries in total, and the two template libraries are expected to contain 39 files (16 present +
23 founder). Confirm all three counts at implementation time from the probe's own output and
record the actual values; the test in Phase 4 asserts the reachability property, not these
numbers.

**Tier Justification**: the edit is confined to the single new script with no externally visible
signature and no caller yet, and is covered by `bash -n` plus the direct live-tree run asserted
above against the two known template libraries.

**Files to modify**:
- `agent-system/extensions/core/scripts/context-reachability.sh` - add the three style checks, the non-short-circuiting union, inbound reference census, declared finding class, and `--check` table

**Verification**:
- `bash -n` clean; `jq empty` clean on a live run's output.
- Every file under the two `contents/**` trees reports `reachable: true` with `directory` in `reachable_styles`.
- At least one file reports two styles simultaneously (proving no short-circuit).
- At least one file reports `index` among its styles, cross-checked by hand against that extension's own `index-entries.json`.
- `--check` exits non-zero when a crafted fixture contains a genuinely unreferenced context file, and exits 0 on a fixture where every file is reachable.

---

### Phase 3: Eager/Lazy Classification and the Telemetry Cross-Check Verdict [COMPLETED]

**Goal**: An eager/lazy field that cannot diverge from `measure-eager-context.sh`, and the
dispatch's telemetry question answered and recorded in the probe's own header.

**Tasks**:
- [x] Classify eager vs. lazy by REUSE BY INVOCATION, the same pattern `script-inventory.sh` uses
      for `check-extension-docs.sh` Rule Q: shell out to
      `REPO_ROOT=<root> bash <script_dir>/measure-eager-context.sh --check`, parse its stable
      tab-delimited output for rows whose CHANNEL field is `at_import`, and treat a candidate whose
      path appears as such a row's PATH as `eager: true`. Do not re-derive a second channel model.
- [x] Emit `eager` as JSON `null` (never `false`) when `measure-eager-context.sh` cannot be found
      next to the probe or exits unusably - the nullable-field pattern `script-inventory.sh` uses
      for `manifest_registered`. A fixture root with no `.claude/CLAUDE.md` chain is exactly this
      case and must degrade to `null`, not crash and not silently answer `lazy`.
- [x] Add a `summary.eager_count` / `summary.lazy_count` pair and document in the header that
      agreement with `measure-eager-context.sh`'s own `at_import` subtotal is the probe's
      non-divergence contract (acceptance criterion 3), satisfied today at 0 == 0 but not
      hardcoded to it.
- [x] Mechanically re-verify the telemetry verdict at implementation time rather than inheriting
      it on trust: grep `context/schemas/events-schema.json` and every `event_type` literal in use
      across the source store; confirm `history.jsonl`'s record shape carries no tool-call or path
      field. Record the observed `event_type` set in `progress-file.md`.
- [x] Write a `TELEMETRY CROSS-CHECK` paragraph into the probe's header stating plainly that no
      telemetry tier records context-file loads at file granularity today, that the probe's verdict
      is therefore STATIC reachability only ("could this be loaded", never "has this been loaded"),
      and naming the instrumentation that would close the gap: a `PostToolUse` hook matched on
      `Read` (and `Bash` for `cat`/`sed -n` reads), filtering paths under
      `agent-system/extensions/*/context/**` or `.claude/context/**`, appending an
      `event_type: "context_file_read"` row with the path in `detail` to `events.jsonl` - which the
      existing open `event_type`/`detail` schema accepts without a schema change. State explicitly
      that building it is out of this task's scope.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: the expected live result is 0 eager and every candidate lazy, because
`measure-eager-context.sh`'s `at_import` channel resolves zero references repo-wide today.
Confirm at implementation time by diffing the probe's eager set against that script's own
`at_import` rows; a non-zero eager count is a real finding to record, not a probe bug.

**Tier Justification**: the edit stays inside the single new script, and its one external
coupling - agreement with `measure-eager-context.sh` - is covered by directly diffing the probe's
eager set against that script's own `--check` `at_import` rows in this phase's verification.

**Files to modify**:
- `agent-system/extensions/core/scripts/context-reachability.sh` - add the eager/lazy classifier via `measure-eager-context.sh` invocation, the nullable-on-unavailable behavior, summary counts, and the TELEMETRY CROSS-CHECK header paragraph

**Verification**:
- The probe's eager set is byte-identical to the set of PATH fields on `measure-eager-context.sh --check`'s `at_import` rows (both empty today; the comparison, not the emptiness, is the check).
- A fixture root lacking the CLAUDE.md chain reports `eager: null` for every candidate and still exits 0.
- The observed `event_type` literal set is recorded, and the header's TELEMETRY CROSS-CHECK paragraph names the instrumentation design and its out-of-scope status.

---

### Phase 4: Regression Suite with the Directory-Reference and Index Fixtures [COMPLETED]

**Goal**: `tests/test-context-reachability.sh` covering enumeration, the three styles, the
eager-null degradation, reproducibility, no-side-effects, and the live-tree regression property
that the dispatch names as its primary acceptance bar.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-context-reachability.sh` on
      `test-script-inventory.sh`'s structural model: `pass()`/`fail()`/`info()` helpers,
      `PASSED`/`FAILED` integer counters, deploy-tree-first then source-store-fallback tool
      resolution, `mktemp -d` workdir with a `trap` cleanup, `mk_git_fixture()` helper, exit 0 on
      all-pass / 1 on any-fail / 2 on environment error.
- [x] `chmod +x` the new test file - `run-all.sh`'s loud-skip discipline reports a non-executable
      suite as `[SKIP]`, which is a silent coverage loss, not a pass.
- [x] Case: enumeration - a fixture with a context `.md`, a non-context `.md`, and a non-`.md`
      file enumerates exactly the context `.md`.
- [x] Case: style 1 - a referrer outside `context/` naming a candidate's basename yields
      `reachable_by_filename: true` and `filename` in `reachable_styles`.
- [x] Case: style 2, present-shape - a fixture replicating `talk/contents/<subdir>/<file>.md` with
      an agent file outside `context/` referencing only the DIRECTORY, and zero basename mentions
      anywhere, yields `reachable: true` with `reachable_styles == ["directory"]` exactly.
- [x] Case: style 2, founder-shape - the same directory reference PLUS a basename mention that
      lives inside another `context/` file, and a referrer using a different path prefix than the
      file's real location, yields `reachable: true` with BOTH `directory` and `filename` recorded
      (proving the union is not short-circuited and that a prefix mismatch does not defeat the
      directory match).
- [x] Case: style 3 - a fixture `index-entries.json` listing a candidate's path with a non-empty
      `load_when` yields `index` in `reachable_styles`; a sibling entry with an empty `load_when`
      and no `always: true` does not.
- [x] Case: genuine orphan - a context file referenced by nothing at all reports
      `reachable: false`, `zero_reference_finding: true`, and makes `--check` exit non-zero.
- [x] Case: eager degradation - a fixture with no CLAUDE.md chain reports `eager: null`, exit 0.
- [x] Case: never reads `.claude/**` - run the probe with `--root` pointed at a fixture that
      contains BOTH an `agent-system/extensions/**/context/**` tree and a decoy
      `.claude/context/**` tree, and assert no decoy path appears anywhere in the output.
- [x] Case: reproducibility - two consecutive default-mode runs against the same root are
      byte-identical after filtering the `generated_at` field out with `jq`, mirroring
      `test-script-inventory.sh`'s own reproducibility filter (acceptance criterion 2).
- [x] Case: no side effects - a before/after `find`-based manifest of the fixture root is
      byte-identical across a full default-mode run.
- [x] Case: degenerate root and usage error - as in `test-script-inventory.sh`.
- [x] Case: LIVE-TREE REGRESSION PROPERTY (the dispatch's primary acceptance bar) - run the probe
      against the real repo root and assert that EVERY file under
      `present/context/project/present/talk/contents/**` and
      `founder/context/project/founder/deck/contents/**` reports `reachable: true` with
      `directory` among its styles, and that the combined count of those files is at least 39.
      Assert the property and a floor, never a hardcoded exact total, so the case does not go
      stale as either template library grows. Skip-with-a-loud-`[INFO]`, never silently, if the
      live tree is unavailable.
- [x] Run the suite and read both its summary line and its exit code.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: the live regression property is expected to cover 39 files (16 present +
23 founder). Confirm the actual count at implementation time from the probe's own output and
record it in `progress-file.md`; the assertion itself is the property plus a >= 39 floor, so a
grown library passes and a shrunken one fails loudly.

**Tier Justification**: the new suite is the covering check for the whole probe, and is itself
exercised by `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-context-reachability.sh`,
which `suite-selection-lib.sh`'s strict basename pairing resolves for both touched paths.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-context-reachability.sh` - new file: the full fixture-driven case list above, executable bit set

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-context-reachability.sh` reports the suite passing, read from its summary line AND its exit code.
- The live-tree regression case passes with a recorded covered-file count of at least 39.
- The reproducibility case passes (two runs byte-identical modulo `generated_at`).
- The no-`.claude/**` case passes against a decoy-bearing fixture.
- The suite file is executable (`test -x`).

---

### Phase 5: Manifest and Inventory Registration [COMPLETED]

**Goal**: The probe and its suite are declared where this repo's own gates require, so the task
cannot reach completion with an unregistered script.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/manifest.json` immediately before editing (a sibling
      task is live in this tree this cycle).
- [x] Add `context-reachability.sh` and `tests/test-context-reachability.sh` to core's
      `provides.scripts`, each at its locally alphabetical position. Prefer
      `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` to confirm the
      gap, then `--write` to insert, rather than hand-editing the array.
- [x] Add one bullet for `.claude/scripts/context-reachability.sh` to
      `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`, in the existing
      one-bullet-per-script format, placed adjacent to the `script-inventory.sh` bullet. State:
      source-store-only (never the deployed tree, `--root` to retarget); the per-file field set
      (bytes, owning extension, the three reference styles recorded individually as a
      non-short-circuiting union, eager/lazy derived from `measure-eager-context.sh`'s `at_import`
      channel by invocation, inbound reference count); `--check`'s table-plus-non-zero-on-finding
      semantics; that it never writes a file; and - following the file's own
      `measure-eager-context.sh` / `measure-eager-surface.sh` precedent - its explicit coexistence
      relationship with `script-inventory.sh`: same probe class, different corpus (`context/**`
      vs. `scripts/**`), neither superseding the other.
- [x] Carry the OVER-counting caveat into the inventory bullet too, so a reader who never opens
      the script's header still meets it.
- [x] Verify with the bounded-wait idiom (Bash tool `timeout` parameter `600000`, inner
      `timeout 540`, redirect and grep):
      ```
      timeout 540 bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow \
        --only-gate 3,4 /home/benjamin/.config/nvim > "$SCRATCH/gate34.log" 2>&1; echo "exit=$?"
      grep -nE "^(FINDING|ERROR|Gate|CHECKS|RESULT)" "$SCRATCH/gate34.log"
      ```

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: exactly two `provides.scripts` entries and one inventory bullet are
expected to be added. Confirm at implementation time with
`sync-manifest-scripts.sh --check` reporting zero remaining gaps and a `grep -c` of the new
bullet.

**Tier Justification**: the manifest edit's blast radius is extension-declaration linting, covered
by `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` plus the
`verify-deploy.sh --skip-slow --only-gate 3,4` run named above (doc-lint and task-reference lint,
with an explicit source-store TARGET rather than the bare no-argument form).

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - add two `provides.scripts` entries for the probe and its suite
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - add one bullet registering the probe, with its coexistence note and OVER-counting caveat

**Verification**:
- `sync-manifest-scripts.sh --check` exits 0 with no on-disk-not-declared gap for either new path.
- `jq empty` clean on the edited manifest.
- `verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` reports no new FINDING versus the Phase 1 baseline, read from the log file with its exit code recorded.
- The new inventory bullet names the source-store-only constraint, the field set, `--check` semantics, the `script-inventory.sh` coexistence relationship, and the OVER-counting caveat.

---

### Phase 6: Live Run, Ranked Disposition, and the Removal Decision Gate [COMPLETED]

**Goal**: Run the proven probe against the live tree and produce an evidenced, ranked disposition
for every finding class - acting only on what the probe actually establishes.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/context-reachability.sh > specs/251_context_corpus_reachability_and_overlap_review/probe-run.json`
      against the live repo root, and a second time to confirm reproducibility modulo
      `generated_at`.
- [x] Write `specs/251_context_corpus_reachability_and_overlap_review/ranked-disposition.md`
      recording, per finding class:
      - **Confirmed dead** (`reachable: false` across all three styles): for each, the probe
        verdict, an explicit statement of the check result for EACH of the three styles, and the
        opened-and-read referrer paths. Research establishes this set is expected to be EMPTY.
      - **Single-referrer / inline candidates** (`inbound_references == 1`): path, the one
        referrer, and a recommendation, with the OVER-counting caveat restated.
      - **Substantial-overlap candidates**: ranked pairs, each with the evidence that suggested the
        overlap and an explicit note that no merge is performed on a textual signal alone.
      - **Live-but-oversized**: ranked by bytes, each annotated with whether the established
        rule-or-command to lazy-narrative split applies (the worked exemplar being a rule file
        whose narrative moved to `context/standards/`).
- [x] DECISION GATE. If the confirmed-dead set is EMPTY (the expected outcome): perform no
      removal, and close this phase's removal and merge sub-steps as excluded with the probe's own
      verdict as evidence, per plan-format.md's `#### Reasoned Exclusions` subsection format.
- [x] If the confirmed-dead set is NON-EMPTY: STOP before editing any named file. Those paths were
      not declared in `file_scope` at plan time and `--file-scope-add` is only valid at
      research/plan postflight, so a removal here would be an undeclared excursion. Record the
      set in `ranked-disposition.md`, report it in the handoff and `.return-meta.json` summary as
      requiring a further plan round to declare the targets, and close the phase as
      `[COMPLETED WITH EXCLUSIONS]` citing the gate.
- [x] In either branch, record the issue-log entry for the branch taken via `issue-record.sh`.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: prose

**Scope Hypothesis**: the confirmed-dead set is expected to be EMPTY (zero files), because the
research established all 39 naive-check orphans are directory-reference false positives. Confirm
at implementation time from `probe-run.json` by counting files with `reachable: false`, and record
the actual count; a non-zero count routes to the decision gate's STOP branch.

**Tier Justification**: every path this phase writes lies under `specs/**` - the task's own
directory, which no test suite maps and which is the task-reference lint's own exempt tree - so
the honest covering check is the `prose` tier's diff read-through of the two written records
against `probe-run.json`'s actual contents.

**Files to modify**:
- `specs/251_context_corpus_reachability_and_overlap_review/probe-run.json` - new file: the probe's full live output, retained as the cited evidence
- `specs/251_context_corpus_reachability_and_overlap_review/ranked-disposition.md` - new file: the per-finding-class ranked disposition with probe and telemetry verdicts

**Verification**:
- `probe-run.json` is `jq empty` clean and its `candidate_count` matches a second run's.
- `ranked-disposition.md` records every finding class, and every entry cites a probe verdict plus the result of all three style checks.
- The telemetry verdict ("no file-granularity load data exists; this ranking is static-reachability only") appears explicitly in the disposition record.
- The decision-gate branch taken is stated in the record, and the no-removal branch carries a `#### Reasoned Exclusions` table whose Evidence column cites the probe's own empty confirmed-dead count.

---

### Phase 7: Document Directory-Reference Reachability [COMPLETED]

**Goal**: Record directory reference as a sanctioned, recognized third reachability mechanism
alongside filename and index enumeration, so a future contributor adding a template library has
written guidance and a mechanical check to point at.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/patterns/context-discovery.md` immediately
      before editing.
- [x] Add a short subsection naming the three reachability mechanisms: by filename (a backticked
      or plain path), by directory (a reference to a containing directory, which reaches every file
      in its subtree), and via a per-extension `index-entries.json` entry the loader resolves at
      deploy/runtime. State plainly that a directory reference is sanctioned and recognized, not an
      accidental gap, and that a file reachable by any one of the three is not dead however
      unloved it looks.
- [x] Point at `context-reachability.sh` as the mechanical check that evaluates all three, naming
      it by filename only - no task numbers, per `no-task-references-in-deliverables.md`.
- [x] Note that the source store holds no merged index: style-3 data lives in 22 separate
      per-extension `index-entries.json` files, which is why the probe enumerates them itself.
- [x] Verify with the bounded-wait idiom (Bash tool `timeout` parameter `600000`, inner
      `timeout 540`, redirect and grep) that doc-lint and the task-reference lint stay clean:
      `verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: prose

**Tier Justification**: the edit is pure guidance markdown with no executable surface, so
`suite_selection_select` returns `__FULL_SWEEP__` and no suite covers it; the honest check is the
source-store gate subset `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
plus the `prose` tier's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/context-discovery.md` - add a subsection naming the three reachability mechanisms and pointing at the probe as the mechanical check

**Verification**:
- `verify-deploy.sh --skip-slow --only-gate 3,4` reports no new FINDING versus the Phase 1 baseline, read from the log file with the exit code recorded.
- The new subsection names all three mechanisms, states that directory reference is sanctioned, points at `context-reachability.sh` by filename, and contains no task-number reference.
- Diff read-through confirms every changed hunk is prose inside the new subsection.

---

### Phase 8: Full Gate Set and Acceptance Confirmation [COMPLETED]

**Goal**: Confirm the complete gate set is green and no worse than the Phase 1 baseline, and that
every one of the task's six acceptance criteria is evidenced.

**Tasks**:
- [x] Run the full shell suite with the bounded-wait idiom. Set the Bash tool's own `timeout`
      parameter to `600000` (the 120000ms default auto-backgrounds this call and strands the
      dispatch; do NOT use `run_in_background` and do NOT wait on a harness notification):
      ```
      timeout 540 bash agent-system/extensions/core/scripts/tests/run-all.sh \
        > "$SCRATCH/run-all.log" 2>&1; echo "exit=$?"
      grep -nE '^\[run-all\] [0-9]+ passed' "$SCRATCH/run-all.log"
      grep -nE '^\[run-all\] Failing suites' "$SCRATCH/run-all.log"
      ```
      Read BOTH the summary line and the exit code. Do not pipe the command itself through
      `tail`/`head`.
- [x] Run the aggregate gate set with the same idiom:
      ```
      timeout 540 bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow \
        /home/benjamin/.config/nvim > "$SCRATCH/verify-final.log" 2>&1; echo "exit=$?"
      grep -nE "^(FINDING|ERROR|Gate [0-9]+|CHECKS|RESULT)" "$SCRATCH/verify-final.log"
      ```
      Compare per-gate results against the Phase 1 baseline log and state explicitly that the
      outcome is no worse.
- [x] Walk the six acceptance criteria and record, for each, the specific evidence: (1) probe runs
      clean, is registered, and reports every template-library file reachable; (2) output
      reproducible across two runs and reads no `.claude/**` path; (3) eager/lazy agrees with
      `measure-eager-context.sh`; (4) every removed file - expected: none - carries a probe verdict
      and an all-three-styles check; (5) `run-all.sh` green by summary line and exit code;
      (6) `verify-deploy.sh --skip-slow` no worse than the baseline.
- [x] State the Phase 2 telemetry finding and its instrumentation design in the completion summary,
      naming it as a candidate follow-up explicitly scoped out of this task.
- [x] Record `modified_files` in `.return-meta.json`, and attest the issue log explicitly (entries
      recorded, or an explicit statement that nothing arose).

**Timing**: 1 hour

**Depends on**: 5, 6, 7

**Verification Tier**: full

**Files to modify**:
- none planned (verification and reporting only)

**Verification**:
- The complete gate set runs: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow /home/benjamin/.config/nvim`, with its exit code and per-gate lines recorded and compared against the Phase 1 baseline.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` reports `0 failed` on its summary line AND exits 0, neither read through a `tail`/`head` pipe.
- All six acceptance criteria have a named piece of recorded evidence.
- `.return-meta.json` carries a non-empty `modified_files` array.

## Testing & Validation

- [x] `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-context-reachability.sh` green (Phase 4).
- [x] `bash agent-system/extensions/core/scripts/tests/run-all.sh` green, read by summary line and exit code, unpiped (Phase 8). *(deviation: altered -- final run is 137 passed, 1 failed, exit 1; the one failure, test-four-tier-conflict.sh's timing-sensitive Case 6, is a confirmed pre-existing load-sensitive flake in an unrelated file, reproduced across four repeated standalone runs under this session's own heavy subprocess load; this task's own new suite passed in every run)*
- [x] `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow /home/benjamin/.config/nvim` no worse than the Phase 1 baseline (Phase 8).
- [x] `sync-manifest-scripts.sh --check` exits 0 (Phase 5).
- [x] `jq empty` clean on the probe's live output and on the edited `manifest.json`.
- [x] Probe output reproducible across two consecutive runs modulo `generated_at`.
- [x] Probe output contains no path under `.claude/`, verified both by the fixture decoy case and by a grep of the live output.
- [x] The probe's eager set equals `measure-eager-context.sh --check`'s `at_import` PATH set.
- [x] Every file under the two live `contents/**` template trees reports `reachable: true` with `directory` among its styles, count >= 39.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/context-reachability.sh` - the standing probe
- `agent-system/extensions/core/scripts/tests/test-context-reachability.sh` - its regression suite
- `agent-system/extensions/core/manifest.json` - two new `provides.scripts` entries
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - one new registration bullet
- `agent-system/extensions/core/context/patterns/context-discovery.md` - the three-mechanism reachability subsection
- `specs/251_context_corpus_reachability_and_overlap_review/probe-run.json` - the cited live probe output
- `specs/251_context_corpus_reachability_and_overlap_review/ranked-disposition.md` - the per-finding-class ranked disposition
- `specs/251_context_corpus_reachability_and_overlap_review/summaries/01_context-reachability-probe-summary.md` - completion summary, carrying the telemetry verdict and the instrumentation follow-up

## Rollback/Contingency

- Phases 1-5 are additive: two new files plus three small, locally reversible edits (two
  `provides.scripts` entries, one inventory bullet, one documentation subsection). Reverting means
  deleting the two new files and reversing those three edits by hand, file by file - no history
  rewrite and no whole-tree operation.
- No phase removes or rewrites any existing context file. Phase 6's decision gate is what keeps it
  that way: with a non-empty confirmed-dead set it STOPS and reports rather than deleting, so
  there is no deletion to roll back.
- A sibling task is live in this tree this cycle. Stage and commit only this task's own paths with
  an explicit file list; never a directory or glob `git add`. If a foreign commit or a foreign
  uncommitted modification appears, check `git log` to confirm the work is not this task's own,
  then STOP and report rather than proceeding.
- Should a genuine rollback of uncommitted work become necessary, follow
  `context/contracts/recovery.md`'s rollback rung for the snapshot-then-rollback invocation shape
  (including its out-of-scope override flag). Do not emit a bare reverting `git-snapshot.sh` as a
  routine checkpoint; an ordinary defensive checkpoint uses `--no-revert`.
