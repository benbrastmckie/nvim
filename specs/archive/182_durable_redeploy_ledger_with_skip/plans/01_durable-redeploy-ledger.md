# Implementation Plan: Task #182

- **Task**: 182 - Add a durable redeploy ledger with content-hash and recency skip to the checkpoint
- **Status**: [COMPLETED]
- **Effort**: 6.5 hours
- **Dependencies**: 181 (gate-depth / verdict-logic unification — completed), 193, 213 (completed)
- **Research Inputs**: specs/182_durable_redeploy_ledger_with_skip/reports/01_durable-redeploy-ledger-design.md
- **Artifacts**: plans/01_durable-redeploy-ledger.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The Inter-Cycle Redeploy Checkpoint in
`agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (the `(k, part 2)` block) has no
memory that lasts between invocations. Its only dedup, `deployed_critical_paths`, is stored in the
session-named `specs/.orchestrator-multi-state-{session_id}.json`, so it is cleared on every
`/orchestrate` run. This plan adds a new ledger that is durable, gitignored, machine-local and
not tied to a session: `specs/.orchestrator-deploy-ledger.json`. The ledger is managed by a new
library, `scripts/lib/deploy-ledger-lib.sh`, and records a per-path and aggregate sha256 of the
source-store critical paths, the verify outcome (using the verdict vocabulary settled by the
gate-depth work), a timestamp, and the batch's task numbers. The checkpoint reads the ledger
**before** the first expensive call (`deploy_findings_snapshot`). It can skip on one of two
separate kinds of evidence:
(1) **hash skip**: the ordinary case. The content is unchanged since a skip-eligible deploy, and
that deploy falls inside a max-age cap.
(2) **attributed skip**: the self-modifying-task case. The deploy was recent, it was made by a
batch that shares a task with this one, and every critical path that changed since then is this
batch's own edit.
When any batch task has a `deploy_pending` completion refusal, both skips are overridden, so a
skip can never starve the completion backstop. The existing `deployed_critical_paths` field keeps
exactly its current within-invocation meaning.

### Research Integration

- Insertion point, success/defer branches, `matched_paths_json`, `PROJECT_ROOT`, and the
  `dry_run` gating convention are taken directly from the report's Codebase Patterns section.
- Report's open decisions, resolved here (see Decisions below): (a) independent ledger file
  (Design Option B), not an extension of `.claude-extensions.json`; (b) git-independent sha256
  content hash (keeps Group 11's non-git fixture working); (c) single rolling record; (d)
  `DEPLOY_LEDGER_RECENT_SEC` / `DEPLOY_LEDGER_MAX_AGE_SEC` env-overridable constants.
- Report's correction adopted: the "its own task" sentence in the Postflight Completion-Deploy
  Gate subsection is about widening the trigger predicate (D6). That is separate follow-up work
  and stays open. This plan only clarifies that sentence so it no longer implies the
  cross-invocation store is still missing.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (no roadmap_path in dispatch).

## Decisions

1. **Ledger file**: `specs/.orchestrator-deploy-ledger.json` (overridable via
   `DEPLOY_LEDGER_FILE` for tests), gitignored, not session-suffixed. Rationale: it describes
   THIS machine's local `.claude/` deploy state (itself gitignored), so committing it would be
   misleading on another clone; `.claude-extensions.json` is tracked and scoped to the whole
   `core` extension. Registered in `runtime-file-patterns.sh` for gitignore purposes, but
   documented in the Class Table as a distinct "durable, machine-local, hash-gated" row — its
   staleness is self-checked on every read (hash compare), so a git-restored or stale copy can
   only cause a redeploy, never a wrong skip beyond the bounded windows below.
2. **Hash**: sha256 per path over every `critical_paths[].path` in
   `context/reference/orchestrator-critical-paths.json`, resolved against the
   `agent-system/extensions/core` scope root ONLY (the other two roots are deploy mirrors). A
   missing file hashes to the literal `MISSING`. Aggregate = sha256 of the sorted `path hash`
   lines. The hash covers the FULL critical-path list (not just the matched subset) so records
   are comparable across invocations. A missing source-store root, a missing `sha256sum`, or a
   jq failure results in CANNOTVERIFY, which means no skip.
3. **Verify outcome vocabulary** (subset of the gate-depth work's checkpoint branches):
   `clean` (post-redeploy findings empty), `pre_existing` (branch (c)), `filtered`
   (branch (c)-equivalent, `filtered:true`) — the three **skip-eligible** outcomes; plus
   non-eligible negative records `deploy_failed` (branch (a)) and `blocking` (branch (b)), which
   are written so that an earlier clean record can never vouch for a tree that a later failed or
   blocking deploy has since overwritten.
4. **Skip rules** (all require a valid, parseable ledger with a skip-eligible outcome, no
   `deploy_pending` batch task, and `DEPLOY_LEDGER_SKIP` not set to `0`):
   - `skip_hash`: current aggregate hash == ledger aggregate hash AND
     `now - verified_at <= DEPLOY_LEDGER_MAX_AGE_SEC` (default 86400).
   - `skip_attributed`: `now - verified_at <= DEPLOY_LEDGER_RECENT_SEC` (default 1800) AND
     ledger `task_numbers` intersects the current batch's `task_numbers` ("the deploy that just
     landed was mine") AND every critical path whose per-path hash differs from the ledger is
     covered by the current `cycle_modified_files` (via `scopes_overlap_first`, with each
     changed path checked under all three scope roots). If any changed path is not explained by
     this batch's own edits, the result is `run`.
   - Otherwise `run`. Every skip decision names its evidence (hash, age, attributing task
     numbers) in a loud stderr banner and in a new `mt_state_file.redeploy_skip_notices[]`
     entry.
5. **`deploy_pending` override**: before deciding, the checkpoint reads each batch task's own
   `.return-meta.json`. If any has `deploy_pending: true`, the decision is forced to `run`.
   Without this, a completion refused because the deploy is stale could be skipped repeatedly
   and stay stuck.
6. **`deployed_critical_paths` retained unchanged**: its within-invocation role stays as it is
   and it is NOT written on a skip. It still means "actually deployed in this invocation". A
   skipped path re-consults the ledger (cheap: about 16 file hashes) on any later cycle that
   touches it again, so the `deploy_pending` override stays reachable.
7. **Writes are gated on `dry_run != "true"`**, like every other mutation in the script, and are
   atomic (tmp file in the same dir + `mv`). With concurrent sessions the last writer wins, which
   is acceptable: every write describes a real, completed deploy.
8. **Out of scope**: the completion-deploy trigger sites (`command-gate-out.sh`,
   skill-base retry) do not write the ledger in this task; the library is built so they can
   later. This matches the "Non-Goals" below.

## Goals & Non-Goals

**Goals**:
- A durable cross-invocation last-deploy record: timestamp, source-store content hash, verify
  outcome.
- A hash skip for the ordinary case, and an attributed-recency skip for the self-modifying-task
  class. Both are backed by positive ledger evidence and never by the absence of evidence.
- A named acceptance test: a simulated self-modifying task does not incur a redundant full
  redeploy across repeated cycles and invocations.
- An updated guardrails contract, with a corrected description of `deployed_critical_paths` that
  gives its within-invocation scope.

**Non-Goals**:
- Widening Stage MT-3 step 7's trigger predicate (D6 residual). That stays open follow-up work.
- Changing the checkpoint's verdict logic, i.e. the confirmation/attribution filters and depth
  reporting.
- Having `command-gate-out.sh` / completion-deploy triggers write or consult the ledger.
- Previewing ledger decisions under `--dry-run`. The checkpoint does not run under dry-run
  today, and that stays unchanged.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Attributed skip degrades into a disabled gate | H | M | Three conjunctive conditions (recent window, shared task numbers, delta ⊆ own edits); `deploy_pending` override; bounded 30 min default; negative-record writes invalidate stale evidence |
| Skip starves the completion backstop (task refused as stale forever) | H | M | `deploy_pending` override forces `run`; skipped paths not added to `deployed_critical_paths` so they are re-evaluated |
| Hash skip trusts a `.claude/` tree edited or rolled back out of band | M | L | `DEPLOY_LEDGER_MAX_AGE_SEC` cap; source rollback changes hash; `DEPLOY_LEDGER_SKIP=0` escape hatch |
| Existing Group 11 cases (a)-(k) accidentally skip | M | L | Fixture has no `agent-system/extensions/core` root, so CANNOTVERIFY → run; seed function also `rm -f`s the ledger |
| Adding a runtime-file class member breaks count-pinned tests | L | H | Phase 4 updates `test-runtime-file-tracking.sh` Case 5 count and the pinned md block together |
| Mid-run script swap (checkpoint edits itself) | M | L | Library sourced once at startup like the other libs; no new behavior beyond the existing self-modification hazard analysis |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3, 5 | 2 |

Phases within the same wave can execute in parallel. (Phase 4 touches no file Phase 2 touches;
Phase 3 and Phase 5 touch disjoint files.)

### Phase 1: Ledger library and unit tests [COMPLETED]

**Goal**: Build `scripts/lib/deploy-ledger-lib.sh` as a pure, testable library with no checkpoint
wiring yet.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/deploy-ledger-lib.sh` (header style
  mirroring `deploy-baseline-lib.sh` / `deploy-freshness-lib.sh`; `set -u`-safe; no top-level
  side effects) exporting:
  - `deploy_ledger_path <project_root>` → `${DEPLOY_LEDGER_FILE:-<root>/specs/.orchestrator-deploy-ledger.json}`
  - `deploy_ledger_hash_state <project_root> <critical_paths_file>` → compact JSON
    `{aggregate, paths:{<path>:<sha256|MISSING>}}` over the `agent-system/extensions/core` root,
    or prints nothing and returns 2 (CANNOTVERIFY) on missing root, missing `sha256sum`, or jq
    failure
  - `deploy_ledger_read <ledger_file>` → validated JSON (schema `deploy-ledger-v1`, required
    keys `aggregate`, `paths`, `verified_at` numeric, `verify_outcome`, `task_numbers` array),
    else empty output + nonzero (fail-safe: missing/malformed = no evidence)
  - `deploy_ledger_decide <ledger_json> <hash_state_json> <now_epoch> <cycle_modified_files_json> <task_numbers_json> <deploy_pending_bool>`
    → JSON `{decision: "skip_hash"|"skip_attributed"|"run", reason, age_sec, changed_paths, attributing_tasks}`
    implementing Decisions 4-5; sources `lib/file-scope-overlap.sh`'s `FILE_SCOPE_OVERLAP_JQ_DEFS`
    for the ⊆ check (changed path expanded across all three `scope_roots`)
  - `deploy_ledger_write <ledger_file> <hash_state_json> <verify_outcome> <task_numbers_json> <session_id> <cycle>`
    → atomic tmp+`mv`, `mkdir -p` of parent; returns nonzero on failure (caller warns, never
    fatal)
  - Constants `DEPLOY_LEDGER_RECENT_SEC=${DEPLOY_LEDGER_RECENT_SEC:-1800}`,
    `DEPLOY_LEDGER_MAX_AGE_SEC=${DEPLOY_LEDGER_MAX_AGE_SEC:-86400}`, `DEPLOY_LEDGER_SKIP`
    (`0` forces `run`); `DEPLOY_LEDGER_ELIGIBLE_OUTCOMES` = `clean pre_existing filtered`
