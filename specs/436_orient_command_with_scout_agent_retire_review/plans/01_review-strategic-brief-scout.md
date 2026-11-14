# Implementation Plan: Task #436

- **Task**: 436 - Add a strategic-brief capability to `/review`, backed by a new read-only scout agent
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/436_orient_command_with_scout_agent_retire_review/reports/01_review-strategic-brief-scout.md
- **Artifacts**: plans/01_review-strategic-brief-scout.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add one new read-only agent (`scout-agent.md`) to the core extension's source store and one new
early-exit mode to `/review` that dispatches it, so the question "where are we against the stated
aim, and what next" has an on-demand answering surface without introducing a new command. The
agent is read-only by construction (no `Write`, no `Edit` in frontmatter) and console-only (it
writes no `.return-meta.json` and no report artifact), which places it in the same lint
classification as `code-reviewer-agent.md` and `roadmap-agent.md` and therefore requires three
curated exclusion-array entries in `lint-agent-contracts.sh`. Every edit lands in
`agent-system/extensions/core/` per the source-store/deploy boundary, and the deployed tree is
regenerated once at the end via `deploy-headless.sh`.

### Premise Re-Validation (Carried-Figure Discipline)

Every line the dispatch flagged was re-derived against live state at plan-authoring time; results
stated explicitly even where they only confirm the description:

- **`conclusion-stage.md`, 498 lines** — CONFIRMED unchanged. `wc -l` reports 498 for both
  `agent-system/extensions/core/context/contracts/conclusion-stage.md` and the deployed
  `.claude/context/contracts/conclusion-stage.md` (source and deploy in sync).
- **`MAX_BATCH_OPTIONS` (3)** — CONFIRMED. `orchestrate-suggest-next-batch.sh:251` reads
  `MAX_BATCH_OPTIONS=3`.
- **EDIT TARGET / `source_dir` resolution** — CONFIRMED. `.claude-extensions.json` resolves
  `extensions.core.source_dir` to `/home/benjamin/.config/nvim/agent-system/extensions/core`, so
  the mirroring source-store paths named throughout this plan are the correct edit targets and
  `.claude/**` is never hand-authored.
- **"Cite durable anchors only ... never task numbers"** — CONFIRMED live:
  `.claude/rules/no-task-references-in-deliverables.md` exists and exempts only `specs/**`, git
  commit messages, and PR/branch metadata. Every deliverable this plan produces is outside
  `specs/**`, so no task number may appear in any of them.
- **"The scout cannot write: no Write and no Edit in its frontmatter"** — this is an acceptance
  criterion, not a carried measurement; it is discharged by Phase 1's authoring and re-checked
  mechanically in Phase 5.
- **PURPOSE section's Lean/`FormalSystem` anchors** — CONFIRMED ABSENT in this repository:
  no `FormalSystem/` tree, and no
  `agent-system/extensions/core/scripts/check-evidence-probes.sh` (it is declared only as a
  manifest `external_scripts` entry, i.e. expected-but-optional per consumer repo). The "37 wired
  probes" figure is therefore CARRIED-UNVERIFIED from the task description, sourced from a
  different consumer repository, and is deliberately **not** reproduced in any deliverable. The
  four universally-present inputs ARE confirmed present here: `specs/ROADMAP.md`,
  `specs/TODO.md`, `specs/state.json`, `specs/CHANGE_LOG.md`.

### Research Integration

The research report is adopted in full with one correction and one narrowing:

- **Adopted**: the authoritative-scope finding (extend `/review` in place; build no `/orient`;
  keep `code-reviewer-agent`), the `tools:` (not `allowed-tools:`) frontmatter spelling, the
  `Bash`-is-not-read-only hazard and its body-level mitigation, the filename constraint (avoid
  the substrings `research`/`implementation` so `lint-agent-contracts.sh` Check N's
  forced-membership nets never apply), the `manifest.json` `provides.agents` requirement, and the
  conditional-probe design for domain-specific authority artifacts.
- **CORRECTION — three exclusion arrays, not two.** The report named
  `EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS` (Check F) and `CHECK_J_EXCLUDED_RELATIVE_PATHS`
  (Check J). Re-reading `lint-agent-contracts.sh` at plan time shows **Check E**
  (terminal-metadata status presence, `check_e_terminal_metadata_presence` at line 543) also runs
  over the full `enumerate_dispatchable_agents` population and FAILs any file carrying no
  canonical non-`in_progress` `"status":` value unless listed in
  `EXCLUDED_TERMINAL_STATUS_RELATIVE_PATHS` (line 525). A console-only agent carries no such
  value, so a third array entry is required. Both `code-reviewer-agent.md` and
  `roadmap-agent.md` are already in all three arrays — exact precedent.
