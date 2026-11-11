# Research Report: Close the Plan-to-File-Scope Reconciliation Gap

- **Task**: 446 - Close the plan-to-file-scope reconciliation gap
- **Started**: 2026-11-09T05:00:00Z
- **Completed**: 2026-11-09T06:30:00Z
- **Effort**: ~3 hours research
- **Dependencies**: Ordered after task 430 (completed; `proposed_file_scope` deposit mechanism)
- **Sources/Inputs**:
  - Codebase: `scripts/plan-file-scope-harvest.sh`, `scripts/git-commit-phase.sh`,
    `scripts/skill-base.sh`, `scripts/update-task-status.sh`, `scripts/validate-artifact.sh`,
    `context/formats/plan-format.md`, `agents/general-implementation-agent.md`,
    `scripts/tests/test-git-commit-phase.sh`
  - Git history (`git log -p`) across the three cited archived tasks' `state.json` entries
  - Archived task artifacts: `specs/archive/417_resolve_gate20_eager_load_budget_overage/`,
    `specs/archive/413_coordinate_concurrent_gate_runs/`,
    `specs/archive/424_harden_four_tier_conflict_case1_releaser_race/` (plans, `issues.jsonl`)
  - Live re-execution of `plan-file-scope-harvest.sh` against the two cited plans' real files
- **Artifacts**:
  - `specs/446_close_the_plan_to_file_scope_reconciliation_gap/reports/01_plan_to_file_scope_reconciliation_gap.md`
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Hypothesis (a) (grammar miss) is mechanically confirmed for the #417 citation**, and the
  harvester's behavior matches `plan-format.md`'s own documented grammar exactly ("a wrapped
  continuation line belongs to the preceding entry"). The defect is in how that plan's Phase 2
  bullet was AUTHORED (one list item wrapping four real file paths across continuation lines,
  and a second item joining two paths with a comma on one line), not a bug in the harvester.
  Re-running the harvester against the real archived plan reproduces exactly the 5-entry
  `file_scope` recorded in `state.json` before the manual recovery commit.
- **Hypothesis (d) (genuinely incomplete plan, discovered mid-phase) is confirmed for all three
  #413 citations and for four of #417's eight missing paths** (the `context/**`-destination
  files, which the plan named only via a glob, never as literal backtick paths). Per the
  dispatch's own instruction, this is task 430's territory (completed) and is not re-litigated
  here.
- **The #424 citation is NOT an instance of any of hypotheses (a)-(e).** It was caused by a
  since-fixed bug in `git-commit-phase.sh`'s `is_contained()` predicate (an un-normalized
  trailing-slash `file_scope` entry composed a non-matching doubled-slash glob), fixed in commit
  `2a945dca3` on 2026-11-04 — two and a half weeks after the incident and independent of this
  task. That fix is already pinned by Case 12 in `test-git-commit-phase.sh`.
- **A real, PRESENT-DAY loophole was found while investigating #424**: the harvested,
  still-current `file_scope` for archived task 424 contains the literal entry `.claude/`,
  harvested verbatim from that plan's own Phase 4 `**Files to modify**:` block. Empirically
  re-testing today's (already-fixed) `is_contained()` logic confirms this entry now judges
  *every* `.claude/**` path as CONTAINED — the opposite of the Hard Constraint's intent. Neither
  `plan-file-scope-harvest.sh` nor `validate-artifact.sh` currently refuses a `.claude/**` path
  in a `Files to modify` block, and the plan should instead have used the reserved
  `` `__WHOLE_TREE__` `` sentinel (`plan-format.md` lines 186-197), which is structurally inert
  against the Containment predicate by design.
- **Task 430's `proposed_file_scope` mechanism is already live and already closes part of PART
  B**, but a gap survives within a single multi-phase implement dispatch: the deposit is only
  consumed by `update-task-status.sh --file-scope-add` at the terminal `implemented` postflight
  write (`scripts/skill-base.sh` lines ~1082-1089), not at each phase's own commit, and nothing
  automatically re-commits the file once the scope widens. This reproduces exactly #413's
  recorded lesson (drop in Phase 2, sits dirty through Phase 6, caught only before Phase 7) even
  under 430's completed fix, for a dispatch spanning multiple phases in one continuous session.