- [x] Create `agent-system/extensions/core/scripts/tests/test-deploy-ledger-lib.sh`, modeled on
  `test-deploy-baseline-lib.sh`, covering: hash determinism and MISSING handling; CANNOTVERIFY
  on absent root; read rejects malformed or missing files; decide returns `skip_hash` (equal
  hash, in cap), `run` (equal hash, past cap), `skip_attributed` (changed hash, in window,
  shared task, delta ⊆ mods), `run` for each single broken conjunct (outside window, disjoint
  tasks, a foreign changed path, `deploy_pending=true`, non-eligible outcome `blocking` /
  `deploy_failed`, `DEPLOY_LEDGER_SKIP=0`); write round-trips through read.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: every `critical_paths[].path` entry is a regular file (16 entries at
planning time), so no directory hashing is needed. Confirm with
`jq -r '.critical_paths[].path' context/reference/orchestrator-critical-paths.json` plus a
`-f` test against `agent-system/extensions/core/`. If any entry is a directory, hash its
sorted `find -type f` listing.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/deploy-ledger-lib.sh` - new library
- `agent-system/extensions/core/scripts/tests/test-deploy-ledger-lib.sh` - new unit tests

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-deploy-ledger-lib.sh` passes; `bash -n`
  and `shellcheck` (if available) clean on the library.

