# Implementation Plan: Task #255

- **Task**: 255 - Reconcile typst extension scope ownership and fix chapter-quality-check.sh Rule 1.3 bib resolution
- **Status**: [IMPLEMENTING]
- **Effort**: 5.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/255_typst_scope_and_chapter_quality_bib_resolution/reports/01_typst-scope-bib-resolution.md
- **Artifacts**: plans/01_typst-scope-bib-resolution.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two defects jointly disable the typst extension's chapter-quality machinery at consecutive
points in the same pipeline: the extension's declared Scope and `keyword_overrides` misroute
chapter/manual-prose work to `general` (so the typst agents that run the chapter-quality gate are
never dispatched), and `chapter-quality-check.sh`'s BLOCKING Rule 1.3 goes unevaluated in the two
commonest real-world layouts (a multi-file manual whose root document owns the
`#bibliography(...)` declaration, and any repo carrying a vendored `.bib`). Part 1 (Phase 1) and
Part 2 (Phases 2-3) have disjoint file scopes and land as separate commits; Phase 4 proves the
shared acceptance question end to end. Every edit lands in the source store
`agent-system/extensions/typst/` and reaches deployed trees only by regeneration. Done means all
eight ACCEPTANCE items in the task description are demonstrated by execution, not asserted.

### Research Integration

The research report (`reports/01_typst-scope-bib-resolution.md`) is integrated as follows, and
four of its findings materially change this plan versus the task description alone:

