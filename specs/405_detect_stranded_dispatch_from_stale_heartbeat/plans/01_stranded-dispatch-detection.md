# Implementation Plan: Detect a Stranded Dispatch From Its Own Stale Heartbeat

- **Task**: 405 - Detect a stranded dispatch from its own stale heartbeat instead of only after a recorded failure
- **Status**: [IMPLEMENTING]
- **Effort**: 11.5 hours
- **Dependencies**: None
- **Research Inputs**:
  - `specs/405_detect_stranded_dispatch_from_stale_heartbeat/reports/01_detect-stranded-dispatch.md`
  - `specs/405_detect_stranded_dispatch_from_stale_heartbeat/reports/01_discriminator-and-failed-remedy.md`
- **Artifacts**: plans/01_stranded-dispatch-detection.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build the missing *monitoring-context* consumer of `task-lock.sh check`'s existing `held-live`
state, as one small read-only probe script (`dispatch-strand-probe.sh`) that combines the
heartbeat signal the system already writes with two further cheap quiescence probes, and wire
that probe into the three readers that can actually act on it: `orchestrate-cycle-postflight.sh`
(a new advisory field, separate from `stall_suspected`), `skill-orchestrate/SKILL.md`'s Move 3
(route a detected strand into the existing one-re-prompt relay instead of `failed_tasks`), and
`reconcile-task-status.sh`'s demotion gate (which today actively misreads `held-live` as
healthy). In parallel, close the prevention half by extending `lint-agent-contracts.sh` with a
check that FAILs on the detach-then-await-a-notification shape in any agent contract. Definition
of done: the probe distinguishes a stranded dispatch from a healthy-but-slow one on fixtures of
both shapes, the detected-strand path reaches a re-prompt without the task being charged a
failed verdict, the per-context interpretation of `held-live` is documented in one named place,
and the forbidden wait shape is mechanically rejected.

### Research Integration

Both reports are integrated, and the second one *overrides* the naive reading of the task
description in two places:

1. **Staleness alone is not a sufficient signal.** Two healthy tasks were measured
   simultaneously `held-live` at `heartbeat_age_min=32` and `41` against a 30-minute threshold,
   and both completed normally minutes later. The heartbeat pulses at phase and dispatch
   boundaries, so a long final phase legitimately crosses the threshold. The detector therefore
   implements the measured **conjunction** (stale heartbeat AND no artifact movement AND no
   commit movement), and the healthy-but-slow shape is a first-class regression fixture, not an
   afterthought (Phase 2).
2. **A message to the stuck agent is not a remedy.** Messages drain at the receiver's next tool
   round and a stranded agent takes none. The remedy that worked was `TaskStop` → postflight →
   a FRESH dispatch at the same `dispatch_seq`. The loop's existing re-prompt relay is already
   shaped that way (one `Agent` call per queued entry, re-using the original `subagent_type`),
   so this plan reuses that relay verbatim rather than adding a second recovery path; the one
   correction owed is to `specs/ROADMAP.md`'s unfiled observation, which still prescribes
   re-prompting the agent directly (Phase 3).

Also integrated, from the first report: the prior, on-the-record ruling that a new detector
**must not** be an added disjunct to `stall_suspected`'s own trigger predicate — hence a
separate field, `stranded_suspected`; the reuse of `test-task-lock-liveness.sh` /
`test-session-registry.sh`'s zero-real-time `held-live` fixture construction (live holder pid via
`$$`, synthetic old `heartbeat_at`) rather than a newly derived one; the precedent of
`lint-agent-contracts.sh`'s Check H, including its curated-exclusion mechanism, for the
prevention half; and the finding that the forbidden literal phrase today occurs only in the two
Lean implementation-agent contracts, which are another task's declared territory and are
therefore carried as exclusions here rather than re-fixed.

One timing question the first report left explicitly open is resolved by this plan (see
"Decisions" below): the postflight consumer must capture the probe verdict **before** WORK (j)'s
`task-lock.sh release`, which runs earlier in the same script than the signal block.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`roadmap_flag` was not set on this dispatch and no `roadmap_path` was supplied, so no roadmap
phases are added and no roadmap snapshot/update phase exists. One narrowly scoped ROADMAP edit is
still owed on its own merits and is carried in Phase 3: the unfiled observation recording this
defect prescribes a remedy (re-prompt the agent directly) that the second research report
measured to be structurally unreachable, so leaving it uncorrected would send the next reader
down a dead end.

## Goals & Non-Goals

**Goals**:

- A single read-only probe that classifies one task's dispatch as `live` / `stranded` /
  `unknown` from the heartbeat the system already writes, reusing `task-lock.sh`'s own
  `TASK_LOCK_STALE_MIN` constant and `check` exit codes plus output prefixes — never a second
  staleness notion.
- The measured conjunction, not bare staleness: a healthy-but-slow dispatch at 32 or 41 minutes
  past the threshold must classify `live`.
- A detected strand reaches the existing one-re-prompt relay **without** the task first being
  charged a failed verdict.
- `held-live`'s interpretation documented once, per context: unchanged during lock acquisition
  (a live pid means "do not steal"), inverted during dispatch monitoring (a live pid plus a
  two-hour-stale heartbeat is the strand signature) — including the explicit caveat that the
  pid-alive half is weak evidence in the monitoring context.
