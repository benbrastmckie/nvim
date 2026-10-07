# Implementation Plan: Task #300

- **Task**: 300 - Resolve AskUserQuestion's unreachability in dispatched subagents: verify the mechanism, correct the frontmatter standard's tool-inheritance claim, and rehome every user-choice gate
- **Status**: [IMPLEMENTING]
- **Effort**: 9.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/300_askuserquestion_unreachable_in_subagents/reports/01_askuserquestion-subagent-reachability.md
- **Artifacts**: plans/01_rehome-askuserquestion-gates.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research settled the task's first obligation by direct probe: `AskUserQuestion` is categorically
withheld from every dispatched-subagent configuration tested — no `tools:` line, an explicit
`tools:` allowlist that names the tool, a `subagent_type` registered with "All tools", and a
`subagent_type: "fork"` continuation all return `No matching deferred tools found`. Resolution 3
(fix the frontmatter) is therefore foreclosed by measurement, and Resolution 1 (rehome the gates)
is adopted — the option that removes the dependence rather than documenting a workaround, matching
the task's stated preference. This plan executes that rehoming against an already-proven in-repo
reference shape (`skill-slide-planning`/`skill-slide-critic` ask in the skill's own stages, then
delegate), corrects every documentation claim that contradicts the measurement, strips the
self-instructing `AskUserQuestion` language from every agent file that cannot honor it, lands a
structural regression fixture under `core/scripts/tests/`, and settles the `isolation` row on its
drop branch with the probes that justify it recorded in place.

Definition of done: no agent file instructs an agent to call a tool it cannot call; every
"inherit the full tool set" claim states the measured exception; `/meta`'s interactive interview
lives where `AskUserQuestion` actually works; the `isolation` row and its two code/doc mirrors are
consistent with each other and with what was (and was not) measured; and `file_scope`'s coarse
`scripts/tests/` entry is narrowed so `validate-state.sh --deep` stops warning on this task.

### Research Integration

- **Finding 1 (five live probes, one categorical result)** drives the whole remediation shape:
  the withholding is not frontmatter-mediated, so Phases 4-6's agent-file edits remove promises
  rather than add declarations. Sub-question (b) (`disallowedTools:` omission vs. `tools:`
  omission) could not be probed — the only two agent files declaring `disallowedTools:` belong to
  an extension not loaded in the probing session — and Phase 1 marks it **unverified** in the
  standard rather than rounding it up to the categorical pattern.
- **Finding 2 (the working reference pattern)** is the template for Phases 2-3: relocate the
  asking into the skill's own pre-delegation stages; leave the agent as the terminal
  non-interactive writer.
- **Finding 3 (Measurement 6)** is Phase 2's `allowed-tools` edit.
- **Finding 4** confirms `skill-spawn/SKILL.md` and `skill-fix-it/SKILL.md` need no change; they
  are deliberately absent from every phase's file list and are dropped from `file_scope` in
  Phase 7. Phase 6 adds a cheap structural guard that their unaffected status stays structural.