---

### Phase 2: Wire the ledger into the inter-cycle redeploy checkpoint [COMPLETED]

**Goal**: Consult the ledger before any expensive checkpoint work, skip on evidence, and write
positive or negative records on every deploy outcome.

**Tasks**:
- [x] Source `lib/deploy-ledger-lib.sh` beside the existing `deploy-baseline-lib.sh` source
  (same loud-failure pattern, lines ~244-252).
- [x] Inside `if [ "$matched_count" -gt 0 ] && [ "$dry_run" != "true" ]`, after the existing
  banner and BEFORE `pre_findings=$(deploy_findings_snapshot ...)`:
  compute `hash_state` (CANNOTVERIFY → treat as `run`), read the ledger, compute
  `deploy_pending_any` by reading each batch task's `.return-meta.json` (resolve the task dir via
  the already-sourced `task-lookup-lib.sh`; an unreadable file counts as not pending), then call
  `deploy_ledger_decide`.
- [x] On `skip_*`: print `[orchestrate] REDEPLOY CHECKPOINT: skipped (<decision>) -- ledger shows
  aggregate <short-hash> verified <outcome> <age>s ago by task(s) <list>; <reason>` to stderr.
  Append an entry `{cycle, decision, reason, age_sec, ledger_outcome, changed_paths,
  attributing_tasks}` to `mt_state_file.redeploy_skip_notices` (initialize with `// []`). Do NOT
  touch `deployed_critical_paths`. Bypass the whole deploy/verify body with an if/else wrapper,
  not an early exit, so the trailing `cycle_modified_files = []` reset and `mt_save` still run.