- **NARROWING — `index-entries.json`.** The report found no mechanical requirement for an
  `index-entries.json` change and no precedent for indexing an agent file. This plan therefore
  satisfies Deliverable 3's `index-entries.json` half with one *genuinely justified* edit rather
  than a decorative entry: add `scout-agent` to the `load_when.agents` array of the existing
  `formats/roadmap-format.md` entry (302 lines), the one indexed doc the scout actually needs in
  order to read `specs/ROADMAP.md`'s structure correctly. The scout is deliberately NOT added to
  `standards/analysis-framework.md` or `workflows/review-process.md` (`code-reviewer-agent`'s
  code-review context — wrong domain for an orientation brief).

### Prior Plan Reference

No prior plan. `prior_plan_path` was not provided and `plans/` was empty at authoring time.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are included (`roadmap_flag` absent). `specs/ROADMAP.md`
exists in this repository but is read-only subject matter for the scout, never a maintenance
target of this plan — see Non-Goals.

## Goals & Non-Goals

**Goals**:

- A new read-only, console-only agent at `agent-system/extensions/core/agents/scout-agent.md`
  whose frontmatter carries `Read, Grep, Glob, Bash` and contains neither `Write` nor `Edit`.
- The agent body specifies the five required brief sections in order, the HARD REQUIREMENTS, the
  four-way `SETTLED` / `LANDED-AT-ONE-FIXTURE` / `CARRIED-UNVERIFIED` / `OPEN` labelling for
  section (3), and an explicit prohibition on mutating any file through `Bash`.
- A strategic-brief mode in `agent-system/extensions/core/commands/review.md` that dispatches the
  scout and renders its returned brief to the user in conversation, short-circuiting before
  `/review`'s existing code-review machinery.
- `provides.agents` registration in core's `manifest.json`, plus the three
  `lint-agent-contracts.sh` exclusion-array entries that keep Checks E, F and J green.
- `code-reviewer-agent` left fully in place with every registry consumer intact.
- One regeneration of the deployed tree via `deploy-headless.sh`; no hand-patch of `.claude/**`.

**Non-Goals**:

- No `/orient` command, no `skills/skill-orient/` directory, and no retirement of `/review` or of
  `code-reviewer-agent`. The task's `title` field in `specs/state.json` still carries that
  superseded shape; the dispatch `## Description` is authoritative and is what this plan
  implements. Correcting the title is `/revise`'s or a later `/todo` pass's work, not this plan's.
- No `roadmap-integration.sh --regenerate` call in `review.md`. That is Deliverable 1 of the
  `wire_todo_review_roadmap_regenerate` record; re-verified at plan time that `review.md` contains
  zero occurrences of `roadmap-integration.sh`, and this plan adds none.
- No ROADMAP or CHANGE_LOG maintenance. The scout reports on their state and stops there; if its
  section (3) surfaces stale content it says so and does not repair it.
- No new entry in `routing_agents`. That block is keyed by lifecycle phase then task type; the
  scout is not a lifecycle-phase agent and must not claim a task-type route.
- No addition of the scout to `validate-context-budgets.sh`'s `CAPS` array or
  `validate-index.sh`'s budget-print loop. Both are hardcoded, informational-or-opt-in lists that
  do not force inclusion, and nothing in the acceptance criteria asks for it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Checks E, F or J fail because the new agent is not in the matching exclusion array, and `lint-agent-contracts.sh` is outside the dispatch's stated FILE SCOPE | H | H | Phase 2 treats the three array edits as a necessary, explicit extension of scope — the alternative contradicts the named acceptance bullet. Each entry carries the same justification shape already recorded for `code-reviewer-agent.md`. |
