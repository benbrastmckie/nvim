# Research Report: Deliver Tool-Timeout Half of the Bounded-Wait Idiom

**Task**: 392 - Close the delivery gap between external-process-wait.md Rule 1 and the deploy
remedy sites that need it
**Started**: 2026-10-12
**Completed**: 2026-10-12
**Effort**: medium (codebase audit across ~9 scripts, 2 pattern docs, 1 agent file; no code
changes made in this phase)
**Dependencies**: task #354 (completed; owns general-implementation-agent.md's
"Dispatched-Subagent Wait Discipline" subsection), task #318 (completed; added verify-deploy.sh
gate 23, no line-number collision with this task's anchors)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/context/patterns/external-process-wait.md`,
  `.../bounded-build-waiter.md`, `.../agents/general-implementation-agent.md`
- Codebase: `scripts/verify-deploy.sh`, `scripts/orchestrate-build-dispatch.sh`,
  `scripts/check-deploy-freshness.sh`, `scripts/deploy-headless.sh`, and 6 further scripts
  found via a repo-wide grep (see Findings)
- Codebase: `scripts/tests/test-orchestrate-build-dispatch.sh`,
  `scripts/tests/test-deploy-freshness.sh` (read for exact assertion text, not assumed)
- Prior-session evidence relayed by the dispatching orchestrator: four stranding incidents
  observed in this same batch (tasks 354, 281, the orchestrator's own `orchestrate-cycle-plan.sh`
  call, and an earlier conclusion-stage dispatch), cited per instruction rather than re-derived
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task description's "three emission sites" undercounts the actual delivery gap by roughly
  4x: a repo-wide grep for redeploy-remedy text combined with `deploy-headless.sh` found **13
  occurrences across 9 scripts**, not 3 across 2. Closing the gap at only the named 3 would leave
  most real remedy sites unfixed.
- One of the task description's own attributions is wrong in a way that matters: the claim that
  `test-deploy-freshness.sh` asserts on `verify-deploy.sh`'s remedy strings is false. That test's
  `run_checker` invokes `check-deploy-freshness.sh`, and its substring assertion targets **that**
  script's WARN lines (`check-deploy-freshness.sh:95` and `:126`) — two sites the task description
  never named at all. `verify-deploy.sh`'s two named remedy strings (confirmed at the corrected
  lines, `:190` and `:310`) are not asserted on by name anywhere in the test suite.
- Both substring assertions that DO exist (`test-orchestrate-build-dispatch.sh:668` and
  `test-deploy-freshness.sh:151`) check only for the literal text `"deploy-headless.sh"` inside
  the emitted string — not exact wording. This gives wide latitude to enrich every remedy string
  with the tool-timeout obligation without risk to either suite, as long as that literal
  substring survives.
- `external-process-wait.md` Rule 1 already states the tool-`timeout`-600000 obligation as an
  imperative sentence, not purely as "Why 540 < 600" rationale — but it is one sentence sandwiched
  between a code block and a "Why" heading, with no visual or structural separation from the
  rationale that follows it. That placement, not its grammatical mood, is why agents keep missing
  it; promoting it into an explicit numbered sub-step (not just rewording) is the fix this task's
  evidence calls for.
- `general-implementation-agent.md` already carries the three-way shape distinction this task's
  description asks for (External Process Wait Discipline / Local Long-Running Command Discipline
  / Dispatched-Subagent Wait Discipline, the last added by task #354) — but none of the three
  sections states the tool-timeout-raise obligation explicitly in its own MUST bullets; each one
  only says "inner timeout below the harness's Bash-tool ceiling" and relies on a reader following
  the cross-reference to find half (ii). This is the same delivery gap, one layer up.
- Recommended fix shape: a single shared remedy-string helper (new function, natural home
  `scripts/lib/common.sh` or a small new lib) rather than 13 independently hand-edited strings,
  to avoid reproducing the exact "N independently-drifting copies" anti-pattern
  `bounded-build-waiter.md`'s own "Canonical Agent-Contract Bullet" section already named and
  rejected for the agent-contract case.

## Context & Scope

This is a **research-phase** dispatch: no source files were modified. The deliverable is findings,
a recorded set of decisions/rulings for the three "ALSO RULE ON" questions, and recommendations
for the planning phase. The task's own ACCEPTANCE criteria read as whole-task (research + plan +
implement) acceptance; this report addresses the research-phase slice of that (evidence-gathering,
site enumeration, test-assertion verification, and rulings) and explicitly defers the actual edits,
redeploy, and `verify-deploy.sh` gate run to the implementation phase.

