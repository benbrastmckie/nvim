# Research Report: Task #360

- **Task**: 360 - Evidence discipline for report and plan artifacts, in three phases: validate
  that a CARRIED-UNVERIFIED mark names a source, extend the carried-figure obligation to
  recommendations and dispatch premises, and require a self-derived enumeration to state and
  stress-test its search pattern
- **Started**: 2026-11-09T00:00:00Z
- **Completed**: 2026-11-09T00:00:00Z
- **Effort**: ~3 hours (research)
- **Dependencies**: 328, 358, 385, 407, 428, 446 (all resolved/archived at dispatch time)
- **Sources/Inputs**: Codebase (`agent-system/extensions/core/context/formats/report-format.md`,
  `plan-format.md`, `scripts/validate-artifact.sh`, `scripts/tests/test-validate-artifact.sh`,
  `agents/general-research-agent.md`, `agents/planner-agent.md`,
  `scripts/orchestrate-build-dispatch.sh`); live corpus grep over `specs/**`; archived task
  `specs/archive/358_require_rederivation_of_carried_figures_in_artifacts/` (report, plan,
  summary, `progress/phase-4-progress.json`)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The narrow well-formedness check (Phase 1) is straightforward and belongs in
  `scripts/validate-artifact.sh`, advisory-only (`log_warn`), following the existing
  Verification Tier / Files-to-modify precedent exactly. It must gate on
  `artifact_type` in `{report, plan}` only — `summary-format.md` carries no Carried-Figure
  Discipline obligation, confirmed by grep (zero hits).
- The real corpus currently contains exactly **3 live `[CARRIED-UNVERIFIED:` marks** across
  `specs/**` (2 in an archived plan, 1 in an open report), and **all 3 are well-formed**
  (non-empty, correctly-cited sources). Projected flag count against the live corpus today is
  **zero** — well within any triageable threshold. One of the 3 live marks is genuinely
  line-wrapped across 3 source lines, which is direct, present-in-the-wild evidence that the
  check must not be a naive single-line `grep -E`.
- The central engineering finding, directly inherited from the rejected general detector's own
  post-mortem (`specs/archive/358.../progress/phase-4-progress.json`, re-derived below): a
  single-line-oriented pattern is the exact failure shape that sank the earlier, more ambitious
  detector (markdown bold split its trigger phrase). The fix here is narrow and cheap — flatten
  newlines before matching — but it must be done deliberately, not assumed away, because this
  check's own literal token is open to the same class of miss if the implementation is naive.