| `Bash` in `tools:` silently defeats "read-only by construction" (shell redirection, `sed -i`, `cp`, `tee` all still mutate) | H | M | Phase 1 writes an explicit MUST NOT bullet forbidding every file-mutating `Bash` form by name, following the precedent `general-research-agent.md` sets for its own unrestricted-`Bash` exposure. Phase 5 greps the finished file to confirm both the frontmatter absence and the prose presence. |
| The domain-specific authority paths in the task description are hardcoded into a `core` file shared by every consumer repo, producing a scout that errors or misleads everywhere those paths are absent | H | M | Phase 1 specifies existence-conditional probing only; the four universally-present `specs/**` inputs are read unconditionally, everything else is `[[ -f ]]`/`grep`-guarded with graceful "absent" reporting. This repository, which has none of them, is the regression fixture. |
| Check E's requirement is missed because the research report named only two arrays | M | M | Already corrected above and encoded as Phase 2's Scope Hypothesis, with a before/after lint run as the confirmation. |
| The stale `file_scope` on this task (naming `commands/orient.md`, `skills/skill-orient/SKILL.md`, `agents/scout-agent.md`, `merge-sources/claudemd.md`) misdirects a concurrency or staging guard | M | M | Phase 5's harvest supersedes it from this plan's own `Files to modify` blocks. Note that `agents/scout-agent.md` and `merge-sources/claudemd.md` are retained deliberately by this plan, so the overlap is partly real, not wholly stale. |
| Declaring `__WHOLE_TREE__` makes this task's `file_scope` overlap every other held task lock, so one unreleased foreign lock becomes a total dispatch block | M | M | Accepted, not avoided: the sentinel is mandatory for a phase that invokes whole-tree regeneration, and substituting a real wide path would trip `validate-state.sh` Check 8 and loosen `path_covered_by_scope()`. Mitigation is scheduling — Phase 5 is the only phase carrying it, so the window is one phase wide. |
| Concurrent-write overlap on `commands/review.md` with the `wire_todo_review_roadmap_regenerate` record | M | M | Ordinary overlap with disjoint deliverables; resolve by batching the two or adding an ordering edge via `update-task-status.sh --depends-on-add`, not by excluding either. |
| `index-entries.json`'s new `load_when.agents` member trips `validate-context-budgets.sh`'s Double-Loading Check | L | L | Phase 4's Scope Hypothesis names this as the thing to confirm; Phase 5 runs the validator. If it flags, drop the `index-entries.json` edit and record the reason — the entry is a convenience, not an acceptance requirement. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 3 |
| 4 | 5 | 2, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Author the Read-Only Scout Agent Definition [COMPLETED]

**Goal**: Create the scout agent file so that it is read-only by construction, console-only by
design, portable across consumer repositories, and compliant with every unconditional
`lint-agent-contracts.sh` check that applies to it on sight (A, B, K).

**Tasks**:

- [x] Create `agent-system/extensions/core/agents/scout-agent.md`. Use the name `scout-agent` and
      the filename `scout-agent.md` — it contains neither `research` nor `implementation`, so
      Check N's two forced-membership nets (`*implementation*agent.md`, `*research*agent.md`) do
      not reach it, and it already matches an entry in this task's existing `file_scope`.
      *(completed)*
- [x] Write the frontmatter with exactly these keys: `name: scout-agent`, a one-line
      `description:`, `tools: Read, Grep, Glob, Bash`, `model: sonnet`. Use `tools:` — NOT
      `allowed-tools:`, which Check A hard-FAILs as an unsupported key. `model:` is required by
      Check B. Neither `Write` nor `Edit` appears anywhere in the frontmatter. *(completed)*
- [x] Write the body's brief specification: the five REQUIRED SECTIONS in order — (1) WHAT
      HAPPENED, verdict-first; (2) WHY, so a refutation reads as a result; (3) WHERE WE ARE,
      labelling every item `SETTLED` / `LANDED-AT-ONE-FIXTURE` / `CARRIED-UNVERIFIED` / `OPEN`;
      (4) GAINS AND LOSSES, explicitly both; (5) NEXT STRATEGIC GOALS, naming the critical path,
      what gates what, and the cheapest next move. State that none may be omitted and each is
      ruthlessly compressed. *(completed)*
- [x] Write the HARD REQUIREMENTS as MUST / MUST NOT bullets: waste no words and omit nothing
      essential; cite durable anchors only (declaration name, filename, section heading, probe
      name) and never a task number, per `rules/no-task-references-in-deliverables.md`; never
      conflate a SETTLED THEOREM with a LANDED-AT-ONE-FIXTURE result or a CARRIED-UNVERIFIED
      figure; never present a refutation as a failure; point at an authority document's
      guardrails rather than restating them; return the brief to the user in conversation rather
      than producing another artifact. *(completed)*
- [x] Add the read-only MUST NOT bullet: the agent MUST NOT mutate any file through `Bash` —
      naming the forms explicitly (`>`/`>>` redirection, `sed -i`, `tee`, `cp`, `mv`, `rm`,
      `mkdir`, `git` commands that write) — and MUST NOT create, edit, or delete any file by any
      route. `Bash` exists solely to run `jq` and read-only repository probe scripts. *(completed)*
- [x] Add the input-discovery section: read `specs/ROADMAP.md`, `specs/TODO.md`,
      `specs/state.json` and `specs/CHANGE_LOG.md` unconditionally (all four confirmed present
      here), and probe for every repository-specific authority artifact — an authority README's
      verdict table, a do-not-re-attempt register, an evidence-probe collection script —
      existence-conditionally (`[[ -f ]]` guarded), reporting absence as absence rather than
      erroring. Hardcode no repository-specific path. *(completed)*
