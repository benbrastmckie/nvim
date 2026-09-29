# Implementation Plan: Task #51

- **Task**: 51 - Move session runtime files out of the specs root and make the reap path run
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: None (task 143 and task 209 are both completed/archived and non-blocking)
- **Research Inputs**: specs/051_move_session_state_files_out_of_specs_root/reports/01_relocate-widen-reap-wire-todo.md
- **Artifacts**: plans/01_relocate-widen-reap-wire-todo.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/standards/task-reference-exemptions.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Session-scoped orchestration runtime files accumulate unbounded at the `specs/` root because the
only trigger for `reap-session-runtime-files.sh` is a manual `/refresh`. This plan wires that
reaper (plus `task-lock.sh session-reap`) into `/todo` — the repo's frequently-run housekeeping
command — as the acceptance-critical deliverable; widens the reaper's own literal glob so
superseded naming generations become reapable; remediates one currently git-tracked orphan of a
retired convention; and relocates the two live singletons into `specs/.orchestration/` so the
`specs/` root stops carrying runtime scratch at all. Definition of done: a live `/todo` run
reports and reaps stale runtime files, `check-runtime-file-tracking.sh` and
`scripts/tests/run-all.sh` are green, and no file matching the two runtime classes is written to
the `specs/` root by any live writer.

### Research Integration

Key findings from `reports/01_relocate-widen-reap-wire-todo.md` that shape this plan:

- **The gitignore side is already correct.** `runtime-file-patterns.sh`'s
  `**/.orchestrator-multi-state*.json` and `**/.return-meta-*.json` are shell globs that already
  tolerate all four naming generations at any depth. The defect is confined to
  `reap-session-runtime-files.sh`'s own literal bash candidate array, which requires a literal
  hyphen. This reduces Part (2) to a one-file fix (Phase 2) — no migration script needed.
- **Part (3) has a ready-made reference implementation.** `skill-refresh/SKILL.md` Steps 4.5/4.6
  (lines 207-263) are a directly portable template for both required calls, already reusing a
  single `dry_run` boolean and already honoring `ORCHESTRATOR_SESSION_REAP_MIN` (240min) and
  `SESSION_REGISTRY_REAP_MIN` (240min) unchanged — so "honor the existing threshold" needs zero
  code.
- **The `/todo` hook point is real and unconditional.** `skill-todo/SKILL.md` uses
  `<stage id="N" name="...">` tags; Stage 8 (`DryRunOutput`) is the *only* early exit, so every
  non-`--dry-run` invocation falls through Stages 9-16 regardless of whether any task was
  actually archived. A new `<stage id="14.5">` between Stage 10 (`ArchiveTasks`) and Stage 15
  (`GitCommit`) therefore runs on frequency, not on archival volume.
- **Stage 15's staging is a fixed explicit path list**, never a `specs/`-wide add, so reaped
  deletions (all on gitignored paths) need no git interaction at all. The task's "land in the
  same commit" phrasing is read as *sequencing/reporting*, not a staging requirement — with one
  exception: the tracked orphan in Phase 3 genuinely needs `git rm --cached` and its own commit.
- **A newly-found, currently git-tracked orphan**:
  `specs/.meta-return-sess_1790273700_meta01.json` (committed at `a38456608`/`f3bded704`) belongs
  to a retired `/meta` return-file convention with zero writer and zero reader. Because
  "meta-return" (reversed word order) has never been a canonical class member,
  `check-runtime-file-tracking.sh`'s Check B never scans for it and reports a clean PASS despite
  the tracked file. Remediation is `git rm --cached`, not `rm -f`.

### Divergence from the research report (measured during planning)

The report's blast-radius table listed **one** test fixture for Part (1)
(`scripts/test-session-runtime-files.sh`). A direct grep during planning found **seven** test
files carrying literal `specs/.orchestrator-multi-state-*` / `specs/.return-meta-multi-*` paths,
totalling ~121 references:

| Test file | References |
|-----------|-----------|
| `scripts/tests/test-orchestrate-cycle-plan.sh` | 92 |
| `scripts/test-session-runtime-files.sh` | 13 |
| `scripts/tests/test-orchestrate-cycle-postflight.sh` | 7 |
| `scripts/tests/test-orchestrate-context-growth.sh` | 3 |
| `scripts/tests/test-init-specs.sh` | 3 |
| `scripts/tests/test-force-phases.sh` | 2 |
| `scripts/tests/test-orchestrate-unwind-dispatch.sh` | 1 |