- [x] On the three success branches (clean, branch (c), filtered (c)-equivalent), right next to
  each existing `deployed_critical_paths` `mt_set`, call `deploy_ledger_write` with outcome
  `clean` / `pre_existing` / `filtered`, using the `hash_state` computed BEFORE the deploy (the
  content that was actually deployed). Skip the write if `hash_state` was CANNOTVERIFY.
- [x] On branch (a) write outcome `deploy_failed`; on branch (b) write outcome `blocking`
  (negative records, never skip-eligible).
- [x] Ledger-write failure → one stderr WARNING, never fatal, never changes the branch outcome.
- [x] Extend the `(k, part 2)` header comment block with a short "Durable redeploy ledger"
  paragraph pointing at the guardrails subsection (no task numbers).

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: the batch task numbers are available as `mt_get_json '.task_numbers'`, and
`task-lookup-lib.sh` exposes a function that resolves a task number to its directory, including
archived tasks. Confirm by grepping `task-lookup-lib.sh` for its exported function names before
wiring. If no such function exists, build the path from the `lookup_project` result using the
`{NNN}_{project_name}` convention.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - source lib; ledger consult/skip; ledger writes on all five outcomes; header comment

**Verification**:
- `bash -n` clean. The existing Group 11 cases (a)-(k) in
  `scripts/tests/test-orchestrate-cycle-plan.sh` still pass unchanged, which confirms the
  CANNOTVERIFY → run path. The full test file still passes.

---

### Phase 3: Group 11 checkpoint coverage, including the self-modifying acceptance criterion [COMPLETED]

**Goal**: End-to-end coverage of the skip rules through the real SUT, with a named test for the
self-modifying-task acceptance criterion.

**Tasks**:
- [x] Add a call-counting `deploy-headless.sh` stub variant (marker file, mirroring
  `G11_CALL_MARKER`) so tests can assert the deploy was or was not invoked.
- [x] Add a helper that creates a fixture source-store root at
  `$WORKDIR/agent-system/extensions/core/` containing copies/stand-ins for the critical-path
  files, plus a helper that seeds `$WORKDIR/specs/.orchestrator-deploy-ledger.json` from the
  library's own `deploy_ledger_hash_state` + `deploy_ledger_write` (so tests never hand-roll
  hashes). Make `g11_seed_state_and_mt` also `rm -f` the ledger so earlier cases are isolated.