In scope per the task description: (a) remedy-string delivery at the deploy-emission sites, (b)
`external-process-wait.md` Rule 1's presentation. Out of scope, confirmed and not reopened here:
widening postflight's `stall_suspected` predicate; changing the harness's own defaults.

## Findings

### Finding 1 — The true emission-site count is ~13, not 3

A grep across `agent-system/` for files containing `deploy-headless.sh` AND one of
(`Remedy`|`Run: bash`|`regenerate`|`redeploy via`) found 9 scripts carrying a live remedy string,
not 2:

| Site | Line(s) | Status vs. task description |
|---|---|---|
| `scripts/orchestrate-build-dispatch.sh` | `:393` | Named (corrected line per dispatching orchestrator) |
| `scripts/verify-deploy.sh` | `:190`, `:310` | Named (corrected lines) |
| `scripts/check-deploy-freshness.sh` | `:95`, `:126` | **Not named** — and see Finding 2 |
| `scripts/orchestrate-batch-admit.sh` | `:520` | Not named |
| `scripts/git-snapshot.sh` | `:130` | Not named |
| `scripts/orchestrate-predispatch-review.sh` | `:182` | Not named |
| `scripts/check-extension-docs.sh` | `:322`, `:337`, `:452`, `:459`, `:658`, `:713` | Not named (6 occurrences, one script) |
| `scripts/task-lock.sh` | `:244` | Not named |
| `scripts/skill-base.sh` | `:460` | Not named — wording is a near-duplicate of `orchestrate-build-dispatch.sh:393`'s, confirming independent copy-paste drift already exists |

The task description's GOAL states the gap to close is "every redeploy remedy string in the
source store" and its ACCEPTANCE criterion says "**every** redeploy remedy emission site" — both
phrased universally, with the "three emission sites" bullet list appearing only under a "WHY
AGENTS MISS HALF (ii)" illustrative section, not as a closed enumeration. Treating 3 as the full
scope would leave 10 real sites — including the one most commonly seen by an ordinary agent,
since `check-deploy-freshness.sh` fires non-blocking on every command via CHECKPOINT 1 — carrying
no timeout guidance at all, reproducing the exact defect this task exists to close for most of
the agents who would actually encounter it.

### Finding 2 — The task description's test attribution is wrong; the real coverage is narrower than claimed in one place and wider in another

`test-deploy-freshness.sh`'s `run_checker()` (line 120) invokes
`$WORKDIR/bin/check-deploy-freshness.sh`, not `verify-deploy.sh`. Its STALE-case assertion (line
151: `[[ "$OUT_STALE" == *"deploy-headless.sh"* ]]`) therefore checks `check-deploy-freshness.sh`'s
own WARN line (`:95`/`:126`), which the task description never named as an emission site at all.
Meanwhile `verify-deploy.sh`'s two named remedy strings (`:190`, `:310`) are not asserted on by
name in any test file found by grep. Net effect: the task description both omits the site its
own cited test actually targets, and claims test coverage for a site that has none. This does not
block the fix — both strings can still be safely enriched — but it changes which site's edit is
test-verified and which is not, and planning should verify `check-deploy-freshness.sh`'s two
sites explicitly rather than relying on the task description's pairing.

### Finding 3 — Both substring assertions are loose enough to permit the Half A fix without risk

- `test-orchestrate-build-dispatch.sh:668`: `assert_contains "$content" "deploy-headless.sh" ...`
- `test-deploy-freshness.sh:151`: `[[ "$OUT_STALE" == *"deploy-headless.sh"* ]]`

Neither checks exact wording, surrounding punctuation, or message length — only that the literal
substring `deploy-headless.sh` survives somewhere in the emitted text. Any enrichment (inline
timeout idiom, cross-reference by path, or both) that keeps that one substring intact passes both
suites unmodified. No test update is required for Half A, contrary to the task description's
hedge ("verify rather than assume, and update them if needed") — verification is complete and no
update is needed, provided the literal substring is preserved.

### Finding 4 — `external-process-wait.md` Rule 1 already states the obligation; the defect is placement, not mood

Current text (Rule 1, `context/patterns/external-process-wait.md:40-56`):

```
Use an inner-bounded, foreground, blocking command, not an unbounded watch:
    timeout 540 gh run watch ID --interval 60 --exit-status >/dev/null; gh run view ID ...
Issue it with the Bash tool's own `timeout` parameter set to `600000` (600s, its ceiling).
Repeat the pair only while the reported `status` is `in_progress` or `queued`.

**Why 540 < 600**: the inner `timeout 540` (540s) must fire and return control to the agent
*before* the harness's own 600000ms (600s) Bash-tool ceiling is reached. ...
```

