# Research Report: Preflagging Module-Wiring Invariant Failures

**Task**: 455 - Preflag module-wiring invariant failures in generated-surface appending
**Started**: 2026-11-22T00:00:00Z
**Completed**: 2026-11-22T00:00:00Z
**Effort**: medium
**Dependencies**: 446 (predecessor, landed 2026-11-09 -- re-read against it, see Decisions)
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` (source store, read in full)
- `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` (source store, read in full)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`, `skill-base.sh` (grepped for `file_scope` consumption)
- `agent-system/extensions/core/context/formats/plan-format.md`, `context/standards/repo-level-declarations.md`
- `/home/benjamin/Projects/BimodalLogic` (read-only live checkout: `README.md`, `FormalSystem/OpenLanguage/`, `specs/archive/833_stab_definable_from_open_modals/**`, `specs/archive/state.json`) -- read-only cross-repo consultation to settle Part (1), no edit made there
- Direct, reproducible execution of `plan-file-scope-harvest.sh` against synthetic fixtures and against the real BimodalLogic plan + tree
- Task 446's archived report/summary (`specs/archive/446_.../reports/`, `specs/archive/446_.../summaries/`)
**Artifacts**:
- This report: `specs/455_preflag_module_wiring_invariant_failures/reports/01_preflag-module-wiring-invariants.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Part (1) is answered, and the dispatch's own premise is falsified for the generated-surface
  mechanism itself.** Running the current `plan-file-scope-harvest.sh` against the real,
  read-only BimodalLogic checkout and the real archived plan for the cited task 833 incident
  produces `typst/generated/status.typ` and the repository-root `README.md` correctly -- the
  exact two surfaces the incident reports as missed. Neither of the dispatch's two offered
  hypotheses holds: the plan DID harvest `.lean` paths, and the ancestor-chain walk DOES reach
  the repository root and DOES match the root `README.md`'s `dir=FormalSystem` marker.
- **The real gap is a pipeline-visibility gap, outside the two files this task's `file_scope`
  declares.** `plan-file-scope-harvest.sh` correctly computes the appended surfaces and
  `skill-base.sh`'s plan-postflight correctly persists them into the task's `file_scope` array in
  `state.json`, before Phase 1 implementation begins (confirmed against BimodalLogic's own
  completed-task record for #833, whose final `file_scope` already lists both surfaces). But
  that appended knowledge never reaches (a) the plan document's own per-phase "Files to modify"
  prose -- the harvester only reads the plan, it never writes back to it -- or (b)
  `orchestrate-build-dispatch.sh`'s implement-dispatch construction, which never reads
  `file_scope` for the dispatching task itself (grepped: the only occurrence is a comment about
  sibling-batch overlap detection). The implementer never sees the correctly-computed surfaces at
  the one point they matter: mid-phase, before committing.
- **Part (2) ruling: NO for all four candidates** (the three original exemplars plus the
  C15/`Paper:`-line fourth exemplar folded in from BimodalLogic:#833) -- they do not belong in
  the generated-surface appending stage. Argued both ways below; the ruling is driven by a type
  mismatch (the stage appends PATHS that go stale from a mechanical regeneration trigger; all
  four candidates are CONTENT obligations a human must satisfy, not paths that go stale) and,
  independently, by the Part (1) finding itself (even a correctly-appended path is invisible to
  the implementer today, so widening the append list would not even address the complained-of
  cost).
- **Part (3): no agent-system fix is proposed for the repository-local remedies.** The four
  candidates' actual remedies remain BimodalLogic-local, as the dispatch already stipulates.
- **No code change to `plan-file-scope-harvest.sh` or its test suite is recommended by this
  report.** The mechanism is correct and the general three-level ancestor-chain shape with a
  shared `dir=` value at two levels is already pinned by the existing suite's Case 16, which
  (independently of this task) already mirrors BimodalLogic's real `dir=FormalSystem` convention
  closely. The recommended next action is a narrowly-scoped follow-up task against the
  dispatch-construction / plan-postflight pipeline (see Recommendations), not against this
  task's declared files.

## Context & Scope

This is the lowest-value item of its originating batch (BimodalLogic:#761,
`iss_1792371983911_ldAzpn`, class gate-friction, severity minor), later joined by a third
occurrence and a fourth exemplar folded in from BimodalLogic:#833. The scope is narrowly the
agent-system's `plan-file-scope-harvest.sh` generated-surface appending stage: (1) determine why
it did not cover the cited incidents, closing the gap if one exists; (2) rule on whether four
named lint/documentation-obligation classes belong in that stage; (3) explicitly exclude any
repository-local remedy from this record. All incident citations are entry_ids in
BimodalLogic's own `issues.jsonl` files and are CARRIED-UNVERIFIED narrative *except* where this
report states a figure as directly reproduced below -- those are machine-checked in this
session, not carried.

Per the dispatch's Territory Edges, task 446 (predecessor, "closes the plan-to-file_scope
reconciliation gap") must land first and this record must be re-read against what it landed.
446 is confirmed `completed` in `specs/archive/state.json`. Its own report
(`specs/archive/446_close_the_plan_to_file_scope_reconciliation_gap/reports/01_plan_to_file_scope_reconciliation_gap.md`)
addresses a different class of divergence -- a plan declaring paths an implementer's actual
touched-file set diverges from -- and contains no discussion of the generated-surface stage, of
`status.typ`, or of any plan-prose/`file_scope` write-back gap. 446 does not subsume this
record's Part (1) finding; no narrowing against 446 is required.

## Findings

### Part (1): Why the generated-surface appending stage did not cover the cited cases

**Direct reproduction, not inference.** Two independent reproductions were run, both read-only
against the live BimodalLogic checkout (`/home/benjamin/Projects/BimodalLogic`), using the
source-store `plan-file-scope-harvest.sh` with `PLAN_FILE_SCOPE_HARVEST_ROOT` pointed at that
tree -- the same override mechanism the existing test suite uses for its own fixtures.

1. A synthetic one-phase plan naming `FormalSystem/OpenLanguage/OpenTruth.lean` (the file the
   SURFACE A/B incident names) harvests:
   `["FormalSystem/OpenLanguage/OpenTruth.lean","FormalSystem/OpenLanguage/README.md","FormalSystem/README.md","README.md","typst/generated/status.typ"]`.
2. Running the harvester against the ACTUAL archived plan file for the cited incident
   (`specs/archive/833_stab_definable_from_open_modals/plans/01_stab-definable-from-open-modals.md`
   in BimodalLogic) produces:
   `["FormalSystem/OpenLanguage/OpenTruth.lean","FormalSystem/OpenLanguage/OpenValidity.lean","FormalSystem/OpenLanguage/README.md","FormalSystem/README.md","README.md","docs/theorem-index.md","typst/generated/status.typ"]`.

Both runs include `typst/generated/status.typ` (SURFACE A) and the repository-root `README.md`
(SURFACE B) -- the exact two surfaces the incident reports as missing. This directly falsifies
Part (1)'s first offered hypothesis ("the wiring edit harvested no `.lean` path" -- it harvested
two: `OpenTruth.lean` and `OpenValidity.lean`) and its second ("the ancestor-chain walk missed
the new module's READMEs, or terminates before reaching the root" -- it reaches `.` for every
nested `.lean` path by construction of `ancestor_chain()`, and the root README's actual marker,
`<!-- BEGIN GENERATED: inventory dir=FormalSystem rows=totals desc=no -->` (BimodalLogic
`README.md:19`), matches cleanly because `FormalSystem` is on the ancestor chain of
`FormalSystem/OpenLanguage/OpenTruth.lean`). Three further synthetic probes (root block with no
`dir=` key, a plural `dirs=` key, and a comma-joined `dir=` value) were run to rule these
alternate failure shapes in or out; all three DO cause a silent miss in isolation, but none of
them is BimodalLogic's actual marker syntax -- the real root block uses the plain
`dir=FormalSystem` form the existing Case 16 fixture already models, confirmed by direct `grep`
of the live file. These three probes are recorded here only to close off alternative
explanations, not because any of them describes the real repository.

**The appended surfaces are already correctly persisted, from before Phase 1 began.**
`skill-base.sh`'s `plan`-postflight branch (the live write path; `orchestrator-postflight.sh`'s
own equivalent branch has no live callers per its own header note) runs
`plan-file-scope-harvest.sh` over the WHOLE plan document and forwards the result via
`--file-scope-add` at the `[PLANNING] -> [PLANNED]` transition -- i.e. before any implementation
phase starts. BimodalLogic's own completed-task record for #833
(`specs/archive/state.json`, `project_number: 833`) lists a final `file_scope` of
`["FormalSystem/OpenLanguage/OpenClasses.lean","FormalSystem/OpenLanguage/OpenTruth.lean","FormalSystem/OpenLanguage/OpenValidity.lean","FormalSystem/OpenLanguage/README.md","FormalSystem/README.md","README.md","docs/theorem-index.md","typst/generated/status.typ"]`
-- byte-identical in content to what the harvester reproduces above (plus `OpenClasses.lean`,
unrelated to this finding). The bookkeeping array was correct the whole time.

**The actual gap: a consumer-side blind spot, not a producer-side bug.**
`plan-file-scope-harvest.sh` is a pure read-the-plan/emit-JSON-to-stdout tool; it never writes
back into the plan `.md` file. Direct inspection of the archived plan's own per-phase "Files to
modify" blocks confirms Phase 1 names only `FormalSystem/OpenLanguage/OpenTruth.lean` and Phase 3
names only `FormalSystem/OpenLanguage/README.md` and `docs/theorem-index.md` -- neither
`typst/generated/status.typ` nor the root `README.md` appears anywhere in the plan document's own
prose, in any phase. An implementer following the plan phase-by-phase has no textual cue, at the
point of committing Phase 1 or Phase 3, that these surfaces will also go stale. Separately,
`grep -n "file_scope" agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` returns
exactly one hit, a comment about *sibling* tasks' declared `file_scope` for batch-overlap
detection -- the dispatch-construction script never reads the DISPATCHING task's own `file_scope`
at all. So the correctly-computed generated-surface knowledge is invisible on both of the two
channels (plan prose, dispatch prompt) an implementing agent actually reads. The header comment's
own stated rationale for the stage -- "This stage appends them so the plan's declared
`file_scope` already carries what the edit will force" -- is true of the bookkeeping array in
isolation, but demonstrably does not prevent the incident it names, because nothing downstream of
`file_scope` ever surfaces the addition to the implementer before the commit that trips the gate.

**This finding sits outside this task's own `file_scope`.** The two files this task declares
(`plan-file-scope-harvest.sh` and its test suite) are not where the visibility gap lives;
`orchestrate-build-dispatch.sh` (or whichever step would be taught to diff a phase's declared
paths against the task's recorded `file_scope` and annotate the delta into the dispatch prompt)
is a different file, in the same source store. Per this task's own Hard Constraints ("Resist
scope growth... If the honest answer to (1) and (2) is 'the mechanism is correct and the
remaining friction is repository-local,' that is a complete and successful outcome"), this report
does not widen the file_scope to reach into `orchestrate-build-dispatch.sh`; it recommends a
follow-up task instead (see Recommendations).

### Part (2): Do the other three (plus a fourth) failure classes belong in this stage?

The four candidates, as named by the dispatch: (C16) two `scripts/nolints.json` allowlist
entries for `env_linter` `unusedArguments` findings; (C23) an identifier rename flagged by a
naming check; (C29) a linter-suppression-needs-a-reason-comment fix; and the fourth exemplar
folded in from BimodalLogic:#833, (C15) a `docs/theorem-index.md` ledger row's "Paper:" doc-comment
line obligation.

**Argument FOR inclusion** (as framed by the dispatch, strongest form): all four arise from the
same act (wiring/extending a module); the stage already carries repository-specific knowledge of
this exact gate (it already names `check-module-invariants.sh` and `typst-sync-check.sh` by
path, so "no repo-specific knowledge in core" is not a bright line this stage already respects);
a one-line pre-flag costs far less than a fix-up pass; and C15 specifically is MECHANICALLY
derivable from a declared surface (`docs/theorem-index.md`'s own rows name the exact declaration
the obligation attaches to) by exactly the kind of parse the stage already performs on markdown
comment syntax -- closer to a generated-surface consequence than to "things the gate will
probably complain about."

**Argument AGAINST inclusion, and the ruling (NO, for all four):**

1. **Type mismatch.** The stage's one documented job is appending PATHS that a mechanical
   regeneration step will overwrite -- a file that literally goes stale and needs `--emit-inventory`
   or `--fix` re-run. None of the four candidates is a path going stale: a `nolints.json` entry,
   an identifier spelling, a missing reason comment, and a missing `Paper:` line are all CONTENT
   obligations inside files already being edited (or, for `nolints.json`, a file whose correct
   FUTURE content the stage cannot determine without actually running `env_linter`). The
   append-only `file_scope` mechanism is path-shaped; none of these four is naturally expressible
   as "and also touch this path," because knowing WHICH two `nolints.json` entries, WHICH
   identifier, WHICH suppression, or WHICH doc-comment line is not computable from the plan's
   declared paths alone -- it requires running the lint/naming/suppression checks themselves, a
   categorically larger capability than the stage's existing comment-syntax parse.
2. **C16 specifically already has a zero-core-change home.** `scripts/nolints.json` IS a real
   path, and this repository already ships a GENERIC, repo-declarable mechanism for exactly
   "trigger glob -> path that needs attention": `coupled_generated_surfaces`
   (`context/standards/repo-level-declarations.md`), read by `validate-artifact.sh`'s advisory
   plan-acceptance check. BimodalLogic can declare
   `{"trigger_glob": "FormalSystem/**/*.lean", "generated_paths": ["scripts/nolints.json"], "commit_blocking": false}`
   in its OWN `.claude-extensions.json` TODAY, with zero agent-system code change, and get an
   advisory warning at plan-acceptance time. This is a better fit than widening
   `plan-file-scope-harvest.sh`'s hardcoded append list, and it is self-serve.
3. **C23 and C29 have no file at all to append.** The "fix" for both is content inside a file the
   plan already declares (the newly-wired module's own `.lean` file, or `scripts/nolints.json`'s
   content for C29's suppression-comment case) -- there is no SECOND path this stage could even
   name.
4. **C15, the strongest candidate, is a content-completeness obligation, not a file_scope
   problem.** Even granting it is mechanically derivable in principle, deriving it requires
   parsing Lean DECLARATION NAMES out of a `.lean` file's content and cross-referencing them
   against `docs/theorem-index.md`'s rows -- a materially different and larger capability than
   the stage's existing ancestor-directory/comment-marker matching, which never inspects Lean
   source content at all. The dispatch's own framing locates the actual defect correctly: the
   obligation "was absent from the documentation obligations the dispatch composed" -- i.e. a
   BimodalLogic-local planning-time obligation-composition gap, not a file-path harvesting gap.
5. **Independently, Part (1)'s finding makes inclusion pointless even if the type mismatch were
   waived.** Any of these four, even if successfully appended as a `file_scope` path, would land
   in exactly the same invisible bookkeeping array this report shows the implementer never
   consults mid-phase. Widening the append list would add more correctly-computed, equally
   invisible entries -- it would not reduce the "one avoidable fix-up pass per module" cost the
   dispatch is trying to eliminate, because that cost is driven by the visibility gap, not by
   the append list's coverage.

**Ruling: NO for all four.** The correct home for all four remains a BimodalLogic-local,
human-facing wiring directive (`docs/project-info/MAINTENANCE.md` / `ORGANISATION.md`, already
named by the dispatch as referencing this gate), consistent with Part (3)'s boundary below. C16
additionally has an immediately available, zero-core-change path via BimodalLogic's own
`coupled_generated_surfaces` declaration, which this report notes but does not create (that
declaration lives in BimodalLogic's `.claude-extensions.json`, outside this repository).

### Part (3): Repository-local boundary

No agent-system file is proposed to carry any of C16/C23/C29/C15's actual remedies. Per the
dispatch, those remedies (the `nolints.json` entries, the rename, the reason block, the `Paper:`
lines, and any wiring-directive text naming them) belong in BimodalLogic and are out of scope
here. This report recommends, but does not create, a BimodalLogic-local record for a wiring
checklist entry covering all four classes plus the `coupled_generated_surfaces` self-service
option named in Finding 2 above.

## Decisions

- **446 does not subsume this record.** 446's scope (plan-declared-vs-observed-touched-path
  divergence) is confirmed disjoint from this record's Part (1) finding (generated-surface
  `file_scope` additions never reaching plan prose or the implement dispatch). No narrowing
  against 446 is applied.
- **No code change to `plan-file-scope-harvest.sh` or `scripts/tests/test-plan-file-scope-harvest.sh`
  is recommended.** The generated-surface appending stage is correct as implemented; both
  offered Part (1) hypotheses are falsified by direct reproduction (see Findings). The existing
  suite's Case 16 already pins the general three-level ancestor-chain shape with a `dir=` value
  shared across two registered READMEs, which mirrors BimodalLogic's real `dir=FormalSystem`
  convention closely enough that no new fixture is required to establish correctness; a future
  plan/implement phase MAY still add a fixture using the literal real path shapes purely for
  future-reader traceability (see Recommendations), but this is a documentation nicety, not a
  correctness gap.
- **Part (2) ruling is NO for all four exemplars** (C16, C23, C29, and the folded-in C15), with
  the fullest-strength argument for inclusion (C15) answered on its own terms rather than lumped
  in with the weaker three. See Findings for the five-point argument.
- **Part (3) boundary is upheld.** No BimodalLogic file is touched or proposed for edit from this
  record.

## Recommendations

1. **File a narrowly-scoped follow-up task against the dispatch-construction / plan-postflight
   pipeline** (likely `orchestrate-build-dispatch.sh`, possibly with a companion change at the
   `skill-base.sh` plan-postflight write site), to close the actual visibility gap found in Part
   (1): project a phase's `file_scope` delta (paths in the task's recorded `file_scope` that are
   not already named in that phase's own "Files to modify" block) into the implement dispatch
   prompt, or write it back into the plan document's own per-phase prose at plan-postflight time.
   This is the fix that would actually reduce the "one avoidable fix-up pass per module" cost;
   this task's own narrow `file_scope` (the harvester and its tests) cannot carry it.
2. **No change recommended to this task's two declared files.** Close this task on the finding
   that the mechanism is correct, per the dispatch's own stated acceptable outcome.
3. **Suggest, for BimodalLogic (not created here):** a `coupled_generated_surfaces` entry in
   BimodalLogic's own `.claude-extensions.json` for the `scripts/nolints.json` coupling (C16),
   immediately available with zero agent-system change; and a wiring-checklist addition to
   `docs/project-info/MAINTENANCE.md` / `ORGANISATION.md` covering C16 (as a cross-reference to
   the declaration above), C23, C29, and C15.

## Risks & Mitigations

- **Risk**: a future reader re-litigates Part (1) assuming the dispatch's premise (a bug in the
  appending stage) without re-running the reproduction. **Mitigation**: the reproduction commands
  and their exact outputs are recorded in Findings; re-run `plan-file-scope-harvest.sh` with
  `PLAN_FILE_SCOPE_HARVEST_ROOT` pointed at a live BimodalLogic checkout against the archived
  plan path named above to re-verify before assuming otherwise.
- **Risk**: the recommended follow-up task (Recommendation 1) is itself non-trivial (it touches
  `orchestrate-build-dispatch.sh`, a widely-depended-on file) and could be deprioritized
  indefinitely, leaving the underlying "one avoidable fix-up pass per module" cost unaddressed.
  **Mitigation**: none proposed here; this is an honest residual risk to flag for roadmap
  triage, not something this narrow task's scope can absorb.

## Context Extension Recommendations

- **Topic**: the distinction between `file_scope` as machine bookkeeping versus the plan
  document's own per-phase "Files to modify" prose as what an implementer actually reads.
- **Gap**: no existing context file states this distinction explicitly as a known architectural
  property with a known consequence (generated-surface appends are invisible to implementers).
  `plan-format.md`'s "Generated-surface appending" discussion (inherited from
  `plan-file-scope-harvest.sh`'s own header, which both documents) states the append's existence
  but not its consumer-visibility limitation.
- **Recommendation**: if the Recommendation-1 follow-up task lands, its own plan/summary should
  record this distinction in `context/formats/plan-format.md`'s existing "Generated-surface
  appending" cross-reference once a canonical fix exists, rather than adding a new standalone
  context file now, before any fix is decided.

## Appendix

### Reproduction commands (exact)

```
# Synthetic probe (dir=FormalSystem, matching BimodalLogic's real root marker):
PLAN_FILE_SCOPE_HARVEST_ROOT=/home/benjamin/Projects/BimodalLogic \
  bash agent-system/extensions/core/scripts/plan-file-scope-harvest.sh <synthetic-plan-naming-OpenTruth.lean>
