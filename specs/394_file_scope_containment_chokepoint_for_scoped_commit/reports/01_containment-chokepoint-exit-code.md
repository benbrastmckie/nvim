# Research Report: Task #394

**Task**: 394 - Specify and implement a file_scope-based containment chokepoint for
`git-commit-scoped.sh` / `git-commit-phase.sh`
**Started**: 2026-10-16
**Completed**: 2026-10-16
**Effort**: medium
**Dependencies**: task 304 (owns the current exit-code contract and V9 gate this task extends)
**Sources/Inputs**:
- `specs/archive/336_phase_commit_staging_has_no_scope_check/evidence/03_followup-mechanical-check.md`
  (authoritative starting point, named by the dispatch)
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (header + implementation)
- `agent-system/extensions/core/scripts/git-commit-phase.sh` (header + implementation)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (Phase-Commit Containment
  Self-Check prose, Phase Checkpoint Protocol)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (WORK (h)/(i): the
  per-cycle Containment advisory + drop-and-warn filter)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (Exit-Code Contract and
  Safety Gates table; Staging-Layer Containment Filter subsection)
- Per-extension implementation agents: lean, rust, typst, books, web, python, z3, nix, nvim, latex
- `specs/state.json` (task 394's own `file_scope`; schema of `active_projects[]`)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The gap the evidence file predicted is real and currently live.** Roughly a dozen
  per-extension implementation agents (lean, rust, typst, books, web, python, z3, nix, nvim,
  latex, and likely cslib/founder/epi) call `git-commit-scoped.sh` **directly** for every
  per-phase commit, already passing `--task {N}` (for the existing V5 Overlap/contention check),
  but their own prose still points at a Containment Self-Check that has since been **mechanized
  only inside `git-commit-phase.sh`** — a wrapper none of these agents invoke. That
  cross-reference is now dead prose: these agents' phase commits have **zero** Containment
  protection today.
- Two Containment implementations already exist, at two *other* layers, confirming the predicate
  and posture (drop-and-warn, fail-open) are settled, but neither reaches the gap above:
  `git-commit-phase.sh`'s self-check (phase commits that go through the wrapper — currently only
  `general-implementation-agent.md`), and `orchestrate-cycle-postflight.sh`'s WORK (h)/(i)
  advisory-then-filter (the final per-task "researched"/"planned"/"implemented" commit).
- **Recommended mechanism**: layer the Containment predicate onto `git-commit-scoped.sh`'s
  existing `--task <task_number>` flag, in the same `if [ -n "$contention_task_number" ]; then`
  block that already runs the V5 check. Every one of the ~12 unmigrated call sites already
  supplies `--task {N}` for V5, so this closes the gap with **zero call-site changes** — the
  exact "cannot be forgotten by a sixteenth agent definition" property the evidence file asked
  for.
- **Recommended exit code**: reuse exit `7`, exactly as reserved in task 304's own table —
  emitted only when a commit **succeeds** (`commit_exit == 0`) and one or more positive
  pathspecs were dropped as Containment-excluded (parallel to exit `6`'s V9 observability
  semantics, but for a different predicate). An all-dropped/nothing-committed shape folds into
  the existing exit `4` (V6), alongside V2/V9 drops, exactly as V9 drops already do.
- Posture: **drop-and-warn, never refuse**, fail-open on missing/empty/unreadable/malformed
  `file_scope` — matching both existing implementations and the "under-stage, never over-stage"
  direction, not a new refusal class.

## Context & Scope