- The two sites that today *actively* misclassify `held-live` as healthy outside the acquisition
  context are fixed, or explicitly recorded as out of scope with the reason.
- The detach-then-await-a-notification shape is mechanically rejected in agent contracts.

**Non-Goals**:

- Changing how harness notifications are delivered (dispatch-declared out of scope).
- Reaping or killing orphaned process trees (dispatch-declared out of scope): an orphan nothing
  reads exits on its own; the harm is the agent waiting on it.
- Widening `stall_suspected`'s own trigger predicate. A prior ruling on the record forbids it and
  this task produces no evidence bearing on it; the new signal is a separate field throughout.
- Editing `scripts/orchestrate-cycle-plan.sh`'s lock PROBE. Its same-session `held-live` branch
  has the same blind spot and the fix is small, but that file is a concurrent sibling's declared
  `file_scope` this same cycle (see the dispatch Territory block). It stays untouched here and is
  named as a follow-up in Phase 3's documentation so the gap is recorded rather than forgotten.
- Editing `lean/agents/lean-implementation-agent.md` or
  `lean/agents/lean-implementation-hard-agent.md`. Their occurrences of the forbidden phrase are
  already owned and tracked elsewhere; Phase 7 carries them as curated lint exclusions instead of
  racing that owner's edit.
- Any process-tree walk or system-load reading inside the probe. Both were decisive for the human
  who diagnosed the live incident, and neither is mechanizable per task — see Decisions.

## Decisions

These are settled here so the implementer does not re-litigate them mid-phase.

1. **A new script, not a new `task-lock.sh` subcommand.** The probe composes lock state with
   artifact and commit evidence; folding non-lock concerns into the lock primitive would make the
   lock tool the owner of staleness policy it does not own. A separate script calling
   `task-lock.sh check` satisfies the "reuse the existing threshold constant and exit codes"
   requirement exactly, and earns strict-basename suite pairing
   (`dispatch-strand-probe.sh` → `tests/test-dispatch-strand-probe.sh`) in
   `scripts/lib/suite-selection-lib.sh` for free.
2. **Named `strand`, not `stall`.** `stall_suspected` already means the commit-gated
   abandoned-wrap-up signature. The new signal is lexically distinct (`dispatch-strand-probe.sh`,
   `stranded_suspected`) specifically so the two cannot be read as the same thing, which is the
   conflation the prior non-widening ruling exists to prevent.
3. **The conjunction's three terms are heartbeat staleness, artifact quiescence, and commit
   quiescence.** Deliberately excluded, with reasons recorded in the script header and in
   Phase 3's documentation: (a) a process-descendant walk — the recorded holder pid is commonly a
   shared ancestor `claude` pid (`pid_source: ancestor-claude`), so descendants cannot be
   attributed to one dispatch, and name-matching process lookups (`ps | grep`, `pgrep -f`) are
   forbidden by `bounded-build-waiter.md` Rule 2; (b) system load — global, not task-attributable,
   and the measured idle-load tell was an operator-grade judgement, not a per-task signal.
4. **Fail closed.** `check` exit 3 (resolution error), an unreadable task directory, or any
   ambiguity yields `unknown`, never `stranded`. No consumer acts on `unknown`.
5. **The postflight field is advisory and phase-agnostic.** It never changes `verdict`,
   `persisted_status`, or `failed_tasks` bookkeeping. Unlike `stall_suspected` it is not
   restricted to `plan`/`implement` and is not commit-gated — that is precisely the gap it exists
   to close, since the measured total-loss instance was a research dispatch with zero commits.
6. **The probe verdict must be captured early in postflight.** WORK (j) releases the per-task
   lock before the signal-computation block runs in the multi-task engine, so a probe call sited
   with the other signals would read `free` and never fire. Phase 4 captures the verdict before
   WORK (j) and consumes the captured value later.
7. **Honest coverage boundary, stated rather than papered over.** A heartbeat-based detector
   cannot fire for a dispatch that strands and then *returns promptly* with a still-fresh
   heartbeat — the measured research-dispatch shape. For that shape `report_missing` plus the
   message-findings recovery already detect, and the residual cost is the failure charge, which
   is a separate concern this plan does not widen into. Phase 3 records this boundary explicitly
   so a future reader does not mistake the detector for complete coverage.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Detector false-positives on a healthy long final phase (measured: 32 and 41 min past threshold) | H | H | The three-term conjunction, plus a dedicated healthy-but-slow fixture in Phase 2 that must classify `live`; Phase 6 gates the only status-mutating consumer on `stranded` alone |
