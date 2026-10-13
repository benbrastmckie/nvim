# Implementation Plan: Task #392

- **Task**: 392 - Deliver the tool-`timeout` half of the bounded-wait idiom to the redeploy
  remedy sites and to Rule 1's presentation
- **Status**: [NOT STARTED]
- **Effort**: 7 hours
- **Dependencies**: task #354 (completed; owns `general-implementation-agent.md`'s
  "Dispatched-Subagent Wait Discipline" subsection and the ruling records in
  `bounded-build-waiter.md` / `external-process-wait.md`), task #318 (completed; added
  `verify-deploy.sh` gate 23)
- **Research Inputs**: `specs/392_deliver_tool_timeout_half_of_bounded_wait_idiom/reports/01_tool-timeout-remedy-delivery.md`
- **Artifacts**: plans/01_tool-timeout-remedy-delivery.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close the delivery gap between `external-process-wait.md` Rule 1's bounded-wait idiom and the
sites that need it, in both directions the task authorizes. **Half B** restructures Rule 1 so
the Bash-tool `timeout`-parameter obligation reads as a numbered requirement rather than an
unmarked sentence adjacent to a rationale heading, and states the obligation in caller-agnostic
terms so it reaches the orchestrator's own foreground calls, not only a dispatched subagent's.
**Half A** appends one short, fixed, canonical fragment — the `600000` number plus a path
cross-reference — to every runtime redeploy-remedy emission site, with the fragment held in a
single per-script variable so a script's N sites have one edit point. Three recorded rulings
answer the task's ALSO RULE ON questions, and a fourth names the harness-initiated-backgrounding
shape and its two distinct remedies.

### Research Integration

The research report is the authoritative input and this plan builds on it directly. Carried from
it and independently re-derived at plan-authoring time (see **Scope Hypothesis** lines per
phase):

- **Finding 3 confirmed, and tightened.** Both named test suites assert only the loose literal
  substring `deploy-headless.sh` (`test-orchestrate-build-dispatch.sh:668`
  `assert_contains "$content" "deploy-headless.sh"`; `test-deploy-freshness.sh:151`
  `[[ "$OUT_STALE" == *"deploy-headless.sh"* ]]`), so any append that preserves that substring
  passes both. **One additional constraint the report did not surface**:
  `test-deploy-freshness.sh:149` also asserts `WARN_COUNT_STALE -eq 1`, where
  `WARN_COUNT_STALE=$(grep -c '^WARN:' ...)`. An appended fragment MUST NOT begin a physical
  line with `WARN:`. Re-verified at plan-authoring time by reading both files.
- **Finding 2 confirmed.** `test-deploy-freshness.sh`'s `run_checker()` invokes
  `check-deploy-freshness.sh`, not `verify-deploy.sh`. Its fixture copies exactly two files into
  `$WORKDIR/bin` (the checker and `lib/deploy-freshness-lib.sh`) — see Decision 1 for why this
  kills the report's shared-helper recommendation at the most agent-visible site.
- **Finding 4 confirmed.** Rule 1's `timeout`-parameter sentence sits at
  `context/patterns/external-process-wait.md:48`, *before* the "Why 540 < 600" heading at `:51`,
  already in imperative mood. The defect is structural placement, so the fix is an explicit
  numbered sub-step, not a reword (Decision 3).
- **Finding 5 confirmed.** All three wait-discipline subsections already exist in
  `general-implementation-agent.md` (External Process Wait Discipline, Local Long-Running
  Command Discipline, Dispatched-Subagent Wait Discipline), and none of their MUST bullets
  states the tool-parameter obligation.
- **Finding 7 confirmed.** `bounded-build-waiter.md`'s "Copy this exact text" generated-copy
  block is at `:174-190`; its two bullets are literal-copied into every carrying implementation
  agent and checked by `lint-agent-contracts.sh` Check H. This plan edits only ordinary prose in
  that file, never that block (Decision 5).
- **Finding 1 superseded by a wider re-derivation.** The report's 13-site count undercounts.
  See Decision 2 for the re-derived inventory and the in-scope predicate.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap phases are
included.

## Goals & Non-Goals

**Goals**:
- Half A: every runtime redeploy-remedy emission site carries the complete idiom's load-bearing
  number (`600000`) plus a path cross-reference, applied by one consistent rule.
- Half B: Rule 1 states the tool-`timeout` obligation as a numbered requirement, in
  caller-agnostic terms.
- A recorded ruling on each of the three ALSO RULE ON questions, declines included.
- The harness-initiated-backgrounding shape named, with its two sub-cases distinguished by
  remedy, stated where a future reader will find it and composing with task #354's mandate.
- Both named test suites green; redeployed; full gate set run with residual failures attributed.

**Non-Goals**:
- Widening postflight's `stall_suspected` trigger predicate (explicitly out of scope; a prior
  ruling declined it and nothing here bears on it).
- Changing the harness's own Bash-tool defaults.
- A shared cross-script remedy-string helper in `scripts/lib/common.sh` (rejected — Decision 1).
- Editing `bounded-build-waiter.md`'s "Copy this exact text" generated-copy block, or
  re-propagating the agent-contract bullet pair across the 14 carrying agent files.
- Adding the tool-timeout obligation to the three MUST-bullet summaries in
  `general-implementation-agent.md` beyond the one clarifying note Decision 6 authorizes (the
  report's Recommendation 6 defers this; reassess after Half B lands).
- A lint enforcing the canonical fragment's presence at every emission site (recorded as a
  follow-up in Phase 2's deliverable, not built here).
- Investigating `test-four-tier-conflict.sh` Case 6 (known pre-existing timing flake; attribute,
  do not investigate).

## Decisions

These are the plan's own rulings. Each is argued, per the task's acceptance criteria.

### Decision 1 — Reject the shared-helper approach; use a per-script canonical fragment variable

The research report's Recommendation 1 (one shared remedy-string helper in
`scripts/lib/common.sh`) is **rejected**, on a verified blocker rather than a preference.
`test-deploy-freshness.sh` builds its fixture by copying exactly two files into `$WORKDIR/bin`:
`check-deploy-freshness.sh` and `lib/deploy-freshness-lib.sh`. Making
`check-deploy-freshness.sh` source `lib/common.sh` breaks that fixture — at the single most
agent-visible emission site in the inventory, since the checker fires non-blocking on every
command via CHECKPOINT 1. Re-derived at plan-authoring time: of the nine scripts carrying the
highest-traffic sites, five do not source `common.sh` at all (`git-snapshot.sh`,
`verify-deploy.sh`, `check-deploy-freshness.sh`, `check-extension-docs.sh`,
`orchestrate-build-dispatch.sh`), so the shared helper would require five new sourcing
dependencies plus a fixture edit, to save roughly twenty one-line appends.