- Recommended fix shape for PART A: no grammar change to the harvester (it already matches the
  documented format); add an authoring-discipline note to `plan-format.md` plus a
  `validate-artifact.sh` advisory check that flags a `Files to modify` entry line immediately
  followed by a continuation line itself matching the entry-line backtick pattern minus the
  leading dash (the exact #417 shape) and a bare `.claude/**` harvester refusal for the Hard
  Constraint case.

## Context & Scope

This task investigates why five divergences between a plan's declared `Files to modify` list and
a task's `file_scope` were observed across three archived tasks (#417, #424, #413) in one prior
`/orchestrate` invocation, despite the plan-to-`file_scope` reconciliation mechanism
(`plan-file-scope-harvest.sh` + the plan-postflight harvest in `skill-base.sh`) already being
live and additive. The dispatch names five candidate causes (a)-(e) and requires a verdict per
cited entry, a decision for PART A (closing the specific gap) and PART B (making the
drop-and-warn non-advisory), and an explicit ruling on the Hard Constraint (a `.claude/**` path
must never be "fixed" by widening `file_scope`).

Scope is research only: no code changes were made. Task 430 (the `proposed_file_scope`
implement-time feedback mechanism) is confirmed `[COMPLETED]` and is treated as settled
upstream — this task's PART B ruling must build on it, not invent a parallel channel, per this
dispatch's own Territory Edges section.

## Findings

### Codebase Patterns

- `scripts/plan-file-scope-harvest.sh`'s entry grammar (`^[ \t]*-[ \t]*\`` starts a NEW entry;
  everything else inside a `Files to modify` block, including an indented line that itself
  begins with a backtick but no leading dash, is a "continuation, contributes nothing") is not
  an accidental narrowness — it mirrors `context/formats/plan-format.md`'s own field
  definition verbatim: "a wrapped continuation line belongs to the preceding entry rather than
  starting a new one." The two are in agreement, not in conflict.
- `emit_entry()` extracts only the FIRST backtick-delimited token on an entry line. A
  comma-joined second path on the same entry line (`` `a.md`, `b.md` - ... ``) is silently
  dropped by design, same root cause as the continuation-line case.
- `git-commit-phase.sh`'s Containment Self-Check (`is_contained()`) reads `file_scope`
  exclusively from `specs/state.json` at commit time; it never consults a task's own
  `.return-meta.json` `proposed_file_scope` array. This is why a path deposited into
  `proposed_file_scope` by one phase's drop cannot be honored by the very next phase's own
  commit within the same dispatch — only a later, separate postflight write of the
  `implemented` status (`scripts/skill-base.sh` lines ~1082-1089) consumes it.
- `plan-format.md` already documents a reserved `__WHOLE_TREE__` sentinel (lines 186-197) for
  exactly the "a phase invokes the deploy script" case, explicitly engineered to be inert
  against the Overlap and Containment predicates (it is "slashless"). Task 424's Phase 4 named
  `` `.claude/` `` directly instead of using this sentinel — a plan-authoring deviation from an
  existing, documented idiom.
- Neither `plan-file-scope-harvest.sh` nor `validate-artifact.sh` contains any check or refusal
  for a harvested path matching the deployed-tree prefix (`.claude/` or `.claude/**`). Grepped
  for `WHOLE_TREE`, `deploy.*boundary`, `\.claude/\*\*` in both files; the only hit is
  `validate-artifact.sh`'s unrelated Tier-Justification exclusion of the `__WHOLE_TREE__` token
  itself (line 433), not a `.claude/**`-path refusal.

### External Resources

Not applicable — this is a pure codebase/history investigation; no external documentation was
consulted.

### Verdict Per Cited Entry

