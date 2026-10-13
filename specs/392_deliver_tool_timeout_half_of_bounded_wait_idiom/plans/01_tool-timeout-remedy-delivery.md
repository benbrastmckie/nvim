# Implementation Plan: Task #392

- **Task**: 392 - Deliver the tool-`timeout` half of the bounded-wait idiom to every redeploy
  remedy emission site and to Rule 1's presentation
- **Status**: [NOT STARTED]
- **Effort**: 11.25 hours
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
sites that need it, at **universal scope via a shared helper** per the user's recorded decision.
**Half B** restructures Rule 1 so the Bash-tool `timeout`-parameter obligation reads as a
numbered requirement rather than an unmarked sentence beside a rationale heading, and states it
in caller-agnostic terms so it binds the orchestrator's own foreground calls, not only a
dispatched subagent's. **Half A** routes every runtime redeploy-remedy emission site through one
new shared library, `scripts/lib/redeploy-remedy-lib.sh`, so the remedy text has exactly one
definition repo-wide.

The plan is sequenced around the self-modification hazard this task was flagged for at admission:
the helper is built and proven in isolation first, call sites convert in small separately-committed
batches, and the orchestrator-critical scripts convert **last**, after the inert ones have proven
the helper in production.

### Research Integration

The research report is the authoritative input. Carried from it and independently re-derived at
plan-authoring time (see per-phase **Scope Hypothesis** lines):

- **Finding 3 confirmed, and tightened.** Both named suites assert only the loose literal
  substring `deploy-headless.sh` (`test-orchestrate-build-dispatch.sh:668`
  `assert_contains "$content" "deploy-headless.sh"`; `test-deploy-freshness.sh:151`
  `[[ "$OUT_STALE" == *"deploy-headless.sh"* ]]`). **One constraint the report did not surface**:
  `test-deploy-freshness.sh:149` also asserts `WARN_COUNT_STALE -eq 1`, where
  `WARN_COUNT_STALE=$(grep -c '^WARN:' ...)`. Emitted text MUST NOT begin a physical line with
  `WARN:`.
- **Finding 2 confirmed, and independently confirmed by the dispatching orchestrator** from the
  suite header: `test-deploy-freshness.sh` is a regression suite for `check-deploy-freshness.sh`,
  not `verify-deploy.sh`. `verify-deploy.sh`'s two named strings have no suite asserting on them
  by name. Phase 9 re-establishes assertion coverage against the **final** site list, since
  widening scope brings newly-covered sites into play.
- **Finding 4 confirmed.** Rule 1's `timeout`-parameter sentence sits at
  `external-process-wait.md:48`, *before* the "Why 540 < 600" heading at `:51`, already
  imperative. The defect is structural placement, so the fix is an explicit numbered sub-step,
  not a reword (Decision 3).
- **Finding 5 confirmed.** All three wait-discipline subsections already exist in
  `general-implementation-agent.md`, and none of their MUST bullets states the tool-parameter
  obligation.
- **Finding 7 confirmed.** `bounded-build-waiter.md`'s "Copy this exact text" generated-copy
  block is at `:174-190`, literal-copied into 14 carrying agent files and checked by
  `lint-agent-contracts.sh` Check H. This plan edits only ordinary prose there (Decision 5).
- **Finding 1 superseded.** The report's 13-site count and the dispatching orchestrator's ~15-file
  list are both treated as **leads, not inventories**. Phase 1 derives the authoritative list
  mechanically and records it (Decision 2).
- **Recommendation 1 (shared helper) is now the adopted approach**, per the user's decision,
  with the one verified obstacle solved rather than used as grounds to decline (Decision 1).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap phases are
included.

## Goals & Non-Goals

**Goals**:
- A mechanically derived, recorded, authoritative inventory of every redeploy-remedy emission
  site repo-wide, with the IN/OUT discriminator stated and applied per occurrence.
- One shared helper owning the remedy text, proven in isolation before any call site converts.
- Every in-scope site routed through that helper, in small separately-committed batches, with
  orchestrator-critical scripts last.
- Half B: Rule 1 states the tool-`timeout` obligation as a numbered, caller-agnostic requirement.
- A recorded ruling on each of the three ALSO RULE ON questions, declines included.
- The harness-initiated-backgrounding shape named with its two sub-cases, stated where a future
  reader will find it, composing with task #354's mandate.
- Assertion coverage re-established against the final site list; redeployed; full gate set run
  with residual failures attributed.

**Non-Goals**:
- Widening postflight's `stall_suspected` trigger predicate (explicitly out of scope; a prior
  ruling declined it and nothing here bears on it).
- Changing the harness's own Bash-tool defaults.
- Editing `bounded-build-waiter.md`'s "Copy this exact text" generated-copy block, or
  re-propagating the agent-contract bullet pair across the 14 carrying agent files (Decision 5).