- [x] Add the stop-at-reporting scope boundary: the scout REPORTS on `ROADMAP.md` and
      `CHANGE_LOG.md` state and MAINTAINS neither; if section (3) surfaces stale content it says
      so and stops. *(completed)*
- [x] Add the return contract: a console-only bullet-point return to the caller, no
      `.return-meta.json`, no `.orchestrator-handoff.json`, no report artifact — the same shape
      `code-reviewer-agent.md` already uses. *(completed)*
- [x] Verify by diff read-through that the finished file pairs no backgrounding instruction with
      a wait-for-notification instruction (Check K is an absence check over every dispatchable
      agent and needs only that the antipattern never be written). *(completed: no such
      instruction written anywhere in the file)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Tier Justification**: `suite_selection_select` returns the sentinel `__FULL_SWEEP__` for
`agent-system/extensions/core/agents/scout-agent.md`, so no suite covers this file; the honest
covering check for this source-store non-`specs/**` markdown path (sub-case b) is
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`,
run alongside the diff read-through this tier prescribes.

**Files to modify**:

- `agent-system/extensions/core/agents/scout-agent.md` - CREATE. New read-only scout agent
  definition; confirmed absent at authoring time, so this is a creation target carrying no
  existence obligation. If a file is unexpectedly already present at this path, read it first and
  extend rather than overwrite, and record the deviation.

**Verification**:

- `grep -nE '^(tools|model|name):' agent-system/extensions/core/agents/scout-agent.md` shows all
  three keys, with `tools:` spelled exactly that way.
- `sed -n '1,/^---$/p'` over the file (the frontmatter block only) contains zero occurrences of
  `Write` and zero of `Edit`.
- The body contains all five section headings in order, and the four label tokens `SETTLED`,
  `LANDED-AT-ONE-FIXTURE`, `CARRIED-UNVERIFIED`, `OPEN`.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with both gates actually running (not SKIP).

---

### Phase 2: Record the Three Lint Exclusions [COMPLETED]

**Goal**: Add the new agent's relative path to each of `lint-agent-contracts.sh`'s three curated
exclusion arrays that a console-only, forked-dispatch-only agent requires, so Checks E, F and J
pass on their recorded merits rather than demanding contracts the scout structurally cannot
carry.

**Tasks**:

- [x] Run `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` first, with
      Phase 1's file in place, and capture the exact set of FAIL lines naming
      `agent-system/extensions/core/agents/scout-agent.md`. This is the confirmation step for
      this phase's Scope Hypothesis — do not assume the set. *(completed: confirmed exactly three
      FAIL lines, naming Checks E, F and J — matching the Scope Hypothesis exactly, no fourth
      check)*
- [x] Add `"agent-system/extensions/core/agents/scout-agent.md"` to
      `EXCLUDED_TERMINAL_STATUS_RELATIVE_PATHS` (Check E, array at line 525), with a comment in
      the established shape recording that the file carries no `"status":` value anywhere because
      it writes no terminal metadata at all — the same justification already recorded for
      `code-reviewer-agent.md` and `roadmap-agent.md`. *(completed)*
- [x] Add the same path to `EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS` (Check F, array at line
      392), with the recorded justification "console-only bullet-summary return, no file-based
      metadata exchange anywhere in the file". *(completed)*
- [x] Add the same path to `CHECK_J_EXCLUDED_RELATIVE_PATHS` (Check J, array at line 919), with
      the recorded justification "dispatched directly from `/review`'s own command body via the
      Agent tool; never reached through a `skill-orchestrate` `dispatch[]`/`aux_dispatch[]` row,
      so `orchestrator_mode` never applies and no handoff-writing section is ever required".
      *(completed)*
- [x] Confirm the file contains zero occurrences of `.orchestrator-handoff.json` and zero
      recognized handoff-writing heading — Check J's own inverted-drift guard FAILs any exclusion
      entry whose file later acquires one. *(completed: two prose mentions in scout-agent.md were
      rewritten to avoid the literal string entirely, even though the exclusion array entry alone
      would already short-circuit the grep via is_excluded_from_check_j's continue)*
- [x] Re-run the lint and confirm zero FAIL lines naming the new path. *(completed: lint-agent-contracts.sh
      exits 0, scout-agent.md logged only as PASS (Check K) and as a recorded exclusion, no FAIL)*
- [x] Do NOT add the scout to `IN_SCOPE_RELATIVE_PATHS` (Check C),
      `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` (Check G), Check H's or Check L's or Check M's arrays.
      Those are curated inclusion lists; a file absent from them is simply not checked, and Check
      N's completeness nets reach only `*implementation*agent.md` and `*research*agent.md`.
      *(completed: confirmed not added to any of those arrays)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: THREE arrays need an entry (Checks E, F, J), not the two the research report
named (F, J) — the report at
`specs/436_orient_command_with_scout_agent_retire_review/reports/01_review-strategic-brief-scout.md`
omitted Check E. Re-derived at plan-authoring time by reading
`check_e_terminal_metadata_presence` (line 543) and `EXCLUDED_TERMINAL_STATUS_RELATIVE_PATHS`
(line 525) directly. Confirm at implementation time by the before-run in this phase's first task:
the FAIL set it prints is the authoritative list of arrays needing an entry, and if it names a
fourth check, add that array's entry too and record the deviation.

**Tier Justification**: `suite_selection_select` for
`agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` returns exactly
`test-askuserquestion-rehome.sh test-deploy-baseline-lib.sh test-gate-cache-equivalence.sh test-gate-cache-lib.sh test-lint-agent-contracts-await-notification.sh test-lint-agent-contracts-handoff-section.sh test-lint-agent-contracts-heartbeat.sh test-lint-agent-contracts.sh test-run-all-selection.sh test-verify-deploy-context-budget.sh`,
so the covering check is
`bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-askuserquestion-rehome.sh,test-deploy-baseline-lib.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh,test-lint-agent-contracts-await-notification.sh,test-lint-agent-contracts-handoff-section.sh,test-lint-agent-contracts-heartbeat.sh,test-lint-agent-contracts.sh,test-run-all-selection.sh,test-verify-deploy-context-budget.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - AMEND an existing file,
  confirmed present at authoring time (1400+ lines, all three target arrays located at lines 525,
  392 and 919). Add one array entry plus its justification comment to each of the three arrays. If
  an array has been renamed or removed by the time this phase runs, re-derive the current array
  names from the failing check's own FAIL message, which names the array it wants the entry added
  to, and record the deviation.

