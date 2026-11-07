# Research Report: Cross-Phase Numeric Ceiling Consistency in Plans

**Task**: 464 - Plan cross-phase line/scope budget consistency
**Started**: 2026-11-06T00:00:00Z
**Completed**: 2026-11-06T00:00:00Z
**Effort**: small (one rule + one advisory check)
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/core/context/formats/plan-format.md`,
`agent-system/extensions/core/scripts/validate-artifact.sh`, `agent-system/extensions/core/rules/plan-format-enforcement.md`,
live `specs/` corpus), dispatch file `.dispatch/2.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The gap is real and structural, not a missing field: `plan-format.md` already requires a
  per-phase `**Scope Hypothesis:**` line whenever a phase asserts a count/estimate, but nothing
  compares those per-phase numbers to each other or to a numeric ceiling the same plan cites in
  its own prose. A plan can therefore assert conformance ("stays well under 1500") while its own
  per-phase arithmetic sums past the cited ceiling, and nothing catches the contradiction at plan
  time.
- `validate-artifact.sh` already isolates each phase into a `phase_block` string inside an
  existing loop (the Verification-Tier / Files-to-modify check), and the file already has a
  working advisory-first → promotion-criterion pattern used twice. This is the natural, lowest-
  cost consumer to extend — no new script is warranted.
- `**Scope Hypothesis:**` is explicitly documented as free-form prose, not a harvested structured
  field, and this repository's own live plans (`specs/328_.../plans/03_...md`,
  `specs/482_.../plans/01_...md`) already cite numeric ceilings in exactly this unstructured,
  prose way. A new required field would impose cost on every plan author for a problem that free-
  prose already expresses adequately for a human reader; a **heuristic, best-effort regex check**
  over existing prose — not a new field — is both sufficient and consistent with the advisory
  posture already in force for `Verification Tier`.
- **Recommendation: (b), layered on a mandatory stated rule.** Add one general subsection to
  `plan-format.md` (the stated rule, required under all three options per the dispatch's
  Acceptance criterion) and one new advisory check block in `validate-artifact.sh` that sums
  per-phase numeric estimates found in `Scope Hypothesis` text and flags a plan that also asserts
  conformance against a ceiling its own sum contradicts. (a) alone is rejected as too weak (the
  incident is already an author-arithmetic failure); (c) alone is rejected as non-durable (a
  planner-agent checklist item is not retained across model/agent churn the way a format-file
  rule and a script check are).

## Context & Scope

Researched: how to state, and optionally mechanically check, that a plan's own per-phase numeric
estimates of some ceiling-governed quantity do not contradict a numeric ceiling the same plan
cites and claims to respect. Carried verbatim from the dispatch, marked `CARRIED-UNVERIFIED`
since it originates in a different repository's issue log (BimodalLogic, task `849`,
`iss_1793754003650_RvAmat`): a plan with per-phase estimates `110+120+95+10+90+80+130` against a
`959`-line starting file summed to `~1594`, past a `1500`-line ceiling the same plan cited, while
its Rollback/Contingency note asserted the file "stays well under 1500". Not independently
re-derivable here (the originating file is not in this repository); treated as the illustrating
incident only, with `longFile` itself never acquiring a Lean-specific clause in the governing
format document, per the dispatch's explicit generality requirement.

Explicitly out of scope (per dispatch Non-Goals): improving line-estimate *accuracy*, adding a
*blocking* gate over approximate numbers, and any Lean-specific clause in `plan-format.md`.

Both files this record touches (`plan-format.md`, `validate-artifact.sh`) sit under the
`core` extension's `source_dir` (`agent-system/extensions/core/`) resolved from
`.claude-extensions.json`; any implementation must edit there and redeploy, never hand-author
under a deployed `.claude/` tree (`rules/source-store-deploy-boundary.md`).

