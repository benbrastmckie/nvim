# Research Report: Task #334

**Task**: 334 - Fix two books-extension scaffold contract defects: the hard implementation
agent's artifacts shape and hand-rolled task lookups in both hard skills
**Started**: 2026-10-03T22:08:00Z
**Completed**: 2026-10-03T22:30:00Z
**Effort**: Small (3 files, mechanical fixes, well-precedented in sibling files)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/books/**`, `agent-system/extensions/core/scripts/lint/**`,
  `agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md`,
  `agent-system/extensions/core/context/formats/plan-format.md`
- Git history: `git log --follow`, `git blame`-equivalent commit tracing for the four implicated
  files and the two lint scripts
- Live tool runs: `lint-agent-contracts.sh --verbose`, `lint-task-lookup-adoption.sh --verbose`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Defect 1 confirmed**: `agent-system/extensions/books/agents/books-implementation-hard-agent.md`
  Stage 7 only describes the `artifacts` shape in prose ("same `artifacts` shape as the base
  agent") with no literal `"artifacts"` key anywhere in the file. This fails
  `lint-agent-contracts.sh` Check F (object-shaped artifacts template) **and** Check E (terminal
  status presence) simultaneously — the file carries no fenced `"status": "<value>"` line either,
  only backtick-separated prose (`` `implemented`/`partial`/`blocked` ``). Both failures are
  fixed by the same single edit: copy the sibling non-hard agent's fenced JSON block verbatim
  into Stage 7.
- **Defect 2 confirmed**: both `skill-books-implementation-hard/SKILL.md:52` and
  `skill-books-research-hard/SKILL.md:43` hand-roll the narrow full-record jq lookup
  (`'.active_projects[] | select(.project_number == $num)'`) directly in their own "Stage 1:
  Input Validation" bash block, instead of sourcing `skill-base.sh` and calling
  `skill_validate_input`. Their own **non-hard siblings** (`skill-books-implementation`,
  `skill-books-research`) do not hand-roll this lookup at all — they rely on `skill_validate_input`-equivalent inputs already being in scope and never declare an inline "Stage 1" bash
  block.
- Both defects were introduced by **task 297** ("scaffold books extension routing and agents"),
  phase 2 (agent) and phase 3 (skills), on 2026-10-03 08:52–08:54. Both lint scripts already
  existed and were already wired into `verify-deploy.sh` well before that — `lint-agent-contracts.sh`
  Check F since 2026-08-12, `lint-task-lookup-adoption.sh`'s gate-18 wiring since 2026-09-01.
  Neither defect is pre-existing tooling catching up; both slipped past tooling that was already
  live.
- **Root cause of the "general defect" (why the scaffold's own completion gate passed anyway)**:
  task 297's Phase 8 ("Lint, wiring and detection gate") declared **`Verification Tier: full`**
  but its own task list named only three specific validators — `check-extension-docs.sh`,
  `validate-index.sh`, `validate-wiring.sh` — plus the 7-row task-type-detection re-run. It never
  invoked `lint-agent-contracts.sh`, `lint-task-lookup-adoption.sh`, or the aggregate
  `verify-deploy.sh` itself. This directly contradicts `plan-format.md`'s own definition of the
  `full` tier ("The complete gate set for the repository" / "Nothing is deferred past this
  tier") and the established convention elsewhere in the codebase, where every other observed
  `Verification Tier: full` phase that reaches a repo-wide gate explicitly runs
  `bash .claude/scripts/verify-deploy.sh` (or the source-store equivalent) — see tasks 165, 127,
  184, 265, 250 for concrete precedent. Task 297's completion summary explicitly lists only the
  three narrow validators it ran as its basis for "fully scaffolded ... and passes
  check-extension-docs.sh, validate-index.sh, validate-wiring.sh" — `verify-deploy.sh` is never
  mentioned.
- The same gap reproduced independently: **task 326** ("books verification tier at implement
  dispatch") later edited the same two hard-agent/hard-skill files again (adding the `--gate`
  step) and edited shared/global core scripts (`orchestrate-build-dispatch.sh`,
  `orchestrate-cycle-plan.sh`, `parse-command-args.sh`). Its plan never declared a single
  `Verification Tier: full` phase at all (highest declared tier: `interface`), and neither its
  plan nor its summary mentions running `verify-deploy.sh`. The two standing defects were
  therefore never re-surfaced by this second touch either, even though it rewrote the exact
  files that carried them.
- **Live re-check during this research** (`bash .claude/scripts/verify-deploy.sh --skip-slow`,
  run 2026-10-03): `[verify-deploy] FAIL -- 2 of 33 check(s) failed`, specifically gate 6 (Agent
  contracts lint) and gate 18 (Task-lookup adoption lint) — exactly the two defects this task
  names. The dispatch description's "currently FAIL 3 of 33" is now stale by one: gate 20
  (orchestrator context-budget lock) passes live, consistent with this repo's most recent commit
  (`29766b2c8 meta: bring skill-orchestrate/SKILL.md back under its context-budget ceiling`,
  visible in git status/log at the start of this session) having already closed that third,
  separately-tracked failure. This task's own scope is unaffected — it was never responsible for
  gate 20 — but a planner should expect `verify-deploy.sh --skip-slow` to go fully green (33 of
  33) once Defects 1-2 are fixed, not merely drop to 1 of 33.

## Context & Scope

Researched: the two concrete lint failures named in the task description, their precise fix
shape (by comparison against each defect's own passing sibling file), the git provenance of
when and where each defect was introduced, and — per the task description's explicit mandate —
why task 297's own completion postflight did not catch either failure, since both lint checks
were already live in `verify-deploy.sh` well before task 297 ran.

Out of scope for this research pass (left to planning/implementation): the actual file edits
(this is a research-only dispatch); the unrelated third `verify-deploy.sh --skip-slow` failure
(an orchestrator context-budget ceiling), which the task description explicitly says is "tracked
separately."

## Findings

### Codebase Patterns

**Defect 1 — artifacts/status shape (`lint-agent-contracts.sh` Checks E and F)**

- `books-implementation-agent.md` (non-hard sibling, PASSES both checks) carries, at its Stage 7,
  a fenced JSON block:
  ```json
  {
    "status": "implemented",
    "artifacts": [
      {
        "type": "summary",
        "path": "specs/{N}_{SLUG}/summaries/{NN}_{short-slug}-summary.md",
        "summary": "One-line description of what the summary covers."
      }
    ]
  }
  ```
- `books-implementation-hard-agent.md` Stage 7 instead reads: "Write to
  `specs/{N}_{SLUG}/.return-meta.json`, status `implemented`/`partial`/`blocked`, same
  `artifacts` shape as the base agent." — no fenced JSON, no literal `"artifacts"` or `"status"`
  key anywhere in the file. Confirmed live:
  ```
  [FAIL] books-implementation-hard-agent.md: missing an object-shaped artifacts array with keys
         (artifacts path summary type)
  [FAIL] books-implementation-hard-agent.md: no conformant terminal status found
  ```
  (`lint-agent-contracts.sh --verbose`, run 2026-10-03; both FAILs are this one file.)
- `lint-agent-contracts.sh` Check F mechanism (`has_artifacts_object_shape`): scans for an
  `"artifacts"` occurrence and requires `"type"`, `"path"`, `"summary"` keys all present within
  the following 6 lines. A prose reference satisfies nothing — only a literal fenced block does.
- `return-meta-artifacts-template.md`'s own "Placement" section anticipates exactly this
  situation: "Where an agent carries only a prose warning ... with no inline JSON template, keep
  the prose and add the template — prose alone does not substitute for a copyable example."
- **Fix**: insert the identical fenced JSON block (adapted only if the hard agent's own artifact
  `type`/`path` differs — it does not; both agents write the same summary artifact shape) into
  `books-implementation-hard-agent.md`'s Stage 7, exactly as the non-hard sibling has it. This
  single edit resolves both the Check F and Check E failures on this file, since the template
  itself carries the literal `"status": "implemented"` line.

**Defect 2 — hand-rolled task lookup (`lint-task-lookup-adoption.sh`)**

- Confirmed live, exactly 2 violations, both in the two named hard skills:
  ```
  [VIOLATION] skill-books-implementation-hard/SKILL.md:52: '.active_projects[] | select(.project_number == $num)' \
  [VIOLATION] skill-books-research-hard/SKILL.md:43: '.active_projects[] | select(.project_number == $num)' \
  ```
- Both hard skills' own "Stage 1: Input Validation" is a literal bash fence:
  ```bash
  task_data=$(jq -r --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == $num)' \
    specs/state.json)
  if [ -z "$task_data" ]; then
    return error "Task $task_number not found"
  fi
  task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
  status=$(echo "$task_data" | jq -r '.status')
  project_name=$(echo "$task_data" | jq -r '.project_name')
  description=$(echo "$task_data" | jq -r '.description // ""')
  if [ "$status" = "completed" ] || [ "$status" = "abandoned" ] || [ "$status" = "expanded" ]; then
    return error "Task is in terminal state [$status]"
  fi
  ```
- The **non-hard siblings** (`skill-books-implementation`, `skill-books-research`) have no such
  block at all: their own "Stage 1: Input Validation" is one unadorned sentence ("Validate
  task_number exists and task type is 'books'") with zero bash, and their later "Stage 2 + Stage
  3" block sources `skill-base.sh` and calls `skill_preflight_update`/
  `skill_create_postflight_marker` directly — never a `skill_validate_input` call either, since
  these two fields are apparently already in scope by the time this skill runs (both skills
  immediately use `task_number`, `project_name`, `description`, `task_type` in later stages
  without deriving them locally).
- The canonical fix pattern, precedented across many other extensions'
  non-hard implementation/research skills (e.g. `skill-web-implementation`,
  `skill-web-research`), is:
  ```bash
  source .claude/scripts/skill-base.sh
  skill_validate_input "$task_number"
  task_data="$TASK_DATA"
  task_type="$TASK_TYPE"
  status="$TASK_STATUS"
  project_name="$TASK_DIR"   # see note below
  description="$DESCRIPTION"
  ```
  `skill_validate_input` (in `agent-system/extensions/core/scripts/skill-base.sh:336-376`) exits
  1 itself on not-found or terminal-state, exports `TASK_DATA, TASK_TYPE, TASK_STATUS,
  PROJECT_NAME, DESCRIPTION, PADDED_NUM, TASK_DIR, TASK_DIR_ABS, TASK_IS_ARCHIVED` — a strict
  superset of what the hand-rolled block derives, including the identical terminal-state check
  (and additionally covering `archived` tasks via `task_lookup_is_active`, which the hand-rolled
  version does not).
- **Fix**: replace each hard skill's Stage 1 bash fence with the `source skill-base.sh` +
  `skill_validate_input "$task_number"` pattern (mirroring `skill-web-implementation`'s Stage 1
  exactly), or — to track the non-hard siblings even more closely — delete the Stage 1 bash
  block entirely and let the later "Stage 2 + Stage 3" `source .claude/scripts/skill-base.sh`
  line stand as the sole place `skill-base.sh` is sourced, with `task_number`/`project_name`/
  `description`/`task_type` treated as already-in-scope precondition variables exactly as the
  non-hard siblings treat them. Either shape satisfies the lint (which only flags the literal
  hand-rolled jq shape, not the presence/absence of a Stage 1 heading); the first shape is more
  conservative since it keeps an explicit, local terminal-state check next to where the hard
  skill already does its own Stage 1.5 hard-mode-cost-note work.
- **Important adjacent note for planning**: `cslib-implementation-hard`, `cslib-research-hard`,
  `lean-implementation-hard`, and `lean-research-hard` skills carry the **identical** hand-rolled
  shape today, but are explicitly recorded in `lint-task-lookup-adoption.sh`'s own
  `EXCLUDED_FILES` allowlist as "pending migration ... deferred pending the core-collapse
  sequencing decision." The books hard skills were never added to that allowlist — this task's
  fix should **not** add them there either (that would hide the defect, not fix it, and
  contradicts the task description's framing of this as a defect to resolve) — but a planner
  should be aware the allowlist exists and is the alternative (rejected) path, in case a
  reviewer asks "why not just allowlist like the others."

### External Resources

None consulted — this is a pure in-repo contract/lint-conformance defect with full local
precedent (the passing sibling files) available; no external documentation applies.

### Root-Cause Finding: Why Task 297's Completion Gate Passed Anyway

This is the "more general defect" the task description asks this task to rule on.

**Timeline (commit timestamps, not task numbers — task numbers are not chronological across
vault operations):**

| When | What | Evidence |
|------|------|----------|
| 2026-08-05 14:36 | `lint-task-lookup-adoption.sh` wired as `verify-deploy.sh` gate 18 | commit `e037f8429` |
| 2026-08-12 09:05 | `lint-agent-contracts.sh` Check F (object-shaped artifacts) added | commit `7b4bc183a` |
| 2026-10-03 08:52 | `books-implementation-hard-agent.md` created (task 297 phase 2) | commit `8655007d1` |
| 2026-10-03 08:54 | both hard `SKILL.md` files created (task 297 phase 3) | commit `985d05b47` |
| 2026-10-03 09:03 | task 297 Phase 8 "Lint, wiring and detection gate" runs | commit `a823bbf28` |
| 2026-10-03 09:06 | task 297 marked `[COMPLETED]` | commit `87dbd6644` |
| 2026-10-03 12:55 | task 326 phase 5 edits the same 4 files again (adds `--gate` step) | commit `75f93d1ad` |

Both lint checks were live and already wired into the aggregate gate roughly two months before
task 297 ran. The defects are not a case of tooling catching up to old content — the tooling was
already watching when the content was written.

**The actual mechanism**: task 297's plan
(`specs/297_scaffold_books_extension_routing_and_agents/plans/01_books-extension-wiring.md`)
declares Phase 8 with `**Verification Tier**: full`, but Phase 8's own task checklist reads:

```
- [x] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` ...
- [x] Run `bash agent-system/extensions/core/scripts/validate-index.sh` and
      `bash agent-system/extensions/core/scripts/validate-wiring.sh`; resolve `books` findings.
- [x] Confirm `README.md` is newer than `manifest.json`; ...
- [x] Re-run the full 7-row `detect_task_type` table ...
- [x] Confirm nothing was written under `.claude/**` by this task ...
- [x] Confirm no task-number reference landed in any file under `agent-system/extensions/books/**`.
```

Three named validators plus two local confirmations — never `lint-agent-contracts.sh`,
`lint-task-lookup-adoption.sh`, or `verify-deploy.sh` itself. The task's own completion summary
(`specs/297_.../summaries/01_books-extension-scaffold-summary.md`) echoes this exactly: "is
fully scaffolded in the source store and passes check-extension-docs.sh, validate-index.sh,
validate-wiring.sh, and the 7-row task-type detection table" — a true claim about exactly what
was run, but a claim that silently narrows "full" down to a hand-picked subset.

This contradicts `plan-format.md`'s own normative text for the `full` tier (`## Verification
Tiers`):

> `full` | Edits that can change runtime, proof, or elaboration behavior anywhere... | **The
> complete gate set for the repository** | Nothing is deferred past this tier. This is the
> ceiling

and its "Non-negotiable invariant": "the full gate set still runs before a phase closes and
before a task completes, unchanged." It also departs from the convention every other located
`Verification Tier: full` phase follows: tasks 165, 127, 184, 265, and 250 each explicitly list
`bash .claude/scripts/verify-deploy.sh` (or the source-store-root equivalent) as the Phase's own
verification command when they declare `full`. Task 297's Phase 8 declares `full` but never
names `verify-deploy.sh` anywhere in its own text.

**The gap reproduced a second time, independently**: task 326
(`specs/326_books_verification_tier_at_implement_dispatch/`) later rewrote the exact same four
files (plus three core orchestration scripts) to add the `--gate` flag plumbing. Its plan never
declares a single `Verification Tier: full` phase — its highest declared tier anywhere is
`interface` (Phase 5, the one that touched the two defective hard files again). Neither its plan
nor its summary mentions `verify-deploy.sh` at all. So even a task whose own file list included
global/shared core scripts (`orchestrate-build-dispatch.sh`, `orchestrate-cycle-plan.sh`,
`parse-command-args.sh` — exactly the "shared tactics, core types, global config" category
`plan-format.md` names as the textbook case for `full`) never triggered a full-gate run, and the
two pre-existing defects in the files it was editing were never re-surfaced.

**Conclusion**: the defect is not in the lint scripts (both are correct and were already
catching this class of failure) and not in `verify-deploy.sh`'s wiring (both gates are correctly
registered at gates 6 and 18). The defect is **planning-time**: a `Verification Tier: full`
declaration is not mechanically tied to an actual `verify-deploy.sh` invocation anywhere in the
authoring or execution path — it is purely a documentation convention that two different plans
(297's Phase 8, and the entirety of 326) did not follow, with no lint or gate catching the
mismatch between the declared tier and the actual commands run. `plan-format.md` itself
acknowledges this gap exists in its own "Enforcement level" note: `**Verification Tier**:` field
presence is checked only in `--strict` mode and only for *presence*, never for whether a
declared `full` phase's own task list actually reaches `verify-deploy.sh`.

## Recommendations

1. **Fix Defect 1** (`books-implementation-hard-agent.md`): insert the base agent's exact fenced
   `"status"`/`"artifacts"` JSON block into Stage 7, verbatim except for anything the hard agent
   genuinely differs on (nothing does — same artifact type, same path shape). This is a single,
   mechanical, low-risk edit with a passing sibling file as the literal copy source.
2. **Fix Defect 2** (`skill-books-implementation-hard/SKILL.md`,
   `skill-books-research-hard/SKILL.md`): replace each file's hand-rolled Stage 1 jq lookup with
   `source .claude/scripts/skill-base.sh` + `skill_validate_input "$task_number"`, reading
   `task_type`/`status`/`project_name`/`description` from the exported `TASK_TYPE`/`TASK_STATUS`/
   `PROJECT_NAME`/`DESCRIPTION` variables. Do not add these two files to
   `lint-task-lookup-adoption.sh`'s `EXCLUDED_FILES` allowlist — that would suppress rather than
   fix the defect the task was opened to resolve, and the task description frames this
   explicitly as a fix, not a deferral.
3. **Address the general defect, scoped conservatively**: this research task's own mandate is to
   "rule on why" the gate passed — it does not, on its own evidence, point to a single
   three-line code fix the way Defects 1-2 do. Two candidate remedies for a follow-on
   implementation/planning task to weigh (do not treat either as pre-decided by this research):
   a. A lint/validator addition that, given a plan file, flags any phase declaring
      `**Verification Tier**: full` whose own task list contains no recognizable full-gate
      invocation (`verify-deploy.sh`, or equivalently all of the aggregate's constituent lints)
      — mirroring the existing `--strict` presence check but for *content*, not just the field's
      presence. This directly targets the mechanism found above.
   b. A lighter-weight fix: amend `plan-format.md`'s `## Verification Tiers` table to state
      explicitly, next to the `full` row, that the concrete command satisfying "the complete gate
      set for the repository" is `bash .claude/scripts/verify-deploy.sh` (or
      `agent-system/extensions/core/scripts/verify-deploy.sh` from the source store), removing
      the current ambiguity that let two different plans independently narrow "full" to
      self-chosen validator subsets without being wrong about the letter of the text.
   These are not mutually exclusive, and (b) is strictly cheaper; a planner may choose to land
   (b) now and treat (a) as a separate follow-on task given its larger surface (a new lint rule
   touching every extension's plans).
4. **Do not re-litigate** the already-closed `--gate` advisory-tier design (task 326) or the
   books extension's broader scaffold design (task 297) — both are settled, completed work;
   only the three named files and the general-defect finding above are in scope for this task.

## Decisions

- The fix for Defect 1 is to copy the non-hard sibling's exact JSON template, not to author a
  new template from scratch — this is the explicit instruction in the task description and is
  independently confirmed as the only variant that already passes the lint elsewhere in this
  same extension.
- The fix for Defect 2 is to adopt `skill_validate_input` (the `skill-base.sh` canonical helper),
  not `gate_in` (the command-layer helper) — `skill_validate_input` is the one already used by
  this codebase's non-hard-skill convention at the skill layer (see `skill-web-implementation`,
  `skill-spawn`), and `gate_in` is reserved for command-layer (`.md` command file) call sites,
  which these SKILL.md files are not.
- The two books hard skills are NOT to be added to `lint-task-lookup-adoption.sh`'s
  `EXCLUDED_FILES` allowlist, even though four other extensions' hard skills with the identical
  anti-pattern are already there — the allowlist is an explicitly-reasoned, shrinking exception
  list for *pending* migrations, not a precedent that license new entries by default, and this
  task's own description frames the two books occurrences as defects to fix now.
- This research task does not pick between remedy (a) and (b) above for the general defect; both
  are recorded as candidate follow-on scope for the planning phase to weigh, since neither is a
  simple three-line fix comparable to Defects 1-2 and a planner should size them deliberately
  rather than inherit an unexamined research-time pick.

## Risks & Mitigations

- **Risk**: fixing Defect 1 by hand-typing a new JSON block (rather than copying the sibling's)
  risks a subtly different key order or an extra/missing key that still fails Check F's
  window-based key search. **Mitigation**: copy-paste the sibling's exact fenced block; do not
  retype it.
- **Risk**: fixing Defect 2 by calling `skill_validate_input` could change behavior subtly (e.g.
  it is also archive-aware via `task_lookup_is_active`/`task_lookup_dir`, which the hand-rolled
  version is not). **Mitigation**: this is a strict behavioral superset for every live task this
  skill will realistically see (an archived `books`/`books:certify` task resuming hard-mode
  implementation is already an edge case the non-hard skill would handle the same way via its
  own later `skill-base.sh` sourcing); no narrowing of behavior results.
- **Risk**: the general-defect remedy (recommendation 3) is scoped broadly enough that an
  implementer might try to "fix" it by editing `verify-deploy.sh`, `lint-agent-contracts.sh`, or
  `lint-task-lookup-adoption.sh` directly, none of which are defective. **Mitigation**: this
  report states explicitly, twice, that the lints and the gate wiring are correct; any
  implementation task addressing the general defect should scope itself to `plan-format.md`
  and/or a new validator over plan files, never the three already-correct scripts above.
- **Risk** (territory): per this dispatch's Territory block, task 285 is a concurrent sibling
  touching `orchestrate-record-decision.sh`, `orchestrate-cycle-postflight.sh`,
  `skill-orchestrate/SKILL.md`, and `utility-scripts-inventory.md` this same cycle. None of
  those four files are touched by this research or by the three-file fix scope named in this
  task's `file_scope`; no collision expected, but an implementer should re-read
  `context/contracts/territory.md` before any edit regardless.

## Context Extension Recommendations

- **Topic**: `plan-format.md`'s `## Verification Tiers` section, `full` row.
- **Gap**: the `full` tier's "in-phase verification" column reads "The complete gate set for the
  repository" in prose only, with no named command. Every located precedent (tasks 165, 127, 184,
  265, 250) independently converged on `bash .claude/scripts/verify-deploy.sh` as that command,
  but two other plans (task 297's Phase 8, and all of task 326) never named it and both
  substituted a self-scoped subset instead, with nothing catching the mismatch.
- **Recommendation**: add one sentence to the `full` row (or an adjacent note) naming
  `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`) as the canonical command that
  satisfies "the complete gate set" — this is recommendation 3(b) above, repeated here as a
  context-documentation gap in its own right since it is cheap, low-risk, and directly
  addresses the ambiguity this research found causing the general defect.

## Appendix

### Search queries / commands used

- `git log --oneline --follow -- <file>` for each of the 4 implicated agent/skill files, to find
  originating commits
- `git log --oneline --diff-filter=A -- <lint-script>` for both lint scripts' creation commits
- `git log --oneline -S "<anchor text>" -- <verify-deploy.sh path>` to find when each gate was
  wired into the aggregate
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
- `bash agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh --verbose`
- `grep -n "Verification Tier" specs/*/plans/*.md` across the repo to establish the `full`-tier
  convention precedent

### Files read in full or in large part

- `agent-system/extensions/books/agents/books-implementation-agent.md` (passing reference)
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` (defect 1)
- `agent-system/extensions/books/skills/skill-books-implementation/SKILL.md` (passing reference)
- `agent-system/extensions/books/skills/skill-books-research/SKILL.md` (passing reference)
- `agent-system/extensions/books/skills/skill-books-implementation-hard/SKILL.md` (defect 2a)
- `agent-system/extensions/books/skills/skill-books-research-hard/SKILL.md` (defect 2b)
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` (Checks E/F mechanics)
- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` (detection/exclusion
  mechanics)
- `agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md`
- `agent-system/extensions/core/context/formats/plan-format.md` (`## Verification Tiers`)
- `agent-system/extensions/core/scripts/skill-base.sh` (`skill_validate_input`, lines 336-376)
- `specs/297_scaffold_books_extension_routing_and_agents/plans/01_books-extension-wiring.md`
  (Phase 8)
- `specs/297_scaffold_books_extension_routing_and_agents/summaries/01_books-extension-scaffold-summary.md`
- `specs/326_books_verification_tier_at_implement_dispatch/plans/01_gate-flag-verification-tier.md`
  (all `Verification Tier` lines)
- `specs/326_books_verification_tier_at_implement_dispatch/summaries/01_gate-flag-verification-tier-summary.md`