**Verification**:

- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0, with Checks E,
  F and J each logging the new path as a recorded exclusion rather than a FAIL.
- `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-askuserquestion-rehome.sh,test-deploy-baseline-lib.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh,test-lint-agent-contracts-await-notification.sh,test-lint-agent-contracts-handoff-section.sh,test-lint-agent-contracts-heartbeat.sh,test-lint-agent-contracts.sh,test-run-all-selection.sh,test-verify-deploy-context-budget.sh`
  passes.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` reports no new finding for
  the edited file.

---

### Phase 3: Add the Strategic-Brief Mode to /review [NOT STARTED]

**Goal**: Give `/review` an explicit, early-exit strategic-brief mode that dispatches the scout
and renders its returned brief to the user in conversation, without touching the existing
code-review workflow and without adding the roadmap-regeneration call that belongs to another
record.

**Tasks**:

- [ ] Add `Agent` to `review.md`'s `allowed-tools:` frontmatter line. `errors.md` already carries
      `Agent` in the same position, so this is an established spelling, not a new convention.
      Without it the command cannot dispatch a subagent at all.
- [ ] Extend the `argument-hint:` frontmatter to advertise the new flag:
      `"[SCOPE] [--create-tasks] [--brief]"`.
- [ ] In `## Arguments`, document `--brief` as requesting the strategic orientation brief instead
      of a code review, and state that it is mutually exclusive with `--create-tasks` and ignores
      `SCOPE`.
- [ ] Insert a new `### 1.1. Strategic-Brief Mode (early exit)` section immediately after
      `### 1. Parse Arguments` and BEFORE `### 1.5. Load Review State`, so the brief path never
      initializes review state, never writes `specs/reviews/state.json`, never creates tasks, and
      never reaches the git-commit section.
- [ ] In that section, specify the dispatch: use the `Agent` tool with `subagent_type:
      scout-agent`, a prompt stating the repository root and the five required sections, and no
      write-capable instruction. State that exactly one scout is dispatched per invocation.
- [ ] Specify the rendering: print the returned brief to the user in conversation as bullet
      points under the five section headings, verbatim in substance. Writing a file is the
      exception, not the default; if one is written at all it is a single short brief, never a
      full report, and never a `specs/reviews/` artifact.
- [ ] Add an explicit early-exit statement: after rendering, `/review` terminates — Sections 2
      through 8 do not run.
- [ ] Add a MUST NOT bullet in the new section: do not call `roadmap-integration.sh` from this
      path or any other path in `review.md`. That wiring is `wire_todo_review_roadmap_regenerate`'s
      Deliverable 1; re-confirm with `grep -c roadmap-integration.sh
      agent-system/extensions/core/commands/review.md` returning 0 after the edit, exactly as it
      does before it.
