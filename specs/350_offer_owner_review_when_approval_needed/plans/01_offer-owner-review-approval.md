# Implementation Plan: Task #350

- **Task**: 350 - Offer the owner the review path when a books task reaches a point that needs an
  approval, instead of requiring the owner to know to run /approve
- **Status**: [IMPLEMENTING]
- **Effort**: 7.5 hours
- **Dependencies**: `add_approve_command_owner_labeled_approvals` (shipped; archived in this
  repository). `owner_labeled_agent_assisted_approvals` (Logos/Verification repository) owns
  `approve.sh`/`check-approvals.sh` — read-only inputs here, never edited by this task.
- **Research Inputs**: `specs/350_offer_owner_review_when_approval_needed/reports/01_offer-owner-review-approval.md`
- **Artifacts**: plans/01_offer-owner-review-approval.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The interaction plumbing this task is told to reuse is already complete: an agent sets
`user_decision` on `.return-meta.json`, `orchestrate-cycle-postflight.sh` forces
`verdict=ask_user` on field presence alone, and `skill-orchestrate`'s Move 3/Move 4 accumulate
and batch-relay it in the root session. This plan therefore adds no interaction machinery at all.
It adds one read-only recognizer that turns a component gate's approvals-stage red into a
correctly shaped `user_decision`, a books-domain record pinning the exact failure signature and
the rulings, and a thin cross-cutting instruction in the two books implementation agents telling
them to run the recognizer whenever they run a gate.

The detection seam is the **books agent definitions**, not postflight. Postflight reads only
`.return-meta.json`/the handoff plus a fixed set of artifact and git probes — it never sees a
dispatch's raw gate output, so it has structurally nothing to classify; and `user_decision` is
producer-owned by the agent that sets it, with every later writer required to relay it verbatim.
"Both" would mean postflight second-guessing a signal it cannot see.

The accepted option never auto-invokes `/approve`. It relays the exact `/approve <component>
[--task N]` line for the owner to type in their own next turn, reusing `push-consent-relay.md`'s
YES-mints-nothing design. That is the only mechanism that works (`/approve` is direct-execution
only; `AskUserQuestion` is withheld from every dispatched subagent) and it satisfies the
no-human-attached requirement by construction, backed independently by `skill-approve`'s own
Stage 2 refusal on `orchestrator_mode: true`.

### Research Integration

Four research findings are load-bearing here and are carried into the phases below:

1. **No change to `skill-orchestrate/SKILL.md`, `orchestrate-cycle-postflight.sh`, or
   `orchestrate-record-decision.sh`.** The relay is already generic. The task's originating
   `proposed_file_scope` named all three; that was a pre-research guess and research does not
   support touching any of them.
2. **No fixed hook exists in the books agents.** `books-implementation-agent.md` Stage 5 runs
   `lake build`, `books-tool validate`/`check`, and (conditionally) the certify driver's
   `--check`; the advisory `books-gate.sh --gate` tier has only a layer-lint leg and a
   `Books.Meta` closure leg and **no approvals leg at all**. The fail-closed component gate is
   plan-directed, not a numbered stage. So the new instruction is worded as a cross-cutting rule
   ("whenever a step in this dispatch runs a component gate"), not as a Stage 5 sub-step.
3. **Decline and defer need no new state.** Nothing today can turn an absent-or-stale record
   green as a side effect of answering a `user_decision`; `.decisions.json` is informational and
   is read by no guard or gate. Honest-red is the do-nothing outcome. The real risk is a *future*
   implementer adding a `.decisions.json`-reading shortcut, so the prohibition is written down
   explicitly rather than left implicit.
4. **The signature gap research flagged is now closed.** Research could not read
   `check-approvals.sh` (separate repository) and correctly refused to guess, warning that "any
   non-zero exit from the gate" would misclassify ordinary build/proof failures. During planning
   both scripts were found locally and read, so Phase 1 pins the literal signature from source.
   See Decisions below for what was found.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Recognize, from a component gate's own output, the specific failure mode "approval records are
  absent or stale" and distinguish it from every other way that gate can go red.
