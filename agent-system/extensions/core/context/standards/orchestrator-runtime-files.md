# Orchestrator Runtime-File Tracking Policy

## Overview

`/orchestrate` and the skills it dispatches write several small scratch files directly under
`specs/{NNN}_{SLUG}/` (and a couple under `specs/` itself, for multi-task batches). This standard
is the single canonical policy for which of those files are **git-tracked** and which are
**gitignored**, and why. It is the authority `git-staging-scope.md`, both orchestrate skills,
`handoff-schema.md`, and the verification check script all point back to — extend this table when
a new runtime file class is discovered rather than re-deriving the split ad hoc at each call site.

## The Two-Class Split

Every runtime file falls into exactly one of two classes:

- **Ephemeral (gitignored, untracked)** — per-cycle scratch state that a resume/read site trusts
  with **no freshness check**. If a stale copy of one of these were restored from git history, it
  would silently corrupt in-flight orchestration state (a wrong `cycle_count`, a stale mutex, a
  bogus churn counter) with nothing to catch it.
- **Durable provenance (tracked)** — per-dispatch audit trail. Two distinct hazards apply here,
  and the "documented freshness gate" protects against only one of them. The **git-restoration
  hazard** (a stale copy silently reappearing from history) is fully covered by the mtime-window
  freshness gate described below. The **late-writer hazard** — a dispatch that reported once,
  woke via a self-armed watcher or an operator resume, and wrote again while still live — is
  NOT covered by mtime alone: a woken predecessor's late write carries a *newer* mtime than the
  successor's dispatch window by construction, so it passes an mtime-only check. That hazard is
  covered instead by the orchestrator-minted `dispatch_seq` identity check (see
  `docs/architecture/handoff-schema.md`), and its root cause is stated once in
  `context/patterns/dispatch-report-not-termination.md` — see that file rather than restating it
  here. With both hazards covered, tracking this file costs nothing beyond history noise and
  gains a genuine audit trail of what each dispatch did.

### Class Table