The sentence "Issue it with the Bash tool's own `timeout` parameter set to `600000`" is already
an imperative, not phrased as rationale — it sits *before* the "Why 540 < 600" heading, not under
it. The task description's framing ("stated once, in prose, ... under a heading reading 'Why 540
< 600' that presents as rationale") is imprecise about *where* the sentence sits, but the
underlying complaint still holds: the obligation is one unmarked sentence between a code block
and an explanatory aside, with nothing structurally distinguishing "you must do this" from "here
is why the margin is 60s and not some other number." The measured evidence (the conclusion-stage
agent's actual command, `timeout 580 bash .claude/scripts/deploy-headless.sh 2>&1 | tail -60`,
applying half (i) correctly and omitting half (ii) entirely) is consistent with an agent reading
the code block and the first imperative sentence as one unit and stopping there, since nothing
marks a second required step.

### Finding 5 — The three-shapes distinction already exists in the codebase; this task's shape is not yet named within it

`general-implementation-agent.md` (lines ~156-266) already carries three clearly headed
subsections: **External Process Wait Discipline** (remote/CI), **Local Long-Running Command
Discipline** (local build/gate/test, including the bounded-build-waiter.md idiom), and
**Dispatched-Subagent Wait Discipline** (added by task #354; governs a nested `Agent`-tool
dispatch). All three MUST-bullet summaries have the same omission as Finding 4: each states "use
a bounded wait with an inner timeout below the harness's Bash-tool ceiling" (or equivalent) and
cross-references the owning pattern doc for "the full mechanics," but none of the three MUST
bullets itself states the tool-parameter-raise obligation. This task's shape (an agent issues an
ordinary foreground call with no deliberate backgrounding, and the harness auto-backgrounds it
purely because the Bash tool's own `timeout` parameter was left at its 120000ms default) is
distinct from all three existing cases by *trigger*, not by *command category*: `deploy-headless.sh`
is exactly the kind of local script "Local Long-Running Command Discipline" already covers, but
that section's framing ("whenever a local verification/gate process is **backgrounded at all**")
presumes the backgrounding was the agent's own deliberate choice (`&`/`nohup`), which is not what
happened in either measured incident.

### Finding 6 — `bounded-build-waiter.md`'s own "prefer the foreground form" guidance has the identical gap

`bounded-build-waiter.md`'s "The Canonical Idiom" section says: "Prefer the simpler foreground
form, `timeout 3000 cmd`, whenever the command fits within the calling tool's own timeout limit."
This already implies the tool's own timeout limit is adjustable, but never says to adjust it, and
its "Sizing a Wait Near the Per-Call Ceiling" subsection only cross-references
`external-process-wait.md`'s margin rule for the detach-plus-waiter case — not for this
preferred, simpler, plain-foreground case, which is exactly the shape `deploy-headless.sh`'s
~3-4 minute runtime (per the dispatching orchestrator's same-session measurement; not
re-measured here — see "Carried Figures" in Risks & Mitigations) falls into. This is the same
delivery gap as Finding 4, one file over.

### Finding 7 — Editing bounded-build-waiter.md's canonical bullet text has a wide blast radius; editing its prose does not