**Adopted instead**: one short canonical fragment, byte-identical everywhere, held in a
**per-script shell variable** in each script that has more than one site. This gives each script
exactly one edit point (`verify-deploy.sh`: 1 variable / 4 sites; `check-extension-docs.sh`:
1 / 6; `check-deploy-freshness.sh`: 1 / 2) without any new cross-script dependency, and the
fragment's authoritative text is recorded once in `regeneration-is-manual-only.md` (Phase 2) so
a future site copies rather than re-invents it. The drift the report warns about
(`skill-base.sh:460` already being a near-duplicate of `orchestrate-build-dispatch.sh:393`) is
addressed by that single recorded source plus the deferred lint, not by runtime coupling.

### Decision 2 — Half A delivery form: hybrid (short inline clause + path), and the in-scope predicate

The report's Decision 1 (hybrid, not a pure choice) is **adopted**. A bare path reference
reproduces the exact gap this task exists to close — both measured incidents show an agent under
schedule pressure not making the extra read hop — while a full prose restatement at twenty-odd
terse stderr lines is the drift anti-pattern. The inline clause carries the one number that
actually matters; the path carries the "why" and the worked example.

**Canonical fragment** (final wording settled in Phase 2; this is the shape, ~130 chars, no
line-initial `WARN:`):

```
Long call -- set this Bash call's timeout parameter to 600000 and wrap in 'timeout 540'; see context/patterns/external-process-wait.md Rule 1.
```

**In-scope predicate, stated so the application is consistent and auditable**: a site is in
scope if and only if it emits, **at runtime**, text directing its reader to RUN
`deploy-headless.sh` (stderr, stdout, or composed dispatch-prompt text). Deliberately excluded,
each for a stated reason rather than an oversight:

- **Header comment blocks** (`orchestrate-record-decision.sh`, `orchestrate-conclusion-aggregate.sh`,
  `dispatch-metrics.sh`, `issue-record.sh`, `system-defect-record.sh`, `measure-eager-context.sh`,
  `check-extension-docs.sh`'s narrative, `orchestrate-cycle-plan.sh`'s and
  `lib/redeploy-checkpoint-lib.sh`'s headers, `deploy-headless.sh`'s own usage block). These are
  read by a human or agent already editing the script, not acted on under schedule pressure, and
  appending to each would roughly triple their length for no measured benefit. `deploy-headless.sh`'s
  header gets the runtime note from Decision 4 instead, which is the targeted version of the same
  idea.
- **`check-extension-docs.sh`'s Rule R remedies** (two sites naming
  `generate-context-line-counts.sh --write`): the remedy is not a deploy.
- **`command-gate-out.sh`'s three deploy diagnostics**: these report on a deploy that already
  ran; they do not instruct a reader to run one.

### Decision 3 — Half B: restructure Rule 1 into numbered requirements, not a reword

The report's Decision 2 is **adopted**. Rule 1 becomes an explicit numbered list whose step 1 is
the inner-bounded foreground command and whose step 2 is the tool-`timeout`-parameter raise,
with "Why 540 < 600" retained and scoped strictly to explaining the 60-second margin. This
matches the acceptance criterion's wording ("a numbered requirement, not ... rationale under a
'why this constant' heading") without overstating what was already true: the sentence was
already imperative and already sat before that heading (Finding 4) — what it lacked was any
structural marker that a second required step existed at all.

**Caller-agnostic framing is added at the same time**, because it is the one change that makes
Rule 1 reach the orchestrator. Rule 1's current wording is embedded in a document whose
**Audience** line reads "Any dispatched subagent"; the numbered requirement is restated to bind
**any caller issuing a long foreground Bash call**, dispatched subagent or orchestrator session
alike. This is a scope widening of one sentence's audience, not of the document's.

### Decision 4 — ALSO RULE ON #1 (deploy-local runtime note): yes, add one

`deploy-headless.sh`'s header already documents its modes and exit codes inline, so a parallel
bullet stating its expected runtime class and the required tool `timeout` at the point of use
fits the file's existing conventions. Biased toward the path side of Decision 2's hybrid (it is
prose read by someone already inspecting the script, not a terse stderr line). **The figure
must be measured in Phase 2, not carried**: the orchestrator's same-session ~3-4 minute
measurement is cited as evidence for why the note is warranted, never written into the note.

### Decision 5 — ALSO RULE ON #2 (`bounded-build-waiter.md` needs the same pairing): yes, as ordinary prose

The report's Decision 4 is **adopted**, with its placement constraint. Finding 6's gap is real
and sits in the exact subsection an agent reads immediately before choosing the foreground form:
"The Canonical Idiom" says "Prefer the simpler foreground form ... whenever the command fits
within the calling tool's own timeout limit" — which presupposes the limit is adjustable and
never says to adjust it. A local deploy is structurally far closer to this file's
local-detached-build case than to `external-process-wait.md`'s remote `gh run watch` case, so
leaving the pairing only in the remote document is the delivery gap one file over.

Placement: ordinary prose in "The Canonical Idiom" and "Sizing a Wait Near the Per-Call
Ceiling", **never** inside "Copy this exact text" (`:174-190`). Finding 7's cost of getting this
wrong (a 14-file literal-copy re-propagation plus `lint-agent-contracts.sh` Check H re-check) is
avoidable and buys nothing this task needs: the bullet pair's content — whether backgrounding is
permitted at all — is orthogonal to what value the tool `timeout` parameter carries.

### Decision 6 — ALSO RULE ON #3 (`general-implementation-agent.md` naming the third case): yes, as a clarifying note inside the existing Local section

The report's Decision 5 is **adopted**. Finding 5 confirms the three-way structure already
exists and already covers local scripts like `deploy-headless.sh` by command category. What is
missing is one clarifying note that "backgrounded at all" includes the **harness's own**
auto-backgrounding of an ordinary foreground call whose tool `timeout` parameter was left at the
120000ms default — not only a deliberate `&`/`nohup`. That framing is load-bearing: the existing
Local Long-Running Command Discipline presumes the agent controls whether backgrounding happens,
and it does not.

**Composition with task #354, stated explicitly**: #354's ruling lives in the separate
Dispatched-Subagent Wait Discipline subsection and governs a nested `Agent`-tool dispatch. This
note touches only the Local Long-Running Command Discipline subsection and adds no restriction
on subagent dispatch. The two rulings are about different trigger surfaces and neither weakens
the other: #354 forbids an async subagent dispatch awaited across a turn boundary; this note
says an *ordinary foreground* call can be backgrounded without the agent choosing it, and names
the parameter that prevents it. A fourth top-level subsection is **declined** — the case is a
precondition on all three existing disciplines, not a fourth kind of wait.