# => includes "FormalSystem/OpenLanguage/README.md","FormalSystem/README.md","README.md","typst/generated/status.typ"

# Real-incident reproduction, read-only against the actual archived plan:
PLAN_FILE_SCOPE_HARVEST_ROOT=/home/benjamin/Projects/BimodalLogic \
  bash agent-system/extensions/core/scripts/plan-file-scope-harvest.sh \
  /home/benjamin/Projects/BimodalLogic/specs/archive/833_stab_definable_from_open_modals/plans/01_stab-definable-from-open-modals.md
# => ["FormalSystem/OpenLanguage/OpenTruth.lean","FormalSystem/OpenLanguage/OpenValidity.lean",
#     "FormalSystem/OpenLanguage/README.md","FormalSystem/README.md","README.md",
#     "docs/theorem-index.md","typst/generated/status.typ"]
```

### Corroborating evidence

- BimodalLogic `README.md:19`: `<!-- BEGIN GENERATED: inventory dir=FormalSystem rows=totals desc=no -->`.
- BimodalLogic `specs/archive/state.json`, `project_number: 833`, final `file_scope` includes
  `"README.md"` and `"typst/generated/status.typ"`.
- BimodalLogic `specs/archive/833_stab_definable_from_open_modals/plans/01_stab-definable-from-open-modals.md`,
  Phase 1 (line 181) and Phase 3 (line 315) "Files to modify" blocks: neither mentions
  `typst/generated/status.typ` nor the root `README.md`.
- `agent-system/extensions/core/scripts/skill-base.sh` lines ~1084-1111: the live
  `plan`-operation `--file-scope-add` write path, calling `plan-file-scope-harvest.sh`.
- `grep -n "file_scope" agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`:
  exactly one hit (line 132), a sibling-batch-overlap comment, not a read of the dispatching
  task's own `file_scope`.
- Git history of `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh`: task 731
  (landed 2026-10-10) introduced the generated-surface appending stage this task's dispatch was
  written against (dispatch provenance date 2026-10-18); task 446 (2026-11-09) and task 554
  (2026-11-10) added the deployed-tree and unexpanded-variable refusals, both after the cited
  incident (2026-11-04) and both irrelevant to this finding.

### Issue log entries recorded this dispatch

- `iss_1795392576104_KckqGY` (win, class `architecture`): the reproduction finding.
- `iss_1795392576148_l6Zb2T` (issue, class `scope`): the dispatch-premise refutation and
  pipeline-visibility localization.