`bounded-build-waiter.md`'s "Canonical Agent-Contract Bullet (Generated-Copy Source)" section is
explicitly the single edit point for a MUST/MUST-NOT bullet pair that is then **literal-copied**
into every carrying implementation-agent file (14 files per that section's own count) and checked
by `lint-agent-contracts.sh` Check H (confirmed present via `test-lint-agent-contracts.sh`'s
reference to both pattern files). Any wording change inside that specific "Copy this exact text"
block requires a full re-propagation pass across all 14 files to keep the lint green. Adding the
tool-timeout obligation to Rule 1's or the Sizing subsection's ordinary prose (outside that
generated-copy block) carries no such obligation and is the lower-risk location for this task's
fix.

## Decisions

1. **Half A delivery form — hybrid, not a pure choice between the two offered options.** Each of
   the (confirmed) 13 remedy strings should carry BOTH a short, actionable inline clause (the
   concrete numbers: "set this Bash call's timeout parameter to 600000, inner `timeout` below
   that") AND a path cross-reference to `context/patterns/external-process-wait.md` Rule 1 for
   full mechanics. Rationale: a bare path reference reproduces the exact gap this task exists to
   close — an agent handed a terse stderr string under schedule pressure has already been shown
   (both measured incidents) not to make the extra read hop on its own; but a full prose
   restatement at 13 sites is the drift anti-pattern Finding 7/skill-base.sh already shows
   happening. The inline clause carries the one number that actually matters (the tool parameter,
   600000); the path carries the "why" and the worked example.
2. **Half B presentation — restructure Rule 1 into two explicit numbered sub-steps**, not a
   reword of the existing sentence. Keep "Why 540 < 600" scoped strictly to explaining the
   60-second margin (a rationale for a constant), and move the obligation itself ("the Bash
   tool's own `timeout` parameter must be raised to 600000") into step 2 of an explicit two-item
   list that step 1 (the inner-bounded command) also becomes. This directly matches the
   acceptance criterion's wording ("a numbered requirement, not ... rationale under a 'why this
   constant' heading") without overstating what was already true (Finding 4).
3. **ALSO RULE ON #1 (deploy-local runtime note)** — yes, add one. `deploy-headless.sh`'s header
   comment block already documents its modes inline (default/`--minimal-init`/`--wipe`/
   `--consumer-report`); add a parallel bullet stating the expected runtime class and the
   tool-timeout requirement at the point of use, pointing to Rule 1 by path rather than
   restating it, consistent with Decision 1's hybrid but biased toward the path side since this
   is prose documentation read by a human or an agent already inspecting the script, not a
   terse stderr line.
4. **ALSO RULE ON #2 (bounded-build-waiter.md pairing)** — yes, state it, but as ordinary prose
   in Rule 1 / the "Sizing" subsection (Finding 7), never inside the "Copy this exact text"
   generated-copy block. Argument: Finding 6 shows the gap is real and in the exact section an
   agent reads right before choosing the foreground form; Finding 7 shows the cost of placing it
   in the wrong sub-section (a 14-file propagation + lint re-check) is avoidable and buys nothing
   this task needs, since the existing bullet pair's content (background-or-not permission) is
   orthogonal to the tool-timeout-value question.
5. **ALSO RULE ON #3 (general-implementation-agent.md naming the third case)** — yes, but as a
   clarifying note inside the existing **Local Long-Running Command Discipline** section rather
   than a fourth top-level subsection. Finding 5 shows the three-way structure already exists and
   already covers local scripts like `deploy-headless.sh` by command category; what's missing is
   a sentence clarifying that "backgrounded at all" includes the harness's own auto-backgrounding
   of an ordinary foreground call whose tool `timeout` parameter was left at the 120000ms default
   — not only a deliberate `&`/`nohup`. This composes with task #354's addition (which lives in
   the separate Dispatched-Subagent section) rather than conflicting with it: #354 ruled on a
   different adjacent case in a different subsection, and this clarification does not touch that
   subsection's text.

## Recommendations

1. **Factor the remedy string into one shared helper rather than 13 independent edits.** Natural
   home: `scripts/lib/common.sh`, already sourced by `orchestrate-batch-admit.sh`,
   `orchestrate-predispatch-review.sh`, `task-lock.sh`, and (indirectly) `orchestrate-build-dispatch.sh`
   via `skill-base.sh`. Three scripts (`verify-deploy.sh`, `check-extension-docs.sh`,
   `git-snapshot.sh`) do not currently source `common.sh` at all; the plan should decide whether
   to add that sourcing or keep those three as hand-maintained near-duplicates of the shared
   string. `skill-base.sh:460`'s wording is already a near-duplicate of
   `orchestrate-build-dispatch.sh:393`'s — concrete evidence that hand-maintained duplication is
   already drifting, strengthening the case for a shared function over independent edits at all
   13 sites.
2. **Scope the implementation phase's edit list explicitly to all 9 files / 13 lines found in
   Finding 1**, not the task description's original 3, and have the plan cite this report rather
   than re-deriving the count.
3. **Verify `check-deploy-freshness.sh`'s two sites (`:95`, `:126`) against
   `test-deploy-freshness.sh:151` directly** during implementation (per Finding 2/3) — that is the
   actually-tested pair, not `verify-deploy.sh`'s.
4. **Re-measure `deploy-headless.sh`'s runtime once, at implementation time**, rather than
   carrying the dispatching orchestrator's same-session figure (~3-4 minutes) into a deliverable;
   that figure is cited here as research-stage evidence per instruction, not re-derived, and
   should not be treated as verified for the implementation's own runtime note (Decision 3).
5. **Run the full `verify-deploy.sh` gate set after redeploying**, per the task's acceptance
   criterion, using the Rule-1-pairing idiom this task itself is adding (tool `timeout` >= 600000,
   inner `timeout` below that) — a concrete, self-referential opportunity to confirm the fixed
   guidance actually prevents the stranding it targets.
6. **Flag, but do not fix in this task**, the agent-contract-bullet-level omission in
   `general-implementation-agent.md`'s three MUST-bullet summaries (Finding 5): each
   cross-references its owning pattern doc for "the full mechanics" without restating the
   tool-timeout obligation inline. Once Decision 2 lands (Rule 1 restructured into numbered
   steps), the cross-reference alone may become sufficient — reassess after Half B lands rather
   than editing both layers in one pass.

## Risks & Mitigations

- **Risk**: widening scope from 3 to 13 sites could be read as scope creep beyond what the task
  description authorized. **Mitigation**: the GOAL and ACCEPTANCE text both use the universal
  phrasing "every redeploy remedy string" / "every ... emission site," and the 3-site list is
  presented only under an illustrative "WHY AGENTS MISS HALF (ii)" heading, not as a closed
  enumeration — the wider scope is consistent with, not contrary to, the task's own stated intent.
  Planning should still confirm this reading explicitly rather than treating it as settled by this
  report alone.
- **Risk**: adding the tool-timeout sentence inside `bounded-build-waiter.md`'s generated-copy
  block (instead of ordinary prose) would force a 14-file re-propagation pass and could fail
  `lint-agent-contracts.sh` Check H if done incompletely. **Mitigation**: Decision 4 places the
  addition outside that block specifically to avoid this; implementation should double-check the
  exact line range of the "Copy this exact text" block before editing nearby text.
- **Carried figures**: this report cites the dispatching orchestrator's same-session measurements
  (`deploy-headless.sh` ~3-4 min, `verify-deploy.sh`'s full gate set 6-10 min) as evidentiary
  context for Finding 6/Recommendation 4, per that message's explicit instruction to cite rather
  than re-derive at the research stage. These are not re-measured in this report and should be
  re-measured once, at implementation time, before being written into any deploy-local runtime
  note (Decision 3) — a carried figure written into a deliverable without re-measurement would
  violate `report-format.md`'s Carried-Figure Discipline.
- **Known pre-existing flake** (out of scope, not investigated further): `test-four-tier-conflict.sh`
  Case 6, a `[1000ms,2000ms)` timing assertion observed at ~2.3-2.8s under concurrent session
  load. Not encountered in this research-phase dispatch (no test suites were run); recorded here
  only because the dispatching orchestrator flagged it for attribution if seen during
  implementation's test runs.

## Context Extension Recommendations

- **Topic**: redeploy-remedy-string inventory.
- **Gap**: nothing in `.claude/context/` currently catalogs where `deploy-headless.sh` remedy
  text is emitted; Finding 1's 13-site list exists only in this report.
- **Recommendation**: if the implementation phase adopts the shared-helper approach
  (Recommendation 1), the helper function itself becomes the durable inventory (one definition,
  N call sites) and no separate context file is needed. If the implementation phase instead keeps
  13 independent strings, consider a short addition to
  `context/patterns/regeneration-is-manual-only.md` (already the canonical home for
  deploy-freshness detection per `check-deploy-freshness.sh`'s own header comment) listing all
  emission sites, so a future audit does not have to re-run this report's grep.

## Appendix

### Search queries used

```
grep -rn "deploy-headless.sh" --include="*.sh" -l . | xargs grep -ln "Remedy\|Run: bash\|regenerate\|redeploy via"
grep -n "Remedy|Run: bash deploy-headless|regenerate" scripts/verify-deploy.sh scripts/orchestrate-build-dispatch.sh
grep -n "run_checker" -A5 scripts/tests/test-deploy-freshness.sh
grep -n "deploy-headless.sh|Remedy" scripts/tests/test-orchestrate-build-dispatch.sh scripts/tests/test-deploy-freshness.sh
```

### Files read in full or substantial part

- `agent-system/extensions/core/context/patterns/external-process-wait.md`
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md` (lines 143-442)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (relevant excerpts)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (relevant excerpts)
- `agent-system/extensions/core/scripts/check-deploy-freshness.sh` (full header + WARN logic)
- `agent-system/extensions/core/scripts/deploy-headless.sh` (header comment block)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` (relevant
  excerpts)
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` (relevant excerpts)