These break because the writers derive the path as
`"$(dirname "$STATE_FILE")/.orchestrator-multi-state-${session_id}.json"` and the tests assert on
`$WORKDIR/specs/.orchestrator-multi-state-*.json` fixtures. The churn is mechanical (one
`sed`-shaped substitution per file plus a `mkdir -p` in setup), not conceptually hard, but it is
~100x the volume the report implied. Part (1) is planned in full here (Phases 4-6) because the
task description names it as in scope; the concern to flag is that relocation is the *cosmetic*
half — the task's own evidence-refresh says relocation "leaves the growth rate untouched" — so if
any phase must be dropped under time pressure, Phases 4-6 are the ones to drop, never Phase 1.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag was set; ROADMAP.md was not
consulted.

### Scope additions this plan requests

`file_scope` already covers Parts 2 and 3 and Part 1's writer/reader/doc sites. Phase 5 adds the
six additional test files above beyond `scripts/test-session-runtime-files.sh`, plus
`scripts/tests/test-runtime-file-tracking.sh` and `scripts/lib/deploy-ledger-lib.sh` (a
one-line comment mention). These are declared in the phases' `Files to modify` lists, which is
the harvest source `plan-file-scope-harvest.sh` reads at plan postflight.

## Goals & Non-Goals

**Goals**:
- Wire `reap-session-runtime-files.sh` and `task-lock.sh session-reap` into `/todo` as a new,
  non-blocking, threshold-respecting stage, without changing `/refresh`'s existing invocation.
- Widen `reap-session-runtime-files.sh`'s candidate globs so all four naming generations
  (un-suffixed, hyphen-suffixed, dot-separator, `.prev-`) are reapable.
- Untrack the one tracked orphan of the retired "meta-return" convention and document the
  coverage limit that hid it.
- Relocate `.orchestrator-multi-state-{sid}.json` and `.return-meta-multi-{sid}.json` into
  `specs/.orchestration/`, updating every writer, reader, reaper glob, gitignore-class member,
  verification probe, test fixture, and doc mention — with no fourth orphaned generation created.

**Non-Goals**:
- Adding a permanent reap glob or gitignore pattern for the three fully-dead shapes
  (`.return-meta-meta.json`, `.return-meta-meta-sess_{sid}.json`, `.meta-return.json`). With zero
  live writer there is no ongoing accumulation to guard; a one-shot untrack plus a documented
  manual-hunt recipe is the sanctioned disposition (Phase 3).
- A one-shot legacy-name migration script. Widening the reaper's existing glob is cheaper,
  permanent, and protects every consumer repo rather than sweeping this one once.
- Recursing the reaper into `specs/{NNN}_{SLUG}/` per-task runtime files — already correctly
  isolated by task directory and explicitly out of the reaper's documented scope.
- Sweeping the other four affected repos (BimodalLogic, cslib, ModelChecker, PersonalWebsite).
  Their fix arrives via the next deploy of the core extension; no cross-repo action is taken here.
- Changing `ORCHESTRATOR_SESSION_REAP_MIN` / `SESSION_REGISTRY_REAP_MIN` defaults or adding new
  threshold logic.