- [ ] Leave Sections 1.5 through 8 and the `## Standards Reference` block byte-identical.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Tier Justification**: `suite_selection_select` returns the sentinel `__FULL_SWEEP__` for
`agent-system/extensions/core/commands/review.md`, so no suite covers this file; the honest
covering check for this source-store non-`specs/**` markdown path (sub-case b) is
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`,
run alongside the diff read-through this tier prescribes.

**Files to modify**:

- `agent-system/extensions/core/commands/review.md` - AMEND an existing file, confirmed present at
  authoring time (833 lines; `allowed-tools:` on line 3, `### 1. Parse Arguments` on line 19,
  `### 1.5. Load Review State` on line 31). Add `Agent` to `allowed-tools`, extend
  `argument-hint`, document `--brief`, and insert the new Section 1.1. If the file's section
  numbering has shifted by the time this phase runs, anchor the insertion on the
  `### 1. Parse Arguments` heading text rather than on a line number, and record the deviation.

**Verification**:

- `grep -n '^allowed-tools:' agent-system/extensions/core/commands/review.md` shows `Agent`
  present.
- `grep -n 'scout-agent' agent-system/extensions/core/commands/review.md` shows the dispatch
  reference.
- `grep -c 'roadmap-integration.sh' agent-system/extensions/core/commands/review.md` returns 0.
- Diff read-through confirms every changed hunk lies in the frontmatter, the `## Arguments` list,
  or the newly inserted Section 1.1 — with no change inside Sections 1.5 through 8.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with both gates actually running.

---

### Phase 4: Registry and Documentation Wiring [NOT STARTED]

**Goal**: Register the scout in core's manifest so it deploys at all, give it the one indexed
context doc it genuinely needs, and bring the agent tables and the CLAUDE.md merge source into
line — without granting it a lifecycle route it does not have.

**Tasks**:

- [ ] Append `"scout-agent.md"` to `manifest.json`'s `provides.agents` array (currently 8
      entries, alphabetically ordered — insert in order). This is mandatory, not cosmetic:
      `check-extension-docs.sh` Rule J FAILs a deployed agent with no `provides.agents` source,
      and `deploy-headless.sh` copies agents from this array, so an unregistered file never
      deploys.
- [ ] Do NOT add anything to `manifest.json`'s `routing_agents` block. It is keyed by lifecycle
      phase (`research`/`plan`/`implement`) then task type; the scout is neither, and an entry
      there would wrongly claim a task-type route. Core carries `routing_exempt: true` and already
      has a non-empty `routing_agents`, so the existing
      "declares agents but has no routing_agents block" check is already satisfied.
- [ ] Add `"scout-agent"` to the `load_when.agents` array of `index-entries.json`'s existing
      `formats/roadmap-format.md` entry. Do not add, remove, or renumber any entry, and do not
      touch any `line_count` field — this edit changes no indexed file's content, so no
      `line_count` moves and `check-extension-docs.sh` Rule R is unaffected.
- [ ] Do NOT add the scout to `standards/analysis-framework.md`'s or
      `workflows/review-process.md`'s `load_when.agents` arrays. Those carry
      `code-reviewer-agent`'s code-review standards, which are the wrong domain for an
      orientation brief and would inflate the scout's composition for no benefit.
- [ ] Add a `| scout-agent.md | ... |` row to `agents/README.md`'s agent table, in the existing
      table's style and ordering.
- [ ] Add a matching row to `README.md`'s agent table and add `scout-agent.md` to the directory
      tree listing in the same file, next to the existing `code-reviewer-agent.md` lines.
- [ ] Update `merge-sources/claudemd.md`: the `/review` row in the command-reference table so it
      mentions the strategic-brief mode, and the `| /review | (direct execution) ... |` row in the
      skill-to-agent table so it names `scout-agent` for the brief alongside the existing
      `code-reviewer-agent` note. Keep both edits to one line each — the file is 284 lines and
      every line merges into the generated `.claude/CLAUDE.md`.
- [ ] Re-verify, before closing the phase, that `code-reviewer-agent` is untouched: still in
      `provides.agents`, still in the three `index-entries.json` `load_when.agents` rows, still in
      `validate-index.sh`'s budget loop, still in all three `lint-agent-contracts.sh` exclusion
      arrays, still in `validate-context-budgets.sh`'s `CAPS` at 8000, and still in both README
      tables.
- [ ] Confirm `jq empty` parses both edited JSON files before committing.

**Timing**: 1 hour

