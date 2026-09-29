# Research Report: Task #136

- **Task**: 136 - Implementation-agent contract corrections: plan-level Status ownership, no
  fan-out, marker/commit sync, validator catch
- **Started**: 2026-09-29T00:00:00Z
- **Completed**: 2026-09-29T00:00:00Z
- **Effort**: ~2 hours (research)
- **Dependencies**: Task 91 (completed, resolution captured below)
- **Sources/Inputs**: Codebase exploration (agent-system/extensions/**), archived task summaries
  (091, 013, 139), live fixture reproductions against `validate-artifact.sh`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 91's dependency is resolved (COMPLETED). Its actual trailing-text policy is **accept and
  preserve** text after the closing `]`; the malformed shapes are (M1) missing `- **Status**:`
  prefix, (M2) no `[...]` bracket pair at all, (M3) text between the prefix and the opening
  bracket. **This task's own dispatch text mis-states this policy** (it lists "trailing text
  after the closing bracket" as one of the three malformed shapes to reject) — the validator
  grammar check in WORK item (b) must reject M1/M2/M3 and ACCEPT trailing-after-bracket text, the
  opposite of what the dispatch literally says.
- DEFECT 2 (validator checks presence, not grammar) is reproduced live today: a plan fixture
  carrying `- **Status**: COMPLETED` (no brackets) validates `[PASS]` under the current
  `validate-artifact.sh`.
- DEFECT 1's "apply to at minimum" list is incomplete and one named file does not exist
  (`general-implementation-hard-agent.md` — general/meta/markdown tasks have no hard-mode agent
  variant). A grep sweep across every `*implementation*agent.md` in the source store finds phase-
  marker-editing instructions, and zero ownership-boundary language, in **13 files**, not 4.
- Task 13 already resolved the `--fix` interaction this task must respect: `--fix` **remains**
  in-place-mutating on the gate-out path, justified as narrow and self-flagging. This decision is
  live and unambiguous — no "task 13 still open" caveat is needed.
- The absorbed former-task-166 thread (report/summary heading conformance) is reproduced live: a
  fixture report carrying `## Context Extension Recommendations` and `## Recommended Next Steps`
  but no `## Recommendations` fails validation with exactly the historically observed message.
  The regex `^##+ ${section}` matches at **any** heading depth, so `general-research-agent.md`'s
  own skeleton (which nests `### Recommendations` under `## Findings`) is already
  validator-conforming — the defect is that a real report drifted from its own conforming
  skeleton, not that the skeleton or the regex is wrong.
- General-implementation-agent.md still carries **zero** fan-out prohibition and zero same-commit
  marker-sync requirement (confirmed by grep), and the same is true of both lean implementation
  agents — the "already landed" half of the absorbed former-task-14 work (in_progress routed to
  STATUS_IN_PROGRESS rather than failed_tasks) is intact and should not be re-touched.

## Context & Scope

Task 136 bundles three previously separate defects around one shared root cause — agent/skeleton
text drifting from what `validate-artifact.sh` enforces — plus one older, still-open contract gap
(fan-out / terminal-status / marker-commit-sync) absorbed from a former task 14. This research
phase verifies every factual claim in the dispatch against the current source-store state (never
the deployed `.claude/` tree), checks the two upstream dependencies' actual resolutions, and
reproduces the defects live with fixtures rather than relying on the dispatch's historical
narrative alone.

Out of scope per the dispatch's own boundary: `update-plan-status.sh`, `update-task-status.sh`,
and `context/formats/plan-format.md` belong to task 91 (already completed; not reopened here).

## Findings

### Codebase Patterns

**Task 91 resolution (the load-bearing dependency).** Read live from
`agent-system/extensions/core/scripts/update-plan-status.sh` and
`agent-system/extensions/core/context/formats/plan-format.md`'s "Plan-level vs. phase-level
markers" → "Trailing annotations on the plan-level Status line" subsection:

- Well-formed: `- **Status**: [STATUS]` optionally followed by arbitrary trailing text after `]`
  — **accepted and preserved** verbatim across a stamp (e.g.
  `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)`).
- M1: the line doesn't even match `^- \*\*Status\*\*:` (missing prefix) → "Plan-level Status line
  not found" (script treats this identically to the line being absent).
- M2: prefix present, no `[...]` pair anywhere on the line → "no [STATUS] bracket pair" error.
- M3: a bracket pair exists but text intrudes **between** the prefix and the opening bracket
  (e.g. `- **Status**: see [NOTE]`) → "unexpected text between the prefix and the bracket" error.

The dispatch text (Task 136's own description, §DEPENDENCY ON 91) frames this as an open
question ("either accept... or reject") and separately lists "trailing text after the closing
bracket" as one of "the three malformed shapes task 91 enumerates" that WORK item (b) must
reject. Both framings are now stale: 91 shipped **accept**, and the three actually-malformed
shapes are M1/M2/M3 above — none of which is "trailing text after the bracket". The validator
grammar check must be written against the real M1/M2/M3 classification, not the dispatch's
literal wording.

**DEFECT 2 reproduced live.** A minimal conforming plan fixture with
`- **Status**: COMPLETED` (metadata field present per the existing substring check, but
unbracketed) validates:

```
$ bash agent-system/extensions/core/scripts/validate-artifact.sh <fixture> plan
Validating plan: <fixture>
  [WARN]  Missing Dependency Analysis table under Implementation Phases
[PASS] plan artifact is valid (1 warning(s))
```

Confirms the dispatch's claim exactly: presence-only `grep -qF "**Status**:"` at
`validate-artifact.sh:120-124` never inspects the bracket grammar, for any of the three types
(plan/report/summary) that share this loop.

**DEFECT 1 sweep — the "at minimum" list undercounts by a wide margin, and misnames one file.**
`extensions/core/agents/general-implementation-hard-agent.md` does not exist:
`manifest.json`'s `routing_agents_hard` (or lack thereof) confirms `general`/`meta`/`markdown`
task types have no hard-mode agent variant — `general`, `meta`, and `markdown` all route to the
single `general-implementation-agent` regardless of `--hard`. The dispatch's fourth "at minimum"
target is not a real file.

A grep sweep for phase-marker-editing instructions (`### Phase {P}: ... [STATUS]` Edit
instructions, "Mark Phase In Progress/Complete", or `MUST update phase status markers`) across
every `*implementation*agent.md` under `agent-system/extensions/`, cross-checked against a
second grep for existing ownership language (`update-plan-status|plan-level.?status|owned by
update-plan-status`), found:

| File | Phase-marker instructions? | Ownership boundary present? |
|------|---|---|
| `core/agents/general-implementation-agent.md` | yes | no |
| `lean/agents/lean-implementation-agent.md` | yes | no |
| `lean/agents/lean-implementation-hard-agent.md` | yes ("Mark Phase In Progress/Complete") | no |
| `cslib/agents/cslib-implementation-agent.md` | yes | no |
| `cslib/agents/cslib-implementation-hard-agent.md` | yes ("Mark Phase In Progress" edit) | no |
| `python/agents/python-implementation-agent.md` | yes | no |
| `rust/agents/rust-implementation-agent.md` | yes | no |
| `latex/agents/latex-implementation-agent.md` | yes | no |
| `typst/agents/typst-implementation-agent.md` | yes | no |
| `z3/agents/z3-implementation-agent.md` | yes | no |
| `nvim/agents/neovim-implementation-agent.md` | yes | no |
| `nix/agents/nix-implementation-agent.md` | yes ("Mark Phase In Progress/Complete") | no |
| `web/agents/web-implementation-agent.md` | yes ("Mark Phase In Progress/Complete") | no |
| `cslib/agents/pr-review-implementation-agent.md` | no (reads plans only) | n/a |
| `email/agents/email-implementation-agent.md` | no (wrapper-only; reads plan steps, doesn't edit phase headings) | n/a |

**13 files** need the ownership boundary, not 4; 2 files (`pr-review-implementation-agent.md`,
`email-implementation-agent.md`) are correctly out of scope. Zero files currently carry any
ownership language — the "verified absent by grep" claim in the dispatch generalizes cleanly to
the full set.

**Shared-mechanism option is already available without inventing new infrastructure.**
`plan-format.md`'s "Plan-level vs. phase-level markers" subsection (written by task 91, which
already shipped) is the authoritative statement of the two-vocabulary/two-owner distinction. Task
136 cannot edit that file (task 91's `file_scope`), but every implementation-agent contract can
**point to it** rather than re-deriving the explanation locally. The recommended remedy (see
Decisions) is a short (2-4 line), near-identical ownership paragraph in all 13 files, ending in a
pointer to that existing subsection — not a new standards file, and not a bespoke explanation
per agent.

**--fix interaction (WORK item c) is resolved, not open.** Task 13 (archived, COMPLETED) decided
**D-A: `--fix` remains in-place-mutating on the gate-out path**, reasoned as narrow (a single
placeholder line for a missing metadata field) and self-flagging (every repair is reported via
`skill_validate_task_artifacts`'s aggregated counters and an `events.jsonl` row — task 13's own
deliverable). The dispatch's "NOTE THE INTERACTION... do not silently add a new in-place mutation
while that decision is open" caveat no longer applies as an open-decision caveat; it now reads as
"be consistent with D-A", which is a narrower, easier bar.

**Fan-out / terminal-status / marker-commit-sync (absorbed former task 14) — confirmed still
open, confirmed nothing to undo.** Grep for fan-out/sub-agent/terminal-status/marker-commit-sync
language returns zero hits in `general-implementation-agent.md`, `lean-implementation-agent.md`,
and `lean-implementation-hard-agent.md` alike — the contract-side gap the dispatch describes is
real and unaddressed. Separately, `orchestrate-recover-outcome.sh:323-324` still emits a clean
`STATUS_IN_PROGRESS` verdict for `status: "in_progress"` (never routing it to `failed_tasks`),
confirming the "already landed" half (status-vocabulary handling) remains correct and must not be
re-litigated, exactly as the 2026-08-24 revision recorded.

**Absorbed former-task-166 thread (report/summary heading conformance) — reproduced live, root
cause confirmed narrower than "the skeleton is wrong".**

1. Fixture reproduction: a report with `## Context Extension Recommendations` and
   `## Recommended Next Steps (for the plan phase)` but no `## Recommendations` fails:
   `[ERROR] Missing required section: ## Recommendations` — byte-for-byte the historically
   observed failure.
2. Mechanical check of `general-research-agent.md`'s own embedded report skeleton: it contains
   `### Recommendations` at depth 3 (nested under `## Findings`). `validate-artifact.sh`'s check
   is `grep -qE "^##+ ${section}"` — `##+` matches **two or more** `#` characters, so depth 3
   (`###`) satisfies it exactly as depth 2 (`##`) would. **The skeleton is not, and never was,
   validator-non-conforming; burial does not cause a false negative in the regex.** The defect is
   purely that a real dispatch produced prose that departed from its own already-conforming
   skeleton (used "Context Extension Recommendations" / "Recommended Next Steps" instead of
   "Recommendations").
3. Applying the direct fix — inserting a top-level `## Recommendations` section alongside the
   existing near-miss headings, changing nothing else — flips the same fixture to
   `[PASS] report artifact is valid (0 warning(s))`. The near-miss headings coexisting with a
   conforming one does not interfere (confirms remedy (i)-class fixes are sufficient; validator
   relaxation, option (iii) in the dispatch, is unnecessary as well as dangerous).
4. Scope check across every agent in `agent-system/extensions/core/agents/` (the canonical-source
   constraint's actual boundary — "core" means this directory, confirmed by the dispatch's own
   `CANONICAL SOURCE CONSTRAINT`):
   - `general-research-agent.md` — embeds a full report skeleton; `### Recommendations` present,
     validator-conforming (see above). **This is the only core agent whose authored output was
     observed to drift.**
   - `general-implementation-agent.md` — embeds a full summary skeleton; all six
     `SUMMARY_SECTIONS` (Overview, What Changed, Decisions, Impacts, Follow-ups, References)
     present as top-level `##` headings. Fully conforming; no defect found.
   - `planner-agent.md` — embeds a full plan skeleton; all seven `PLAN_SECTIONS` (Overview,
     Goals & Non-Goals, Risks & Mitigations, Implementation Phases, Testing & Validation,
     Artifacts & Outputs, Rollback/Contingency) present as top-level `##` headings. Fully
     conforming; no defect found.
   - `reviser-agent.md` — carries **no embedded skeleton at all**; it instructs "follow
     plan-format.md structure exactly" by pointer only. Structurally immune to this entire defect
     class (nothing to drift from locally), which is itself worth noting as a contrast: a
     pointer-only contract cannot drift the way an embedded copy can.
   - `code-reviewer-agent.md`, `meta-builder-agent.md`, `spawn-agent.md` — none carry a
     report/plan/summary skeleton subject to `validate-artifact.sh` at all (spawn-agent's output
     is a task-spawn proposal, not a validated artifact type).

### External Resources

Not applicable — this is a closed-codebase contract/validator consistency question with no
external dependency.

### Recommendations

1. **Grammar check target (WORK b)**: implement the plan-level Status grammar check against the
   real M1/M2/M3 classification (missing prefix / no bracket pair / text before the bracket),
   accepting arbitrary trailing text after `]`. Do not implement the dispatch's literal wording
   ("trailing text after the closing bracket" as malformed) — that would re-diverge from task
   91's shipped policy the moment it is implemented. Strongly prefer extracting the
   classification logic into a shared function both `update-plan-status.sh` and
   `validate-artifact.sh` call (mirroring the existing `phase-heading-patterns.sh` shared-library
   idiom already used for the plan-specific phase-heading checks in the same script), rather than
   re-deriving the same regex independently in two places.
2. **Ownership boundary target (WORK a)**: apply to all 13 files enumerated above, not the 4
   named "at minimum" (and not the non-existent
   `general-implementation-hard-agent.md`). Each gets a short, near-identical paragraph near its
   existing phase-marker instructions, stating the metadata `- **Status**:` field is owned by
   `update-plan-status.sh`/postflight and MUST NOT be hand-edited, ending in a pointer to
   `plan-format.md`'s existing "Plan-level vs. phase-level markers" subsection rather than
   restating that subsection's content locally.
3. **--fix participation (WORK c)**: state explicitly that this decision follows task 13's D-A
   precedent (narrow, self-flagging, in-place, reported via the same counter/events-row
   mechanism) rather than treating D-A as still-open. A grammar auto-repair that rewrites only
   the bracketed token (mirroring `update-plan-status.sh`'s own mutating `sed`, which never
   touches trailing text) fits D-A's "narrow" bar; report-only is the safer fallback if the plan
   phase judges the repair ambiguous for any malformed shape (e.g. M3, where there's no
   unambiguous way to auto-derive the intended bracket contents from text before it).
4. **Report/summary heading remedy**: adopt (i) — state the five/six/seven required heading
   strings verbatim in each authoring agent's contract and mark them non-paraphrasable — paired
   with (ii) for `general-research-agent.md` specifically (promote `### Recommendations` to a
   top-level `## Recommendations`, since it is the one skeleton observed to be departed from in
   real output, even though the regex already tolerates its current depth). Do not pursue (iii)
   (validator relaxation) — proven both unnecessary (the regex already matches at any depth) and
   dangerous (a substring relax would let `## Context Extension Recommendations` pass, converting
   a true failure into a false pass, matching the dispatch's own warning). No change needed to
   `general-implementation-agent.md` or `planner-agent.md`'s skeletons — both already conform.
5. **Fan-out / terminal-status / marker-commit-sync**: this is a genuine design decision (the two
   "TWO INDEPENDENT QUESTIONS" in the dispatch), not something research can resolve by grepping —
   hand to the plan phase as-is. Do not touch the already-correct `in_progress` →
   `STATUS_IN_PROGRESS` routing in `orchestrate-recover-outcome.sh`.

## Decisions

- Treat task 91 as fully resolved and authoritative; this task's own dispatch prose about "three
  malformed shapes" is superseded by 91's actual M1/M2/M3 classification and accept-trailing-text
  policy, and the plan phase should implement against the code/docs, not the dispatch's framing.
- Treat task 13 as fully resolved (D-A); the `--fix` interaction is a consistency check against a
  shipped decision, not an open question to re-litigate.
- Scope the report/summary-heading remedy to `general-research-agent.md`'s skeleton + contract
  wording only; `general-implementation-agent.md`, `planner-agent.md`, and `reviser-agent.md`
  require no change under this thread (verified conforming or structurally immune).
- Scope the ownership-boundary work to the 13-file list above; drop the non-existent
  `general-implementation-hard-agent.md` target; exclude `pr-review-implementation-agent.md` and
  `email-implementation-agent.md` (no phase-marker-editing authority to bound).

## Risks & Mitigations

- **Risk**: implementing the validator grammar check by re-deriving the M1/M2/M3 regexes
  independently in `validate-artifact.sh` instead of sharing logic with `update-plan-status.sh`
  risks future drift between the two (exactly the class of bug this task exists to prevent).
  **Mitigation**: extract to a shared library function at plan time, following the
  `phase-heading-patterns.sh` precedent already present in the same script.
- **Risk**: adding the ownership-boundary paragraph to 13 files by hand risks minor wording
  drift across files. **Mitigation**: use one exact paragraph text, copied verbatim into each of
  the 13 files (a mechanical, not creative, edit), verified afterward by grep for the paragraph's
  exact opening clause across all 13 targets.
- **Risk**: auto-fixing the Status grammar (if the plan phase chooses to participate in --fix)
  could silently "repair" an M3 case (text before the bracket) by guessing wrong. **Mitigation**:
  as noted in Recommendations item 3, prefer auto-repair only for shapes with an unambiguous
  correction (missing brackets/prefix around an otherwise-recognizable status word) and
  report-only for M3.

## Context Extension Recommendations

- None identified beyond what task 91 already documented in `plan-format.md`. The existing
  "Plan-level vs. phase-level markers" subsection is sufficient as the pointed-to authority for
  the new agent-contract paragraphs; no new context file is needed for this task.

## Appendix

### Fixture commands used to reproduce defects live

```bash
# DEFECT 2 (validator checks presence, not grammar) — a plan with an unbracketed Status
# field validates PASS today:
bash agent-system/extensions/core/scripts/validate-artifact.sh <plan-fixture-with-Status:-COMPLETED-unbracketed> plan
# -> [PASS] plan artifact is valid (1 warning(s))

# Former-task-166 thread — report with near-miss Recommendations headings, no conforming one:
bash agent-system/extensions/core/scripts/validate-artifact.sh <report-fixture> report
# -> [ERROR] Missing required section: ## Recommendations ; [FAIL] 1 error(s), 0 warning(s)

# Same fixture with a top-level "## Recommendations" section added alongside the near-miss
# headings (nothing else changed):
bash agent-system/extensions/core/scripts/validate-artifact.sh <report-fixture-fixed> report
# -> [PASS] report artifact is valid (0 warning(s))
```

### Sweep commands used for the 13-file enumeration

```bash
find agent-system/extensions -iname "*implementation*agent.md"
grep -nE "### Phase \{P\}|MUST update phase status markers|Mark Phase (In Progress|Complete)" <file>
grep -icE "update-plan-status|plan-level.?status|owned by update-plan-status" <file>
```

### References consulted

- `agent-system/extensions/core/scripts/update-plan-status.sh` (M1/M2/M3 classification, accept
  policy for trailing text)
- `agent-system/extensions/core/context/formats/plan-format.md` ("Plan-level vs. phase-level
  markers" subsection)
- `agent-system/extensions/core/scripts/validate-artifact.sh` (metadata/section check loops,
  `REPORT_SECTIONS`/`SUMMARY_SECTIONS`/`PLAN_SECTIONS` arrays)
- `agent-system/extensions/core/manifest.json` (`routing_agents_hard` — confirms no
  general-implementation-hard-agent)
- `specs/archive/091_fail_loudly_on_nonconforming_plan_status_line/summaries/01_status-line-diagnostics-and-tolerance-summary.md`
- `specs/archive/013_instrument_gate_out_auto_repair_reporting/summaries/01_gate-out-repair-reporting-summary.md`
- `specs/archive/139_forbid_concurrent_writer_history_rewrites/summaries/01_forbid-concurrent-writer-rewrites-summary.md`
- All 15 `*implementation*agent.md` files under `agent-system/extensions/` (13 in-scope + 2
  out-of-scope, enumerated above)
- `agent-system/extensions/core/agents/{general-research,general-implementation,planner,reviser,
  code-reviewer,meta-builder,spawn}-agent.md`