- Creating any pull request or pushing (see `.claude/rules/pr-prohibition.md`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Territory collision: `orchestrate-cycle-plan.sh` and `docs/architecture/orchestrate-state-machine.md` sit in sibling task 265's declared `file_scope`; `orchestrate-cycle-postflight.sh`, `skill-orchestrate/SKILL.md` and `context/formats/return-metadata-file.md` sit in sibling task 263's — and `test-orchestrate-cycle-plan.sh` / `test-orchestrate-cycle-postflight.sh` sit in theirs too | H | M | Both siblings are in `plan` phase this cycle, not implement. Per `context/contracts/territory.md` (Cross-Task Territory): re-read each file immediately before editing; stage only this task's own hunks with an explicit file list (never a directory/glob `git add`); on observing a foreign commit or foreign uncommitted modification, STOP and report rather than proceeding |
| A new `/todo` reap stage fires during `--dry-run`, or reaps an in-flight batch | H | L | Reuse the exact `dry_run` boolean already parsed by `skill-todo/SKILL.md` Stage 1, mirroring `skill-refresh` Steps 4.5/4.6's branch structure verbatim; rely on the unchanged 240-minute thresholds — no new threshold logic |
| `git rm --cached` on the tracked orphan, if done as a plain `rm -f`, leaves a staged deletion needing its own commit and a dirty tree | M | M | Phase 3 uses `git rm --cached` explicitly and commits that single path on its own |
| Relocation creates a fourth orphaned generation: pre-migration root-level files in five repos become unreapable once the reaper only looks in the new directory | H | M | Phase 5 keeps the legacy root globs *in addition to* the new `specs/.orchestration/` globs — the reaper sweeps both locations permanently, so every already-stranded file in every consumer repo stays reapable |
| Adding a 19th runtime-file class member desynchronizes the lib from the `orchestrator-runtime-files.md` "Consumer Repo Setup" block, failing `test-runtime-file-tracking.sh` Case 3 | M | M | Change the lib and the doc block in the SAME phase (Phase 4). Note Case 3 resolves lib+doc from one tree root (`.claude` first), so it compares a consistent pair mid-implementation and only reflects the source-store change after Phase 7's redeploy |
| Relocation is the cosmetic half and consumes ~60% of this plan's effort while leaving the growth rate untouched | M | H | Phase 1 (the acceptance-critical wire-up) is Wave 1 and depends on nothing, so it lands and commits before any relocation work starts. Phases 4-6 are the designated drop candidates if effort must be cut |
| `specs/.orchestration/` shows as an untracked directory in `git status` | L | L | Phase 4 adds `**/.orchestration/` as a directory-class member (mirroring `.sessions/`, `.dispatch/`, `.deploy-lock/` precedent) rather than relying on the two basename patterns alone; Phase 5 verifies `git status --porcelain` stays clean |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 2, 3 |
| 3 | 5, 6 | 4 |
| 4 | 7 | 1, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Wire the reap pair into /todo [COMPLETED]

**Goal**: `/todo` reaps stale session-scoped orchestration files and stale session-registry
entries on every live invocation, reporting both verbatim, with `/refresh`'s behavior unchanged.
This is the acceptance-critical deliverable.

**Tasks**:
- [x] Read `skills/skill-refresh/SKILL.md` Steps 4.5 and 4.6 (lines ~207-263) as the porting
      template — note the `if [ "$dry_run" = true ]` / `--dry-run` passthrough branch and the
      "echo its output verbatim rather than summarizing it away" instruction *(completed)*
- [x] Confirm `skill-todo/SKILL.md` Stage 1 (`ParseArguments`) sets a `dry_run` boolean and that
      Stage 8 (`DryRunOutput`) is the only early exit; record the variable's exact name *(completed)*
- [x] Insert `<stage id="14.5" name="ReapRuntimeFiles">` into `skills/skill-todo/SKILL.md`
      between Stage 14 (`CreateMemories`, line ~936) and Stage 15 (`GitCommit`, line ~977),
      containing both calls (`.claude/scripts/reap-session-runtime-files.sh` and
      `.claude/scripts/task-lock.sh session-reap`) under the same `dry_run` branch shape as
      `skill-refresh` Steps 4.5/4.6 *(completed)*
- [x] State in the stage body that it is non-blocking (a nonzero exit or missing script is logged
      and stepped over, never failing `/todo`) and that both thresholds are honored unchanged *(completed)*
- [x] Add a `Runtime file reap` bullet to Stage 16 (`OutputResults`)'s summary list, following the
      same verbatim-echo convention *(completed)*
- [x] Add `### 5.8. Reap Stale Session Runtime Files` to `commands/todo.md` between
      `### 5.7. Vault Operation` (line ~779) and `### 6. Git Commit` (line ~906), mirroring
      `commands/refresh.md`'s own two reap subsections (lines ~140-180) in prose shape *(completed)*
- [x] Note explicitly in both files that Stage 15's staging is a fixed explicit path list, so
      reaped (gitignored) deletions require no git interaction *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that `skill-todo/SKILL.md` Stage 8 is the only early
exit, that Stage 1 defines a reusable `dry_run` boolean, and that `commands/todo.md` §5.7 is the
last step before §6. Confirm at implementation time by re-grepping `<stage id=` in
`skill-todo/SKILL.md` and `^### ` in `commands/todo.md` before inserting — the line numbers above
are planning-time observations, not facts.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` - new `<stage id="14.5" name="ReapRuntimeFiles">` between Stages 14 and 15; new summary bullet in Stage 16
- `agent-system/extensions/core/commands/todo.md` - new `### 5.8.` documentation subsection between §5.7 and §6

**Verification**:
- `bash -n` on the new stage's extracted bash block (write it to a scratch file and syntax-check)
- `bash agent-system/extensions/core/scripts/reap-session-runtime-files.sh --dry-run` and
  `bash agent-system/extensions/core/scripts/task-lock.sh session-reap --dry-run` both run clean
  from the repo root, confirming the invocation text in the new stage is correct as written
- `grep -c '<stage id=' skills/skill-todo/SKILL.md` increases by exactly 1
- `git diff HEAD -- agent-system/extensions/core/skills/skill-refresh/SKILL.md` is empty at the
  end of this phase (`/refresh` untouched here; its prose paths are updated later, in Phase 6,
  while its two bash invocation blocks stay byte-identical throughout)

---

### Phase 2: Widen the reaper's candidate globs [NOT STARTED]

**Goal**: `reap-session-runtime-files.sh` sweeps all four naming generations of both file
families, and `extract_session_id` parses the session id out of each shape.

**Tasks**:
- [ ] Replace the two-entry `candidates=( ... )` array with one covering, for each family, the
      un-suffixed (`.orchestrator-multi-state.json`), hyphen-suffixed
      (`.orchestrator-multi-state-*.json`), dot-separator (`.orchestrator-multi-state.*.json`) and
      `.prev-` (`.orchestrator-multi-state.prev-*.json`) shapes, and the `.return-meta-multi`
      equivalents — keeping `shopt -s nullglob` around it and de-duplicating any path a widened
      glob matches twice
- [ ] Extend `extract_session_id` to strip the dot-separator and `.prev-` prefixes in addition to
      the two existing hyphen prefixes, keeping the existing `jq -r '.session_id'` fallback
- [ ] Update the script's header comment block (`# Scope:` and the `# Filename shape:` note above
      `extract_session_id`) to name all four shapes and state why widening was chosen over a
      one-shot migration (the gitignore side already tolerates all four; widening protects every
      consumer repo permanently)