**Live-corpus check**: `plan-format.md` is high-traffic (several unstarted tasks name it in
`file_scope` under other topics, per the dispatch's own Territory Note). At research time no
live plan round text was re-grepped for the specific deleted-lifecycle-command names the
dispatch flags as the one residual coordination risk — that grep belongs at plan-authoring time,
immediately before editing, since the contending set "drifts" per the dispatch's own caveat.

## Findings

### Codebase Patterns

**1. The existing carrier field is explicitly free-form, by design.**
`plan-format.md`'s "Counts-are-hypotheses obligation" section (~L461-468) states: "Any count,
file list, or scope estimate asserted in a plan is a hypothesis requiring implementation-time
confirmation... When a phase asserts one, it carries a **Scope Hypothesis:** line." Three lines
later (~L485-488): "**`**Scope Hypothesis**:` is deliberately not a harvest source for
`file_scope`. It is free-form prose about a claim to confirm." There is no structured
sub-grammar inside it today — a per-phase numeric estimate is whatever English the author wrote
("adds ~110 lines to `Foo.lean`").

**2. No plan-level structured ceiling field exists either.** A numeric ceiling is cited only in
free prose, wherever the author chooses to put it (Goals & Non-Goals, Risks & Mitigations, or — in
the originating incident — the Rollback/Contingency section, which `plan-format.md`'s own
template (~L908-910) shows as a bare bullet list with zero structure: `## Rollback/Contingency` /
`- ...`).

**3. This repository's own live plans already cite numeric ceilings in exactly this unstructured
way**, confirming the pattern is real here, not just in the carried incident:
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`
  performs its own ad hoc "NET-MD accounting" across phases — e.g. (L3357-3360) "this phase
  NET-MD = -6; running total since Phase 17 = -849. The -2,100 (and the revised ≈482-line
  ceiling) allocation is NOT met" — a hand-rolled, per-task cumulative-vs-ceiling narrative with
  no format-level support.
- `specs/482_create_sapience_extension/plans/01_create-sapience-extension.md` (L248) cites
  "`EXTENSION.md` against Rule U's 60-line ceiling. The ceiling is a verified external
  constraint..." — the same "cite a ceiling in prose, then assert conformance" shape the
  BimodalLogic incident got wrong, just not (here) summed incorrectly.

  This shows the generalized rule is pulling its weight on this repository's own corpus, not only
  on a hypothetical Lean case — "ceiling" language recurs independent of file type or domain.

**4. `validate-artifact.sh` already has the exact per-phase block-isolation machinery a
mechanical check would need**, and does not need a new script. The "Per-phase Verification Tier
check" (lines ~303-343) already:
```bash
mapfile -t phase_line_nums < <(grep -nE "$PHASE_HEADING_ERE" "$artifact_path" | cut -d: -f1)
...
phase_block=$(sed -n "${start_line},${end_line}p" "$artifact_path")
tier_value=$(echo "$phase_block" | grep -oE '\*\*Verification Tier\*\*:...' ...)
```
— i.e. it already walks every phase, isolates that phase's own text block, and regex-extracts a
field value from it, inside the one `if [ "$artifact_type" = "plan" ]` branch. A new check for
per-phase numeric estimates is a sibling block in the same loop, reading the same `phase_block`
variable, not a new parsing pass or a new file.

**5. The advisory-first → promotion-criterion pattern is already established twice in this same
file**, and is explicitly documented in `plan-format.md`'s "Enforcement level" and "Enforcement
level (Files to modify)" subsections (~L490-529): a missing/violating field emits `log_warn`
(counted but non-blocking in default mode; `--strict` promotes `total_issues = errors + warnings`
to a failing exit), with a *named, measurable* promotion criterion recorded for a future task
("promote ... once no non-terminal plan under `specs/` lacks the field", with the exact current
residue counted and named). Any new check for this task should follow the same shape rather than
inventing a third enforcement convention.

**6. No existing mechanism touches this gap.** A repo-wide grep for `line budget`, `line
estimate`, `line ceiling`, `longFile`, `stays well under` inside `agent-system/extensions/core/`
and `agent-system/extensions/lean/` returned nothing — confirming the dispatch's own
duplicate-check claim. `longFile`/`LEAN_STYLE_GUIDE`/`MODULE_INVARIANTS` do not appear anywhere
in this repository's `agent-system/` tree at all (they are BimodalLogic-only), so there is no
risk of accidentally inheriting a Lean-specific clause by habit.

### External Resources

Not applicable — this is a pure in-repo format/tooling question with no external library or API
dependency; no web research was performed.

## Decisions

- **Decision: adopt option (b) — a generalized, advisory-first mechanical check added to
  `validate-artifact.sh`'s existing per-phase plan loop — layered on the mandatory stated rule
  the dispatch's Acceptance criterion requires under every option.** The rule is sited once, as a
  new subsection in `plan-format.md` immediately after "### Counts-are-hypotheses obligation"
  (its natural sibling — same obligation family, narrower claim), tentatively titled
  "### Cross-phase ceiling consistency obligation", generalized to "a numeric ceiling for any
  quantity a plan cites against a per-phase estimate of that same quantity," with `longFile`
  appearing only as one parenthetical worked example, per the dispatch's generality requirement.
- **Rejected: (a), authoring rule only, no enforcement.** The dispatch's own framing is decisive
  here: "the incident IS an author not doing the arithmetic, so a rule asking for the same
  arithmetic again is weak." Finding 3 above reinforces this — this repository's own authors
  already write ceiling-citing prose today, under no rule at all, and the NET-MD accounting case
  shows at least one author already doing ad hoc cumulative tracking by hand; a rule with zero
  mechanical backstop adds nothing the careful authors weren't already doing and does nothing for
  the inattentive case the incident actually was.
- **Rejected: (c), planner-agent checklist item, as the primary mechanism.** A checklist item
  lives in an agent's own prompt/instructions, which are far more volatile than a format document
  or a shell script under test — there is no durable record that the check ran, no counted
  residue, and no promotion path to a stronger guarantee the way `validate-artifact.sh`'s
  documented promotion criteria provide. It also duplicates work the research found a cheaper
  existing consumer already does well (Finding 4). Not useless as a *supplementary* nudge, but
  recorded as rejected for the primary enforcement role on durability grounds.
- **Decision: no new required field.** `**Scope Hypothesis:**` stays free-form prose; the check
  reads it with a best-effort regex rather than requiring authors to adopt a new microformat.
  This directly answers the dispatch's own open cost question ("a check needs either a parse
  heuristic or a new field... a new required field has its own cost across every plan author") —
  research found the parse-heuristic path strictly cheaper here, because (i) Finding 3 shows
  authors already phrase estimates and ceilings in plain, grep-able English without being asked
  to, and (ii) the check is advisory, so a heuristic's unavoidable false-negative rate (missing a
  badly-phrased estimate) is an acceptable cost — it only ever adds a warning when it *does* catch
  a contradiction, never silently approves one by omission of a stricter requirement.

## Recommendations

1. **Rule text (plan-format.md, new subsection after "Counts-are-hypotheses obligation"):**
   state that when a plan cites a numeric ceiling for some quantity (a line-count limit, a
   file-count budget, a token budget — `longFile` only as an example) and one or more phases
   carry a `**Scope Hypothesis:**` estimating that same quantity, the plan's own numbers must be
   internally consistent: it MUST NOT assert elsewhere in its own prose (Goals & Non-Goals, Risks
   & Mitigations, Rollback/Contingency, or a phase block) that the quantity "stays under" /
   "remains within" the ceiling when the plan's own per-phase estimates, summed against any
   stated starting baseline, already exceed it. Where the author expects the quantity to approach
   or cross the ceiling, the plan must say so and name its own contingency (e.g. widening the
   ceiling via the governing linter/limit's own sanctioned escape valve, splitting a phase, or
   re-scoping) rather than asserting conformance the plan's own numbers contradict.
2. **Mechanical check (validate-artifact.sh, new block inside the existing plan-type `if`
   branch, sibling to the Verification-Tier loop at ~L303-343, reusing the same
   `phase_line_nums`/`phase_block` machinery):**
   - During the existing per-phase loop, additionally regex-extract a bare numeric-with-unit token
     from each phase's `Scope Hypothesis` text (e.g. `~?[0-9]+\+?\s*(lines?|LOC)` — generalized
     enough to also match a file-count or token-count unit word) and accumulate a running sum per
     distinct unit word encountered.
   - After the loop, scan the *whole document* (not phase-scoped — ceiling citations and
     conformance assertions both live in plan-level prose, per Finding 2) for (i) a ceiling
     citation matching the same unit word near a ceiling-indicating word (`ceiling|limit|budget|
     cap`) and (ii) a conformance assertion near the same number (`stays|remains` + optional
     `well` + `under|within|below`).
   - If both are found for the same unit word AND the accumulated per-phase sum exceeds the cited
     ceiling, `log_warn` naming the phase(s), the summed total, and the cited ceiling — advisory
     only, exactly mirroring the Verification-Tier pattern's `log_warn` (never `log_error` in
     default mode; `--strict` promotes via the existing `total_issues = errors + warnings`
     branch).
   - Document a promotion criterion in `plan-format.md`'s "Enforcement level" subsection, in the
     same shape as the two existing ones: promote to error once a corpus sweep of non-terminal
     `specs/` plans shows zero plans would newly fail — not performed as part of this research,
     left for the task that lands the check (mirrors how the two existing promotion criteria were
     each recorded by the task that introduced their check, not executed by it).
3. **Scope the implementation plan to exactly these two edits** — no new script, no new required
   field, no change to `Scope Hypothesis`'s existing free-form status, no Lean-specific clause.
   Both target files resolve under `agent-system/extensions/core/` via `.claude-extensions.json`'s
   `source_dir`; redeploy after editing, per the dispatch's own SOURCE STORE note.
4. **At plan-authoring time**, re-run the dispatch's own residual-risk grep (deleted
   lifecycle-command names against `plan-format.md`) before editing, since the dispatch itself
   flags that contention as drift-prone rather than settled.

## Risks & Mitigations

- **Heuristic false negatives** (a badly-phrased or oddly-worded estimate/ceiling the regex
  misses): acceptable because the check is advisory-only and strictly additive — it never
  suppresses a warning a stricter rule would have raised; it only ever adds one.
- **Heuristic false positives** (an unrelated number near an unrelated "ceiling"/"under" word):
  mitigated by requiring the *same unit word* to co-occur in both the per-phase estimate and the
  plan-level ceiling citation, and by requiring an explicit nearby ceiling-indicating word
  (`ceiling|limit|budget|cap`) rather than matching bare numbers; residual risk is a warning that
  is spurious but non-blocking in default mode, consistent with how the existing
  Verification-Tier/Files-to-modify warnings already tolerate some imprecision.
- **Scope creep toward "estimate accuracy"**: mitigated by keeping the rule's trigger condition
  purely about *internal arithmetic contradiction*, never about whether the estimates themselves
  are realistic — exactly the dispatch's own Non-Goals boundary.
- **Territory contention on `plan-format.md`**: multiple unstarted tasks declare this file in
  `file_scope` under unrelated topics (prose rewording, script/test corpus consolidation); none
  touches the counts-are-hypotheses section or line-estimate arithmetic on substance, so no
  dependency edge is warranted, but the plan phase should re-grep for the one named residual risk
  (a deleted-lifecycle-command rename landing in this same file) before editing.

## Context Extension Recommendations

- **Topic**: cross-phase numeric-consistency checks in plan artifacts.
- **Gap**: `plan-format.md` documents several per-phase scalar obligations (`Verification Tier`,
  `Files to modify`, `Scope Hypothesis`) but, before this task, no guidance existed for a
  *relationship between* per-phase numbers and a plan-level numeric claim. No context file
  currently names this pattern generally (confirmed via `index-entries.json` topic grep — no
  `plan-format`/`scope-hypothesis`/`line`-named topic under the `core-agent-system` subdomain).
- **Recommendation**: once this task's rule lands, consider whether
  `context/patterns/` (or a similar cross-cutting location) should gain a short pattern note
  generalizing "plan-level numeric claims must be checked against their own cited per-phase
  arithmetic" as a reusable authoring pattern beyond `plan-format.md` itself (e.g. for
  `report-format.md`'s own Carried-Figure Discipline, which governs a related but distinct
  claim-provenance obligation). Not performed here — this task's scope is `plan-format.md` and
  `validate-artifact.sh` only, per the dispatch's own Non-Goals.

## Appendix

Searches/greps performed:
- `grep -rn "Scope Hypothesis\|Counts-are-hypotheses" agent-system/extensions/core/context/formats/plan-format.md`
- `grep -n "Verification Tier\|per-phase\|advisory\|STRICT\|longFile\|line.*budget\|ceiling" agent-system/extensions/core/scripts/validate-artifact.sh`
- `grep -rln "longFile\|long-file\|LEAN_STYLE_GUIDE\|MODULE_INVARIANTS" agent-system/` (no hits)
- `grep -rln "stays well under\|stays under\|remains under\|well under [0-9]\|line budget\|line ceiling" specs/` (non-archive hits enumerated in Findings)
- `jq -r '.entries[] | select(.subdomain == "core-agent-system") | .topics[]' .../index-entries.json` (no matching topic names)

References:
- `agent-system/extensions/core/context/formats/plan-format.md` (~L85-229 phase fields, ~L461-529
  Counts-are-hypotheses obligation and Enforcement level subsections, ~L895-911 worked template)
- `agent-system/extensions/core/scripts/validate-artifact.sh` (~L27-52 header notes, ~L303-368
  per-phase Verification-Tier / Files-to-modify loop)
- `agent-system/extensions/core/rules/plan-format-enforcement.md`
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`
  (~L3283, ~L3357-3360)
- `specs/482_create_sapience_extension/plans/01_create-sapience-extension.md` (~L248)