- [x] New cases (append after the existing (a)-(k) sequence, named for the acceptance criteria):
  - (l) **skip on unchanged hash**: ledger clean, same content, fresh → deploy stub count 0,
    no defer, `redeploy_skip_notices[0].decision == "skip_hash"`,
    `deployed_critical_paths` unchanged (empty).
  - (m) **skip within the recency window**: content changed on a path in
    `cycle_modified_files`, ledger recent, same task number → `skip_attributed`, deploy count 0.
  - (n) **NO skip when the source store genuinely changed outside the window**: changed content
    and ledger `verified_at` older than `DEPLOY_LEDGER_RECENT_SEC` → full pipeline runs (deploy
    count 1, verify called), ledger rewritten with the new aggregate and `clean`.
  - (o) **NO skip on a foreign change**: in-window ledger, but a changed critical path is absent
    from `cycle_modified_files` → run.
  - (p) **deploy_pending override**: a batch task dir `.return-meta.json` carrying
    `deploy_pending: true` → run despite an otherwise-matching hash.
  - (q) **negative record**: branch (b) setup writes `verify_outcome: "blocking"`; a following
    run with unchanged content does NOT skip.
  - (r) **Self-modifying-task acceptance criterion (named)**: a task whose `file_scope` and
    `cycle_modified_files` overlap `scripts/orchestrate-cycle-plan.sh`. Invocation 1 (session A,
    empty ledger) runs the full redeploy, so the deploy count is 1 and the ledger is written.
    The fixture source file is then edited (new hash, by construction). Invocation 2 (session B,
    fresh `mt_state_file`, persistent ledger, same task number) and invocation 3 (session C,
    another edit) both skip via `skip_attributed`. Assert the total deploy count stays 1 across
    all three, and assert that the same scenario with only a hash rule (simulated via
    `DEPLOY_LEDGER_RECENT_SEC=0`) would redeploy every time (count 3). This proves the
    attributed rule is what closes the failure mode. *(deviation: altered — used
    `DEPLOY_LEDGER_RECENT_SEC=-1`, not `0`, for the counterfactual: age is computed as whole
    seconds via `date +%s`, so a same-second seed+decide pair could produce `age_sec == 0`,
    making `0` a flaky, timing-dependent threshold; `-1` is unsatisfiable by any non-negative
    age and keeps the assertion deterministic.)*