- [ ] Add cases to `scripts/test-session-runtime-files.sh` asserting each of the three previously
      unreapable shapes is now reaped when stale, and that a fresh one of each is left alone

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: asserts exactly four naming generations per family (eight globs total) and
that no live writer produces any but the hyphen-suffixed shape. Confirm at implementation time
with `grep -rn 'orchestrator-multi-state\|return-meta-multi' agent-system/extensions/core/` and
check the writer list (`skill-orchestrate/SKILL.md`, `orchestrate-cycle-plan.sh`,
`orchestrate-cycle-postflight.sh`, `orchestrate-unwind-dispatch.sh`) before finalizing the array.

**Files to modify**:
- `agent-system/extensions/core/scripts/reap-session-runtime-files.sh` - widened `candidates` array, extended `extract_session_id`, updated header comments
- `agent-system/extensions/core/scripts/test-session-runtime-files.sh` - new cases per superseded shape (stale-reaped and fresh-spared)

**Verification**:
- `bash -n agent-system/extensions/core/scripts/reap-session-runtime-files.sh` and
  `shellcheck` on the same file report no new findings
- `bash agent-system/extensions/core/scripts/test-session-runtime-files.sh` passes, including the
  new cases
- `bash agent-system/extensions/core/scripts/reap-session-runtime-files.sh --dry-run` from the
  repo root reports the live root-level litter without deleting anything

---

### Phase 3: Untrack the retired-convention orphan and document the coverage limit [NOT STARTED]

**Goal**: `specs/.meta-return-sess_1790273700_meta01.json` is no longer git-tracked, and
`orchestrator-runtime-files.md` records why Check B cannot see a retired convention's litter plus
the manual recipe for hunting one.

**Tasks**:
- [ ] Re-confirm the file is tracked and unmodified against HEAD
      (`git ls-files -- specs/.meta-return-sess_1790273700_meta01.json`,
      `git diff HEAD -- <path>` empty)
- [ ] `git rm --cached specs/.meta-return-sess_1790273700_meta01.json` (never `rm -f` — the
      working-tree copy is already gitignored by `**/.return-meta-*.json`... verify this with
      `git check-ignore -v` first; if it is NOT ignored, delete the working-tree copy too and say
      so in the commit message)