- Both "ALSO SETTLE" questions are ruled NO, each independently grounded in this report's own
  evidence, not asserted on the dispatch's stated prior alone:
  - **Does-the-source-resolve?** NO. The real corpus shows the source designator is
    legitimately prose, not always a filesystem path (e.g. "this report's own dispatch
    instructions; no corresponding entry was found in `specs/events.jsonl`..."). A
    resolve-check would misfire on exactly this legitimate shape.
  - **Is a mark OWED (missing-mark detection)?** NO, for the same reason the general detector
    failed its gate: distinguishing a copied claim from an independently-derived one is a
    semantic provenance judgment, not a greppable pattern.
- Phase 2 (Part A: recommendation behaviour-preservation; Part B: dispatch-premise staleness,
  plus the further "contradicted-by-a-prior-artifact" B-case) and Phase 3 (enumeration
  completeness + verification independence) are both real, currently-undocumented gaps,
  confirmed by direct inspection of `planner-agent.md` and `general-research-agent.md` (neither
  file contains any re-measurement, staleness, or completeness-trigger language today). Concrete
  phase designs are recommended below.

## Context & Scope

This task folds three originally-separate backlog records (per the ROADMAP's settled
linear-chain-becomes-one-task-with-phases rule) plus two later-folded B-cases, all amending the
same `## Carried-Figure Discipline` section of `report-format.md` and the same validator
(`scripts/validate-artifact.sh`) / fixture suite
(`scripts/tests/test-validate-artifact.sh`). Phase order, fixed by the folded records' own
dependency edges: **Phase 1** (narrow well-formedness check on the `CARRIED-UNVERIFIED` token —
this is the only piece with a hard, cross-task dependency edge: task `488`'s concurrent-sibling
territory and other now-closed records explicitly require Phase 1 to land first as "the first
mechanical surface for this convention"), **Phase 2** (widen the obligation to a
recommendation's mechanical claim, Part A; and to a dispatch's acted-on premise, Part B, plus
the further B-case), **Phase 3** (require a self-derived enumeration to state and stress-test
its search pattern).

This report researches all three phases so the planner can build one coherent multi-phase plan,
per the dispatch's own instruction that the three phases are deliberately one record, not three.

## Findings

### Phase 1 — The narrow well-formedness check

**Where it belongs.** `scripts/validate-artifact.sh` already has a well-established
advisory-first idiom for exactly this shape of check: the per-phase **Verification Tier**
check (lines ~328-367) and the **Files to modify** authoring-shape scan (lines ~380-437) both
(a) run only `log_warn`, never `log_error`, in default mode; (b) are gated by `artifact_type`;
(c) carry an explicit, commented promotion criterion stating what would need to be true before
upgrading to `log_error`; and (d) leave `--strict` to fold warnings into the exit-affecting
total (`total_issues=$((errors + warnings))` only under `--strict`, confirmed at the script's
tail, lines ~658-667). The new check should follow this idiom verbatim: `log_warn`, gated,
promotion criterion stated in a comment, no `--strict` behavior change needed beyond what the
existing `total_issues` accumulation already provides for free.

**Type gating.** The check applies only to `artifact_type` in `{report, plan}`. Verified by
grep: `summary-format.md` contains zero occurrences of `Carried-Figure` or `CARRIED-UNVERIFIED`
— the convention's own Placement record states it governs "both report and plan artifacts," and
plan-format.md points at report-format.md rather than restating; summary is never named. The
check must sit **outside** the existing `if [ "$artifact_type" = "plan" ]; then ... fi` block
(which is plan-only), as a sibling block gated on `[ "$artifact_type" = "report" ] || [
"$artifact_type" = "plan" ]`, placed after the "Check required sections" loop.

**The recall-failure mode, concretely.** The rejected general detector's own post-mortem
(re-derived verbatim from `specs/archive/358_require_rederivation_of_carried_figures_in_artifacts/progress/phase-4-progress.json`,
measured 2026-10-07) states:

- RECALL: FAIL — the known positive ("does **not** contain") was missed because markdown bold
  (`**not**`) split the literal multi-word trigger phrase across a markup boundary; the probe
  found an unrelated non-contradictory duplicate instead.
- PRECISION: FAIL — 0 of ~12 hand-sampled flagged files were genuine; all were ordinary prose
  re-quoting a short literal.
- BOUNDEDNESS: FAIL — 92 of 2711 corpus files flagged, "an advisory nobody can triage is noise."

These three numbers (2711 corpus files, 92 flagged, 12 sampled, 0 genuine) match the dispatch's
own citation exactly on independent re-derivation from the primary source file — no
discrepancy found.

The failure mode that matters for *this* check is specifically the RECALL one: a naive
single-line `grep -E` over the raw file would miss a mark whose closing `]` is on a *later*
source line than its opening `[CARRIED-UNVERIFIED:` token, because `grep`'s per-line matching
never lets a character class see across a newline. This is not a hypothetical concern — **one
of the three live marks in the current corpus is exactly this shape**:

```
specs/476_isolate_seven_red_gate8_shell_suites/reports/01_fixture-lib-allowlist-root-cause.md:158-160
- 2026-11-05T18:24:04Z verify-deploy.sh run, "all 26 gates passed individually, Gate 8 aggregate
  sole failure" [CARRIED-UNVERIFIED: this report's own dispatch instructions; no corresponding
  entry was found in `specs/events.jsonl` or elsewhere in the repository by this dispatch's own
  search].
```

(The source designator continues, and the closing `]` lands, on a line that also contains a
sentence fragment — a second recall-adjacent wrinkle: nothing marks where the designator prose
ends and ordinary following prose begins other than the `]` itself.) A second live example
spans two lines in the archived plan:

```
specs/archive/358_require_rederivation_of_carried_figures_in_artifacts/plans/01_carried-figure-authoring-contract.md:65-66
  [CARRIED-UNVERIFIED: planner's own read of the two files during this planning dispatch, not
  re-read at implementation time — concurrent sibling tasks share this working tree].
```

**Recommended mechanism**: normalize the file's content by collapsing all newlines (e.g.
`tr '\n' ' '` or equivalent) into a single logical line *before* pattern-matching, then search
the flattened text for `\[CARRIED-UNVERIFIED:[^]]*\]`. Because the character class `[^]]`
excludes only the literal `]`, this is naturally non-greedy to the *nearest* following closing
bracket regardless of line breaks, and is unaffected by markdown emphasis markers or table
pipe characters appearing inside the source designator (neither `*` nor `|` is `]`, so they
pass through the character class untouched). Two distinct conditions must be flagged
separately, both via `log_warn`:

1. **Empty/whitespace-only source** — a complete `\[CARRIED-UNVERIFIED:[^]]*\]` match whose
   captured interior, after stripping the leading `CARRIED-UNVERIFIED:` and trimming
   whitespace, is empty.
2. **No closing bracket at all** — count total occurrences of the literal `\[CARRIED-UNVERIFIED:`
   token separately from the count of complete matches; a shortfall means at least one mark has
   no `]` to close it anywhere in the (flattened) remainder of the file. This is the
   degenerate case of (1) and must not be silently absorbed into it — it indicates a different
   authoring defect (a dropped bracket, not an empty name) and is worth a distinct message.

Markdown emphasis and table-cell placement do **not** require special-case handling under this
mechanism, because neither introduces a `]` character; they fall out of the flatten-then-match
approach for free. The one case that *does* require deliberate handling is exactly the
line-wrap case demonstrated by the two real corpus examples above, which is why flattening
(not a per-line scan) is the load-bearing design choice here, not an incidental implementation
detail.

**Fixture coverage required** (mirrors the dispatch's ACCEPTANCE bullet and the existing test
file's `make_report_fixture`/`make_plan_fixture` helper pattern at
`scripts/tests/test-validate-artifact.sh`): plain well-formed; plain malformed (empty source);
inside markdown emphasis (e.g. `**text [CARRIED-UNVERIFIED: source]**`), both well-formed and
malformed variants; inside a markdown table cell (`| ... | text [CARRIED-UNVERIFIED: source] |
...`), both variants; line-wrapped across 2+ lines (mirroring the two real corpus shapes
above), both a well-formed multi-line source and a malformed multi-line case (e.g. the bracket
closes on its own line with nothing but whitespace before it). New fixtures should use
`$VALIDATE_SRC` (the source-store-pinned subject already defined in the test file, lines
~36-41) rather than `$VALIDATE`, following the same precedent the cross-phase ceiling and FTM
cases set — this check will not exist in the deployed tree until this task's own redeploy phase
runs.

**Real-corpus flag count.** Running the recommended mechanism by hand against the 3 live marks
found by `grep -rl '\[CARRIED-UNVERIFIED:' specs/` (excluding `specs/state.json` and
`specs/TODO.md`, which are task-management mirrors, not report/plan artifacts themselves, and
excluding the one hit inside the archived task's *summary*, which is a template-citation
example using placeholder braces `{source path or record identifier}`, not a real mark on a
carried figure, and is not of type report/plan): all 3 are well-formed. **Projected flag count
today: 0.** This is well within any triageable threshold and is a genuine, re-derived-in-this-
session finding — it is not itself a carried figure requiring its own mark, but the planner
implementing this check should re-run the same grep at implementation time rather than trusting
this count, per the Carried-Figure Discipline's own re-derivation guidance.

### The two "ALSO SETTLE" rulings

