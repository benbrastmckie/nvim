# Implementation Plan: Task #488

- **Task**: 488 - MCP write-tool grant ownership scope
- **Status**: [IMPLEMENTING]
- **Effort**: 1.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/488_mcp_write_tool_grant_ownership_scope/reports/01_mcp-ownership-scope-verdict.md
- **Artifacts**: plans/01_mcp-ownership-scope-carveout.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research phase reached a verdict: the sapience extension's project-scoped grant of the four
`mcp__sapience__*` write tools is correct as-is and must NOT move to `~/.dotfiles`, because a
machine-wide grant for unreviewed personal-vault writes is a strictly worse security posture than
the current one-repository blast radius. The document that judges the grant —
`context/patterns/mcp-server-ownership.md` — is therefore the thing that changes, not the grant.
This plan adds an explicit carve-out subsection to that standard, repairs the two other places in
the same file whose wording would otherwise contradict the new carve-out (the Composition table
and the Decision procedure), makes the existing one-way disclosure pointer symmetric, and
redeploys so the deployed tree and `verify-deploy.sh` agree with the source store.

All edits land in the source store (`agent-system/extensions/**`), never in the deployed
`.claude/**` tree, per `rules/source-store-deploy-boundary.md`. No change to
`agent-system/extensions/sapience/settings-fragment.json` is required or permitted by the verdict.

### Research Integration

Key findings carried into the phase structure:

- **The verdict is "amend the standard, keep the grant"** (research Decisions, items 1-2).
  Recommendation 1 supplies draft carve-out text with three stated requirements
  (externally-enforced settings file; a pre-existing safe/unsafe split drawn by the owning system;
  explicit enumeration, never a wildcard) that narrow the carve-out to this shape and keep it from
  eroding the general same-scope rule. Phase 1 adapts that draft into the file's own voice.
- **`~/.claude/settings.json`'s `permissions` key is nix-enforced** and byte-identical to its
  `~/.dotfiles` source, so no extension deploy can durably edit it — the factual premise the
  carve-out rests on. This premise is already verified by research; the implementation phase does
  not need to re-verify it, and MUST NOT attempt an edit there.
- **The four write tools are deliberately absent from the user-scope seven-tool read-only
  allow-list**, which is what makes the owning system's own safe/unsafe split a precondition the
  carve-out can cite rather than an inference.
- **Disclosure part (b) is already satisfied** at the extension layer (`EXTENSION.md`,
  `README.md`, `review-gate-boundary.md`). The only real gap is the standard's silence plus the
  missing back-pointer, which is why Phase 2 is a two-file link edit and not a new disclosure
  surface.
- **The `nix` extension is a structurally similar precedent** whose project-scope grants are
  harmless duplication (a user-scope grant already exists for both read-only tools). Phase 1 must
  therefore avoid phrasing the carve-out so broadly that it retroactively reclassifies the `nix`
  entries, which the "Known gaps" section already governs under a different rationale.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- `mcp-server-ownership.md` states an explicit verdict covering the nix-enforced-settings case,
  naming the wrong fix (widening the grant to `~/.dotfiles`) as wrong and saying why.
- The new carve-out is internally consistent with the rest of the same document: the Composition
  table's fix column and the Decision procedure's step 3 both acknowledge it rather than still
  reading as if the project-scope exception were the only one.
- The disclosure pointer between the standard and the sapience extension is symmetric (today
  `review-gate-boundary.md` names the standard, and the standard says nothing back).
- The deployed tree is regenerated from the source store and the full `verify-deploy.sh` gate set
  is green.

**Non-Goals**:

- Changing `agent-system/extensions/sapience/settings-fragment.json`. The verdict is that its
  content is already correct; editing it would implement the rejected alternative.
- Any edit to `~/.dotfiles/config/claude/settings.json` or `~/.claude/settings.json`. The first is
  a different repository; the second is nix-enforced and any edit there is reverted on the next
  home-manager switch.
- Adding a new disclosure surface (a new context file, a new README section) on the sapience side.
  Research established the existing three surfaces already state the tradeoff in full.
- Re-opening the `memory` extension's dead `mcpServers` block or any other item in the standard's
  "Known gaps" section.