Task 304 landed a V9 gate inside `git-commit-scoped.sh` that drops a pathspec whose **resolved
parent lies outside the repository**. That gate says nothing about a pathspec that is *inside*
the repository but outside the *dispatching task's own declared* `file_scope` — a narrower,
different predicate task 304 explicitly deferred and reserved exit code `7` for (see
`git-staging-scope.md`'s Exit-Code Contract table, row `7`, "Reserved for a separate, unfiled
`file_scope`-Containment chokepoint follow-up"). This task's scope, per its declared
`file_scope` in `specs/state.json`, is exactly three files: `git-commit-scoped.sh`, its test
suite `tests/test-git-commit-scoped.sh`, and `context/standards/git-staging-scope.md` — **not**
`git-commit-phase.sh`, confirming the chokepoint belongs inside the base script itself, with
`git-commit-phase.sh` named in the task title only as a consumer/caller to account for, not a
file this task edits.

The authoritative starting point is
`specs/archive/336_phase_commit_staging_has_no_scope_check/evidence/03_followup-mechanical-check.md`,
which left two mechanism shapes open (layer onto `--task`, or a distinct opt-in flag) and left
the exit-code question open ("a genuinely new exit code, OR a deliberately and explicitly reused
one"). Both are resolved below by evidence gathered in this pass, not asserted a priori.

## Findings

### Two Containment implementations already exist — and neither is the chokepoint

1. **`git-commit-phase.sh`'s Phase-Commit Containment Self-Check** (its own header, "PHASE-COMMIT
   CONTAINMENT SELF-CHECK" section): reads the task's `file_scope` from `specs/state.json`, carves
   out the four always-staged paths (task dir, `TODO.md`, `state.json`, plan path), applies the
   predicate (exact match, or either path a directory/glob ancestor of the other) to every
   derived `files_touched` entry, drops uncontained entries with a loud warning plus a
   non-fatal `issue-record.sh --class "scope excursion"` call, and fails open on any missing/
   malformed `file_scope`. Its own header explains the siting choice directly: "not inside
   `git-commit-scoped.sh` itself, since changing that script's own staging semantics remains out
   of scope [at the time that wrapper was built]." This task is the first to revisit that
   decision, with an explicit mandate (and a reserved exit code) to do so.
2. **`orchestrate-cycle-postflight.sh` WORK (h)/(i)**: WORK (h) is a **detection-only advisory**
   (`modified_files` vs. declared `file_scope`, with the task's own directory spliced in as an
   implicit always-in-scope member) — "no gate, no exit-code, no verdict effect." WORK (i) is a
   **drop-and-warn filter** applied to `modified_files` immediately before the per-cycle call
   into `git-commit-scoped.sh`, reaching only the final per-task completion commit
   (`researched`/`planned`/`implemented`), not any mid-dispatch phase commit.

Both are confirmed-correct, fail-open, drop-and-warn implementations of the identical
Containment predicate the evidence file specified. Both also structurally **cannot** reach a
caller that invokes `git-commit-scoped.sh` directly without going through either layer — which
is exactly what the unmigrated extension agents do.

### Confirmed, currently-live gap: ~12 extension implementation agents have no Containment protection

`agent-system/extensions/{lean,rust,typst,books,web,python,z3,nix,nvim,latex}/agents/*-implementation*-agent.md`
each hand-type a `stage_paths` array and invoke `git-commit-scoped.sh` **directly**, e.g. (lean):

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N} phase {P}: {phase_name}" \
  --session "{session_id}" \
  --honest-index-rows {N} \
  --task "{N}" \
  -- <modified-files-for-this-phase>
```

Every one of these already supplies `--task {N}`. Their own prose, immediately above the call,
still reads: "Before invoking, run the Phase-Commit Containment Self-Check (see
`general-implementation-agent.md`'s `#### Phase-Commit Containment Self-Check`)." That
referenced section, however, now states explicitly that the check "runs MECHANICALLY inside
`git-commit-phase.sh`" — a script these ~12 agents never call. The cross-reference is therefore
dead: there is no mechanism left for an agent reading this prose to actually run the check by
hand (the whole point of mechanizing it was to remove exactly that human-reliability step), and
no script-level enforcement reaches these call sites either. This is recorded as a live issue
(see Issue Log, `--class "dead cross-reference / stale self-check"`) — it is the precise
"forgotten by a sixteenth agent definition" failure mode the evidence file predicted, now
observed for roughly a dozen agents simultaneously rather than one hypothetical future one.

`git-staging-scope.md` itself already names this migration gap in its "Scope of the
`git-commit-phase.sh` migration" paragraph as "a real, separately-scoped follow-up, not folded
in here" — i.e. migrating these ~12 (or more) agents onto the wrapper is a known, acknowledged,
unfinished task. This research task's own `file_scope`, however, does **not** include any of
those per-extension agent files, nor `git-commit-phase.sh` — confirming the intended fix is not
"migrate everyone onto the wrapper" but "make the one script everyone already calls do the
check," which requires zero changes to any of those ~12 files.

### Mechanism: layering onto `--task` is feasible and is the right shape

`git-commit-scoped.sh`'s existing V5 block (header: "V5 contended-path refusal (--task opt-in
only)") already:
- gates on the same `contention_task_number` variable that `--task` populates;
- runs before V2/V3 and before any `git add` — a refusal here leaves nothing staged;
- has `PROJECT_ROOT`, `jq`, and a per-positive-pathspec loop already in scope;
- is unconditionally fail-open (`--task` omitted, or any read/parse error, proceeds exactly as
  today).