- Emit a correctly shaped `user_decision` carrying three options — enter review now, defer,
  decline — with the semantics the task requires, and let the existing Move 3/Move 4 relay do all
  the asking.
- Record the detection-seam ruling **with its reason**, and the pinned signature, in a
  books-domain context record a future reader can check.
- Prove by test that declining leaves the requirement intact, that non-approval gate failures are
  not misclassified, and that no path self-answers or auto-invokes `/approve`.

**Non-Goals**:

- `/approve` itself, its artifact paths, its summary contract, its step-through UX.
- `approve.sh` and `check-approvals.sh` (Logos/Verification repository). Read-only inputs here.
- Any policy question about which specifications deserve scrutiny.
- Any new prompting channel, state file, root-session relay, or second `AskUserQuestion` path.
- `books-research-agent.md` / `books-research-hard-agent.md`: research dispatches do not run
  build or gate commands in the current contract, so the rule is not wired into them.

## Decisions

Recorded here so the phases below do not have to re-argue them.

**D1 — Detection seam: the books agent definitions, not postflight, and not both.** Reason, which
is the durable part: postflight's verdict derivation is a flat lookup from the agent's own
reported `status` string and has no access to a dispatch's raw command output, so
"postflight classification" presupposes a signal postflight does not have; and
`user-decision-contract.md` makes `user_decision` producer-owned, requiring every later writer to
leave it untouched — a postflight-side classifier that *originated* one would be the orchestrator
deciding what counts as an approval need, the exact inversion the contract's opening sentence
rules out. "Both" collapses to "agent only" plus redundant machinery.

**D2 — The pinned signature** (read from
`/home/benjamin/Projects/Logos/Verification/components/framed_channel/`, 2026-10-17):

- `check.sh` runs the approvals stage **last**, under an `== approvals ==` header, and on failure
  prints the literal line `check.sh: FAIL at the final stage, approvals; every earlier stage
  passed`, then exits 1. That line is the stage attribution.
- `check-approvals.sh` exits `0` current, `1` "a record is absent or stale", `2` usage error or
  missing prerequisite. **Exit 1 alone is not the signal** — it also covers a malformed approvals
  file, a `spec-check.sh` failure, record-consistency errors, and the `--require-person` policy
  refusal. The distinguishing marker is the message text, all of it on **stdout** (its `fail()`
  helper and the absent-file branch both `echo` without redirection; usage errors go to stderr).
- **The absent-or-stale class — six message families, treated as "a person needs to approve":**
  1. `[FAIL] approvals: <file> does not exist. No selection or specification has been approved.`
  2. `[FAIL] approvals: no selection record (the selection has not been approved)`
  3. `[FAIL] approvals: the selection is stale: the Rust changed since it was approved (source_sha256 recorded …`
  4. `[FAIL] approvals: the selection is stale: the candidate set changed since it was approved (candidates_sha256 recorded …`
  5. `[FAIL] approvals: the specification <M> is stale: it changed since it was approved (spec_digest recorded …`
  6. `[FAIL] approvals: no specification record for <M> (its current spec_digest is <D>): it has not been approved`
- **Deliberately excluded** (same stage, same exit 1, but "something is broken" or a policy
  refusal, not "someone needs to approve"): malformed `by`/`approver`/`confirmed_via`/
  `assisted_by` records; `is both selected and declined`; `is listed more than once`;
  `is neither selected nor declined`; `is selected or declined but is not an in-subset candidate`;
  `selected, but no registered statement is about it`; `specified … but not selected`;
  `declined … has an empty reason`; `names <M>, which is not a Challenge module`;
  `SpecCheck reports no digest for it`; `the approvals file does not have the recorded shape`;
  `spec-check.sh failed`; and every exit-2 usage/prerequisite path.
- **`--require-person` is excluded, with its reason stated**: `[FAIL] approvals: <what> was
  approved by an agent (<approver>), and --require-person is set` genuinely does mean a person
  must approve, but the records are present and current, so it is not the absent-or-stale mode
  this task is scoped to ("that specific failure mode"). Excluding it is a scoping decision, not
  an oversight; it is recorded in the context record as a candidate follow-up rather than
  silently folded in.