### Decision 7 — The orchestrator's own foreground call: yes, the deliverable must say so, at `skill-orchestrate/SKILL.md`'s invocation site

This is the scope point the dispatching orchestrator asked to be reflected, and it needs saying
because **shape 3's two sub-cases have different remedies, and 3a's remedy is actively
misleading for 3b**:

- **3a — the call fits under the ceiling, but the parameter was left at the 120000ms default.**
  Remedy: raise the Bash tool `timeout` parameter to `600000` and keep an inner `timeout` below
  it. This is the measured `deploy-headless.sh` case (3-4 min: past 120s, comfortably inside
  540s). Half A and Half B both target this sub-case.
- **3b — the call cannot fit under the 600s ceiling at all.** Raising the parameter to its
  ceiling does not help, because the ceiling itself is the bound. Remedy: redirect stdout and
  stderr to a log, launch with a captured PID, and resolve with a *sequence* of bounded
  foreground `kill -0` waits — `bounded-build-waiter.md`'s "Sizing a Wait Near the Per-Call
  Ceiling", which already describes exactly this and is the right cross-reference.

The orchestrator's own auto-backgrounded `orchestrate-cycle-plan.sh` call is sub-case 3b, and
verified so at plan-authoring time: the Inter-Cycle Redeploy Checkpoint inside that one script
call runs a pre `verify-deploy.sh --skip-slow` findings snapshot, then
`deploy-headless.sh --skip-verify`, then a post `verify-deploy.sh --skip-slow` snapshot (and, on
a new finding, a confirm snapshot). That composite is structurally larger than one 600s call.

**Placement ruling, with two candidates evaluated and declined**:

- **`context/contracts/orchestrator-discipline.md` — declined.** It is the audience-correct file
  on its face (its opening sentence binds the orchestrator role itself), and
  `external-process-wait.md`'s own "Contract home for this prohibition" note already cites that
  audience distinction. But its "Domain Specialization / Scope" section scopes it **`--hard`-only**,
  and the observed stranding happened in a standard-mode `/orchestrate` run. Placing
  standard-mode guidance there would make it unreachable in exactly the mode that produced the
  evidence.
- **`docs/architecture/orchestrate-state-machine.md` — declined as the primary home, adopted as
  a cross-reference.** Its "Diagnosing Dispatch Liveness: A Probe for External Watchers" section
  (task #354's addition) is about an external watcher diagnosing a dispatch that has gone quiet
  — complementary, but it tells the orchestrator nothing at the moment it issues the call.
- **Adopted: `skills/skill-orchestrate/SKILL.md`, at the `orchestrate-cycle-plan.sh` invocation
  block.** This is the point of use, in the one file the orchestrator actually reads, and it is
  today documented with no timeout guidance at all. A second, sharper reason it must change
  there: the documented shape is `plan_json=$(bash .claude/scripts/orchestrate-cycle-plan.sh ...)`,
  a command substitution into a shell variable. If the harness backgrounds that call, the
  captured stdout is lost outright — there is no log to poll and no way back to the JSON. The
  note therefore must change the documented shape to redirect to a log file and read the JSON
  back from it, not merely annotate the existing one.

### Decision 8 — The `exit=124` fallback: a generic step in Rule 1, the `--skip-slow` specialization declined

The sibling plan's `exit=124` fallback (re-run once with `--skip-slow` and record the baseline as
such) is **split, not adopted wholesale**:

- **Adopted into Rule 1** as a short step: exit `124` means the *inner bound fired*, not that the
  command's subject failed — the command was killed mid-run, so re-check state rather than
  reading 124 as a failure. This is caller-agnostic and genuinely belongs with the idiom that
  produces the 124.
- **Declined for Rule 1**: the specific "re-run once with `--skip-slow` and record the baseline
  as `--skip-slow`-depth" fallback. It is a property of `verify-deploy.sh`'s gate-depth and
  baseline-comparison semantics, not of the bounded-wait idiom, and Rule 1 is consumed by callers
  waiting on things that have no `--skip-slow` equivalent. It is recorded in the
  `deploy-headless.sh` / `regeneration-is-manual-only.md` runtime note instead (Phase 2), where
  the gate it concerns is already the subject.

### Decision 9 — The three-shapes taxonomy's home: `bounded-build-waiter.md`

