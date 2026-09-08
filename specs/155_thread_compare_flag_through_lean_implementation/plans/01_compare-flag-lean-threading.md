# Implementation Plan: Task #155

- **Task**: 155 - Thread an advisory `--compare` flag through the lean implementation path
- **Status**: [COMPLETED]
- **Effort**: 7 hours
- **Dependencies**: `lean-comparator-run.sh` (exists, tested), `lean-challenge-snapshot.sh` (exists, tested); dependency-ordered behind the in-flight lean artifact-skeletons work that edits `agents/lean-implementation-agent.md` and `agents/lean-research-agent.md`
- **Research Inputs**: specs/155_thread_compare_flag_through_lean_implementation/reports/01_compare-flag-lean-threading.md
- **Artifacts**: plans/01_compare-flag-lean-threading.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task is pure wiring. Both Lean-side building blocks already exist and are tested:
`lean-comparator-run.sh` (the sandboxed Comparator judge wrapper with a closed 9-verdict
vocabulary) and `lean-challenge-snapshot.sh` (which produces the immutable `Challenge.lean` plus
`specs/{NNN}_{SLUG}/challenge/manifest.json`). What is missing is the spine that carries an
opt-in `--compare` request from the command line, through the orchestrator's dispatch machinery,
into the two Lean implementation skills' delegation contexts, into the two Lean implementation
agents' Final Verification Stage, out into a `comparator` block in `.return-meta.json`, and back
up into the skill postflight's returned summary.

The gate is **advisory only**, and that decision is binding and not relitigated here: a
Comparator rejection is recorded and surfaced loudly, but MUST NOT set `verification_passed`
false, MUST NOT downgrade status to `partial`, and MUST NOT block completion. The failure mode
this plan designs against is not a false block — it is a finding nobody ever reads.

All edits land in `agent-system/extensions/**` (the source store). No file under `.claude/**` is
hand-authored; `.claude/` is a disposable deploy artifact regenerated from the source store.

### Research Integration

The research report (`reports/01_compare-flag-lean-threading.md`) established the exact
precedents this plan copies: `LIT_FLAG`'s 4-part shape in `parse-command-args.sh`; the two
skills' delegation-context JSON blocks; the two agents' numbered Final Verification checklists;
Stage 6b/6a's "SKILL reads the agent-recorded result, never re-runs the check" postflight
pattern; and `### completion_data (optional)` as the template for a new schema section. It also
surfaced one integration risk not in the dispatch's WORK list — the Challenge commit and the
Solution commit are necessarily different, and `lean-comparator-run.sh --commit REF` checks out
one commit for both modules — which this plan handles with an explicit content-hash cross-check
(Phase 4). Research left four questions open; all four are resolved below rather than deferred
further.

### Resolved Open Questions