| File | Writer | Reader | Cleanup site | Disposition |
|------|--------|--------|---------------|-------------|
| `.orchestrator-loop-guard` | `skill-orchestrate` Stage 2 (loop-guard init, both effort modes — the formerly-separate hard-mode engine's own Stage 2 was merged into this one and deleted) | Base-mode Stage 2 resume branch: unconditional trust, see Rationale. Hard-mode Stage 2 resume branch: conditional trust — a `loop-guard-staleness` detector runs first; see "Operational staleness: a second, orthogonal freshness axis" below | `rm -f` only at full-loop termination (Stage 8, both effort modes); a hard-mode guard that trips the staleness detector is instead archived aside before reinitialization, see below | **Ephemeral** |
| `.orchestrator-churn-state.json` | `skill-orchestrate` Stage 2 (`churn_file`, hard-mode-gated — formerly the standalone hard-mode engine's own Stage 2, since merged in and deleted) | Hard-mode convergence-policing (H6) reads; also archived aside alongside a stale loop guard, inheriting its verdict rather than deriving its own — see "Operational staleness" below | `rm -f` only at full-loop termination, alongside the loop guard; also archived aside (never deleted) when the loop guard it accompanies is found stale | **Ephemeral** |
| `.lock/` (directory, e.g. `holder.json`) | `task-lock.sh` mutex primitives (see `context/patterns/task-lock.md`) | Lock-holder checks during an in-flight dispatch | Released (removed) when the mutex is released | **Ephemeral** |
| `.drift-inspection.json` | `skill-orchestrate` Stage 5a (drift-inspection fork) | The same Stage 5a call, immediately after the fork returns | `rm -f` only at Stage 8 postflight (full-loop termination) — same timing class as the loop guard, not per-cycle | **Ephemeral** (newly identified by this audit — see note below) |
| `.orchestrator-handoff.json` | Skills when `orchestrator_mode: true` (currently: a hard-mode implementation agent's H9 wrap-up — cslib's and lean's today, since core's own is deleted; see `docs/architecture/handoff-schema.md`) | `skill-orchestrate` Stage 5 (single-task, both effort modes) and Stage MT-4 (multi-task) | Overwritten in place each dispatch cycle (static filename, never deleted) | **Durable provenance** |
| `.return-meta.json` | Every research/plan/implement dispatch's own Stage 7 postflight (base and hard mode alike) | `orchestrate-recover-outcome.sh` fallback recovery path; `command-gate-out.sh`'s defensive status correction and `skill_validate_task_artifacts`; each single-task command's own CHECKPOINT 3 commit block (`modified_files`/staging) | `skill_cleanup()` no longer removes this file (fixed defect — see `context/patterns/skill-postflight-flow.md`'s reader table for the full history). Deletion is owned by the calling command's own last step that consumes it: each single-task command's CHECKPOINT 3 (or, for `/revise`, the step after gate-out; for `/orchestrate`, the completion branch only), each multi-task batch loop's Step 4 (per dispatched task), or `skill-spawn/SKILL.md` Stage 16 inline for the one caller with no command-level consumer. `/orchestrate`'s own multi-task path (Stage MT-4) never deletes it at all, deliberately — see the reader table linked above. `orchestrator-postflight.sh` Stage 10 is an orphaned script with zero live call sites (see the other rows above that still mention it for historical/other-file context) and is not part of the live `.return-meta.json` cleanup path | **Durable provenance** |
| `specs/.orchestrator-multi-state-{session_id}.json` | `skill-orchestrate` multi-task batch dispatch (Stage MT, `specs/` root, not per-task) | The per-task commits issued at Stage MT-4 step 5.5, each scoped to its own task and session | Not explicitly cleaned up between batch runs; scratch state for one batch invocation; reaped by `scripts/reap-session-runtime-files.sh` after `ORCHESTRATOR_SESSION_REAP_MIN` | **Ephemeral**. The path carries a `{session_id}` suffix so two concurrent multi-task batches never collide on the same file. |
| `specs/.events.lock` | `scripts/events-append.sh` (`flock` guard around the append-only event store) | Itself, for the duration of a single append | Released by `flock` at the end of the append | **Ephemeral** |
| `specs/.freshness-warn-streak.json` | `scripts/check-deploy-freshness.sh` (consecutive-ignore escalation counter — see `context/patterns/regeneration-is-manual-only.md`'s "Detecting When You're Stale" Tier 1 section) | Same script, on its next invocation | Reset (file deleted) the moment a run fires no WARN (fresh or cannot-verify, collapsed identically); incremented on every WARN-firing run, capped at 999 | **Ephemeral** — a freshness-check runtime file rather than an orchestrator one; listed here because this file is the repo's single runtime-file policy home |
| `.continuation-loop-guard` / `.continuation-loop-guard.tmp` | `orchestrator-postflight.sh` for `implement` operations (its own internal continuation-retry counter, distinct from the orchestrator loop guard above; previously owned inline by the now-deleted base lifecycle implement skill) | Same resume branch | Removed at postflight (`orchestrator-postflight.sh` Stage 10 for `implement`) | **Ephemeral** |
| `.postflight-loop-guard` | Any skill importing the shared `skill_create_postflight_marker()` block (`skill-reviser`, `skill-spawn`, every extension `skill-{domain}-research`/`skill-{domain}-implementation`, etc. — their own postflight retry marker) | Same skills' own postflight | Removed at postflight (`skill_cleanup()`, `orchestrator-postflight.sh` Stage 10) | **Ephemeral** |
| `.return-meta-*.json` (suffixed variants, e.g. `.return-meta-orchestrate.json`, `specs/.return-meta-multi-{session_id}.json`) | Distinct from the bare `.return-meta.json` above — see "The bare-vs-suffixed distinction" below | Varies by variant. **`specs/.return-meta-multi-{session_id}.json` has no reader anywhere in the source store today** — it is written for collision/audit hygiene only; a future reader-adder must add the read-time `session_id` verification check together with the reader, not separately | Varies | **Ephemeral** |
| `specs/.sessions/{session_id}.json` | `task-lock.sh session-register`/`session-heartbeat` | **`hooks/guard-destructive-git.sh`'s concurrency-gated history-rewrite predicate** — its first consumer in the source store. It reads entries directly and cwd-relatively (its own `pid`+`heartbeat_at` freshness check inlined, `kill -0` plus a `HISTORY_REWRITE_LIVE_MIN`-minute window) rather than via `task-lock.sh session-list`, because that command sources `deploy-root-guard.sh` (`exit 1`s from the source store) and anchors `PROJECT_ROOT` to its own `SCRIPT_DIR` rather than the caller's cwd — both fatal for a hermetically testable, cwd-relative hook. See `context/standards/git-safety.md`'s "A Second Hazard Class" section for the full design. | `task-lock.sh session-release` at session end; `task-lock.sh session-reap` after `SESSION_REGISTRY_REAP_MIN` (or sooner via the pid-liveness-shortened `dead-pid` band, floored by `SESSION_REGISTRY_DEAD_PID_MIN`) | **Ephemeral** |
| `.dispatch/{seq}.md` | `scripts/orchestrate-build-dispatch.sh`, once per dispatch | The dispatched agent, exactly once, immediately after being pointed at it by the lead's fixed pointer prompt | Bulk `rm -rf "${task_dir}/.dispatch/"` at every loop-termination site (single-task Stage 8, both effort modes) and the per-task MT-5 equivalent — **not** a per-dispatch `rm -f`, since this is the only per-task ephemeral entry that accumulates one file per dispatch rather than being a singleton overwritten in place | **Ephemeral** (directory class, like `.lock/` — probe a file inside it, e.g. `${PROBE_DIR}/.dispatch/1.md`) |
| `specs/.deploy-lock/` (directory, `owner` file) | `scripts/deploy-headless.sh` (fail-open mutex acquired inline, deliberately without sourcing `task-lock.sh` — this script is about to overwrite the deployed copy of that very file) | Same script's own acquire block, on the next invocation (holder-declared staleness via `DEPLOY_LOCK_STALE_SEC`, default 120s; warn-and-proceed on failure, never blocking) | `rm -rf` via a `trap release_deploy_mutex EXIT` at the end of the deploy invocation that created it | **Ephemeral** (directory class, like `.lock/`) |
| `specs/.scope-lock/` (directory) | `task-lock.sh`'s `acquire_scope_mutex`/`cmd_scope_acquire` (cross-task `file_scope` overlap check, generalized `acquire_named_mutex` primitive) | Same script's own acquire loop; fails closed (nonzero) on a 5s wait-budget timeout rather than ever failing open | `release_scope_mutex` (`rm -rf`) at the end of the held critical section, or reclaimed by a waiter past the holder-declared `stale_sec` (default 10s) | **Ephemeral** (directory class, like `.lock/`) |
| `specs/.commit-lock/` (directory) | `task-lock.sh`'s `acquire_commit_mutex`/`cmd_commit_acquire`, called from `scripts/git-commit-scoped.sh` to serialize the `git add` + `git commit` pair around scoped commits — a DISTINCT mutex from `.scope-lock/` above (distinct reentrancy flag, distinct staleness/budget: 30s/15000ms vs 10s/5000ms, sized for up to `MAX_TASKS=8` concurrent committers) | Same script's own acquire loop | `release_commit_mutex` (`rm -rf`) at the end of the held critical section, or reclaimed by a waiter past the holder-declared `stale_sec` (default 30s) | **Ephemeral** (directory class, like `.lock/`) |
| `specs/.errors.lock` | `scripts/errors-append.sh` (`flock -x` guard around both its `append` and read-modify-write subcommands, held across the entire read → merge/transform → validate → write) | Itself, for the duration of a single invocation | Released by `flock` at the end of the invocation | **Ephemeral** — structurally identical to `specs/.events.lock` above |
| `specs/tmp/` (directory, e.g. `claude-tts-notify.log`) | `hooks/tts-notify.sh` and `scripts/lifecycle-notify.sh` (append-only notification log, `LOG_FILE="specs/tmp/claude-tts-notify.log"`); `scripts/state-write.sh` also stages its own private `mktemp` write-ahead and spill files here (`TMP_DIR="$PROJECT_ROOT/specs/tmp"`) | The notify hooks read their own log only to append; `state-write.sh`'s staging files are read once by the same process that wrote them, immediately before `mv` | The notify log is append-only and never cleaned up by this policy (an operator's own concern); `state-write.sh`'s staging/spill files are removed by its own `mv`/cleanup trap within the same invocation | **Ephemeral** (directory class, like `.lock/`; deliberately root-scoped — `/specs/tmp/` — rather than `**/`-prefixed, since every writer targets the `specs/` top level only, never a per-task directory) |
| `specs/.orchestrator-deploy-ledger.json` | `scripts/orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy Checkpoint, via `scripts/lib/deploy-ledger-lib.sh`'s `deploy_ledger_write` (one of the checkpoint's five outcome branches: `clean`, `pre_existing`, `filtered`, `deploy_failed`, `blocking`) | The same checkpoint, on every LATER `/orchestrate` invocation (`deploy_ledger_read` + `deploy_ledger_decide`, consulted before the checkpoint's first expensive call) | Never — a single rolling record, overwritten in place (atomic tmp+`mv`) on every write; no cleanup site removes it | **Durable, machine-local (gitignored), hash-gated on read** — see the note immediately below; this is a THIRD disposition, distinct from both Ephemeral and (tracked) Durable provenance above |
| `.orchestrate-worktrees/<task_number>-<seq>/` (directory, repo-root-scoped) | `scripts/dispatch-worktree.sh provision` (the per-dispatch isolated `git worktree` checkout selected for lean4/cslib `implement` dispatches — see `context/patterns/batch-orchestration-guardrails.md`'s "Working-Tree and Build Isolation Posture" decision record) | The dispatched agent, for the lifetime of its own isolated dispatch; `dispatch-worktree.sh path` resolves it from the registry record below | `dispatch-worktree.sh release` (`git worktree remove`, after first stripping the hardlink-cloned `.claude/`/`.lake/` scratch so a plain release is never refused as "dirty" by content neither tracked nor meant to survive) on a clean outcome, or `dispatch-worktree.sh prune --session <sid>` reaping any registry record whose session differs from `<sid>` and whose age exceeds `DISPATCH_WORKTREE_STALE_SEC` | **Ephemeral** (directory class, like `.lock/`; deliberately root-scoped — `/.orchestrate-worktrees/` — not `**/`-prefixed, since every writer targets the repo root, never a per-task directory. The branch it sits on, `orchestrate/task-<task_number>-<seq>`, is NOT removed by `release` — a branch is durable git history, not runtime scratch, and is left for later inspection) |
| `specs/.worktree-registry/<task_number>-<seq>.json` | `scripts/dispatch-worktree.sh provision` (records `task_number`, `session_id`, `seq`, `branch`, `path`, `created_at` for the worktree row immediately above) | `dispatch-worktree.sh path`/`release`/`prune`, and `provision`'s own idempotent-reuse check | Removed by `release` on a clean outcome, or by `prune`'s age/session reap (see the worktree row above — the two are always removed together) | **Ephemeral** — no freshness gate; a git-restored or stale copy would point at a worktree that may no longer exist, exactly the ephemeral-class hazard this table's Overview section describes |

### A third disposition: durable, machine-local, and gitignored

`specs/.orchestrator-deploy-ledger.json` does not fit either of the two classes in "The Two-Class
Split" above. It is not **Ephemeral**: unlike every other row in this table, it is deliberately
DURABLE cross-invocation memory — the whole point of the durable redeploy ledger is that it
survives between separate `/orchestrate` runs, which is the opposite of per-cycle scratch state.
It is also not (tracked) **Durable provenance**: it is gitignored, not committed. The reason it is
gitignored despite being durable is that it describes THIS machine's own local `.claude/` deploy
state — content-hashing the source-store tree currently sitting on disk here — which would be
actively misleading if committed and read back on a different clone or a different machine's
checkout. A gitignored file here does NOT mean ephemeral, freshness-blind semantics: every read
is hash-gated (`deploy_ledger_decide` compares the ledger's recorded aggregate/per-path hashes
against a freshly recomputed `deploy_ledger_hash_state`), so a stale, git-restored, or
hand-edited copy can only ever cause an extra, unnecessary redeploy — never a false skip. See
`context/patterns/batch-orchestration-guardrails.md`'s "Durable redeploy ledger" paragraph for the
full skip-rule contract, and `scripts/lib/deploy-ledger-lib.sh`'s own header for the function-level
contract.

**Not classified here (reviewed and deliberately excluded)**: `.stray-handoff-{timestamp}.json`,
and, for the identical reason, `.stale-loop-guard-{ts}.json` / `.stale-churn-state-{ts}.json`.
Both orchestrate skills' stray-handoff sweep (`docs/architecture/handoff-schema.md`'s "Handoff
Writers" section) moves a misplaced handoff aside into this timestamped name specifically to
**preserve evidence of a bug** for a human to inspect — it is diagnostic output, not per-cycle
control-flow state nothing reads back with unconditional trust. Silently gitignoring it would
suppress the very evidence the sweep exists to surface. `.stale-loop-guard-{ts}.json` and
`.stale-churn-state-{ts}.json` (written by the hard-mode `loop-guard-staleness` detector described
below) are the same shape of artifact: preserved diagnostic evidence of a superseded runtime file,
never read back by anything, never itself a control-flow input. All three are intentionally left
out of both the ephemeral and durable-provenance classes above; if any recurs often enough to need
its own policy, that policy belongs to its own sweep/detector mechanism, not this file-tracking
split.

`specs/.eager-context-snapshot-{ISO8601}.json` is the same shape of exclusion for a different
reason: it is an **opt-in, human-invoked** diagnostic snapshot with no automated writer, whose
purpose is later human diffing across two points in time. It is never a control-flow input, so it
does not fit the ephemeral rationale, and it is not a per-dispatch audit trail either, so it is
not durable provenance — same "preserve the evidence, do not gitignore it" class as the
stray-handoff/stale-guard trio above. It is deliberately left out of both classes and out of the
lib's 18-member enumeration.

### The bare-vs-suffixed `.return-meta.json` distinction

**This distinction must never be collapsed.** The bare `specs/{NNN}_{SLUG}/.return-meta.json` is
the durable, per-dispatch outcome-recovery record described above and MUST stay tracked. Suffixed
variants — `specs/{NNN}_{SLUG}/.return-meta-orchestrate.json`, `specs/.return-meta-multi-{session_id}.json`,
round-numbered variants like `.return-meta-02.json` observed in this repo's archive — are a
different, ephemeral class: batch/scratch state or artifacts of a prior naming scheme, not the
one documented outcome-recovery contract in `docs/architecture/handoff-schema.md` and
`context/formats/return-metadata-file.md`. Keep the ignore pattern for the suffixed form (`**/.return-meta-*.json`)
even while the bare form is un-ignored — they are opposite dispositions, not the same file with a
looser glob.

### A newly-identified ephemeral class: `.drift-inspection.json`

The audit behind this standard was scoped to not assume the previously-known runtime-file names
were complete (`skills/skill-orchestrate/SKILL.md` Stage 5a). `.drift-inspection.json` fits the
ephemeral rationale exactly: it has no freshness gate, and — like the loop guard — its cleanup
fires only at Stage 8 postflight (full-loop termination), not between cycles, so a mid-loop
Stage 9 whole-directory `git add` can capture it while a multi-cycle run is still in flight. It is
therefore adopted into the ephemeral (gitignored) class alongside the loop guard, churn state, and
`.lock/`, consistent with (not a re-opening of) the decided two-class split — that split concerns
the two named durable files, not an exhaustive enumeration of every ephemeral name.

## Rationale: the freshness-gate asymmetry

The two classes are not an arbitrary grouping — they track a real, verifiable difference in how
each file is read back.

The loop guard is read completely unconditionally in **base mode**
(`skill-orchestrate/SKILL.md` Stage 2): `if [ -f "$loop_guard_file" ] && jq empty ...` resumes
`cycle_count` and `infra_failures` from whatever is on disk, with **no `session_id` comparison and
no mtime/staleness check**. Any syntactically valid guard at the expected path is trusted,
regardless of its age or which session wrote it. This sentence is scoped deliberately to base
mode and stays true there — base mode's own Stage 2 resume branch in `skill-orchestrate/SKILL.md`
is unchanged and still has no gate. **Hard mode now gates**: the SAME file's Stage 2, on its
hard-mode branch (formerly a separate standalone hard-mode engine's own Stage 2, since merged in
and deleted), runs a `loop-guard-staleness` detector before this same unconditional-trust read,
described in full in "Operational staleness: a second, orthogonal freshness axis" below.
`.drift-inspection.json` (trusted the instant its writer-fork returns, no independent freshness
re-check) is unaffected by either change. A committed-then-git-
restored copy of any of these is a genuine correctness hazard: it would silently resume a stale
cycle count, a stale churn history, or a stale drift signal — which is exactly the git-restoration
hazard the ephemeral/gitignored classification below protects against, a distinct hazard from the
operational staleness the new hard-mode detector addresses (see the two-axis distinction below).

The handoff has the opposite contract. `docs/architecture/handoff-schema.md` states: "**Readers
MUST check freshness.** ... Both orchestrators compare the file's mtime against
`dispatch_start_ts` ... and treat an out-of-window handoff exactly as they treat a missing one."
A restored-from-history handoff simply fails this check and is treated as absent — never silently
trusted. `.return-meta.json` has the equivalent gate at its one documented read site
(`orchestrate-recover-outcome.sh`): "A recovered outcome is fail-closed: only a present, **fresh
(within the current dispatch window)**, parseable `.return-meta.json` ... is ever treated as a
success," with the gate keyed on `meta_mtime` versus the current dispatch's `window_start_ts`.

**Ephemeral-and-ungated must be ignored; gated provenance is safe to track.** This is the
mechanism-level justification for the settled split, independent of (and consistent with) the
"durable audit trail" framing used to motivate it.

### Operational staleness: a second, orthogonal freshness axis

The ephemeral/gitignored classification above protects against exactly one hazard: a **git-
restored** stale copy of the loop guard, churn state, or drift-inspection file silently
reappearing on disk and being trusted. That classification stays correct and is unchanged by this
section.

There is a second, independent hazard it does **not** cover: a loop guard that is **genuinely
present on disk, never touched by git at all**, but simply superseded — written by an earlier,
now-obsolete line of work on the same task directory (a stale `max_cycles` from a since-edited
skill file, a `plan_version` from a plan that has since been revised) or just old enough that no
orchestration cycle has touched it in a very long time. Neither hazard subsumes the other: a file
can be git-clean and operationally stale, or git-restored and operationally current (immediately
after restoration, before any cycle runs). Both are live and both need a gate; this section
documents the second one, which hard mode alone implements today.

**Three OR-combined signals** (any one tripping is sufficient — each is independent evidence the
guard predates the live line of work), checked by the `loop-guard-staleness` detector inserted
into `skill-orchestrate/SKILL.md` Stage 2's hard-mode branch (formerly a separate standalone
hard-mode engine's own Stage 2, since merged in and deleted), immediately before the pre-existing
`if [ -f "$loop_guard_file" ] && jq empty ...` resume branch:

1. **Schema/version drift**: `guard.max_cycles != $MAX_CYCLES`. `MAX_CYCLES` changes only when the
   skill file itself is edited (e.g. the base-to-hard-mode bump from 5 to 13), so a mismatch means
   the guard predates the currently-running skill definition.
2. **Plan-lineage drift**: `guard.plan_version != <current latest plans/*.md basename>`, evaluated
   **only when both sides are non-empty and neither is the literal string `none`** — a missing or
   absent value is never itself evidence of staleness, it just means the check does not apply
   (e.g. a guard written before this field existed, or a task with no `plans/` directory yet). The
   latest-plan basename changes only when a plan artifact is actually written, so a mismatch means
   the guard predates the current plan revision.
3. **mtime-age backstop**: `now - mtime(guard) > ORCHESTRATOR_LOOP_GUARD_STALE_DAYS` days, default
   **7**, env-overridable. The guard is rewritten by the per-cycle Stage 3b update, so its mtime
   tracks last *cycle activity*, not creation — seven days means no orchestration cycle touched it
   across an entire working week, far outside any plausible conversational-resume gap and
   comfortably below the observed 13-day failure this detector was built to catch. It is a
   backstop, not the primary gate: the two drift signals above catch a superseded guard regardless
   of age. Note that `ORCHESTRATOR_SESSION_REAP_MIN`'s 4-hour default is deliberately **not** a
   usable anchor for this threshold — it protects a much shorter-lived class of file (the in-flight
   session registry), not a guard meant to survive across conversational turns spanning days.

**Why not gate on `session_id` equality (the explicitly rejected design)**: `session_id` is
regenerated on *every* `/orchestrate` invocation regardless of whether any work actually
progressed, so a gate keyed on it would flag every legitimate conversational resume — a 100%
false-positive rate by construction, and directly contrary to the loop guard's whole purpose of
surviving across conversational turns (this repo's Stage 2 comments already document exactly this
non-gating rationale for the churn file's own observational `session_id` tracking). All three
chosen signals above are structurally different from `session_id` in the property that matters:
none of them changes merely because a new invocation started. `MAX_CYCLES` changes only when the
skill file itself is edited; the latest-plan basename changes only when a plan artifact is
actually written; mtime advances only on a real cycle's Stage 3b update. An ordinary
cross-conversational-turn resume — same skill version, same plan, a guard touched within the last
`ORCHESTRATOR_LOOP_GUARD_STALE_DAYS` days — trips none of the three signals, by construction, even
though it always carries a brand-new `session_id`.

**On detection**: the tripped guard (and its lifecycle-coupled churn-state file, see below) is
**archived aside, never deleted**, with a loud named notice identifying which signal tripped and
where each file was preserved — the same "preserve the evidence" shape the pre-existing
stray-handoff sweep in this same file already uses for a misplaced handoff (see the Class Table's
stray-handoff exclusion note above). A fresh guard is then initialized at cycle 0 by the
pre-existing, unmodified fresh-init branch, which the archive naturally falls through to (the
`[ -f "$loop_guard_file" ]` test is false once the stale file has been moved aside). Never silently
trust a stale guard and never silently reset it without saying so.

**`.orchestrator-churn-state.json` inherits the loop guard's verdict** rather than deriving an
independent staleness signal of its own. This is justified by the Class Table's already-documented
1:1 lifecycle coupling between the two files: both are hard-mode-only, both are created in the same
Stage 2 block, and both are removed together only at full-loop termination. The churn file has no
`max_cycles`-equivalent schema constant and no lineage field of its own to drift-check — deriving a
second, independent detector for it would be needless surface area duplicating a decision the loop
guard's verdict already makes. When the loop guard is found stale, the churn file (if present) is
archived alongside it under the same timestamp suffix, purely as a consequence of the guard's
verdict, not its own judgment.

**Base mode is explicitly out of scope.** `skill-orchestrate/SKILL.md` carries the byte-for-byte
identical unconditional-trust shape in its own Stage 2 and is not changed by this detector — see
the Class Table row and Rationale paragraph above, both of which now state this asymmetry
explicitly rather than leaving it to be inferred.

### `cycle_count` semantics: per-run, not cumulative (per-run cycle-budget contract)

`cycle_count`, as read by the BATCH engine (`orchestrate-cycle-plan.sh`), is **per-task and
per-RUN — it resets to zero at the start of every `/orchestrate` invocation, and is never seeded
from or flushed to this durable guard file for budgeting purposes.** This supersedes an earlier
design (the "cumulative across invocations, by design" contract this section used to document)
whose own operator-typed continuation override (an authorization flag to reset the counter and
continue) is now WITHDRAWN end to end: there is no override any more, because there is no
cross-invocation counter left to override. The budget exists to bound work WITHIN one run (e.g.
a single hard, long-running proof or implementation); re-running `/orchestrate` is the explicit,
ordinary way to continue past an exhausted per-run budget — nothing special-cased, nothing
flag-gated.

The field `cycle_count` itself is left alone in the guard file's own JSON schema: never read,
never written by the batch engine any more, but not deleted or migrated either — an old guard
file predating this change needs no special handling, and any OTHER caller wanting to persist a
`cycle_count` for its own purposes (e.g. a future single-task resume) keeps working against
`orchestrate-loop-guard-init.sh --flush` unchanged. `test-session-runtime-files.sh` Case 3, which
protected the OLD cumulative-across-invocations contract, is inverted (not merely updated) to
assert the new per-run contract instead — a fresh session must start at `cycle_counts = 0`
regardless of what the durable file's `cycle_count` says.

**What DOES still cross invocations**: `dispatch_seq_counter` (Defect A; must never repeat a
value within a task across separate runs) is durably seeded (via `--seed`, read-only peek, taking
the max of the durable value and whatever the in-session counter already holds) and durably
flushed (via the NEW `orchestrate-loop-guard-init.sh --flush-seq` form) at every dispatch_seq mint
site in the batch engine — both the main per-task dispatch loop and the aux_dispatch[] emission
loop. This is the one piece of per-task state whose cross-run persistence is load-bearing: unlike
the cycle budget, a repeated `dispatch_seq` would let a new run's dispatch file silently collide
with (overwrite) a prior run's still-live one.

**Loop-guard-staleness detector disposition**: the 3-signal `loop-guard-staleness` detector
(schema/lineage/age mismatch, hard mode only — see above) is now MOOT for budgeting purposes in
the batch engine, because nothing about `cycle_count` is trusted for budgeting across invocations
any more — there is no cumulative counter left for a stale guard to corrupt. The detector itself
is unchanged and still fires for its own original purpose (protecting `detected_defects`,
`plan_version`, and the churn-state coupling described above); this is a scoping note about what
it no longer needs to protect, not a change to its own mechanics.

**Asymmetry note, retained for history**: the OLD design's "Asymmetry decision" (why budget
exhaustion was never folded into the 3-signal staleness detector as a fourth signal) is now
vacuous — there is no budget-exhaustion override left to fold in or keep separate. Recorded here
only so a reader following an old cross-reference to this subsection is not left wondering where
that paragraph went.

**Guard lifecycle is otherwise unchanged.** The loop guard is still `rm -f`'d only at full-loop
termination (see the Class Table row above); a partial exit leaves the guard fully in place,
exactly as before. Its ongoing job, post-this-change, is `dispatch_seq_counter` durability and
whatever else a future single-task resume needs from it — not per-task cycle budgeting.

### `pending_dispatch`: the durable, cross-invocation half of "do not charge for a read"

`pending_dispatch` — `{seq: int, phase: string, forced: bool, dispatch_file: string,
recorded_at: string, prior_status: string, prior_last_updated: string, prior_session_id: string,
prior_dispatch_seq_counter: int}` or absent — is a field on this same guard file, written by
`orchestrate-loop-guard-init.sh --record-pending` at the same charge site that durably flushes
`dispatch_seq_counter` (via the NEW `--flush-seq` form; see above — this site no longer touches
durable `cycle_count` at all, per the per-run cycle-budget contract), and cleared by
`--clear-pending` (called unconditionally by `orchestrate-cycle-postflight.sh` on every outcome —
success, failure, defer, off-schema all count — since reaching postflight at all is proof the
recorded dispatch was consumed). It is unconditionally carried forward like
`dispatch_seq_counter`/`detected_defects`/`plan_version`/`max_cycles` above — there is no
budget-reset override any more to specially clear it early.

The read side lives in `orchestrate-cycle-plan.sh`'s live per-task dispatch loop, immediately
before the in-session `cycle_counts[t]` increment: if a seeded `pending_dispatch` (read via
`orchestrate-loop-guard-init.sh --seed`, which now also returns this field) matches the freshly
composed row in `(phase, forced)` AND its recorded `dispatch_file` still exists on disk (proof no
postflight ever ran to consume it), the composition reuses the recorded `seq` and skips both the
in-session `cycle_counts[t]` increment and the durable `--flush-seq` call — this is a replay of
an already-charged, never-consumed dispatch, not a genuinely new cycle. This closes the specific
failure chain a live
`/orchestrate` run reproduced: a defect that let one invocation dispatch nothing while still
charging a cycle left that charge permanently stranded, since the NEXT invocation started from a
fresh, unrelated `mt_state_file` (keyed by a new `session_id`) with no way to see it — the durable
guard file, not the ephemeral multi-state file, is this mechanism's source of truth. Its
IN-SESSION counterpart — replaying an unconsumed COMPOSITION (the whole plan, not one task's
row) within the same `mt_state_file` — is `plan_cache`, a separate field on the multi-state file
itself; see `orchestrate-cycle-plan.sh`'s own header for that mechanism's full contract.

**The four `prior_*` fields** are the pre-dispatch pre-image captured at record time (never on a
replay — a replay reuses the existing record verbatim, since the current status is now the
in-flight one, not the pre-dispatch one): `prior_status`/`prior_last_updated`/`prior_session_id`
are this task's state.json entry as read immediately before the preflight status write that
overwrote them; `prior_dispatch_seq_counter` is the durable `dispatch_seq_counter` as it stood
before this charge's own `--flush-seq` call. They exist solely so
`scripts/orchestrate-unwind-dispatch.sh` (see `docs/architecture/orchestrate-state-machine.md`'s
"Unwinding an Unconsumed Dispatch" subsection) can restore a task to its exact pre-dispatch state
when a prepared dispatch is never issued (no agent call, no postflight). A `pending_dispatch`
record written before this task existed lacks these fields; the unwind script refuses to act on
such a legacy record rather than guessing.

## Consumer Repo Setup

**This is now automatic.** `scripts/init-specs.sh` — called from every command/skill/agent that
can be the first thing to touch `specs/` in a fresh consumer repo (`/task` create mode, `/review`
follow-up task creation, `skill-fix-it`, `skill-project-overview`, `skill-spawn`,
`meta-builder-agent`, and defensively at `/orchestrate`'s entry) — writes a managed, sentinel-
delimited block into that repo's `specs/.gitignore` on its first run, generated from
`runtime_specs_ignore_block()` (see "A sixth site" below). Because `specs/.gitignore`'s patterns
are matched relative to `specs/` itself, this single file gives FULL ephemeral-class coverage —
including `specs/.sessions/` (a `**/`-prefixed pattern matches at its own `.gitignore`'s root
too, not only at deeper nesting; verified live: `**/.sessions/` inside `specs/.gitignore` ignores
`specs/.sessions/*` directly). This supersedes an earlier limitation: `specs/.sessions/` used to
require the repo-root `.gitignore` specifically, because the only *other* delivery mechanism at
the time — `copy_category("root_files", ...)`, which deploys `root-files/` into the consumer's
`.claude/` directory, not the repo root (see `context/guides/loader-reference.md`) — could not
reach a `specs/`-rooted pattern (it would resolve to `.claude/specs/.sessions/`, matching
nothing real). `init-specs.sh` sidesteps that limitation entirely by writing `specs/.gitignore`
directly, a path `root_files` could never reach.

`init-specs.sh` also untracks (`git rm --cached`, never a working-tree delete) any ephemeral-class
file git already tracks under `specs/`, staging the removal for the caller's own scoped commit —
see "Untracking Already-Committed Ephemeral Files" below.

**No manual step is required** for a repo that only ever creates tasks through the wired call
sites above. The repo-root `.gitignore` block below is retained as an optional
belt-and-braces/legacy path — useful if a consumer repo wants ephemeral-class patterns visible at
the repo root too, or if `specs/` was bootstrapped some other way before this policy existed — not
because anything still depends on it. To add it anyway, place the following block in the consumer
repo's **own root** `/.gitignore` **by hand**:

```gitignore
# Ephemeral orchestrator runtime state: per-dispatch scratch, mutex directories, and loop
# guards. Ignored because these have no freshness gate on read — a git-restored copy would
# silently corrupt in-flight cycle/churn state. See
# agent-system/extensions/core/context/standards/orchestrator-runtime-files.md for the full
# two-class policy and rationale. Deliberately does NOT include .orchestrator-handoff.json or
# .return-meta.json — those are durable, freshness-gated provenance and MUST stay tracked.
# Canonical source: agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh
# (runtime_ignore_block()) -- this block is generated from that lib and pinned to it by
# tests/test-runtime-file-tracking.sh Case 3; do not hand-edit the pattern list here.
**/.lock/
**/.orchestrator-loop-guard
**/.continuation-loop-guard
**/.orchestrator-churn-state.json
**/.postflight-loop-guard
**/.orchestrator-multi-state*.json
**/.drift-inspection.json
**/.return-meta-*.json
**/.events.lock
**/.sessions/
**/.freshness-warn-streak.json
**/.dispatch/
**/.deploy-lock/
**/.scope-lock/
**/.commit-lock/
**/.errors.lock
/specs/tmp/
**/.orchestrator-deploy-ledger.json
```

Run `check-runtime-file-tracking.sh` afterward to confirm coverage (see "Verification" below).

### Automatic-wiring decision record

Three decisions made while wiring `init-specs.sh` into the codebase, recorded here so a future
reader does not re-litigate them:

- **Deploy does NOT call `init-specs.sh`.** `deploy-headless.sh` and the extension loader's
  `manager.resync_all`/`manager.load` are strictly `.claude/`-scoped today — they never touch
  `specs/` at all. `specs/` bootstrap is a task-lifecycle concern (triggered by the first attempt
  to create a task), not a deploy concern (triggered by a redeploy, which can happen with zero
  tasks ever created, or many times across a repo's life with no relationship to when `specs/`
  should be initialized). `.syncprotect`'s documented scope is hand-edited `.claude/**`/root
  files being skipped during a resync — it has no defined relationship to `specs/` either way,
  so calling `init-specs.sh` from deploy would be introducing a new, undocumented scope-crossing
  rather than extending an existing one. The six command/skill/agent call sites (plus the
  defensive `/orchestrate` site) already cover every documented first-touch path without deploy's
  involvement.
- **`command-gate-in.sh` is NOT wired.** It reads `specs/state.json` to look up an **existing**
  task by number (confirmed live: `grep -c next_project_number command-gate-in.sh` is `0` — it
  never reads that field at all). By the time any command reaches gate-in, a task already exists,
  so `specs/` is already bootstrapped by construction; gate-in is not a viable first-touch choke
  point.
- **Coordination with `move_session_state_files_out_of_specs_root`**: that task (if/when
  undertaken) will relocate some of today's `specs/`-root session-state files elsewhere, editing
  the same `scripts/lib/runtime-file-patterns.sh` and this standards file. Whichever of the two
  efforts lands second must re-check that the generated `specs/.gitignore` (via
  `runtime_specs_ignore_block()`) still covers every relocated path — a stale pattern list would
  silently stop ignoring a file it used to cover.

### Single source of truth (scope decision record)

This block, `scripts/check-runtime-file-tracking.sh`'s two internal lists (Check A's probe array
and Check B's tracked-file-regex array), and both deploy-harness test fixtures
(`scripts/tests/test-deploy-orphans.sh`, `scripts/tests/test-deploy-propagation.sh`) are five
sites that must agree on the same 18-member class. Before this decision, they were three
hand-maintained enumerations plus two fixtures claiming (falsely, by the time this was audited)
to "mirror" this markdown block by hand — the exact shape that let `.deploy-lock/`,
`.scope-lock/`, `.commit-lock/`, `.errors.lock`, and `.dispatch/` drift out of sync across the
sites in mutually inconsistent ways.

**Decision**: the two script-internal lists and both test fixtures now derive mechanically from
`scripts/lib/runtime-file-patterns.sh` — one canonical record (gitignore pattern, Check A probe
path, Check B regex, directory-class flag) per class member, sourced directly by
`check-runtime-file-tracking.sh` and by both fixtures when they seed a scratch repo's
`.gitignore`. This markdown block is the one site that *cannot* mechanically derive from the lib
(a markdown fenced block cannot `source` a bash file), so it is instead **pinned** to the lib: 
`scripts/tests/test-runtime-file-tracking.sh` Case 3 extracts this fenced block verbatim and
asserts it is byte-identical to the lib's `runtime_ignore_block()` output, failing loudly if a
future edit changes one without the other.

**Reasoning**: the lib was proportionate here because the mechanical consumers (a lint script and
two test fixtures) already shared an identical pattern-list shape, and the drift was actively
live in this repo's own history at audit time (Check A's probe list and Check B's regex list
inside the *same* script already disagreed on `.dispatch/`) — the maintenance-in-triplicate shape
was demonstrably the root cause, not a theoretical risk. Any future class member is added to the
lib once; the markdown block is regenerated from `runtime_ignore_block()` and the doc-sync test
catches a forgotten regeneration.

**This gitignore coverage is the primary, sufficient control.** The staging-narrowing described in
`git-staging-scope.md` is defense-in-depth for a repo that has not yet applied this block — it
does not replace it. A repo with full coverage above is protected purely by gitignore, regardless
of what any automated `git add` stages.

**A sixth site, added by the consumer-bootstrap work**: `scripts/lib/runtime-file-patterns.sh`
also exports `runtime_specs_ignore_block()`, a `specs/`-relative rewrite of the same 18-member
class (root-scoped patterns converted from repo-root form to `specs/`-relative form; `**/`-prefixed
patterns pass through unchanged). Its sole writer is `scripts/init-specs.sh`, which uses it to
populate the managed block of a fresh consumer repo's `specs/.gitignore` — see "Consumer Repo
Setup" below. Unlike the five sites above, this one needs no doc-sync pin of its own: it is
mechanically derived from `RUNTIME_FILE_PATTERNS` (the same array `runtime_ignore_block()` reads),
never a hand-written second list, so there is nothing for it to drift against.

## Untracking Already-Committed Ephemeral Files

If any ephemeral-class file was committed before this policy was applied (as observed live in
other consumer repos), untrack it while leaving it on disk:

```bash
git rm --cached specs/{NNN}_{SLUG}/.orchestrator-loop-guard
git rm -r --cached specs/{NNN}_{SLUG}/.lock/
```

`git rm --cached` (and its `-r` form for directories) removes the file from git's index only —
the working-tree copy is untouched, so an in-flight orchestration reading that file is never
disrupted by the untracking operation itself.

**Explicit prohibition: never run this against `.orchestrator-handoff.json` or
`.return-meta.json`.** They are the per-dispatch audit trail this policy is built to keep; the
`check-runtime-file-tracking.sh` script (Check C) actively verifies they are NOT ignored and
never suggests untracking them.

## Forward-Only Migration Note

Adopting this policy in a repo whose root `.gitignore` previously ignored
`.orchestrator-handoff.json`/`.return-meta.json` (a reversal, not a fresh addition) makes every
existing on-disk file of those two classes newly stageable the moment the ignore lines are
removed — but it does **not** retroactively backfill git history. A task directory that never
receives another commit keeps its existing handoff/return-meta files untracked indefinitely; only
future writes to directories that get a future commit are picked up. This is the accepted,
intentional shape of the migration: no bulk backfill commit is created as part of applying this
policy.

## Verification

`scripts/check-runtime-file-tracking.sh` (see that script's header for the full contract) proves
three things from any consumer repo root:

1. Every ephemeral pattern above actually ignores a representative path (`git check-ignore -q`).
2. No ephemeral-class file is currently tracked (`git ls-files` scan; prints the exact
   `git rm --cached` remediation if one is found).
3. `.orchestrator-handoff.json` and `.return-meta.json` are **not** ignored.

## Related Documentation

- `context/standards/git-staging-scope.md` — the staging-narrowing defense-in-depth layer
- `docs/architecture/handoff-schema.md` — the handoff's own freshness-gate contract and outcome-channel design
- `context/patterns/task-lock.md` — the `.lock/` mutex primitives
- `scripts/check-runtime-file-tracking.sh` — the verification check
