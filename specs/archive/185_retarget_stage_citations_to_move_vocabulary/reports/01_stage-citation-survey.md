# Research Report: Task #185

- **Task**: 185 - Retarget the remaining historical "Stage N" and "Stage MT-N" citations to the
  four-move loop vocabulary
- **Started**: 2026-10-02
- **Completed**: 2026-10-02
- **Effort**: standard
- **Dependencies**: task 88 (the four-move rewrite that deleted single-task Stages 0-8 and
  multi-task Stages MT-1..MT-5 from `skill-orchestrate/SKILL.md`)
- **Sources/Inputs**: codebase grep survey of `agent-system/extensions/core/{context,docs,skills,
  commands,agents}`, `skill-orchestrate/SKILL.md` (current), `docs/architecture/
  orchestrate-state-machine.md`, task 88's archived plan
  (`specs/archive/088_mode_gate_skill_orchestrate_multi_task_section/plans/
  01_four-move-loop-rewrite.md`)
- **Artifacts**: `reports/01_stage-citation-survey.md` (this file)
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's own naive grep (`Stage MT-|Stage [0-8]\b`) over
  `core/{context,docs,skills,commands,agents}` matches **77 files**, not a small, uniform set —
  but the overwhelming majority of those hits are **false positives from four other, independently
  numbered "Stage N" vocabularies** that happen to collide lexically with
  `skill-orchestrate`'s deleted single-task/multi-task numbering. A blind find-replace across all
  77 files would corrupt unrelated conventions that are still correct and unrelated to this task.
- After line-by-line verification, I confirmed **18 files carrying genuine citations** of
  `skill-orchestrate/SKILL.md`'s deleted Stage 0-8 / Stage MT-1..5 structure (~171 raw regex hits,
  close to the task's own "~120 citations" estimate once the false-positive lines inside two mixed
  files are subtracted). This supersedes the dispatch's "9 files" known-sites estimate — see
  Findings and Recommendations for the full list.
- **Key structural finding**: the new Move 1-4 structure is coarser-grained than the old
  Stage/Stage-MT structure. Sub-step detail ("step 3", "step 7", "step 4.5", "step 5.5") no
  longer exists as an addressable SKILL.md prose anchor — that granularity now lives entirely
  inside the implementing scripts (`orchestrate-cycle-plan.sh`, `orchestrate-build-dispatch.sh`,
  `orchestrate-cycle-postflight.sh`). A correct retarget must rename the **section anchor** (Stage
  N -> Move K) while preserving the **descriptive parenthetical** naming the mechanism/script —
  never invent a fictitious "Move 1 step 3".