**Q1 — Is `/orchestrate N --compare` plumbing in scope?** *Yes, and the plan scopes it
explicitly (Phase 2).* The ACCEPTANCE criteria are written entirely in dispatch-level language
("a lean4 dispatch WITH `--compare`", "`--compare --hard` routes to the hard agent AND runs the
Comparator step"). None of those can be exercised if `--compare` is unreachable from the only
command that produces a lean4 implementation dispatch. Concretely, `COMPARE_FLAG` from
`parse-command-args.sh` is dead unless `skill-orchestrate` reads it, and the skill's implement
dispatch sites build their arguments through `orchestrate-cycle-plan.sh` ->
`orchestrate-build-dispatch.sh`. Two constraints shape the scope:

- The dispatch file is declared to the agent as authoritative ("names every input, output path,
  and contract this one dispatch carries"). If `compare_flag` lived only in the JSON delegation
  context and the dispatch file were silent, the two channels would disagree on the same run.
  So `orchestrate-build-dispatch.sh` emits it.
- ACCEPTANCE bullet 1 requires a no-`--compare` dispatch to behave *exactly* as today. So the
  dispatch-file line is emitted **only when `compare_flag=true`** — a run without the flag
  produces a byte-identical dispatch file to today's, which is directly demonstrable by diff.

Scope is further narrowed to the **implement-phase** dispatch sites only. `--compare` is
meaningless for research and plan dispatches, and threading it there would add churn with no
acceptance criterion behind it.

**Q2 — `solution_module` derivation.** *Reuse the agent's existing Stage-5 compliance-check file
discovery; never synthesize a module.* For each identifier in the manifest's `theorem_names`,
run the same `grep -rl "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) ${name}\b"`
search the compliance step already performs, collect the distinct set of matching files, and:

- **exactly one file** -> `solution_module` is that path relative to `project_root` with `.lean`
  stripped and `/` replaced by `.` (the exact inverse of `lean-challenge-snapshot.sh`'s
  `CHALLENGE_REL_PATH="${CHALLENGE_MODULE}.lean"`, so the two sides use one convention);
- **zero files** -> preflight verdict `solution_module_unresolved`;
- **two or more files** -> preflight verdict `solution_module_ambiguous`, with the candidate file
  list in `reason_detail`.

Synthesizing an aggregator module that imports several files is explicitly rejected: it would
require writing a new `.lean` file into the target project and committing it so the clean-room
worktree checkout can see it, which mutates the very tree whose integrity the check exists to
establish. Recording ambiguity as a loud advisory finding, with the concrete remediation named
(co-locate the plan's goal identifiers in one module, or extend the runner to accept multiple
solution modules in a separate, later task), is the correct advisory-mode behavior.

**Q3 — Does a missing Challenge manifest need its own verdict category?** *Yes — a distinct
verdict in a caller-side namespace, discriminated by a `verdict_source` field.* Reusing
`comparator_unavailable` would conflate two conditions with different owners and different
remediations: `comparator_unavailable` means "the tool could not run, install/fix the toolchain",
whereas a missing manifest means "nobody ran the prerequisite at plan time, run
`lean-challenge-snapshot.sh`". The research report names that conflation as a specific hazard.
Consumer simplicity is preserved by keeping exactly one `verdict` string field — any value other
than `verified` is surfaced loudly — with `verdict_source` (`"runner"` or `"preflight"`) telling
a reader which vocabulary the value is drawn from. The two vocabularies are:

| Source | Verdicts |
|--------|----------|
| `runner` (from `lean-comparator-run.sh`, unchanged, closed) | `verified`, `statement_mismatch`, `axiom_violation`, `kernel_rejected`, `definition_hole_needs_human`, `comparator_unavailable`, `timeout`, `config_error`, `unclassified_failure` |
| `preflight` (new, agent-side, this task) | `challenge_missing`, `challenge_drift`, `solution_module_unresolved`, `solution_module_ambiguous` |

A run where `--compare` was not passed records no `comparator` block at all (see Phase 3's
`ran` field discussion) rather than a `not_requested` verdict, so that ACCEPTANCE bullet 1's "no
new metadata block" holds literally.

**Q4 — Does `skill-lean-implementation-hard/SKILL.md` need its own postflight surfacing stage?**
*Yes.* The hard skill has its own `### Stage 6a: Plan Compliance Check (Read from Metadata)`,
structurally parallel to the base skill's Stage 6b; the two skills do not share postflight code.
Both therefore get their own comparator-surfacing stage (Phase 5).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (`specs/ROADMAP.md` does not exist). No roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Add `COMPARE_FLAG` to `core/scripts/parse-command-args.sh` as a boolean mode hint modeled on
  `LIT_FLAG`/`CLEAN_FLAG`, composable with `--hard` rather than competing with it.
- Thread `compare_flag` from `/orchestrate` through `orchestrate-cycle-plan.sh` and
  `orchestrate-build-dispatch.sh` to the implement-phase dispatch, emitting nothing new when the
  flag is absent.
- Pass `compare_flag` into the delegation context of both
  `skills/skill-lean-implementation/SKILL.md` and `skills/skill-lean-implementation-hard/SKILL.md`.
- Add a gated Comparator step to the Final Verification Stage of both
  `agents/lean-implementation-agent.md` and `agents/lean-implementation-hard-agent.md`, running
  only when `compare_flag == true`.
- Record a `comparator` block in `.return-meta.json` (verdict, verdict_source, theorem names,
  axiom whitelist, runtime) and document it as `### comparator (optional)` in
  `core/context/formats/return-metadata-file.md`.
- Surface a non-`verified` verdict loudly in both skills' postflight and in the returned summary,
  without ever downgrading status.
- Record concrete promotion-to-hard-gate criteria in the implementation summary.

**Non-Goals**:
- Any change to `lean-comparator-run.sh` or `lean-challenge-snapshot.sh`. Both are finished,
  tested, and their design records are binding.
- Any change to the existing `verification` block keys (`verification_passed`, `sorry_count`,
  `vacuous_count`, `axiom_count`, `build_passed`). Explicitly untouched by this task.
- Documenting the pre-existing, currently-undocumented `verification` block in
  `return-metadata-file.md`. Research flagged this gap; fixing it here is scope creep and belongs
  in a separate follow-up.
- Promoting the gate from advisory to blocking. That is a separate, later, evidence-based
  decision.
- Threading `compare_flag` into research- or plan-phase dispatches.
- Installing, provisioning, or fixing `landrun` / `lean4export` / `nanoda_bin` / `comparator`
  binaries. A missing binary yielding `comparator_unavailable` is a designed-for, tested outcome.
- Adding a plan-format field for a per-plan `permitted_axioms` override.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A mode hint that fires unconditionally regresses every existing lean4 task (cost: two sandboxed builds + two exports + a kernel replay) | H | M | Gate the agent step on `compare_flag == true` as its literal first line; emit the dispatch-file line only when true; Phase 6 demonstrates a no-flag dispatch is byte-identical by diff |
| The advisory contract is quietly broken by an editor folding the new step into the existing "On verification failure -> status: partial" enumeration | H | M | State the MUST NOTs inline in the new agent step's own text, not only in the schema doc; Phase 6 exercises a rejection end to end and asserts completion still happens |
| Commit-selection mismatch: Challenge is committed at plan time, Solution only after implementation; the runner checks out ONE commit for both | H | M | Pass `--commit <post-implementation HEAD>`, and cross-check `git show <that-commit>:<challenge_path> \| sha256sum` against the manifest's `content_sha256` before trusting the run; a mismatch is the `challenge_drift` preflight verdict |
| A rejection is recorded but nobody reads it (the named failure mode) | H | M | Loud, differently-worded postflight line per verdict in both skills; a mandatory section in the written summary artifact; non-`verified` named in the returned brief summary |
| Missing Challenge manifest is conflated with a missing binary, so the operator cannot tell which remediation applies | M | H | Distinct `challenge_missing` preflight verdict plus a `verdict_source` discriminator (Q3) |
| Goal identifiers span several files, so no single `solution_module` exists | M | M | `solution_module_ambiguous` preflight verdict naming the candidate files; explicitly no aggregator-module synthesis (Q2) |
| The in-flight lean artifact-skeletons task is concurrently editing `agents/lean-implementation-agent.md` | M | M | Re-read both agent files at implementation time rather than working from any line numbers quoted here; Phase 4 requires a fresh read before editing |
| `skill-orchestrate/SKILL.md` has many dispatch sites; editing the wrong ones adds churn or misses the implement path | M | M | Phase 2 carries a Scope Hypothesis requiring the implementer to enumerate implement-phase dispatch sites by grep before editing, and to touch only those |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4, 5 | 1, 3 |
| 3 | 6 | 2, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Flag Spine — `COMPARE_FLAG` in `parse-command-args.sh` [COMPLETED]

**Goal**: `--compare` is parsed into an exported boolean `COMPARE_FLAG`, shaped exactly like
`LIT_FLAG`, and stripped from `FOCUS_PROMPT` so it never leaks into a description.

**Tasks**:
- [x] Add a `COMPARE_FLAG` line to the file's header comment block enumerating exported
      variables, worded like the existing `LIT_FLAG` line and naming it a mode hint that composes
      with `--hard` (the header block is load-bearing documentation — extend it, do not merely add
      the assignment). *(completed)*
- [x] Add `COMPARE_FLAG="false"` to the flag-init default block, adjacent to `LIT_FLAG="false"`. *(completed)*
- [x] Add the `if [[ "$remaining" =~ --compare ]]; then COMPARE_FLAG="true"; fi` match block,
      adjacent to the `--lit` block. *(completed)*
- [x] Add `| sed 's/--compare//g' \` to the `FOCUS_PROMPT` construction chain. *(completed)*
- [x] Add `COMPARE_FLAG` to the final `export` line. *(completed)*
- [x] Confirm `COMPARE_FLAG` is NOT modeled on `EFFORT_FLAG` (no enum slot, no mutual exclusion
      with `--hard`, `--fast`, or any model flag). *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/parse-command-args.sh` - five additions mirroring
  `LIT_FLAG` (header doc, default, match block, `sed` strip, `export`)

**Verification**:
- `bash -n agent-system/extensions/core/scripts/parse-command-args.sh` passes.
- Sourcing the script with `--compare` in the args exports `COMPARE_FLAG=true`; without it,
  `COMPARE_FLAG=false`.
- With `--compare --hard`, both `COMPARE_FLAG=true` and `EFFORT_FLAG=hard` hold simultaneously —
  the composability requirement, checked directly rather than assumed.
- `FOCUS_PROMPT` produced from an args string containing `--compare` contains no `--compare`
  substring.

---

### Phase 2: Orchestrate Plumbing — `--compare` reaches an implement dispatch [COMPLETED]

**Goal**: `/orchestrate N --compare` (and `--compare --hard`) carries `compare_flag=true` to the
implement-phase dispatch, and a run without `--compare` produces exactly today's output.

**Tasks**:
- [x] Re-read the `--lit` treatment in each of the four files below and mirror it; do not invent a
      new shape. *(completed)*
- [x] `commands/orchestrate.md`: add a `--compare` row to the options table alongside the `--lit`
      row, stating it is advisory-only, lean-implementation-scoped, and composable with `--hard`
      and the model flags. Update the `--hard` row's composability list to name `--compare`. *(completed)*
- [x] `scripts/orchestrate-cycle-plan.sh`: add `compare_flag="false"`, a `--compare)` case in the
      argument loop, the usage-line mention in both header and `usage()`, and
      `[ "$compare_flag" = "true" ] && build_args+=(--compare)` next to the existing `--lit` line. *(completed)*
- [x] `scripts/orchestrate-build-dispatch.sh`: add `compare_flag="false"`, a `--compare)` case,
      the two usage-line mentions, and emission of a single `- compare_flag: true` line into the
      dispatch file's `## Identity` section — **emitted only when the flag is true**, so a
      no-flag dispatch file is byte-identical to today's. *(completed)*
- [x] `skills/skill-orchestrate/SKILL.md`: enumerate the implement-phase dispatch sites by grep,
      then at each add `[ "${compare_flag:-false}" = "true" ] && build_args+=(--compare)` beside
      the existing `--lit` line, and add `compare_flag` to that site's `context` table row.
      Add `compare_flag` (default `"false"`) to the skill's documented input list where
      `lit_flag` and `clean_flag` are already listed. *(completed: 3 implement dispatch sites found via `grep -n 'build_args+=(--lit)'` — 7 total hits, classified 2 research (lines 803/863), 2 plan (989/1123), 3 implement (1453/1547/1625); only the 3 implement sites edited, matching the plan's 4-file assumption. Additionally forwarded --compare in the MT-3 multi-task call site to orchestrate-cycle-plan.sh, which was not caught by the literal grep pattern but is required for --compare to have any effect in multi-task mode)*
- [x] Leave every research-phase and plan-phase dispatch site untouched. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This plan asserts four files and "the implement-phase dispatch sites only"
in `skill-orchestrate/SKILL.md`. Confirm at implementation time with
`grep -n 'build_args+=(--lit)' agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
and, for each hit, read the surrounding dispatch block to classify it as research / plan /
implement. Edit only the implement ones and record the confirmed count and line numbers in the
summary. If the confirmed set differs from the four-file assumption, report the difference rather
than silently widening or narrowing the edit.

**Files to modify**:
- `agent-system/extensions/core/commands/orchestrate.md` - options-table row; `--hard`
  composability note
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - default, `--compare` case,
  usage lines, `build_args` forwarding
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - default, `--compare`
  case, usage lines, conditional Identity-section emission
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - input list; implement-site
  `build_args` lines and `context` table rows

**Verification**:
- `bash -n` passes on both modified scripts.
- `orchestrate-build-dispatch.sh` run without `--compare` produces a dispatch file byte-identical
  to the pre-change output for the same inputs (diff, not eyeball).
- The same run with `--compare` differs by exactly the one added `compare_flag: true` line.
- `orchestrate-cycle-plan.sh` invoked with `--compare` includes `--compare` in the build args it
  emits for an implement-phase task, and does not for a research- or plan-phase task.
- `--compare --hard` together yield both the hard routing and `compare_flag=true`.

---

### Phase 3: Metadata Schema — document the `comparator` block [COMPLETED]

**Goal**: The `comparator` block is a documented part of `return-metadata-file.md`'s schema, with
its verdict vocabulary and its advisory contract stated inline, before any writer or reader of it
is implemented.

**Tasks**:
- [x] Add a `### comparator (optional)` section to
      `core/context/formats/return-metadata-file.md`, structurally modeled on the existing
      `### completion_data (optional)` section (Type / Include if / field table / Notes). *(completed)*
- [x] Field table: `ran` (bool, yes), `verdict` (string, yes), `verdict_source` (string, yes —
      `runner` or `preflight`), `reason_detail` (string, no), `underlying_verdict` (string, no —
      present only for `definition_hole_needs_human`), `theorem_names` (array of strings, yes),
      `permitted_axioms` (array of strings, yes), `solution_module` (string, no),
      `challenge_commit` (string, no), `solution_commit` (string, no), `runtime_seconds`
      (number, yes). *(completed)*
- [x] Document both verdict vocabularies as a table, exactly as reproduced in this plan's Q3
      resolution — the nine `runner` values carried through unchanged from
      `lean-comparator-run.sh`, and the four new `preflight` values. *(completed)*
- [x] State the advisory contract inline in the Notes list, verbatim in force: a `comparator`
      block MUST NOT cause `verification_passed` to be set false, MUST NOT downgrade status to
      `partial`, and MUST NOT block completion — so a reader of the schema doc alone, without the
      design record, still gets the binding constraint. *(completed)*
- [x] State that the block is omitted entirely when `--compare` was not passed (there is no
      `"ran": false` "not requested" record), and that `"ran": false` is reserved for a request
      that reached preflight and stopped there. *(completed)*
- [x] Note that this section documents a lean-only block and does not alter the `verification`
      block's keys. *(completed)*
- [x] Do not add `comparator` to the generic top-level `## Schema` JSON example — that block
      already omits `completion_data` and `verification`, and is not exhaustive; adding a
      lean-only field there would misrepresent it as universal. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - new
  `### comparator (optional)` section placed after `### completion_data (optional)`

**Verification**:
- The new section's heading matches the file's existing `### {name} (optional)` convention.
- Every field named in Phases 4 and 5 appears in the field table, and no field appears in the
  table that no phase writes.
- The three MUST NOT clauses are present verbatim.
- No pre-existing section is modified.

---

### Phase 4: Agent Gate — Comparator step in both Final Verification Stages [COMPLETED]

**Goal**: Both Lean implementation agents run the Comparator against the snapshot Challenge and
the implemented Solution when — and only when — `compare_flag == true`, and record the result in
the `comparator` block without ever changing their own status logic.

**Tasks**:
- [x] **Re-read both agent files fresh** before editing (the lean artifact-skeletons task edits
      `lean-implementation-agent.md` concurrently; any line number in this plan is stale by
      assumption). *(completed)*
- [x] In `agents/lean-implementation-agent.md`, append a numbered step 6 to the Final Verification
      Stage checklist, after "Plan compliance spot-check". *(completed)*
- [x] In `agents/lean-implementation-hard-agent.md`, append the structurally identical step 6 to
      its Stage 6 checklist. *(completed)*
- [x] The step's literal first line is the gate: if `compare_flag` is not `true`, do nothing —
      no invocation, no `comparator` block, no runtime cost — and skip the rest of the step. *(completed)*
- [x] Preflight, in order, each producing a `verdict_source: "preflight"` verdict on failure and
      stopping without invoking the runner:
      1. Locate `specs/{padded_num}_${project_name}/challenge/manifest.json`. Absent ->
         `challenge_missing`, with `reason_detail` naming
         `lean-challenge-snapshot.sh` as the remediation.
      2. Read `project_root`, `challenge_module`, `challenge_path`, `theorem_names`, and
         `content_sha256` from the manifest with `jq`. Never re-derive any of these; in
         particular read `theorem_names` from the manifest rather than re-parsing the plan's
         `**Goals**:` bullets, since the snapshot already cross-validated the two sets.
      3. Resolve the solution commit as the post-implementation `HEAD` of `project_root`, then
         cross-check `git -C "$project_root" show "${solution_commit}:${challenge_path}" |
         sha256sum` against the manifest's `content_sha256`. Mismatch -> `challenge_drift`.
      4. Derive `solution_module` per this plan's Q2 rule, reusing the Stage-5 compliance
         `grep -rl` discovery. Zero matches -> `solution_module_unresolved`; two or more distinct
         files -> `solution_module_ambiguous` with the candidate list in `reason_detail`. *(completed)*
- [x] Invoke `bash .claude/scripts/lean-comparator-run.sh --json` with `--project-root`,
      `--challenge-module`, `--solution-module`, `--theorems` (the manifest list, comma-joined),
      `--permitted-axioms propext,Quot.sound,Classical.choice`, and
      `--commit "$solution_commit"`. Do not pass `--definitions` (a non-empty list downgrades an
      otherwise-`verified` result to `definition_hole_needs_human`, which is not what this gate
      is asking). *(completed)*
- [x] Capture wall-clock elapsed seconds around the invocation as `runtime_seconds`. *(completed)*
- [x] Map the runner's `--json` output into the `comparator` block: `verdict`, `reason_detail`,
      `underlying_verdict` carried through unchanged, with `verdict_source: "runner"`, plus
      `ran: true`, `theorem_names`, `permitted_axioms`, `solution_module`, `challenge_commit`
      (the manifest's `commit`), `solution_commit`, and `runtime_seconds`. *(completed)*
- [x] State explicitly, inside the new step's own text: a non-`verified` verdict MUST NOT set
      `status: "partial"`, MUST NOT set `verification_passed` false, MUST NOT set
      `requires_user_review`, and MUST NOT be added to the file's existing "On verification
      failure" enumeration. This wording exists precisely so a later editor does not fold the new
      step into that list. *(completed)*
- [x] Require the agent to name any non-`verified` verdict prominently in its implementation
      summary artifact (a dedicated section, not a buried line) and in its returned brief text
      summary. *(completed)*
- [x] Require the summary to record concrete promotion-to-hard-gate criteria (see Phase 6's
      wording requirement). *(completed)*

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - new gated step 6 in the
  Final Verification Stage
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - structurally
  identical step 6 in Stage 6

**Verification**:
- Every bash snippet added to either file passes `bash -n` when extracted from its fence.
- Every field the step writes exists in the Phase 3 field table; every `verdict` value it can
  produce exists in one of the two Phase 3 vocabularies.
- The gate condition is the step's first line in both files (read the diff, confirm it precedes
  every side-effecting statement).
- Neither file's existing "On verification failure" / "On Verification Failure" paragraph gained
  a comparator condition — confirm by reading those paragraphs' diffs, which must be empty.
- The two files' steps are structurally parallel (same preflight order, same verdicts, same
  advisory MUST NOTs); a diff of the two new sections shows only wording differences appropriate
  to each file's voice.

---

### Phase 5: Skill Threading and Postflight Surface [COMPLETED]

**Goal**: Both Lean implementation skills forward `compare_flag` into the agent's delegation
context, and both read back the agent-recorded `comparator` block and surface a non-`verified`
verdict loudly — without re-running anything and without downgrading status.

**Tasks**:
- [x] `skills/skill-lean-implementation/SKILL.md` Stage 3: add
      `"compare_flag": {true|false}` to the delegation-context JSON block, with a short note that
      it is forwarded from this skill's own delegation context unchanged and defaults to `false`
      when absent — modeled on the hard skill's existing "forward `dispatch_seq` unchanged, never
      invent" wording. *(completed)*
- [x] `skills/skill-lean-implementation-hard/SKILL.md` Stage 4: the same addition to its
      delegation-context JSON block, beside the existing `"effort_flag": "hard"` (which it does
      not replace — `--compare` composes with `--hard`). *(completed)*
- [x] Both skills' Stage 4/Stage 5 "The subagent will:" bullet lists: add a bullet noting the
      subagent runs the advisory Comparator gate when `compare_flag` is true. *(completed)*
- [x] Add `### Stage 6c: Comparator Verdict Surface (Read from Metadata)` to the base skill,
      immediately after Stage 6b, and the analogous stage to the hard skill immediately after its
      Stage 6a. Both read the block with `jq` from the already-written `.return-meta.json`
      (`.comparator.ran`, `.comparator.verdict`, `.comparator.verdict_source`,
      `.comparator.reason_detail`) and branch:
      - block absent / `ran` false-y -> a single INFO line; proceed silently.
      - `verified` -> a one-line PASS.
      - any other verdict -> a loud, multi-line block naming the verdict, its
        `verdict_source`, the `reason_detail`, and the fact that this is ADVISORY and completion
        is proceeding regardless. *(completed: the hard skill's Stage 6c is placed immediately after the pre-existing Stage 6b, not literally between 6a/6b, to avoid renumbering downstream Stages 7-10; documented inline as a placement note)*
- [x] Each new stage carries the same architecture note Stage 6b carries: the skill READS the
      agent-recorded result and MUST NOT re-run the check, per
      `context/standards/postflight-tool-restrictions.md`. *(completed)*
- [x] Each new stage MUST NOT assign `status="partial"` — unlike Stage 6b's
      `compliance_check == "failed"` branch, which does. Call this asymmetry out explicitly in a
      one-line comment so it does not read as an omission a later editor should "fix". *(completed)*
- [x] Both skills' final "Return Brief Summary" stage: add a conditional bullet that names a
      non-`verified` verdict in the returned summary. Do not add a bullet for the `verified` or
      absent cases beyond a single short line. *(completed)*
- [x] Both skills' `## MUST NOT (Postflight Boundary)` list: add "MUST NOT re-run the Comparator"
      and "MUST NOT downgrade status on a Comparator verdict". *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1, 3

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md` - Stage 3 delegation
  context; new Stage 6c; Stage 9 return format; MUST NOT list
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` - Stage 4
  delegation context; new comparator stage after Stage 6a; Stage 10 return format; MUST NOT list

**Verification**:
- Both delegation-context JSON blocks remain valid JSON with the new key present (parse the
  fenced block).
- Every `jq` path the new stages read matches a field name in the Phase 3 table.
- No new stage contains an assignment to `status` — confirm by grepping the added hunks.
- The hard skill's `"effort_flag": "hard"` is still present and unmodified.
- Added bash snippets pass `bash -n`.

---

### Phase 6: Acceptance Demonstration and Regression Coverage [COMPLETED]

**Goal**: All five ACCEPTANCE criteria are demonstrated with evidence, the orchestrate plumbing
has automated regression coverage, and the promotion criteria are recorded.

**Tasks**:
- [x] **A1 — no-flag parity.** Produce a dispatch file for a lean4 task without `--compare` and
      diff it against the pre-change output for identical inputs. Assert byte-identity. Assert no
      `comparator` block is produced and no Comparator invocation occurs. *(completed: demonstrated
      LIVE — a fixture-repo run of `orchestrate-build-dispatch.sh` without `--compare` vs. with it
      diffs by exactly one added `- compare_flag: true` line; also codified as Group 9 in
      `test-orchestrate-build-dispatch.sh`)*
- [x] **A2 — honest implementation.** Using the existing `simple_match` fixture under
      `agent-system/extensions/lean/scripts/tests/fixtures/comparator/`, exercise the gate path
      end to end and assert a `verified` verdict is recorded and the run completes normally.
      *(completed: demonstrated LIVE — the exact bash block added to
      `lean-implementation-agent.md` was extracted and run against a fixture project with a
      stubbed landrun/lean4export/lake/comparator toolchain (the same stub technique
      `test-lean-comparator-run.sh` already uses for its own V1 case), producing
      `verdict=verified source=runner solution_module=Theories.Solution`)*
- [x] **A3 — weakened statement still completes.** Using the existing `statement_weakened`
      fixture, assert a `statement_mismatch` verdict is recorded, is surfaced in both the returned
      summary and the written summary artifact, and that status is NOT downgraded and completion
      still happens. This is the criterion that actually tests the advisory contract — treat a
      pass here as the phase's primary evidence. *(completed: demonstrated LIVE in two parts — (1)
      the extracted agent bash block, run against a fixture Solution with a stubbed comparator
      emitting the upstream "theorem statement do not match" string, recorded
      `verdict=statement_mismatch source=runner`; (2) the extracted Stage 6c bash block from
      `skill-lean-implementation/SKILL.md`, run against a synthetic `.return-meta.json` carrying
      that verdict with `status=implemented` on input, printed the loud advisory block AND left
      `status` unchanged at `implemented` — proving the advisory contract holds in the one
      direction that actually tests it)*
- [x] **A4 — composition.** Assert `--compare --hard` routes to `lean-implementation-hard-agent`
      AND carries `compare_flag=true`. *(completed: demonstrated LIVE — Group 12's second case in
      `test-orchestrate-cycle-plan.sh` asserts both `--compare` and `--hard` reach the same
      implement build_args; hard-mode agent routing itself (`effort_flag=hard` ->
      lean-implementation-hard-agent via `command-route-agent.sh`) is pre-existing, unmodified
      logic confirmed present and untouched by this task)*
- [x] **A5 — missing binaries.** With `landrun`/`lean4export` unavailable (their state on this
      host as measured), assert a reported `comparator_unavailable` verdict — not a silent pass,
      not a block. *(completed: demonstrated LIVE against the REAL `lean-comparator-run.sh` and
      the REAL environment — `landrun`/`comparator` are now present on this host but `lean4export`
      remains absent, and both a direct invocation and the extracted agent bash block's "happy
      path" branch correctly resolved `solution_module` and then received
      `verdict=comparator_unavailable source=runner` from the real script, not a stub)*
- [x] **Preflight verdicts.** Additionally assert `challenge_missing` (no manifest) and
      `challenge_drift` (manifest present, Challenge content at the solution commit hashes
      differently) each produce their own verdict with `verdict_source: "preflight"`. *(completed:
      demonstrated LIVE via the extracted agent bash block — no manifest -> `challenge_missing`;
      manifest with a deliberately wrong `content_sha256` -> `challenge_drift` with the exact
      mismatched hashes named in `reason_detail`; additionally exercised (beyond the two named
      here) `solution_module_unresolved` (zero matching theorem declarations) and
      `solution_module_ambiguous` (two files declaring the same theorem name), both also
      `verdict_source: preflight`)*
- [x] Add regression cases to `core/scripts/tests/test-orchestrate-build-dispatch.sh` (dispatch
      file gains the `compare_flag` line only when `--compare` is passed) and
      `core/scripts/tests/test-orchestrate-cycle-plan.sh` (`--compare` forwards into build args
      for an implement-phase task and not for research/plan). *(completed: Group 9 added to
      `test-orchestrate-build-dispatch.sh` (58 passed, 0 failed overall); Group 12 added to
      `test-orchestrate-cycle-plan.sh` (89 passed, 0 failed overall))*
- [x] Run the existing `agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh`
      and confirm it still passes unchanged (this task edits nothing it covers; a failure means
      something unintended was touched). *(completed: 22 passed, 0 failed, 1 skipped (real E2E
      Comparator binaries), identical to its pre-task result — this task made no edits to this
      script or to `lean-comparator-run.sh` itself)*
- [x] Write the implementation summary, including a dedicated **Promotion Criteria** section
      enumerating concrete, evidence-based conditions for promoting the gate from advisory to
      blocking — e.g. N consecutive `verified` runs across M distinct target projects with zero
      `comparator_unavailable` and zero `preflight`-sourced verdicts, and a measured p95 runtime
      under an agreed budget — so the later decision has evidence rather than vibes. *(completed)*
- [x] Run the repository's deploy/validation gate over the modified source-store files.
      *(completed: `bash .claude/scripts/deploy-headless.sh` reported
      `RESULT=landed_verify_clean` after regenerating `.claude/` from the edited source store;
      `.claude/` is gitignored so `git status --short .claude/` shows zero tracked changes,
      confirming nothing was hand-authored there)*

**Timing**: 2 hours

**Depends on**: 2, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that three Comparator fixtures (`simple_match`,
`statement_weakened`, `def_hole_axiom_issue`) exist and are reusable for A2/A3, and that the two
named orchestrate test scripts are the right homes for the new regression cases. Confirm by
listing `agent-system/extensions/lean/scripts/tests/fixtures/comparator/` and reading each test
script's existing case structure before writing new cases. If a fixture does not support the
scenario as assumed, report that rather than inventing a new fixture inside this phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - conditional
  `compare_flag` emission case
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - `--compare`
  forwarding case
- `specs/155_thread_compare_flag_through_lean_implementation/summaries/01_compare-flag-lean-threading-summary.md` -
  implementation summary including the Promotion Criteria section

**Verification**:
- All five ACCEPTANCE bullets have a named, reproducible check with recorded evidence.
- A3 in particular: status after the rejection run is a completion status, not `partial`.
- New and existing test scripts pass.
- The deploy/validation gate passes over every modified source-store file.
- No file under `.claude/**` was hand-authored (confirm with a diff of that tree, which should
  show only regeneration, if anything).

---

## Testing & Validation

- [x] `bash -n` clean on every modified `.sh` file. *(completed)*
- [x] `COMPARE_FLAG` round-trips through `parse-command-args.sh` for `--compare`, `--compare
      --hard`, and the no-flag case. *(completed)*
- [x] A dispatch file built without `--compare` is byte-identical to the pre-change output.
      *(completed)*
- [x] A dispatch file built with `--compare` differs by exactly one line. *(completed)*
- [x] Every `comparator` field written by an agent is documented in `return-metadata-file.md`.
      *(completed)*
- [x] Every verdict value producible by either agent appears in one of the two documented
      vocabularies. *(completed)*
- [x] Neither skill's new stage assigns `status`. *(completed)*
- [x] Neither agent's "On verification failure" enumeration gained a comparator condition.
      *(completed)*
- [x] `test-lean-comparator-run.sh` passes unchanged. *(completed)*
- [x] New regression cases in the two orchestrate test scripts pass. *(completed)*
- [x] All five ACCEPTANCE criteria demonstrated with recorded evidence, A3 foremost. *(completed)*

## Artifacts & Outputs

- `COMPARE_FLAG` in `agent-system/extensions/core/scripts/parse-command-args.sh`
- `--compare` rows/cases in `commands/orchestrate.md`, `orchestrate-cycle-plan.sh`,
  `orchestrate-build-dispatch.sh`, and `skills/skill-orchestrate/SKILL.md`
- `### comparator (optional)` section in `core/context/formats/return-metadata-file.md`
- Gated Comparator step in `lean-implementation-agent.md` and `lean-implementation-hard-agent.md`
- `compare_flag` in both Lean implementation skills' delegation contexts, plus a comparator
  verdict-surfacing postflight stage in each
- New regression cases in `test-orchestrate-build-dispatch.sh` and `test-orchestrate-cycle-plan.sh`
- Implementation summary at
  `specs/155_thread_compare_flag_through_lean_implementation/summaries/01_compare-flag-lean-threading-summary.md`,
  including the Promotion Criteria section

## Rollback/Contingency

Every change is additive and gated behind a flag that defaults to `false`, so the rollback story
is strong by construction: reverting any single phase's commits restores prior behavior exactly,
and leaving the flag unset already restores it at runtime.

- If Phase 2's orchestrate plumbing proves more invasive than the Scope Hypothesis anticipates
  (for example, the implement dispatch sites are not cleanly separable from research/plan sites),
  stop and report rather than widening the edit. Phases 1, 3, 4, and 5 still deliver a coherent
  spine reachable by any caller that sets `compare_flag` in a delegation context directly; the
  `/orchestrate` surface can then be finished as a follow-up.
- If the Comparator toolchain cannot be exercised at all on this host, A2 and A3 fall back to
  fixture-level demonstration through `lean-comparator-run.sh`'s own test harness plus a
  traced-by-inspection walk of the agent step; A5 (`comparator_unavailable`) is then the
  primary live evidence. Record explicitly which acceptance bullets were demonstrated live and
  which by inspection — do not report an inspected bullet as a live one.
- If the concurrent lean artifact-skeletons edits conflict in `lean-implementation-agent.md`,
  re-read and re-apply Phase 4's step against the current file rather than resolving a merge
  mechanically; the step's placement (after plan compliance, gate line first) is what matters,
  not its byte offset.