- Reclassifying the `nix` extension's two project-scope grants.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Carve-out phrased broadly enough to license any narrow-scope grant, eroding the same-scope rule | H | M | State all three preconditions as REQUIREMENTS in the subsection text (externally-enforced file; owning system has already drawn a safe/unsafe line; explicit enumeration) and say explicitly that it does not apply when the repo's own deploy could durably edit the user-scope file |
| A future reader skims only the governing rule, judges the sapience grant broken, and "fixes" it toward `~/.dotfiles` | H | M | The carve-out names that fix as wrong and gives the security reason; the governing-rule subsection gets a forward pointer so the skim path reaches it |
| New carve-out contradicts Decision procedure step 3 ("grant in USER scope regardless of registration scope ... Project-scope registration is the one exception") | M | H | Phase 1 explicitly updates step 3 and the Composition table in the same edit; a carve-out added without this leaves the file self-contradicting |
| Carve-out wording retroactively reclassifies the `nix` extension's grants, conflicting with "Known gaps" | M | L | Scope the carve-out to the case where the project-scope grant is the ONLY grant for a risk-bearing tier; `nix`'s tools are also granted at user scope, so it does not match |
| Redeploy sweeps in unrelated pending source-store changes (`core` and `lean` are already flagged stale pre-edit) | M | H | Expected and accepted: `verify-deploy.sh` green is the acceptance gate regardless of whose changes it validates. Do not attempt to narrow the deploy |
| Concurrent sibling dispatch is editing `core` source files this same cycle | M | M | Re-read each target file immediately before editing; stage explicit file lists only, never a directory or glob; treat a failure in a file outside this task's `file_scope` as possibly a sibling's in-flight edit and report rather than "fix" it |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Amend the Standard with the Carve-Out Verdict [COMPLETED]