| Citation | Dropped path | Verdict | Evidence |
|---|---|---|---|
| `#417:iss_1792313133347_sYEA9t` / `#417:iss_1792313199291_fFKK9m` | `rules/artifact-formats.md` (4 of 8 paths: this plus `state-management.md`, `pr-prohibition.md`, `email/EXTENSION.md`) | **(a) Grammar/authoring miss** — mechanically confirmed. These 4 paths were literally backtick-quoted in the plan's Phase 2 block, but as comma-joins or wrapped continuation lines of an existing entry, never their own `- \`path\`` line. | Re-running `plan-file-scope-harvest.sh` against `specs/archive/417_.../plans/01_gate20-eager-load-headroom.md` today reproduces the exact 5-entry array recorded in `state.json` at commit `455cdb0c4`'s parent, before the hand recovery added the 8 missing entries. |
| `#417` (remaining 4 of 8: `status-markers.md`, `lit-stage4a-flow.md`, `literature-organization.md`, `distill-usage.md`) | destination files | **(d) Genuinely incomplete** — the plan named only a glob (`context/**`), never these literal paths; they were resolved as concrete destinations during Phase 1's candidate-ranking step. Deferred to task 430. | Phase 2 block text: "The corresponding non-eager destinations under `agent-system/extensions/core/context/**`..." — no literal path, confirmed absent from harvester output. |
| `#413:iss_1792323411434_KyvPGL` (`index-entries.json`), `#413:iss_1792326472706_NNRVgW` (own `summaries/*.md`), `#413:iss_1792323496988_DwFozE` (`test-run-all-parallel.sh`) | — | **(d) Genuinely incomplete** — none of the three paths appear anywhere in any phase's `Files to modify` block in `specs/archive/413_.../plans/01_concurrent-gate-run-coordination.md` (verified by grep across all 7 phase blocks). These are real, legitimate mid-implementation discoveries, exactly the case task 430's `proposed_file_scope` mechanism now exists to catch. Deferred to task 430. | Grep of the plan's full text found zero occurrences of any of the three paths outside the issue log and the summary. |
| `#424:iss_1792337289912_zl0Jq5` | `.claude/scripts/test-four-tier-conflict.sh` | **Neither (a)-(e): a since-fixed predicate bug, plus a separate, still-live Hard-Constraint loophole.** At drop time (2026-10-18T15:28:09Z), `file_scope` already contained the literal entry `.claude/` (added at plan-creation postflight, commit `fa35919a3`, 02:35:51 that same morning). `is_contained()`'s pre-fix code did not strip the entry's trailing slash, composing `.claude//*` (doubled slash), which never matches a real single-slash child path — the exact defect `git-commit-phase.sh`'s own current header comment now describes. This was fixed in commit `2a945dca3` ("orchestrate conclusion: channel (a) direct fixes", 2026-11-04), independent of and prior to this task, and is pinned by Case 12 in `test-git-commit-phase.sh`. | `git show 2a945dca3 -- scripts/git-commit-phase.sh` shows the trailing-slash normalization loop added; `git log` dates place it after the incident. Empirical re-test (below) confirms today's code treats `.claude/` as covering the dropped path. |

### The Live, Present-Day Hard-Constraint Loophole

Empirically re-running today's `is_contained()` normalization + match logic in isolation:

```
entry=".claude/"; path=".claude/scripts/test-four-tier-conflict.sh"
# after trailing-slash normalization: entry=".claude"
case "$path" in "$entry"/*) → MATCHES (.claude/*)
```