`bounded-build-waiter.md` already hosts the shape-taxonomy ruling record — its
"Dispatched-Subagent Wait Ruling: A Third Case, Resolved in `general-implementation-agent.md`,
Not Here" section is where task #354's ruling was recorded. Extending that same file with the
harness-initiated shape keeps the taxonomy in one place and reads as composing with #354 rather
than competing with it, by following the precedent #354 itself set. `external-process-wait.md`
Rule 1 and `general-implementation-agent.md`'s Local section cross-reference it by path.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `index-entries.json` `line_count` drift fails `check-extension-docs.sh` Rule R | M | H | Verified: `external-process-wait.md` is pinned at `line_count: 161` and `bounded-build-waiter.md` at `318`, both matching current `wc -l`. Every markdown-editing phase ends by running `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`. `deploy-headless.sh` also runs it automatically pre-deploy, but a `verify-deploy.sh` run *before* redeploy would fail without it. |
| `test-deploy-freshness.sh`'s `WARN_COUNT_STALE -eq 1` assertion breaks | H | L | The canonical fragment must not begin a physical line with `WARN:`. `check-deploy-freshness.sh`'s remedy lines start with two spaces; preserve that. Asserted explicitly in Phase 4's verification. |
| Appending to a `verify-deploy.sh` `fail` call changes FINDING text and perturbs the redeploy checkpoint's pre/post baseline comparison | M | M | Verified: `fail()` builds `FINDING $CURRENT_GATE $1` from its **first** argument only; the remediation `$2` never reaches a FINDING line. So `:310` (fragment appended to `$2`) is safe as-is, and `:647`/`:681` — where the hint currently sits inside `$1` — must take the fragment as a **new second argument**, leaving `$1` byte-identical. |
| Scope read as creep (inventory wider than the description's three sites) | M | M | The task's GOAL and ACCEPTANCE both use universal phrasing ("every redeploy remedy string" / "every ... emission site"); the three-site list appears only under an illustrative "WHY AGENTS MISS HALF (ii)" heading. Decision 2 states the in-scope predicate and its exclusions explicitly so the boundary is auditable rather than assumed. |
| `file_scope` harvest misses edits (a sibling task lost four edits to extension-relative paths) | H | M | Every `Files to modify` entry in this plan is **repo-relative** (`agent-system/extensions/core/...`) so `plan-file-scope-harvest.sh` widens `file_scope` correctly. |
| Completion-deploy gate refuses completion while deployed `core` is stale | L | H | Expected; the next cycle's redeploy checkpoint resolves it. Do not plan or build a workaround. |
| A long gate/deploy call strands the implementer — the very defect this task fixes | H | M | Every phase step invoking a long command carries the bounded-wait idiom inline (Idiom A or Idiom B below). Non-negotiable. |
| `test-four-tier-conflict.sh` Case 6 timing flake under concurrent load | L | M | Known pre-existing; `[1000ms,2000ms)` assertion measuring ~2.3-2.8s. **Attribute, do not investigate.** |
| `check-record-versioning.sh` emits "ignored null byte in input" warnings scanning binary files | L | H | Cosmetic stderr noise in freshly-shipped sibling code, verified to drop no findings. Not this task's to fix; ignore if seen. |

## Bounded-Wait Idiom — Inline, Verbatim, for Every Long-Command Step

Written out here in full because it would be absurd for the plan that fixes this defect to
strand its own implementer. Every phase step below that invokes a long command names **Idiom A**
or **Idiom B** and means exactly this.

Set `LOGDIR` once per dispatch (scratchpad, not the project tree):

```bash
LOGDIR=/tmp/claude-1000/-home-benjamin--config-nvim/t392-logs; mkdir -p "$LOGDIR"
```

**Idiom A — the command plausibly fits under 540s.** Use for `deploy-headless.sh`,
`verify-deploy.sh --skip-slow`, `run-all.sh --only <subset>`, and any single test suite.
**Issue the Bash tool call with its `timeout` parameter set to `600000` — NOT the 120000ms
default. This is the load-bearing half.**

```bash
timeout 540 bash <COMMAND> >"$LOGDIR/<name>.log" 2>&1; rc=$?
echo "EXIT=$rc"; tail -40 "$LOGDIR/<name>.log"
```

`rc=124` means the inner bound fired and the command was killed mid-run — re-check state; do not
read 124 as a failure of the command's subject. For a `verify-deploy.sh` full-gate run
specifically, the sanctioned fallback is one re-run at `--skip-slow` depth with the baseline
recorded as `--skip-slow`-depth (never silently compared against a full-depth baseline).

**Idiom B — the command may exceed 540s.** Use for `verify-deploy.sh`'s **full** gate set (gate
8 nests `run-all.sh`, so a full battery pays both) and for any deploy+verify composite. Tool
`timeout` parameter `600000`, launch and wait inside **one** call:

```bash
LOG="$LOGDIR/<name>.log"
nohup bash <COMMAND> >"$LOG" 2>&1 & echo $! > "$LOG.pid"
pid=$(cat "$LOG.pid")
timeout 540 bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 10; done' _ "$pid"
if kill -0 "$pid" 2>/dev/null; then echo "STILL RUNNING pid=$pid"; else echo "WRITER DEAD"; fi
tail -60 "$LOG"
```

If `STILL RUNNING` at the deadline, issue **another** identical bounded call (tool `timeout`
`600000`), re-reading `pid` from `$LOG.pid`. Once `WRITER DEAD`, read the log **once**.

**MUST NOT**, in any phase: use `Bash(run_in_background: true)`, arm a `Monitor`, end the turn on
an unresolved wait, issue no-op filler calls, or poll `$LOG` for a sentinel with no `kill -0`
liveness check behind it.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 4 |
| 5 | 6 | 3, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Half B — Restructure Rule 1 into Numbered Requirements [NOT STARTED]

**Goal**: `external-process-wait.md` Rule 1 states the tool-`timeout` obligation as a numbered
requirement in caller-agnostic terms, with "Why 540 < 600" retained and scoped strictly to the
margin, plus the generic `exit 124` step.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/patterns/external-process-wait.md` in full
      immediately before editing. Anchor on TEXT, never on the line numbers cited in this plan.
- [ ] Rewrite the `### 1. Bounded blocking wait` body as an explicit numbered list:
      **(1)** issue an inner-bounded, foreground, blocking command (keep the existing
      `timeout 540 gh run watch ...` code block as the worked example);
      **(2)** issue it with the Bash tool's own `timeout` parameter set to `600000` — stated as a
      required step, with the 120000ms default named explicitly as what it must be raised FROM,
      because leaving it at the default makes step (1)'s inner bound inert;
      **(3)** on exit `124`, the inner bound fired and the command was killed mid-run — re-check
      state rather than reading 124 as a failure of the command's subject (Decision 8);
      **(4)** repeat the pair only while the reported `status` is `in_progress` or `queued`.
- [ ] Make step (2) **caller-agnostic** (Decision 3): bind it to any caller issuing a long
      foreground Bash call — a dispatched subagent OR an orchestrator session — not only to this
      document's stated "Any dispatched subagent" audience.
- [ ] Add, as a short note under the numbered list, the two sub-cases from Decision 7: raising the
      parameter resolves a call that fits under the ceiling (3a); a call that cannot fit the 600s
      ceiling at all is NOT resolved by the parameter and takes
      `bounded-build-waiter.md`'s "Sizing a Wait Near the Per-Call Ceiling" instead (3b).
      Cross-reference that section by path.
- [ ] Keep the `**Why 540 < 600**` heading and paragraph, scoped strictly to explaining the
      60-second margin. Do not delete it and do not let it carry the obligation.
- [ ] Add a forward pointer to `bounded-build-waiter.md`'s shape taxonomy (Phase 2 creates the
      target section; this pointer is by section title and path, with no line number).
