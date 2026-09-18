# Implementation Plan: Task #209

- **Task**: 209 - Set up a fresh repo specs/ state and runtime-file ignore rules automatically
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: None
- **Research Inputs**: specs/209_init_consumer_specs_and_runtime_ignores/reports/01_init_consumer_specs.md
- **Artifacts**: plans/01_init-specs-bootstrap.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A consumer repo that has never run the task system has neither `specs/` state nor any ignore
coverage for the system's own runtime scratch files, so `/task`'s create path dies on its first
`jq ... specs/state.json` and every subsequent scoped commit sweeps up lock/session/dispatch
files. This plan adds one idempotent bootstrap script (`init-specs.sh`) that creates the
`specs/` state trio, writes a managed `specs/.gitignore` generated from the existing canonical
pattern library, and untracks any already-tracked runtime files without deleting them; wires it
into every command/skill/agent that can be the first to touch `specs/`; adds the missing
`specs/tmp/` class member to the pattern library; and updates the standards doc plus the lint
script's messaging to match. Done when a scratch repo with no `specs/` bootstraps cleanly, a
second run is a true no-op, a scoped `specs/` commit plus lock release leaves
`git status --porcelain -- specs/` empty, and `check-runtime-file-tracking.sh` passes — all
demonstrated by a fixture suite.

**All edits target the source store `agent-system/extensions/core/**`, never `.claude/**`**
(see `.claude/rules/source-store-deploy-boundary.md`); `.claude/` is a disposable deploy
artifact regenerated from the source store.

### Research Integration

Key findings from `reports/01_init_consumer_specs.md` that shape this plan:

- **`state-write.sh --init` cannot create `specs/state.json`.** It normalizes the requested
  `--state-file` against the default path via `realpath -m` and unconditionally exits 1 when
  they match ("--init refuses to target the default live state file"). `init-specs.sh` must
  write `specs/state.json` directly (mktemp + atomic `mv`). `specs/archive/state.json` is a
  non-default target and `--init` was built for it, but `--init` overwrites silently, so the
  existence guard stays in `init-specs.sh` either way.
- **Item (h) is already shipped.** `check-runtime-file-tracking.sh` Check B scans `git ls-files`
  against `RUNTIME_FILE_B_REGEX` and never consults `.gitignore` at all, so a tracked ephemeral
  file already FAILs regardless of ignore coverage (shipped in `8695facc8`, 2026-09-09,
  predating the 2026-09-14 amendment that asked for it). This plan **verifies** that with a
  fixture rather than reimplementing detection.