| A demotion fires under a genuinely live dispatch and races real work | H | M | `reconcile-task-status.sh` keeps refusing on `held-fresh` unchanged, and demotes on `held-live` only when the probe returns `stranded`; every demotion and every refusal stays loudly logged, as that gate already requires |
| The new field is read as a licence to widen `stall_suspected` | M | M | Separate field, separate computation block, separate name; the non-widening ruling restated in the field's own comment and in Phase 5's documentation |
| New probe call makes postflight slower or introduces a failure mode in the hot path | M | L | Probe is read-only, calls `task-lock.sh check` once plus two `find`/`git log` probes; its call site tolerates any nonzero exit by treating the verdict as `unknown` |
| Prevention lint FAILs the repository on files another task owns | M | H (without mitigation) | Curated exclusion list carrying exactly the two Lean contracts, with the per-file reason recorded inline, mirroring Check H's existing exclusion mechanism |
| New script undeclared in the extension manifest, failing the undeclared-scripts rule | L | M | Phase 1 declares it via `sync-manifest-scripts.sh --write` and verifies with `check-extension-docs.sh` |
| Sibling task edits collide on a shared file this same cycle | M | M | `orchestrate-cycle-plan.sh` and `context/formats/plan-format.md` are excluded by Non-Goals; every phase re-reads its target immediately before editing and stages only its own explicit file list |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 7 | -- |
| 2 | 2, 3, 4, 6 | 1 |
| 3 | 5 | 4 |
| 4 | 8 | 2, 3, 5, 6, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: The strand probe script [COMPLETED]

**Goal**: One read-only script that classifies a single task's dispatch as `live` / `stranded` /
`unknown` by composing `task-lock.sh check`'s existing output with artifact and commit
quiescence, emitting one compact JSON line and never mutating anything.

**Tasks**:

- [x] Create `scripts/dispatch-strand-probe.sh` with usage
      `dispatch-strand-probe.sh <task_number> [--task-dir DIR] [--repo-root DIR] [--json]`.
- [x] Call `bash "${SCRIPT_DIR}/task-lock.sh" check "$task_number"` exactly once, capturing both
      the output line and the exit code using the `if VAR=$(cmd); then ... else rc=$?; fi` shape
      `reconcile-task-status.sh`'s demote gate already uses (a bare assignment under
      `set -e` would abort on the routine nonzero exits `check` documents).
- [x] Classify the lock term from the output line's **text prefix**, not the exit code alone:
      `free` and `held-fresh` → heartbeat not stale; `held-live` and `held-stale` → stale;
      exit 3 or an unrecognized prefix → `unknown`.
- [x] Parse `heartbeat_age_min` and `threshold_min` off the same line rather than recomputing
      either; the threshold constant is `task-lock.sh`'s to own.
- [x] Implement artifact quiescence: newest mtime of any regular file under the task directory,
      EXCLUDING `.lock/` (whose `holder.json` carries the heartbeat itself, so including it would
      make the term vacuous) and `.dispatch/`. Compare against a cutoff computed as
      `now - threshold_min*60` with controlled epoch arithmetic — never a `sleep`.
- [x] Implement commit quiescence with the same `git log --oneline --since=@<cutoff> -- <task_dir>`
      count shape `orchestrate-cycle-postflight.sh`'s existing stall block already uses, so the
      two signals cannot drift into two different notions of "a commit landed".
- [x] Resolve the verdict: `stranded` iff stale-heartbeat AND artifact-quiescent AND
      commit-quiescent; `live` if the heartbeat is fresh or either quiescence term shows
      movement; `unknown` on any resolution error. Fail closed — `unknown` is never `stranded`.