**Ruling 1 — does-the-source-resolve?** NO; do not add resolve-checking. Grounds (re-derived
from the live corpus, not merely asserted from the dispatch's framing):

- `report-format.md`'s own mark specification calls the designator a "source path **or record
  identifier**" and explicitly says "prefer the most specific identifier available (path, plus
  section heading or line range)" — the convention never mandates that the designator literally
  *be* a resolvable filesystem path.
- Two of the three live marks are pure prose, not paths at all: "this report's own dispatch
  instructions; no corresponding entry was found in `specs/events.jsonl`..." and "planner's own
  read of the two files during this planning dispatch, not re-read at implementation time —
  concurrent sibling tasks share this working tree." A resolve-check applied to either would
  either (a) have nothing to resolve (no path substring present) and silently no-op, or (b) if
  it tried to heuristically extract a path-shaped substring from arbitrary prose, it would
  reproduce in miniature exactly the semantic-extraction problem that sank the general
  detector.
- The two *path-bearing* marks also append non-path qualifiers after a comma (a section name, a
  sub-class label: `..., Findings, sub-class (1)`), so even a successful path extraction would
  need to separate the path substring from trailing prose — again drifting toward
  natural-language judgment rather than a literal check.
- **Conclusion**: resolve-checking is excluded by the same reasoning the dispatch anticipated,
  now confirmed against the actual corpus shape rather than assumed. Record this in
  `report-format.md`'s Enforcement-level paragraph as a reasoned exclusion, explicitly named
  (not merely omitted).

**Ruling 2 — is a mark OWED (missing-mark detection) mechanically checkable?** NO. Grounds:
determining that a figure was *carried* (copied or closely paraphrased from another record)
rather than freshly derived in-session requires comparing the artifact's prose against an
unbounded set of candidate prior records (other tasks' artifacts, prior plan versions, session
transcripts) for semantic equivalence or close paraphrase — precisely the same class of
natural-language-contradiction-detection problem the general detector was built to solve and
failed on all three gate criteria (recall, precision, boundedness). There is no narrower
sub-case here analogous to Phase 1's literal-token well-formedness check, because "is this
sentence a copy of some other sentence I have not been told to compare it against" has no fixed
literal anchor to grep for. **Conclusion**: record as a reasoned exclusion in
`report-format.md`'s Enforcement-level paragraph, explicitly, per the dispatch's own
instruction not to leave this open.

### Phase 2, Part A — Recommendations that assert a measurable property of the live corpus

**Confirmed gap.** `report-format.md`'s `## Carried-Figure Discipline` Out-of-scope paragraph
excludes "a purely interpretive or evaluative claim... (a recommendation, a priority ranking, a
design preference, a quality assessment)" because it is "not falsifiable by re-measurement."
The cited counterexample (a recommendation to tighten `strip_exempt_regions` to a depth counter,
which plan-time re-measurement showed breaks 5 named test files' marker parsing) IS falsifiable
by re-measurement — the exclusion's own stated rationale ("not falsifiable") does not hold for
this shape, so the exclusion over-reaches here specifically, while remaining correct for a pure
design preference or priority ranking (neither of which asserts anything the corpus could
contradict).

**Recommended trigger** (adopting the dispatch's candidate shape, which is well-formed): a
recommendation is in-scope when it proposes changing a mechanical rule *applied over a corpus*,
and its soundness as recommended depends on how the current corpus responds to that changed
rule. A design preference, priority ranking, or quality assessment carries no such corpus
dependency and stays excluded.

**Recommended discharge mechanism**: run the proposed rule against the corpus and report the
result inline (re-derivation), OR mark the recommendation `CARRIED-UNVERIFIED` if deferring the
check — but note the dispatch's own observation that the claim here is the *artifact's own new
claim*, not literally copied from elsewhere, so `CARRIED-UNVERIFIED` (whose definition is
keyed to "copied or closely paraphrased from another record") is a conceptual mismatch. The
cleaner fit is a parallel, distinctly-named mark for this shape (the dispatch's option (3)) —
e.g. something in the `UNVERIFIED` family already established stylistically by
`CARRIED-UNVERIFIED` itself (archived task 358's report notes this mark's "style borrowed from
the existing bolded `VERIFIED`/`UNVERIFIED` family"). Recommend the planner choose a distinct
literal token (not `CARRIED-UNVERIFIED` itself, to avoid muddying its "copied from elsewhere"
semantics) and require it to name the corpus/rule it was not checked against, mirroring the
required-source rule already proven out for `CARRIED-UNVERIFIED`.

**Out-of-scope paragraph rewrite**: must be rewritten (not merely appended to) so it draws the
line at "falsifiable by re-measurement against the live corpus" rather than "a recommendation"
categorically — the dispatch requires this explicitly and the current text would otherwise
contradict the new rule the moment it exists.

### Phase 2, Part B (+ further B-case) — Dispatch-premise staleness

**Confirmed gap.** `scripts/orchestrate-build-dispatch.sh`'s dispatch-file composer emits
`## Description` via a single `echo "${description}"` (line ~550) with **zero** re-validation,
re-measurement, or staleness signal of any kind — confirmed by direct read of the composer
function (lines 460-560 inspected; no conditional, no grep, no fingerprint check touches
`$description` before that `echo`). `planner-agent.md` and `general-research-agent.md` were
both grepped for `re-measur|stale|premise|CARRIED` and neither contains any such obligation
today — the gap is real on both the composer side and the receiving-agent side, not merely
theoretical.

**An existing, reusable mechanism worth noting**: the same composer function already has a
`.decisions.json` supersession-detection pattern (lines ~478-508) — it recomputes a
`sha256sum` fingerprint over the *current* description and compares it against each recorded
decision's `description_fingerprint`, flagging any mismatch as "POTENTIALLY SUPERSEDED." This
is a proven, cheap, already-shipped precedent for "the composer has two documents in hand and
can flag a conflict without any new measurement" — directly analogous to the further B-case's
proposed third shape (a prior dispatch's research artifact contradicting the description).
The planner should weigh reusing or extending this exact pattern (fingerprint/supersession
style) rather than inventing a second mechanism, since the composer already proves this shape
is cheap to build and matches the further-B-case's own framing almost exactly ("the composer
has both documents in hand... without any new measurement at all").

**Recommended weighing** (per the dispatch's own three candidate owners): (1) receiving-agent
re-measurement is the most general but costs a new obligation on every dispatch regardless of
whether anything is stale; (2) composer-emitted re-validation checklist is cheap and
mechanically keyed to the six existing trigger shapes, but only *prompts* re-measurement, it
does not perform it; (3) the further-B-case's composer-side contradiction surfacing (reusing
the decisions-file fingerprint precedent, extended to also diff against a prior dispatch's own
research-report artifact in the same task directory) is strictly cheaper than (1) and catches
the conflict one stage earlier than (1), doing no work in the common case where nothing
disputes the description. Recommend the plan adopt (3) as the primary mechanism, with (2) as a
lightweight complement for cases with no prior artifact to diff against yet (first dispatch in
a task's lifecycle has nothing to compare).

### Phase 3 — Self-derived enumeration completeness and search-pattern independence

**Confirmed gap**: `general-research-agent.md` contains no completeness-trigger or
search-pattern-disclosure language (grepped, zero hits for `completeness|enumerat`). The
cross-repo origin citation (BimodalLogic `#828`) cannot be independently re-verified from this
repository — noted as a limitation, not re-derived, consistent with the dispatch's own
"verify before citing" instruction applying only to this-repo artifacts. The companion citation
for the "further Part B case" (BimodalLogic `#833`) is likewise cross-repo and not
re-verifiable here; both are accepted as the dispatch presents them, per that caveat.

**Recommended trigger**: an enumeration carries an implicit completeness claim when it asserts
or implies totality ("every", "all", "exact", "the N sites", or a closed table a later phase
treats as its full work list) rather than presenting illustrative examples. Recommend treating
a bare count ("19 sites") as itself such a claim, since a later consumer (a plan phase) has no
way to distinguish "19 sites, confirmed exhaustive" from "19 sites, a sample" without the
author saying which.

**Recommended obligation**: adopt both (a) and (b) from the dispatch's menu, as it itself
suggests they are complementary: (a) state the search patterns used, inline and verbatim,
wherever completeness is claimed (cheap, immediately auditable); (b) require a second,
differently-shaped pattern (a loose structural pattern alongside the literal one) before
completeness may be asserted — this directly targets the root cause identified in the folded
record ("a verification sweep that reuses the sweep it verifies inherits its blind spot and
converts an open gap into a false green"). Option (c), a parallel `COVERAGE-UNVERIFIED` mark,
is a reasonable complement for an author who has NOT cross-checked but still wants to disclose
an unconfirmed completeness claim honestly (mirroring `CARRIED-UNVERIFIED`'s own
disclosure-not-prohibition purpose) — recommend including it alongside (a)/(b), not instead of
them.

**Verification-independence rule**: has no existing home, per the dispatch's own flag — this is
the item most likely to be silently dropped in favor of the easier trigger/obligation items.
Recommend stating it explicitly in `report-format.md`'s Carried-Figure Discipline section
(nearest existing load-bearing location) with a pointer from `plan-format.md`'s
verification-criteria guidance, mirroring the existing single-placement convention rather than
restating.

## Decisions

- Phase 1's check belongs in `scripts/validate-artifact.sh`, advisory-only (`log_warn`), gated
  to `artifact_type` in `{report, plan}`, following the Verification Tier precedent's exact
  idiom (promotion-criterion comment, no `--strict` special-casing needed).
- Phase 1's matching mechanism must flatten newlines before pattern-matching — single-line
  `grep -E` is explicitly rejected as the design, on direct evidence that 2 of the 3 live marks
  in the corpus are line-wrapped.
- Does-the-source-resolve: **excluded**, ruled NO on corpus evidence (prose-only sources exist
  live today), to be recorded as a named reasoned exclusion in `report-format.md`.
- Is-a-mark-owed (missing-mark detection): **excluded**, ruled NO on the same semantic-judgment
  grounds that sank the general detector, to be recorded as a named reasoned exclusion in
  `report-format.md`.
- Phase 2 Part A's Out-of-scope paragraph will be rewritten, not merely supplemented, to draw
  the "not falsifiable by re-measurement" line correctly against the corpus-dependent
  recommendation shape.
- Phase 2 Part A's mark should be a new, distinctly-named token (not `CARRIED-UNVERIFIED`
  itself), to avoid conflating "copied from elsewhere" with "this artifact's own
  corpus-dependent claim, unverified."
- Phase 2 Part B (+ further case) should primarily adopt the composer-side contradiction-
  surfacing shape, reusing the existing `.decisions.json` fingerprint/supersession mechanism
  already proven in `orchestrate-build-dispatch.sh` rather than inventing a second mechanism,
  with a lightweight re-validation-checklist complement for the no-prior-artifact case.
- Phase 3 adopts both obligations (a) state-the-pattern and (b) require-a-second-differently-
  shaped-pattern, plus (c) a parallel disclosure mark, and states the verification-independence
  rule explicitly in `report-format.md` with a `plan-format.md` pointer.

## Recommendations

1. Size Phase 1 as its own plan phase (tier: local/interface — touches one script, one test
   file, and one Enforcement-level paragraph update) given its hard precedence requirement over
   everything else in this task and over sibling task `488`'s territory note.
2. Size Phase 2 as two sub-phases (Part A, then Part B/further-case) rather than one, since Part
   A changes report-format.md's Out-of-scope paragraph (a text edit) while Part B changes a
   *script's* composer logic (orchestrate-build-dispatch.sh) plus agent-contract prose
   (planner-agent.md) — different verification tiers.
3. Size Phase 3 last, per the folded records' own declared order, touching
   general-research-agent.md and report-format.md/plan-format.md's verification-criteria
   pointer.
4. For every new fixture added to `scripts/tests/test-validate-artifact.sh`, use
   `$VALIDATE_SRC`, not `$VALIDATE`, until this task's own redeploy phase lands the check under
   `.claude/`.
5. Re-run `grep -rl '\[CARRIED-UNVERIFIED:' specs/` at implementation time rather than trusting
   this report's "3 live marks, 0 malformed" count — it is itself subject to the very
   re-derivation discipline this task is building tooling for.

## Risks & Mitigations

- **Risk**: a planner reproduces the rejected general detector's shape by accident while
  building Phase 1 (e.g. widening the match beyond the literal `[CARRIED-UNVERIFIED:` token).
  **Mitigation**: the plan's acceptance criteria should explicitly name the fixed literal token
  as the only match surface, with no semantic/contradiction-detection component — this report's
  Findings section states that boundary plainly for the plan to inherit.
- **Risk**: the Phase 2 Part A corpus-dependent-recommendation check, if under-scoped, drifts
  back toward the rejected general detector (any recommendation touching code could be read as
  "corpus-dependent"). **Mitigation**: the trigger is deliberately narrow — "changes a
  mechanical rule applied over a corpus" — and should be stated with the dispatch's own worked
  counterexample (the `strip_exempt_regions` case) as the canonical positive instance and a pure
  design-preference recommendation as the canonical negative instance.
- **Risk**: Phase 2 Part B's composer-side contradiction-surfacing mechanism, if it tries to
  diff arbitrary prose between a research artifact and a description, reproduces the semantic-
  contradiction-detection problem. **Mitigation**: scope it to the same six fixed trigger
  shapes the Carried-Figure Discipline already enumerates (count, command output, file/line
  citation, pass/fail, N-of-M ratio, qualitative state claim) — mechanically identifiable,
  exactly as the dispatch itself recommends as the cheap alternative to a blanket obligation.
- **Risk**: Phase 3's "second, differently-shaped pattern" obligation is unenforceable
  mechanically (nothing can verify two patterns are genuinely differently-shaped). **Mitigation**:
  this is correctly an authoring-side-only obligation per the dispatch's own Enforcement-level
  item 4; the plan should not attempt to mechanize it and should say so explicitly, mirroring
  this report's Rulings 1/2 above.

## Context Extension Recommendations

- **Topic**: Carried-Figure Discipline mechanical enforcement surface.
- **Gap**: prior to this task, no context file documented *which* parts of the convention are
  mechanically checkable versus authoring-side-only, beyond the single "named future item"
  sentence in `report-format.md`'s Enforcement-level paragraph.
- **Recommendation**: once Phase 1 lands, update that same paragraph (not a new file, per the
  dispatch's Placement-record constraint) to state, in one place, the full enforcement map: the
  Phase 1 well-formedness check (built), the does-the-source-resolve exclusion (ruled out,
  reasoned), the is-a-mark-owed exclusion (ruled out, reasoned), and — once Phase 2/3 land —
  their own authoring-side-only status alongside whatever mechanical surface (if any) each adds.

## Appendix

- Search queries used: `grep -n "Carried-Figure Discipline" -A 150 report-format.md`;
  `grep -rl '\[CARRIED-UNVERIFIED:' specs/`; `grep -rl "92 files\|2711" specs/`; `grep -n
  "re-measur\|stale\|premise\|Scope Hypothesis\|CARRIED" planner-agent.md`; `grep -n
  "re-measur\|stale\|premise\|CARRIED\|completeness\|enumerat" general-research-agent.md`;
  `sed -n` ranges over `validate-artifact.sh` (lines 1-437, 640-677),
  `orchestrate-build-dispatch.sh` (lines 460-560), `plan-format.md` (lines 420-545).
- References: `agent-system/extensions/core/context/formats/report-format.md`,
  `agent-system/extensions/core/context/formats/plan-format.md`,
  `agent-system/extensions/core/scripts/validate-artifact.sh`,
  `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh`,
  `agent-system/extensions/core/agents/general-research-agent.md`,
  `agent-system/extensions/core/agents/planner-agent.md`,
  `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`,
  `specs/archive/358_require_rederivation_of_carried_figures_in_artifacts/progress/phase-4-progress.json`,
  `specs/476_isolate_seven_red_gate8_shell_suites/reports/01_fixture-lib-allowlist-root-cause.md`.