- [ ] No task-number references anywhere in the edited file
      (`rules/no-task-references-in-deliverables.md`).
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` to
      resync `index-entries.json`'s `line_count` for this file.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: markdown-only edit with no compile or elaboration surface, so
`suite_selection_select` returns `__FULL_SWEEP__` for it (sub-case (b), source-store non-`specs/**`
markdown); the covering check is `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` with the explicit source-store TARGET, alongside the `prose` row's diff read-through.

**Scope Hypothesis**: this plan asserts Rule 1's `timeout`-parameter sentence currently sits at
`external-process-wait.md:48` and the "Why 540 < 600" heading at `:51`, and that the file is 161
lines (matching `index-entries.json`'s pinned `line_count: 161`) — all re-derived at plan-authoring
time from the research report's Finding 4. Confirm by re-reading the file and running `wc -l`
immediately before editing; anchor the edit on text, not on these figures.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/external-process-wait.md` - Rule 1 restructured into numbered requirements (1)-(4); caller-agnostic step (2); exit-124 step (3); 3a/3b sub-case note; forward pointer to the shape taxonomy
- `agent-system/extensions/core/index-entries.json` - `line_count` resynced by `generate-context-line-counts.sh --write`

**Verification**:
- Diff read-through confirming every changed hunk lies in prose/markdown.
- `grep -n "600000" agent-system/extensions/core/context/patterns/external-process-wait.md`
  shows the value inside a numbered step, not only inside the "Why 540 < 600" paragraph.
- `grep -n "120000" ...` shows the default named explicitly.
- `wc -l` on the file equals the `line_count` now recorded in `index-entries.json`.
- Idiom A: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  — clean, or every finding attributed as pre-existing.

---

### Phase 2: Shape Taxonomy, `bounded-build-waiter.md` Pairing, Deploy-Local Runtime Note, Canonical Fragment Record [NOT STARTED]

**Goal**: ALSO RULE ON #1 and #2 discharged; the three-shapes taxonomy recorded in its chosen
home; the canonical remedy fragment's authoritative text and emission-site inventory recorded
once; `deploy-headless.sh`'s runtime measured, not carried.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` in full.
      **Locate the exact line range of the `### Copy this exact text` block before editing
      anything near it** — nothing in this phase may touch that block (Decision 5, Finding 7).
- [ ] **Measure, do not carry** (Idiom A, tool `timeout` `600000`):
      time one `bash .claude/scripts/deploy-headless.sh --skip-verify` run and one
      `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow /home/benjamin/.config/nvim`
      run, recording wall-clock for each. Use the measured figures, with their measurement
      conditions, in every runtime statement this phase writes. The dispatching orchestrator's
      ~3-4 min / 6-10 min same-session figures are evidence that the note is warranted, and MUST
      NOT be written into any deliverable.
- [ ] `bounded-build-waiter.md`, **ordinary prose only**: in "The Canonical Idiom", state that
      the "calling tool's own timeout limit" referenced by the existing foreground-form
      preference is itself a parameter the caller sets, and that preferring the foreground form
      requires raising it to `600000` (from its 120000ms default) — cross-referencing
      `external-process-wait.md` Rule 1 by path. Mirror the same pairing in "Sizing a Wait Near
      the Per-Call Ceiling" for the plain-foreground case that subsection currently does not
      cover.
- [ ] `bounded-build-waiter.md`: add a new section recording the **shape taxonomy** (Decision 9),
      adjacent to and composing with the existing "Dispatched-Subagent Wait Ruling: A Third Case"
      section. Name all three shapes — agent-chosen local-gate backgrounding; awaiting a
      dispatched subagent; harness-initiated backgrounding of an ordinary foreground call — and
      state that the third is distinguished by **trigger, not command category**: the agent chose
      nothing. Record sub-cases 3a and 3b with their different remedies (Decision 7), and state
      explicitly that this composes with the dispatched-subagent ruling (different trigger
      surface, neither weakens the other) rather than superseding it.
- [ ] `deploy-headless.sh` header: add a bullet, parallel to the existing mode and exit-code
      bullets, stating the **measured** expected runtime class and the required Bash-tool
      `timeout` parameter at the point of use, pointing to `external-process-wait.md` Rule 1 by
      path (Decision 4). Also record the `verify-deploy.sh`-specific exit-124 fallback here
      (one `--skip-slow` re-run with the baseline recorded as `--skip-slow` depth), per
      Decision 8's declined-for-Rule-1 half.
- [ ] `regeneration-is-manual-only.md`: add a `### Canonical Redeploy-Remedy Fragment` subsection
      under "Detecting When You're Stale" recording (a) the fragment's authoritative text
      verbatim, (b) the in-scope predicate and exclusions from Decision 2, (c) the emission-site
      inventory by script and site count, and (d) the deferred follow-up — a lint asserting the
      fragment's presence at every in-scope site — as a named future item, not built here.
- [ ] No task-number references in any edited file.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: all four edits are markdown prose or a shell header comment block with no
executable surface, so `suite_selection_select` returns `__FULL_SWEEP__` (sub-case (b)); the
covering check is `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
plus the `prose` row's diff read-through confirming the `deploy-headless.sh` hunk stays inside its
leading `#` comment block.

**Scope Hypothesis**: this plan asserts `bounded-build-waiter.md`'s generated-copy block spans
`:174-190` and the file is 318 lines (matching the pinned `line_count: 318`), and that
`regeneration-is-manual-only.md` is 722 lines with a `## Detecting When You're Stale` section —
all re-derived at plan-authoring time. Confirm by `grep -n "Copy this exact text"` and `wc -l`
immediately before editing; anchor on text.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` - tool-`timeout` pairing stated in "The Canonical Idiom" and "Sizing a Wait Near the Per-Call Ceiling"; new shape-taxonomy section naming the harness-initiated case and its 3a/3b sub-cases
- `agent-system/extensions/core/scripts/deploy-headless.sh` - header comment bullet: measured runtime class, required tool `timeout`, Rule 1 path, verify-deploy exit-124 fallback
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - new `### Canonical Redeploy-Remedy Fragment` subsection: fragment text, in-scope predicate, emission-site inventory, deferred lint
- `agent-system/extensions/core/index-entries.json` - `line_count` resynced

**Verification**:
- `git diff -- agent-system/extensions/core/context/patterns/bounded-build-waiter.md` confirms
  **zero** changed lines inside the `### Copy this exact text` block.
- Idiom A: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh`
  — green (Check H unaffected, proving the generated-copy block is untouched).
- `grep -n "600000" agent-system/extensions/core/context/patterns/bounded-build-waiter.md` and
  `... scripts/deploy-headless.sh` both hit.
- The runtime note's figure matches this phase's own measurement, with conditions stated.
- `wc -l` on each edited markdown file equals its new `index-entries.json` `line_count`.
- Idiom A: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

---

### Phase 3: Agent-Contract and Orchestrator-Caller Delivery [NOT STARTED]

**Goal**: ALSO RULE ON #3 discharged inside the existing Local Long-Running Command Discipline
subsection, composing with the dispatched-subagent mandate; and the orchestrator's own
foreground call addressed at its point of use.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/agents/general-implementation-agent.md`'s three
      wait-discipline subsections in full, including the Dispatched-Subagent Wait Discipline
      subsection, before editing. **Do not modify that subsection.**
- [ ] Add a clarifying note to **Local Long-Running Command Discipline** (Decision 6): "backgrounded
      at all" includes the harness's own auto-backgrounding of an ordinary foreground call whose
      Bash-tool `timeout` parameter was left at its 120000ms default — not only a deliberate
      `&`/`nohup`. State the remedy (raise to `600000`, keep an inner `timeout` below it) and
      cross-reference `external-process-wait.md` Rule 1 and the shape taxonomy by path. Decline
      a fourth top-level subsection explicitly in the note's own wording: this is a precondition
      on all three disciplines, not a fourth kind of wait.
- [ ] Verify by reading that the note introduces no restriction on nested `Agent`-tool dispatch
      and does not reword any bullet in the Dispatched-Subagent Wait Discipline subsection.
- [ ] Re-read `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`'s
      `orchestrate-cycle-plan.sh` invocation block in full.
- [ ] Add, immediately adjacent to that invocation block (Decision 7): a note that this one call
      performs the whole of Move 1 **including the Inter-Cycle Redeploy Checkpoint**
      (pre-verify snapshot + `deploy-headless.sh --skip-verify` + post-verify snapshot), that it
      is therefore a sub-case-3b call which can exceed the 600s ceiling even with the tool
      `timeout` parameter at `600000`, and that the documented `plan_json=$(...)` command
      substitution loses its captured stdout outright if the harness backgrounds it. Change the
      documented shape to redirect stdout to a log file under the session's own runtime directory
      and read the JSON back from that log, so a backgrounded call stays recoverable. Name the
      tool `timeout` parameter `600000` requirement explicitly and cross-reference
      `bounded-build-waiter.md`'s "Sizing a Wait Near the Per-Call Ceiling" by path.
- [ ] Add a one-line cross-reference from
      `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`'s
      "Diagnosing Dispatch Liveness: A Probe for External Watchers" section to the shape taxonomy,
      so an external watcher diagnosing a quiet dispatch can reach the harness-initiated case.
      **Do not** touch that section's `stall_suspected`-predicate paragraphs — the predicate is
      explicitly out of scope and that section already records its own reasoned decline.
- [ ] No task-number references in any edited file.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`.

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Verification Tier**: prose

**Tier Justification**: three markdown edits with no executable surface (`suite_selection_select`
returns `__FULL_SWEEP__`, sub-case (b)); covered by
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
plus `run-all.sh --only test-lint-agent-contracts.sh` for the agent-file edit, alongside the
`prose` row's diff read-through.

**Scope Hypothesis**: this plan asserts `general-implementation-agent.md` carries exactly three
headed wait-discipline subsections and that `skill-orchestrate/SKILL.md` (344 lines) documents the
`orchestrate-cycle-plan.sh` call as `plan_json=$(bash ...)` with no timeout guidance — both
re-derived at plan-authoring time. Confirm by
`grep -n "Wait Discipline\|Long-Running Command Discipline" agent-system/extensions/core/agents/general-implementation-agent.md`
and by re-reading the SKILL.md invocation block before editing.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - clarifying note in Local Long-Running Command Discipline naming harness-initiated backgrounding; Dispatched-Subagent Wait Discipline untouched
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - sub-case-3b note at the `orchestrate-cycle-plan.sh` invocation; documented shape changed to log-redirect-and-read-back
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - one-line cross-reference from the dispatch-liveness probe section to the shape taxonomy
- `agent-system/extensions/core/index-entries.json` - `line_count` resynced

**Verification**:
- `git diff` on `general-implementation-agent.md` shows no changed line inside the
  Dispatched-Subagent Wait Discipline subsection.
- `git diff` on `orchestrate-state-machine.md` shows no changed line in the
  `stall_suspected`-predicate paragraphs.
- Idiom A: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh`
  — green.
- Idiom A: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.
- `wc -l` on each edited markdown file equals its new `index-entries.json` `line_count`.

---

### Phase 4: Half A — Canonical Fragment at the High-Traffic Emission Sites [NOT STARTED]

**Goal**: the five scripts carrying the sites an agent is most likely to act on all emit the
canonical fragment, with each script holding it in exactly one variable, and both named test
suites verified green.

**Tasks**:
- [ ] Settle the canonical fragment's final wording against the text recorded in Phase 2, and
      confirm it (a) contains the literal `deploy-headless.sh` substring where the emitting line
      already did, (b) begins no physical line with `WARN:`, (c) names `600000`, (d) names
      `context/patterns/external-process-wait.md` by path.
- [ ] **Re-read each target file and re-locate each site by TEXT immediately before editing.** The
      line numbers below are plan-authoring-time observations, not anchors.
- [ ] `orchestrate-build-dispatch.sh` — the `Remedy: redeploy via '...deploy-headless.sh'...`
      string in `deploy_freshness_context` (observed `:393`). Append the fragment. This is the
      highest-value site: the string is composed into a dispatch file an agent reads as prompt
      context.
- [ ] `skill-base.sh` — the `WARN: [skill-base] verify against the source store ...` stderr line
      (observed `:460`). Append the fragment.
- [ ] `check-deploy-freshness.sh` — introduce ONE fragment variable and use it at both
      `  Remedy: bash .claude/scripts/deploy-headless.sh ...` lines (observed `:95`, `:126`).
      **Preserve the two-space line prefix** and add no new `^WARN:` line.
      **MUST NOT** add a `lib/common.sh` dependency: `test-deploy-freshness.sh`'s fixture copies
      only this script and `lib/deploy-freshness-lib.sh` (Decision 1).
- [ ] `verify-deploy.sh` — introduce ONE fragment variable and use it at all four sites:
      `Run: bash deploy-headless.sh $TARGET` (observed `:190`); the
      `fail "$rel is missing" "run deploy-headless.sh to regenerate"` remediation (observed
      `:310`, append to the **second** argument); and the two
      `fail "... (run deploy-headless.sh first)"` calls (observed `:647`, `:681`) — for these
      two, pass the fragment as a **new second argument** and leave the first argument
      byte-identical, because `fail()` builds `FINDING $CURRENT_GATE $1` from the first argument
      only and the redeploy checkpoint compares FINDING text across its pre/post snapshots.
- [ ] No task-number references in any edited file.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: five independent one-line-append edits with no changed signature or
cross-script dependency, each covered by its own suite —
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-deploy-freshness.sh,test-verify-deploy-gate-selection.sh,test-verify-deploy-context-budget.sh,test-skill-base-lifecycle.sh`.

**Scope Hypothesis**: this plan asserts five scripts carry eight high-traffic sites at the
observed lines above, and that `fail()` in `verify-deploy.sh` derives its FINDING line from `$1`
only (observed `:242-253`) — all re-derived at plan-authoring time. Confirm each site by
`grep -n "deploy-headless.sh" <file>` and re-read `fail()` before editing; treat every line
number here as stale until re-confirmed.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - fragment appended to the `deploy_freshness_context` redeploy remedy
- `agent-system/extensions/core/scripts/skill-base.sh` - fragment appended to the stale-extension WARN remedy
- `agent-system/extensions/core/scripts/check-deploy-freshness.sh` - one fragment variable used at both WARN remedy lines; two-space prefix and single `^WARN:` line preserved
- `agent-system/extensions/core/scripts/verify-deploy.sh` - one fragment variable used at four sites; the two `fail` calls whose hint sits in `$1` take the fragment as a new `$2` so FINDING text stays byte-identical

**Verification**:
- Idiom A: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-deploy-freshness.sh,test-verify-deploy-gate-selection.sh,test-verify-deploy-context-budget.sh,test-skill-base-lifecycle.sh`
  — all green. Report the actual output; do not assume a substring-preserving edit kept them green.
- Explicitly confirm `test-deploy-freshness.sh`'s STALE case still counts **exactly one**
  `^WARN:` line and still finds the `deploy-headless.sh` substring (both assertions, named).
- Explicitly confirm `test-orchestrate-build-dispatch.sh`'s stale-fixture
  `assert_contains "$content" "deploy-headless.sh"` still passes.
- `git diff` confirms every `verify-deploy.sh` `fail` call's **first** argument is unchanged.
- `bash -n` on each edited script.
- `grep -c "600000"` on each edited script is non-zero.

---

### Phase 5: Half A — Remaining Emission Sites and Inventory Completion [NOT STARTED]

**Goal**: every remaining in-scope runtime emission site carries the same fragment, and the
inventory recorded in Phase 2 matches what is actually in the tree.

**Tasks**:
- [ ] **Re-derive the full inventory first**, rather than trusting this plan's list:
      `grep -rn "deploy-headless.sh" --include="*.sh" agent-system/extensions/core/scripts/ | grep -v "/tests/" | grep -iE "remedy|run: bash|regenerate|redeploy|re-run"`,
      then classify each hit against Decision 2's predicate. Reconcile against the Phase 2
      inventory and correct whichever is wrong.
- [ ] The four scripts carrying the identical
      `  Remedy: regenerate via the picker's [Reload All]/[Regenerate] entries, or bash .claude/scripts/deploy-headless.sh.`
      boilerplate — `git-snapshot.sh` (observed `:130`), `orchestrate-batch-admit.sh` (`:520`),
      `orchestrate-predispatch-review.sh` (`:182`), `task-lock.sh` (`:244`). Append the fragment
      to each, keeping the four lines identical to one another.
- [ ] `check-extension-docs.sh` — introduce ONE fragment variable and use it at the six
      `(regenerate via <leader>al 'Reload All', or bash .claude/scripts/deploy-headless.sh)`
      advisories (observed `:322`, `:337`, `:452`, `:459`, `:658`, `:713`). **Do not** touch the
      two Rule R remedies naming `generate-context-line-counts.sh` (observed `:801`, `:808`) —
      out of scope per Decision 2.
- [ ] `deploy-headless.sh` — the `[deploy-headless] Remedy: run '...' IN EACH stale repo` line
      (observed `:480`). Append the fragment.
- [ ] `migrate-state-legacy-fields.sh` (`:161`), `validate-state.sh` (`:382`),
      `check-consumer-freshness.sh` (`:185`), and `orchestrate-cycle-plan.sh`'s
      `REDEPLOY CHECKPOINT WARNING: ... redeploy manually, then re-run /orchestrate` line
      (`:977`). Append the fragment to each.
- [ ] Update the Phase 2 inventory in `regeneration-is-manual-only.md` to the re-derived truth if
      it differs, and record any site classified out of scope that this plan did not already name.
- [ ] No task-number references in any edited file.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` if
      `regeneration-is-manual-only.md` changed.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Tier Justification**: one-line string appends confined to each script's own emission lines with
no signature or dependency change, covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-snapshot.sh,test-orchestrate-batch-admit.sh,test-orchestrate-predispatch-review.sh,test-task-lock-liveness.sh,test-validate-state.sh,test-consumer-freshness.sh,test-orchestrate-cycle-plan.sh`.

**Scope Hypothesis**: this plan asserts nine further scripts carry fourteen in-scope sites at the
observed lines above, that the four `Remedy: regenerate via the picker's ...` lines are currently
byte-identical, and that `check-extension-docs.sh` has no dedicated test suite under
`scripts/tests/`. All re-derived at plan-authoring time; the first task of this phase re-derives
the inventory mechanically and corrects it rather than trusting these figures.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-snapshot.sh` - fragment appended to the stale-deploy remedy
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - fragment appended to the stale-deploy remedy
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - fragment appended to the stale-deploy remedy
- `agent-system/extensions/core/scripts/task-lock.sh` - fragment appended to the stale-deploy remedy
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - one fragment variable used at the six deploy advisories; the two Rule R remedies left untouched
- `agent-system/extensions/core/scripts/deploy-headless.sh` - fragment appended to the stale-consumer remedy line
- `agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh` - fragment appended to the deploy-first remedy
- `agent-system/extensions/core/scripts/validate-state.sh` - fragment appended to the deploy-first remedy
- `agent-system/extensions/core/scripts/check-consumer-freshness.sh` - fragment appended to the stale-consumer remedy
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - fragment appended to the redeploy-checkpoint failure remedy
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - inventory corrected to the re-derived truth
- `agent-system/extensions/core/index-entries.json` - `line_count` resynced if the markdown changed

**Verification**:
- `bash -n` on each edited script.
- Idiom A: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-snapshot.sh,test-orchestrate-batch-admit.sh,test-orchestrate-predispatch-review.sh,test-task-lock-liveness.sh,test-validate-state.sh,test-consumer-freshness.sh,test-orchestrate-cycle-plan.sh`
  — all green, or any failure attributed.
- Idiom A: `bash agent-system/extensions/core/scripts/check-extension-docs.sh` — no NEW advisory
  relative to a pre-edit baseline captured in this phase.
- The re-derived grep shows every in-scope site carrying `600000`, and every excluded site
  unchanged and named in the recorded inventory.

---

### Phase 6: Redeploy, Full Gate Set, Named Suites, Attribution [NOT STARTED]

**Goal**: the source-store edits are deployed, the full `verify-deploy.sh` gate set has been run
and observed, both named test suites are green, and every residual failure is attributed rather
than absorbed.

**Tasks**:
- [ ] Confirm `index-entries.json` `line_count` values match the tree:
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`, then
      `git diff -- agent-system/extensions/core/index-entries.json` to see whether anything moved.
- [ ] **Redeploy** (Idiom A, tool `timeout` parameter `600000`):
      `timeout 540 bash .claude/scripts/deploy-headless.sh >"$LOGDIR/deploy.log" 2>&1; rc=$?`,
      then `echo "EXIT=$rc"; tail -60 "$LOGDIR/deploy.log"`. Record the wall-clock. Exit `3` is a
      landed deploy, not a failure (see `regeneration-is-manual-only.md`'s
      "`deploy-headless.sh`'s Inline Verification and Exit Code 3"); exits `1`/`2` are not landed.
      On `rc=124`, the inner bound fired — re-check whether the deploy landed before re-running.
- [ ] Confirm the deploy landed and the edited scripts reached `.claude/scripts/`:
      `grep -c "600000" .claude/scripts/verify-deploy.sh .claude/scripts/check-deploy-freshness.sh .claude/scripts/orchestrate-build-dispatch.sh`.
- [ ] **Run the full `verify-deploy.sh` gate set** (Idiom B — gate 8 nests `run-all.sh`, so a full
      battery pays both and can exceed 540s; the dispatching orchestrator measured one full run at
      6m32s, cited here only as the reason Idiom B is required, not as a figure to report):
      `nohup bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim >"$LOGDIR/gates.log" 2>&1 & echo $! > "$LOGDIR/gates.log.pid"`
      followed by the bounded `kill -0` wait. Re-issue the bounded wait as many times as needed;
      never end the turn, never arm a Monitor, never `run_in_background`.
- [ ] Run both named suites explicitly and report their actual output (Idiom A):
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-deploy-freshness.sh`.
- [ ] **Attribute every residual failure**, do not absorb it. Expected, pre-classified:
      `test-four-tier-conflict.sh` Case 6 (known `[1000ms,2000ms)` timing flake measuring
      ~2.3-2.8s under concurrent load — attribute, do not investigate); the completion-deploy
      gate refusing completion while deployed `core` is stale (resolved by the next cycle's
      redeploy checkpoint — do not work around); `check-record-versioning.sh`'s
      "ignored null byte in input" stderr noise from scanning binary files (cosmetic, in
      freshly-shipped sibling code, verified to drop no findings). Any failure NOT on this list is
      investigated and either fixed or recorded with evidence.
- [ ] Record the measured `deploy-headless.sh` and full-gate-set wall-clock figures, and reconcile
      them against the runtime note Phase 2 wrote. Correct the note if the measurements disagree.
- [ ] Confirm no task-number reference landed anywhere under `agent-system/**`:
      `bash .claude/scripts/check-task-references.sh` (or the gate-4 run inside the full set).

**Timing**: 1.5 hours

**Depends on**: 3, 5

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - final `line_count` resync if anything moved
- `agent-system/extensions/core/scripts/deploy-headless.sh` - runtime-note figure corrected if this phase's measurement disagrees with Phase 2's
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - runtime figure corrected if it disagrees

**Verification**:
- The complete gate set: `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`
  run to completion via Idiom B, with its exit code and the full `FAIL`/`FINDING` list reported
  verbatim — every finding either clean or attributed by name.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-deploy-freshness.sh`
  green, with actual output reported.
- Deploy landed: exit `0`, `3`, or `4`, with the deployed-artifact count reported, and `600000`
  present in the deployed copies of the edited scripts.
- Acceptance walk-through, each item answered with evidence: every in-scope emission site carries
  the fragment; Rule 1 states the obligation as a numbered requirement; all three ALSO RULE ON
  questions have a recorded ruling; both named suites green; the three-shapes distinction is
  recorded and composes with the dispatched-subagent mandate; redeployed with residual failures
  attributed.

---

## Testing & Validation

- [ ] `test-orchestrate-build-dispatch.sh` green — its stale-fixture
      `assert_contains "$content" "deploy-headless.sh"` assertion named and confirmed.
- [ ] `test-deploy-freshness.sh` green — BOTH its STALE assertions named and confirmed: exactly
      one `^WARN:` line, and the `deploy-headless.sh` substring present.
- [ ] `test-lint-agent-contracts.sh` green (Check H unaffected — the generated-copy block untouched).
- [ ] The per-phase `run-all.sh --only` subsets in Phases 4 and 5 all green or attributed.
- [ ] `bash -n` clean on every edited shell script.
- [ ] `check-extension-docs.sh` produces no NEW advisory relative to a pre-edit baseline,
      including Rule R `line_count` truth.
- [ ] Full `verify-deploy.sh` gate set run to completion, with residual failures attributed.
- [ ] No task-number reference under `agent-system/**` (gate 4 / `check-task-references.sh`).

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/external-process-wait.md` — Rule 1 restructured
  into numbered requirements, caller-agnostic, with the exit-124 step and the 3a/3b note.
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` — tool-`timeout`
  pairing stated in prose; the shape taxonomy recorded.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — canonical
  remedy fragment, in-scope predicate, emission-site inventory, deferred lint.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — harness-initiated
  backgrounding named inside Local Long-Running Command Discipline.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — sub-case-3b note and a
  log-redirected `orchestrate-cycle-plan.sh` invocation shape.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — cross-reference
  to the shape taxonomy.
- Fourteen scripts under `agent-system/extensions/core/scripts/` carrying the canonical fragment.
- `agent-system/extensions/core/index-entries.json` — resynced `line_count` values.
- A redeployed `.claude/` tree and a completed full gate-set run.
- `specs/392_deliver_tool_timeout_half_of_bounded_wait_idiom/summaries/01_tool-timeout-remedy-delivery-summary.md`.

## Rollback/Contingency

Every edit is an additive append to prose or to a string literal, with no deletions and no
structural refactoring, so the blast radius of any single phase is one file's worth of appended
text. Per-phase rollback is `git checkout` of that phase's own paths from `HEAD` once the phase's
commits are in — the plan's phases each commit independently, so a bad phase is reverted without
disturbing its siblings.

If a phase needs a defensive checkpoint before risky work, use
`bash .claude/scripts/git-snapshot.sh 392 --no-revert` (never the default reverting form as a
routine checkpoint). Reserve the default reverting
`bash .claude/scripts/git-snapshot.sh 392` for a genuine rollback scenario, per
`context/contracts/recovery.md`'s rollback rung.

Two specific contingencies:

- **If a named test suite goes red on a fragment append**, the fix is the fragment's wording, not
  the test: both assertions are deliberately loose (a literal `deploy-headless.sh` substring, and
  a `^WARN:` line count). A red suite means the fragment violated one of those two properties.
  Updating either assertion requires an argued justification, per the task's acceptance — a
  mechanical test edit is not acceptable here.
- **If the redeploy does not land** (`deploy-headless.sh` exit `1` or `2`), stop: do not
  hand-patch any file under `.claude/**` as a substitute, which would mask the divergence rather
  than fix it. Fix the deploy failure at its source, or close the phase `[PARTIAL]` with a
  handoff naming the concrete resume command.