- [x] Emit one compact JSON line:
      `{task, verdict, lock_state, heartbeat_age_min, threshold_min, artifact_age_min, commits_in_window, evidence}`
      where `evidence` is an array of short strings naming which terms fired. Exit 0 for any
      verdict (verdicts are data, mirroring `orchestrate-cycle-plan.sh`'s and
      `orchestrate-batch-admit.sh`'s convention); exit 2 only for a usage error or a missing
      collaborator.
- [x] Write the script header to carry: the per-context interpretation in one paragraph (why a
      live pid means the opposite here from what it means during acquisition), the three
      conjunction terms, and the two deliberately rejected signals with their reasons
      (Decision 3). Reference `context/patterns/task-lock.md` by section name.
- [x] Declare the new script in the core extension manifest via
      `bash scripts/sync-manifest-scripts.sh --write`, then confirm with
      `bash scripts/check-extension-docs.sh` that no undeclared-script finding remains.
- [x] Smoke-verify against a throwaway fixture root built by hand (live holder pid `$$`,
      synthetic stale `heartbeat_at`, quiescent task dir) that the verdict is `stranded`, and
      against the same fixture with a freshly touched artifact that the verdict is `live`.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-shellcheck.sh`
plus the hand-built smoke fixture above covers a brand-new standalone script that no other module
yet calls, so nothing outside this one file can break.

**Scope Hypothesis**: This phase asserts that `task-lock.sh check` emits
`heartbeat_age_min=`/`threshold_min=` as parseable appended fields on all three held-* prefixes
and that exit 3 is its only resolution-error code (carried from
`reports/01_detect-stranded-dispatch.md` Finding 1 and the script's own header table); confirm by
reading `cmd_check` and the exit-code table in `scripts/task-lock.sh` before writing the parser.

**Files to modify**:

- `agent-system/extensions/core/scripts/dispatch-strand-probe.sh` - new file, the probe
- `agent-system/extensions/core/manifest.json` - declare the new script (via `sync-manifest-scripts.sh --write`, not by hand)

**Verification**:

- `bash agent-system/extensions/core/scripts/dispatch-strand-probe.sh --help` exits 2 or prints
  usage without touching any tree.
- The two smoke fixtures above produce `stranded` and `live` respectively, with a non-empty
  `evidence` array in each.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-shellcheck.sh`
  passes.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no undeclared
  script.

---

### Phase 2: Probe regression suite, both shapes [COMPLETED]

**Goal**: A fixture-driven suite that proves the probe fires on the stranded shape AND stays
silent on the measured healthy-but-slow shape, with no real sleeping and no contact with the real
`specs/` tree.

**Tasks**:

- [x] Create `scripts/tests/test-dispatch-strand-probe.sh`, modelled structurally on
      `scripts/tests/test-task-lock-liveness.sh`: isolated `mktemp -d` root satisfying
      `deploy-root-guard.sh`'s "`.claude/scripts/`, two levels under root" shape, the real
      `task-lock.sh` and its sibling dependencies copied in, `pass()`/`fail()`/`info()` helpers,
      a cleanup trap, and controlled-epoch timestamp helpers.
- [x] Reuse that suite's live-pid technique verbatim: `$$` as the guaranteed-live holder pid, and
      its downward-probe technique for a guaranteed-dead pid.
- [x] Case: **stranded** — live holder pid, `heartbeat_at` well past the threshold, session
      registry entry resolving `pid-alive`, task directory with no file touched inside the
      window, no commit in the window. Assert `verdict == "stranded"` and that `evidence` names
      all three terms.
- [x] Case: **healthy-but-slow (the false-positive regression)** — identical lock and session
      fixture at `heartbeat_age_min` just past the threshold, but one artifact file touched
      inside the window. Assert `verdict == "live"`. Record in the case comment that this shape
      was measured twice on live, healthy tasks that completed normally minutes later, so a
      staleness-only detector would have flagged both.
- [x] Case: **held-fresh** — heartbeat inside the threshold. Assert `verdict == "live"` and that
      no quiescence probe was needed to reach it.
- [x] Case: **unknown / fail-closed** — a task number that resolves to no directory. Assert
      `verdict == "unknown"` and, explicitly, that it is not `stranded`.
- [x] Case: **no side effects** — a before/after `find`-based manifest of the fixture root is
      byte-identical across a full run, proving the probe writes nothing (the shape
      `test-script-inventory.sh`'s own no-side-effects case already uses).
- [x] Exit 0 on all-pass, 1 on any failure, 2 on environment error, matching the suite
      conventions in this directory.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-dispatch-strand-probe.sh`
is the suite this phase creates and is the only consumer of the file it adds.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-dispatch-strand-probe.sh` - new suite, five cases

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-dispatch-strand-probe.sh`
  passes with all five cases green.
- Negative control, run once by hand and recorded in the suite header the way
  `test-task-lock-liveness.sh` records its own: inverting the probe's conjunction to a bare
  staleness test flips the healthy-but-slow case red. A suite that cannot be made to fail is not
  evidence.

---

### Phase 3: Document the per-context interpretation [COMPLETED]

**Goal**: One named place states how `held-live` must be read in each context, why the pid-alive
half is weak evidence during monitoring, which signals were rejected and why, and what the
detector does not cover — plus the one ROADMAP correction owed.

**Tasks**:

- [x] Add a named subsection to `context/patterns/task-lock.md`, immediately after the existing
      "`held-live`: stale-heartbeat-but-pid-alive" section, titled so it is findable on its own
      (for example "`held-live` Interpretation Is Context-Dependent, Not Universal").
- [x] State both readings side by side: during **acquisition** (`cmd_acquire`'s cross-task overlap
      pass) a live pid means "a live session may be working, do not steal" — unchanged; during
      **in-flight or post-return dispatch monitoring** the same observation is the strand
      signature, because the heartbeat staleness is doing the discriminating work.
- [x] State the weak-evidence caveat explicitly, grounded in the existing "Keyed on `session_id`,
      never on `pid`" paragraph: two independent sessions inside one Claude Code process can share
      an ancestor pid, so `pid-alive` can be true for the whole orchestrator run regardless of
      whether the specific dispatch is productive. A reader must not mistake the pid check for a
      strong liveness proof in the monitoring context the way it legitimately is during
      acquisition.
- [x] State the conjunction requirement and the measured false-positive evidence: two healthy
      tasks simultaneously `held-live` at 32 and 41 minutes past a 30-minute threshold, both
      completing normally minutes later, because the heartbeat pulses at phase and dispatch
      boundaries and a long final phase legitimately crosses the threshold.
- [x] Record the two rejected signals with their reasons (shared ancestor pid defeats descendant
      attribution and name-matching process lookups are forbidden; system load is global, not
      task-attributable) so neither is re-proposed as an obvious improvement.
- [x] Name the consumers: `dispatch-strand-probe.sh` as the monitoring-context reader, and the
      three sites that consume its verdict. Record, as a named gap rather than a silent one, that
      `orchestrate-cycle-plan.sh`'s lock PROBE still groups same-session `held-live` with
      `held-fresh` and is deliberately untouched here because it is another task's live territory.
- [x] Record the honest coverage boundary (Decision 7): the detector cannot fire for a dispatch
      that strands and returns promptly with a fresh heartbeat; that shape is `report_missing`'s
      and the message-findings recovery's ground.
- [x] Correct `specs/ROADMAP.md`'s unfiled observation of this defect: its prescribed remedy
      ("re-prompt the agent directly") is structurally unreachable, because messages drain at the
      receiver's next tool round and a stranded agent takes none. Replace it with the sequence
      measured to work — stop the agent, run postflight, then issue a FRESH dispatch at the same
      `dispatch_seq` — and point at the new subsection. Edit only that observation; touch nothing
      else in the file.
- [x] Re-read both target files immediately before editing (concurrent siblings are active on
      this tree) and stage only these two paths.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Both edits are pure prose with no executable surface, so the covering
checks are `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
for the source-store file plus the `prose` tier's diff read-through for `specs/ROADMAP.md`, which
lies in the task-reference lint's own exempt tree and maps to no suite.

**Scope Hypothesis**: This phase carries two figures from
`reports/01_discriminator-and-failed-remedy.md` Findings 2 and 5 — the `32`/`41`-minute
false-positive ages and the unreachable-message remedy. Both are field observations from a single
live batch and are not re-derivable from the codebase; cite them as observed measurements with
their report as the source, and do not restate them as general rates.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/task-lock.md` - new named subsection on context-dependent interpretation
- `specs/ROADMAP.md` - correct the unfiled observation's prescribed remedy only

**Verification**:

- The new subsection is reachable by its own heading and states both readings, the weak-evidence
  caveat, the conjunction, the rejected signals, the named `orchestrate-cycle-plan.sh` gap, and
  the coverage boundary.
- `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
  passes, with the exit status checked (not a stdout diff).
- `git diff -- specs/ROADMAP.md` touches only the one observation.
- Diff read-through confirms no task-number reference and no record-versioning language entered
  the `agent-system/**` file.

---

### Phase 4: Postflight producer — `stranded_suspected` [COMPLETED]

**Goal**: `orchestrate-cycle-postflight.sh` emits a new advisory field computed from the probe,
captured before the lock is released, separate from `stall_suspected` in every respect.

**Tasks**:

- [x] Capture the probe verdict EARLY, before WORK (j)'s `task-lock.sh release` call, into a
      single variable (for example `strand_probe_json`). Site the call so it runs for both engines
      and under `--dry-run` (it is read-only, so a dry run reports the true current state).
- [x] Tolerate every failure mode: a missing script, a nonzero exit, or unparseable output yields
      a verdict of `unknown` and never fails postflight. No new hard dependency in the hot path.
- [x] Compute `stranded_suspected=true` exactly when: no usable outcome was recovered
      (`have_outcome != true`), `dispatch_start_ts` is known (not the sentinel), and the captured
      probe verdict is `stranded`. Phase-agnostic and NOT commit-gated — state in the comment that
      this is the deliberate difference from `stall_suspected`, which the measured zero-commit
      research-dispatch loss falls outside of by construction.
- [x] Write the field's comment block to state: the trigger, that the field is advisory and never
      changes `verdict`/`persisted_status`/`failed_tasks`, who the real consumer is, the
      DELIBERATE NON-WIDENING of `stall_suspected` (a separate field, never an added disjunct),
      and the early-capture requirement with the reason (the lock is released earlier in this same
      script).
- [x] Emit the field in BOTH output arms, alongside `stall_suspected`, so neither the single-task
      nor the multi-task emission path can silently omit it.
- [x] Extend the script's header Output contract with a `stranded_suspected:` paragraph in the
      same shape as the existing `stall_suspected:` and `report_missing:` paragraphs.
- [x] Add producer cases to `scripts/tests/test-orchestrate-cycle-postflight.sh`: field present
      and `false` on an ordinary successful dispatch; `true` on a no-outcome dispatch whose
      fixture lock is stranded; `false` on a no-outcome dispatch whose fixture lock is
      healthy-but-slow; present in both emission arms.
- [x] Re-read the script immediately before editing and stage only this phase's own hunks.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: The emitted JSON line is a cross-file contract, so verification spans the
changed script plus its enumerated direct consumers:
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh,test-stall-reprompt-wiring.sh,test-handoff-dispatch-identity.sh`.

**Scope Hypothesis**: This phase asserts that WORK (j)'s `task-lock.sh release` precedes the
`report_missing`/`stall_suspected` computation block in program order, and that a no-outcome
dispatch leaves `dispatch_status` empty (so WORK (j)'s own `failed_tasks` write does not fire and
the only charge point is the lead's Move 3). Confirm both by reading the release call site and the
verdict-resolution `else` arm before siting the new code — the whole "no failure charged" claim
rests on the second half.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - early probe capture, new field, both emission arms, header contract
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - four producer cases

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh,test-stall-reprompt-wiring.sh,test-handoff-dispatch-identity.sh`
  passes.
- `jq -e 'has("stranded_suspected")'` succeeds against the JSON line from both emission arms.
- A fixture run with the probe script deliberately absent still emits a decision line and exits 0,
  with `stranded_suspected=false`.
- `stall_suspected`'s own trigger expression is byte-identical to its pre-phase form
  (`git diff` confirms no edit inside that block).

---

### Phase 5: Lead consumer — route a strand to the existing relay [NOT STARTED]

**Goal**: `skill-orchestrate/SKILL.md`'s Move 3 reads the new field and routes a first-occurrence
strand into the existing `pending_stall_reprompt[]` queue instead of `failed_tasks`, so detection
precedes any failure charge; the state-machine document records the mechanism.

**Tasks**:

- [ ] In Move 3's extraction block, read `stranded_suspected` alongside `stall_suspected`
      (`// false` default, so an older postflight build cannot break the lead).
- [ ] In the `verdict = failed` branch, OR the two signals into the single re-prompt predicate the
      existing `jq` program already evaluates, keeping the existing `stall_reprompted[]`
      `{task, dispatch_seq}` idempotency key unchanged — exactly one re-prompt per dispatch_seq
      regardless of which signal fired.
- [ ] Keep the two signals distinguishable in the operator-facing line and in the ledger entry, so
      a reader can tell which detector fired; do not collapse them into one label.
- [ ] Reuse the existing relay unchanged. The remedy the relay already performs — one fresh `Agent`
      call per queued entry, same `subagent_type`, same `dispatch_seq`, followed by a re-run of
      postflight — is the sequence measured to actually recover a stranded dispatch. Add no
      message-to-the-stuck-agent path: a message drains at the receiver's next tool round and a
      stranded agent takes none.
- [ ] Update `docs/architecture/orchestrate-state-machine.md`: extend the "Abandoned Wrap-Up"
      section with the new signal and its distinct trigger, restate the non-widening ruling, and
      name the probe in the "Diagnosing Dispatch Liveness: A Probe for External Watchers" section
      as the mechanical form of the guidance that section currently gives a human — including that
      the conjunction it already recommends (artifact mtimes, live descendants) is what the probe
      mechanizes, minus the descendant term and why.
- [ ] Record in the `mt_state_file` field reference that `pending_stall_reprompt[]`/`stall_ledger[]`
      entries can now originate from either signal, and which field each entry carries.
- [ ] Extend `scripts/tests/test-stall-reprompt-wiring.sh` with the same producer/consumer
      assertions it already makes for `stall_suspected`: the producer computes and emits the new
      field, the consumer extracts it, the re-prompt predicate references it, and the
      state-machine document documents it. This suite exists precisely to catch a signal that is
      computed and documented but has no consumer.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-stall-reprompt-wiring.sh`
is the static producer/consumer wiring suite that covers exactly these three files and is the only
mechanical consumer of their wiring.

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Move 3 extraction and re-prompt predicate
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - Abandoned Wrap-Up, liveness-probe section, mt_state_file field reference
- `agent-system/extensions/core/scripts/tests/test-stall-reprompt-wiring.sh` - wiring assertions for the new field

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-stall-reprompt-wiring.sh`
  passes, including the new assertions.
- Diff read-through confirms the `failed_tasks` write is reachable only when the re-prompt has
  already been spent for that `dispatch_seq` — the property that makes detection precede the
  failure charge.
- No new message-based recovery path was introduced.

---

### Phase 6: Fix the reconcile demotion gate's `held-live` conflation [COMPLETED]

**Goal**: `reconcile-task-status.sh` stops reading `held-live` as healthy. `held-fresh` still
refuses demotion unchanged; `held-live` consults the probe and demotes only on a `stranded`
verdict, with the evidence logged.

**Tasks**:

- [x] Re-read `demote_stranded_status()` and its exit-code gate comment, then split the exit-1 arm
      on the captured output line's **text prefix**: `held-fresh` keeps today's refusal message
      byte-for-byte; `held-live` becomes its own branch.
- [x] In the `held-live` branch, call `dispatch-strand-probe.sh` for the same task. On `stranded`,
      demote through the existing `state-write.sh` path with a log line naming the probe verdict,
      the heartbeat age, the threshold, and the evidence terms. On `live` or `unknown`, refuse —
      with wording distinct from the `held-fresh` refusal, so the log says which condition was
      observed.
- [x] Update the function's exit-code gate comment block so the documented mapping matches the
      code: the prose currently says exit 1 means a fresh lock and must never demote, which is
      exactly the conflation being fixed.
- [x] Preserve the fail-closed posture for exit 3 and for a probe that cannot be run at all:
      refuse, never demote.
- [x] Create `scripts/tests/test-reconcile-demote-stranded.sh` (referencing
      `reconcile-task-status.sh` by basename so suite selection maps the script to it): cases for
      `free` → demote, `held-stale` → demote, `held-fresh` → refuse with the unchanged message,
      `held-live` + probe `stranded` → demote, `held-live` + probe `live` → refuse,
      `held-live` + probe `unknown` → refuse, resolution error → refuse. Use `--dry-run` where
      available so no case mutates a real state file.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-reconcile-demote-stranded.sh,test-reconcile-handoff-status.sh`
covers the changed function and the only other suite that exercises this script, and the edit adds
no externally visible signature.

**Scope Hypothesis**: This phase asserts that `demote_stranded_status()` is the only site in
`reconcile-task-status.sh` that branches on `task-lock.sh check`'s exit code; confirm with
`grep -n 'task-lock.sh' agent-system/extensions/core/scripts/reconcile-task-status.sh` before
editing, and widen the phase's own file list rather than its claim if a second site exists.

**Files to modify**:

- `agent-system/extensions/core/scripts/reconcile-task-status.sh` - split the exit-1 arm, consult the probe, correct the gate comment
- `agent-system/extensions/core/scripts/tests/test-reconcile-demote-stranded.sh` - new suite, seven cases

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-reconcile-demote-stranded.sh,test-reconcile-handoff-status.sh`
  passes.
- The `held-fresh` refusal message is unchanged (`git diff` shows no edit to that string).
- Every branch logs — no silent demotion and no silent refusal, as that function's own header
  requires.

---

### Phase 7: Prevention — lint the await-a-notification shape [COMPLETED]

**Goal**: An agent contract that pairs backgrounding with "wait for the completion notification"
fails the agent-contracts lint, with the forbidden text sourced from one canonical home and the
two already-owned Lean contracts carried as curated exclusions.

**Tasks**:

- [x] Add a "Forbidden-Shape Lint Anchor" subsection to `context/patterns/bounded-build-waiter.md`,
      beside the existing "Copy this exact text" generated-copy source, carrying the forbidden
      phrasings in a fenced block so the lint reads them from source rather than transcribing them
      — the same read-from-source discipline Checks C, F, G and H already follow.
- [x] Add `check_k_await_notification_antipattern()` to `scripts/lint/lint-agent-contracts.sh`
      (A through J are taken) and register it in `main()` in letter order.
- [x] Scope: every dispatchable agent contract under the agents root, not only the narrower
      bounded-wait in-scope list — Check H's own scope answers a different question (presence of
      the canonical bullet pair), and this check answers absence of a contradicting instruction,
      which is the gap Check H's presence-only design leaves open.
- [x] Predicate: FAIL a file that carries a notification-await phrase from the anchor block
      together with a backgrounding or Monitor-arming instruction; PASS a file carrying neither, or
      carrying the phrase only inside an explicitly prohibitive sentence. Keep the predicate
      conservative enough that the canonical prose homes, which quote the forbidden shape in order
      to forbid it, do not self-trip.
- [x] Curated exclusion list carrying exactly `lean/agents/lean-implementation-agent.md` and
      `lean/agents/lean-implementation-hard-agent.md`, each with its per-file reason recorded
      inline and the removal condition stated — mirroring Check H's exclusion block, and
      referencing the files by path and the owning work by durable anchor, never by task number.
- [x] Include a verbatim re-audit reproduce command in the check's header comment, as Check H does,
      so a future auditor can re-derive the occurrence set rather than trusting a dated count.
- [x] Create `scripts/tests/test-lint-agent-contracts-await-notification.sh`, modelled on
      `test-lint-agent-contracts-heartbeat.sh`: a fixture agents root with one clean file (PASS),
      one violating file (FAIL), one excluded-path violating file (not a FAIL), and one file
      quoting the phrase prohibitively (PASS). Assert on the check's own output lines and the
      script's exit code.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts-await-notification.sh,test-lint-agent-contracts.sh,test-lint-shellcheck.sh`
covers the changed lint and its fixture suites, and the anchor block is prose with no executable
surface of its own.

**Scope Hypothesis**: This phase carries two figures from
`reports/01_detect-stranded-dispatch.md` Findings 6 and 7 — that check letters A through J are
taken, and that the literal forbidden phrase occurs today only in the two named Lean contracts
(five and two occurrences). Re-derive both before writing the check:
`grep -o 'check_[a-z]_' agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh | sort -u`
and `grep -rc 'completion notification' agent-system/extensions/*/agents/*.md`. If a third file
now matches, decide explicitly whether it is an exclusion or a genuine FAIL rather than widening
the list by reflex.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` - forbidden-shape lint anchor block
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - Check K plus its exclusion list and main() registration
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-await-notification.sh` - new fixture suite, four cases

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts-await-notification.sh,test-lint-agent-contracts.sh,test-lint-shellcheck.sh`
  passes.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` against the real tree
  exits 0 (the two Lean contracts are excluded, nothing else matches), with the exit status
  checked rather than a stdout diff.
- Removing one exclusion entry by hand turns the real-tree run red, proving the check is live and
  not vacuous. Restore the entry afterwards.

---

### Phase 8: Integration proof, full gate, redeploy [NOT STARTED]

**Goal**: Prove end to end that a stranded-shape fixture produces a detected strand that reaches
the re-prompt relay without the task being charged a failed verdict, then take the complete gate
set green and redeploy.

**Tasks**:

- [ ] Build the end-to-end fixture: an isolated root with a task whose lock has a live holder pid
      and a stale heartbeat, a quiescent task directory, a session registry entry resolving
      `pid-alive`, and no usable dispatch outcome — the shape the dispatch's verification
      requirement names.
- [ ] Run `orchestrate-cycle-postflight.sh` against it and assert `stranded_suspected=true` in the
      emitted JSON.
- [ ] Prove the no-failure-charge property mechanically, not by inspection: evaluate the lead's own
      routing expression against that JSON with a fixture `mt_state_file` and assert the task
      lands in `pending_stall_reprompt[]` and is ABSENT from `failed_tasks`. Then assert the
      second pass with the same `dispatch_seq` already present in `stall_reprompted[]` DOES charge
      `failed_tasks`, so the obligation is bounded to one re-prompt. A test that only passes once
      a failure is recorded would have reproduced the current behaviour, not the fix.
- [ ] Run the same end-to-end fixture in its healthy-but-slow variant and assert
      `stranded_suspected=false`, closing the false-positive case at the integration level too.
- [ ] Record the end-to-end case in whichever suite owns it (`test-stall-reprompt-wiring.sh` for
      the routing assertions, `test-dispatch-strand-probe.sh` for the fixture builder) rather than
      leaving it as a one-off manual transcript.
- [ ] Run the complete repository gate set: `bash .claude/scripts/verify-deploy.sh` (source-store
      path `agent-system/extensions/core/scripts/verify-deploy.sh`), with every gate it
      aggregates, no `--skip-slow` and no `--only-gate` narrowing.
- [ ] Redeploy the source store with `bash agent-system/extensions/core/scripts/deploy-headless.sh`
      so the deployed `.claude/` tree carries the new script, lint check and documentation, then
      re-run the full gate set against the deployed tree.
- [ ] Confirm the new script appears in the extension manifest and in no undeclared-script
      finding, and that the plan's own artifacts validate
      (`bash .claude/scripts/validate-artifact.sh <this plan> plan`).
- [ ] Final sweep for the two deliverable-content rules across every file this task touched under
      `agent-system/**`: no task-number references, no record-versioning language.

**Timing**: 1.5 hours

**Depends on**: 2, 3, 5, 6, 7

**Verification Tier**: full

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-stall-reprompt-wiring.sh` - end-to-end routing assertions
- `agent-system/extensions/core/scripts/tests/test-dispatch-strand-probe.sh` - end-to-end fixture builder reuse

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` exits 0 with its complete gate set, before and after the
  redeploy, exit status checked in both runs.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes across every discovered
  suite (not a selected subset — this is the final phase and selection is not evidence here).
- The routing assertions prove `pending_stall_reprompt[]` membership and `failed_tasks`
  non-membership on the first pass, and `failed_tasks` membership on the second.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no finding.
- `bash .claude/scripts/check-task-references.sh` and
  `bash agent-system/extensions/core/scripts/check-record-versioning.sh` report no finding on the
  touched files.

---

## Testing & Validation

- [ ] Probe classifies the stranded shape (live holder pid, stale heartbeat, quiescent artifacts
      and commits) as `stranded`, with all three evidence terms named.
- [ ] Probe classifies the measured healthy-but-slow shape (same lock state, one artifact touched
      inside the window) as `live` — the false-positive regression case.
- [ ] Probe classifies `held-fresh` as `live` and an unresolvable task as `unknown`, never
      `stranded`.
- [ ] Probe writes nothing: before/after fixture-root manifests are byte-identical.
- [ ] `stranded_suspected` is emitted in both postflight output arms, is `false` on a successful
      dispatch, and is `true` only on the conjunction.
- [ ] Postflight still emits a decision line and exits 0 when the probe script is absent.
- [ ] `stall_suspected`'s trigger expression is unchanged.
- [ ] A first-occurrence strand lands in `pending_stall_reprompt[]` and NOT in `failed_tasks`; a
      second occurrence at the same `dispatch_seq` does charge `failed_tasks`.
- [ ] `reconcile-task-status.sh` demotes on `held-live` + `stranded`, refuses on `held-live` +
      `live`/`unknown`, and refuses on `held-fresh` with its message unchanged.
- [ ] Check K FAILs a violating fixture contract, PASSes a clean one and a prohibitively-quoting
      one, and does not FAIL an excluded path; removing an exclusion turns the real-tree run red.
- [ ] Full gate set green before and after redeploy.
- [ ] No task-number references and no record-versioning language in any touched
      `agent-system/**` file.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/dispatch-strand-probe.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-dispatch-strand-probe.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-reconcile-demote-stranded.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-await-notification.sh` (new)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (new field, early probe capture, header contract)
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` (demotion gate split)
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` (Check K)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Move 3 routing)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (mechanism and field reference)
- `agent-system/extensions/core/context/patterns/task-lock.md` (per-context interpretation subsection)
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` (forbidden-shape lint anchor)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`, `test-stall-reprompt-wiring.sh` (extended)
- `agent-system/extensions/core/manifest.json` (script declaration)
- `specs/ROADMAP.md` (one observation's remedy corrected)
- A redeployed `.claude/` tree carrying all of the above

## Rollback/Contingency

Every phase is additive and independently revertable, and each lands as its own commit, so the
ordinary contingency is to revert the offending phase's commit and re-run the full gate set.

Two targeted fallbacks if a phase proves wrong rather than merely incomplete:

- **The detector false-positives in real operation.** The only status-mutating consumer is
  Phase 6's demotion branch; reverting that one commit returns `reconcile-task-status.sh` to its
  current refuse-on-exit-1 behaviour while leaving the advisory field and the probe in place for
  observation. The postflight field and the Move 3 routing are advisory and bounded to one
  re-prompt per `dispatch_seq`, so they cannot wedge a task even if the signal is noisy.
- **Check K proves too broad.** Reverting Phase 7's lint commit alone restores a green
  agent-contracts lint; the anchor block in `bounded-build-waiter.md` is inert prose and may stay.

Should a rollback need to discard uncommitted work rather than revert a commit, follow
`context/contracts/recovery.md`'s rollback rung for the sanctioned snapshot-then-rollback
invocation, including its out-of-scope override flag — not a bare precautionary snapshot.