**Depends on**: 1, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly one `index-entries.json` edit (one array member
added to the existing `formats/roadmap-format.md` entry, 302 lines, `load_when.agents` currently
empty) and exactly one `manifest.json` edit (one array member appended to a `provides.agents`
array of 8 entries) — both counts re-derived with `jq` at plan-authoring time, not carried from
the research report. Confirm at implementation time with
`jq '.provides.agents | length' agent-system/extensions/core/manifest.json` returning 9 and
`jq -r '.entries[] | select(.path=="formats/roadmap-format.md") | .load_when.agents'
agent-system/extensions/core/index-entries.json` returning exactly `["scout-agent"]`. Separately
confirm that the new `load_when.agents` member does not trip
`validate-context-budgets.sh`'s Double-Loading Check; if it does, revert the
`index-entries.json` edit, record the reason, and rely on the `manifest.json` registration alone.

**Tier Justification**: `manifest.json`'s `provides.agents` is extension-system global
configuration that deploy composition, routing resolution and index generation all read, and
`suite_selection_select` maps this phase's five paths to a union of 44 distinct suites spanning
the deploy, routing, index-schema, gate-cache and state-validation machinery — a cross-cutting
surface no `--only` subset or `--only-gate` subset narrows honestly.

**Files to modify**:

- `agent-system/extensions/core/manifest.json` - AMEND an existing file, confirmed present with a
  `provides.agents` array of 8 entries and `routing_exempt: true`. Append the new agent filename
  to `provides.agents` only. If `provides.agents` is absent by the time this phase runs, stop and
  record a blocker rather than inventing the key — the deploy contract depends on it.
- `agent-system/extensions/core/index-entries.json` - AMEND an existing file, confirmed present
  with a `formats/roadmap-format.md` entry whose `load_when.agents` is empty. Add one array
  member. If that entry is absent by the time this phase runs, skip this edit entirely and record
  the reason; it is a convenience, not an acceptance requirement.
- `agent-system/extensions/core/agents/README.md` - AMEND an existing file, confirmed present with
  an agent table listing `code-reviewer-agent.md` at line 13. Add one table row. If the table is
  absent, add the row to whatever agent listing the file does carry and record the deviation.
- `agent-system/extensions/core/README.md` - AMEND an existing file, confirmed present with an
  agent table row at line 59 and a directory-tree entry at line 80. Add one table row and one
  tree line. If either structure is absent, add only the one that exists and record the deviation.
- `agent-system/extensions/core/merge-sources/claudemd.md` - AMEND an existing file, confirmed
  present (284 lines) with a `/review` command-table row at line 107 and a `/review`
  skill-to-agent row at line 175. Update both rows. If either row is absent, update only the one
  that exists and record the deviation.

**Verification**:

- `jq empty agent-system/extensions/core/manifest.json` and
  `jq empty agent-system/extensions/core/index-entries.json` both exit 0.
- `jq '.provides.agents | length' agent-system/extensions/core/manifest.json` returns 9, and the
  array still contains `code-reviewer-agent.md`.