**Goal**: `mcp-server-ownership.md` carries an explicit, internally consistent verdict covering a
grant placed at a NARROWER scope than registration because the matching user-scope settings file
is externally owned and enforced.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` immediately
      before editing (a sibling dispatch is live on `core` this cycle). *(completed)*
- [x] Add a new `###` subsection under `## Permission`, placed immediately after
      `### Carve-out: safe/unsafe tool splits require enumeration` and before the `---` that opens
      `## Composition`. Adapt the research report's Recommendation 1 draft into the file's own
      voice and cross-link conventions; do not paste it verbatim. *(completed: added "Carve-out: a
      nix-enforced user-scope settings file cannot receive a new grant")*
- [x] The subsection MUST state, in its own prose: (a) the governing rule's unstated assumption —
      that the matching user-scope settings file is one this repo's deploy can durably write;
      (b) that a nix-enforced/externally-reset file breaks that assumption, so an edit there is
      silently reverted; (c) the verdict that an extension MAY instead grant the withheld tier at
      its own project scope when the owning system has already drawn a safe/unsafe line;
      (d) explicitly, that widening the grant to the externally-owned file is the WRONG fix for a
      mutating, unreviewed capability, because it enlarges the blast radius from one opted-in
      repository to every project on the machine. *(completed)*
- [x] State the three requirements as requirements, not observations: explicit enumeration (never
      a wildcard, so a newly added server tool cannot silently inherit the narrow grant); the
      extension's own docs must state the tradeoff and link back to this subsection; never
      hand-edit the enforced file to "fix" the apparent mismatch. *(completed)*
- [x] Distinguish this carve-out from the preceding one in one sentence: the safe/unsafe carve-out
      leaves the unsafe tier permanently prompting everywhere, whereas this one deliberately
      grants it in exactly one repository. *(completed)*
- [x] Name the worked example by path: `agent-system/extensions/sapience/settings-fragment.json`
      and `context/project/sapience/domain/review-gate-boundary.md`, with the four tool names.
      *(completed)*
- [x] Add a forward pointer from `### Grant permissions at the same scope where the server is
      registered` to the new subsection, so a reader arriving at the governing rule learns an
      enforced-file exception exists before concluding a narrower grant is broken. *(completed)*
- [x] Update the `## Composition` table's first row (Connected-but-prompts) fix cell so it no
      longer reads as if user-scope and owning-extension-fragment were the only two placements.
      *(completed)*
- [x] Update `## Decision procedure` step 3, which currently says "Project-scope registration is
      the one exception" — make it name both exceptions, or point at the Permission section's
      carve-outs, so the procedure and the new subsection do not contradict each other.
      *(completed)*
- [x] Confirm no task-number reference and no record-versioning language ("previously", "no
      longer", "v2", supersession framing) was introduced; the file states the current design
      only. *(completed: check-task-references.sh PASS; pre-existing "previously" occurrences at
      unrelated lines were not touched by this edit)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: The edit is confined to one markdown guidance file with no executable
surface; `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc-lint plus task-reference
lint, run from this repository's root, which is simultaneously deploy consumer and source store)
is the specific covering check, plus a diff read-through for the two cross-reference edits.

**Scope Hypothesis**: One file, three edit sites (new subsection, Composition table row,
Decision procedure step 3) plus one forward pointer. Confirm at implementation time by grepping
the file for every occurrence of "the one exception", "same scope as registration", and
"Carve-out" and checking each hit either already acknowledges the new subsection or does not need
to.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` - new carve-out
  subsection under `## Permission`; forward pointer in the governing-rule subsection; Composition
  table fix-column wording; Decision procedure step 3 wording

**Verification**:

- `grep -n '^### ' agent-system/extensions/core/context/patterns/mcp-server-ownership.md` shows
  the new subsection between the safe/unsafe carve-out and `## Composition`.
- The file contains, by grep, the words identifying the premise and the verdict: a mention of the
  externally-enforced/reset user-scope settings file, and an explicit statement that moving the
  grant there is the wrong fix.
- `grep -n 'the one exception' ...` returns either nothing or only a hit that names both
  exceptions.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` exits 0.
- Diff read-through confirms every changed hunk is prose, and that no `nix`-extension grant or
  "Known gaps" statement was altered.

---

### Phase 2: Make the Disclosure Pointer Symmetric [COMPLETED]

**Goal**: A reader starting from either side — the sapience extension's own docs or the central
standard — reaches the other side. The author-facing permission guide's carve-out summary names
both carve-outs rather than only the safe/unsafe one.

**Tasks**:

- [x] Re-read both target files immediately before editing. *(completed)*
- [x] In `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`,
      section "The Permission Grant's Repository-Scoped Tradeoff": keep the existing factual
      narrative and add the back-link naming the new `mcp-server-ownership.md` subsection by its
      heading, so the deliberate-exception claim points at the section that sanctions it instead
      of only at the rule it departs from. *(completed)*
- [x] In the same section, state the verdict plainly: the repository-scoped placement is the
      sanctioned placement for this tier, not merely the only one the extension can reach. Keep
      the existing honest caveat that other projects on the machine still prompt. *(completed)*
- [x] In `agent-system/extensions/core/docs/guides/permission-configuration.md`, extend the
      existing `**Carve-out**:` paragraph (which today names only the safe/unsafe split) with a
      one-sentence second carve-out plus a link to the new subsection, matching the paragraph's
      existing link style. *(completed)*
- [x] Confirm no task-number reference and no record-versioning language was introduced in either
      file. *(completed: check-task-references.sh PASS on both files; diff contains no
      record-versioning language)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Both edits are prose and cross-reference text in markdown guidance files
with no executable surface; `verify-deploy.sh --only-gate 3,4` is the specific covering check for
doc-lint and task-reference lint, and the new link targets are verified by grepping the heading
text added in Phase 1.

**Scope Hypothesis**: Exactly two files, one paragraph each, and no change to any
`settings-fragment.json`. Confirm by `git status --short` showing only these two paths modified in
this phase, and by grepping both files for the Phase 1 heading text to prove the links resolve.

**Files to modify**:

- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` -
  back-link to the new carve-out subsection; verdict stated in the tradeoff section
- `agent-system/extensions/core/docs/guides/permission-configuration.md` - carve-out summary
  paragraph extended to name the second carve-out with a link

**Verification**:

- Both files contain the Phase 1 subsection's exact heading text (grep), so both links resolve to
  a real heading.
- `review-gate-boundary.md` still contains its existing honest caveat that other projects prompt
  (nothing removed in the course of adding the verdict).
- `grep -rn 'sapience' agent-system/extensions/sapience/settings-fragment.json` output is
  unchanged from the pre-phase state — the fragment was not edited.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` exits 0.

---

### Phase 3: Redeploy and Verify the Full Gate Set [COMPLETED]

**Goal**: The deployed `.claude/` tree is regenerated from the source store (clearing the
pre-existing `core`/`lean` staleness alongside this task's edits) and the complete
`verify-deploy.sh` gate set is green — the task's stated acceptance gate.

**Tasks**:

- [x] Confirm Phases 1 and 2 are committed (the deploy regenerates the deployed tree from the
      source store; uncommitted source edits still deploy, but committing first keeps the
      post-deploy diff readable). *(completed)*
- [x] Redeploy with the bounded-wait idiom: `timeout 540 bash .claude/scripts/deploy-headless.sh`,
      invoked with the Bash tool's `timeout` parameter raised to 600000 (NOT its 120000ms
      default), per `context/patterns/external-process-wait.md` Rule 1. *(completed)*
- [ ] Run the full gate set: `bash .claude/scripts/verify-deploy.sh` (no `--only-gate` narrowing)
      and confirm it exits 0. *(deviation: altered -- discharged via `--only-gate 3,4` per the
      dispatch file's Batch Gate Deferral directive; the full run surfaced 3 pre-existing
      failures unrelated to this task's file_scope (eager-load baseline, shellcheck in a lean
      script, dead-command-recommendation in z3 agent files), confirmed via `git log` as not
      authored by task 488; the complete gate set is deferred to the batch-level stage, not
      forgiven)*
- [x] Spot-check that the deployed copies of all three edited files now match their source-store
      counterparts (the carve-out subsection is present in
      `.claude/context/patterns/mcp-server-ownership.md`). *(completed: diff confirms all three
      files identical between source store and deployed tree)*
- [x] If a gate fails in a file outside this task's `file_scope`, check `git log` to confirm the
      work is not this task's own, then STOP and report rather than repairing a sibling's
      in-flight edit. *(completed: confirmed via git log, recorded in issue log and this phase's
      progress file; did not repair the unrelated failures)*

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`, an
  implicit scope claim over the entire deployed tree. No real path is declared here on purpose:
  the deployed tree is generated output, never hand-authored, and a real wide path (`.claude/`)
  would trip the coarse-declaration lint while loosening every consumer's containment guard.

**Verification**:

- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes without error inside the bound.
- `bash .claude/scripts/verify-deploy.sh` exits 0 across the complete gate set.
- `grep -c 'Carve-out' .claude/context/patterns/mcp-server-ownership.md` shows the deployed copy
  carries both carve-out subsections, confirming the source-store edit propagated.
- No file under `.claude/**` was edited by hand at any point in this task.

---

## Testing & Validation

- [x] `mcp-server-ownership.md` states a verdict that explicitly covers the
      nix-enforced-settings case (acceptance criterion 1). *(completed)*
- [x] The sapience extension's grant placement matches that verdict — i.e.
      `settings-fragment.json` is unchanged and the standard now sanctions it (acceptance
      criterion 2). *(completed)*
- [x] `bash .claude/scripts/verify-deploy.sh` gate set is green after redeploy (acceptance
      criterion 3). *(completed: scoped tier `--only-gate 3,4` green per this dispatch's Batch
      Gate Deferral directive; the complete gate set is deferred to the once-per-invocation
      batch-level stage, not independently run here -- see Phase 3's Reasoned-Exclusions-style
      note in its own progress file)*
- [x] The standard is internally consistent: no remaining sentence asserts that project-scope
      registration is the only exception to the same-scope rule. *(completed)*
- [x] The disclosure pointer is symmetric in both directions. *(completed)*
- [x] No file under `agent-system/**` gained a task-number reference or record-versioning
      language. *(completed)*
- [x] No edit was made to `~/.dotfiles/config/claude/settings.json`, `~/.claude/settings.json`, or
      `agent-system/extensions/sapience/settings-fragment.json`. *(completed)*

## Artifacts & Outputs

- Amended `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` with a new
  `## Permission` carve-out subsection and three consistency repairs.
- Amended `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`
  with a back-link and the stated verdict.
- Amended `agent-system/extensions/core/docs/guides/permission-configuration.md` carve-out summary.
- Regenerated deployed `.claude/` tree, with the full `verify-deploy.sh` gate set green.
- Implementation summary at `specs/488_mcp_write_tool_grant_ownership_scope/summaries/01_*-summary.md`.

## Rollback/Contingency

All three edits are additive prose in markdown guidance files with no executable surface, so
rollback is low-risk: `git revert` the phase commits, or restore the individual files from HEAD,
then redeploy with the same bounded-wait idiom to bring the deployed tree back in line with the
reverted source store.

If the full `verify-deploy.sh` run in Phase 3 fails on a gate unrelated to these three files,
that is most likely the pre-existing `core`/`lean` staleness or a concurrent sibling's in-flight
edit surfacing — do not revert this task's prose edits in response. Confirm ownership via
`git log`, report the failure, and let the task rest at `[PARTIAL]` rather than repairing another
task's territory.

If the carve-out text is judged too broad on review, the contingency is to narrow the three
stated requirements in place (a single-file prose edit plus a redeploy), not to withdraw the
subsection — leaving the standard silent would restore the exact apparent-violation condition this
task exists to remove.