- **Mixed reds are honest, not suppressed**: the classes are not mutually exclusive. When an
  absent-or-stale family matches *and* an excluded family also matches, the offer is still made
  (the approval need is real) and the `question` says plainly that other approvals failures are
  present too, so the owner is not misled into thinking review alone turns the leg green.

**D3 — Detection is a read-only recognizer script, not prose alone.** The acceptance bar demands
"demonstrated, not asserted" and two more "with a test" clauses. A prose-only rule in an agent
definition cannot be tested. A small recognizer — reads captured gate output, writes nothing,
prompts nothing, emits either one `user_decision` object or nothing — makes every acceptance
clause a fixture test while keeping the agent instruction thin. It is detection and shaping only;
it is not interaction machinery (no prompt, no state file, no relay, no `AskUserQuestion`), so it
does not trip the dispatch's KEEP IT MODEST constraint.

**D4 — The recognizer lives in the books extension.** Its consumers are the books implementation
agents, the books extension already owns `books-gate.sh` and its test suite, and a books dispatch
must be able to run it whenever `books` is loaded. The approvals extension owns `/approve`'s own
flow, which is out of scope.

**D5 — `user_decision` shape: `blocking: false`, `recommended` = the defer option.** "Enter review
now" cannot be a silent default: nothing can act on it without the owner's own keystroke, so
recommending it non-blockingly would be procedurally meaningless. "Decline" must never be chosen
for the owner — the honesty requirement reads as "the owner must affirmatively decline". "Defer"
is the one option that is free to take as a default: fully reversible, costs nothing, and matches
`user-decision-contract.md`'s own description of `blocking: false`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A future implementer reads `.decisions.json` and treats a recorded "decline"/"defer" as grounds to suppress, waive, or downgrade the requirement | H | M | Write the prohibition explicitly in the context record, in the agent instruction, and as a test asserting the recognizer still emits the same offer after a recorded decline (Phase 3) |
| The six-family predicate drifts when the external `check-approvals.sh` changes its message text | M | M | Pin the exact strings with their source and read date in the context record; the fixture suite's inputs are copies of the real message lines, so a drift surfaces as a failing recognition case rather than as a silent miss |
| Over-broad matching misclassifies an ordinary build/proof/record failure as an approval request | H | L | The predicate is the six families, never the exit code; the suite carries explicit negative cases for every excluded family (Phase 3) |
| The relayed option names `/approve` in a repository where the approvals extension is not deployed, handing the owner a command that does not exist | M | M | The recognizer probes for the deployed `/approve` surface and otherwise names the component's own `approve.sh --review`/`--record` lines — the same commands `check-approvals.sh` already prints itself. One bounded conditional; duplicates no review logic |
| A test that would pass against a stubbed predicate proves nothing | H | M | The books corpus's forgery-probe discipline applies: every predicate in the new suite carries a probe that stubs it out and asserts the expectation then fails (`standards/forgery-probe-discipline.md`, and `test-books-gate.sh` as the shape precedent) |
| Sibling task 396 is dispatched this same cycle on this same tree | L | L | Its declared file scope is three lean-extension files; this task touches only `extensions/books/**`. Re-read before editing, stage explicit file lists only, never a directory or glob add, never `git-snapshot.sh` in its reverting default mode |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1, 2 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Pin the Signature and the Rulings in a Books-Domain Record [COMPLETED]

**Goal**: A durable, checkable record of D1's ruling *with its reason*, D2's pinned signature, the
three options and their semantics, the no-human ruling, the hand-off design, and the
never-suppress prohibitions — so no later reader has to re-read an external repository's scripts
or re-derive why the seam was chosen.

**Tasks**:

- [x] **Step 1.1:** *(completed)* Create `agent-system/extensions/books/context/project/books/domain/approvals-detection.md`
  with these sections: the ruling and its reason (D1); the pinned signature (D2) as a table of the
  six recognized families and a second table of the excluded families each with its reason,
  naming the source files, the repository, and the 2026-10-17 read date; the stage-attribution
  line; the stdout-not-stderr detail; the three options with their exact semantics; the
  `blocking: false` / `recommended = defer` ruling (D5); the hand-off design (the relayed command
  line, never an auto-invocation) with its three independent reasons; the no-human ruling and its
  mirror in `skill-approve`'s Stage 2; and an explicit **MUST NOT** block: a recorded decline or
  defer is never read by any check as evidence that the requirement is satisfied, waived, or
  downgraded; declining leaves the records absent-or-stale and the gate leg red; deferring does
  not consume the need, which is raised again on the next run that hits the same red.
  - **Files:** `agent-system/extensions/books/context/project/books/domain/approvals-detection.md` (new)
- [x] **Step 1.2:** *(completed)* Add the approvals leg to `domain/gate-tiers.md`: extend the `full-gate.sh`
  tier's **Checks** row to name the approvals stage (`check.sh` runs it last, via the component's
  `check-approvals.sh`) and add a `Related` pointer to the new record. This closes the gap
  research named — `gate-tiers.md` today documents every tier's checks in detail and does not
  mention an approvals leg at all.
  - **Files:** `agent-system/extensions/books/context/project/books/domain/gate-tiers.md`
- [x] **Step 1.3:** *(completed)* Register the new record: add a `project/books/domain/approvals-detection.md`
  entry to `agent-system/extensions/books/index-entries.json` (`on_demand: true`, empty
  `load_when`, matching the shape of the `gate-tiers.md` / `known-gap-register.md` entries, with
  an accurate `line_count`), and add its row to the navigation table in
  `context/project/books/README.md`.
  - **Files:** `agent-system/extensions/books/index-entries.json`,
    `agent-system/extensions/books/context/project/books/README.md`
- [x] **Step 1.4:** *(completed)* Re-read both edited files immediately before staging (sibling dispatch active
  this cycle), then commit with an explicit file list.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: D2 asserts six recognized message families and thirteen excluded ones, read
from `check-approvals.sh` on 2026-10-17. Confirm at implementation time by re-reading
`/home/benjamin/Projects/Logos/Verification/components/framed_channel/scripts/check-approvals.sh`
and recounting both sets; if the counts differ, the record states the counts actually found, not
these.

**Tier Justification**: Every touched path is source-store markdown or a JSON index entry with no
executable surface, so `suite_selection_select` returns `__FULL_SWEEP__` (sub-case b): the
covering check is `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim/agent-system`
plus the `prose` row's diff read-through.

**Files to modify**:

- `agent-system/extensions/books/context/project/books/domain/approvals-detection.md` - new record
- `agent-system/extensions/books/context/project/books/domain/gate-tiers.md` - approvals leg in the
  `full-gate.sh` Checks row; `Related` pointer
- `agent-system/extensions/books/index-entries.json` - new context entry
- `agent-system/extensions/books/context/project/books/README.md` - navigation row

**Verification**:

- `verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` passes (doc-lint, task-reference
  lint) and neither gate reports SKIP for the touched paths.
- `python3 -c "import json; json.load(open('agent-system/extensions/books/index-entries.json'))"`
  succeeds, and the new entry's `line_count` equals `wc -l` of the new record.
- Diff read-through confirms every hunk is prose or a JSON index entry.
- The record contains the ruling's **reason**, not only its choice, and contains the explicit
  never-suppress MUST NOT block.

---

### Phase 2: The Read-Only Recognizer [COMPLETED]

**Goal**: One script that reads a captured component-gate run's output and emits either a single
correctly shaped `user_decision` object or nothing — writing nothing, prompting nothing, invoking
nothing.

**Tasks**:

- [x] **Step 2.1:** *(completed)* Create `agent-system/extensions/books/scripts/books-approvals-signal.sh`.
  Usage: `books-approvals-signal.sh --gate-output FILE --component NAME [--task N]
  [--gate-exit N]`. Header comment states READ-ONLY, names the source record from Phase 1, and
  states the exit contract: `0` an approval-need signal was recognized and the JSON object is on
  stdout; `1` no approval-need signal (the normal outcome for a green gate or any other red);
  `2` usage error or an unreadable `--gate-output`. House shell conventions apply (`set -uo
  pipefail` per the books suite precedent; see `context/standards/shell-strict-mode.md`).
  - **Files:** `agent-system/extensions/books/scripts/books-approvals-signal.sh` (new)