- `jq -r '.routing_agents' agent-system/extensions/core/manifest.json` is byte-identical to its
  pre-edit value.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no new finding.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh` — the complete gate set this
  tier requires — exits 0.

---

### Phase 5: Redeploy and Full Acceptance Verification [NOT STARTED]

**Goal**: Regenerate the deployed tree from the edited source store and discharge every acceptance
criterion mechanically, including the three named validate/lint scripts that read the deployed
`.claude/context/index.json` and therefore cannot be checked before the deploy.

**Tasks**:

- [ ] Run the deploy with the bounded-wait idiom: `timeout 540 bash
      agent-system/extensions/core/scripts/deploy-headless.sh` with the Bash tool's own `timeout`
      raised to `600000`. Never hand-patch any file under `.claude/**`; the deploy is the only
      sanctioned writer there. Read `context/patterns/bounded-build-waiter.md` before backgrounding
      anything, and prefer the foreground bounded run above.
- [ ] Confirm the deploy landed the new agent: `.claude/agents/scout-agent.md` exists and its
      frontmatter matches the source file's.
- [ ] Run `bash .claude/scripts/validate-index.sh` and confirm exit 0 with no orphaned, missing,
      or duplicate entry introduced.
- [ ] Run `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` and confirm
      exit 0, with the scout logged as a recorded exclusion under Checks E, F and J and as a PASS
      under Checks A, B and K.
- [ ] Run `bash .claude/scripts/validate-context-budgets.sh` and confirm exit 0, including the
      Double-Loading Check against the new `load_when.agents` member.
- [ ] Verify the scout cannot write: the frontmatter block of
      `agent-system/extensions/core/agents/scout-agent.md` contains zero occurrences of `Write`
      and zero of `Edit`, and the body carries the explicit no-`Bash`-mutation MUST NOT bullet.
- [ ] Verify `/review` resolves and can dispatch the scout: `Agent` is present in the deployed
      `.claude/commands/review.md` `allowed-tools` line, the brief section references
      `scout-agent`, and `.claude/agents/scout-agent.md` exists so the `subagent_type` resolves.
- [ ] Verify the brief contract is fully specified: all five section headings and all four
      labelling tokens (`SETTLED`, `LANDED-AT-ONE-FIXTURE`, `CARRIED-UNVERIFIED`, `OPEN`) appear
      in the agent body.
- [ ] Re-verify `code-reviewer-agent` and every consumer named in the task description:
      `manifest.json`, `index-entries.json`, `validate-index.sh`,
      `lint/lint-agent-contracts.sh`, `validate-context-budgets.sh`, `agents/README.md`,
      `README.md`, and `docs/reference/standards/agent-frontmatter-standard.md`. All eight must
      still reference it.
- [ ] Confirm no task-number reference leaked into any deliverable:
      `bash .claude/scripts/check-task-references.sh` over the edited paths exits clean (every
      file this plan touches is outside `specs/**`, so none is exempt).
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`, and confirm exit 0 with
      no gate reporting zero checks under a filter.

**Timing**: 1 hour

**Depends on**: 2, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`, which is
  an implicit scope claim over the entire deployed tree that no real declared path can express.
  Declared with the reserved slashless sentinel per plan-format.md's whole-tree-claim declaration
  rule, so `orchestrate-batch-admit.sh`'s `whole_tree_claim` admission dimension can serialize
  this task against another whole-tree regenerator. No real `.claude/**` path is declared here,
  and none may be: `.claude/` is a disposable deploy artifact and
  `plan-file-scope-harvest.sh` refuses any entry naming a path under it.

**Verification**:

- `timeout 540 bash agent-system/extensions/core/scripts/deploy-headless.sh` exits 0.
- `bash .claude/scripts/validate-index.sh` exits 0.
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0.
- `bash .claude/scripts/validate-context-budgets.sh` exits 0.
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set, not a subset.
- `grep -c -E '\b(Write|Edit)\b'` over the scout's frontmatter block returns 0.
- `grep -l code-reviewer-agent` finds all eight named consumers.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0 with the
      scout classified under Checks E, F and J and passing A, B, K.
- [ ] `bash .claude/scripts/validate-index.sh` exits 0.
- [ ] `bash .claude/scripts/validate-context-budgets.sh` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no new finding.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0.
- [ ] The scout's frontmatter contains no `Write` and no `Edit`.
- [ ] The scout's body specifies all five brief sections and the four-way labelling.
- [ ] `/review --brief` resolves: `Agent` in `allowed-tools`, `scout-agent` referenced,
      `.claude/agents/scout-agent.md` deployed.
- [ ] `grep -c roadmap-integration.sh agent-system/extensions/core/commands/review.md` returns 0.
- [ ] `code-reviewer-agent` is present and referenced by all eight consumers.
- [ ] No `.claude/**` file was hand-edited; the deployed tree came only from `deploy-headless.sh`.

## Artifacts & Outputs

- `agent-system/extensions/core/agents/scout-agent.md` — the new read-only, console-only scout
  agent definition.
- An amended `agent-system/extensions/core/commands/review.md` carrying the strategic-brief mode.
- Amended core registries: `manifest.json` (`provides.agents`) and `index-entries.json`
  (one `load_when.agents` member).
- Amended `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` with three recorded
  exclusion entries.
- Amended documentation: `agents/README.md`, `README.md`, `merge-sources/claudemd.md`.
- A regenerated `.claude/` deploy tree (a build output, not a tracked deliverable).

## Rollback/Contingency

The source-store edits are small, additive, and confined to seven files, so rollback is a revert
of this task's own commits followed by one re-run of `timeout 540 bash
agent-system/extensions/core/scripts/deploy-headless.sh` to regenerate `.claude/` from the
reverted source. Nothing under `.claude/**` needs manual repair, because it is a disposable
artifact rebuilt wholly from the source store.

Phase-level contingencies:

- If `lint-agent-contracts.sh` names a check beyond E, F and J (Phase 2's Scope Hypothesis), add
  that array's entry in the same phase and record the deviation — do not leave a check red and do
  not weaken the lint.
- If `validate-context-budgets.sh`'s Double-Loading Check flags the new `load_when.agents` member,
  revert only the `index-entries.json` edit and record the reason. The `manifest.json`
  registration alone satisfies the deploy contract; the index edit is a convenience.
- If the deploy exceeds its 540-second bound, do not retry blindly: read
  `context/patterns/bounded-build-waiter.md`, capture the partial output, record an
  `issue-record.sh` entry, and mark the phase `[PARTIAL]` with the deploy as the resume point.
- Before any intentional rollback that would discard uncommitted work, run
  `bash .claude/scripts/git-snapshot.sh 436` first. Do not emit that command as a routine
  start-of-phase checkpoint; use `--no-revert` for an ordinary defensive checkpoint.