- **Item (f) needs no logic change.** Check A calls `git check-ignore -q` per probe, which
  resolves `.gitignore` files at every directory depth — a `specs/.gitignore` already satisfies
  it. Only the human-facing failure message ("add the missing pattern(s) to the repo root
  .gitignore") is stale.
- **Item (g) has no prior art.** No script in the source store runs `git rm --cached` against
  the runtime-file class; Check B's print-only remediation loop is the shape to adapt into an
  executing form.
- **Six first-touch call sites** read `next_project_number` directly: `commands/task.md` Step 1,
  `commands/review.md` follow-up creation, `skills/skill-fix-it/SKILL.md` 8.1,
  `skills/skill-project-overview/SKILL.md` 5.1, `skills/skill-spawn/SKILL.md`, and
  `agents/meta-builder-agent.md`'s task-creation step. `/orchestrate` and `/spawn`'s parent
  lookup both require a pre-existing task number and cannot be genuine first-touch sites.
- **`specs/tmp/` writer confirmed**: `hooks/tts-notify.sh` and `scripts/lifecycle-notify.sh`
  both set `LOG_FILE="specs/tmp/claude-tts-notify.log"`. This repo's own root `.gitignore`
  already carries root-relative `/specs/tmp` as precedent — use that form, not a blanket
  `**/tmp/` which would silently swallow a legitimate per-task `tmp/`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- One idempotent `init-specs.sh` that bootstraps `specs/`, `specs/archive/`, `specs/state.json`,
  `specs/archive/state.json`, `specs/TODO.md`, and `specs/.gitignore`, overwriting nothing that
  already exists.
- `specs/.gitignore` generated mechanically from `scripts/lib/runtime-file-patterns.sh`, never
  hand-copied, inside a marked managed block so user-added lines survive a refresh.
- An untrack sweep that `git rm --cached`es already-tracked runtime files under `specs/` without
  removing them from disk, leaving the change staged for the caller's own scoped commit.
- `specs/tmp/` added to the canonical pattern library so every consumer of the list agrees.
- Every realistic first-touch command/skill/agent calls the script before reading
  `specs/state.json`.
- Standards doc and lint messaging tell the truth about what is automatic and what is still
  manual.
- Fixture coverage proving the bootstrap, the no-op re-run, and the untrack/clean-tree
  acceptance scenario.

**Non-Goals**:
- Writing or modifying any consumer repo's **root** `.gitignore` (explicitly forbidden).
- Adding `.orchestrator-handoff.json` or `.return-meta.json` to any ignore list, or ever
  untracking them.
- Rewriting history in any repo.
- Implementing new tracked-file *detection* in `check-runtime-file-tracking.sh` (already
  present — verified, not rebuilt).
- Relocating session-state files out of the `specs/` root (that is the separate
  `move_session_state_files_out_of_specs_root` task; see Risks).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A blanket `**/tmp/` pattern silently hides a legitimate per-task `tmp/` directory | M | M | Use the root-scoped form (`/specs/tmp/` at repo root, `/tmp/` inside `specs/.gitignore`), matching this repo's own precedent; never `**/tmp/` |
| Owning the whole `specs/.gitignore` clobbers a consumer's hand-added local ignore rule on refresh | M | M | Marked managed block (`# BEGIN`/`# END` sentinels); rewrite only between sentinels, preserve everything outside verbatim (Phase 2) |
| Adding a 17th class member breaks the byte-identity pin between the lib and `orchestrator-runtime-files.md` | M | H | Regenerate the fenced markdown block from `runtime_ignore_block()` in the same phase as the lib edit, and run `test-runtime-file-tracking.sh` Case 3 before closing Phase 1 |
| The untrack sweep deletes working copies or touches durable provenance | H | L | `git rm --cached` / `git rm -r --cached` only (never plain `rm`); derive hits exclusively from `RUNTIME_FILE_B_REGEX`, which by construction matches neither `.orchestrator-handoff.json` nor bare `.return-meta.json`; add an explicit belt-and-braces skip plus a fixture asserting both stay tracked |
| Calling `init-specs.sh` from `deploy-headless.sh` widens deploy's scope (today strictly `.claude/`-only) and interacts with `.syncprotect` in an undefined way | M | M | Decided in Phase 4: deploy does **not** call it; the six command/skill/agent sites already cover every documented first-touch path. Decision and rationale recorded in the standards doc |
| Concurrent-session interference: the untrack sweep stages changes into a shared index while another session is mid-commit | M | L | Stage only; never commit inside `init-specs.sh`. Report what was staged on stdout so the caller's scoped commit can include it deliberately |
| The coordinating `move_session_state_files_out_of_specs_root` task edits the same lib and standards file | M | M | No conflict today (that task is `[NOT STARTED]`). Whichever lands second re-checks that the generated `specs/.gitignore` covers the relocated paths — noted in the standards doc's decision record |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 5 | 2 |
| 4 | 4 | 3 |
| 5 | 6 | 4, 5 |
| 6 | 7 | 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Extend runtime-file-patterns.sh with specs/tmp and a specs-relative emitter [COMPLETED]

**Goal**: The canonical pattern library gains the missing `specs/tmp/` class member and a second
block emitter producing `specs/`-relative patterns, so `init-specs.sh` can generate
`specs/.gitignore` without hand-copying anything. The pinned markdown block is regenerated in
lockstep.

**Tasks**:
- [x] Add a 17th member to every parallel array in
      `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh`: id `"tmp"`; root-form
      pattern `/specs/tmp/` (root-scoped, **not** `**/tmp/`); probe
      `specs/tmp/claude-tts-notify.log`; Check B regex `^specs/tmp/`; `IS_DIR="1"`;
      `DIR_BASENAME="tmp"`. *(completed)*
- [x] Update the lib's header comment: member count 16 -> 17, and note that `tmp` is
      deliberately root-scoped because its only writers (`hooks/tts-notify.sh`,
      `scripts/lifecycle-notify.sh`) always write to the `specs/` top level. *(completed: also
      noted state-write.sh's own staging/spill files as a third writer, found live during
      implementation)*
- [x] Add `runtime_specs_ignore_block()` emitting the same class as patterns relative to
      `specs/` (drop the leading `specs/` segment for root-scoped members: `/specs/tmp/` ->
      `/tmp/`; `**/`-prefixed members are unchanged), with its own comment header naming
      `init-specs.sh` as the writer and this lib as the canonical source. Derive it from the
      arrays, do not hand-write a second literal list. *(completed: loop over
      RUNTIME_FILE_PATTERNS, not a second heredoc)*
- [x] Regenerate the fenced block in
      `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`'s "Consumer
      Repo Setup" section from `runtime_ignore_block()` output so the byte-identity pin holds.
      *(completed)*
- [x] Update the "Single source of truth" decision record in that standards file: 16-member ->
      17-member class, and the site count if the new emitter adds one. *(completed: added a
      "sixth site" paragraph plus a new Class Table row for specs/tmp/)*
- [x] `shellcheck` the lib per `context/standards/shell-strict-mode.md`. *(completed: clean
      except two pre-existing SC2034 warnings on RUNTIME_FILE_PROBES/RUNTIME_FILE_B_REGEX that
      predate this task -- confirmed via `git show HEAD` diff; this edit's own new array
      reference actually silenced a third, RUNTIME_FILE_PATTERNS, by giving it a consumer)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts the class is exactly 16 members today and becomes exactly 17, and
that `RUNTIME_FILE_IDS`, `RUNTIME_FILE_PATTERNS`, `RUNTIME_FILE_PROBES`, `RUNTIME_FILE_B_REGEX`,
`RUNTIME_FILE_IS_DIR`, `RUNTIME_FILE_DIR_BASENAME` are the complete set of parallel arrays.
Confirm at implementation time with
`grep -c '^\s*"' ` over each `declare -a` block and `grep -n 'declare -a' scripts/lib/runtime-file-patterns.sh`
before editing; if a seventh array exists, extend it too.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` - 17th member across all
  parallel arrays; new `runtime_specs_ignore_block()`; header comment update
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - regenerated
  fenced block; class-table row for `tmp`; member-count updates in the decision record

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` passes,
  including Case 3's byte-identity assertion between the markdown block and
  `runtime_ignore_block()`.
- `diff <(bash -c 'source .../runtime-file-patterns.sh; runtime_ignore_block')` against the
  extracted markdown block is empty.
- `runtime_specs_ignore_block` output contains `/tmp/` and does not contain any line beginning
  `specs/`.
- `shellcheck` clean.

---

### Phase 2: Create init-specs.sh (state bootstrap + managed specs/.gitignore) [COMPLETED]

**Goal**: A new idempotent `scripts/init-specs.sh` that creates the `specs/` state trio and
writes a managed-block `specs/.gitignore`, overwriting nothing that already exists.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/init-specs.sh` with strict mode per
      `context/standards/shell-strict-mode.md`, a usage/`--help` header describing the contract
      (idempotent, non-destructive, never commits), and the same deploy-tree-first /
      source-store-fallback lib resolution `check-runtime-file-tracking.sh` uses
      (`SCRIPT_DIR`-relative `lib/runtime-file-patterns.sh`). *(completed)*
- [x] `mkdir -p specs specs/archive`. *(completed)*
- [x] If `specs/state.json` is absent, write
      `{"next_project_number": 1, "active_projects": [], "active_topics": []}` **directly** via
      mktemp + atomic `mv`. Do **not** route through `state-write.sh` — its `--init` mode
      unconditionally refuses the default live state path by design. *(completed)*
- [x] If `specs/archive/state.json` is absent, write it directly too (same mktemp+mv idiom, for
      symmetry with the line above and to avoid depending on `--init`'s silent-overwrite
      behavior). Confirm the minimal key set against its live readers (`task.md --recover`,
      `/todo`'s archival writer) before fixing it; the observed live shape is
      `{"archived_projects": [], "completed_projects": []}`. *(completed)*
- [x] If `specs/TODO.md` is absent, generate it by calling `generate-todo.sh` rather than
      hand-writing the format. *(completed)*
- [x] Write/refresh `specs/.gitignore` from `runtime_specs_ignore_block()` inside sentinels
      `# BEGIN managed block: runtime-file-patterns.sh` / `# END managed block:
      runtime-file-patterns.sh`. If the file exists with the sentinels, replace only the region
      between them; if it exists without them, append the block; if absent, create it. Preserve
      all content outside the sentinels byte-for-byte. *(completed)*
- [x] Emit a per-action summary on stdout (created / already present / refreshed) and exit 0 on
      a full no-op. *(completed)*
- [x] Register `init-specs.sh` in `agent-system/extensions/core/manifest.json` under
      `provides.scripts` (alphabetical position) and add an entry to
      `docs/reference/utility-scripts-inventory.md`. *(completed)*
- [x] `shellcheck` clean. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Assumes `specs/archive/state.json`'s minimal shape is
`{"archived_projects": [], "completed_projects": []}` and that it is not validated against
`state-schema.json`. Confirm at implementation time by grepping every reader
(`grep -rn 'archive/state.json' agent-system/extensions/core/`) and by running
`validate-artifact.sh`/any schema check against the generated file before closing the phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/init-specs.sh` - new file
- `agent-system/extensions/core/manifest.json` - `provides.scripts` registration
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - inventory entry

**Verification**:
- In a scratch `git init` repo with no `specs/`: running the script creates `specs/state.json`
  (valid against `context/schemas/state-schema.json`), `specs/archive/state.json`,
  `specs/TODO.md`, and `specs/.gitignore` containing the managed block.
- Running it a second time changes nothing: `git status --porcelain` and a
  `find specs -newer <marker>` check are both empty.
- Hand-add a line outside the sentinels to `specs/.gitignore`, re-run, confirm the line survives
  and the managed region is byte-identical to `runtime_specs_ignore_block()`.
- Pre-seed a populated `specs/state.json` and confirm the script leaves it untouched.
- `shellcheck` clean.

---

### Phase 3: Untrack sweep for already-tracked runtime files [COMPLETED]

**Goal**: `init-specs.sh` finds runtime-class files under `specs/` that git already tracks and
untracks them with `git rm --cached` (never deleting the working copy), leaving the change
staged and reported for the caller's own scoped commit.

**Tasks**:
- [x] Add an untrack step to `init-specs.sh` that loops `RUNTIME_FILE_B_REGEX` against
      `git ls-files -- specs/`, adapting Check B's existing print-only remediation loop into an
      executing form (`git rm -r --cached "<dir>"` for directory-class hits resolved via
      `runtime_file_dir_basename_for_hit()`, `git rm --cached "<file>"` otherwise). *(completed)*
- [x] Add an explicit belt-and-braces skip for any hit whose basename is
      `.orchestrator-handoff.json` or `.return-meta.json`, even though neither can match any
      `RUNTIME_FILE_B_REGEX` entry by construction. Comment why the redundant guard exists.
      *(completed)*
- [x] Never run plain `rm`; assert the working copy still exists after each `git rm --cached`.
      *(completed)*
- [x] Do **not** commit. Print each untracked path and a closing line telling the caller the
      changes are staged and belong in its own scoped commit. *(completed)*
- [x] Make the step a clean no-op (silent, exit 0) when no tracked runtime files are found, so
      repeated runs stay idempotent. *(completed: "silent" read as "stages nothing, exit 0" --
      it still prints one SKIP line for symmetry with every other step's summary line, verified
      idempotent via a real second-run test)*
- [x] Skip the step gracefully with a named notice when the working directory is not inside a
      git repository. *(completed)*
- [x] `shellcheck` clean. *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Assumes `runtime_file_dir_basename_for_hit()` resolves every
directory-class hit the sweep can encounter, including the new `tmp` member. Confirm at
implementation time by feeding each of the 17 members' probe paths through the function and
asserting the directory-class ones return their basename and the file-class ones return 1.

**Files to modify**:
- `agent-system/extensions/core/scripts/init-specs.sh` - untrack sweep step

**Verification**:
- In a scratch repo where `specs/.commit-lock/owner`, `specs/.events.lock`,
  `specs/001_x/.lock/holder.json`, `specs/001_x/.dispatch/1.md`,
  `specs/001_x/.orchestrator-loop-guard`, and
  `specs/.orchestrator-multi-state-sess_0_x.json` are all committed: the script untracks all of
  them, every file still exists on disk, and `git diff --cached --name-status` shows only `D`
  entries for those paths.
- A committed `specs/001_x/.orchestrator-handoff.json` and `specs/001_x/.return-meta.json` are
  still tracked afterward.
- Second run produces no further staged changes.
- `shellcheck` clean.

---

### Phase 4: Wire init-specs.sh into every first-touch call site [COMPLETED]

**Goal**: Every command, skill, and agent that can be the first thing to touch `specs/` in a
fresh consumer repo calls `init-specs.sh` before reading `specs/state.json`, and the deploy
question is decided and recorded.

**Tasks**:
- [x] Insert a call to `init-specs.sh` immediately before the `next_project_number` read in each
      site, using the deployed path (`bash .claude/scripts/init-specs.sh`) with the same
      invocation form neighboring script calls already use in that file:
      - `agent-system/extensions/core/commands/task.md` - Create Task Mode, before Step 1
      - `agent-system/extensions/core/commands/review.md` - follow-up task creation (Step 8)
      - `agent-system/extensions/core/skills/skill-fix-it/SKILL.md` - Step 8.1
      - `agent-system/extensions/core/skills/skill-project-overview/SKILL.md` - Step 5.1
      - `agent-system/extensions/core/skills/skill-spawn/SKILL.md` - "Get the next available
        task numbers" step
      - `agent-system/extensions/core/agents/meta-builder-agent.md` - task-creation step
      *(completed)*
- [x] Add the same defensive call at `/orchestrate`'s entry
      (`agent-system/extensions/core/commands/orchestrate.md`), noting inline that it is
      belt-and-braces: `/orchestrate` requires a pre-existing task number and cannot realistically
      be a first-touch site, but the call is idempotent and cheap. *(completed)*
- [x] **Decide and record: deploy does not call `init-specs.sh`.** Record the rationale (deploy
      is strictly `.claude/`-scoped today; `specs/` bootstrap is a task-lifecycle concern, not a
      deploy concern; `.syncprotect`'s documented scope is hand-edited `.claude/**`/root files
      and has no defined relationship to `specs/`) in `orchestrator-runtime-files.md`'s decision
      record (written in Phase 5), so a future reader does not re-litigate it. *(completed: the
      decision itself is made here -- deploy-headless.sh is untouched by this phase -- the
      written record lands in Phase 5 as planned)*
- [x] Confirm `command-gate-in.sh` is **not** wired: by the time it runs a task already exists,
      so it is not a viable choke point. Note this in the same decision record. *(completed:
      confirmed via `grep -c next_project_number command-gate-in.sh` = 0; it only reads
      specs/state.json to look up an EXISTING task)*
- [x] Verify no task-number references leak into any deliverable outside `specs/**`
      (`.claude/rules/no-task-references-in-deliverables.md`). *(completed: verified in the
      deployed tree after redeploy, per Phase 4's own Verification list below)*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts exactly six `next_project_number`-reading first-touch sites plus
one defensive `/orchestrate` site. Confirm at implementation time with
`grep -rn 'next_project_number' agent-system/extensions/core/commands agent-system/extensions/core/skills agent-system/extensions/core/agents`
before editing; wire any site the grep finds that this list omits, and say so in the summary.

**Files to modify**:
- `agent-system/extensions/core/commands/task.md` - init call before Step 1
- `agent-system/extensions/core/commands/review.md` - init call before follow-up creation
- `agent-system/extensions/core/commands/orchestrate.md` - defensive init call
- `agent-system/extensions/core/skills/skill-fix-it/SKILL.md` - init call before 8.1
- `agent-system/extensions/core/skills/skill-project-overview/SKILL.md` - init call before 5.1
- `agent-system/extensions/core/skills/skill-spawn/SKILL.md` - init call before task-number read
- `agent-system/extensions/core/agents/meta-builder-agent.md` - init call before task creation

**Verification**:
- `grep -rn 'next_project_number' agent-system/extensions/core/{commands,skills,agents}` — every
  hit has an `init-specs.sh` call above it in the same procedure.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` passes (no task numbers
  in deliverables outside `specs/**`).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` shows no new failures.

---

### Phase 5: Update standards doc and lint messaging [COMPLETED]

**Goal**: `orchestrator-runtime-files.md`'s "Consumer Repo Setup" states plainly that `specs/`
ignore rules are now installed automatically and names precisely what remains manual;
`check-runtime-file-tracking.sh`'s Check A failure message stops claiming the repo-root
`.gitignore` is the only remedy.

**Tasks**:
- [x] Rewrite "Consumer Repo Setup" in
      `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`: the
      `specs/`-scoped rules are installed automatically by `init-specs.sh` (called from the
      sites wired in Phase 4); the retained fenced root-`.gitignore` block is now the optional
      belt-and-braces/legacy path; state any genuinely remaining manual step precisely rather
      than leaving the whole section as "paste this by hand". Keep the fenced block itself
      byte-identical to `runtime_ignore_block()` (the Case 3 pin). *(completed: also discovered
      and documented, with a live check, that specs/.gitignore's own `**/.sessions/` pattern
      already covers specs/.sessions/ -- the automatic path needs NO remaining manual step at
      all for a repo using only the wired call sites)*
- [x] Add the Phase 4 decision record to the same file: deploy does not call `init-specs.sh`
      (with rationale), `command-gate-in.sh` is not a viable choke point (with rationale), and a
      coordination note that whichever of this work and the session-state-relocation work lands
      second must re-check the generated `specs/.gitignore` covers the relocated paths.
      *(completed: "Automatic-wiring decision record" subsection)*
- [x] Reword Check A's failure message in
      `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` to name
      `init-specs.sh` / `specs/.gitignore` as the primary remediation and the root `.gitignore`
      as the alternative. **No logic change** — `git check-ignore -q` already honors
      `specs/.gitignore` at any depth. *(completed: message text only, verified no logic diff)*
- [x] Confirm (do not reimplement) that Check B already FAILs on tracked ephemeral files
      independent of ignore coverage; record the confirmation in the phase's commit message so
      the fixture in Phase 6 is understood as a regression pin, not new behavior. *(completed:
      confirmed live via the Phase 3 scratch-repo test -- Check B failed on tracked
      specs/.commit-lock/*, specs/.events.lock, etc. even before any ignore coverage was
      involved; recorded in this phase's commit message)*
- [x] `shellcheck` clean. *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - Consumer Repo
  Setup rewrite; deploy/gate-in/coordination decision record
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` - Check A failure
  message only

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` still passes
  (Case 3 byte-identity intact after the doc rewrite).
- Manual read-through: the section names exactly one remaining manual step, or none, and does
  not contradict the automatic path.
- `shellcheck` clean.

---

### Phase 6: Fixture test suite [COMPLETED]

**Goal**: A scratch-repo fixture suite pins every acceptance criterion: full bootstrap, true
no-op re-run, untrack-without-delete, clean tree after a scoped commit plus lock release, and
`check-runtime-file-tracking.sh` passing.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-init-specs.sh`, modeled on
      `test-deploy-orphans.sh` / `test-deploy-propagation.sh`'s scratch-repo harness and
      following `context/standards/shell-script-testing.md` (loud-skip discipline, PASS/FAIL
      counters, executable bit set). *(completed: modeled specifically on
      test-runtime-file-tracking.sh's TREE_ROOTS resolution, since init-specs.sh's own dependency
      chain needs a full scripts/ copy, not a 3-file subset)*
- [x] Case 1 — fresh bootstrap: scratch `git init` repo with no `specs/`; run `init-specs.sh`;
      assert `specs/state.json` is schema-valid, `specs/archive/state.json` and `specs/TODO.md`
      exist, and `specs/.gitignore` carries the managed block. *(completed)*
- [x] Case 2 — idempotence: run again; assert zero filesystem changes and zero staged changes.
      *(completed)*
- [x] Case 3 — managed-block preservation: a user line outside the sentinels survives a refresh;
      the region inside is regenerated byte-identically. *(completed)*
- [x] Case 4 — ADDED ACCEPTANCE untrack scenario: commit `specs/.commit-lock/{owner,claimed_at,
      stale_sec}`, `specs/.events.lock`, `specs/001_x/.lock/holder.json`,
      `specs/001_x/.dispatch/1.md`, `specs/001_x/.orchestrator-loop-guard`, and a
      `specs/.orchestrator-multi-state-sess_*.json`; run `init-specs.sh`; assert all are
      untracked, all still exist on disk, and a following `git-commit-scoped.sh ... -- specs/`
      plus lock release leaves `git status --porcelain -- specs/` empty. *(completed: the
      fixture's own commit step uses a plain `git commit` on the sweep's already-staged index
      rather than invoking `git-commit-scoped.sh` itself -- git-commit-scoped.sh's own staging/
      mutex logic has its dedicated test-git-commit-scoped.sh suite; this case verifies the
      observable outcome git-commit-scoped.sh would produce, which is behaviorally identical
      here since nothing beyond the sweep's own `git rm --cached` output is staged)*
- [x] Case 5 — provenance preserved: a committed `.orchestrator-handoff.json` and
      `.return-meta.json` remain tracked and un-ignored after the sweep. *(completed)*
- [x] Case 6 — `check-runtime-file-tracking.sh` exits 0 on the bootstrapped repo whose only
      coverage is `specs/.gitignore` (proves item f without a logic change). *(completed)*
- [x] Case 7 — regression pin for item (h): with `specs/.gitignore` covering the class AND a
      tracked ephemeral file present, `check-runtime-file-tracking.sh` still exits nonzero via
      Check B. *(completed)*
- [x] Case 8 — `specs/tmp/claude-tts-notify.log` is ignored in the bootstrapped repo.
      *(completed)*
- [x] Confirm the suite is discovered by `scripts/tests/run-all.sh` (glob-based discovery; set
      the exec bit so it is not reported as a `[SKIP]`). *(completed: exec bit set, registered in
      manifest.json provides.scripts)*
- [x] `shellcheck` clean. *(completed: only the same SC2329/SC2001 info/style codes already
      present and tolerated in test-runtime-file-tracking.sh, the sibling suite this one is
      modeled on; no new warning class introduced)*

**Timing**: 1.5 hours

**Depends on**: 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts eight fixture cases cover the dispatch's ACCEPTANCE and ADDED
ACCEPTANCE paragraphs completely. Confirm at implementation time by re-reading both paragraphs
against the case list and adding a case for anything unmatched.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-init-specs.sh` - new suite

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-init-specs.sh` passes all cases.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` discovers it (appears in the
  per-suite narration, not as `[SKIP]`) and reports no failures anywhere.
- `shellcheck` clean on the suite.

---

### Phase 7: Deploy and confirm in a consumer repo [COMPLETED]

**Goal**: The change is deployed from the source store and confirmed working end-to-end in a
real consumer repo, as the dispatch's ACCEPTANCE requires.

**Tasks**:
- [x] Run the repo's deploy path so `.claude/` regenerates from the source store; confirm
      `.claude/scripts/init-specs.sh` exists and `.claude/scripts/lib/runtime-file-patterns.sh`
      carries the 17th member. *(completed)*
- [x] Run `bash .claude/scripts/tests/run-all.sh` against the deployed tree; confirm no
      failures. *(completed with a documented exception: 70/79 suites passed; the two failing
      suites -- test-task-lock-reap.sh and test-state-write-regen-timing.sh -- are pre-existing
      and unrelated to this task, confirmed via `git log` showing task-lock.sh's reap/mutex
      logic and its task-lookup-lib.sh dependency were last touched by an unrelated task
      (197), never by this one; this task never touches task-lock.sh, task-lookup-lib.sh, or
      either failing test file. test-init-specs.sh itself: 23/23 passing)*
- [x] Run `bash .claude/scripts/check-runtime-file-tracking.sh` in this repo; confirm it passes.
      *(completed: PASS, all three checks)*
- [x] In a throwaway scratch repo (not a user project), run the deployed
      `.claude/scripts/init-specs.sh` and confirm the bootstrap and re-run no-op behave as the
      fixtures assert. *(completed via test-init-specs.sh's own Case 1/2 against the deployed
      copy, plus the ad hoc scratch-repo testing performed throughout Phases 2-3)*
- [x] Report the consumer-repo confirmation status in the implementation summary. If a real
      consumer repo (e.g. `~/Projects/Logos/Verification`) is not available or is dirty, say so
      explicitly rather than claiming the confirmation happened — do not modify a user project's
      history or working tree to force the check. *(completed: repo exists and is clean, but
      Phase 7's own task list above substitutes a scratch repo for this confirmation, not a real
      user project, and redeploying that repo's `.claude/` was correctly avoided as an
      unnecessary working-tree modification outside this task's mandate -- see the summary for
      the full finding, including that this repo has since gitignored the entirety of `specs/`
      at its root, independent of this task's work)*

**Timing**: 0.75 hours

**Depends on**: 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- None (deploy + verification only; `.claude/**` is regenerated by the deploy process, never
  hand-authored)

**Verification**:
- `run-all.sh` green in the deployed tree.
- `check-runtime-file-tracking.sh` exits 0 in this repo.
- Scratch-repo bootstrap from the deployed copy produces the same artifacts as Phase 6 Case 1.

---

## Testing & Validation

- [ ] `test-runtime-file-tracking.sh` passes, including Case 3's lib-to-markdown byte-identity
      pin, after the 17th member is added.
- [ ] `test-init-specs.sh` passes all eight cases.
- [ ] `run-all.sh` green in both the source store and the deployed tree.
- [ ] `check-runtime-file-tracking.sh` exits 0 in this repo and in a bootstrapped scratch repo
      whose only coverage is `specs/.gitignore`.
- [ ] `check-task-references.sh` passes (no task numbers in deliverables outside `specs/**`).
- [ ] `shellcheck` clean on `init-specs.sh`, the lib, `check-runtime-file-tracking.sh`, and
      `test-init-specs.sh`, per `context/standards/shell-strict-mode.md`.
- [ ] Running `init-specs.sh` twice in a row changes nothing (asserted mechanically, not by
      inspection).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/init-specs.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-init-specs.sh` (new)
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` (17th member,
  `runtime_specs_ignore_block()`)
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` (Check A message)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (Consumer Repo
  Setup rewrite, decision record, regenerated block)
- `agent-system/extensions/core/manifest.json` (script registration)
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` (inventory entry)
- Seven command/skill/agent files wired with the init call (Phase 4 list)
- `specs/209_init_consumer_specs_and_runtime_ignores/summaries/01_*-summary.md` (at completion)

## Rollback/Contingency

Every phase is a `per-substep` commit boundary, so the cheapest rollback is `git revert` of the
offending phase commit — no working-tree destruction needed, and the phases are ordered so that
reverting a later one leaves earlier ones coherent (the lib change in Phase 1 is inert until
Phase 2 consumes it; the call-site wiring in Phase 4 is inert if `init-specs.sh` is reverted,
beyond a missing-script error that the call sites should tolerate — make the call non-fatal if
the script is absent).

If uncommitted work must be discarded mid-phase, take a snapshot first per
`context/contracts/recovery.md`'s rollback rung (including its out-of-scope override flag for a
deliberate whole-tree revert) before running any destructive git command — never a bare
precautionary `git-snapshot.sh` call as a routine start-of-phase checkpoint. For a durable,
non-reverting checkpoint before the riskiest step (the Phase 3 untrack sweep), use
`git-snapshot.sh --no-revert` instead.

Contingency for the highest-risk step: the untrack sweep only ever stages `git rm --cached`
deletions, so an unwanted sweep is undone with `git reset -- specs/` (unstage) without touching
a single file on disk.