- [x] **Step 2.2:** *(completed)* Implement the predicate exactly as D2 pins it: match the six absent-or-stale
  families against the captured output; never key on the exit code alone. Record, in the emitted
  object's `question`, which families matched, the component, and the task scope when `--task` was
  given. Detect the stage-attribution line (`check.sh: FAIL at the final stage, approvals`) and
  use it as corroboration only — a direct `check-approvals.sh` invocation never prints it, so its
  absence must not suppress a recognized signal.
- [x] **Step 2.3:** *(completed)* Implement the mixed-red honesty rule: when an excluded family also matches,
  still emit, and add one clause to `question` naming that other approvals failures are present,
  so review alone will not turn the leg green.
- [x] **Step 2.4:** *(completed)* Emit the object in `user_decision`'s exact schema — `question`, `options`
  (three flat self-describing strings), `recommended`, `blocking` — with `blocking: false` and
  `recommended` set verbatim to the defer option (D5). Option strings follow
  `push-consent-relay.md`'s worked-example shape, for example:
  `"Enter review now — run /approve <component> --task <N> yourself in your next turn"`,
  `"Defer — ask again on the next run that hits this red"`,
  `"Decline — leave <component>'s approval records as-is; the gate leg stays red"`.
- [x] **Step 2.5:** *(completed)* Implement the one bounded fallback: when the deployed `/approve` surface is
  absent (no `commands/approve.md` and no `scripts/approve-paths.sh` in the resolved `.claude/`
  tree), the first option instead names the component's own
  `approve.sh --review …` / `approve.sh --record …` lines — the same commands
  `check-approvals.sh`'s own absent-file branch already prints. No review logic is duplicated
  either way.
- [x] **Step 2.6:** *(completed)* Assert the prohibitions in the script itself: no write to any path, no
  invocation of `approve.sh`, `/approve`, `check-approvals.sh`, or the gate; no `AskUserQuestion`;
  no read of `.decisions.json`. State each as a header comment so a later editor sees the
  constraint at the point of temptation.
- [x] **Step 2.7:** *(completed)* Register the script in `agent-system/extensions/books/manifest.json` under
  `provides.scripts`, alongside `books-gate.sh`.
  - **Files:** `agent-system/extensions/books/manifest.json`