- [ ] Add a short subsection to `context/standards/orchestrator-runtime-files.md` — placed after
      the Class Table — recording: (a) Check B scans only the canonical class members, so a
      retired convention's tracked litter is invisible to it by construction; (b) the deliberate
      decision NOT to add a class member for a zero-writer dead convention; (c) the manual hunt
      recipe `git log --all --diff-filter=A -- '**/.{retired-name}*'`
- [ ] Commit the untrack plus the doc note together as this phase's single green sub-step

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: asserts exactly one such tracked orphan exists in this repo. Confirm with
`git ls-files specs/ | grep -E '\.meta-return|\.return-meta-meta'` before editing; if more turn
up, untrack each and say so rather than assuming the count.

**Files to modify**:
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - new "Retired conventions and Check B's coverage limit" subsection after the Class Table
- `specs/.meta-return-sess_1790273700_meta01.json` - untracked via `git rm --cached` (no content edit)

**Verification**:
- `git ls-files -- specs/.meta-return-sess_1790273700_meta01.json` returns empty
- `git check-ignore -v specs/.meta-return-sess_1790273700_meta01.json` names a managed pattern
  (so it cannot reappear in `git status`)
- `git status --porcelain` shows no unexpected staged or unstaged path
- `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` still exits 0

---

### Phase 4: Relocate the writers into specs/.orchestration/ [NOT STARTED]

**Goal**: every live writer and reader of the two singletons resolves them under
`specs/.orchestration/`, creating the directory on demand, and the runtime-file class lib plus its
pinned doc block carry the new directory-class member.

**Tasks**:
- [ ] Add a single shared path resolver rather than four independent string literals — a small
      function in `scripts/lib/runtime-file-patterns.sh` (e.g.
      `runtime_mt_state_path <specs_dir> <session_id>` and a `return-meta-multi` sibling) — so a
      future rename touches one site
- [ ] Update `scripts/orchestrate-cycle-plan.sh` (~line 495) and its header comment (~lines
      167-168) to resolve `mt_state_file` under `<dirname STATE_FILE>/.orchestration/`, with
      `mkdir -p` before first write
- [ ] Update `scripts/orchestrate-cycle-postflight.sh` (~line 317) and its header comment
      (~line 75) identically
- [ ] Update `scripts/orchestrate-unwind-dispatch.sh` (~line 300) and its header comment
      (~line 39) identically (read path — no `mkdir -p` needed)
- [ ] Update `skills/skill-orchestrate/SKILL.md` Stage MT-1's `mt_state_file=` (~line 92) and the
      `.return-meta-multi-${session_id}.json` write (~line 269), adding the `mkdir -p` step
- [ ] Add `orchestration` as the 19th member of `runtime-file-patterns.sh`'s four index-aligned
      arrays: id `orchestration`, pattern `**/.orchestration/`, probe
      `specs/.orchestration/.orchestrator-multi-state-sess_0000000000_probe.json`, Check B regex
      `/\.orchestration/`; and repoint the existing `orchestrator-multi-state` probe to the new
      directory