- Converting header-comment, self-reference, test-fixture, or non-deploy-remedy occurrences
  (Decision 2's OUT rules) — these are not emission sites.
- Adding the tool-timeout obligation to the three MUST-bullet summaries in
  `general-implementation-agent.md` beyond the one clarifying note Decision 6 authorizes.
- Adding a repo-root computation (`$SCRIPT_DIR/../..`) to any script that lacks one — sibling-lib
  resolution only, so the Root-Resolution Guard requirement is not newly incurred (Decision 1).
- A lint asserting every emission site routes through the helper (recorded as a named follow-up
  in Phase 1's deliverable, not built here).
- Investigating `test-four-tier-conflict.sh` Case 6 (known pre-existing timing flake; attribute,
  do not investigate).

## Decisions

### Decision 1 — Shared helper: a new dedicated lib, with the fixture obstacle solved and a degrade-safe source

The user has ruled for universal scope via a shared helper, recorded in
`specs/392_deliver_tool_timeout_half_of_bounded_wait_idiom/.decisions.json`. This plan implements
that ruling. Three design constraints, all verified at plan-authoring time, determine its shape:

**(a) A new dedicated lib, not `scripts/lib/common.sh`.** `common.sh` is sourced by only a
minority of the callers and carries unrelated machinery; a new single-purpose
`scripts/lib/redeploy-remedy-lib.sh` keeps the dependency a leaf. Verified: `scripts/lib/` **is**
deployed (`.claude/scripts/lib/` already carries `common.sh`, `deploy-freshness-lib.sh`,
`deploy-baseline-lib.sh` and others), so a new lib reaches every deploy consumer by the existing
mechanism with no loader change.

**(b) The `test-deploy-freshness.sh` fixture obstacle is solved by extending the fixture, and
the update is argued.** That suite builds its workdir by copying exactly two files
(`check-deploy-freshness.sh` and `lib/deploy-freshness-lib.sh`), so the new lib must be copied
too. The argument is the suite's own stated intent, quoted from its header comment: the files are
"copied byte-for-byte so the suite exercises exactly the deployed artifacts." A fixture that
omits the new lib would exercise the degraded fallback path (see (c)) instead of the real
deployed shape — the opposite of what the suite exists to do. This is one added `cp` line, argued
rather than mechanical, as the task's acceptance requires.

**(c) The source is guarded and degrades to pre-change behavior, never to a hard failure.** This
is the structural mitigation for the self-modification hazard, not a stylistic choice. Each
caller gets:

```bash
_RR_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/redeploy-remedy-lib.sh"
[ -f "$_RR_LIB" ] && . "$_RR_LIB"
declare -F redeploy_remedy_fragment >/dev/null 2>&1 || redeploy_remedy_fragment() { printf '%s' ""; }
```

A deploy tree that predates the lib, or a partial deploy, therefore emits exactly the pre-change
remedy text rather than dying at source time. Several core scripts do not use `set -e`, so an
unguarded `source` of a missing helper would print an error and continue in an undefined state —
precisely the failure this guard prevents.

**(d) Resolution cost is uneven and drives the batch ordering.** Re-derived at plan-authoring
time: ten callers already resolve their own directory (`SCRIPT_DIR` via `BASH_SOURCE`, or
`$(dirname "${BASH_SOURCE[0]}")` inline — `skill-base.sh` already sources `lib/common.sh` through
exactly this shape, and `check-extension-docs.sh` already sources `deploy-root-guard.sh` through
it). **Three do not resolve their own directory at all**: `verify-deploy.sh`,
`deploy-headless.sh`, `command-gate-out.sh`. Those three need a new own-dir expression, which is
new machinery in sensitive files and is why they are split across Phases 7 and 8 rather than
batched with the leaf callers. The expression added is sibling-lib-relative only — it MUST NOT
compute a repo root as `"$SCRIPT_DIR/../.."`, which would newly incur
`regeneration-is-manual-only.md`'s Root-Resolution Guard obligation
(`. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1`) for no benefit this task needs.

### Decision 2 — The IN/OUT discriminator, and why Phase 1 derives the list itself

Neither the research report's count (13 sites / 9 scripts) nor the dispatching orchestrator's
list (~15 files) is treated as closed. Phase 1 is a **mechanical enumeration phase** that derives
the authoritative list from the tree and records it. Already verified at plan-authoring time as a
correction to the leads given: the two `lib/` entries on the orchestrator's list,
`lib/redeploy-checkpoint-lib.sh` and `lib/deploy-baseline-lib.sh`, carry
`deploy-headless.sh` **only inside their header comment blocks** (`deploy-baseline-lib.sh:12`
and `:23`), so both are OUT by rule O1 below — recorded here as evidence the discriminator does
real work, not as grounds to skip the enumeration.

**IN SCOPE — a "redeploy-remedy emission site"**: a string the script emits **at runtime**
(stderr, stdout, or text composed into an agent-facing dispatch prompt) that directs its reader
to RUN a regeneration — i.e. it names `deploy-headless.sh` (or the picker's `[Reload All]` /
`Regenerate`) as an action the reader should take.

**OUT OF SCOPE — incidental mentions**, each with a stated rule so the classification is
auditable:

- **O1 — Comment blocks.** Any occurrence inside a leading `#` header block or an inline `#`
  comment. Not emitted at runtime; read only by someone already inside the file. Covers
  `lib/redeploy-checkpoint-lib.sh`, `lib/deploy-baseline-lib.sh`,
  `orchestrate-record-decision.sh`, `orchestrate-conclusion-aggregate.sh`,
  `dispatch-metrics.sh`, `issue-record.sh`, `system-defect-record.sh`,
  `measure-eager-context.sh`, and the header narratives in `check-extension-docs.sh`,
  `orchestrate-cycle-plan.sh`, `verify-deploy.sh` and `deploy-headless.sh`.
- **O2 — Self-reference.** `deploy-headless.sh`'s own usage/help text naming itself.
- **O3 — Test fixtures and assertions.** A path or substring inside `scripts/tests/**`.
- **O4 — A remedy naming a different tool.** `check-extension-docs.sh`'s Rule R remedies name
  `generate-context-line-counts.sh`, not a deploy.
- **O5 — Pure post-hoc diagnostics.** A report that a deploy already ran or already failed,
  with no next action named for the reader.

**Tie-break, stated so borderline cases resolve deterministically**: a string that tells the
reader the deploy did not land or is stale AND names running one as the next action is **IN**,
even if it also reports a result — so `orchestrate-cycle-plan.sh`'s
`REDEPLOY CHECKPOINT WARNING: ... redeploy manually, then re-run /orchestrate` is IN, while
`command-gate-out.sh`'s three post-deploy report lines are to be classified individually against
O5 and this tie-break rather than pre-decided here. Where a case remains genuinely ambiguous
after both rules, resolve **toward IN** (an extra timeout hint on a failure notice is harmless)
and record the call.

Phase 1 records the result as a table of every occurrence with its rule and verdict, so a future
audit does not re-run the grep.

### Decision 3 — Half B: restructure Rule 1 into numbered requirements, not a reword

The report's Decision 2 is **adopted**. Rule 1 becomes an explicit numbered list whose step 1 is
the inner-bounded foreground command and whose step 2 is the tool-`timeout`-parameter raise, with
"Why 540 < 600" retained and scoped strictly to the 60-second margin. This matches the acceptance
criterion ("a numbered requirement, not ... rationale under a 'why this constant' heading")
without overstating what was already true: the sentence was already imperative and already sat
before that heading (Finding 4) — what it lacked was any structural marker that a second required
step existed at all.

**Caller-agnostic framing is added at the same time**, because it is the one change that makes
Rule 1 reach the orchestrator. The document's **Audience** line reads "Any dispatched subagent";
the numbered requirement is restated to bind **any caller issuing a long foreground Bash call**,
dispatched subagent or orchestrator session alike. One sentence's audience widens, not the
document's.

### Decision 4 — ALSO RULE ON #1 (deploy-local runtime note): yes, add one

`deploy-headless.sh`'s header already documents its modes and exit codes inline, so a parallel
bullet stating its expected runtime class and the required tool `timeout` at the point of use
fits the file's existing conventions. **The figure must be measured in Phase 4, not carried**:
the orchestrator's same-session ~3-4 minute measurement is evidence that the note is warranted,
and MUST NOT be written into it.

### Decision 5 — ALSO RULE ON #2 (`bounded-build-waiter.md` needs the same pairing): yes, as ordinary prose only

Adopted with its placement constraint, and the constraint is itself part of the ruling. Finding
6's gap is real and sits in the exact subsection an agent reads immediately before choosing the
foreground form: "The Canonical Idiom" says "Prefer the simpler foreground form ... whenever the
command fits within the calling tool's own timeout limit" — which presupposes the limit is
adjustable and never says to adjust it. A local deploy is structurally far closer to this file's
local-detached-build case than to `external-process-wait.md`'s remote `gh run watch` case, so
leaving the pairing only in the remote document is the delivery gap one file over.

**Placement: ordinary prose in "The Canonical Idiom" and "Sizing a Wait Near the Per-Call
Ceiling" — never inside the `### Copy this exact text` generated-copy block (`:174-190`), which
is explicitly out of scope.** The reason: that block is literal-copied into 14 carrying
implementation-agent files and kept in sync by `lint-agent-contracts.sh` Check H, so any wording
change inside it requires a full re-propagation pass across all 14 plus a lint re-check. That
cost buys nothing this task needs, because the bullet pair's content — whether backgrounding is
permitted at all — is orthogonal to what value the tool `timeout` parameter carries. Phase 4
verifies by diff that the block has zero changed lines.

### Decision 6 — ALSO RULE ON #3 (`general-implementation-agent.md` naming the third case): yes, as a clarifying note inside the existing Local section

The report's Decision 5 is **adopted**. Finding 5 confirms the three-way structure already exists
and already covers local scripts like `deploy-headless.sh` by command category. What is missing
is one clarifying note that "backgrounded at all" includes the **harness's own**
auto-backgrounding of an ordinary foreground call whose tool `timeout` parameter was left at the
120000ms default — not only a deliberate `&`/`nohup`. That framing is load-bearing: the existing
Local Long-Running Command Discipline presumes the agent controls whether backgrounding happens,
and it does not.

**Composition with task #354, stated explicitly**: #354's ruling lives in the separate
Dispatched-Subagent Wait Discipline subsection and governs a nested `Agent`-tool dispatch. This
note touches only the Local Long-Running Command Discipline subsection and adds no restriction on
subagent dispatch. The two rulings concern different trigger surfaces and neither weakens the
other: #354 forbids an async subagent dispatch awaited across a turn boundary; this note says an
*ordinary foreground* call can be backgrounded without the agent choosing it, and names the
parameter that prevents it. A fourth top-level subsection is **declined** — the case is a
precondition on all three existing disciplines, not a fourth kind of wait.

### Decision 7 — The orchestrator's own foreground call: yes, the deliverable must say so, at `skill-orchestrate/SKILL.md`'s invocation site

Shape 3's two sub-cases have different remedies, and 3a's remedy is actively misleading for 3b:

- **3a — the call fits under the ceiling, but the parameter was left at the 120000ms default.**
  Remedy: raise the Bash tool `timeout` parameter to `600000` and keep an inner `timeout` below
  it. This is the measured `deploy-headless.sh` case (3-4 min: past 120s, comfortably inside
  540s). Halves A and B both target this sub-case.
- **3b — the call cannot fit under the 600s ceiling at all.** Raising the parameter to its ceiling
  does not help, because the ceiling itself is the bound. Remedy: redirect stdout and stderr to a
  log, launch with a captured PID, and resolve with a *sequence* of bounded foreground `kill -0`
  waits — `bounded-build-waiter.md`'s "Sizing a Wait Near the Per-Call Ceiling".

The orchestrator's auto-backgrounded `orchestrate-cycle-plan.sh` call is sub-case 3b, verified at
plan-authoring time: the Inter-Cycle Redeploy Checkpoint inside that one script call runs a pre
`verify-deploy.sh --skip-slow` findings snapshot, then `deploy-headless.sh --skip-verify`, then a
post `verify-deploy.sh --skip-slow` snapshot (and, on a new finding, a confirm snapshot). That
composite is structurally larger than one 600s call.

**Placement ruling, two candidates evaluated and declined**:

- **`context/contracts/orchestrator-discipline.md` — declined.** Audience-correct on its face
  (its opening sentence binds the orchestrator role itself), and `external-process-wait.md`'s own
  "Contract home for this prohibition" note already cites that audience distinction. But its
  "Domain Specialization / Scope" section scopes it **`--hard`-only**, and the observed stranding
  happened in a standard-mode `/orchestrate` run. Standard-mode guidance placed there would be
  unreachable in exactly the mode that produced the evidence.
- **`docs/architecture/orchestrate-state-machine.md` — declined as primary home, adopted as a
  cross-reference.** Its "Diagnosing Dispatch Liveness: A Probe for External Watchers" section
  (#354's addition) concerns an external watcher diagnosing a quiet dispatch — complementary, but
  it tells the orchestrator nothing at the moment it issues the call.
- **Adopted: `skills/skill-orchestrate/SKILL.md`, at the `orchestrate-cycle-plan.sh` invocation
  block.** The point of use, in the one file the orchestrator reads, today documented with no
  timeout guidance at all. A second, sharper reason it must change there: the documented shape is
  `plan_json=$(bash .claude/scripts/orchestrate-cycle-plan.sh ...)`, a command substitution into
  a shell variable. If the harness backgrounds that call, the captured stdout is lost outright —
  there is no log to poll and no way back to the JSON. The note must therefore **change** the
  documented shape to redirect to a log and read the JSON back, not merely annotate it.

### Decision 8 — The `exit=124` fallback: a generic step in Rule 1, the `--skip-slow` specialization declined there

Split, not adopted wholesale:

- **Adopted into Rule 1** as a short step: exit `124` means the *inner bound fired*, not that the
  command's subject failed — the command was killed mid-run, so re-check state rather than reading
  124 as a failure. Caller-agnostic, and genuinely belongs with the idiom that produces the 124.
- **Declined for Rule 1**: the "re-run once with `--skip-slow` and record the baseline as
  `--skip-slow` depth" fallback. It is a property of `verify-deploy.sh`'s gate-depth and
  baseline-comparison semantics, not of the bounded-wait idiom, and Rule 1 is consumed by callers
  waiting on things with no `--skip-slow` equivalent. Recorded in the `deploy-headless.sh` runtime
  note instead (Phase 4), where the gate it concerns is already the subject.

### Decision 9 — The three-shapes taxonomy's home: `bounded-build-waiter.md`

`bounded-build-waiter.md` already hosts the shape-taxonomy ruling record — its
"Dispatched-Subagent Wait Ruling: A Third Case, Resolved in `general-implementation-agent.md`,
Not Here" section is where #354's ruling was recorded. Extending that same file with the
harness-initiated shape keeps the taxonomy in one place and reads as composing with #354 by
following the precedent #354 itself set. `external-process-wait.md` Rule 1 and
`general-implementation-agent.md`'s Local section cross-reference it by path.

## The Self-Modification Hazard — Stated Plainly

**This orchestration is executing the very scripts this task edits.** `skill-base.sh` runs on
every skill lifecycle stage; `task-lock.sh` acquires and releases every task lock;
`command-gate-out.sh` performs every status transition and commit trigger;
`orchestrate-build-dispatch.sh` composes every dispatch file; `orchestrate-cycle-plan.sh` is the
loop itself; `verify-deploy.sh` is every phase gate.

**If the helper breaks `skill-base.sh` or `task-lock.sh`, this orchestration cannot commit or
lock, and recovery is by hand** — no automated path reaches back in, because the machinery that
would run the recovery is the machinery that broke. The same holds for `command-gate-out.sh`
(no status transition or commit can fire) and `orchestrate-cycle-plan.sh` (no further cycle can
be planned).

Four structural mitigations, each wired into the phase sequence rather than left to care:

1. **The helper is built and proven in isolation first** (Phase 2), with its own test suite, with
   zero call sites converted.
2. **The source is degrade-safe by construction** (Decision 1(c)): a missing or partial lib falls
   back to a no-op fragment and pre-change output, never a source-time failure.
3. **Call sites convert in small, separately-committed batches** (Phases 6, 7, 8) — never one
   sweeping commit — grouped so a broken batch cannot take down the commit or dispatch machinery.
4. **Orchestrator-critical files convert LAST** (Phase 8), after the inert callers have proven
   the helper in production.

## Bounded-Wait Idiom — Inline, Verbatim, for Every Long-Command Step

Written out in full because it would be absurd for the plan that fixes this defect to strand its
own implementer. Every phase step invoking a long command names **Idiom A** or **Idiom B** and
means exactly this.

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
recorded as `--skip-slow` depth (never silently compared against a full-depth baseline).

**Idiom B — the command may exceed 540s.** Use for `verify-deploy.sh`'s **full** gate set (gate 8
nests `run-all.sh`, so a full battery pays both) and for any deploy+verify composite. Tool
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

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The helper breaks orchestrator-critical machinery; recovery is by hand | H | L | The four structural mitigations above: isolation-first, degrade-safe source, small separate batches, critical files last. Phase 8 additionally commits per file, not per batch. |
| A caller lacking own-dir resolution gets a broken sibling-lib path | H | M | Verified: `verify-deploy.sh`, `deploy-headless.sh`, `command-gate-out.sh` have no own-dir expression. Each gets a sibling-lib-relative expression only, never a `../..` root computation (which would newly incur the Root-Resolution Guard obligation). Each is `bash -n`'d and smoke-run in its own phase. |
| `test-deploy-freshness.sh` fixture omits the new lib and silently exercises the fallback | M | H | Phase 2 adds the `cp` line and asserts the fixture's emitted remedy contains `600000`, so the fallback path cannot pass as the real one. |
| `test-deploy-freshness.sh`'s `WARN_COUNT_STALE -eq 1` assertion breaks | H | L | The helper's output must not begin a physical line with `WARN:`; `check-deploy-freshness.sh`'s remedy lines start with two spaces — preserve that. Asserted in Phases 2 and 7. |
| Appending to a `verify-deploy.sh` `fail` call changes FINDING text and perturbs the redeploy checkpoint's pre/post baseline | M | M | Verified: `fail()` builds `FINDING $CURRENT_GATE $1` from its **first** argument only; the remediation `$2` never reaches a FINDING line. So `:310` is safe as-is, and the two `fail "... (run deploy-headless.sh first)"` calls must take the remedy as a **new second argument**, leaving `$1` byte-identical. |
| `index-entries.json` `line_count` drift fails `check-extension-docs.sh` Rule R | M | H | Verified: `external-process-wait.md` pinned at `line_count: 161`, `bounded-build-waiter.md` at `318`, both matching current `wc -l`. Every markdown-editing phase ends by running `generate-context-line-counts.sh --write`. `deploy-headless.sh` runs it pre-deploy too, but a `verify-deploy.sh` run *before* redeploy would fail without it. |
| The inventory is wrong in either direction | M | M | Phase 1 derives it mechanically with a stated discriminator and records every occurrence with its rule and verdict; Phase 9 re-checks the final list against actual assertions. Neither the report's count nor the orchestrator's list is trusted as closed. |
| `file_scope` harvest misses edits (a sibling task lost four edits to extension-relative paths) | H | M | Every `Files to modify` entry is **repo-relative** (`agent-system/extensions/core/...`) so `plan-file-scope-harvest.sh` widens `file_scope` correctly. |
| Completion-deploy gate refuses completion while deployed `core` is stale | L | H | Expected; the next cycle's redeploy checkpoint resolves it. Do not plan or build a workaround. |
| A long gate/deploy call strands the implementer — the very defect this task fixes | H | M | Every long-command step carries Idiom A or Idiom B inline. Non-negotiable. |
| `test-four-tier-conflict.sh` Case 6 timing flake under concurrent load | L | M | Known pre-existing; `[1000ms,2000ms)` assertion measuring ~2.3-2.8s. **Attribute, do not investigate.** |
| `check-record-versioning.sh` "ignored null byte in input" stderr noise | L | H | Cosmetic, in freshly-shipped sibling code, verified to drop no findings. Not this task's to fix. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4 | 1 (for 2); 3 (for 4) |
| 3 | 5, 6 | 3, 4 (for 5); 2 (for 6) |
| 4 | 7 | 6 |
| 5 | 8 | 7 |
| 6 | 9 | 1, 8 |
| 7 | 10 | 5, 9 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Mechanical Enumeration and Authoritative Site Inventory [COMPLETED]

**Goal**: an authoritative, recorded inventory of every redeploy-remedy emission site repo-wide,
derived from the tree rather than copied from any prior count, with the discriminator stated and
applied per occurrence. No caller is edited in this phase.

**Tasks**:
- [x] Derive candidate occurrences mechanically over the **source store**, not a deployed tree:
      `grep -rn "deploy-headless.sh\|Reload All\|Regenerate" --include="*.sh" agent-system/extensions/`
      Widen once with the picker-wording alternates so a remedy that names only the picker is not
      missed, and run it over every extension, not only `core`.
- [x] Classify **every** occurrence against Decision 2's discriminator: IN if emitted at runtime
      and naming a regeneration as the reader's next action; OUT by rule O1 (comment block), O2
      (self-reference), O3 (test fixture/assertion), O4 (different tool), or O5 (pure post-hoc
      diagnostic). Apply the tie-break for borderline cases and record the call made.
- [x] Sanity-check the classification against the two leads given, and record the disagreements
      explicitly: the research report's 13 sites / 9 scripts, and the dispatching orchestrator's
      ~15-file list (which includes `lib/redeploy-checkpoint-lib.sh` and
      `lib/deploy-baseline-lib.sh` — both already verified at plan-authoring time to carry the
      string only in header comments, i.e. OUT by O1). Treat a disagreement as a finding to
      record, not as a reason to adopt either list.
- [x] Assign each IN site a **batch**: A (inert leaf — no role in the executing orchestration's
      commit, lock, dispatch, or gate path), B (verification path), C (orchestrator-critical).
      Record the reasoning per site. The Phase 6/7/8 file lists are this plan's hypothesis;
      correct them here if the enumeration disagrees.
- [x] Record the inventory in
      `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` as a new
      `### Redeploy-Remedy Emission Sites` subsection under "Detecting When You're Stale":
      (a) the discriminator and its five OUT rules plus the tie-break, (b) the per-occurrence
      table with file, rule applied, and verdict, (c) the batch assignment, (d) the deferred
      follow-up — a lint asserting every IN site routes through the helper — as a named future
      item, not built here.
- [x] No task-number references in any edited file
      (`rules/no-task-references-in-deliverables.md`).
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: a single markdown edit with no compile or elaboration surface, so
`suite_selection_select` returns `__FULL_SWEEP__` (sub-case (b), source-store non-`specs/**`
markdown); the covering check is
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
with the explicit source-store TARGET, alongside the `prose` row's diff read-through.

**Scope Hypothesis**: this plan carries two unverified site counts from other records — the
research report's 13 sites across 9 scripts, and the dispatching orchestrator's ~15 files — and
its own plan-authoring-time grep suggested roughly 22 IN occurrences across 14 scripts. **All
three are hypotheses.** This phase's own mechanical enumeration is the confirmation step and its
recorded table supersedes every one of them; the Phase 6/7/8 file lists below are to be corrected
against it.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - new `### Redeploy-Remedy Emission Sites` subsection: discriminator, five OUT rules, tie-break, per-occurrence table, batch assignment, deferred lint
- `agent-system/extensions/core/index-entries.json` - `line_count` resynced

**Verification**:
- The recorded table accounts for **every** occurrence the grep returned — IN and OUT — with no
  unclassified rows.
- Re-running the grep after recording returns the same occurrence set the table lists.
- `wc -l` on the edited markdown equals its new `index-entries.json` `line_count`.
- Idiom A: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  — clean, or every finding attributed as pre-existing.

---

### Phase 2: Build the Shared Helper in Isolation, With Its Own Test [COMPLETED]

**Goal**: `scripts/lib/redeploy-remedy-lib.sh` exists, is proven by its own suite, and the
`test-deploy-freshness.sh` fixture carries it — with **zero** call sites converted.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/redeploy-remedy-lib.sh` with a header
      comment stating its purpose, its single-definition role, and the degrade-safe contract.
      Export two functions, so sites that only need a suffix and sites whose whole remedy is the
      shared boilerplate are both genuinely deduplicated rather than merely sharing a tail:
      - `redeploy_remedy_fragment()` — the timeout clause alone, for appending to a
        site-specific remedy. Must name `600000`, name an inner `timeout 540`, and reference
        `context/patterns/external-process-wait.md` Rule 1 by path.
      - `redeploy_remedy()` — the full canonical remedy (regeneration action + the fragment), for
        the sites whose entire remedy text is today the identical picker boilerplate.
- [x] Hard constraints on both functions' output, asserted by the new suite: contains the literal
      substring `deploy-headless.sh`; begins **no** physical line with `WARN:`; emits no trailing
      newline (callers control their own line structure); contains no task-number reference.
- [x] Make the lib idempotent and side-effect-free on source: no `set -e`/`set -u` changes, no
      global variable writes beyond the function definitions, safe to source twice.
- [x] Create `agent-system/extensions/core/scripts/tests/test-redeploy-remedy-lib.sh` covering:
      both functions' exact output; the `deploy-headless.sh` substring; no line-initial `WARN:`;
      no trailing newline; double-source idempotence; and the **degrade-safe fallback** — that a
      caller using Decision 1(c)'s guarded-source snippet with the lib absent defines a no-op
      `redeploy_remedy_fragment` and does not fail. `run-all.sh` auto-discovers
      `scripts/tests/test-*.sh` by glob (verified), so no registration step is needed.
- [x] Update `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh`'s fixture to
      copy the new lib into `$WORKDIR/bin/lib/` alongside `deploy-freshness-lib.sh`. **Argue the
      update in the fixture's own comment**, citing the suite header's stated intent (files
      "copied byte-for-byte so the suite exercises exactly the deployed artifacts") — a fixture
      omitting the lib would exercise the fallback path instead of the deployed shape.
- [x] Confirm by reading `suite-selection-lib.sh` whether a path-to-suite mapping entry is needed
      for the new lib and the new suite; add it if the resolver would otherwise return
      `__FULL_SWEEP__` for `scripts/lib/redeploy-remedy-lib.sh`.
- [x] **Convert no call sites in this phase.** Confirm by diff that no file under
      `scripts/` other than the new lib, the new suite, and the fixture is touched.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: a new leaf library plus its own new suite, with no call site converted and
therefore no externally visible behavior change; covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-redeploy-remedy-lib.sh,test-deploy-freshness.sh`.

**Scope Hypothesis**: this plan asserts `run-all.sh` auto-discovers suites by the
`scripts/tests/test-*.sh` glob (so no registration is needed) and that `scripts/lib/` is deployed
to `.claude/scripts/lib/` by the existing mechanism (so no loader change is needed) — both
re-derived at plan-authoring time from `run-all.sh`'s header and a listing of the deployed `lib/`
directory. Confirm both by reading `run-all.sh`'s discovery block and
`ls .claude/scripts/lib/` before relying on them.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/redeploy-remedy-lib.sh` - NEW: `redeploy_remedy_fragment()` and `redeploy_remedy()`, the single definition of the remedy text
- `agent-system/extensions/core/scripts/tests/test-redeploy-remedy-lib.sh` - NEW: output, substring, line-prefix, idempotence, and degrade-safe-fallback coverage
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` - fixture copies the new lib; the update argued inline from the suite header's stated intent
- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` - path-to-suite mapping for the new lib and suite, if the resolver needs one

**Verification**:
- `bash -n` on the new lib, the new suite, and the edited fixture.
- Idiom A: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-redeploy-remedy-lib.sh,test-deploy-freshness.sh`
  — both green, actual output reported.
- `test-deploy-freshness.sh`'s STALE case still counts **exactly one** `^WARN:` line and still
  finds the `deploy-headless.sh` substring — both assertions named and confirmed.
- A direct probe that the fixture's emitted remedy now contains `600000`, proving the fixture
  exercises the real lib and not the fallback.
- A direct probe of the degrade-safe path: source the guarded snippet with the lib renamed away,
  confirm `redeploy_remedy_fragment` is defined and returns empty, and confirm no non-zero exit.
- `git diff --name-only` lists only the four files above.

---

### Phase 3: Half B — Restructure Rule 1 into Numbered Requirements [COMPLETED]

**Goal**: `external-process-wait.md` Rule 1 states the tool-`timeout` obligation as a numbered
requirement in caller-agnostic terms, with "Why 540 < 600" retained and scoped strictly to the
margin, plus the generic `exit 124` step.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/patterns/external-process-wait.md` in full
      immediately before editing. Anchor on TEXT, never on the line numbers cited in this plan.
- [x] Rewrite the `### 1. Bounded blocking wait` body as an explicit numbered list:
      **(1)** issue an inner-bounded, foreground, blocking command (keep the existing
      `timeout 540 gh run watch ...` code block as the worked example);
      **(2)** issue it with the Bash tool's own `timeout` parameter set to `600000` — a required
      step, naming the 120000ms default explicitly as what it must be raised FROM, because leaving
      it at the default makes step (1)'s inner bound inert;
      **(3)** on exit `124`, the inner bound fired and the command was killed mid-run — re-check
      state rather than reading 124 as a failure of the command's subject (Decision 8);
      **(4)** repeat the pair only while the reported `status` is `in_progress` or `queued`.
- [x] Make step (2) **caller-agnostic** (Decision 3): bind it to any caller issuing a long
      foreground Bash call — a dispatched subagent OR an orchestrator session — not only to the
      document's stated "Any dispatched subagent" audience.
- [x] Add, under the numbered list, a short note carrying Decision 7's two sub-cases: raising the
      parameter resolves a call that fits under the ceiling (3a); a call that cannot fit the 600s
      ceiling at all is NOT resolved by the parameter and takes `bounded-build-waiter.md`'s
      "Sizing a Wait Near the Per-Call Ceiling" instead (3b). Cross-reference by path.
- [x] Keep the `**Why 540 < 600**` heading and paragraph, scoped strictly to the 60-second margin.
      Do not delete it and do not let it carry the obligation.
- [x] Add a forward pointer to `bounded-build-waiter.md`'s shape taxonomy (Phase 4 creates the
      target section; this pointer is by section title and path, with no line number).
- [x] No task-number references in the edited file.
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: markdown-only edit with no compile or elaboration surface, so
`suite_selection_select` returns `__FULL_SWEEP__` (sub-case (b)); the covering check is
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
alongside the `prose` row's diff read-through.

**Scope Hypothesis**: this plan asserts Rule 1's `timeout`-parameter sentence sits at
`external-process-wait.md:48` and the "Why 540 < 600" heading at `:51`, and that the file is 161
lines (matching the pinned `line_count: 161`) — re-derived at plan-authoring time from the
research report's Finding 4. Confirm by re-reading the file and running `wc -l` immediately before
editing; anchor the edit on text, not on these figures.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/external-process-wait.md` - Rule 1 restructured into numbered requirements (1)-(4); caller-agnostic step (2); exit-124 step (3); 3a/3b sub-case note; forward pointer to the shape taxonomy
- `agent-system/extensions/core/index-entries.json` - `line_count` resynced

**Verification**:
- Diff read-through confirming every changed hunk lies in prose/markdown.
- `grep -n "600000" agent-system/extensions/core/context/patterns/external-process-wait.md` shows
  the value inside a numbered step, not only inside the "Why 540 < 600" paragraph.
- `grep -n "120000" ...` shows the default named explicitly.
- `wc -l` equals the `line_count` now in `index-entries.json`.
- Idiom A: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

---

### Phase 4: Shape Taxonomy, `bounded-build-waiter.md` Pairing, Measured Deploy-Local Runtime Note [COMPLETED]

**Goal**: ALSO RULE ON #1 and #2 discharged; the three-shapes taxonomy recorded in its chosen
home; `deploy-headless.sh`'s runtime measured, not carried.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` in full.
      **Locate the exact line range of the `### Copy this exact text` block before editing
      anything near it** — nothing in this phase may touch that block (Decision 5).
- [x] **Measure, do not carry** (Idiom A, tool `timeout` `600000`): time one
      `bash .claude/scripts/deploy-headless.sh --skip-verify` run and one
      `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow /home/benjamin/.config/nvim`
      run, recording wall-clock for each. Use the measured figures, with their measurement
      conditions, in every runtime statement this phase writes. The orchestrator's ~3-4 min /
      6-10 min same-session figures are evidence the note is warranted and MUST NOT be written
      into any deliverable.
- [x] `bounded-build-waiter.md`, **ordinary prose only**: in "The Canonical Idiom", state that
      the "calling tool's own timeout limit" referenced by the existing foreground-form preference
      is itself a parameter the caller sets, and that preferring the foreground form requires
      raising it to `600000` (from its 120000ms default), cross-referencing
      `external-process-wait.md` Rule 1 by path. Mirror the pairing in "Sizing a Wait Near the
      Per-Call Ceiling" for the plain-foreground case that subsection does not currently cover.
- [x] `bounded-build-waiter.md`: add a new section recording the **shape taxonomy** (Decision 9),
      adjacent to and composing with the existing "Dispatched-Subagent Wait Ruling: A Third Case"
      section. Name all three shapes — agent-chosen local-gate backgrounding; awaiting a dispatched
      subagent; harness-initiated backgrounding of an ordinary foreground call — and state that the
      third is distinguished by **trigger, not command category**: the agent chose nothing. Record
      sub-cases 3a and 3b with their different remedies, and state explicitly that this composes
      with the dispatched-subagent ruling (different trigger surface, neither weakens the other)
      rather than superseding it.
- [x] `deploy-headless.sh` header: add a bullet, parallel to the existing mode and exit-code
      bullets, stating the **measured** expected runtime class and the required Bash-tool
      `timeout` parameter at the point of use, pointing to `external-process-wait.md` Rule 1 by
      path (Decision 4). Also record the `verify-deploy.sh`-specific exit-124 fallback here (one
      `--skip-slow` re-run with the baseline recorded as `--skip-slow` depth), per Decision 8's
      declined-for-Rule-1 half.
- [x] No task-number references in any edited file.
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`.

**Timing**: 1.25 hours

**Depends on**: 3

**Verification Tier**: prose

**Tier Justification**: two markdown edits plus one shell **header comment** block, none with an
executable surface, so `suite_selection_select` returns `__FULL_SWEEP__` (sub-case (b)); covered
by `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
plus the `prose` row's diff read-through confirming the `deploy-headless.sh` hunk stays inside its
leading `#` block.

**Scope Hypothesis**: this plan asserts `bounded-build-waiter.md`'s generated-copy block spans
`:174-190` and the file is 318 lines (matching the pinned `line_count: 318`) — re-derived at
plan-authoring time. Confirm by `grep -n "Copy this exact text"` and `wc -l` immediately before
editing; anchor on text.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` - tool-`timeout` pairing in "The Canonical Idiom" and "Sizing a Wait Near the Per-Call Ceiling"; new shape-taxonomy section naming the harness-initiated case and its 3a/3b sub-cases
- `agent-system/extensions/core/scripts/deploy-headless.sh` - header comment bullet: measured runtime class, required tool `timeout`, Rule 1 path, verify-deploy exit-124 fallback
- `agent-system/extensions/core/index-entries.json` - `line_count` resynced

**Verification**:
- `git diff -- agent-system/extensions/core/context/patterns/bounded-build-waiter.md` shows
  **zero** changed lines inside the `### Copy this exact text` block.
- Idiom A: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh`
  — green, proving Check H's 14 literal copies are unaffected.
- `grep -n "600000"` hits in both `bounded-build-waiter.md` and `scripts/deploy-headless.sh`.
- The runtime note's figure matches this phase's own measurement, with conditions stated.
- `wc -l` on each edited markdown file equals its new `index-entries.json` `line_count`.
- Idiom A: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

---

### Phase 5: Agent-Contract and Orchestrator-Caller Delivery [NOT STARTED]

**Goal**: ALSO RULE ON #3 discharged inside the existing Local Long-Running Command Discipline
subsection, composing with the dispatched-subagent mandate; and the orchestrator's own foreground
call addressed at its point of use.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/agents/general-implementation-agent.md`'s three
      wait-discipline subsections in full, including Dispatched-Subagent Wait Discipline.
      **Do not modify that subsection.**
- [ ] Add a clarifying note to **Local Long-Running Command Discipline** (Decision 6):
      "backgrounded at all" includes the harness's own auto-backgrounding of an ordinary foreground
      call whose Bash-tool `timeout` parameter was left at its 120000ms default — not only a
      deliberate `&`/`nohup`. State the remedy (raise to `600000`, keep an inner `timeout` below
      it) and cross-reference `external-process-wait.md` Rule 1 and the shape taxonomy by path.
      Decline a fourth top-level subsection explicitly in the note's own wording: this is a
      precondition on all three disciplines, not a fourth kind of wait.
- [ ] Verify by reading that the note introduces no restriction on nested `Agent`-tool dispatch
      and rewords no bullet in the Dispatched-Subagent Wait Discipline subsection.
- [ ] Re-read `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`'s
      `orchestrate-cycle-plan.sh` invocation block in full.
- [ ] Add, immediately adjacent to that invocation block (Decision 7): a note that this one call
      performs the whole of Move 1 **including the Inter-Cycle Redeploy Checkpoint** (pre-verify
      snapshot + `deploy-headless.sh --skip-verify` + post-verify snapshot), that it is therefore
      a sub-case-3b call which can exceed the 600s ceiling even with the tool `timeout` parameter
      at `600000`, and that the documented `plan_json=$(...)` command substitution loses its
      captured stdout outright if the harness backgrounds it. **Change** the documented shape to
      redirect stdout to a log file under the session's own runtime directory and read the JSON
      back from that log, so a backgrounded call stays recoverable. Name the `600000` requirement
      explicitly and cross-reference `bounded-build-waiter.md`'s "Sizing a Wait Near the Per-Call
      Ceiling" by path.
- [ ] Add a one-line cross-reference from
      `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`'s
      "Diagnosing Dispatch Liveness: A Probe for External Watchers" section to the shape taxonomy.
      **Do not** touch that section's `stall_suspected`-predicate paragraphs — the predicate is
      explicitly out of scope and that section already records its own reasoned decline.
- [ ] No task-number references in any edited file.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`.

**Timing**: 0.75 hours

**Depends on**: 3, 4

**Verification Tier**: prose

**Tier Justification**: three markdown edits with no executable surface
(`suite_selection_select` returns `__FULL_SWEEP__`, sub-case (b)); covered by
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

### Phase 6: Convert Batch A — Inert Leaf Call Sites [NOT STARTED]

**Goal**: the helper is proven in production against call sites whose failure cannot touch this
orchestration's commit, lock, dispatch, or gate path.

**Tasks**:
- [ ] Take Phase 1's batch-A assignment as authoritative; correct this phase's file list against
      it before editing.
- [ ] For each batch-A script: **re-read and re-locate the site by TEXT immediately before
      editing.** Every line number in this plan is a plan-authoring-time observation, not an
      anchor.
- [ ] Add Decision 1(c)'s guarded-source snippet once per script, placed after the script's own
      directory resolution and before first use. All batch-A scripts already resolve their own
      directory (`SCRIPT_DIR` via `BASH_SOURCE`), so no new own-dir expression is needed here —
      confirm per script rather than assuming.
- [ ] Convert each site to call `redeploy_remedy_fragment` (append) or `redeploy_remedy` (whole
      remedy), whichever Phase 1 recorded for it.
- [ ] `git-snapshot.sh`, `orchestrate-batch-admit.sh`, `orchestrate-predispatch-review.sh` and
      `task-lock.sh` today carry the **identical** `  Remedy: regenerate via the picker's
      [Reload All]/[Regenerate] entries, or bash .claude/scripts/deploy-headless.sh.` line — these
      are the primary `redeploy_remedy()` candidates. **`task-lock.sh` is batch C, not A** (it is
      orchestrator-critical); convert only the batch-A members here and leave `task-lock.sh` to
      Phase 8.
- [ ] `bash -n` every edited script immediately after editing it.
- [ ] **Commit this batch separately**, as its own commit, before Phase 7 begins.
- [ ] No task-number references in any edited file.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: each edit adds a guarded sibling-lib source plus a string substitution
confined to one script, with no signature change and no shared state, covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-snapshot.sh,test-orchestrate-batch-admit.sh,test-orchestrate-predispatch-review.sh,test-validate-state.sh,test-consumer-freshness.sh`.

**Scope Hypothesis**: this plan hypothesizes batch A as `git-snapshot.sh`,
`orchestrate-batch-admit.sh`, `orchestrate-predispatch-review.sh`, `validate-state.sh:382`,
`check-consumer-freshness.sh:185` and `migrate-state-legacy-fields.sh:161`, and that all six
already define `SCRIPT_DIR` — re-derived at plan-authoring time. Phase 1's recorded batch
assignment supersedes this list; confirm each script's own-dir resolution by
`grep -m1 'SCRIPT_DIR=' <file>` before adding the guarded source.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-snapshot.sh` - guarded source; stale-deploy remedy routed through the helper
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - guarded source; stale-deploy remedy routed through the helper
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - guarded source; stale-deploy remedy routed through the helper
- `agent-system/extensions/core/scripts/validate-state.sh` - guarded source; deploy-first remedy routed through the helper
- `agent-system/extensions/core/scripts/check-consumer-freshness.sh` - guarded source; stale-consumer remedy routed through the helper
- `agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh` - guarded source; deploy-first remedy routed through the helper

**Verification**:
- `bash -n` clean on every edited script.
- Idiom A: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-snapshot.sh,test-orchestrate-batch-admit.sh,test-orchestrate-predispatch-review.sh,test-validate-state.sh,test-consumer-freshness.sh`
  — all green, actual output reported.
- For each edited script, a direct invocation of the stale/failure path (or the nearest reachable
  probe) shows the emitted remedy now contains `600000` and still contains `deploy-headless.sh`.
- `git log --oneline -1` confirms this batch landed as its own commit.

---

### Phase 7: Convert Batch B — Verification-Path Call Sites [NOT STARTED]

**Goal**: the verification path's emission sites route through the helper, including the two
scripts that need a new own-dir expression, with FINDING text held byte-identical.

**Tasks**:
- [ ] Take Phase 1's batch-B assignment as authoritative; correct this phase's file list against
      it before editing.
- [ ] **Re-read and re-locate every site by TEXT immediately before editing.**
- [ ] `verify-deploy.sh` — **has no own-dir expression** (verified). Add a sibling-lib-relative
      one (`$(dirname "${BASH_SOURCE[0]}")`) plus the guarded source. **MUST NOT** add a
      `"$SCRIPT_DIR/../.."` repo-root computation, which would newly incur
      `regeneration-is-manual-only.md`'s Root-Resolution Guard obligation. Then convert all its
      IN sites:
      - the `Run: bash deploy-headless.sh $TARGET` line (observed `:190`);
      - the `fail "$rel is missing" "run deploy-headless.sh to regenerate"` remediation (observed
        `:310`) — the remedy is already argument **2**, which never reaches a FINDING line;
      - the two `fail "... (run deploy-headless.sh first)"` calls (observed `:647`, `:681`) —
        pass the remedy as a **new second argument** and leave the first argument byte-identical,
        because `fail()` builds `FINDING $CURRENT_GATE $1` from argument 1 only and the redeploy
        checkpoint compares FINDING text across its pre/post snapshots.
- [ ] `check-deploy-freshness.sh` — resolves its own directory as `_CDF_SCRIPT_DIR` and already
      sources `lib/deploy-freshness-lib.sh` through it; follow that exact pattern for the new lib.
      Convert both WARN remedy lines (observed `:95`, `:126`). **Preserve the two-space line
      prefix** and add no new `^WARN:` line — `test-deploy-freshness.sh` asserts exactly one.
- [ ] `check-extension-docs.sh` — already sources `deploy-root-guard.sh` via
      `$(dirname "${BASH_SOURCE[0]}")`; follow that pattern. Convert the six deploy advisories
      (observed `:322`, `:337`, `:452`, `:459`, `:658`, `:713`). **Do not** touch the two Rule R
      remedies naming `generate-context-line-counts.sh` — OUT by rule O4.
- [ ] `bash -n` every edited script immediately after editing it.
- [ ] **Commit this batch separately** before Phase 8 begins.
- [ ] No task-number references in any edited file.

**Timing**: 1.25 hours

**Depends on**: 6

**Verification Tier**: interface

**Tier Justification**: `verify-deploy.sh` and `check-extension-docs.sh` are the verification
path's own entry points and their emitted text is parsed by enumerated direct dependents
(`lib/deploy-baseline-lib.sh`'s `deploy_findings_snapshot` FINDING grep, and gate 3's advisory
accounting), so the covering check is those dependents exercised directly:
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow /home/benjamin/.config/nvim`
plus `bash agent-system/extensions/core/scripts/check-extension-docs.sh` plus
`run-all.sh --only test-deploy-freshness.sh,test-verify-deploy-gate-selection.sh,test-verify-deploy-context-budget.sh`.

**Scope Hypothesis**: this plan hypothesizes batch B as `verify-deploy.sh` (4 IN sites at the
observed lines), `check-deploy-freshness.sh` (2), and `check-extension-docs.sh` (6), and asserts
that `verify-deploy.sh` has no own-dir expression while the other two already resolve their own
directory, and that `fail()` derives its FINDING line from argument 1 only (observed `:242-253`)
— all re-derived at plan-authoring time. Confirm each by `grep -n` and by re-reading `fail()`
before editing; Phase 1's batch assignment supersedes this list.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - new sibling-lib-relative own-dir expression (no repo-root computation) + guarded source; four IN sites routed through the helper, with the two `fail` calls taking the remedy as a new argument 2 so FINDING text stays byte-identical
- `agent-system/extensions/core/scripts/check-deploy-freshness.sh` - guarded source via the existing `_CDF_SCRIPT_DIR` pattern; both WARN remedy lines routed through the helper, two-space prefix and single `^WARN:` line preserved
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - guarded source; seven deploy advisories routed through the helper (Phase 1's enumeration found a 7th IN site at the closing summary block, `:1669-1671`, beyond the plan's original 6-site hypothesis), the two Rule R remedies untouched
- `agent-system/extensions/core/scripts/check-record-versioning.sh` - guarded source; the "Redeploy core..." stale-library-API remedy routed through the helper (new IN site, found only by Phase 1's secondary case-insensitive sweep, not present in any prior hypothesis)

**Verification**:
- `bash -n` clean on every edited script.
- `git diff` confirms every `verify-deploy.sh` `fail` call's **first** argument is unchanged.
- Idiom A: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --findings /home/benjamin/.config/nvim`
  — the FINDING line set is identical to a pre-edit baseline captured at the start of this phase.
- Idiom A: `bash agent-system/extensions/core/scripts/check-extension-docs.sh` — no NEW advisory
  relative to a pre-edit baseline captured at the start of this phase.
- Idiom A: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-freshness.sh,test-verify-deploy-gate-selection.sh,test-verify-deploy-context-budget.sh`
  — all green, with the exactly-one-`^WARN:` and `deploy-headless.sh`-substring assertions named.
- `git log --oneline -1` confirms this batch landed as its own commit.

---

### Phase 8: Convert Batch C — Orchestrator-Critical Call Sites, Last [NOT STARTED]

**Goal**: the commit, lock, dispatch and loop machinery routes through the helper, converted last
and committed per file, after the helper has been proven in Phases 2, 6 and 7.

**Tasks**:
- [ ] Take Phase 1's batch-C assignment as authoritative; correct this phase's file list against
      it before editing.
- [ ] **Re-read and re-locate every site by TEXT immediately before editing.** Re-confirm that the
      helper is present in the tree and that its own suite is green before touching any file in
      this batch.
- [ ] **Commit per FILE in this phase, not per batch** — a stricter granularity than Phases 6 and
      7, because a broken edit here halts the machinery that would otherwise commit the fix. After
      each file: `bash -n`, then a direct smoke probe of that script's own happy path, then commit.
- [ ] `skill-base.sh` — **has no own-dir expression**, but already sources `lib/common.sh` via
      `$(dirname "${BASH_SOURCE[0]}")/lib/common.sh` inside a guarded `elif` chain (verified);
      extend that existing chain rather than introducing a parallel resolver. Convert the
      stale-extension WARN remedy (observed `:460`).
- [ ] `task-lock.sh` — already defines `SCRIPT_DIR`. Convert the stale-deploy remedy (observed
      `:244`), which today is byte-identical to the batch-A boilerplate, so it is a
      `redeploy_remedy()` candidate.
- [ ] `orchestrate-build-dispatch.sh` — already defines `SCRIPT_DIR`. Convert the
      `deploy_freshness_context` remedy (observed `:393`). This is the highest-value site in the
      inventory: the string is composed into a dispatch file an agent reads as prompt context.
- [ ] `orchestrate-cycle-plan.sh` — already defines `SCRIPT_DIR`. Convert the
      `REDEPLOY CHECKPOINT WARNING: ... redeploy manually, then re-run /orchestrate` line
      (observed `:977`), which is IN by Decision 2's tie-break.
- [ ] `command-gate-out.sh` — **has no own-dir expression** (verified). Convert only the
      occurrences Phase 1 classified IN; its three post-deploy report lines (observed `:226`,
      `:241`, `:275`) are to be taken from Phase 1's O5-versus-tie-break verdict, not pre-decided
      here. If all three are OUT, this file drops from the batch and that is recorded, not treated
      as a miss.
- [ ] `deploy-headless.sh` — **has no own-dir expression** (verified). Convert the
      `[deploy-headless] Remedy: run '...' IN EACH stale repo` line (observed `:480`). Note this
      file's header was already edited in Phase 4; keep the two hunks distinct.
- [ ] For each file needing a new own-dir expression, add a sibling-lib-relative one only — **never**
      a `"$SCRIPT_DIR/../.."` repo-root computation.
- [ ] No task-number references in any edited file.

**Timing**: 1.5 hours

**Depends on**: 7

**Verification Tier**: full

**Tier Justification**: these six scripts are the executing orchestration's own commit, lock,
dispatch-composition and cycle-planning machinery, so a break is not observable through any single
suite or module build — the cross-cutting surface is "this orchestration can still lock, commit,
compose a dispatch, and plan a cycle," which only the complete gate set exercises.

**Scope Hypothesis**: this plan hypothesizes batch C as `skill-base.sh:460`, `task-lock.sh:244`,
`orchestrate-build-dispatch.sh:393`, `orchestrate-cycle-plan.sh:977`, `command-gate-out.sh` (0-3
sites, pending Phase 1's verdict) and `deploy-headless.sh:480`; and asserts that `skill-base.sh`,
`command-gate-out.sh` and `deploy-headless.sh` lack an own-dir expression while the other three
define `SCRIPT_DIR` — all re-derived at plan-authoring time. Phase 1's recorded batch assignment
supersedes this list; confirm each script's resolution by `grep -m1 'SCRIPT_DIR=\|BASH_SOURCE'`
before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - new lib added to the existing guarded `lib/common.sh` source chain; stale-extension WARN remedy routed through the helper
- `agent-system/extensions/core/scripts/task-lock.sh` - guarded source; stale-deploy remedy routed through the helper
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - guarded source; `deploy_freshness_context` remedy routed through the helper
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - guarded source; both redeploy-checkpoint failure remedies routed through the helper (`:977` and a second site at `:1147` found by Phase 1's secondary sweep, not in the plan's original single-site hypothesis)
- `agent-system/extensions/core/scripts/command-gate-out.sh` - DROPPED from this batch: Phase 1's enumeration found zero IN sites in this file (all candidate lines are O5 result-only reports with no reader action named), resolving the dispatch brief's explicitly-flagged "deliberately undecided" point; not edited
- `agent-system/extensions/core/scripts/deploy-headless.sh` - new sibling-lib-relative own-dir expression + guarded source; stale-consumer remedy routed through the helper
- `agent-system/extensions/core/scripts/deploy-root-guard.sh` - new IN site found by Phase 1 (not in any prior hypothesis); already has its own `BASH_SOURCE`-relative dir resolution (`__guard_dir`), reused for the sibling-lib lookup; guarded source; the bogus-root-guard remedy routed through the helper. Reclassified into Batch C (not B) for its universal sourcing breadth — effectively every core script, including several other Batch-C members, sources it at startup
- `agent-system/extensions/core/scripts/update-task-status.sh` - new IN site found by Phase 1 (not in any prior hypothesis); already defines `SCRIPT_DIR`; guarded source; the deploy-check-stale remedy routed through the helper. Orchestrator-critical: this script performs every postflight status transition

**Verification**:
- `bash -n` clean on every edited script, checked immediately after each file's edit.
- Per-file smoke probe before its commit: `skill-base.sh` sourced and a lifecycle function
  resolved; `task-lock.sh` acquire-and-release round trip; `orchestrate-build-dispatch.sh`
  `--help` or dry-run path; `orchestrate-cycle-plan.sh --dry-run` (mutates nothing, per
  `commands/orchestrate.md`'s dry-run short-circuit); `command-gate-out.sh` usage path;
  `deploy-headless.sh --dry-run`.
- `git log --oneline -6` shows one commit per file, not one batch commit.
- Idiom A: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-skill-base-lifecycle.sh,test-task-lock-liveness.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-cycle-plan.sh`
  — all green, actual output reported.
- The complete gate set, per this phase's `full` tier: Idiom B,
  `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`, run to
  completion with every finding clean or attributed.

---

### Phase 9: Re-Establish Assertion Coverage Against the Final Site List [NOT STARTED]

**Goal**: establish exactly which test assertions exist against the **final** site list — not the
list the task description or any briefing assumed — and run every suite that covers a converted
site.

**Tasks**:
- [ ] Take Phase 1's recorded inventory as the final site list. For **each** IN site, search the
      test tree for an assertion naming it or its emitted text:
      `grep -rn "<distinctive substring>" agent-system/extensions/core/scripts/tests/`.
- [ ] Record, per site, whether coverage exists and what exactly it asserts. Widening scope brings
      newly-covered sites into play that no prior analysis examined — this step establishes the
      truth rather than extrapolating from the two assertions already known.
- [ ] Re-confirm the two assertions already established, by name and current behavior:
      `test-orchestrate-build-dispatch.sh`'s stale-fixture
      `assert_contains "$content" "deploy-headless.sh"`, and `test-deploy-freshness.sh`'s pair
      (exactly one `^WARN:` line; the `deploy-headless.sh` substring). Confirm the corrected
      attribution holds — `test-deploy-freshness.sh` exercises `check-deploy-freshness.sh`, not
      `verify-deploy.sh` — and that `verify-deploy.sh`'s sites still have no suite asserting on
      them by name.
- [ ] Resolve the covering suite set mechanically rather than by hand: run
      `suite_selection_select` from `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`
      over every path this plan touched, and use its output as the suite list.
- [ ] Run that resolved suite set (Idiom A, in `--only` subsets sized to stay under 540s each).
- [ ] Record any site that is IN but has **no** assertion as a named gap in the Phase 1 inventory
      subsection — a recorded finding for a future task, not new test-writing in this task.
- [ ] If any assertion required updating, **argue the update** in the test's own comment rather
      than editing it mechanically. The acceptance criterion requires this.

**Timing**: 1 hour

**Depends on**: 1, 8

**Verification Tier**: local

**Tier Justification**: this phase edits at most test comments and one markdown subsection, with
no production-code change, and its own work product is the suite run itself:
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the suite_selection_select-resolved set>`.

**Scope Hypothesis**: this plan asserts exactly two assertions exist today against any emission
site (`test-orchestrate-build-dispatch.sh:668` and `test-deploy-freshness.sh:149`+`:151`) and that
`verify-deploy.sh`'s sites have none — re-derived at plan-authoring time by grepping the test tree.
This phase's own per-site search over the final list is the confirmation step and supersedes that
count.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - per-site assertion-coverage column added to the inventory table; uncovered IN sites recorded as a named gap
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` - only if an assertion genuinely required updating, with the update argued inline
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - only if an assertion genuinely required updating, with the update argued inline
- `agent-system/extensions/core/index-entries.json` - `line_count` resynced

**Verification**:
- Every IN site in the inventory carries an assertion-coverage verdict; none is blank.
- Idiom A: the `suite_selection_select`-resolved suite set runs green, in `--only` subsets, with
  actual output reported per subset.
- Both named suites green, with their specific assertions named in the report.
- `git diff` on the two test files is empty, or each hunk carries an inline argument for why it
  changed.
- `wc -l` on the edited markdown equals its new `index-entries.json` `line_count`.

---

### Phase 10: Redeploy, Full Gate Set, Attribution [NOT STARTED]

**Goal**: the source-store edits are deployed, the full `verify-deploy.sh` gate set has been run
and observed, and every residual failure is attributed rather than absorbed.

**Tasks**:
- [ ] Resync line counts and confirm nothing moved:
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`, then
      `git diff -- agent-system/extensions/core/index-entries.json`.
- [ ] **Redeploy** (Idiom A, tool `timeout` `600000`):
      `timeout 540 bash .claude/scripts/deploy-headless.sh >"$LOGDIR/deploy.log" 2>&1; rc=$?`,
      then `echo "EXIT=$rc"; tail -60 "$LOGDIR/deploy.log"`. Record wall-clock. Exit `3` is a
      landed deploy, not a failure (see `regeneration-is-manual-only.md`'s
      "`deploy-headless.sh`'s Inline Verification and Exit Code 3"); exits `1`/`2` are not landed.
      On `rc=124`, the inner bound fired — re-check whether the deploy landed before re-running.
- [ ] Confirm the new lib and the converted scripts reached the deployed tree:
      `ls .claude/scripts/lib/redeploy-remedy-lib.sh` and
      `grep -l "redeploy_remedy" .claude/scripts/*.sh`.
- [ ] **Run the full gate set** (Idiom B — gate 8 nests `run-all.sh`, so a full battery pays both
      and can exceed 540s; the orchestrator measured one full run at 6m32s, cited only as the
      reason Idiom B is required, not as a figure to report):
      `nohup bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim >"$LOGDIR/gates.log" 2>&1 & echo $! > "$LOGDIR/gates.log.pid"`
      followed by the bounded `kill -0` wait, re-issued as many times as needed. Never end the
      turn, never arm a `Monitor`, never `run_in_background`.
- [ ] Run both named suites explicitly and report their actual output (Idiom A):
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-deploy-freshness.sh,test-redeploy-remedy-lib.sh`.
- [ ] **Attribute every residual failure**, do not absorb it. Expected, pre-classified:
      `test-four-tier-conflict.sh` Case 6 (known `[1000ms,2000ms)` timing flake measuring
      ~2.3-2.8s under concurrent load — attribute, do not investigate); the completion-deploy gate
      refusing completion while deployed `core` is stale (resolved by the next cycle's redeploy
      checkpoint — do not work around); `check-record-versioning.sh`'s "ignored null byte in
      input" stderr noise from scanning binary files (cosmetic, verified to drop no findings). Any
      failure NOT on this list is investigated and either fixed or recorded with evidence.
- [ ] Reconcile the measured `deploy-headless.sh` wall-clock against the runtime note Phase 4
      wrote; correct the note if they disagree.
- [ ] Confirm no task-number reference landed under `agent-system/**`
      (`bash .claude/scripts/check-task-references.sh`, or gate 4 inside the full set).

**Timing**: 1.5 hours

**Depends on**: 5, 9

**Verification Tier**: full

**Scope Hypothesis**: this phase carries one figure from the dispatching orchestrator — a full
`verify-deploy.sh` gate-set run clocked at 6m32s on this host — used only to justify Idiom B's
use, never reported as this task's own measurement. Confirm by this phase's own timing of the
full-gate run, and report that figure instead.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - final `line_count` resync if anything moved
- `agent-system/extensions/core/scripts/deploy-headless.sh` - runtime-note figure corrected if this phase's measurement disagrees with Phase 4's

**Verification**:
- The complete gate set: `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`
  run to completion via Idiom B, with its exit code and the full `FAIL`/`FINDING` list reported
  verbatim — every finding clean or attributed by name.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-deploy-freshness.sh,test-redeploy-remedy-lib.sh`
  green, with actual output reported.
- Deploy landed: exit `0`, `3`, or `4`, with the deployed-artifact count reported, and
  `.claude/scripts/lib/redeploy-remedy-lib.sh` present.
- Acceptance walk-through, each item answered with evidence: every IN emission site routes through
  the helper; Rule 1 states the obligation as a numbered requirement; all three ALSO RULE ON
  questions have a recorded ruling; both named suites green; the three-shapes distinction recorded
  and composing with the dispatched-subagent mandate; redeployed with residual failures
  attributed.

---

## Testing & Validation

- [ ] `test-redeploy-remedy-lib.sh` (new) green — both functions' output, the `deploy-headless.sh`
      substring, no line-initial `WARN:`, no trailing newline, double-source idempotence, and the
      degrade-safe fallback.
- [ ] `test-deploy-freshness.sh` green — BOTH STALE assertions named and confirmed: exactly one
      `^WARN:` line, and the `deploy-headless.sh` substring. Fixture carries the new lib.
- [ ] `test-orchestrate-build-dispatch.sh` green — its stale-fixture
      `assert_contains "$content" "deploy-headless.sh"` assertion named and confirmed.
- [ ] `test-lint-agent-contracts.sh` green (Check H unaffected — the generated-copy block untouched).
- [ ] Per-batch suite subsets in Phases 6, 7 and 8 all green or attributed.
- [ ] `bash -n` clean on every edited shell script, checked per file as it is edited.
- [ ] `verify-deploy.sh --findings` FINDING line set unchanged by the Phase 7 edits.
- [ ] `check-extension-docs.sh` produces no NEW advisory relative to a pre-edit baseline,
      including Rule R `line_count` truth.
- [ ] The `suite_selection_select`-resolved suite set for every touched path (Phase 9) green.
- [ ] Full `verify-deploy.sh` gate set run to completion, residual failures attributed.
- [ ] No task-number reference under `agent-system/**` (gate 4 / `check-task-references.sh`).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/redeploy-remedy-lib.sh` — NEW: the single definition
  of the redeploy-remedy text repo-wide.
- `agent-system/extensions/core/scripts/tests/test-redeploy-remedy-lib.sh` — NEW: the helper's own
  regression suite, including its degrade-safe fallback.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — the
  authoritative emission-site inventory: discriminator, five OUT rules, tie-break, per-occurrence
  table with verdicts and batch assignment, assertion-coverage column, deferred lint.
- `agent-system/extensions/core/context/patterns/external-process-wait.md` — Rule 1 restructured
  into numbered caller-agnostic requirements with the exit-124 step and the 3a/3b note.
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` — the tool-`timeout`
  pairing in prose; the shape taxonomy recorded.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — harness-initiated
  backgrounding named inside Local Long-Running Command Discipline.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — sub-case-3b note and a
  log-redirected `orchestrate-cycle-plan.sh` invocation shape.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` —
  cross-reference to the shape taxonomy.
- Every converted emission-site script under `agent-system/extensions/core/scripts/`, landed as
  three batch commits (Phases 6, 7) plus one commit per file (Phase 8).
- `agent-system/extensions/core/index-entries.json` — resynced `line_count` values.
- A redeployed `.claude/` tree and a completed full gate-set run.
- `specs/392_deliver_tool_timeout_half_of_bounded_wait_idiom/summaries/01_tool-timeout-remedy-delivery-summary.md`.

## Rollback/Contingency

The batch structure *is* the rollback design. Phases 6 and 7 each land as one commit, and Phase 8
lands one commit per file, so any single conversion is reverted with a `git revert` of exactly one
commit without disturbing the others. The helper itself (Phase 2) is additive — a new lib and a
new suite — so reverting every conversion leaves a dormant, tested, unused library rather than a
broken tree.

If a phase needs a defensive checkpoint before risky work, use
`bash .claude/scripts/git-snapshot.sh 392 --no-revert` (never the default reverting form as a
routine checkpoint). Reserve the default reverting `bash .claude/scripts/git-snapshot.sh 392` for
a genuine rollback scenario, per `context/contracts/recovery.md`'s rollback rung.

Four specific contingencies:

- **If the helper breaks an orchestrator-critical script** (`skill-base.sh`, `task-lock.sh`,
  `command-gate-out.sh`, `orchestrate-build-dispatch.sh`, `orchestrate-cycle-plan.sh`): this
  orchestration cannot commit, lock, compose a dispatch, or plan a cycle, and **recovery is by
  hand** — no automated path reaches back in, because the machinery that would run the recovery is
  the machinery that broke. The by-hand recovery is: revert that one file's commit with `git`
  directly (not through `git-commit-scoped.sh`, which routes through the broken machinery), or
  restore the file from `HEAD`, then re-run its smoke probe. Decision 1(c)'s degrade-safe guarded
  source exists so a *missing* lib cannot cause this; only a genuine syntax or logic error in the
  edit can, which is why Phase 8 commits per file and `bash -n`s each one immediately.
- **If a named test suite goes red on a conversion**, the fix is the helper's output, not the
  test: both known assertions are deliberately loose (a literal `deploy-headless.sh` substring,
  and a `^WARN:` line count). A red suite means the helper violated one of those two properties.
  Updating either assertion requires an argued justification per the task's acceptance — a
  mechanical test edit is not acceptable.
- **If the inventory turns out materially different from this plan's hypothesis**, Phase 1's
  recorded table wins and Phases 6-8's file lists are corrected to match. That is the designed
  outcome, not a deviation.
- **If the redeploy does not land** (`deploy-headless.sh` exit `1` or `2`), stop: do not
  hand-patch any file under `.claude/**` as a substitute, which would mask the divergence rather
  than fix it. Fix the deploy failure at its source, or close the phase `[PARTIAL]` with a handoff
  naming the concrete resume command.