- [x] Update the Group 11 banner/`info` text to mention the ledger.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: `PROJECT_ROOT` in the SUT resolves to `$WORKDIR` under the fixture (via
`common_repo_root "$SCRIPT_DIR" 2`), so the default ledger path lands in `$WORKDIR/specs/`.
Confirm by running one new case with `DEPLOY_LEDGER_FILE` unset and checking the file appears
there. If it does not, export `DEPLOY_LEDGER_FILE` explicitly in the Group 11 setup.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - new stub/helpers and cases (l)-(r)

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` is fully
  green, including all pre-existing groups.

---

### Phase 4: Register the ledger as a gitignored runtime file [COMPLETED]

**Goal**: The ledger is never committed, and the runtime-file policy documents its distinct
tracking disposition.

**Tasks**:
- [x] Add a member for `.orchestrator-deploy-ledger.json` to
  `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` (all parallel arrays in
  lockstep; update the header's member count and the enumeration comment).
- [x] Update `context/standards/orchestrator-runtime-files.md`: a new Class Table row (writer:
  the orchestrate-cycle-plan.sh checkpoint; reader: the same checkpoint on later invocations;
  cleanup: never, since it is a single rolling record overwritten in place; disposition:
  **Durable, machine-local (gitignored)**, hash-gated on read). Add a short subsection explaining
  that a gitignored file here does not mean ephemeral semantics. Update the pinned "Consumer Repo
  Setup" fenced block so it stays byte-identical to `runtime_ignore_block()`.
- [x] Add the pattern to the repo-root `/home/benjamin/.config/nvim/.gitignore` ephemeral block
  (this is a hand-maintained repo file, not a `.claude/**` deploy artifact).
- [x] Update `scripts/tests/test-runtime-file-tracking.sh` Case 5's member count and message.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: the lib currently has 17 members, Case 5 is the only count-pinned
assertion, and `test-deploy-orphans.sh` / `test-deploy-propagation.sh` consume the lib's
arrays without hardcoded counts. Confirm with
`grep -rn "17" scripts/tests/test-runtime-file-tracking.sh scripts/tests/test-deploy-orphans.sh scripts/tests/test-deploy-propagation.sh`
and `grep -rn "runtime_ignore_block\|RUNTIME_FILE_IDS" agent-system/extensions/` before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` - new member
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - Class Table row, pinned block, disposition note
- `.gitignore` (repo root) - new pattern
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` - count update

**Verification**:
- `test-runtime-file-tracking.sh`, `test-deploy-orphans.sh`, `test-deploy-propagation.sh` pass;
  `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` clean.

---

### Phase 5: Guardrails contract documentation [COMPLETED]

**Goal**: Replace the deferred-work note with the real contract, and correct the description of
`deployed_critical_paths`.

**Tasks**:
- [x] In `context/patterns/batch-orchestration-guardrails.md` "### The Inter-Cycle Redeploy
  Checkpoint": rewrite the **Idempotence guard** paragraph to state explicitly that
  `deployed_critical_paths` lives in the session-suffixed `mt_state_file`. It is a
  WITHIN-invocation re-deploy suppressor that is written only on the success branches and never
  on defer or skip. Its semantics are unchanged.
- [x] Add a **Durable redeploy ledger** paragraph block covering: file and schema; the hash scope
  (source-store root only, full critical-path list); the skip-eligible and negative outcome
  vocabulary; the two skip rules and why both are needed (the hash rule cannot help the
  self-modifying class because that class changes the hash by construction); the
  `deploy_pending` override; the fail-safe read (missing, malformed or CANNOTVERIFY means run);
  the env knobs (`DEPLOY_LEDGER_RECENT_SEC`, `DEPLOY_LEDGER_MAX_AGE_SEC`, `DEPLOY_LEDGER_SKIP`,
  `DEPLOY_LEDGER_FILE`); `redeploy_skip_notices`; and a "Rejected alternative: bare recency
  window" note.
- [x] In "### The Postflight Completion-Deploy Gate" D6 residual: edit only the clause "its
  `deployed_critical_paths` idempotence backing store, which is its own task". It should now say
  that the cross-invocation durable ledger exists (with a pointer to the subsection above) and
  that widening the trigger predicate remains open follow-up work. Do NOT mark D6 resolved.
- [x] Check the whole file for other stale mentions (`grep -n "deployed_critical_paths\|ledger"`).
  Use no task numbers (run the task-reference lint).

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - Inter-Cycle subsection + D6 clause

**Verification**:
- Diff read-through; `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the
  deployed equivalent) reports no new violations; described env var names/defaults match the
  library exactly (grep both).

## Testing & Validation

- [ ] `test-deploy-ledger-lib.sh` green (unit rules, one test per broken conjunct).
- [ ] `test-orchestrate-cycle-plan.sh` fully green, including new Group 11 cases (l)-(r) and the
  named self-modifying acceptance case (r).
- [ ] `test-runtime-file-tracking.sh`, `test-deploy-orphans.sh`, `test-deploy-propagation.sh`,
  `test-deploy-baseline-lib.sh` green.
- [ ] Task-reference lint clean across all touched deliverables.
- [ ] Final full gate unchanged: after the last phase, run the repository's full shell test
  suite / `verify-deploy.sh --findings` after a `deploy-headless.sh` redeploy (this task edits a
  critical path, so it is itself a member of the self-modifying class).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/deploy-ledger-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-deploy-ledger-lib.sh` (new)
- Modified: `orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-plan.sh`,
  `runtime-file-patterns.sh`, `test-runtime-file-tracking.sh`,
  `orchestrator-runtime-files.md`, `batch-orchestration-guardrails.md`, repo-root `.gitignore`
- `specs/182_durable_redeploy_ledger_with_skip/summaries/01_durable-redeploy-ledger-summary.md`

## Rollback/Contingency

Each phase is committed separately. Reverting Phase 2's commit alone restores the exact
pre-ledger checkpoint behavior; the library and tests are inert without it. As an operational
kill switch that needs no revert, `DEPLOY_LEDGER_SKIP=0` forces every checkpoint back to the
full deploy+verify path. A stale or corrupt ledger file can be deleted safely at any time, since
absence means "run".