- [x] **Step 2.8:** *(completed)* `chmod +x` the script; confirm `bash -n` and `shellcheck` are clean; re-read
  `manifest.json` immediately before staging; commit with an explicit file list.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash -n` plus `shellcheck` on the single new script, and a JSON parse of
`manifest.json`, is the complete covering check — the script is standalone, is called by nothing
yet (Phase 4 wires it), and adds no symbol any other script sources.

**Files to modify**:

- `agent-system/extensions/books/scripts/books-approvals-signal.sh` - new recognizer
- `agent-system/extensions/books/manifest.json` - `provides.scripts` entry

**Verification**:

- `bash -n` and `shellcheck` clean on the new script.
- A hand-run against a fixture containing family 6's line emits one JSON object parseable by `jq`,
  with exactly three `options`, `blocking: false`, and `recommended` byte-equal to the defer
  option; exit 0.
- A hand-run against a fixture containing only an excluded family's line emits nothing; exit 1.
- `python3 -c "import json; json.load(open('agent-system/extensions/books/manifest.json'))"`
  succeeds and the new path appears in `provides.scripts`.

---

### Phase 3: Behavioural Fixture Suite, with Forgery Probes [COMPLETED]

**Goal**: Turn every acceptance clause that can be tested into a passing, non-forgeable test.

**Tasks**:

- [x] **Step 3.1:** *(completed)* Create `agent-system/extensions/books/scripts/tests/test-books-approvals-signal.sh`
  following `test-books-gate.sh`'s shape: inline `mktemp -d` fixtures, no dependency on any real
  `specs/` tree or on the external repository, Class B PASSED/FAILED-counter harness that reports
  every case rather than aborting on the first failure.
  - **Files:** `agent-system/extensions/books/scripts/tests/test-books-approvals-signal.sh` (new)
- [x] **Step 3.2:** *(completed)* Positive recognition: one case per recognized family (D2's list), each fixture
  holding the real message line, asserting exit 0 and a `jq`-parseable object.
- [x] **Step 3.3:** *(completed)* Negative non-recognition: one case per excluded family, plus a green-gate
  fixture, plus an exit-2 usage-error fixture, plus a `--require-person` fixture — each asserting
  exit 1 and empty stdout. This is the case set that proves an ordinary build, proof, or record
  failure is never offered as an approval request.
- [x] **Step 3.4:** *(completed)* Shape assertions: exactly three options; `blocking` is `false`; `recommended`
  is byte-equal to the defer option; the component name, and the task scope when `--task` was
  given, appear in the option text; and the `/approve`-absent fallback names the component's own
  `approve.sh` lines instead.
- [x] **Step 3.5:** *(completed)* **Decline leaves the requirement intact** (the acceptance clause). Fixture: a
  recorded decline answer in a stand-in `.decisions.json` next to the fixture gate output.
  Assert (a) the recognizer emits the same offer on the next run — a decline does not consume or
  suppress the need; (b) the recognizer never reads that file (stub it unreadable and assert the
  behaviour is unchanged); (c) nothing under the fixture tree was created, modified, or deleted by
  the run, compared by a before/after digest of the whole fixture directory. Same three
  assertions, re-run with a recorded defer answer, for the defer semantics.
- [x] **Step 3.6:** *(completed)* **No self-answering** (the acceptance clause): assert the recognizer's own
  source contains no invocation of `approve.sh`, `/approve`, `check-approvals.sh`, `full-gate.sh`,
  `check.sh`, or `AskUserQuestion`, and no write redirection to any path outside stdout — so the
  only thing it can ever do is report.
- [x] **Step 3.7:** *(completed)* Forgery probes, per `standards/forgery-probe-discipline.md`: for each
  predicate the suite relies on (family matching, excluded-family rejection, the shape assertions,
  the read-only assertion), add a probe that stubs the predicate out and asserts that the suite's
  own expectation then FAILS. A suite that would pass against a stubbed predicate proves nothing.
- [x] **Step 3.8:** *(completed)* Register the suite in `manifest.json`'s `provides.scripts` as
  `tests/test-books-approvals-signal.sh`; confirm `run-all.sh` discovers it (the discovery engine
  scans `agent-system/extensions/*/scripts/tests/test-*.sh`).
  - **Files:** `agent-system/extensions/books/manifest.json`
- [x] **Step 3.9:** *(completed)* Run the suite to green; re-read `manifest.json` before staging; commit with an
  explicit file list.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: the case count follows D2's family counts (six positive, thirteen-plus
negative). Confirm at implementation time against the counts Phase 1 actually recorded, and write
one case per family actually found rather than per family listed here.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-books-approvals-signal.sh` is the complete covering check — the suite and the script it
exercises are the only files touched, and nothing else sources either.

**Files to modify**:

- `agent-system/extensions/books/scripts/tests/test-books-approvals-signal.sh` - new suite
- `agent-system/extensions/books/manifest.json` - test registration

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-books-approvals-signal.sh`
  passes, reporting a non-zero case count (a zero-case pass is a harness failure, not a pass).
- Every forgery probe is present and demonstrably fails when its predicate is stubbed.
- The decline and defer cases both assert the unchanged-fixture digest, not merely the exit code.

---

### Phase 4: Wire the Cross-Cutting Rule into the Books Implementation Agents [NOT STARTED]

**Goal**: Both books implementation agents recognize the condition at the point they run a gate,
shape their own return, and never self-answer — worded once, by reference, so a third agent
definition can adopt it without copy-paste drift.

**Tasks**:

- [ ] **Step 4.1:** Add the rule to `books-implementation-agent.md` as a cross-cutting
  instruction, sited near Stage 5's existing gate-tier guidance but worded to apply to *any*
  gate or check command the dispatch runs, plan-directed or fixed — because no fixed hook exists
  today and the fail-closed gate is plan-directed. The rule: capture the gate run's combined
  stdout and stderr to a file; run `books-approvals-signal.sh` over it; if an object comes back,
  copy it **verbatim** into `.return-meta.json`'s `user_decision` and mirror it into
  `.orchestrator-handoff.json` under the same key; report the gate red exactly as it is. Keep the
  rule short and point at Phase 1's record for the signature, the options, and the reasons.
  - **Files:** `agent-system/extensions/books/agents/books-implementation-agent.md`
- [ ] **Step 4.2:** Add the same rule, by reference to the same record, to
  `books-implementation-hard-agent.md`. Do not restate the signature in either agent file — the
  existing `--gate` advisory text is already duplicated verbatim across both, which is the drift
  precedent to avoid repeating.
  - **Files:** `agent-system/extensions/books/agents/books-implementation-hard-agent.md`
- [ ] **Step 4.3:** Add the prohibitions to both agents' MUST NOT lists: never invoke `/approve`
  or the component's `approve.sh` from inside a dispatch; never treat a recognized approval need
  as a verification pass, a waiver, or a downgrade; never answer the offer on the owner's behalf,
  pick a default, auto-defer, or auto-decline — on a dispatch with no human attached, stop and
  report, consistent with `skill-approve`'s own `orchestrator_mode: true` refusal; never read
  `.decisions.json` as evidence that an approval requirement is satisfied.
- [ ] **Step 4.4:** Add the context reference to both agents' Context References sections as a
  plain on-demand pointer (not an eager `@`-import), matching how `gate-tiers.md` is already
  cited there.
- [ ] **Step 4.5:** Extend Phase 3's suite with structural assertions over the two agent files:
  each contains the recognizer invocation, the verbatim-copy instruction, each prohibition from
  Step 4.3, and the pointer to Phase 1's record; and neither contains an instruction to invoke
  `/approve`. Give each assertion its forgery probe.
  - **Files:** `agent-system/extensions/books/scripts/tests/test-books-approvals-signal.sh`
- [ ] **Step 4.6:** Re-read all three files immediately before staging; run the suite to green;
  commit with an explicit file list.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: two agent definitions carry the rule (`books-implementation-agent.md`,
`books-implementation-hard-agent.md`), and the research agents do not. Confirm at implementation
time by grepping all four books agent definitions for a gate or build invocation; if a research
agent turns out to run one, wire it too and say so in the summary.

**Tier Justification**: `run-all.sh --only test-books-approvals-signal.sh` plus the `prose` row's
diff read-through is the complete covering check — the agent-definition edits are pure guidance
markdown with no executable surface, and the suite's new structural assertions are exactly what
checks them.

**Files to modify**:

- `agent-system/extensions/books/agents/books-implementation-agent.md` - cross-cutting rule,
  prohibitions, context pointer
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` - same, by reference
- `agent-system/extensions/books/scripts/tests/test-books-approvals-signal.sh` - structural
  assertions plus their forgery probes

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-books-approvals-signal.sh`
  passes, including the new structural cases.
- Diff read-through confirms the signature is stated once (in Phase 1's record) and referenced,
  not duplicated, in either agent file.
- Each prohibition from Step 4.3 is present in both agent files and asserted by a probed test.

---

### Phase 5: Deploy, Full Gate, and the End-to-End Demonstration [NOT STARTED]

**Goal**: The source-store work reaches the deployed tree, the complete gate set is green, and the
acceptance clause "reaches Move 4's batched relay (demonstrated, not asserted)" is demonstrated
rather than claimed.

**Tasks**:

- [ ] **Step 5.1:** Deploy the source store: `bash .claude/scripts/deploy-headless.sh`. Confirm
  the new script, suite, and context record are present under `.claude/` and that the deployed
  agent definitions carry the rule.
- [ ] **Step 5.2:** Demonstrate the relay end to end without running the ~10-minute external
  gate: write a `.return-meta.json` carrying the recognizer's own emitted object as
  `user_decision` into a scratch task directory, run `orchestrate-cycle-postflight.sh` over it,
  and confirm the derived verdict is `ask_user` and the decision text is relayed byte-for-byte —
  the mechanical proof that the object this task emits reaches the batched Move 4 relay unchanged.
  Record the observed output in the summary; this is the acceptance clause's evidence.
- [ ] **Step 5.3:** Confirm the honest-red half of the same demonstration: the dispatch's reported
  status is unchanged by the presence of `user_decision` (the gate red is still a red), and no
  file under the component's approvals tree was touched.
- [ ] **Step 5.4:** Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. Confirm
  Gate 8 discovers and runs `test-books-approvals-signal.sh`.
- [ ] **Step 5.5:** Write the implementation summary, including a `## Plan Deviations` section, the
  rulings as shipped, the observed relay output from Step 5.2, and anything the Scope Hypothesis
  lines turned out to contradict.
- [ ] **Step 5.6:** Re-read every file before staging; commit with an explicit file list.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Files to modify**:

- `.claude/**` - deploy output only, never hand-authored
- `specs/350_offer_owner_review_when_approval_needed/summaries/01_offer-owner-review-approval-summary.md` - new

**Verification**:

- `bash .claude/scripts/deploy-headless.sh` succeeds and the deployed tree carries all four new or
  edited source-store files.
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set this aggregates — passes, with
  Gate 8 including the new suite and no gate reporting a zero-check-under-filter condition.
- `orchestrate-cycle-postflight.sh` over the scratch fixture yields `verdict=ask_user` with the
  `question`, `options`, `recommended`, and `blocking` values relayed verbatim.

---

## Testing & Validation

- [ ] Every recognized absent-or-stale family produces an offer (one case each).
- [ ] Every excluded family, a green gate, and a usage error produce no offer (one case each) —
      an ordinary build, proof, or record failure is never offered as an approval request.
- [ ] The emitted object matches `user_decision`'s schema exactly: three self-describing options,
      `blocking: false`, `recommended` byte-equal to the defer option.
- [ ] Declining leaves the requirement intact: the same offer is re-emitted, the recognizer never
      reads `.decisions.json`, and the fixture tree's digest is unchanged.
- [ ] Deferring does not consume the need: the same offer is re-emitted on the next run.
- [ ] No path self-answers: the recognizer's source invokes neither `/approve`, nor `approve.sh`,
      nor any gate, nor `AskUserQuestion`; both agent definitions are asserted to forbid it.
- [ ] The emitted object reaches a `verdict=ask_user` relay verbatim through
      `orchestrate-cycle-postflight.sh` (Phase 5, demonstrated).
- [ ] Every predicate in the new suite carries a forgery probe.
- [ ] `verify-deploy.sh`'s complete gate set is green after deploy.

## Artifacts & Outputs

- `agent-system/extensions/books/context/project/books/domain/approvals-detection.md` — the
  ruling with its reason, the pinned signature, the option semantics, the prohibitions.
- `agent-system/extensions/books/scripts/books-approvals-signal.sh` — the read-only recognizer.
- `agent-system/extensions/books/scripts/tests/test-books-approvals-signal.sh` — the fixture and
  structural suite with forgery probes.
- Edits: `agents/books-implementation-agent.md`, `agents/books-implementation-hard-agent.md`,
  `context/project/books/domain/gate-tiers.md`, `context/project/books/README.md`,
  `index-entries.json`, `manifest.json`.
- `specs/350_offer_owner_review_when_approval_needed/summaries/01_offer-owner-review-approval-summary.md`.

## Rollback/Contingency

Every phase is additive and independently revertible by commit. The recognizer is unreferenced
until Phase 4 wires it, so reverting Phase 4's commit alone disables the whole feature while
leaving the record and the tested script in place. Nothing in this plan edits
`skill-orchestrate/SKILL.md`, `orchestrate-cycle-postflight.sh`,
`orchestrate-record-decision.sh`, `/approve`, `approve.sh`, or `check-approvals.sh`, so no
existing interaction, approval, or gate path can regress from it. If a phase must stop midway,
take a defensive checkpoint with
`bash .claude/scripts/git-snapshot.sh 350 --no-revert` — never the reverting default form, which
is for a genuine rollback only and is barred outright while a sibling dispatch shares this tree.