- [ ] Update `context/standards/orchestrator-runtime-files.md` in the SAME commit as the lib: the
      "Consumer Repo Setup" fenced pattern block (must stay byte-identical to
      `runtime_ignore_block()`'s output) and a new Class Table row for `specs/.orchestration/`,
      plus the two existing rows' paths

**Timing**: 1.75 hours

**Depends on**: 2, 3

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: asserts exactly four writer/reader code sites and that
`runtime-file-patterns.sh`'s arrays are index-aligned 1:1 with 18 current members. Confirm with
`grep -rn 'mt_state_file=\|return-meta-multi-\${' agent-system/extensions/core/` (excluding
`scripts/tests/`) and by re-reading the lib's four `declare -a` arrays before editing. Re-read
`orchestrate-cycle-plan.sh` and `orchestrate-cycle-postflight.sh` immediately before touching
them — sibling territory.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` - shared path resolver; 19th `orchestration` class member across all four arrays; repointed `orchestrator-multi-state` probe
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - `mt_state_file` resolution + `mkdir -p` + header comment
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - `mt_state_file` resolution + header comment
- `agent-system/extensions/core/scripts/orchestrate-unwind-dispatch.sh` - `mt_state_file` read path + header comment
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Stage MT-1 `mt_state_file=`, the `.return-meta-multi` write, and the new `mkdir -p` step
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - Consumer Repo Setup pattern block (lockstep with the lib), new `specs/.orchestration/` Class Table row, updated paths on the two existing rows

**Verification**:
- `bash -n` plus `shellcheck` clean on all four shell files and the lib
- `bash agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` passes —
  specifically Case 3 (lib-to-doc pin) and Case 5 (arrays stay 1:1 by construction)
- `grep -rn 'specs/\.orchestrator-multi-state-\|specs/\.return-meta-multi-' agent-system/extensions/core/scripts/ agent-system/extensions/core/skills/ | grep -v '/tests/'`
  returns no live *writer* path (comments and legacy-glob entries in the reaper are expected)

---

### Phase 5: Extend the reaper and repoint every test fixture [NOT STARTED]

**Goal**: the reaper sweeps both `specs/.orchestration/` and the legacy `specs/` root (so already
stranded files in all five affected repos stay reapable), and all seven test suites carrying
literal paths assert against the new location.

**Tasks**:
- [ ] Extend `reap-session-runtime-files.sh`'s candidate array (widened in Phase 2) with the same
      four shapes per family under `specs/.orchestration/`, **keeping every legacy root glob** —
      state in the header comment that the root globs are permanent legacy coverage, not
      transitional, so no fourth orphaned generation is created
- [ ] Update the reaper's `rel_path` computation so reported paths are correct for both locations
      (currently hardcoded `specs/$(basename "$f")`)
- [ ] Repoint the literal paths in `scripts/test-session-runtime-files.sh` (13 refs), adding
      `mkdir -p "$TMPROOT/specs/.orchestration"` to setup, and add a case asserting a legacy
      root-level stale file is still reaped
- [ ] Repoint `scripts/tests/test-orchestrate-cycle-plan.sh` (92 refs) with one mechanical
      substitution (`/specs/.orchestrator-multi-state-` -> `/specs/.orchestration/.orchestrator-multi-state-`),
      adding `mkdir -p "$WORKDIR/specs/.orchestration"` to setup; re-read the file immediately
      before editing (sibling territory)
- [ ] Repoint `scripts/tests/test-orchestrate-cycle-postflight.sh` (7 refs) the same way; re-read
      first (sibling territory)
- [ ] Repoint `scripts/tests/test-orchestrate-context-growth.sh` (3 refs, including its
      `compgen -G` and `git status --porcelain` assertions),
      `scripts/tests/test-init-specs.sh` (3 refs), `scripts/tests/test-force-phases.sh` (2 refs),
      and `scripts/tests/test-orchestrate-unwind-dispatch.sh` (1 ref)
- [ ] Update `scripts/tests/test-runtime-file-tracking.sh` only if Phase 4's 19th member requires
      it (Case 3 and Case 5 are generated from the lib, so likely a no-op — confirm, do not assume)

**Timing**: 1.75 hours

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: asserts seven test files and ~121 literal references (92/13/7/3/3/2/1 as
tabulated in "Divergence from the research report" above). Confirm at implementation time with
`grep -rc 'orchestrator-multi-state\|return-meta-multi' agent-system/extensions/core/scripts/tests/*.sh agent-system/extensions/core/scripts/test-*.sh`
and reconcile against the table before starting — a count mismatch means a file was added or
edited since planning.

**Files to modify**:
- `agent-system/extensions/core/scripts/reap-session-runtime-files.sh` - new-location globs added alongside permanent legacy root globs; two-location-aware `rel_path`
- `agent-system/extensions/core/scripts/test-session-runtime-files.sh` - repointed fixtures, `.orchestration` setup, new legacy-root-still-reaped case
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - repointed fixture paths, `.orchestration` setup
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - repointed fixture paths
- `agent-system/extensions/core/scripts/tests/test-orchestrate-context-growth.sh` - repointed fixture paths and `compgen`/`git status` assertions
- `agent-system/extensions/core/scripts/tests/test-init-specs.sh` - repointed fixture paths
- `agent-system/extensions/core/scripts/tests/test-force-phases.sh` - repointed fixture paths
- `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh` - repointed fixture path
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` - only if Phase 4's new class member needs it (expected no-op; confirm)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` fully green (this is the phase's
  gate, not a per-file check)
- `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` exits 0
- A scratch end-to-end check: create a stale file in both `specs/.orchestration/` and at the
  `specs/` root inside a temp root, run the reaper, confirm both are reaped and reported with
  correct relative paths
- `git status --porcelain` in this repo stays clean with respect to `specs/.orchestration/`

---

### Phase 6: Documentation sweep for the relocated paths [NOT STARTED]

**Goal**: no prose in the source store still names `specs/.orchestrator-multi-state-{sid}.json` or
`specs/.return-meta-multi-{sid}.json` at the `specs/` root as the live location.

**Tasks**:
- [ ] `commands/refresh.md` (~lines 155-156): update the two paths in the reap documentation
- [ ] `commands/orchestrate.md` (~line 238): update the `mt_state_file` path
- [ ] `commands/todo.md`: update the paths in the §5.8 subsection added in Phase 1
- [ ] `docs/architecture/orchestrate-state-machine.md` (~lines 1011, 1038): update both paths;
      re-read immediately before editing (sibling territory)
- [ ] `context/patterns/batch-orchestration-guardrails.md` (~line 798): update the path
- [ ] `context/patterns/orchestrate-batch-results-template.md` (~line 143): update the
      `.return-meta-multi.json` mention
- [ ] `context/formats/return-metadata-file.md` (~lines 84, 122): update both mentions; re-read
      immediately before editing (sibling territory)
- [ ] `skills/skill-refresh/SKILL.md` (~lines 209-210): update Step 4.5's two paths — prose only,
      the invocation itself stays byte-identical
- [ ] `scripts/lib/deploy-ledger-lib.sh` (~line 12): update the comment's path mention
- [ ] Final sweep: `grep -rn 'specs/\.orchestrator-multi-state\|specs/\.return-meta-multi' agent-system/extensions/core/`
      returns only intentional legacy-coverage mentions in the reaper and its tests

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: asserts nine prose-only files with the mention counts above. Confirm with
the final-sweep grep before and after editing; a file that turns up unlisted gets updated and
named in the commit message rather than skipped.

**Files to modify**:
- `agent-system/extensions/core/commands/refresh.md` - reap-section paths
- `agent-system/extensions/core/commands/orchestrate.md` - `mt_state_file` path
- `agent-system/extensions/core/commands/todo.md` - §5.8 paths
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - both engine-state paths
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - session-suffixed path mention
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - `.return-meta-multi` mention
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - two path mentions
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md` - Step 4.5 prose paths only (invocation unchanged)
- `agent-system/extensions/core/scripts/lib/deploy-ledger-lib.sh` - header comment path mention

**Verification**:
- The final-sweep grep above returns only the reaper's and its tests' intentional legacy mentions
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` still green (no prose edit should
  move it, and any suite that greps doc text will catch a mistake)
- `diff` review confirms `skill-refresh/SKILL.md`'s two bash invocation blocks are byte-identical
  to HEAD

---

### Phase 7: Redeploy, run the full gate, and sweep the live litter [NOT STARTED]

**Goal**: the deployed `.claude/` tree carries every change, the repository-wide gate set is
green, and this repo's ~72 stranded root-level runtime files are actually gone.

**Tasks**:
- [ ] Regenerate the deploy tree from the source store
      (`bash agent-system/extensions/core/scripts/deploy-headless.sh`), so `.claude/scripts/`,
      `.claude/skills/skill-todo/`, `.claude/context/standards/` and each consumer repo's
      `specs/.gitignore` managed block pick up the 19th class member via `init-specs.sh`
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh` — all gates, including Gate 8
      (the shell test suite) and the deploy-parity gates
- [ ] `bash .claude/scripts/tests/run-all.sh` in deployed mode as well as source-store mode, since
      the two resolve different tree roots
- [ ] `bash .claude/scripts/check-runtime-file-tracking.sh` from the repo root — Checks A, B, C
      all pass with the new class member
- [ ] `bash .claude/scripts/tests/test-runtime-file-tracking.sh` — Case 3 now compares the
      *regenerated* deployed doc against the regenerated deployed lib
- [ ] Live sweep: `bash .claude/scripts/reap-session-runtime-files.sh --dry-run` first, review the
      per-file report, then run it live; confirm the root-level count drops to zero
- [ ] Confirm `/refresh`'s path still works: `bash .claude/scripts/task-lock.sh session-reap --dry-run`
- [ ] Record the before/after litter counts in the implementation summary

**Timing**: 0.75 hours

**Depends on**: 1, 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: asserts ~72 stranded root-level files (40 `.orchestrator-multi-state-*`,
32 `.return-meta-multi-*`, measured at planning time). Re-count immediately before the sweep with
`ls -A specs/ | grep -c '^\.orchestrator-multi-state-'` and the `.return-meta-multi-` equivalent;
report the actual numbers, never the planned ones. Note some files may be younger than the
240-minute threshold and correctly survive — that is a pass, not a failure.

**Files to modify**:
- `specs/.gitignore` - regenerated managed block from `init-specs.sh` (if the 19th member changes it)

No source file is hand-edited in this phase. The deployed `.claude/` tree is regenerated, never
hand-authored (see `.claude/rules/source-store-deploy-boundary.md`); it is gitignored and enters
no commit, so it is deliberately not listed as a path above.

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` exits 0
- `bash .claude/scripts/tests/run-all.sh` and
  `bash agent-system/extensions/core/scripts/tests/run-all.sh` both exit 0
- `bash .claude/scripts/check-runtime-file-tracking.sh` exits 0
- `ls -A specs/ | grep -Ec '^\.(orchestrator-multi-state|return-meta-multi|meta-return)'` reports
  0, or only files younger than `ORCHESTRATOR_SESSION_REAP_MIN`
- `git status --porcelain` shows no stray tracked or untracked runtime file

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/test-session-runtime-files.sh` — all cases,
      including the new superseded-shape and legacy-root cases
- [ ] `bash agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` — Cases 1-5,
      especially Case 3 (lib-to-doc pin) and Case 5 (array alignment)
- [ ] `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` — Checks A, B, C
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` — source-store mode
- [ ] `bash .claude/scripts/tests/run-all.sh` — deployed mode
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh` — every gate
- [ ] `shellcheck` and `bash -n` on every shell file this plan edits
- [ ] Behavioral check: a stale file in each of the eight glob shapes (four per family) in both
      locations is reaped; a fresh one in each is spared
- [ ] Behavioral check: `/todo --dry-run` performs no reap; a live `/todo` reports both reap
      outputs verbatim and does not fail when a reap script exits nonzero
- [ ] Regression check: `/refresh`'s Steps 4.5/4.6 invocations are byte-identical to HEAD

## Artifacts & Outputs

- `specs/051_move_session_state_files_out_of_specs_root/plans/01_relocate-widen-reap-wire-todo.md`
  (this plan)
- `specs/051_move_session_state_files_out_of_specs_root/summaries/01_relocate-widen-reap-wire-todo-summary.md`
  (at implementation completion)
- Source-store edits across 18 files under `agent-system/extensions/core/` (enumerated per phase)
- One `git rm --cached` untracking `specs/.meta-return-sess_1790273700_meta01.json`
- A regenerated `.claude/` deploy tree (gitignored) and a possibly-regenerated `specs/.gitignore`
  managed block
- A measured before/after litter count recorded in the summary

## Rollback/Contingency

Each phase commits its own green sub-steps, so rollback is per-phase `git revert` of that phase's
commits — the preferred route, and the only one that is safe while sibling tasks share this
working tree.

If a phase must be abandoned mid-edit with uncommitted changes, take a durable, non-reverting
checkpoint first (`bash .claude/scripts/git-snapshot.sh 51 --no-revert`, per
`context/patterns/checkpoint-before-overflow.md`) and then revert only this task's own paths
individually. Do **not** reach for a whole-tree rollback: siblings 263 and 265 may have
uncommitted work in this same tree. If a genuine whole-tree rollback is unavoidable, follow
`context/contracts/recovery.md`'s rollback rung exactly, including its `--allow-out-of-scope`
override, and report the decision rather than performing it silently.

Phase-specific contingencies:

- **Phase 1** is independently revertable and carries no dependency, so a failure there does not
  block Phases 2-6. It is also the acceptance-critical half — if anything else fails, Phase 1's
  commit must survive.
- **Phase 3**'s untrack is reversed with `git reset HEAD -- <path>` before commit, or
  `git revert` after. The working-tree copy is never deleted, so no data is lost either way.
- **Phases 4-6** (relocation) are revertable as a unit. Because the reaper retains permanent
  legacy root-glob coverage (Phase 5), reverting relocation leaves the writers back at the
  `specs/` root with the reaper still sweeping them — a consistent state, not a broken one.
- **Phase 7**'s redeploy is idempotent: re-running `deploy-headless.sh` after any revert restores
  the deployed tree to match the source store.