Today, a `file_scope` array containing the bare entry `.claude/` — exactly what task 424's
archived `state.json` entry still holds — would judge **every** `.claude/**` path as CONTAINED,
not dropped. This is the opposite of the Hard Constraint's intent ("No reconciliation may 'fix'
[the #424 case] by widening file_scope into `.claude/**`"), and it was not introduced by this
task — it already exists, seeded by the harvester faithfully doing its job against a plan that
named `.claude/` directly instead of using the `__WHOLE_TREE__` sentinel `plan-format.md` already
documents for this exact situation.

## Decisions

1. **PART A — no grammar change to `plan-file-scope-harvest.sh`.** Its "one path per `- \`path\``
   line; a continuation line belongs to the preceding entry" behavior is not a bug: it is the
   literal, verbatim-mirrored contract `plan-format.md` documents. Widening it to scan every
   backtick token in a block (to also catch comma-joins and wrapped continuations) was
   considered and rejected: `#417`'s own Phase 2 text contains backtick-quoted tokens that are
   NOT meant as file-scope entries (a quoted markdown heading, `` `## Literature Mode (--lit)` ``,
   and a bare basename, `` `lit-stage4a-flow.md` ``, missing its directory prefix) sitting in
   ordinary descriptive prose inside the SAME block. A token-scan widening would harvest the
   heading text as a bogus "path" and the bare basename as a non-matching partial path — trading
   one silent-drop failure mode for a silent-garbage failure mode, which is strictly worse
   because a garbage `file_scope` entry can falsely legitimize an unrelated future edit under
   the Containment predicate (see the `.claude/` loophole below for exactly this class of risk).
2. **PART A — the fix belongs in authoring discipline, surfaced loudly, not in silent
   correction.** Add an advisory `validate-artifact.sh` check (see Recommendations) that detects
   the specific #417 shape — an entry line immediately followed by one or more continuation
   lines that themselves match the entry-start backtick pattern once the leading dash is
   stripped, or an entry line containing a second backtick-pair after a comma — and warns at
   plan-acceptance time, before the harvest runs, rather than at implement-time via a drop.
   Reaffirm in `plan-format.md`'s `Files to modify` field definition that each real path needs
   its own `- \`path\`` line, with the #417 anti-pattern as a named example.
3. **PART A — the #424/`.claude/**` case is a plan-authoring defect, not a harvester defect, and
   is now additionally a live harvester *loophole*.** Ruling: `plan-file-scope-harvest.sh` MUST
   refuse (skip with a loud stderr warning, never silently) any harvested path that is exactly
   `.claude`, `.claude/`, or matches the prefix `.claude/*` — a deployed-tree path is never a
   legitimate `file_scope` member under `rules/source-store-deploy-boundary.md`, full stop.
   `validate-artifact.sh` additionally gets an advisory warning (not an error, to avoid breaking
   already-accepted plans) when a phase's `Files to modify` block names a `.claude/**` path
   directly instead of the `` `__WHOLE_TREE__` `` sentinel `plan-format.md` already reserves for
   this exact situation.
4. **PART B — defer to task 430's completed ruling; do not re-decide auto-merge vs. confirmation.**
   Task 430 already settled: the drop deposits additively into `.return-meta.json`'s
   `proposed_file_scope` (never a new channel), and the implement-postflight consumer at the
   `implemented` status write auto-merges it via `--file-scope-add` (no operator confirmation
   gate). This record's PART B work extends that same channel rather than inventing a second.
5. **PART B — the remaining gap is WITHIN-DISPATCH timing, not channel design.** The
   `proposed_file_scope` deposit is correct and durable, but `git-commit-phase.sh`'s own
   Containment Self-Check at the NEXT phase's commit (within the same multi-phase dispatch) does
   not consult it — only `specs/state.json`'s committed `file_scope`, which is not widened until
   the dispatch's terminal postflight. Ruling: `git-commit-phase.sh` should additionally union
   this task's own currently-deposited `proposed_file_scope` entries (read directly from
   `.return-meta.json`, same skip-if-absent posture `propose_file_scope_addition()` already
   uses) into `file_scope_arr` when building the Containment check — honoring a drop from an
   earlier phase in this same dispatch at the very next commit, without waiting for the terminal
   postflight and without touching `state.json` early (state.json still only updates once, at
   postflight, preserving the existing mutex-guarded write path).
6. **PART B — still does not auto-recover an already-dirty file.** Even with Decision 5, a path
   dropped in Phase 2 remains outside the Phase 2 commit; Decision 5 only prevents the SAME drop
   recurring in Phase 3+. The dirty file from Phase 2 needs an explicit follow-up commit once its
   path becomes contained. Recommend (not mandate, since this crosses into implement-agent
   prose territory task 430 also touches) that the Phase Checkpoint Protocol's per-phase step
   check, after a successful `git-commit-phase.sh` call, whether this task's own
   `proposed_file_scope` just gained a NEW entry relative to the previous phase, and if so,
   immediately re-attempt a scoped follow-up commit of that specific path before proceeding —
   closing the loop mechanically rather than relying on a reader to notice the WARNING text, as
   PART B's framing requires.

## Recommendations

1. **(PART A, harvester)** Add a refusal to `plan-file-scope-harvest.sh`: drop (with a loud
   stderr warning, never silently) any harvested entry equal to `.claude`, `.claude/`, or
   matching `.claude/*`, before emitting the final JSON array. Update the script's header
   comment and `plan-format.md`'s field definition together (both already claim to mirror each
   other verbatim — Hard Constraint).