- A second, sharp hazard: `orchestrate-build-dispatch.sh` itself still internally calls one of its
  own pipeline phases **"Stage 3.5"** (unrenamed, and correctly so — it is the script's own label,
  not a citation of `SKILL.md`'s structure). At least 6 files cite this script-internal "Stage
  3.5" by name; none of them are broken and none should be touched. Distinguishing "cites
  SKILL.md's deleted section" from "cites a script's own still-valid internal label" is the single
  highest-value discrimination implementation must make correctly.
- Recommended `file_scope` addition (beyond the 5 explicitly named in the dispatch) is **13 further
  files** (listed in Recommendations), not the task description's own guess of "four further
  files." Two of those 13 are *mixed* files needing line-level treatment, not whole-file
  find-replace.

## Context & Scope

Task 88 rewrote `skill-orchestrate/SKILL.md` from a two-engine, Stage-numbered state machine
(single-task Stages 0-8; multi-task Stages MT-1 through MT-5) into a single four-move loop
(`## The Four-Move Loop`: Move 1 Plan the cycle, Move 2 Dispatch, Move 3 Postflight, Move 4
Branch — `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:27-263`). That rewrite
deliberately deferred retargeting every external citation of the old section names as
disproportionate to its own scope. This task is that deferred mechanical sweep.

Scope boundaries set by the dispatch and confirmed by this research:
- Edit only the source store under `agent-system/extensions/**` (never the deployed `.claude/`
  tree) — confirmed: `agent-system/extensions/core/...` exists and is the correct target tree; no
  `source_dir` key exists in `.claude-extensions.json` at the repo root, but the source-store/
  deploy-boundary rule names `agent-system/extensions/**` directly and the directory is present.
- In scope: markdown prose in `context/`, `docs/`, `skills/*/SKILL.md`, and `commands/*.md` that
  **cites** `skill-orchestrate/SKILL.md`'s old section names as the authority for where a live
  mechanism lives, or that narrates the old engine's history.
- Out of scope (established by this research, not stated explicitly in the dispatch): the six
  `agents/*.md` files, and every other file whose "Stage N" is its own, unrelated numbering
  convention (see Findings). Also out of scope: renaming script filenames/internal labels that
  happen to contain "stage" (`orchestrate-stage5-gates.sh`, `orchestrate-stage5-postflight.sh`,
  `orchestrate-build-dispatch.sh`'s internal "Stage 3.5" label) — these are script identity, not
  `SKILL.md` section citations, and renaming them is a separate, much larger, unrequested
  undertaking.

## Findings

### The five independent "Stage N" vocabularies found in this codebase

Running the dispatch's literal grep (`Stage MT-|Stage [0-8]\b`) over `core/{context,docs,skills,
commands,agents}` returns 77 files. Verifying each by reading surrounding context revealed **five
independently-numbered conventions** that all happen to use the word "Stage" followed by a small
integer, only one of which is this task's target:

1. **The task's actual target** — `skill-orchestrate/SKILL.md`'s deleted single-task Stage 0-8
   and multi-task Stage MT-1..5. Genuine citations describe *skill-orchestrate's own* dispatch
   loop (eligibility, dispatch, postflight, handoff reading, drift inspection, blocker
   escalation, redeploy checkpoint, consolidated output). These are almost always accompanied by
   the literal string `skill-orchestrate`, `orchestrate-cycle-plan.sh`, `orchestrate-cycle-
   postflight.sh`, `orchestrate-build-dispatch.sh`, or an explicit "both orchestrate engines" /
   "the orchestrator's own" phrase.

2. **The generic agent-execution-flow convention** (`context/templates/agent-template.md`,
   `context/templates/subagent-template.md`, and every file generated from them: `agents/
   general-research-agent.md`, `agents/general-implementation-agent.md`, `agents/planner-
   agent.md`, `agents/reviser-agent.md`, `agents/spawn-agent.md`, `agents/meta-builder-agent.md`,
   plus `docs/templates/agent-template.md`, `docs/templates/README.md`, `docs/guides/
   creating-agents.md`, `context/patterns/early-metadata-pattern.md`,
   `context/architecture/generation-guidelines.md`, `docs/guides/context-loading-best-
   practices.md`, `context/contracts/phase-closure.md`, `context/contracts/adversarial-
   verification.md`, `context/patterns/checkpoint-before-overflow.md`, `context/formats/
   frontmatter.md`, `context/formats/return-metadata-file.md`). Each agent names its *own*
   internal "Stage 0: Initialize Early Metadata" ... "Stage 7/8: ..." execution steps — this
   numbering is unrelated to, and predates/postdates independently of, `skill-orchestrate`'s
   engine. This research agent is itself running under this exact convention right now (see this
   agent's own Stage 0-8 headings).

3. **The generic skill-body / shared preflight-postflight-flow convention** (`context/
   patterns/skill-preflight-flow.md`, `context/patterns/skill-postflight-flow.md`,
   `context/patterns/postflight-control.md`, `context/patterns/skill-lifecycle.md`,
   `context/patterns/subagent-continuation-loop.md`, `context/standards/postflight-tool-
   restrictions.md`, `context/workflows/command-lifecycle.md`, `context/workflows/preflight-
   postflight.md`, `context/workflows/review-process.md`, `context/orchestration/delegation.md`,
   `context/orchestration/orchestrator.md`, `context/orchestration/postflight-pattern.md`,
   `context/orchestration/preflight-pattern.md`, `docs/guides/creating-skills.md`, and the
   direct-execution skills that still use it: `skills/skill-todo/SKILL.md`, `skills/skill-
   reviser/SKILL.md`, `skills/skill-spawn/SKILL.md`, `skills/skill-project-overview/SKILL.md`).
   This is the shared Stage 1-9 numbering every *other* skill's body still uses
   (PreflightValidation/DetermineRouting/.../Postflight/Cleanup). `skill-orchestrate` never
   literally imported this block even in its old Stage-numbered incarnation — its own numbering
   was bespoke. **One exception inside this category needs retargeting**: `skill-postflight-
   flow.md:169` explicitly contrasts the generic flow with `skill-orchestrate`'s own "Stage MT-4
   per-task loop" — that one line is a genuine citation; the rest of that file's Stage 6-9 is the
   unrelated generic convention.

4. **`/meta`'s own interview-stage convention** (`commands/meta.md`, `context/meta/
   meta-guide.md`, `context/meta/context-revision-guide.md`, `context/patterns/topic-
   assignment-pattern.md`'s "/meta Interview Stage 4.5" mentions, `docs/reference/standards/
   multi-task-creation-standard.md`'s "/meta's Stage 3.5" mentions). Unrelated to
   `skill-orchestrate`.

5. **Other scripts' own retained internal "stage" labels, unrelated to the Move rewrite and
   still valid**: `orchestrate-build-dispatch.sh` still internally calls one of its six output
   phases **"Stage 3.5 (Dispatch Prep)"** (confirmed live in the script's own header comment and
   section markers, `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh:8,247-
   364`). Six files cite this *script-internal, still-accurate* label by name: `commands/
   orchestrate.md:97`, `context/contracts/anti-analysis.md:49`, `context/guides/hard-mode-
   routing.md:104`, `context/guides/manifest-routing-schema.md:41,69,98,267`, and
   `docs/reference/standards/multi-task-creation-standard.md` (the `/meta` variant, already
   counted in #4). **None of these need to change** — the script was never renamed, so the
   citation is not broken. Separately, `context/patterns/task-lock.md:499,520,562-563` cites
   `orchestrator-postflight.sh`'s own "Stage 7-8a" — that script is independently confirmed
   orphaned/dead elsewhere in the repo (`skills/skill-git-workflow/SKILL.md:23-25`: "now an
   orphaned script with no live callers"). This is a *pre-existing staleness issue unrelated to
   the Move rewrite* (task-lock.md still describes a dead script as a live reference
   implementation) — flagged under Context Extension Recommendations, not in this task's scope.
   `docs/reference/utility-scripts-inventory.md:23` similarly cites a lean skill's own "Stage 2",
   unrelated.

### Confirmed true-positive files (need retargeting)

| File | Raw hits | Nature |
|---|---|---|
| `context/patterns/batch-orchestration-guardrails.md` | 33 | All MT-3/MT-4/MT-5 citations of still-live admission/dispatch/commit/redeploy mechanics. Largest single concentration; named in dispatch. |
| `docs/architecture/handoff-schema.md` | 28 | Named in dispatch; not individually re-verified line-by-line this pass (trust the dispatch's own classification; implementation should still grep-verify before editing). |
| `context/standards/orchestrator-runtime-files.md` | 17 | Maps runtime files (`.orchestrator-loop-guard`, `.orchestrator-churn-state.json`, `.drift-inspection.json`, `.orchestrator-handoff.json`) to the orchestrate engine's own Stage 2/5/5a/8/MT-4 write/read/cleanup points. Not in the dispatch's named list — add it. |
| `docs/examples/research-flow-example.md` | 25 | Walks a worked example of `skill-orchestrate`'s OLD single-task Stage 1 through Stage 8 end-to-end. Not in the dispatch's named list — add it. This file needs the most substantial rewrite (the whole worked trace, not scattered citations) or an explicit historical-example framing; flag for the plan phase to decide which. |
| `docs/architecture/batch-admit-schema.md` | 12 | Named in dispatch. |
| `docs/architecture/orchestrate-cycle-postflight.md` | 11 | Named in dispatch. |
| `context/patterns/skill-postflight-flow.md` | 12 (1 true) | **Mixed file** — only line 169's "Stage MT-4" is a genuine citation; the other 11 hits are the unrelated generic skill-flow convention (#3 above). Line-level edit only. |
| `context/patterns/infra-failure-discrimination.md` | 7 (~2-3 true) | **Mixed file** — "Stage 5 / Stage MT-4 step 1" (lines 10, 22, 38) describe the orchestrator's own handoff-inspection timing and need retargeting to Move 3; "Stage 0" (line 62), "Stage 2" (line 78), "Stage 7" (line 92) are the generic agent-execution convention (#2) and must NOT change. |
| `context/patterns/regeneration-is-manual-only.md` | 7 | All genuine: "Stage MT-3 step 7" (inter-cycle redeploy checkpoint) and "Stage MT-4" (per-task commit) citations of still-live mechanics, plus one reference to `orchestrate-build-dispatch.sh`'s own valid "Stage 3.5" (leave that one alone per #5). |
| `context/patterns/orchestrate-batch-results-template.md` | 5 | Named in dispatch. |
| `docs/architecture/orchestrate-state-machine.md` | 5 | Already mostly fixed by task 88 itself. Lines 48, 704 are correctly-framed historical ("former", "single-task's own ... Stage 6, deleted along with that engine") — leave as-is, they are the model for how to mark history. Line 279 ("agent's Stage 0 writes...") is a false positive (category #2, the agent's own Stage 0) — leave unchanged. Lines 212-213 ("Stage 5 recovery grep") correctly cite the still-live `orchestrate-stage5-gates.sh` script's own retained name (category #5) — leave unchanged. **No action needed in this file**, but keep it in file_scope as a reviewed/confirmed-clean site so a future grep sweep doesn't re-flag it without a record of why. |
| `skills/skill-git-workflow/SKILL.md` | 1 | "single-task CHECKPOINT 3 and multi-task Stage MT-4 step 5.5" describing the current commit execution site — needs retargeting to Move 2. |
| `docs/fork-patterns.md` | 1 | "Stage 5a drift inspection, Stage 6 blocker research" — needs retargeting to Move 2's `aux_dispatch[]` path. |
| `context/contracts/territory.md` | 1 | "The orchestrator's own Stage 5 `dispatch_seq` gate" — confirmed this logic now lives inside `orchestrate-cycle-postflight.sh`, called from Move 3. |
| `context/contracts/wrap-up.md` | 1 | "...Stage 5 of both orchestrate engines compares against..." — same dispatch_seq-gate logic; retarget to Move 3, and note "both orchestrate engines" is itself stale (there is only one engine now). |
| `context/patterns/dispatch-report-not-termination.md` | 3 (1 true at line 69) | "`skill-orchestrate/SKILL.md`'s Stage 5 staleness-gate comment block" -> Move 3. The other 2 hits are the lean extension's own agent-stage convention (category #2) — leave unchanged. |
| `context/patterns/mode-gated-section-loading.md` | 1 | "`skill-orchestrate/SKILL.md` Stage 2 already uses an informal paired bash-comment convention" — verify against the CURRENT Move 1/Move 2 text for where that bash-comment-pairing style still appears before retargeting (not independently confirmed which Move this collapsed into; likely Move 1 or Move 2). |
| `context/patterns/file-footprint-overlap.md` | 1 | Already correctly historical: "the now-deleted per-mode team-implement skill's own Stage 5". No action needed — a second model example of correct historical framing, from a *different* deleted engine (not even `skill-orchestrate`), useful as a template for how to phrase other historical citations. |

That is **18 files** total (5 named by the dispatch + 13 more confirmed here), not "9" or "the
four further files" the dispatch guessed. Two of the 18 (`skill-postflight-flow.md`,
`infra-failure-discrimination.md`) are mixed and need line-level, not whole-file, treatment.
Three (`orchestrate-state-machine.md`, `file-footprint-overlap.md`, and — once its one line is
fixed — `dispatch-report-not-termination.md`) need little or no further action but should stay in
`file_scope` as confirmed-reviewed so they aren't re-flagged blind by a future grep.

### The Stage -> Move mapping (confirmed from the current `SKILL.md` + `orchestrate-state-machine.md`)

Single-task (deleted):

| Old section | New home |
|---|---|
| Stage 0: Multi-Task Mode Detection | Deleted outright — no `multi_task_mode` branch exists; there is only the one loop now. |
| Stage 1/1b (routing) | Move 1 (classification/admission, inside `orchestrate-cycle-plan.sh`) and `command-route-agent.sh` |
| Stage 2 (bash-comment-pairing convention, loop-guard init) | Move 1 (verify exact spot before editing `mode-gated-section-loading.md`) |
| Stage 3/3.5 (Dispatch Prep) | Move 1's dispatch-file composition call into `orchestrate-build-dispatch.sh` — but see category #5: `orchestrate-build-dispatch.sh`'s own internal "Stage 3.5" label is unchanged and not a broken citation. |
| Stage 4: State Handlers | Deleted; consolidated into Move 2's per-task dispatch preflight (confirmed: `orchestrate-state-machine.md:48-51`) |
| Stage 5: Handoff Reading / dispatch_seq staleness gate | Move 3 (confirmed: logic lives in `orchestrate-cycle-postflight.sh`, called from Move 3) |
| Stage 5a: Drift Inspection | Move 2's `aux_dispatch[]` path (`drift-inspection` kind) |
| Stage 5b: H5 divergence-audit | Move 2's `aux_dispatch[]` path (`divergence-audit` kind) |
| Stage 6: Blocker Escalation | Move 2's `aux_dispatch[]` path (`blocker-research`/`plan-revision` kinds); the cross-cutting 5-step sequence is documented separately in `orchestrate-state-machine.md`'s "Blocker Escalation: 5-Step Sequence" |
| Stage 7: Loop Guard Update | Move 3 (update) / Move 4 (the loop-condition check that reads it) |
| Stage 8: Postflight (full-loop termination) | Move 3 (the shared per-row postflight call) / Move 4 (terminal branch) |

Multi-task (deleted):

| Old section | New home |
|---|---|
| Stage MT-1/MT-2 (initialization) | Move 1 ("Setup (once per invocation...)" + the one `orchestrate-cycle-plan.sh` call) |
| Stage MT-3 (steps 1-7: eligibility, classification, admission, redeploy checkpoint at step 7) | Move 1 — all folded into the single `orchestrate-cycle-plan.sh` call; **no SKILL.md-addressable sub-step exists anymore** |
| Stage MT-4 (dispatch; step 4.5 admission-predicate invocation; step 5.5 per-task commit) | Move 2 |
| Stage MT-5 (consolidated output rendering / detection) | Move 3 (and Move 4's batched `AskUserQuestion` relay for the `pending_ask_user` accumulation specifically) |

**Critical caveat**: none of the old `step N`/`step N.5` sub-divisions survive as prose anchors in
the current `SKILL.md` — Move 1, 2, and 3 are each now a single flattened script call with the
granularity living inside that script. A citation like "Stage MT-3 step 7" must become something
like "Move 1 (`orchestrate-cycle-plan.sh`'s inter-cycle redeploy checkpoint)" — rename the anchor,
keep the descriptive parenthetical, never fabricate a "Move 1 step 7."

## Decisions

- **Scope the retarget to markdown prose citations in `context/`, `docs/`, `skills/*/SKILL.md`,
  `commands/*.md`** that cite `skill-orchestrate/SKILL.md`'s own deleted section names. Script
  filenames/internal labels containing "stage" (`orchestrate-stage5-gates.sh`,
  `orchestrate-build-dispatch.sh`'s "Stage 3.5") are a different kind of artifact and are
  explicitly out of scope — renaming them is a separate, unrequested, much larger undertaking with
  its own blast radius (the dedup/locked-region constraints `orchestrate-stage5-gates.sh`'s header
  already documents).
- **Exclude the six `agents/*.md` files and all four other unrelated "Stage N" vocabularies**
  (categories #2-#5 above) from `file_scope` entirely — none of their hits are citations of
  `skill-orchestrate`'s rewrite, and editing them would corrupt live, correct, unrelated
  documentation.
- **Treat `skill-postflight-flow.md` and `infra-failure-discrimination.md` as line-level edits**,
  not whole-file retargets — each carries both a genuine citation and the unrelated generic
  convention in the same file.
- **The acceptance criterion's closing grep** ("a grep for 'Stage MT-' and for single-task 'Stage
  [0-8]' returns only intentional historical references") should be understood, and should be
  re-stated in the plan, as scoped to the documentation tree (`context/`, `docs/`,
  `skills/*/SKILL.md`, `commands/*.md`) — a literal unscoped repo-wide grep will always show
  dozens of unrelated, correct hits from categories #2-#5 and from script filenames/internal
  labels, and that is expected, not a defect.

## Recommendations

1. **Expand `file_scope` for the implement dispatch to these 18 files** (5 already named by the
   dispatch + 13 confirmed here):
   - `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
   - `agent-system/extensions/core/docs/architecture/handoff-schema.md`
   - `agent-system/extensions/core/docs/architecture/orchestrate-cycle-postflight.md`
   - `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
   - `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
   - `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
   - `agent-system/extensions/core/docs/examples/research-flow-example.md`
   - `agent-system/extensions/core/context/patterns/skill-postflight-flow.md` (line 169 only)
   - `agent-system/extensions/core/context/patterns/infra-failure-discrimination.md` (lines 10, 22, 38 only)
   - `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
   - `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (review-confirmed clean; no edits expected)
   - `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md`
   - `agent-system/extensions/core/docs/fork-patterns.md`
   - `agent-system/extensions/core/context/contracts/territory.md`
   - `agent-system/extensions/core/context/contracts/wrap-up.md`
   - `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md` (line 69 only)
   - `agent-system/extensions/core/context/patterns/mode-gated-section-loading.md`
   - `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` (review-confirmed clean; no edits expected)
2. **Per-file methodology for implementation**: for every file above, `grep -n -C2` the two
   patterns fresh (files may have drifted since this survey), classify each hit as (a) live —
   retarget using the Stage->Move mapping table above, keeping the descriptive parenthetical; (b)
   already-correctly-historical — leave untouched; (c) false positive from one of categories #2-#5
   — leave untouched. Never run a blind `sed` replace across a whole file; `batch-orchestration-
   guardrails.md`, `orchestrator-runtime-files.md`, and `research-flow-example.md` in particular
   mix step-level detail that collapsed into scripts with higher-level mechanism descriptions that
   map cleanly to one Move.
3. **`docs/examples/research-flow-example.md`** needs a plan-phase decision, not just a
   mechanical rename: its worked trace walks the deleted single-task engine's Stage 1 through
   Stage 8 end-to-end as a *procedure*, not scattered references. Either rewrite the trace against
   the current Move 1-4 loop (preferred, keeps the example executable-accurate) or explicitly
   re-frame it as a historical worked example of the superseded engine (faster, but the file's own
   purpose — illustrating how a dispatch actually flows today — would be lost). Flag this choice
   for the plan.
4. **Re-run this task's own survey grep after task 250's and the other concurrent engine-editing
   siblings land** (per this dispatch's Territory note — `batch-orchestration-guardrails.md` and
   `handoff-schema.md` are both named as actively-edited-elsewhere-this-cycle risk files). Citation
   line numbers above will drift; re-grep fresh rather than trusting this report's line numbers
   verbatim at implementation time.
5. **Do not fold the `orchestrator-postflight.sh`/`task-lock.md` staleness mismatch into this
   task** (see Context Extension Recommendations) — it is a pre-existing, unrelated staleness
   issue about a different, already-orphaned script.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Blind find-replace across all 77 raw-grep-matched files corrupts 4 unrelated, correct vocabularies (agent-template, skill-flow, `/meta` interview, script-internal labels) | Use the verified 18-file `file_scope` list above; classify every hit line-by-line, never whole-file replace |
| Sub-step citations ("step 3", "step 7", "step 4.5") get mechanically renamed to a nonexistent "Move N step M" | Follow the explicit caveat in Findings: collapse sub-step citations to "Move K (`<script>`'s `<mechanism>`)" phrasing |
| `orchestrate-build-dispatch.sh`'s own internal "Stage 3.5" gets mistakenly "fixed" | It is not broken — the script itself still uses that name; 6 files correctly cite it and need no change (category #5) |
| Line numbers in this report drift before implementation runs (concurrent sibling tasks edit `batch-orchestration-guardrails.md` and `handoff-schema.md` this same cycle per Territory) | Re-grep fresh at implementation time rather than trusting line numbers verbatim |
| The acceptance grep is run unscoped (repo-wide) and "fails" on categories #2-#5's legitimate hits | State explicitly in the plan that the acceptance grep is scoped to `context/`, `docs/`, `skills/*/SKILL.md`, `commands/*.md` under `agent-system/extensions/core/` (and any other extension's docs that cite `skill-orchestrate` specifically, none found in this survey) |

## Context Extension Recommendations

- **Topic**: `orchestrator-postflight.sh` staleness in `task-lock.md`. **Gap**: `task-lock.md`
  (lines 499, 520, 562-563) describes `orchestrator-postflight.sh` as a live "reference
  implementation" of the `SCOPE_MUTEX_HELD` nesting pattern, but `skill-git-workflow/SKILL.md`
  already records that script as orphaned with no live callers. **Recommendation**: a small
  follow-up task to either pick a currently-live reference consumer for that pattern in
  `task-lock.md`, or explicitly mark the `orchestrator-postflight.sh` example as historical. Not
  part of this task — unrelated to the Stage/Move citation sweep.
- **Topic**: `docs/examples/research-flow-example.md`'s worked trace. **Gap**: no existing
  context file walks a current, Move-based dispatch cycle end-to-end the way this file once did
  for the deleted single-task engine. **Recommendation**: whichever plan-phase choice is made for
  this file (rewrite vs. historical reframe), consider that a Move-based worked example may be
  independently valuable documentation regardless of this task's citation-retargeting goal.

## Appendix

### Search queries used

- `grep -rlE "Stage MT-|Stage [0-8]\b" --include="*.md" agent-system/` (unscoped — 250+ files,
  demonstrated the regex alone is far too broad)
- `grep -rlE "Stage MT-|Stage [0-8]\b" --include="*.md" agent-system/extensions/core/{context,docs,skills,commands,agents}` (77 files, matches the dispatch's own "72 files... on 2026-09-28" estimate within normal codebase drift)
- `grep -rlE "Stage MT-" ...` alone (11 files — the unambiguous subset, all genuine `skill-orchestrate` citations)
- Per-file `grep -n -C2 -E "Stage MT-|Stage [0-8]\b" <file>` for all 71 non-agent candidate files, read in context to classify
- `grep -n "last_recovered_phases_completed" agent-system/extensions/core/scripts/` to confirm `orchestrate-stage5-gates.sh` still live
- `grep -rln "orchestrate-stage5-gates.sh" agent-system/extensions/core/` to confirm live callers
- `sed -n` reads of `skill-orchestrate/SKILL.md`'s Move 1/Move 3 bodies to confirm where `dispatch_seq`, staleness, and redeploy-checkpoint logic now live

### References

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (current Move 1-4 structure)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (exemplary correct historical framing, already-updated citations)
- `specs/archive/088_mode_gate_skill_orchestrate_multi_task_section/plans/01_four-move-loop-rewrite.md` (the rewrite's own deferred-scope decision)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (confirms the still-live internal "Stage 3.5" label)
