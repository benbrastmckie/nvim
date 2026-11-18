# Implementation Plan: Task #503

- **Task**: 503 - MIGRATED FROM BimodalLogic 2026-11-05: `/revise` unavailable to a dispatched agent, undocumented at point of use
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/503_revise_unavailable_to_dispatched_agent/reports/01_revise-unavailable-dispatched-agent.md
- **Artifacts**: plans/01_revise-unavailability-point-of-use.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/revise` is a user-facing slash command with no invocation path from a dispatched subagent, and
that unavailability is stated nowhere a dispatched agent would meet it. An agent needing another
task's description updated therefore has no documented route and must rediscover the sanctioned
one by reading `skill-reviser`'s internals end to end. This plan adds a point-of-use
unavailability note plus a named fallback route to the two surfaces the record names
(`commands/revise.md`, `skills/skill-reviser/SKILL.md`), each pointing at the other, with the
exact `state-write.sh` invocation shape left in the single place it already lives
(`skills/skill-reviser/SKILL.md` Stage 7's "For Description Update" block). Definition of done:
both notes authored under the source store, the full gate set green, and the notes present in the
deployed tree so an agent reading the deployed copy actually sees them. No change to
`skill-reviser`'s revision workflow, no new agent-invokable command, no frontmatter permissions
change.

### Research Integration

- Both mechanisms in the record's verification list are real and compound, not alternatives
  (research Findings 1-3): (i) the literal command is structurally unreachable — the documented
  command->skill->agent flow has no reverse arrow anywhere in the source store; and (ii) the
  underlying skill is nominally Skill-tool-reachable (it carries no `user-only: true` the way
  `skill-tag` does) but direct invocation is unsanctioned-by-contract, because it bypasses
  `commands/revise.md`'s CHECKPOINT 1 task-lock acquisition and CHECKPOINT 3 `.return-meta.json`
  cleanup, both of which the command owns and the skill assumes have already run.
- Candidate (iii) is rejected as the primary explanation: the incident's own wording ("could not
  invoke `/revise N`") is accurate as stated. The narrower nuance — that the skill underneath is
  not frontmatter-withheld the way `AskUserQuestion` is — does not make direct `skill-reviser`
  invocation sanctioned.
- The sanctioned mechanical path already exists and is correct: `skills/skill-reviser/SKILL.md`
  Stage 7's "For Description Update" `state-write.sh` object-merge block. Confirmed live at that
  file's Stage 7 heading. The defect is purely its undiscoverability.
- `context/standards/postflight-tool-restrictions.md` is rejected as the home — see Decisions.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied to this dispatch; no roadmap phases added.

## Premise Re-Validation (Carried-Figure Discipline)

The dispatch extracted three trigger-class lines from the description. Each was checked against
the research report and against live state; results stated explicitly below, including where the
check only confirms the description.

| Carried claim (dispatch line) | Verdict | Evidence |
|---|---|---|
| L23: a dispatched implementation agent cannot invoke `/revise`, and that unavailability is undocumented at the point of use | CONFIRMED, unchanged | Research Findings 1-3 establish the two compounding mechanisms. Re-confirmed live at plan time: `grep -n -i "user-only\|agents MUST NOT\|cannot invoke\|dispatched"` over both `agent-system/extensions/core/commands/revise.md` and `agent-system/extensions/core/skills/skill-reviser/SKILL.md` returns no match — neither surface carries any availability statement today. |
| L55: `postflight-tool-restrictions.md` is one candidate home for the general statement; weigh it and record the rejected alternative | CONFIRMED as a candidate, and WEIGHED AND REJECTED | That file's own header reads `**Purpose**: Define allowed vs prohibited operations during skill postflight phase` / `**Audience**: Skill authors, /meta agent, system maintainers` — verified live by reading its first 12 lines. Different actor (a skill's own postflight script, after a subagent returned) and different lifecycle point than a dispatched agent mid-execution. Rejection recorded under Decisions; the file is excluded from every phase's `Files to modify`. |
| L79: the `agent-system/extensions/**` entries in this task's `file_scope` do not resolve in this repository and a phase commit here cannot carry them | **NO LONGER TRUE** — superseded by this record's own migration header, and independently re-verified | The migration header above the description states this paragraph is INVERTED and must be read as history. Verified live: `agent-system/.git` does not exist (the store is not a separate repository from here); `git check-ignore -v agent-system/extensions/core/commands/revise.md` reports not-ignored; `git ls-files --error-unmatch agent-system/extensions/core/commands/revise.md` succeeds. A phase commit from this repository CAN carry these paths. Expect no containment drops on them, and treat any drop that does occur as a new observation rather than the known one. |

Additionally re-derived live per the record's binding instruction rather than trusted from its
note: `jq -r '.extensions.core.source_dir' .claude-extensions.json` ->
`/home/benjamin/.config/nvim/agent-system/extensions/core`. The path exists. Every edit below is
sited under it; no phase names a `.claude/**` path.

## Goals & Non-Goals

**Goals**:
- State, at `commands/revise.md`, that `/revise` has no invocation path from a dispatched
  subagent, say *why* a direct `skill-reviser` dispatch is also not the answer (lock bypass,
  stale `.return-meta.json` left in the target task's directory), and point at the sanctioned
  description-update route by file, stage, and heading.
- State the mirror-image note at `skills/skill-reviser/SKILL.md`, pointing a dispatched reader
  down to that same file's own Stage 7 "For Description Update" block.
- Keep the exact `state-write.sh` invocation shape in exactly one place, so a future change to
  its argument shape cannot go stale in a second copy.
- Land the notes in the deployed tree, so an agent reading the deployed copy sees them.

**Non-Goals**:
- Changing `skill-reviser`'s revision workflow (explicit record scope boundary).
- Adding a new agent-invokable description-update command (explicit record scope boundary) — the
  mechanical path exists and is correct.
- Adding a `user-only: true` marker or any other frontmatter/permissions change to
  `skill-reviser` or `commands/revise.md`: a human invoking `/revise` must keep working exactly
  as it does now. The gap is discoverability, not permissions.
- Editing `context/standards/postflight-tool-restrictions.md` (rejected; see Decisions).
- Adding the "commands are structurally unreachable, distinct from a frontmatter-withheld tool"
  cross-reference to `docs/reference/standards/agent-frontmatter-standard.md` — the research
  report raises it as a future nicety, and it is outside this record's named two-surface
  deliverable.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A future reader still invokes `skill-reviser` directly: it is not frontmatter-blocked and IS listed as an available skill in a dispatched session | M | M | Each note must say *why* it is unsafe (CHECKPOINT 1 task-lock bypass; CHECKPOINT 3 `.return-meta.json` cleanup skipped, leaving a stale sidecar in the target task's directory), not merely that it is discouraged. A bare prohibition invites exactly the rediscovery this record exists to end. |
| Duplicating the `state-write.sh` invocation shape in `commands/revise.md` lets a future argument-shape change go stale in two places | M | M | `commands/revise.md` carries a precise POINTER only (file + Stage 7 + the "For Description Update" heading), never a second copy of the snippet. Enforced as an explicit Phase 1 task and a Phase 1 verification bullet. |
| A new `subagent_type: "..."` literal placed above line 231 of `skills/skill-reviser/SKILL.md` would silently reroute two mechanical consumers | H | L | Both `scripts/validate-context-budgets.sh`'s `_dlc_subagent_type` (`grep -oP 'subagent_type:\s*"\K[^"]+' ... \| head -1`) and doc-lint's Rule D (`check_deployed_skill_agents`) take the FIRST such line in the file. The Phase 2 note sits near Trigger Conditions (~line 26-33), far above the real line 231. Explicit Phase 2 task: the note contains no `subagent_type:` literal; verified by re-running the same grep and confirming it still yields `reviser-agent`. |
| The new prose trips the blocking write-time task-reference hook | M | M | `hooks/validate-no-task-references.sh` blocks any `task N`-shaped citation outside `specs/**` at Write/Edit time (patterns in `scripts/lib/task-reference-patterns.sh`). Both notes must cite the mechanism and durable anchors (file + stage + heading), never the measured incident's record number. Explicit task in both phases. |
| A sibling dispatch's in-flight source-store edit gets swept into this task's commit or redeploy | H | L | Three siblings (plan phase, this same cycle) hold disjoint `file_scope`s that do not intersect this task's two files. Still: re-read each file immediately before editing; stage only this task's own named files by explicit path list, never a directory or glob; and in Phase 3, if a foreign commit or foreign uncommitted source-store modification is observed, STOP and report per the territory contract instead of deploying over it. |
| The redeploy in Phase 3 regenerates the whole deployed tree, an implicit claim over it | M | M | Phase 3 declares the reserved `` `__WHOLE_TREE__` `` sentinel in its `Files to modify`, so `orchestrate-batch-admit.sh`'s `whole_tree_claim` dimension can serialize this task against any other whole-tree claimant rather than letting two regenerations interleave. |
| A per-phase tier claim measured by calling `suite_selection_select` on SEVERAL paths at once is silently wrong | H | H (hit once at plan time) | Measured at plan time: calling the selector with both of this task's paths as arguments returns the bare `__FULL_SWEEP__` sentinel, because the sentinel DOMINATES the union — it masked the 26 real suites the `skill-reviser/SKILL.md` path maps to on its own. `scripts/validate-artifact.sh` caught the resulting false sentinel claim as an advisory warning, and Phase 2's tier was corrected from `prose` to `local` before this plan was accepted. Rule for the implementer: always re-run the selector **one path per call**, never a combined call, when confirming or updating a Tier Justification. |
| The deployed tree is ALREADY stale for the `core` extension before this task starts | L | H (stated by the dispatch) | Pre-existing condition, not caused here. Phase 3's deploy heals it as a side effect; any source-store content it sweeps in belongs to already-committed work. Phase 3 must not hand-patch any `.claude/**` file as a substitute for the deploy. |

## Decisions

- **Rejected**: `context/standards/postflight-tool-restrictions.md` as the home for a general
  "what a dispatched agent cannot invoke" statement. Its documented purpose and audience
  (allowed-vs-prohibited operations *during the skill postflight phase*; audience "Skill authors,
  /meta agent, system maintainers") govern a different actor at a different lifecycle point — a
  skill's own postflight script after a subagent has returned — than this record's subject, a
  dispatched agent needing a route while it is still running. Filing the statement there would
  group two unrelated restrictions under a heading readers reasonably expect to be homogeneous.
  The file stays untouched and appears in no phase's `Files to modify`, even though it is listed
  in this task's declared `file_scope` (that field is anticipated, not binding).
- **Rejected**: a third, new shared standards file as a consolidated registry. The two existing
  precedents for "what a dispatched agent cannot invoke" in this codebase are each documented at
  their point of use or consequence rather than consolidated —
  `docs/reference/standards/agent-frontmatter-standard.md`'s "Tool Withholding from Dispatched
  Subagents" section and `context/standards/push-consent-relay.md`. Two-surface placement follows
  that existing pattern instead of inventing a new one. A third instance of this same shape of
  gap would be the point to reconsider a registry; not at two.
- **Decided**: the exact `state-write.sh` invocation shape lives in exactly one place — the Stage
  7 "For Description Update" block of `skills/skill-reviser/SKILL.md`, where it already is.
  `commands/revise.md` points at it by file, stage, and heading. This satisfies the record's
  "with the exact `state-write.sh` invocation shape" requirement (the shape is named and
  reachable in one hop from the surface an agent meets) while honoring the research report's
  single-source-of-truth mitigation. Both notes also name `state-write.sh` as the single
  mutex-guarded `specs/state.json` writer, so a reader understands the call is safe without the
  command-level task lock — the mutex is internal to the script and does not depend on
  `task-lock.sh`.
- **Decided**: no `user-only: true` marker on `skill-reviser`. `skill-tag` is the system's only
  user-only precedent and the record directs comparison against it rather than invention of a new
  convention; the comparison's outcome is that `skill-reviser` is NOT user-only in that sense,
  since a human invoking `/revise` still routes through it normally. Permissions are unchanged.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files and
share no edit surface; their mutual pointers are deterministic (each names the other file by
path, plus a stable heading), so neither needs the other's text in hand.

### Phase 1: Agent-Availability Note on `commands/revise.md` [NOT STARTED]

**Goal**: A dispatched agent reading `commands/revise.md` learns, before CHECKPOINT 1, that
`/revise` is unreachable from a dispatch, why a direct `skill-reviser` dispatch is not the
substitute, and exactly where the sanctioned description-update route lives.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/commands/revise.md` in full immediately before
      editing (sibling dispatches are live on this same tree this cycle).
- [ ] Add a new `## Agent Availability` section placed after the `# /revise Command` heading
      block and before `## Arguments` (so a reader meets it before the Execution checkpoints),
      modeled in spirit on `commands/tag.md`'s "Agent Restrictions" section but with this
      record's own content — NOT a copy of `tag.md`'s user-only wording, which does not apply.
- [ ] State mechanism (i): `/revise` is a user-facing slash command, reachable only from a
      literal user/session slash-command parse. The documented command->skill->agent flow
      (`docs/guides/creating-commands.md`) is strictly unidirectional — no tool lets a dispatched
      subagent execute a slash command — so this is structural and independent of any
      frontmatter `tools:`/`disallowedTools:` configuration.
- [ ] State mechanism (ii) with its reasons, not as a bare prohibition: dispatching
      `skill-reviser` directly via the Skill tool is NOT the substitute, because it bypasses this
      command's own CHECKPOINT 1 (task-lock acquisition via `task-lock.sh acquire-retry`, plus
      the cross-task `file_scope` overlap check) and CHECKPOINT 3 (which owns
      `.return-meta.json`'s deletion — `skill_cleanup` does not delete it at the skill's Stage
      9), leaving a stale sidecar in the target task's directory and no lock protection against a
      concurrent sibling dispatch touching the same target task.
- [ ] Name the sanctioned route as a POINTER, not a second copy: the "For Description Update"
      block in Stage 7 of `skills/skill-reviser/SKILL.md`, which calls `state-write.sh` — the
      single mutex-guarded `specs/state.json` writer, whose mutex is internal to the script and
      therefore safe without the command-level task lock.
- [ ] Write no `task N`-shaped citation anywhere in the new text (the write-time hook
      `hooks/validate-no-task-references.sh` blocks it); cite durable anchors only — file paths,
      stage numbers, section headings.
- [ ] Stage and commit by explicit single-path pathspec:
      `git add -- agent-system/extensions/core/commands/revise.md`. Never a directory or glob.

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Exactly one file changes in this phase, and the change is purely additive
(one new section; no existing line removed or reworded). Confirm at implementation time with
`git diff --stat -- agent-system/extensions/core/commands/revise.md` showing one file and zero
deletions, and `git diff` read-through showing only inserted lines. If the diff shows a deletion
or a second file, stop and reconcile before committing — most likely a sibling's edit was caught.

**Tier Justification**: `suite_selection_select agent-system/extensions/core/commands/revise.md`
returns the `__FULL_SWEEP__` sentinel (run at plan time on this path ALONE — see Risks for why a
combined multi-path call must not be used), so no shell suite covers this path at all; as a
source-store non-`specs/**` markdown edit this is plan-format.md sub-case (b), whose covering
check is `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow
--only-gate 3,4 /home/benjamin/.config/nvim` alongside the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/commands/revise.md` - add an `## Agent Availability` section between the header block and `## Arguments`; exists (157 lines, confirmed at plan time). If it is absent or restructured when this phase runs, do not invent a target — record the divergence and re-site the note at the nearest equivalent point-of-use heading, noting the change in the phase's own verification.

**Verification**:
- Diff read-through confirming every changed hunk is inserted prose inside the new section, with
  no hunk crossing into the `## Execution` checkpoint bodies.
- `grep -n "## Agent Availability" agent-system/extensions/core/commands/revise.md` returns a
  line number between the header block and `## Arguments`.
- `grep -c "state-write.sh" agent-system/extensions/core/commands/revise.md` confirms the file
  mentions the script by name but contains no multi-line invocation: verify by confirming no
  `--argjson num` and no `active_projects\[\] | select` text was added (the snippet stays
  single-sourced in `skill-reviser/SKILL.md`).
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4
  /home/benjamin/.config/nvim` **exits 0** (check `$?`, not only its stdout text), with gates 3
  and 4 both reporting RAN rather than SKIP — a zero-checks-under-filter run attests to nothing.
  `TARGET` is the repository root holding both `.claude/` and `agent-system/extensions`, not
  `source_dir`: gate0 exits 2 on a source-store directory before gate selection is consulted.

---

### Phase 2: Mirror Note on `skills/skill-reviser/SKILL.md` [NOT STARTED]

**Goal**: A dispatched agent that reaches the skill directly (it is listed as an available skill
in a dispatched session and carries no `user-only` marker) learns at the top of the file that
direct invocation is not sanctioned, and is sent to the file's own Stage 7 block.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/skills/skill-reviser/SKILL.md` in full immediately
      before editing.
- [ ] Extend the existing `## Trigger Conditions` section (which already states the skill
      activates when "`/revise` command is invoked") with the mirror note, or add a short
      sibling subsection directly beneath it — not a new top-level section competing with it.
- [ ] State that this skill is not a sanctioned direct-invocation target for a dispatched agent,
      with the same two reasons Phase 1 gives (the wrapping command owns task-lock acquisition
      and `.return-meta.json` cleanup; neither happens on a bare skill dispatch) — reasons, not a
      bare prohibition.
- [ ] Point a dispatched reader down to this same file's Stage 7 "For Description Update" block
      as the route to call directly, and across to `commands/revise.md`'s `## Agent Availability`
      section for the command-side statement.
- [ ] Introduce no `subagent_type:` literal anywhere in the new text. Two consumers read the
      FIRST such line in this file and would silently reroute:
      `scripts/validate-context-budgets.sh`'s `_dlc_subagent_type`
      (`grep -oP 'subagent_type:\s*"\K[^"]+' ... | head -1`) and doc-lint's Rule D
      (`check_deployed_skill_agents`).
- [ ] Write no `task N`-shaped citation anywhere in the new text; durable anchors only.
- [ ] Stage and commit by explicit single-path pathspec:
      `git add -- agent-system/extensions/core/skills/skill-reviser/SKILL.md`.

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Exactly one file changes, purely additively, and the file's sole
`subagent_type:` line stays sole and stays `reviser-agent` (it sits at line 231 at plan time;
the new note lands near `## Trigger Conditions`, around line 26-33, far above it). Confirm with
`git diff --stat` showing one file and zero deletions, and with the grep in Verification below.

**Tier Justification**: Unlike Phase 1's path, this one is NOT sentinel-mapped —
`suite_selection_select agent-system/extensions/core/skills/skill-reviser/SKILL.md`, run at plan
time, returns a real covering-suite list, so the cheapest honest covering check is the Gate 8
subset `bash .claude/scripts/tests/run-all.sh --only test-approve-structural.sh,test-askuserquestion-rehome.sh,test-conflict-predicate.sh,test-deploy-propagation.sh,test-double-loading-check.sh,test-four-tier-conflict.sh,test-gate-cache-lib.sh,test-guard-git-push.sh,test-handoff-dispatch-identity.sh,test-handoff-reader-parity.sh,test-install-uninstall-extension.sh,test-lint-branch-gated-sections.sh,test-lint-postflight-boundary.sh,test-lint-task-lookup-adoption.sh,test-lit-pipeline.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-conclusion-roadmap.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-resume-scan-nonconformance.sh,test-roadmap-command-registration.sh,test-routing-resolution.sh,test-session-runtime-files.sh,test-skill-base-lifecycle.sh,test-stall-reprompt-wiring.sh,test-verify-deploy-context-budget.sh`
(the deployed selector's output verbatim, re-run one-path-per-call before the phase closes),
rather than a `prose` claim this path's selector output does not support.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md` - extend `## Trigger Conditions` with the dispatched-agent note pointing at this file's own Stage 7 "For Description Update" block; exists (539 lines, with `## Trigger Conditions` at line 26 and Stage 7 at line 315, both confirmed at plan time). If either anchor has moved when this phase runs, re-locate it by heading text rather than by line number, and record the shift.

**Verification**:
- Diff read-through confirming every changed hunk is inserted prose near `## Trigger Conditions`,
  with no hunk touching the YAML frontmatter, Stage 7's code block, or any other stage body.
- `grep -oP 'subagent_type:\s*"\K[^"]+' agent-system/extensions/core/skills/skill-reviser/SKILL.md
  | head -1` still prints `reviser-agent`, and
  `grep -c 'subagent_type' agent-system/extensions/core/skills/skill-reviser/SKILL.md` still
  prints `1`.
- `grep -n "For Description Update" agent-system/extensions/core/skills/skill-reviser/SKILL.md`
  shows the Stage 7 heading intact and unmodified (the note points at it; it is not rewritten).
- Re-run `suite_selection_select` on this phase's single path immediately before closing the
  phase, then run the exact `run-all.sh --only ...` invocation named in the Tier Justification
  and require **exit 0** (check `$?`, not only its stdout). The named list is the DEPLOYED
  selector lib's output (28 suites); the source-store lib currently returns a 26-suite subset of
  it, because the deployed `core` tree is stale — the superset is named deliberately so the
  declared check over-covers rather than under-covers whichever lib the implementer resolves. If
  the mapping has moved beyond that superset, run the selector's new output and record the shift.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4
  /home/benjamin/.config/nvim` **exits 0** (check `$?`, not only its stdout text), with gates 3
  and 4 both reporting RAN rather than SKIP — the doc-lint/task-reference pair that the suite
  subset above does not itself cover.

---

### Phase 3: Full Gate Verification and Deploy to the Live Tree [NOT STARTED]

**Goal**: The complete gate set runs green over both edits, and the notes reach the deployed
`.claude/` tree, so an agent reading the deployed copy of either surface actually sees them.
Without this, the deliverable exists only in the source store and the two mechanical consumers
that read the DEPLOYED copies (doc-lint Rule D, `validate-context-budgets.sh`) never observe it.

**Tasks**:
- [ ] `git status --short` and `git log --oneline -5`: confirm the working tree holds only this
      task's own changes. If a foreign commit, a foreign uncommitted source-store modification,
      or a running build not started here is observed, STOP and report per the territory
      contract's rule (5) — do not deploy over a sibling's in-flight work and do not dismiss it
      as noise.
- [ ] Run the complete gate set: `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh
      /home/benjamin/.config/nvim`. No `--skip-slow`, no `--only-gate` — a narrowed pass is not
      evidence the doc-sync pins hold and is never a substitute for the final gate.
- [ ] Redeploy with the bounded-wait idiom the dispatch names:
      `timeout 540 bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh`, with the
      Bash tool `timeout` parameter raised to 600000 (not its 120000 default), per
      `context/patterns/external-process-wait.md` Rule 1.
- [ ] Hand-patch no file under `.claude/**` under any circumstance, including to "fix" a
      deploy-time difference — that masks divergence instead of healing it
      (`rules/source-store-deploy-boundary.md`).
- [ ] Confirm the deployed copies now carry the notes, then re-run the complete gate set once
      more post-deploy so the two deployed-copy consumers are exercised against the new content.
- [ ] Stage and commit only this task's own hunks by explicit path list. `.claude/**` is
      gitignored, so the deploy itself contributes nothing to stage; if it unexpectedly does,
      stop and report rather than committing it.

**Timing**: 0.7 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: This phase's own edits to tracked files are zero — it runs gates and a
regeneration. The regeneration rewrites the entire deployed `.claude/` tree, which is gitignored
and therefore contributes no tracked change; `` `__WHOLE_TREE__` `` is declared below because
that regeneration is nonetheless an implicit scope claim over the whole deployed tree. Confirm
with `git status --short` after the deploy showing no new tracked modifications attributable to
this phase.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`; the reserved sentinel declares that implicit claim so `orchestrate-batch-admit.sh`'s `whole_tree_claim` dimension can serialize this task against any other whole-tree claimant. No real file is edited by this phase.

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim`
  exits 0 with no FAIL findings — the complete gate set this tier requires, including gate 3
  (doc-lint, `check-extension-docs.sh`), gate 4 (task-reference lint,
  `check-task-references.sh`), and gate 8 (the full `tests/run-all.sh` shell battery). A
  zero-checks-under-filter condition does not count as a pass.
- Post-deploy, both deployed copies carry the notes:
  `grep -n "## Agent Availability" /home/benjamin/.config/nvim/.claude/commands/revise.md` and
  `grep -n -i "dispatched" /home/benjamin/.config/nvim/.claude/skills/skill-reviser/SKILL.md`
  each return a match.
- Post-deploy, the mechanical consumers still resolve the skill's route correctly:
  `grep -oP 'subagent_type:\s*"\K[^"]+' /home/benjamin/.config/nvim/.claude/skills/skill-reviser/SKILL.md
  | head -1` prints `reviser-agent` (doc-lint Rule D and
  `validate-context-budgets.sh`'s double-loading check both read this deployed path).
- The post-deploy gate set run is green too, and the dispatch's reported `core` staleness is no
  longer present.

---

## Testing & Validation

- [ ] Both notes state mechanism (i) (structural command unreachability) AND mechanism (ii)
      (unsanctioned direct skill dispatch) with reasons, not bare prohibitions — a reader learns
      why the lock bypass and the stale `.return-meta.json` matter.
- [ ] The exact `state-write.sh` object-merge invocation appears in exactly one file across the
      repository's source store (`skills/skill-reviser/SKILL.md` Stage 7). Confirm with
      `grep -rn -- "--argjson num" agent-system/extensions/core/commands/ agent-system/extensions/core/skills/skill-reviser/`
      matching only the Stage 7 block.
- [ ] Each note reaches the other: `commands/revise.md` names
      `skills/skill-reviser/SKILL.md` Stage 7, and `skills/skill-reviser/SKILL.md` names
      `commands/revise.md`'s `## Agent Availability` section.
- [ ] No `user-only` field or `tools:`/`disallowedTools:` change was introduced in either file:
      `git diff` over both files shows no frontmatter hunk.
- [ ] No `task N`-shaped citation in either file's new text; the write-time hook did not fire and
      gate 4 is green.
- [ ] `skill-reviser`'s revision workflow is textually unchanged: `git diff` shows no hunk inside
      Stages 1-11 bodies, only the Trigger Conditions addition.
- [ ] `context/standards/postflight-tool-restrictions.md` is unmodified:
      `git diff --stat -- agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`
      is empty.
- [ ] The complete gate set is green both before the deploy (source-store content) and after it
      (deployed content).

## Artifacts & Outputs

- `agent-system/extensions/core/commands/revise.md` - new `## Agent Availability` section.
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md` - dispatched-agent note extending
  `## Trigger Conditions`, pointing at the file's own Stage 7 block.
- A regenerated deployed `.claude/` tree carrying both notes (gitignored; not a committed
  artifact).
- `specs/503_revise_unavailable_to_dispatched_agent/summaries/01_*-summary.md` at completion,
  recording the rejected `postflight-tool-restrictions.md` alternative and the rejected
  consolidated-registry alternative as the record requires.

## Rollback/Contingency

Both source-store edits are purely additive prose in two independent files, each committed by
explicit single-path pathspec, so reverting either is a per-file `git revert` of that phase's own
commit — no cross-file coupling to unwind.

If an intentional rollback must discard uncommitted work, use the snapshot-then-rollback recipe
in `context/contracts/recovery.md`'s rollback rung for the exact invocation shape, including its
out-of-scope override flag for the deliberate whole-tree case. Do not emit a bare
`git-snapshot.sh 503` as a routine precaution; an ordinary defensive checkpoint before risky work
uses `--no-revert`, which is durable without reverting the working tree.

If Phase 3's gate set fails on something outside this task's two files, treat it as possibly a
sibling's in-flight edit on this shared tree rather than a regression from these edits — check
`git log` and `git status --short` to confirm the work is not this task's own before attributing
it, and report rather than "fixing" a foreign failure.

If the redeploy cannot run or does not complete within its bound, the two source-store commits
still stand on their own and the task's deliverable is intact in the source store; record the
deploy shortfall as an observation of its own (the tree was already reported stale for `core`
before this task began) and do not hand-patch `.claude/**` to simulate the deploy.