- **Findings 5 and 6** are Phase 5 (`literature-agent.md`'s doubly-inert allowlist;
  `slide-critic-agent.md`'s live self-instruction).
- **Finding 8** is Phase 1's `isolation` drop branch.

The fork sub-question is stated **confirmed, without qualification**: probe 5 dispatched
`subagent_type: "fork"` live and got the same `No matching deferred tools found`, so Phase 1's
correction asserts the fork case as measured rather than inferred from `fork-patterns.md`'s
documented mechanism.

**Ruling on the fork prompt-scoping addendum (recorded deliberately, per the research report's
Context Extension Recommendation): INCLUDED, bounded, in Phase 1.** The research measured a second
hazard firsthand while taking probe 5 — a `subagent_type: "fork"` dispatch inherits the *entire*
calling session's mandate, not just the forking turn's instructions, so a loosely-scoped fork
prompt can autonomously resume or complete unrelated inherited work instead of the narrow action
requested. Arguments against including it: it is a different defect class from
`AskUserQuestion` reachability, and the task's non-goals forbid widening. Arguments for, which
carry here: it widens `file_scope` by **zero** paths, because `core/docs/fork-patterns.md` is
already in Phase 1's file list for the withheld-tools pointer; that file is already the one place
documenting `context: fork` vs. `subagent_type: "fork"` as independent mechanisms, so it is the
only non-duplicating home; and the hazard was measured by this task's own research rather than
imported from elsewhere. The addendum is capped at a short subsection plus one table row — if it
starts growing into a second treatment of fork semantics, stop and leave the rest to a task that
declares the file.

Three facts this plan establishes beyond the research report, each measured here and each
expanding no scope beyond files the same defect already owns:

1. **A third occurrence of the false inheritance claim exists**, outside the two the dispatch
   enumerates: `core/docs/templates/agent-template.md:20` ("omit to inherit the full tool set").
   Probe: `grep -rn 'inherit the full tool set\|inherits the full' --include='*.md'
   agent-system/extensions/` returns exactly three hits — `agent-frontmatter-standard.md:39`,
   `agent-frontmatter-standard.md:71`, `agent-template.md:20`. Leaving the template's copy
   uncorrected would re-seed the defect into every agent authored from it, so it is corrected in
   the same pass.
2. **The `isolation` row has two mirrors, not one.** `core/scripts/lint/lint-agent-contracts.sh`
   hardcodes `["isolation"]=1` in its `SUPPORTED_KEYS` array under the comment "per
   agent-frontmatter-standard.md's Supported Fields table", and `agent-template.md:24` names the
   field in its pointer list. Probe: `grep -rln '"isolation"' agent-system/extensions/core/scripts/
   agent-system/extensions/core/hooks/` returns `lint/lint-agent-contracts.sh` only; the doc
   mirror came from the `agent-template.md` grep above. Dropping the row from the table alone
   would leave the lint and the template asserting a field the standard no longer documents.
3. **`cslib-vet-agent.md` already carries the correct phrasing** (line 470: "**Use
   AskUserQuestion** — this agent runs as a subagent and cannot call it; the invoking skill handles
   all user interaction", under its `MUST NOT` list). It is a precedent to copy, not a file to
   fix, and the Phase 6 fixture must not flag it. This plan adopts that sentence as the canonical
   replacement phrasing across Phases 4-5.

### Prior Plan Reference

No prior plan. `plans/` was empty at dispatch.

### Roadmap Alignment

`specs/ROADMAP.md` names this task the widest blocker in the graph ("it gates 302, 312 and 349")
and records its coarse `file_scope` warning as one of the seven standing
`validate-state.sh --deep` warnings. Two roadmap items this plan advances:

- The coarse-scope warning for this task clears in Phase 7.
- The roadmap's stated premise for the `/approve` work — "it needs AskUserQuestion to work in a
  dispatched subagent" — is **falsified by this task's measurement**: no dispatched-subagent
  configuration will ever expose the tool. That downstream task's approach needs re-derivation
  from the rehome pattern instead. This plan records the consequence and does **not** act on it:
  that task is not in this `file_scope` and re-planning it is out of scope here. Per
  `rules/no-task-references-in-deliverables.md`, nothing written into the source store cites it by
  number.

Also carried forward from the roadmap, and binding on Phase 7: **`tests/run-all.sh` (Gate 8) is
documented as not reliably runnable inside a dispatch budget** (111+ suites; a prior dispatch
closed a phase with a Reasoned Exclusion over it). Phase 7 names the targeted-suite substitute to
run when it cannot conclude, rather than discovering the problem mid-gate.

## Goals & Non-Goals

**Goals**:

- Correct every documentation claim that contradicts the measured withholding — all three
  "inherit the full tool set" occurrences — and mark the one unprobed sub-question unverified
  rather than inferring it.
- Settle every optional row of `agent-frontmatter-standard.md`'s Supported Fields table as either
  measured or explicitly unverified, with the row list re-measured at implementation time.
- Settle the `isolation` row on its drop branch, with the probes that justify the drop recorded in
  the file, and both of its mirrors brought into agreement.
- Rehome `/meta`'s interactive interview into `skill-meta`'s own execution, where
  `AskUserQuestion` demonstrably works, preserving every load-bearing interview constraint
  verbatim.
- Remove the instruction to call `AskUserQuestion` from every agent file that cannot call it,
  using the phrasing already proven in `cslib-vet-agent.md`.
- Land a structural regression fixture under `core/scripts/tests/` that encodes the
  postconditions, and state in the record that a shell fixture is not a harness re-verification.
- Record the fork prompt-scoping hazard this task's own research measured firsthand, in the one
  file that already documents fork semantics, capped at one subsection plus one table row.
- Narrow this task's `file_scope` to explicit files so the standing coarse-scope warning clears.

**Non-Goals**:

- Do **not** re-open the worktree isolation verdict.
  `specs/decisions/worktree-isolation-removal-verdict.md` is authoritative and the removal is not
  re-openable. The `isolation` fold-in concerns a documentation row and a missing fence, never the
  decision.
- Do **not** restore any part of the removal layer. `dispatch-worktree.sh`, its two test files, and
  `task_selected_for_worktree_isolation()` stay absent; the probe showing them absent is an
  acceptance check, not a to-do.
- Do **not** edit `git-commit-scoped.sh` or `lake-build-guard.sh`. Both carry separately-tracked
  open defects (false-success staging inside a worktree; cross-tree record replay) and are cited
  here only as the reason a worktree re-entry path would matter. Cite them by path and defect in
  anything written into the source store, never by task number.
- Do **not** add `territory.md` or `batch-orchestration-guardrails.md` to scope. The drop branch
  (Phase 1) means resolution 5's first branch is never reached, so the forwarding prohibition
  needs no new home and the overlap with the other open isolation-posture task is avoided outright
  rather than negotiated. See Risks.
- Do **not** touch the 25 direct-execution skills that merely mention the tool, nor
  `skill-spawn/SKILL.md` / `skill-fix-it/SKILL.md`, which research confirmed structurally
  unaffected.
- Do **not** sanction the `SendMessage`-to-parent relay as the mechanism `/meta` relies on. It
  stays an observed workaround, not a documented pattern; the rehome removes the need for it.
- Do **not** attempt the decisive `isolation` probe by authoring and dispatching an agent that
  declares `isolation: worktree`. See Risks for why that probe is deliberately not taken.
- Do **not** hand-author anything under `.claude/**`. Every edit lands in
  `agent-system/extensions/**`; the deployed tree is regenerated.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Moving ~500 interview lines inline into `skill-meta/SKILL.md` reintroduces the token pressure thin-wrapper skills exist to avoid (294 lines today; `skill-slide-planning` is 497 as the size reference) | M | H | Phase 2 relocates the interview body **verbatim into a new non-eager context file** (`core/context/workflows/meta-interview.md`) and leaves `skill-meta/SKILL.md` a thin stage that reads and executes it. `context/workflows` is already declared wholesale in core's `manifest.json`, so no manifest edit is needed, and prompt/analyze modes stop paying for the interview entirely |
| Relocating the interview silently drops load-bearing constraints embedded in its prose (Stage 4.5's no-Skip rule, the mandatory Stage 5 confirmation gate, the dependency-validation re-prompt) | H | M | Phase 2 relocates by **cut-and-paste, then line-count-and-diff against the original**, never by summarizing or rewriting. Phase 3 only removes the agent-side mandate language after the relocated text has been diff-confirmed present |
| Dropping the `isolation` row leaves two mirrors asserting it (`lint-agent-contracts.sh`'s `SUPPORTED_KEYS`, `agent-template.md`'s pointer list), so the standard and its consumers drift | M | H | Phase 1 edits all three in one phase and runs `test-lint-agent-contracts.sh` as the in-phase gate. No agent file declares `isolation:`, so no new Check A warning can be produced by the narrowing |
| Dropping the `isolation` row could be wrong if a future direct test shows the harness does honor it | L | M | Phase 1 frames the removal as "removed; no measurement supports it, and the worktree-removal posture argues against leaving a documented, unfenced row whose example value requests a worktree" — never as "the harness does not support `isolation`". A future positive measurement can then cleanly re-add the row rather than having to argue against a false negative |
| Taking the decisive `isolation` probe would itself be the hazard it documents: it requires dispatching an agent that declares `isolation: worktree`, which re-arms two separately-tracked open defects (`git-commit-scoped.sh`'s false-success staging inside a worktree; `lake-build-guard.sh`'s cross-tree record replay) | H | H | The probe is deliberately **not taken**, and Phase 1 records that refusal with its reason in the file. This is the stated-unverified branch the task's acceptance criterion admits, not a deferral: the row does not survive unmeasured, it is dropped |
| The acceptance item "`/meta` with no arguments completes a real interview and creates a task" cannot be self-verified by the implementing agent — a dispatched subagent cannot call `AskUserQuestion`, which is the very fact being fixed | M | H | Phase 7 marks this check **primary-session- or user-owned**, names the exact command, and requires the implementer to report it as not-self-verifiable rather than claim it. The handoff `summary` says so explicitly |
| `tests/run-all.sh` (Gate 8) does not reliably conclude inside a dispatch budget | M | H | Phase 7 names the targeted-suite substitute up front and pre-authorizes a `#### Reasoned Exclusions` record for Gate 8 alone, with the per-suite evidence standing in for the aggregate |
| `core/index-entries.json` (Phase 2) and `skill-meta/SKILL.md` + `meta-builder-agent.md` (Phases 2-3) each overlap one other non-terminal task's declared `file_scope` | M | M | Declared explicitly in each phase. `index-entries.json` is a pure single-element array append; re-read immediately before editing, commit only this task's own hunk, never a directory or glob `git add` |
| Two concurrent siblings run this same cycle on this shared tree | M | H | Per the dispatch territory block: re-read before editing, stage only this task's hunks, treat an out-of-`file_scope` failure as possibly a sibling's in-flight edit, and stop and report any foreign commit or uncommitted change after checking `git log` |
| A sibling implementing this same cycle declares three files under `core/scripts/tests/` (`run-all.sh`, `test-stall-reprompt-wiring.sh`, `suite-cost-hints.txt`), which this task's pre-plan coarse directory entry contended with wholesale | M | H | **Contention removed by construction, not negotiated**: this plan declares exactly one path under that directory — the new `test-askuserquestion-rehome.sh` — and touches neither `run-all.sh` (which auto-discovers `test-*.sh` by glob, so no registration is needed) nor `suite-cost-hints.txt` (advisory-only; a missing hint never skips or reorders away a suite). The three sibling-owned files appear in no phase's file list, and Phase 7's narrowing removes the directory entry that created the overlap |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4, 5 | 1, 2 |
| 3 | 6 | 1, 2, 3, 4, 5 |
| 4 | 7 | 6 |

Phases within the same wave can execute in parallel. Wave 2's Phase 3 is blocked by 2 only;
Phases 4 and 5 are blocked by 1 only (see each phase's own `Depends on`).

### Phase 1: Correct the frontmatter standard and settle every optional row [COMPLETED]

**Goal**: `agent-frontmatter-standard.md` states the measured withholding at every occurrence,
every optional row is marked measured or unverified, the `isolation` row is dropped with its
probes recorded, both of the row's mirrors agree, and `fork-patterns.md` carries the pointer plus
the bounded prompt-scoping addendum ruled in under Research Integration.

**Tasks**:
- [x] Re-measure the optional-row list before editing (the integer is not durable, the names are):
      `awk '/^## Supported Fields/,/^## Optional Fields/' agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md | grep '^| `' | awk -F'|' '$4 ~ /No/'`
      — record the row names actually present, not this plan's count.
- [x] Re-measure the inheritance-claim occurrences:
      `grep -rn 'inherit the full tool set\|inherits the full' --include='*.md' agent-system/extensions/`
- [x] Correct the `tools` row (line ~39) and the "`tools:`, `disallowedTools:`, and `mcpServers:`
      Semantics" bullet (line ~71) to state the measured exception: `AskUserQuestion` is withheld
      from every `Agent`-tool dispatch — plain or `subagent_type: "fork"` — regardless of a
      `tools:` allowlist naming it, of "All tools" registration, or of frontmatter omission.
      State the probe (`ToolSearch` with `select:AskUserQuestion` inside a dispatched subagent →
      `No matching deferred tools found`) and the five configurations it was taken across.
- [x] In the same correction, mark the one unprobed sub-question **unverified**, with its reason:
      `disallowedTools:` omission vs. `tools:` omission could not be measured because the only two
      agent files declaring `disallowedTools:` belong to an extension not loaded in the probing
      session. Say that the categorical pattern makes a frontmatter-parsing explanation unlikely,
      and label that an inference, not a measurement.
- [x] Add a verification-status marking to every optional row of the Supported Fields table, so no
      row silently retains an unmeasured behavioural claim. Rows the probe matrix settled are
      marked measured with their probe; every other row is marked unverified. Use the row names
      from the re-measurement above.
- [x] **Drop the `isolation` row** from the Supported Fields table. Record in the file: Probe B
      (`grep -rn '^isolation:' agent-system/extensions/*/agents/` → no match: nothing declares it);
      Probe C (`grep -n -i isolation` on `core/skills/skill-orchestrate/SKILL.md` → no match: the
      forwarding prohibition that fenced it off is gone, deliberately, for a recorded byte-budget
      reclamation); and that the decisive question — whether the harness honours `isolation:` from
      an agent-definition frontmatter block at all — is **unverified and deliberately not probed**,
      because the probe requires dispatching an agent that requests a worktree-isolated dispatch,
      which would re-arm two separately-tracked open defects: `core/scripts/git-commit-scoped.sh`
      reports false success inside a worktree (`PROJECT_ROOT` derived from `BASH_SOURCE[0]`, every
      pathspec WARN-and-dropped, nothing staged, exit 0) and `core/scripts/lake-build-guard.sh`
      replays records across trees. Frame the removal as "removed; no measurement supports it" —
      never as "the harness does not support `isolation`" — so a future positive measurement can
      re-add the row cleanly. Cite both scripts by path and defect, never by task number.
- [x] Remove `["isolation"]=1` from `SUPPORTED_KEYS` in
      `core/scripts/lint/lint-agent-contracts.sh`, keeping the array's comment pointing at the
      table it mirrors.
- [x] In `core/docs/templates/agent-template.md`: correct the "omit to inherit the full tool set"
      parenthetical to match the standard, and drop `isolation` from the pointer list of complete
      field-table names.
- [x] Add a single pointer line to `core/docs/fork-patterns.md` (which already documents
      `context: fork` vs. `subagent_type: "fork"` as independent mechanisms) naming
      `agent-frontmatter-standard.md`'s corrected section as the canonical statement of which
      native tools are withheld from `Agent`-dispatched subagents. **Pointer only — no second copy
      of the content**, so the fact stays in exactly one place.
- [x] In the same file, add the bounded fork prompt-scoping addendum ruled in above: a short
      subsection stating that a `subagent_type: "fork"` dispatch inherits the entire calling
      session's mandate, not just the forking turn's instructions, so a fork asked for a narrow
      diagnostic action needs explicit **negative** scoping ("do not write files, do not dispatch
      further agents, stop after step N") — a positive instruction alone is not sufficient
      containment. Record that this was observed firsthand (a loosely-scoped diagnostic fork
      autonomously produced a full set of deliverables for its inherited task instead of returning
      the one requested probe result; a repeat with explicit negative scoping returned the intended
      single-line result), and add one `Constraints and Incompatibilities` table row for it. The
      existing `subagent_type: "fork"` section's sentence "The fork inherits the parent's context
      without requiring a specialized agent type" reads as a pure benefit — qualify it there with a
      pointer to the new subsection. **Hard cap: one subsection plus one table row.** If it grows
      beyond that, stop and leave the remainder to a task that declares this file.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this plan asserts 14 optional (Required=No) rows, 3 occurrences of the
inheritance claim across 2 files, and exactly 2 mirrors of the `isolation` row
(`lint-agent-contracts.sh`'s `SUPPORTED_KEYS`, `agent-template.md`'s pointer list). Confirm all
three at implementation time with the re-measurement commands in this phase's first two tasks plus
`grep -rln '"isolation"' agent-system/extensions/core/scripts/ agent-system/extensions/core/hooks/`,
and record any divergence in the phase's own notes rather than silently adopting this plan's
figures. It also asserts the `fork-patterns.md` addendum fits inside one subsection plus one table
row; if the file's existing structure makes that impossible, stop at the pointer line and record
why rather than widening.

**Files to modify**:
- `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` - corrected inheritance claim at both occurrences, per-row verification marking across every optional row, `isolation` row dropped with its probes and the deliberate-non-probe reason recorded
- `agent-system/extensions/core/docs/templates/agent-template.md` - third inheritance-claim occurrence corrected; `isolation` dropped from the field-name pointer list
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - `isolation` removed from `SUPPORTED_KEYS` so the lint stops asserting a dropped row
- `agent-system/extensions/core/docs/fork-patterns.md` - one pointer line to the standard's corrected section (no duplicated content), plus the bounded fork prompt-scoping addendum: one short subsection, one `Constraints and Incompatibilities` row, and a qualifier on the existing "inherits the parent's context" sentence

**Verification**:
- `timeout 300 bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` passes
  (run in the foreground, output redirected to a file).
- `REPO_ROOT=$(pwd) timeout 300 bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
  reports no new warning or failure attributable to this phase — in particular no Check A warning,
  since no agent file declares `isolation:`.
- `grep -rn 'inherit the full tool set\|inherits the full' --include='*.md' agent-system/extensions/`
  returns no occurrence lacking the measured exception nearby.
- `grep -rn 'isolation' agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
  shows only the removal record, never a Supported Fields row.
- `grep -rln 'dispatch-worktree.sh\|task_selected_for_worktree_isolation' agent-system/` still
  returns nothing (removal layer untouched).
- `git diff --stat -- agent-system/extensions/core/docs/fork-patterns.md` shows the addendum stayed
  within its declared cap (one subsection, one table row, one qualifier) — a larger diff there is
  the signal to stop and leave the rest to a task that declares the file.

---

### Phase 2: Relocate the /meta interview into skill-meta's own execution [COMPLETED]

**Goal**: the interactive interview lives where `AskUserQuestion` works — in `skill-meta`'s own
pre-delegation stages — with its text preserved verbatim in a new non-eager context file, and
`skill-meta`'s `allowed-tools` able to run it.

**Tasks**:
- [x] Re-read `core/agents/meta-builder-agent.md` and record the exact line ranges of Interview
      Stages 0 through 5 (`DetectExistingSystem`, `InitiateInterview`, `GatherDomainInfo` with
      Questions 1/2, `DetectDomainType`, `IdentifyUseCases` with Question 3 and the dependency
      validation plus Questions 5/5b, `AnalyzeConsolidation` with its own question,
      `AssessComplexity` with Question 6, `AssignTopic`, and the mandatory `ReviewAndConfirm`
      gate), plus Stage 3B's prompt-mode clarification and confirmation steps. Record the
      pre-move line count.
- [x] Create `core/context/workflows/meta-interview.md`: a header stating that this workflow runs
      in the invoking skill's own execution (never in a dispatched subagent, because
      `AskUserQuestion` is withheld there — pointer to the corrected standard section, no second
      copy of the measurement), followed by the interview stages **cut and pasted verbatim** from
      `meta-builder-agent.md`. Preserve the load-bearing constraints exactly as written: the
      topic-picker stage having no Skip option, the mandatory confirmation gate, and the
      dependency-validation re-prompt. Do not summarize or rewrite.
- [x] Diff the relocated text against the original line ranges and confirm every line is accounted
      for before proceeding. Record the before/after line counts.
- [x] Add `AskUserQuestion` to `core/skills/skill-meta/SKILL.md`'s `allowed-tools:` line, matching
      `skill-slide-planning`/`skill-slide-critic`'s own frontmatter (`Agent, Bash, Edit, Read,
      Write, AskUserQuestion`).
- [x] Restructure `skill-meta/SKILL.md`'s Execution section to the proven shape: a new
      pre-delegation stage, placed after input validation and before context preparation, that for
      `mode=interactive` reads and executes `context/workflows/meta-interview.md` in the skill's
      own execution and collects the answers; for `mode=prompt`, runs the relocated clarification
      and confirmation steps the same way; for `mode=analyze`, is a no-op. The existing `Agent`
      dispatch stage then carries the **already-collected answers** in its delegation context.
- [x] Update the "The subagent will:" list in that same section: the `Interactive` bullet must no
      longer read "Run 7-stage interview with AskUserQuestion". Replace with the agent's actual
      remaining job — decisioning on already-collected answers and the task writes.
- [x] Update `skill-meta/SKILL.md`'s postflight `MUST NOT` list, which currently lists
      `AskUserQuestion` as "User interaction is agent work". It is skill work now, and
      specifically pre-delegation work; the postflight boundary still forbids it after the
      dispatch returns. State that distinction rather than deleting the bullet.
- [x] Add the delegation-context fields the collected answers travel in, alongside the existing
      `mode`/`prompt`/`mode_target`/`target_root` keys.
- [x] Re-read `core/index-entries.json` immediately before editing (declared overlap, below), then
      append one entry for `workflows/meta-interview.md` following the
      `workflows/task-breakdown.md` entry's shape (`path`, `domain`, `subdomain`, `summary`,
      `line_count`, `keywords`, `topics`, `load_when`). `load_when` names `skill-meta` and the
      `/meta` command.
- [x] No `core/manifest.json` edit: `provides.context` already declares `workflows` as a whole
      directory, so the new file deploys without one. Confirm with
      `jq -r '.provides.context' agent-system/extensions/core/manifest.json`.

**Timing**: 1.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this plan assumes the relocatable interview text is roughly 500 lines
(Interview Stages 0-5 plus Stage 3B's clarification/confirmation steps), and that `skill-meta`'s
restructured `SKILL.md` stays near its current 294 lines rather than absorbing them. Confirm the
real line ranges and the post-edit `wc -l` of both files at implementation time;
`skill-slide-planning/SKILL.md`'s 497 lines is the size reference, not a target.

**Declared file_scope overlap**: `core/skills/skill-meta/SKILL.md` is also declared by one other
non-terminal task (a commit-staging `--task` change) and `core/index-entries.json` by another (a
record-versioning-language rule). Both of this phase's edits are additive and narrowly located —
a frontmatter line, a new stage, and a single array element. Re-read each file immediately before
editing and stage only this task's own hunks.

**Files to modify**:
- `agent-system/extensions/core/context/workflows/meta-interview.md` - NEW: the interview stages relocated verbatim, with a header stating they run in the invoking skill's own execution
- `agent-system/extensions/core/skills/skill-meta/SKILL.md` - `AskUserQuestion` added to `allowed-tools`; new pre-delegation interview stage; "The subagent will" list and postflight `MUST NOT` corrected; collected answers added to the delegation context
- `agent-system/extensions/core/index-entries.json` - one appended index entry for the new workflow file

**Verification**:
- `timeout 300 bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` passes.
- `head -6 agent-system/extensions/core/skills/skill-meta/SKILL.md` shows `AskUserQuestion` in
  `allowed-tools:`.
- `grep -n 'AskUserQuestion' agent-system/extensions/core/skills/skill-meta/SKILL.md` shows the
  interview is skill work; no line still assigns the asking to the subagent.
- The diff/line-count reconciliation from this phase's third task confirms no interview line was
  lost in relocation.
- `jq -e '.entries[] | select(.path == "workflows/meta-interview.md")' agent-system/extensions/core/index-entries.json`
  exits 0.

---

### Phase 3: Strip the interview mandate from meta-builder-agent [COMPLETED]

**Goal**: `meta-builder-agent.md` stops mandating a tool it cannot call and reads as the terminal,
non-interactive task writer that receives pre-collected answers.

**Tasks**:
- [x] Confirm Phase 2's relocated text is present and diff-reconciled before removing anything
      from this file.
- [x] Remove the interview stages now living in `context/workflows/meta-interview.md`, replacing
      them with a short stage that consumes the collected answers from the delegation context.
- [x] Remove the three mandate statements (the `Constraints` bullets requiring `AskUserQuestion`
      with `options` for EVERY user choice and forbidding the text fallback, and the `NEVER
      present choices as plain text` line in Stage 3B).
- [x] Remove `AskUserQuestion - Multi-turn interview for interactive mode` from the agent's own
      `Allowed Tools` / `Interactive Tools` list.
- [x] Remove the `Critical Requirements` item "Use AskUserQuestion for interactive mode multi-turn
      conversation".
- [x] Add a `MUST NOT` bullet in the file's existing `MUST NOT` list using the phrasing already
      proven in `cslib/agents/cslib-vet-agent.md`: **Use AskUserQuestion** — this agent runs as a
      subagent and cannot call it; the invoking skill handles all user interaction.
- [x] Leave Stage 6 `CreateTasks`, Stage 7 `DeliverSummary`, Stage 3C analysis, and every
      status/metadata stage intact — they are non-interactive and stay the agent's work.
- [x] Re-check that the path-qualification imperative (`target_root`-qualified task-directory
      paths) still reaches the agent after the restructure.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this plan assumes `meta-builder-agent.md` (1558 lines pre-edit) loses roughly
the same ~500 lines Phase 2 relocated and retains Stages 6, 7, 3C and the metadata stages.
Confirm with `wc -l` before and after, and with a `grep -c 'AskUserQuestion'` that reaches zero
except the single `MUST NOT` bullet.

**Declared file_scope overlap**: `core/agents/meta-builder-agent.md` is also declared by one other
non-terminal task. Re-read immediately before editing; stage only this task's hunks.

**Files to modify**:
- `agent-system/extensions/core/agents/meta-builder-agent.md` - interview stages removed (relocated in Phase 2), three mandate statements and the tools-list entry removed, `MUST NOT` bullet added in the proven phrasing, collected-answers consumption stage added

**Verification**:
- `grep -n 'AskUserQuestion' agent-system/extensions/core/agents/meta-builder-agent.md` returns
  exactly one hit: the `MUST NOT` bullet stating the agent cannot call it. *(deviation: altered —
  measured 4 hits, not 1: the MUST NOT bullet appears in both of the file's existing MUST-NOT-shaped
  lists (Constraints FORBIDDEN and Critical Requirements MUST NOT), plus two explanatory sentences
  at the head of Stage 3A/3B pointing at the relocated workflow file. All 4 are unavailability/
  pointer statements, none instructs a call — see progress/phase-3-progress.json.)*
- `REPO_ROOT=$(pwd) timeout 300 bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
  reports no new failure (Checks A, B, C, E, F still pass for this file).
- `timeout 300 bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` passes.

---

### Phase 4: Correct the founder and epidemiology agent files [COMPLETED]

**Goal**: no founder or epidemiology agent file instructs itself to call a tool it cannot call.

**Tasks**:
- [x] Re-enumerate the affected set before editing (the list, not the count, is durable):
      `grep -rln 'AskUserQuestion' --include='*.md' agent-system/extensions/founder/agents/ agent-system/extensions/epidemiology/agents/`
- [x] For each file, replace the self-instruction with the `cslib-vet-agent.md` phrasing, adapted
      to the file's own structure: where the file has a `MUST NOT` list, add the bullet there;
      where the instruction sits inside a workflow step, keep the step's non-interactive fallback
      (several already name one — e.g. "document uncertainties in the findings report") and drop
      only the tool call.
- [x] Remove `AskUserQuestion` from each file's own tools/capabilities list where it is advertised
      (`analyze-agent.md`, `funds-agent.md` and siblings list it as an available tool).
- [x] The two heavy files (`founder/agents/legal-analysis-agent.md`, ~18 occurrences, and the
      present-extension equivalent handled in Phase 5) carry a question-by-question interactive
      flow rather than a single instruction. For these, state where the asking now happens — the
      invoking skill, before delegation — and keep the agent's own stages non-interactive, rather
      than deleting the content outright.
- [x] Do not add any `tools:` declaration to any of these files: measurement forecloses that
      remediation.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this plan asserts 14 files in this phase's set (12 under `founder/agents/`,
2 under `epidemiology/agents/`), with occurrence counts of 18 (`legal-analysis-agent.md`), 4
(`deck-planner-agent.md`), 3 each for seven files, 2 each for two, and 1 each for the two
epidemiology files. Re-run the enumeration command above and the per-file
`grep -c 'AskUserQuestion'` at implementation time; adopt the measured set, not this list.

**Files to modify**:
- `agent-system/extensions/founder/agents/analyze-agent.md` - drop the tools-list entry and the mode-selection/forcing-question self-instructions
- `agent-system/extensions/founder/agents/deck-planner-agent.md` - drop the self-instructions, keep non-interactive fallbacks *(deviation: altered — on inspection this file already matches the proven-correct pattern verbatim (its Overview, Stage 3, error return, and MUST NOT list already state "the skill handles all interactive AskUserQuestion pickers before delegating"); no edit was needed, same precedent class as cslib-vet-agent.md)*
- `agent-system/extensions/founder/agents/deck-research-agent.md` - drop the self-instructions, keep non-interactive fallbacks
- `agent-system/extensions/founder/agents/finance-agent.md` - drop the self-instructions, keep non-interactive fallbacks
- `agent-system/extensions/founder/agents/financial-analysis-agent.md` - drop the self-instructions, keep non-interactive fallbacks
- `agent-system/extensions/founder/agents/founder-spreadsheet-agent.md` - drop the self-instructions, keep non-interactive fallbacks
- `agent-system/extensions/founder/agents/legal-analysis-agent.md` - heaviest file: relocate the asking to the invoking skill in the prose, keep the agent's stages non-interactive
- `agent-system/extensions/founder/agents/legal-council-agent.md` - drop the self-instructions, keep non-interactive fallbacks
- `agent-system/extensions/founder/agents/market-agent.md` - drop the self-instructions, keep non-interactive fallbacks
- `agent-system/extensions/founder/agents/meeting-agent.md` - drop the self-instructions, keep non-interactive fallbacks
- `agent-system/extensions/founder/agents/project-agent.md` - drop the self-instructions, keep non-interactive fallbacks
- `agent-system/extensions/founder/agents/strategy-agent.md` - drop the self-instructions, keep non-interactive fallbacks
- `agent-system/extensions/epidemiology/agents/epi-implement-agent.md` - drop the tool call from the step, keep "document uncertainties in the findings report"
- `agent-system/extensions/epidemiology/agents/epi-research-agent.md` - drop the tool call from the step, keep the report-based fallback

**Verification**:
- `grep -rn 'AskUserQuestion' agent-system/extensions/founder/agents/ agent-system/extensions/epidemiology/agents/`
  shows only lines stating the tool is unavailable to a dispatched subagent — no line instructing
  one to call it, and no tools-list advertisement.
- `REPO_ROOT=$(pwd) timeout 300 bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
  reports no new failure across these files.
- `timeout 300 bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` passes.

---

### Phase 5: Correct the present-extension agents, their two skills, and literature-agent [COMPLETED]

**Goal**: the present extension's agents stop promising the tool, its two fork-to-agent skills'
contracts agree with where the asking happens, and `literature-agent.md`'s doubly-inert allowlist
is correct.

**Tasks**:
- [x] Re-enumerate: `grep -rln 'AskUserQuestion' --include='*.md' agent-system/extensions/present/agents/`
- [x] Apply the same correction as Phase 4 across the present agents. `slide-critic-agent.md`'s
      single occurrence ("Use AskUserQuestion (questions or ambiguities go in the report)") keeps
      only the parenthetical's report-based fallback — it is a live instance, since that agent IS
      genuinely dispatched by `skill-slide-critic/SKILL.md`.
- [x] `present/agents/timeline-agent.md` (~16 occurrences) is the present-side heavy file: state
      that the asking happens in the invoking skill before delegation; keep the agent's stages
      non-interactive.
- [x] In `present/skills/skill-slide-critic/SKILL.md` and
      `present/skills/skill-slide-planning/SKILL.md`, confirm by re-reading that every
      `AskUserQuestion` call still sits in a stage that executes **before** the Stage 7 `Agent`
      dispatch, and add one explicit sentence to each stating that placement is load-bearing and
      why — `context: fork` is a context-loading optimization and grants no tool access; the calls
      work because they run pre-delegation. Point at the corrected standard section rather than
      restating the measurement. Make no other change: these two skills are the working reference
      shape and must not be churned. *(deviation: altered — re-reading `skill-slide-critic/SKILL.md`
      found its `AskUserQuestion` calls (Stage 6, "Interactive Critique Loop") sit AFTER its
      `Agent`-tool dispatch (Stage 4), not before: this skill dispatches the agent first for
      non-interactive analysis, then runs the interactive loop itself on the returned report.
      `skill-slide-planning` matches the plan's literal "before" framing exactly. Both place the
      asking in the skill's own execution — never inside the dispatched agent — which is the
      actual load-bearing property; the sentence added to skill-slide-critic states its own
      correct "after the dispatch returns" placement instead of the "before" wording this task
      item anticipated. See progress/phase-5-progress.json.)*
- [x] Re-verify `literature-agent`'s never-dispatched claim before acting on it (it is a
      load-bearing architectural claim the agent's own body makes about itself):
      `grep -rn 'literature-agent' agent-system/extensions/literature/skills/skill-literature/SKILL.md`
      and a check for any `agent:`/`context:` frontmatter or `Agent`-tool dispatch there.
- [x] Drop `AskUserQuestion` from `literature/agents/literature-agent.md`'s `tools:` line, leaving
      `Bash, Read, Write, Edit` — the measured runtime grant. Add a one-line body note recording
      that the declaration was inert on two independent grounds (the harness drops the tool even
      when declared; the agent is not dispatched in the live `/literature` direct-execution flow)
      and that the agent nonetheless stays registered as a dispatchable type, so the narrowed
      allowlist matters to anyone who does dispatch it.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this plan asserts 7 files under `present/agents/` (occurrence counts 16 for
`timeline-agent.md`, 3 for `budget-agent.md`, 2 for `slides-research-agent.md`, 1 each for
`funds-agent.md`, `pptx-assembly-agent.md`, `slide-critic-agent.md`, `slidev-assembly-agent.md`),
plus the 2 present SKILL.md files and `literature-agent.md` (8 occurrences). It also asserts the
two present skills need only an added explanatory sentence, not a structural change. Re-measure
both the file set and the pre-delegation placement at implementation time.

**Files to modify**:
- `agent-system/extensions/present/agents/budget-agent.md` - drop the self-instructions and the tools-list entry
- `agent-system/extensions/present/agents/funds-agent.md` - drop the tools-list entry advertising the tool
- `agent-system/extensions/present/agents/pptx-assembly-agent.md` - drop the self-instruction
- `agent-system/extensions/present/agents/slide-critic-agent.md` - drop "Use AskUserQuestion", keep the report-based fallback already in the same line
- `agent-system/extensions/present/agents/slides-research-agent.md` - drop the self-instructions
- `agent-system/extensions/present/agents/slidev-assembly-agent.md` - drop the self-instruction
- `agent-system/extensions/present/agents/timeline-agent.md` - heaviest present file: relocate the asking to the invoking skill in the prose, keep the agent's stages non-interactive
- `agent-system/extensions/present/skills/skill-slide-critic/SKILL.md` - one sentence stating the pre-delegation placement of its `AskUserQuestion` stage is load-bearing, pointing at the corrected standard; no structural change
- `agent-system/extensions/present/skills/skill-slide-planning/SKILL.md` - same one-sentence addition; no structural change
- `agent-system/extensions/literature/agents/literature-agent.md` - `AskUserQuestion` dropped from `tools:`; one-line note on the declaration's two independent grounds for inertness

**Verification**:
- `grep -rn 'AskUserQuestion' agent-system/extensions/present/agents/` shows only unavailability
  statements, no self-instructions, no tools-list advertisements.
- `grep -n '^tools:' agent-system/extensions/literature/agents/literature-agent.md` shows
  `Bash, Read, Write, Edit` with no `AskUserQuestion`.
- In both present SKILL.md files, every `AskUserQuestion` line number is less than the line number
  of the `Agent`-tool dispatch stage. *(deviation: altered — holds for `skill-slide-planning`
  (ask-then-delegate); `skill-slide-critic` dispatches first and runs its interactive loop after
  the dispatch returns (ask-after-delegate) — both place the asking in the skill's own execution,
  never the agent, which is the property that actually matters. See phase-5-progress.json.)*
- `REPO_ROOT=$(pwd) timeout 300 bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
  reports no new failure.

---

### Phase 6: Land the structural regression fixture [COMPLETED]

**Goal**: a `core/scripts/tests/test-*.sh` fixture encodes the fix's postconditions, and the record
states plainly that a shell fixture is not a harness re-verification.

**Tasks**:
- [x] Write `core/scripts/tests/test-askuserquestion-rehome.sh` following
      `context/standards/shell-script-testing.md`'s convention and the structural model of
      `test-check-task-references.sh` (grep-based assertions) crossed with
      `test-status-vocabulary.sh` (PASS/FAIL counters): `set -uo pipefail`,
      `SCRIPT_DIR`-relative resolution, `pass()`/`fail()`/`info()`, `PASSED`/`FAILED` counters,
      exit 0 on all-pass, 1 on any fail, 2 on environment error.
- [x] Assert: **no agent file under `agent-system/extensions/*/agents/**` instructs itself to call
      `AskUserQuestion`.** Match the instructing phrasings (an imperative "Use AskUserQuestion",
      a "via AskUserQuestion" directive, a tools-list entry) while admitting lines that state the
      tool is unavailable to a dispatched subagent — the `cslib-vet-agent.md` `MUST NOT` phrasing
      is the admitted form, and the fixture must pass against that file unchanged.
- [x] Assert: `skill-meta/SKILL.md`'s `allowed-tools:` line includes `AskUserQuestion`.
- [x] Assert: `core/context/workflows/meta-interview.md` exists and is referenced from
      `skill-meta/SKILL.md`.
- [x] Assert: no "inherit the full tool set" / "inherits the full" claim remains in
      `agent-frontmatter-standard.md` or `agent-template.md` without the measured exception within
      a bounded window of the same line.
- [x] Assert: the `isolation` branch chosen in Phase 1 holds — no `isolation` row in the Supported
      Fields table, no `["isolation"]=1` in `lint-agent-contracts.sh`'s `SUPPORTED_KEYS`, and the
      justifying probe record present in the standard.
- [x] Assert, as a structural guard on the two confirmed-unaffected skills: `skill-spawn/SKILL.md`
      and `skill-fix-it/SKILL.md` still declare no `agent:` frontmatter field, so their
      `AskUserQuestion` calls keep running in the skill's own execution.
- [x] Assert the removal layer stays absent:
      `grep -rln 'dispatch-worktree.sh\|task_selected_for_worktree_isolation' agent-system/`
      returns nothing.
- [x] Write a header comment stating explicitly that this fixture protects the **fix**, not the
      harness fact: the reachability measurement can only be re-confirmed by a live dispatch probe
      (`ToolSearch` with `select:AskUserQuestion` inside a dispatched subagent), and a future
      reader must not mistake a green run here for a harness re-verification. Point at
      `agent-frontmatter-standard.md`'s corrected section.
- [x] No `run-all.sh` edit: it auto-discovers `scripts/tests/test-*.sh` by glob. No
      `suite-cost-hints.txt` edit either: it is advisory-only and is a concurrent sibling's
      declared target. Confirm discovery with
      `timeout 600 bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet --jobs 4`
      only if time permits — the targeted direct run below is the binding check.

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this plan asserts one new test file and no edit to `run-all.sh` or
`suite-cost-hints.txt`. Confirm the glob discovery claim at implementation time by checking that
`run-all.sh`'s discovery loop still globs `"$ext_scripts/tests"/test-*.sh` with no manifest or
list to register in.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-askuserquestion-rehome.sh` - NEW: structural regression fixture asserting the fix's postconditions, with a header stating it is not a harness re-verification

**Verification**:
- `timeout 300 bash agent-system/extensions/core/scripts/tests/test-askuserquestion-rehome.sh`
  exits 0 with every case PASS (foreground, output redirected to a file).
- The fixture passes against `cslib-vet-agent.md` unchanged, proving the
  "documents-the-absence" exemption works rather than forcing a needless edit.
- Deliberate-regression spot check: temporarily reintroduce one instructing line in a scratch copy
  and confirm the fixture FAILS, so the assertion is not vacuous. Revert the scratch change.
- `bash -n agent-system/extensions/core/scripts/tests/test-askuserquestion-rehome.sh` parses clean.

---

### Phase 7: Narrow file_scope, regenerate, and run the full gate set [NOT STARTED]

**Goal**: this task's `file_scope` names explicit files, the deployed tree reflects the source
edits, the full gate set is green, and the one check no dispatched agent can take is handed off
honestly.

**Tasks**:
- [ ] Re-read project 300's `file_scope` from `specs/state.json` and compose the explicit
      replacement: the union of every path in Phases 1-6's `Files to modify` lists. Drop the three
      coarse directory entries (`core/scripts/tests/`, `epidemiology/agents/`, `founder/agents/`,
      `present/agents/`) and the two confirmed-unaffected files
      (`core/skills/skill-spawn/SKILL.md`, `core/skills/skill-fix-it/SKILL.md`).
- [ ] Apply the narrowing through the sanctioned single writer — a `state-write.sh` jq filter
      scoped to `project_number == 300`'s `file_scope`, never a hand-rolled
      `jq ... > tmp && mv`, and never a wholesale `.artifacts` assignment:
      `bash .claude/scripts/state-write.sh '<filter>' --session-id "$session_id" --argjson scope '<json-array>'`.
      Note that the plan-postflight harvest uses `--file-scope-add` (additive), so the coarse
      entries do **not** disappear on their own; this explicit narrowing is what clears the
      warning.
- [ ] `timeout 240 bash .claude/scripts/validate-state.sh --deep` and confirm no coarse-scope
      warning names project 300. Confirm the other standing warnings are unchanged — a *new*
      warning anywhere is a real finding.
- [ ] Regenerate the deployed tree so `/meta` and the `.claude/` gates see the corrected sources:
      `timeout 600 bash .claude/scripts/deploy-headless.sh`. This is the sanctioned headless path;
      it is non-destructive by default.
- [ ] `timeout 3000 bash .claude/scripts/verify-deploy.sh` in the **foreground**, output
      redirected to a file, then read the file. Do not background it and do not arm a waiter.
- [ ] If Gate 8 (`tests/run-all.sh`) does not conclude inside the dispatch budget, record a
      `#### Reasoned Exclusions` subsection on this phase per plan-format.md and mark the heading
      `[COMPLETED WITH EXCLUSIONS]`, with the targeted direct runs below as the Evidence column:
      `test-askuserquestion-rehome.sh`, `test-lint-agent-contracts.sh`,
      `test-index-entries-schema.sh`, `test-check-task-references.sh`. Exclude Gate 8 only, never
      a gate that did conclude.
- [ ] `timeout 300 bash .claude/scripts/check-task-references.sh` — confirm no task-number
      citation leaked into any source-store file this task wrote. The two separately-tracked
      defect scripts are cited by path and defect only.
- [ ] Hand off the one acceptance check no dispatched agent can take: **`/meta` with no arguments
      completes a real interview and creates a task.** A dispatched subagent cannot call
      `AskUserQuestion` — that is the fact this task fixes — so this must be run by the primary
      session or the user after the redeploy. Report it as not-self-verified; do not claim it.

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this plan asserts that the narrowed `file_scope` is exactly the union of
Phases 1-6's `Files to modify` paths, and that removing the coarse `scripts/tests/` entry is
sufficient to clear the only coarse-scope warning naming this task (the other three directory
entries did not overlap any non-terminal task at plan time, but are narrowed anyway). Re-measure
with `validate-state.sh --deep` before and after rather than assuming.

**Files to modify**:
None in the source store. This phase mutates `specs/state.json`'s `file_scope` for this task
through `state-write.sh`, regenerates the deployed tree, and runs the gates.

**Verification**:
- `timeout 240 bash .claude/scripts/validate-state.sh --deep` reports no coarse `file_scope`
  warning for project 300 and no new warning or failure anywhere.
- `timeout 3000 bash .claude/scripts/verify-deploy.sh` completes with no finding attributable to
  this task's edits (or, for Gate 8 alone, a recorded Reasoned Exclusion with the targeted-suite
  evidence).
- `grep -rln 'dispatch-worktree.sh\|task_selected_for_worktree_isolation' agent-system/` returns
  nothing.
- `git diff --stat` touches no path outside this plan's declared file lists — in particular
  neither `core/scripts/git-commit-scoped.sh` nor `core/scripts/lake-build-guard.sh`.
- The live `/meta` interview check is explicitly reported as primary-session/user-owned and
  not-self-verified.

---

## Testing & Validation

- [ ] `timeout 300 bash agent-system/extensions/core/scripts/tests/test-askuserquestion-rehome.sh`
      — every case PASS, including passing unchanged against `cslib-vet-agent.md`.
- [ ] `timeout 300 bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh`
- [ ] `timeout 300 bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh`
- [ ] `REPO_ROOT=$(pwd) timeout 300 bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
      — no new warning or failure, Check A included.
- [ ] `timeout 300 bash .claude/scripts/check-task-references.sh` — no task-number citation in any
      source-store file written by this task.
- [ ] `timeout 240 bash .claude/scripts/validate-state.sh --deep` — no coarse-scope warning for
      this task; no new warning elsewhere.
- [ ] `timeout 3000 bash .claude/scripts/verify-deploy.sh` — full gate set, foreground, output to a
      file; Gate 8 excluded only with a recorded Reasoned Exclusion and per-suite evidence.
- [ ] `grep -rn 'AskUserQuestion' --include='*.md' agent-system/extensions/*/agents/` — every
      remaining hit states the tool is unavailable to a dispatched subagent.
- [ ] **Primary-session- or user-owned, not self-verifiable by a dispatched agent**: `/meta` with
      no arguments completes a real interview and creates a task, after the Phase 7 redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/context/workflows/meta-interview.md` (new) — the relocated
  interview workflow.
- `agent-system/extensions/core/scripts/tests/test-askuserquestion-rehome.sh` (new) — the
  deliverable structural fixture.
- Corrected: `agent-frontmatter-standard.md`, `agent-template.md`, `lint-agent-contracts.sh`,
  `fork-patterns.md`, `skill-meta/SKILL.md`, `index-entries.json`, `meta-builder-agent.md`,
  14 founder/epidemiology agent files, 7 present agent files, 2 present SKILL.md files,
  `literature-agent.md`.
- `specs/state.json` — project 300's `file_scope` narrowed to explicit files.
- An execution summary under `specs/300_askuserquestion_unreachable_in_subagents/summaries/`.

## Rollback/Contingency

Every phase commits per green sub-step, so the unit of rollback is a commit, not the working tree:
revert the offending phase's commits and leave earlier phases standing. Phases 1, 4, 5 and 6 are
independently revertible. Phases 2 and 3 are a pair — reverting Phase 3 alone leaves
`meta-builder-agent.md` mandating an interview whose text now lives elsewhere, so revert both or
neither.

If an intentional rollback would discard uncommitted work, take the snapshot first per
`context/contracts/recovery.md`'s rollback rung (which names the invocation shape, including its
out-of-scope override flag for the deliberate whole-tree case), then run the destructive command.
For an ordinary defensive checkpoint before the Phase 2/3 pair — the largest single body of moved
text — use `git-snapshot.sh --no-revert`, which is durable without reverting the working tree;
never the bare reverting default as a routine precaution.

Phase 7's `file_scope` narrowing is reversible by a second `state-write.sh` invocation restoring
the prior array; the prior value is recoverable from git history of `specs/state.json`.