1. **The step-4 dead end (drives Phase 1's fix point).** `task-type-detect.sh`'s weak-signal
   table maps `chapter`/`textbook` to `general`, while `typst`'s own weak-signal entry is the
   single keyword `typst` — which can never reach the `>=2` distinct-match threshold. The
   extension's `manifest.json` `keyword_overrides` (step 2) is therefore the *only* viable fix
   point; an implementer must not attempt a weak-signal-table fix (also out of file scope, since
   that table lives in `agent-system/extensions/core/`).
2. **The contradiction is narrower than the task description states (drives Phase 1's wording).**
   Of the five "contradicting" context files, three (`textbook-standards.md`,
   `type-theory-foundations.md`, `theorem-environments.md`) and `chapter-template.md` are already
   presentation-only, and two carry an explicit `**Scope note**` drawing exactly the boundary this
   task needs. Only `chapter-quality.md` genuinely judges content. The Scope rewrite must
   therefore *align with* those existing scope notes rather than invent a new boundary.
3. **Case-f's disposition is settled (drives Phase 2's test work).** Case-f is a genuinely
   bib-less, non-git fixture where `root == filedir`; both fixes leave it untouched. It remains
   valid unmodified — but its survival must be documented in the test file so a future reader does
   not mistake it for an oversight.
4. **The `dirscan` fixture does not regress (drives Phase 2's regression guard).** `mktemp -d`
   was confirmed not to sit inside a git worktree here, so `resolve_repo_root` falls back to
   `root == filedir` for every fixture and the ancestor walk has zero range. The implementer must
   convert this from an unstated assumption into an explicit assertion.

**One finding this plan adds beyond the research report** (verified during planning by direct
execution, and load-bearing for ACCEPTANCE item 4):

- **BUG 2c — the declaration-extraction regex rejects multi-argument declarations.**
  `resolve_bibliography`'s extractor is `#bibliography\("[^"]*"\)`, which requires the closing
  paren immediately after the closing quote. The Logos/Verification root document declares
  `#bibliography("bibliography.bib", title: [References], style: "ieee")` — confirmed by running
  both patterns against that exact line: the current regex does not match, a permissive
  `#bibliography\("[^"]*"` does. **A nearest-ancestor walk reusing the current regex would still
  fail ACCEPTANCE item 4**, because the ancestor document it finds is precisely a multi-argument
  declaration. Phase 2 therefore gives the new ancestor branch its own permissive extractor.
  This respects the task's "do not rewrite the declared-path branch" constraint: branch (a) keeps
  its narrow regex untouched, and because the ancestor walk's first level is the checked file's
  own directory (scanning sibling `*.typ`, which includes the checked file itself), a
  multi-argument declaration in the checked file is picked up by the new branch rather than by a
  modified branch (a).

- **Keyword plural gap** (verified by direct execution during planning): `jq`'s
  `test("\\btypst chapter\\b")` is **false** for "review the typst chapters" — a trailing `s`
  destroys the word boundary. The research report's four-keyword set is therefore extended to
  five in Phase 1.

### Prior Plan Reference

No prior plan. This is round 1 for this task.

### Roadmap Alignment

No ROADMAP.md found (`specs/ROADMAP.md` does not exist, and no `roadmap_path` was supplied in the
delegation context). No roadmap phases added.

## Goals & Non-Goals

**Goals**:
- State a defensible `typst` vs `lean4`/`formal`/`general` boundary in `EXTENSION.md`'s Scope
  section that is consistent with every file actually shipped under `context/project/typst/`.
- Make chapter/manual-quality work self-detect as `task_type: typst` via `detect_task_type()`,
  with no keyword that hijacks another extension's tasks.
- Make BLOCKING Rule 1.3 actually evaluate in the two real layouts that currently skip it
  (root-document declaration reached via ancestor walk; vendored `.bib` excluded from the
  candidate count), including the multi-argument declaration form.
- Make a skipped BLOCKING rule loud rather than quiet: `[WARN]` tier plus a qualified PASSED
  banner, with the exit code deliberately unchanged at 0.
- Keep the script header's documented resolution contract in lockstep with the code, in the same
  commit.
- Leave `scripts/tests/test-chapter-quality-check.sh` green with new regression cases and no test
  weakened or deleted.

**Non-Goals**:
- Full Typst `#include`-graph parsing. The nearest-ancestor walk is deliberately heuristic, in
  keeping with the script's existing "documented rather than solved with a full Typst parser"
  philosophy.
- Changing Rule 1.3's exit-code posture. An unresolvable `.bib` stays a non-failing environment
  fact; only its surfacing changes.
- Rewriting the declared-path branch (a) or its `filedir` fallback — sound, explicitly excluded
  by the task description.
- Touching `scripts/typst-element-lint.sh` or its tests (separate gate, own contract) — and note
  it currently carries **pre-existing uncommitted modifications** (see Risks).
- Updating `context/project/typst/README.md`'s load lists to mention `chapter-quality.md` (a
  research-recommended follow-up). It is outside this task's declared `file_scope`; record it for
  a follow-up task rather than widening scope here.
- Deploying to `.claude/` in this repo or any of the 5 consumer repos. Regeneration is a separate,
  user-driven operation.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Pre-existing uncommitted edits in this same extension (`scripts/typst-element-lint.sh`, `index-entries.json`) get swept into a commit | H | M | Neither file is in this task's `file_scope`. Stage only the explicit per-phase file list (`git add -- <path> <path>`); never a directory or glob pathspec. Verify with `git diff --staged --name-only` before every commit. The baseline "59 passed, 0 failed" was measured *with* these edits present, so a suite delta is attributable to this task's own changes only if that baseline is re-confirmed first. |
| Ancestor walk with the existing narrow regex silently fails ACCEPTANCE item 4 | H | H (without the BUG 2c fix) | Phase 2 gives the ancestor branch a permissive extractor and asserts against a multi-argument fixture specifically, plus the live Logos/Verification run in Phase 4. |
| Ancestor walk ascends past the intended manual root and picks up an unrelated declaration | M | L | Bound the walk at the already-resolved `root` (git top-level, or the file's own directory when not in a worktree) — the same trust boundary branch (b) already accepts, not a new one. |
| A future BLOCKING rule that can go NOT EVALUATED is not wired into the new skip counter, silently regressing the banner qualifier | M | M | Phase 3 makes `emit_not_evaluated` look the rule's severity up in a declared `RULE_SEVERITY` map rather than hardcoding "1.3 is BLOCKING" at the call site, so any future BLOCKING rule increments automatically. |
| `dirscan` non-regression is contingent on `mktemp -d` never resolving inside a git worktree (unusual `TMPDIR` in a future CI) | L | L | Phase 2 adds an explicit assertion plus a one-line comment recording the assumption, converting a silent dependency into a checked one. |
| Part 1 and Part 2 landed as one commit, defeating independent revert | M | M | Separate phases with disjoint file lists and separate commits, mandated by the task's SCOPE DISCIPLINE and restated in each phase's tasks. |
| Concurrent sibling tasks editing this shared working tree | M | M | Re-read each file immediately before editing; stage only this task's own hunks; never run `git-snapshot.sh` in its reverting default mode; treat a foreign commit or modification as a STOP-and-report condition after checking `git log`. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 1 and 2 are independent because their
file sets are disjoint (`EXTENSION.md` + `manifest.json` vs. `scripts/chapter-quality-check.sh` +
its test). Phase 3 follows Phase 2 because both edit `chapter-quality-check.sh`.

---

### Phase 1: Reconcile declared scope and task-type detection (Part 1) [COMPLETED]

**Goal**: `EXTENSION.md`'s Scope section states a boundary consistent with every file under
`context/project/typst/`, and chapter/manual-quality descriptions self-detect as `typst`.

**Tasks**:
- [x] Re-read `agent-system/extensions/typst/EXTENSION.md` lines 1-20 immediately before editing
      (concurrent-sibling discipline). *(completed)*
- [x] Replace the `### Scope` section body with the boundary decided in research Decision 1/2:
      typst owns formatting, compilation, styling, structural concerns, **and the presentation
      quality of existing document content** — including chapter/manual prose review, condensing,
      and the chapter-quality gate (source grounding, anti-fluff density, presentation clarity,
      open-question honesty); originating or mathematically verifying new content routes to
      `lean4`/`formal`/`general`, while typst owns how that content is written up and presented
      once it exists, and the measurable quality of that write-up.
- [x] Confirm by reading that the new wording disclaims no category the extension ships context
      for: check it against `standards/chapter-quality.md`, `standards/textbook-standards.md`,
      `standards/type-theory-foundations.md`, `patterns/theorem-environments.md`, and
      `templates/chapter-template.md`, and confirm it does not contradict the `**Scope note**`
      already carried verbatim by `textbook-standards.md` and `type-theory-foundations.md`
      (ACCEPTANCE 1). *(completed: read all five files, confirmed consistency with existing
      Scope notes)*
- [x] Add five qualified phrases to `manifest.json`'s `keyword_overrides.typst.keywords`, keeping
      the existing eight: `"typst chapter"`, `"typst chapters"`, `"typst manual"`,
      `"chapter quality"`, `"chapter prose"`. The plural `"typst chapters"` is required because
      `\btypst chapter\b` does not match "typst chapters" (verified by direct `jq test()`
      execution during planning). *(completed)*
- [x] Deliberately do NOT add a bare `"chapter"` or bare `"manual"` (KEYWORD SAFETY CONSTRAINT:
      `typst` sorts early among `agent-system/extensions/*/manifest.json`, first whole-word match
      wins and is final). *(completed: confirmed no bare noun added)*
- [x] Validate JSON: `jq -e '.keyword_overrides.typst.keywords | length == 13' manifest.json`.
      *(completed: returned true)*
- [x] Re-run the collision audit across every `agent-system/extensions/*/manifest.json`
      `keyword_overrides` set and confirm no added phrase appears in another extension's list
      (ACCEPTANCE 3). *(completed: audited cslib, email, latex, rust — no collision)*
- [x] Demonstrate detection by execution (ACCEPTANCE 2), sourcing
      `agent-system/extensions/core/scripts/lib/task-type-detect.sh` and calling
      `detect_task_type "<desc>" specs/state.json agent-system/extensions`:
      - `"review and condense the typst manual chapters"` -> `typst` (was `general`)
      - `"typst chapter quality pass on the introduction"` -> `typst`
      - `"review the typst chapters"` -> `typst` (the plural case)
      - `"write a chapter for the textbook on group theory"` -> `general` (unchanged; no false
        positive)
      - `"prove a lemma about lean4 theorem in mathlib"` -> `lean4` (unchanged; no collision)
      *(completed: all five probes matched expected output exactly)*
- [x] Commit this phase alone: `git add -- agent-system/extensions/typst/EXTENSION.md
      agent-system/extensions/typst/manifest.json`, then `git diff --staged --name-only` to
      confirm exactly two paths, then commit. *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts (i) exactly two files change, (ii) the keyword list grows
from 8 to 13 entries, and (iii) the five detection probes above produce the stated results.
Confirm (i) with `git diff --staged --name-only`, (ii) with the `jq -e` length check, and (iii) by
running `detect_task_type` for each description and comparing output — never by assertion. If a
probe disagrees, report the actual output and revise the keyword set rather than adjusting the
probe.

**Files to modify**:
- `agent-system/extensions/typst/EXTENSION.md` - rewrite the `### Scope` section body (lines 5-9)
- `agent-system/extensions/typst/manifest.json` - add five phrases to
  `keyword_overrides.typst.keywords`

**Verification**:
- `jq -e '.keyword_overrides.typst.keywords | length == 13' agent-system/extensions/typst/manifest.json` succeeds.
- All five `detect_task_type` probes produce the expected task types, output captured in the
  phase's progress record.
- The collision audit over all `agent-system/extensions/*/manifest.json` shows no added phrase in
  any other extension's keyword list.
- Reading the rewritten Scope section against the five context files disclaims nothing the
  extension ships (ACCEPTANCE 1).
- The deployed `.claude/CLAUDE.md` `extension_typst` section is NOT edited (source-store boundary).

---

### Phase 2: Fix Rule 1.3 bibliography resolution (BUGs 2a/2b/2c) [COMPLETED]

**Goal**: `resolve_bibliography` resolves the bibliography for a chapter file included into a
root document that declares it (including a multi-argument declaration), and stops being
defeated by a vendored `.bib`; header contract and tests updated in the same commit.

**Tasks**:
- [x] Re-record the baseline: run `bash agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh`
      and confirm "59 passed, 0 failed" before any edit (the baseline is measured with the
      pre-existing uncommitted `typst-element-lint.sh` edits present; do not touch that file).
      *(completed: confirmed 59 passed, 0 failed)*
- [x] Re-read `scripts/chapter-quality-check.sh`'s `resolve_bibliography` (~lines 344-370)
      immediately before editing. *(completed)*
- [x] **BUG 2b**: add vendored/build-directory exclusions to the branch-(b) `find`, pruning at
      least `.lake/`, `.git/`, `node_modules/`, `target/`, `build/`, keeping the `-print0` read
      loop and the single-candidate test otherwise unchanged. *(completed: now branch (c))*
- [x] **BUG 2a + 2c**: insert a **new** resolution attempt strictly between existing branch (a)
      and existing branch (b) — do not modify either. Walk upward from the checked file's own
      directory to the already-resolved `root` (inclusive); at each level, grep that level's own
      `*.typ` files non-recursively (siblings only, no subtree scan) for a `#bibliography("...")`
      declaration using a **permissive extractor** (`#bibliography\("[^"]*"`, no required closing
      paren) so multi-argument declarations match; take the first (nearest) hit and resolve its
      path relative to that ancestor directory, reusing the existing `filedir`-style resolution
      shape. *(completed: new branch (b))*
- [x] Keep branch (a)'s early `return 1` for a declared-but-unresolvable path unchanged (existing
      documented behavior). *(completed: unchanged)*
- [x] Update the header's bibliography-resolution bullet (currently lines ~99-103) to state the
      three-branch order — declared-path-in-file, then nearest-ancestor declared path, then
      single-root-candidate-after-exclusion — and to name the five excluded directory patterns
      (ACCEPTANCE 7). *(completed)*
- [x] Add a KNOWN LIMITATIONS bullet: the ancestor walk assumes one unambiguous declaring `.typ`
      file per level; two siblings at the same level with conflicting declarations fall through to
      branch (b), matching the script's existing "under-firing is the safer bias" posture for
      BLOCKING rules. *(completed: folded into the rewritten bibliography-resolution bullet
      itself rather than a separate bullet, since it is a qualifier on that same contract)*
- [x] Add test case for BUG 2a/2c: a fixture root `.typ` carrying
      `#bibliography("bibliography.bib", title: [References], style: "ieee")` plus a
      `chapters/NN-x.typ` child citing a key present in that `.bib`; assert Rule 1.3 **evaluates**
      (with `--verbose`, `"Rule 1.3 evaluated against"` present) and `"1.3 NOT EVALUATED"` absent
      (ACCEPTANCE 4). *(completed: case-l)*
- [x] Add a negative twin of that case (child cites a key absent from the ancestor `.bib`):
      assert exit 1 and a `[FAIL]` naming 1.3 — the non-vacuity guard proving the new branch
      resolves to a real file rather than merely suppressing the skip. *(completed: case-l-neg)*
- [x] Add test case for BUG 2b: a fixture with a real `.bib` plus a vendored
      `.lake/packages/x/docs/references.bib`; assert Rule 1.3 evaluates against the real one
      (ACCEPTANCE 5 gets its fixture-level guard here; its live demonstration is Phase 4).
      *(completed: case-m)*
- [x] Re-examine case-f (lines ~168-181) and record its disposition: it stays **valid and
      unmodified** (genuinely bib-less, non-git, `root == filedir`, zero ancestor range). Add an
      explanatory comment at the case stating it was re-examined against both new branches and
      confirmed unaffected (ACCEPTANCE 6, 8 — do not weaken or delete it). *(completed: disposition
      comment added directly above case-f; assertions themselves unchanged)*
- [x] Add an explicit assertion to the `dirscan` CLI case that `nested/violation.typ`'s Rule 1.3
      stays NOT EVALUATED post-fix, plus a one-line comment recording the `mktemp -d`-is-not-a-git-worktree
      assumption that makes it hold. *(completed)*
- [x] Re-confirm case-a and case-e still pass unchanged (declared-path branch untouched).
      *(completed: both pass unchanged)*
- [x] Run the full suite; commit this phase alone with an explicit two-path `git add --`.
      *(completed: 72 passed, 0 failed — up from the 59 baseline)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts (i) exactly two files change, (ii) five directory
patterns are excluded from the branch-(b) `find`, and (iii) the pre-edit suite baseline is "59
passed, 0 failed". Confirm (i) with `git diff --staged --name-only`, (ii) by reading back the
implemented `find` invocation and counting its prune patterns, (iii) by running the suite before
editing and recording the actual line. If the baseline differs from 59/0, STOP and report rather
than proceeding — a changed baseline may indicate a sibling task's in-flight edit.

**Files to modify**:
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` - `resolve_bibliography`:
  vendored-dir exclusions in branch (b); new nearest-ancestor branch with permissive extractor
  inserted between (a) and (b); header resolution contract and KNOWN LIMITATIONS bullets updated
- `agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh` - new 2a/2c
  (positive + negative) and 2b cases; case-f disposition comment; explicit `dirscan` NOT-EVALUATED
  assertion

**Verification**:
- Full suite green: `bash agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh`
  reports 0 failed, with a strictly higher passed count than the 59 baseline.
- The new 2a/2c positive case shows `Rule 1.3 evaluated against` and no `1.3 NOT EVALUATED`; its
  negative twin exits 1 with a `[FAIL]` naming 1.3.
- The 2b case resolves against the non-vendored `.bib`.
- case-a, case-e, case-f assertions unchanged in substance; case-f carries its disposition comment.
- Header bullet read back names three branches in order and all five excluded patterns.

---

### Phase 3: Surface skipped BLOCKING rules loudly [COMPLETED]

**Goal**: A NOT EVALUATED **BLOCKING** rule emits at `[WARN]` tier and qualifies the final PASSED
banner, while the exit code stays 0 and ADVISORY skips keep their `[INFO]` posture.

**Tasks**:
- [x] Re-read the emitter block (~lines 265-335) and the final banner block (~lines 655-670)
      immediately before editing. *(completed)*
- [x] Add a declared severity map beside `MECH_RULES` (line ~145), e.g.
      `declare -A RULE_SEVERITY=([1.2]=BLOCKING [1.3]=BLOCKING [1.5]=BLOCKING [3.2]=BLOCKING
      [2.1]=ADVISORY [2.3]=ADVISORY [3.3]=ADVISORY)`, matching the header's rule inventory exactly.
      *(completed)*
- [x] Make `emit_not_evaluated` look the rule's severity up in that map (never hardcode "1.3 is
      BLOCKING" at the call site): on `BLOCKING`, print at `[WARN]` tier and increment a new
      global counter (e.g. `TOTAL_BLOCKING_SKIPPED`); otherwise keep the existing `[INFO]` line.
      A new BLOCKING rule that can go NOT EVALUATED then wires itself in automatically.
      *(completed)*
- [x] Keep `FILE_RULE_NOTEVAL` and the per-file MECHANICAL denominator behavior exactly as is —
      the new counter is global precisely because `FILE_RULE_NOTEVAL` is reset per file and cannot
      answer "did any file skip a BLOCKING rule" by banner time. *(completed: unchanged)*
- [x] Append a qualifier to the PASSED banner when `TOTAL_BLOCKING_SKIPPED > 0`, e.g.
      `CHAPTER QUALITY CHECK PASSED (N BLOCKING rule(s) not evaluated) (mechanical coverage only
      -- judged rules still pending adjudication)`, and **leave `exit 0` unchanged**.
      *(completed)*
- [x] Add the skipped count to the Summary block alongside Blocking/Advisory/Judged.
      *(completed: "Skipped:" line)*
- [x] Update the header to document the new posture: the `[WARN]`-tier rule, the banner qualifier,
      and an explicit restatement that a NOT EVALUATED BLOCKING rule still never affects the exit
      code (the deliberate never-fail-on-unresolved-bibliography design is preserved, only its
      visibility changes). Record the argument for the change in the header so the judgement call
      is documented where the contract lives. *(completed: NOT-EVALUATED SURFACING bullet)*
- [x] Add a test case asserting the qualified banner: reuse a bib-less fixture (case-f's shape),
      assert exit 0, `[WARN]`, `NOT EVALUATED`, and the banner qualifier text. *(completed: case-n)*
- [x] Add a test case asserting an ADVISORY-only run's banner is NOT qualified (guards against the
      counter firing on the wrong severity). *(completed: case-o)*
- [x] Re-run the full suite and confirm no existing assertion broke — in particular case-f's
      `assert_exit ... 0` and the `assert_not_contains ... "[FAIL]"` cases (a `[WARN]` line is not
      a `[FAIL]` line, so these must still hold). *(completed: all prior assertions still pass)*
- [x] Commit this phase alone with an explicit two-path `git add --`. *(completed: 83 passed,
      0 failed — up from Phase 2's 72)*

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the severity map has exactly seven MECHANICAL entries
(four BLOCKING: 1.2, 1.3, 1.5, 3.2; three ADVISORY: 2.1, 2.3, 3.3). Confirm by diffing the map's
keys against `MECH_RULES` and against the header's own rule inventory lines, not by assumption —
if the header and map disagree, the header is the source of truth and the discrepancy is reported.

**Files to modify**:
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` - `RULE_SEVERITY` map;
  severity-aware `emit_not_evaluated`; `TOTAL_BLOCKING_SKIPPED` counter; Summary line; qualified
  PASSED banner; header posture documentation
- `agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh` - qualified-banner
  case and ADVISORY-only unqualified-banner case

**Verification**:
- Full suite green, 0 failed, passed count higher than Phase 2's.
- A bib-less run prints `[WARN]`, the qualified banner, and still exits 0.
- An ADVISORY-only run's banner carries no qualifier.
- No existing `assert_exit` or `assert_not_contains` assertion was changed to accommodate the new
  output (ACCEPTANCE 8).

---

### Phase 4: End-to-end acceptance verification [COMPLETED]

**Goal**: All eight ACCEPTANCE items demonstrated by execution, and the source-store/deploy
boundary confirmed intact.

**Tasks**:
- [x] Run the live reproduction using the **source-store** script (not the stale deployed copy) in
      the reproduction repo, read-only:
      `bash /home/benjamin/.config/nvim/agent-system/extensions/typst/scripts/chapter-quality-check.sh
      --verbose /home/benjamin/Projects/Logos/Verification/typst/manual/chapters/01-introduction.typ`
      and confirm Rule 1.3 now **evaluates** against `typst/manual/bibliography.bib` rather than
      reporting NOT EVALUATED (ACCEPTANCE 4 and 5 in their live form). Make no edits in that repo.
      *(completed: see below and progress/phase-4-progress.json)*
- [x] Record the before/after output lines side by side in the phase's progress record.
      *(completed)*
- [x] Re-run all five `detect_task_type` probes from Phase 1 as a regression check (ACCEPTANCE 2, 3).
      *(completed: all five unchanged from Phase 1)*
- [x] Re-run the full test suite one final time (ACCEPTANCE 6). *(completed: 83 passed, 0 failed)*
- [x] Confirm `git diff --name-only` since the task's first commit touches only the four files in
      the declared `file_scope`, and that nothing under any `.claude/` tree was modified
      (SCOPE DISCIPLINE, source-store-deploy-boundary rule). *(completed: this task's three
      commits touch exactly the four declared file_scope paths plus this task's own specs/
      artifacts; zero .claude/** paths)*
- [x] Confirm `scripts/typst-element-lint.sh` and `index-entries.json` still carry only their
      pre-existing, unstaged modifications — untouched and uncommitted by this task.
      *(completed: both remain modified-but-uncommitted, unchanged by this task)*
- [x] Walk the eight ACCEPTANCE items one by one and record, for each, the command run and its
      observed output. Any item that cannot be demonstrated is reported as an explicit exclusion,
      not quietly marked done. *(completed: see the ACCEPTANCE table in the implementation summary)*

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts all eight ACCEPTANCE items are satisfiable and that
exactly four files changed. Confirm by executing each item's own check and by
`git diff --name-only`; if fewer than eight are demonstrable, report which and why rather than
recording a pass.

**Files to modify**:
- none planned (verification only; a defect found here is fixed in the owning phase, which is
  reopened rather than patched from this phase)

**Verification**:
- Live Logos/Verification run shows Rule 1.3 evaluated, with the resolved `.bib` path named.
- Test suite 0 failed.
- All five detection probes produce the expected types.
- `git diff --name-only` lists only the four declared `file_scope` paths; no `.claude/**` path.
- An eight-item ACCEPTANCE table with per-item evidence exists in the task summary.

---

## Testing & Validation

- [ ] Pre-edit baseline recorded: `bash agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh`
      -> "59 passed, 0 failed".
- [ ] `jq -e '.keyword_overrides.typst.keywords | length == 13' agent-system/extensions/typst/manifest.json`.
- [ ] Five `detect_task_type` probes (3 positive incl. the plural form, 2 negative-control).
- [ ] Keyword collision audit across all `agent-system/extensions/*/manifest.json`.
- [ ] New test cases: BUG 2a/2c positive, BUG 2a/2c negative twin, BUG 2b vendored-`.bib`,
      qualified-banner, ADVISORY-only unqualified-banner, `dirscan` NOT-EVALUATED guard.
- [ ] case-f re-examined, unmodified, disposition comment added.
- [ ] Final suite green with a strictly higher passed count and 0 failed.
- [ ] Live read-only reproduction against `/home/benjamin/Projects/Logos/Verification`.
- [ ] `git diff --name-only` confined to the four declared `file_scope` paths.

## Artifacts & Outputs

- `agent-system/extensions/typst/EXTENSION.md` - reconciled `### Scope` section
- `agent-system/extensions/typst/manifest.json` - 13-entry `keyword_overrides.typst.keywords`
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` - three-branch bibliography
  resolution, vendored-dir exclusions, severity-aware NOT-EVALUATED surfacing, updated header
  contract
- `agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh` - six new
  assertions/cases, case-f disposition comment
- `specs/255_typst_scope_and_chapter_quality_bib_resolution/summaries/01_*-summary.md` - execution
  summary carrying the eight-item ACCEPTANCE evidence table
- Three commits, one per code phase (Part 1; Part 2 resolution; Part 2 surfacing)

## Rollback/Contingency

Each phase is one independently revertable commit with a disjoint or strictly-ordered file set, so
the normal contingency is `git revert <sha>` of the offending phase commit — no working-tree
discard required, and nothing in this plan calls for one.

If an in-flight phase must be abandoned mid-edit while uncommitted changes exist, take a
**durable, non-reverting** checkpoint first (`bash .claude/scripts/git-snapshot.sh 255
--no-revert`, per `context/patterns/checkpoint-before-overflow.md`) and then hand off; do not emit
a bare default-mode `git-snapshot.sh 255` as a routine precaution. A genuine whole-tree rollback —
which this plan does not anticipate, and which would be complicated by the pre-existing unstaged
`typst-element-lint.sh` edits this task must not disturb — follows
`context/contracts/recovery.md`'s rollback rung, including its `--allow-out-of-scope` override,
and requires confirming with the user first given those foreign uncommitted edits.

Partial-completion contingency: Part 1 (Phase 1) and Part 2 (Phases 2-3) are independently
valuable and independently committable. If Part 2 stalls, Phase 1 still fixes routing and should
be left committed; if Part 1 stalls, Phases 2-3 still fix the gate. Record whichever half is
incomplete as an explicit exclusion rather than scaling the task down silently.