A Containment check can run in the same `[ -n "$contention_task_number" ]`-gated block: resolve
`specs/state.json`'s `active_projects[] | select(.project_number == $num) | .file_scope // []`
for `$contention_task_number` (the identical jq query `orchestrate-cycle-postflight.sh` WORK (h)
already uses), splice in the task's own directory as an implicit always-in-scope member
(`task_dir` is directly resolvable from the same state.json entry's `project_name` field —
confirmed present in `active_projects[]`'s schema — via the same `specs/{padded}_{project_name}/`
convention used everywhere else in this codebase), carve out the same four fixed paths
(`TASK_DIR/`, `TODO.md`, `state.json`, plan path — though `git-commit-scoped.sh` itself does not
know which positive pathspec is "the plan path"; see Risks below), and apply the identical
predicate (exact match, or directory/glob ancestor in either direction) already specified in
`git-commit-phase.sh`'s header and ported verbatim from `general-implementation-agent.md`'s
prose. No new flag is needed: the evidence file itself noted "none is known today" as a caller
wanting Overlap without Containment or vice versa, and this research found no such caller either
— every one of the ~15 recipes wired to `--task` wants both.

A **distinct opt-in flag** (the evidence file's second option) was considered and rejected: it
would require editing all ~15 call sites to add the new flag, reproducing exactly the
per-call-site migration burden the chokepoint exists to avoid, for no discovered benefit (no
caller wants one predicate without the other).

### Exit code: reuse the reserved `7`, scoped to the success/partial-drop case only

Task 304's own table (`git-staging-scope.md`, "Exit-Code Contract and Safety Gates") already
reserves `7` by name for this exact follow-up and explicitly warns the follow-up's author to read
the table "before proposing any code for it" — which this research has done. Proposing a
*different* code (reused or new) would contradict that explicit, named reservation without any
offsetting benefit; reusing `7` as reserved is the conservative, already-telegraphed choice.

The evidence file requires the two failure modes (V5 Overlap-refusal vs. Containment) to "remain
distinguishable... even though today's callers mostly do not." Exit `3` (V5) is a **refusal**:
nothing is staged, no commit happens. A Containment drop, by contrast, should **not** be a
refusal — it should inherit the drop-and-warn posture both existing implementations already
settled on, and the "under-stage, never over-stage" fail-safe direction that governs this whole
contract. The correct mapping, by analogy to the existing V9/V6 split (which already
distinguishes "repository-boundary drop" from "ordinary unmatched-path drop" while keeping both
reachable through the same exit codes):

| Shape | Exit code |
|---|---|
| Some (not all) positive pathspecs dropped as Containment-excluded; commit of the survivors succeeds (`commit_exit == 0`) | **7** (new, parallel to V9's exit `6`, but for the Containment predicate rather than the repository-boundary one) |
| All positive pathspecs dropped (by Containment, V2, V9, or any combination) and nothing commits | **4** (existing V6 path — `dropped_pathspecs` already carries V2 and V9 drops "undifferentiated for this gate's purposes"; Containment drops fold in identically, consistent with precedent) |
| `--task` omitted, or `file_scope` missing/empty/unreadable/malformed, or any internal error evaluating the predicate | No effect — proceeds exactly as today (fail-open) |

This keeps exit `3` (Overlap refusal, nothing staged), exit `6` (V9 repository-boundary,
observability), and the new exit `7` (Containment, observability) each independently
attributable, matching the evidence file's distinguishability requirement, while reusing the
existing exit-4 fold for the degenerate all-dropped case rather than inventing a second new code
for it.

### Secondary question (flagged, not resolved here): does `git-commit-phase.sh`'s own self-check become redundant?

`git-commit-phase.sh` already forwards `--task` to its inner `git-commit-scoped.sh` call. Once
that inner call also performs Containment, `git-commit-phase.sh`'s own self-check becomes a
duplicate for every caller that reaches it (currently only `general-implementation-agent.md`).
The duplicate is harmless (idempotent, fail-open, cheap) but is a candidate for de-duplication.
This research recommends **leaving it in place** for the planning/implementation phase to decide
explicitly — removing it is a cleanup, not a correctness requirement, and `git-commit-phase.sh`
is outside this task's declared `file_scope` regardless.

### Related, explicitly out-of-scope follow-ups surfaced but not pursued here

- `git-staging-scope.md`'s evidence-file "Rider" asked for a new "Phase Commit (mid-dispatch)"
  subsection documenting the phase-commit asymmetry. No section with that exact heading exists
  today; the content is already substantially covered by the existing `### implement` section's
  "Sanctioned per-phase implementation" paragraph and the "Staging-Layer Containment Filter"
  subsection. Authoring a dedicated subsection remains open but is not required to close this
  task's own scope (`git-staging-scope.md` is in this task's `file_scope`, so the plan phase may
  choose to add a short cross-reference there alongside the exit-code table update, without
  reopening the full Rider).
- Migrating the ~12+ per-extension agents onto `git-commit-phase.sh` (already named in
  `git-staging-scope.md` as a separately-scoped follow-up) is explicitly **not** needed to close
  this task, since the chokepoint-in-`git-commit-scoped.sh` design protects them without any
  edits to their files.
- A sibling, already-tracked TODO item (not this task) covers documenting the
  repo-relative-paths constraint on `modified_files` for ~10 "silent" agent definitions — unrelated
  predicate (producer-side field hygiene, not Containment), noted only to avoid conflating the two.

## Decisions

- **Mechanism**: layer the Containment check onto `git-commit-scoped.sh`'s existing `--task
  <task_number>` flag, in the same gated block as the existing V5 Overlap check — not a new,
  separate opt-in flag. Rationale: every live caller that needs this protection already supplies
  `--task`, so this closes the confirmed gap at ~12+ call sites with zero edits to those files.
- **Exit code**: reuse exit `7`, exactly as reserved by task 304, emitted only when a commit
  succeeds with one or more Containment-dropped paths (parallel to exit `6`'s V9 role for a
  different predicate). An all-dropped/nothing-committed shape folds into the existing exit `4`
  (V6), matching how V9 drops already fold into that same code.
- **Posture**: drop-and-warn, never refuse; fail-open on missing/empty/unreadable/malformed
  `file_scope`, exactly mirroring both existing Containment implementations and the
  "under-stage, never over-stage" direction. No new refusal exit code is introduced.
- **De-duplication of `git-commit-phase.sh`'s own self-check**: left as an open question for the
  planning phase, not resolved in this task (file is outside this task's `file_scope`).

## Risks & Mitigations

- **Plan-path exemption inside `git-commit-scoped.sh` is harder than inside the wrapper.**
  `git-commit-phase.sh` knows which positive pathspec is "the plan path" because it was passed
  explicitly via `--plan-path`. `git-commit-scoped.sh` has no such flag and cannot distinguish a
  plan-path pathspec from any other positive entry by inspection alone (a path like
  `specs/{NNN}_{SLUG}/plans/01_foo.md` is already inside the task directory, which the implicit
  own-task-directory membership rule already admits as in-scope). *Mitigation*: the directory/
  glob-ancestor half of the predicate already covers this — any path under the task's own
  `specs/{NNN}_{SLUG}/` tree (plans included) is contained by the implicit task-directory member
  regardless of whether it also happens to be "the plan path," so no separate plan-path carve-out
  is needed inside `git-commit-scoped.sh` itself. Only `TODO.md` and `state.json` need the same
  unconditional admission `orchestrate-cycle-postflight.sh` already gives them; these are
  resolvable as fixed literal paths, not caller-supplied flags.
- **Risk of double-dropping a path already excluded by an upstream layer.** A path dropped by
  `orchestrate-cycle-postflight.sh`'s WORK (i) filter before `git-commit-scoped.sh` is ever
  invoked is simply absent from the pathspec list the new inner check sees — it cannot be
  "double-dropped," only not re-evaluated, which is correct and harmless.
- **Risk of the new check misclassifying a legitimate out-of-task-directory but in-scope path**
  (a `file_scope` entry that is NOT under the task's own directory, e.g. a shared script file
  declared in scope). *Mitigation*: the predicate's exact-match / ancestor-in-either-direction
  rule already handles this — it is defined over `file_scope` entries directly, not merely the
  task directory, exactly as already implemented and tested in `git-commit-phase.sh`.
- **Risk to the existing test suite.** `tests/test-git-commit-scoped.sh` is in this task's
  `file_scope` precisely because new cases (fail-open with no `file_scope`, drop-and-continue
  with a partial scope, all-dropped exit-4 fold, exit-7 emission) must be added without
  regressing the V2/V3/V5/V6/V7/V8/V9 cases already there. No mitigation needed beyond normal
  test-suite discipline at implementation time.

## Context Extension Recommendations

- **Topic**: `git-staging-scope.md`'s Exit-Code Contract table currently documents `7` only as
  "RESERVED." Once implemented, that row needs a row-for-row update to the same prose style as
  rows `3` and `6` (this report's Decisions section supplies the exact semantics), plus a new
  gate label (e.g. "V10") alongside V2/V3/V5/V6/V7/V8/V9 documenting the Containment predicate,
  mirroring V9's own entry structure. This is in-scope for task 394's own `file_scope` (the
  standards doc is explicitly named) and should be done in the implementation phase, not deferred
  further.
- **Gap**: no existing context file documents the now-confirmed "dead self-check cross-reference"
  pattern (a prose instruction pointing at a section that was later mechanized into code the
  pointing document never calls) as a general anti-pattern. Not required for this task, but worth
  a `/learn` candidate for future prose-to-mechanism migrations in this codebase.

## Appendix

Search queries / commands used:
- `grep -rln "git-commit-scoped.sh"` across `agent-system/` to enumerate every caller
- `grep -n "git-commit-scoped.sh\|git-commit-phase.sh\|stage_paths"` per extension
  implementation agent (lean, rust, typst, books, web, python, z3, nix, nvim, latex)
- Direct reads of `git-commit-scoped.sh`'s and `git-commit-phase.sh`'s full header comments (V2
  through V9 gate descriptions, exit-code table)
- `jq -r '.active_projects[] | select(.project_number==394)'` against `specs/state.json` for this
  task's own declared `file_scope`
- `jq -r '.active_projects[0] | keys'` against `specs/state.json` to confirm `project_name` is
  available for `task_dir` resolution inside a future `--task`-gated Containment check