2. **(PART A, validate-artifact.sh)** Add an advisory (warn, not error — matching the existing
   advisory-first posture for the Verification Tier and header-presence checks in the same
   per-phase loop) check for: (i) a `Files to modify` entry line whose immediately following
   line, with its leading whitespace stripped, itself starts with a backtick (the #417 wrapped-
   continuation shape); (ii) an entry line containing a second `` `...` `` pair after a comma
   (the #417 comma-join shape); (iii) a literal `.claude/**` path named instead of
   `` `__WHOLE_TREE__` ``.
3. **(PART A, test coverage)** Extend `scripts/tests/test-plan-file-scope-harvest.sh` with: a
   fixture reproducing #417's exact Phase 2 rendering (comma-join + wrapped continuation),
   asserting the CURRENT (correct, unchanged) behavior of extracting only the first-line path
   per entry — this is a regression pin confirming the format's own documented semantics, not a
   bug fixture; and a fixture asserting the new `.claude/**` refusal drops such an entry from the
   output with a stderr warning, while a `` `__WHOLE_TREE__` `` entry passes through unchanged
   (already inert, no refusal needed for the sentinel itself).
4. **(PART B, git-commit-phase.sh)** Extend the Containment Self-Check to additionally union
   `.return-meta.json`'s current `proposed_file_scope` array (same task directory, read the same
   way `propose_file_scope_addition()` already resolves the path, skip-if-absent) into
   `file_scope_arr` before running `is_contained()`. Add fixtures to
   `scripts/tests/test-git-commit-phase.sh` pinning: a path dropped in an earlier simulated phase
   (deposited into `proposed_file_scope`) is NOT dropped again on a subsequent phase's commit in
   the same repo fixture; a genuine out-of-territory path is still dropped, warned, and
   issue-recorded exactly as today (Decision 4's non-negotiable survival requirement); the
   `.claude/**` refusal from Recommendation 1 is independently pinned at the containment site too
   (defense in depth — a `.claude/**` entry should never reach `file_scope_arr` via EITHER the
   harvester or a hand-edited `state.json`, but if it does, containment should not legitimize it).
5. **(PART B, general-implementation-agent.md / Phase Checkpoint Protocol)** Document the
   follow-up-commit step from Decision 6 at the same place the existing rc-code case statement
   lives, so an agent proceeding through multiple phases in one dispatch has an explicit,
   mechanical trigger (a new `proposed_file_scope` entry since the last phase) rather than a
   prose reminder to "verify the WARNING output." This is new prose in a file task 430 also
   owns — coordinate rather than edit in parallel if 430's own follow-up work is still open; it
   is `[COMPLETED]` as of this research, so no live conflict is expected.
6. **(Verification, end-to-end)** Re-run the plan-postflight harvest end-to-end against
   `specs/archive/417_.../plans/01_gate20-eager-load-headroom.md` (already done in this report,
   reproducing the exact 5-entry pre-recovery `file_scope`) as the baseline regression case for
   any PART A test added — the fix must not change this plan's harvested output (it correctly
   authors zero `.claude/**` paths and no sentinel), only plans that newly exercise the
   `.claude/**` refusal path.

## Risks & Mitigations

- **Risk**: Widening the harvester's grammar (rejected in Decision 1) would have been an
  attractive-looking "complete fix" for #417 but silently introduces garbage `file_scope`
  entries from unrelated backtick-quoted prose. **Mitigation**: Decision 1 rejects it explicitly,
  with the concrete counter-example (`## Literature Mode (--lit)`, bare `lit-stage4a-flow.md`)
  recorded so a future reviser does not re-propose the same widening without re-deriving this
  counter-example.
- **Risk**: The `.claude/**` refusal (Recommendation 1) could be read as "the harvester now
  validates file existence/legitimacy," conflicting with the script's own documented
  never-filesystem-validates posture (a path for a file the plan will CREATE must still be
  harvested). **Mitigation**: scope the refusal narrowly to the `.claude/**` PREFIX test only
  (a structural/location check, not an existence check) — this is categorically different from
  filesystem validation and does not touch the CREATE-path guarantee for any other path.
- **Risk**: Unioning `proposed_file_scope` into the live Containment check (Decision 5) could be
  read as weakening the check for a genuine excursion, if a careless implementation treats ANY
  deposit (regardless of which task deposited it) as authoritative. **Mitigation**: the deposit
  is already task-scoped (`.return-meta.json` lives under this task's own directory,
  `propose_file_scope_addition()` already resolves it per-task) — the union must read only THIS
  task's own file, never a cross-task read, which is already how the existing deposit/consume
  pair is wired.
- **Risk**: A `.claude/**` refusal landing only in the harvester, with no containment-site
  defense, leaves a hand-edited `state.json` (bypassing the harvester entirely) as a residual
  path to the same loophole. **Mitigation**: Recommendation 4's "defense in depth" fixture closes
  this by also testing the containment site directly against a `.claude/`-seeded `file_scope`,
  independent of how that entry got there.

## Context Extension Recommendations

- **Topic**: The `__WHOLE_TREE__` sentinel's intended use for deploy/redeploy phases.
- **Gap**: `plan-format.md` documents the sentinel precisely, but nothing in the planner-agent
  guidance or `plan-format.md`'s `Files to modify` field section explicitly warns against the
  #424 anti-pattern (naming `.claude/` or a `.claude/**` path directly instead of the sentinel).
  A future plan author has no signal steering them away from repeating #424's authoring choice.
- **Recommendation**: When Recommendation 2's `validate-artifact.sh` check lands, add a short
  cross-reference from `plan-format.md`'s `Files to modify` field definition directly to the
  `__WHOLE_TREE__` sentinel subsection, phrased as "never name a `.claude/**` path directly; use
  this sentinel instead," co-located with the existing sentinel documentation rather than a new
  file.

## Appendix

### Search Queries / Commands Used

- `bash agent-system/extensions/core/scripts/plan-file-scope-harvest.sh <plan-file>` — run live
  against both `specs/archive/417_.../plans/01_gate20-eager-load-headroom.md` and
  `specs/archive/424_.../plans/01_harden-case1-releaser-race.md`.
- `grep -n "Files to modify" -A N <plan-file>` — located every phase's block in all three cited
  plans.
- `git log --all --format="%H %ad %s" --date=iso -- specs/state.json | grep -i "task 424"` /
  `git log --all --format="%H %ad %s" --date=iso | grep -i "task 424 phase"` — reconstructed the
  424 commit timeline against the issue log's UTC timestamp.
- `git show <sha> -- specs/state.json` — diffed `file_scope` before/after the #417 recovery
  commit (`455cdb0c4`) and the #424 plan-creation commit (`fa35919a3`).
- `git log -p -- agent-system/extensions/core/scripts/git-commit-phase.sh | grep -n "Normalize a
  trailing-slash" -B5` — located the exact commit (`2a945dca3`) that fixed the predicate bug
  underlying the #424 incident.
- Direct bash re-execution of `is_contained()`'s normalization + case-match logic in isolation,
  confirming today's code treats a bare `.claude/` `file_scope` entry as covering every
  `.claude/**` path.

### References

- `specs/archive/417_resolve_gate20_eager_load_budget_overage/plans/01_gate20-eager-load-headroom.md`
- `specs/archive/417_resolve_gate20_eager_load_budget_overage/issues.jsonl`
- `specs/archive/413_coordinate_concurrent_gate_runs/plans/01_concurrent-gate-run-coordination.md`
- `specs/archive/413_coordinate_concurrent_gate_runs/issues.jsonl`
- `specs/archive/424_harden_four_tier_conflict_case1_releaser_race/plans/01_harden-case1-releaser-race.md`
- `specs/archive/424_harden_four_tier_conflict_case1_releaser_race/issues.jsonl`
- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh`
- `agent-system/extensions/core/scripts/git-commit-phase.sh`
- `agent-system/extensions/core/scripts/skill-base.sh`
- `agent-system/extensions/core/scripts/update-task-status.sh`
- `agent-system/extensions/core/scripts/validate-artifact.sh`
- `agent-system/extensions/core/context/formats/plan-format.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`
- Commit `455cdb0c4` ("task 417 phase 2.1: land artifact-formats.md trim + widen declared
  file_scope")
- Commit `fa35919a3` ("task 424: create implementation plan")
- Commit `2a945dca3` ("orchestrate conclusion: channel (a) direct fixes")
- Commit `67c34c525` ("task 440 phase 1: fix the containment predicate at both sites")
- Commit `714a357b3` ("task 430 phase 2: deposit the dropped path at drop time in
  git-commit-phase.sh, with fixtures")
