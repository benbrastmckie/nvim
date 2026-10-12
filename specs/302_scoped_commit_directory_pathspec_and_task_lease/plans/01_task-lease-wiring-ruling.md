# Implementation Plan: Task #302

- **Task**: 302 - Scoped commit directory pathspec and task lease
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/302_scoped_commit_directory_pathspec_and_task_lease/reports/01_task-lease-wiring-and-carveout-ruling.md
- **Artifacts**: plans/01_task-lease-wiring-ruling.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`git-commit-scoped.sh`'s contended-path lease (`--task <N>`) is implemented, tested, and
fail-open, but it is passed by no recipe site at all — only by the orchestrator scripts and one
memory skill. This plan wires it at the recipe sites where a single owning task number exists,
records at the sites where no such number exists why the flag is inapplicable rather than merely
unused, records the ruling that the sanctioned task-scoped directory pathspec carve-out stays
as-is, and closes by proving a recipe-level refusal (exit 3) live rather than asserting the
wiring from the text. Half 1 of this task (directory pathspec to explicit file list) is complete
and is not re-audited or re-litigated anywhere below. Done when the eight single-task sites carry
`--task`, the five inapplicable sites carry a stated reason, `git-staging-scope.md` carries the
carve-out ruling with the task-lock finding that settles it, a recipe-level invocation has been
observed refusing with exit 3 and nothing staged, and the full gate set passes on a redeployed
tree.

### Research Integration

- **The per-site ruling is settled by the research phase and is not re-derived here.** Its
  mechanical rule is adopted verbatim: wherever `--honest-index-rows {N}` is already present and
  keyed to one concrete task number, `--task` on that identical number is the symmetric
  addition; wherever `--honest-index-rows` is already documented as inapplicable because no
  single task number governs the commit, `--task` inherits the identical inapplicability.
- **Site inventory re-derived at plan time rather than carried.** Every site named below was
  re-grepped and read in context; the invocation forms and the presence/absence of
  `--honest-index-rows` at each were confirmed against the current source store, not copied from
  the report. One correction resulted: the report's table enumerates 12 sites, but
  `skills/skill-git-workflow/SKILL.md` carries a **13th** invocation at line 84, inside the
  Execution Flow pseudo-code block, whose own step 1 already receives
  `task_number (if applicable)`. Phase 2 rules on it explicitly.
- **Carve-out ruling adopted, with one argument added that the report did not have.** The
  "leave as-is" verdict stands on the report's grounds (own-territory confinement,
  exclude-injection of the ephemeral candidate set, the per-task `task-lock.sh` dispatch lock,
  and the 36-site rename-pairing conversion cost). Added at plan time from
  `lint-directory-pathspec-boundary.sh`'s own header: V5 compares pathspec tokens against
  contention-manifest entries by **exact string equality**, so a directory token can never match
  a file-path manifest entry and bypasses the lease by construction. That is an argument *for*
  narrowing, and Phase 3 requires the recorded ruling to state it and answer it rather than omit
  it.
- **Verification ordering confirmed, not assumed.** `git-commit-scoped.sh`'s V5 contended-path
  block sits at line ~325, ahead of both the `git add` (~565) and the `--honest-index-rows`
  addendum (~640), so a recipe's full argv — `--honest-index-rows` included — refuses at exit 3
  before either runs. Phase 4's probe can therefore use the recipe's exact argv.
- **`skill-meta/SKILL.md`'s `tasks_created > 1` identity ambiguity is pre-existing**, inherited
  rather than introduced by adding `--task {N}`, and is recorded as a follow-up in Phase 5, not
  resolved here.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag is set; no roadmap
consultation was performed.

## Goals & Non-Goals

**Goals**:
- Pass `--task {N}` at every commit-staging recipe site governed by a single, concrete task
  number, so the contended-path lease is actually consulted there.
- At every site where no single task number governs the commit, state the reason `--task` does
  not apply, mirroring the `--honest-index-rows`-omission prose those sites already carry — so
  the omission reads as a decision, not an oversight.
- Rule explicitly on the 13th site found at plan time (`skill-git-workflow/SKILL.md`'s Execution
  Flow step 3), rather than leaving it unaddressed because the research table predates it.
- Record in `context/standards/git-staging-scope.md` the ruling that the sanctioned task-scoped
  directory carve-out stays as-is, argued from exclude-injection behavior, the per-task dispatch
  lock, and the rename-pairing conversion cost — and answering the exact-string-match argument
  against it.
- Add the missing cross-reference from `git-staging-scope.md`'s Concurrency Qualifier section to
  `context/patterns/task-lock.md`'s per-task lock, so a future reader evaluating a same-task
  staging question does not re-discover it by search.
- Demonstrate a recipe-level refusal live: one edited site's exact invocation refusing with
  exit 3, nothing staged, the holding task named.

**Non-Goals**:
- No re-audit of Half 1's pathspec shapes and no re-litigation of its per-site rulings,
  including `commands/todo.md`'s `stage_paths` accumulator ruling.
- No change to `agent-system/extensions/core/scripts/git-commit-scoped.sh` — an
  orchestrator-adjacent primitive this task deliberately does not touch. Any ruling that would
  require changing it is recorded as a follow-up instead.
- No widening of `file_scope` to any orchestrator-critical path
  (`context/reference/orchestrator-critical-paths.json`), and none to
  `scripts/tests/test-git-commit-scoped.sh` — the permanent regression case belongs to a
  follow-up (Phase 5), and the in-dispatch demonstration runs in a scratch repo instead.
- No narrowing of the ~36 sanctioned task-scoped-directory sites in `founder/`, `lean/`,
  `present/`, `epidemiology/`, `web/`, and `core/skill-reviser` — that is the ruling's own
  outcome, not deferred work.
- No wiring of `lint-directory-pathspec-boundary.sh` as a `verify-deploy.sh` gate (its natural
  wiring point is itself a critical path; already recorded as a separate task's work).
- No redesign of `skill-meta/SKILL.md`'s single-task message template to branch on
  `tasks_created`.
- No edit under `.claude/**`; that tree is a disposable deploy artifact regenerated in Phase 5.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A sibling dispatch edits a shared file on this same working tree mid-phase | M | M | Task 347 is live this cycle with a declared `file_scope` of four `core/hooks`/`core/scripts`/`core/merge-sources` files — no overlap with this task's ten. Still: re-read every target file immediately before editing, stage only this task's own explicit file list, never a directory or glob, and never `git-snapshot.sh` in its reverting default mode. |
| The recipe-level probe refuses for a reason other than V5 (a precondition inside `--honest-index-rows`, a missing scratch script, an untracked-path refusal at exit 2) and is mistaken for a successful demonstration | H | M | Phase 4 asserts the exit code is exactly 3, that the stderr names the holding task number verbatim, and that `git diff --cached` is empty — three independent signals. A non-3 exit is recorded as a finding and isolated, never reported as a pass. |
| The probe is run against the live repository rather than a scratch root, claiming or committing real paths | H | L | Phase 4 builds an isolated `mktemp -d` root mirroring `test-git-commit-scoped.sh`'s own `build_repo covered` shape and never invokes the script with the live repo as `PROJECT_ROOT`; the phase's final task asserts the live tree is unchanged. |
| The carve-out ruling is recorded as an assertion rather than an argument, which the task description explicitly forbids | M | M | Phase 3's task list enumerates the four supporting arguments and the one counter-argument by name, and its verification greps the recorded text for each. |
| Adding `--task {N}` to a template that can fire after a multi-task batch (`skill-meta/SKILL.md`) attributes a lease claim to the wrong task number | M | L | Pre-existing ambiguity, not introduced here; the agent's own Stage 6 batch commit normally lands first, leaving this postflight commit nothing to stage. Recorded as a Phase 5 follow-up with the ambiguity named, rather than silently accepted. |
| An edit lands a task-number reference or record-versioning language into an `agent-system/**` file | M | M | Every editing phase carries an explicit check, and Phase 5's gate 4 (`check-task-references.sh`) plus gate 3 doc-lint are run as part of the full set. |
| A future auditor re-opens the carve-out question because the ruling lives only in this plan | M | M | Phase 3 writes it into `git-staging-scope.md` itself, at the paragraph that already discusses this lint and this carve-out. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4 | 1 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel. Phases 1 and 3 touch disjoint files (seven
recipe files vs. one standards document). Phase 2 depends on Phase 1 only because both edit
`skills/skill-git-workflow/SKILL.md`; Phase 4 depends on Phase 1 because it exercises one of
Phase 1's own edited invocations.

**Source-store discipline (applies to every phase)**: every edit target below is under
`agent-system/extensions/**`. Never hand-author under `.claude/**` — that tree is regenerated by
Phase 5's `deploy-headless.sh` run, per `.claude/rules/source-store-deploy-boundary.md`. No file
landing under `agent-system/**` may contain a task-number reference or record-versioning
language ("no longer", "previously", "supersedes").

---

### Phase 1: Wire `--task {N}` at the eight single-task recipe sites [COMPLETED]

**Goal**: Every commit-staging recipe governed by one concrete task number passes that number to
`git-commit-scoped.sh --task`, so the contended-path lease is consulted before anything is
staged.

**Tasks**:
- [x] Re-read each target file immediately before editing it (a sibling dispatch is live on this
      tree this cycle). *(completed)*
- [x] `skills/skill-git-workflow/SKILL.md`, "Task Commit" template (line ~206): insert
      `--task {N} \` alongside the existing `--honest-index-rows {N} \`, on the same number. This
      is the documentation-front template other recipes copy, so it is edited first. *(completed)*
- [x] `commands/task.md` Step 7 (line ~245): add `--task {N}` beside `--honest-index-rows {N}`. *(completed)*
- [x] `skills/skill-meta/SKILL.md` postflight commit (line ~327): add `--task {N}` beside
      `--honest-index-rows {N}`. Leave the message template and the `GLOBAL_ROOT`/`target_root`
      prose untouched; the `tasks_created > 1` ambiguity is Phase 5's follow-up, not an edit
      here. *(completed)*
- [x] `epidemiology/commands/epi.md` Step 5 (line ~322): add `--task {N}`. *(completed)*
- [x] `present/commands/grant.md` Step 8 (line ~219): add `--task {N}`. *(completed)*
- [x] `present/commands/grant.md` CHECKPOINT 2 revision commit (line ~475): add
      `--task {NEW_N}` — the revision task's own number, matching that site's existing
      `--honest-index-rows {NEW_N}`, never the parent grant's `{N}`. *(completed)*
- [x] `present/commands/slides.md` Step 5 (line ~319): add `--task {N}`. *(completed)*
- [x] `present/commands/timeline.md` Step 8 (line ~223): add `--task {N}`. *(completed)*
- [x] In each of the four extension command files and `commands/task.md`, preserve the exact
      surrounding indentation of the fenced block (two of them are indented inside a numbered
      list item) and the existing line-continuation backslashes. *(completed: verified via `git diff`, each site shows only the added line)*
- [x] Confirm no edit introduced a task-number reference or record-versioning language into any
      `agent-system/**` file. *(completed: check-task-references.sh --quiet exits 0)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/lint/lint-directory-pathspec-boundary.sh --verbose`
and `bash .claude/scripts/lint/lint-scoped-commit-boundary.sh --verbose`, both checked by exit
status, are the complete covering check for this phase — they are the two mechanical readers of
these invocation lines, and `suite_selection_select` returns `__FULL_SWEEP__` for every one of
these markdown paths (verified at plan time), so no test suite covers them and none is claimed.

**Scope Hypothesis**: eight single-task invocation sites across seven files are asserted here,
each already carrying `--honest-index-rows` on a concrete number — re-derived at plan time by
grepping `git-commit-scoped.sh` across all ten declared files and reading every match in
context, rather than carried from the research report's table. Confirm at implementation time
with `grep -rn -- "--honest-index-rows" agent-system/extensions/{core,epidemiology,present}` and
`grep -rn "git-commit-scoped.sh" <the ten declared files>`; if a ninth single-task site exists,
rule on it by the same mechanical rule rather than skipping it, and if one of the eight has
drifted (flag removed, number renamed), re-rule that site rather than forcing the edit.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md` - "Task Commit" template gains `--task {N}`
- `agent-system/extensions/core/commands/task.md` - Step 7 commit gains `--task {N}`
- `agent-system/extensions/core/skills/skill-meta/SKILL.md` - postflight commit gains `--task {N}`
- `agent-system/extensions/epidemiology/commands/epi.md` - Step 5 commit gains `--task {N}`
- `agent-system/extensions/present/commands/grant.md` - Step 8 commit gains `--task {N}`; CHECKPOINT 2 revision commit gains `--task {NEW_N}`
- `agent-system/extensions/present/commands/slides.md` - Step 5 commit gains `--task {N}`
- `agent-system/extensions/present/commands/timeline.md` - Step 8 commit gains `--task {N}`

**Verification**:
- `bash .claude/scripts/lint/lint-directory-pathspec-boundary.sh --verbose` exits 0.
- `bash .claude/scripts/lint/lint-scoped-commit-boundary.sh --verbose` exits 0.
- `grep -rn -- "--task {N}\|--task {NEW_N}" agent-system/extensions/{core,epidemiology,present}`
  returns exactly the eight new sites (plus any pre-existing `--task` text), and each hit sits in
  the same fenced block as an `--honest-index-rows` line carrying the identical number.
- For each of the seven files, `git diff -- <file>` shows only added `--task` lines — no
  reflowed continuation, no changed pathspec, no changed message template.
- `bash .claude/scripts/check-task-references.sh --quiet` exits 0.

---

### Phase 2: Record why `--task` is inapplicable at the five remaining sites [COMPLETED]

**Goal**: Every commit-staging site in the declared file set that does *not* gain `--task`
carries a stated reason for the omission, and the Execution Flow pseudo-code that other recipes
read as a model names the flag conditionally rather than not at all.

**Tasks**:
- [x] Re-read each target file immediately before editing it. *(completed)*
- [x] `commands/todo.md` Step 6, archival commit (the paragraph at lines ~746-754 that already
      explains the `--honest-index-rows` omission): extend that same paragraph to state that
      `--task` is inapplicable for the identical reason — `stage_paths` spans an arbitrary number
      of archived tasks' paths in one commit, so there is no single owning task number for the
      lease to key on. Do not touch the four invocation lines or the `stage_paths` accumulator. *(completed)*
- [x] `commands/todo.md` Step 6.5.3, metrics-sync commit (the sentence at lines ~819-820 that
      already explains its `--honest-index-rows` omission): extend it to state that `--task` is
      inapplicable because this commit touches nothing task-scoped at all — it stages only
      `specs/state.json` for a repo-wide metrics field. *(completed)*
- [x] `agents/meta-builder-agent.md` Stage 6 (the `--honest-index-rows`-omission sentences at
      lines ~958-962): extend them to cover `--task` by the same reasoning — this commit creates
      N tasks in one call and has no single owning task number, including in the N=1 case, which
      runs through the same batch code path with no per-task branch. Keep the existing note about
      skill-meta's later postflight commit intact. *(completed)*
- [x] `skills/skill-git-workflow/SKILL.md`, "Standard Commit" template (line ~206 block, above
      the Task Commit block): add one line of prose stating that this form is for operations with
      no governing task number (`sync:`, `review:`, and similar), so neither
      `--honest-index-rows` nor `--task` applies — and that the Task Commit form below is the one
      to copy when a task number does govern. *(completed)*
- [x] `skills/skill-git-workflow/SKILL.md`, Execution Flow step 3 (line ~84): rule on the 13th
      site. Its own step 1 already receives `task_number (if applicable)`, so make that
      conditionality explicit in the invocation line — pass `--task` when a task number governs
      the request and omit it when none does — keeping the pseudo-code's existing `{scope}` and
      `--message`/`--session` shape. Do not convert the pseudo-code into a second copy of the
      Task Commit template. *(completed)*
- [x] Confirm every added sentence states a *reason*, not merely the fact of omission, and that
      none of them cites a task number or uses record-versioning language. *(completed: check-task-references.sh --quiet exits 0; each added sentence read back and confirmed to state a reason)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/lint/lint-scoped-commit-boundary.sh --verbose` and
`bash .claude/scripts/lint/lint-directory-pathspec-boundary.sh --verbose`, both checked by exit
status, cover this phase's one invocation-line edit (Execution Flow step 3) and confirm the four
prose additions disturbed no staging form; the markdown paths map to `__FULL_SWEEP__` under
`suite_selection_select`, so no suite covers them and none is claimed.

**Scope Hypothesis**: five inapplicable sites are asserted — two in `commands/todo.md`, one in
`agents/meta-builder-agent.md`, and two in `skills/skill-git-workflow/SKILL.md` (the generic
Standard Commit template and the Execution Flow pseudo-code). This is one more than the research
report's four, because the Execution Flow site at line 84 was found at plan time by re-grepping
the declared files. Confirm at implementation time with
`grep -n "git-commit-scoped.sh" agent-system/extensions/core/skills/skill-git-workflow/SKILL.md
agent-system/extensions/core/commands/todo.md
agent-system/extensions/core/agents/meta-builder-agent.md`; the expected hit set is 3 in
`skill-git-workflow/SKILL.md` (lines ~84, ~206, ~214), 7 in `commands/todo.md`, and 2 in
`meta-builder-agent.md` (one prose reference, one invocation). A different count means re-rule
the surplus rather than leaving it unaddressed.

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - Step 6 and Step 6.5.3 omission paragraphs extended to cover `--task`
- `agent-system/extensions/core/agents/meta-builder-agent.md` - Stage 6 omission note extended to cover `--task`
- `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md` - Standard Commit template gains an inapplicability note; Execution Flow step 3 names `--task` conditionally

**Verification**:
- `bash .claude/scripts/lint/lint-scoped-commit-boundary.sh --verbose` exits 0.
- `bash .claude/scripts/lint/lint-directory-pathspec-boundary.sh --verbose` exits 0.
- `grep -n -- "--task" agent-system/extensions/core/commands/todo.md
  agent-system/extensions/core/agents/meta-builder-agent.md` each return at least one hit, and
  each hit is inside a sentence that also states the reason (spans many tasks / nothing
  task-scoped / N tasks in one call).
- `git diff -- agent-system/extensions/core/commands/todo.md` shows no change to any of the four
  Step 6 invocation lines, the Step 6.5.3 invocation line, or the `stage_paths` accumulator.
- `bash .claude/scripts/check-task-references.sh --quiet` exits 0.

---

### Phase 3: Record the carve-out ruling and the task-lock cross-reference [NOT STARTED]

**Goal**: `context/standards/git-staging-scope.md` carries the ruling that the sanctioned
task-scoped directory pathspec carve-out stays as-is — argued, with the counter-argument
answered — and its Concurrency Qualifier section points at the per-task dispatch lock that
settles same-task hazards.

**Tasks**:
- [ ] Re-read `context/standards/git-staging-scope.md` immediately before editing.
- [ ] In the References entry for `lint-directory-pathspec-boundary.sh` (the paragraph at lines
      ~665-673 that already describes the carve-out and its unwired-gate status), add the ruling:
      the task-scoped directory form stays as-is and is deliberately not narrowed to explicit
      file lists. State all four supporting arguments by name: (a) the over-stage is confined to
      one task's own directory, so the cross-session bleed that motivated the explicit-file-list
      rule does not apply; (b) `git-commit-scoped.sh` already injects `:(exclude)` entries for
      the canonical ephemeral-runtime-file candidate set for exactly these directories, so the
      known-risky content is already carved out; (c) the per-task-number lock in
      `context/patterns/task-lock.md`, acquired at the shared command preflight gate, prevents
      two dispatches against the same task number from running concurrently, which is the
      scenario a concurrent in-place artifact write would require; (d) conversion would touch
      roughly three dozen live call sites across the extension tree, each needing the
      both-endpoints audit the "Rename and Directory-Move Staging" section mandates — the
      demonstrated-costly mistake.
- [ ] In the same addition, state and answer the counter-argument rather than omitting it: the V5
      contended-path check compares pathspec tokens against contention-manifest entries by exact
      string equality, so a directory token cannot match a file-path manifest entry and the lease
      is inert at these sites by construction. Answer it on the record: the manifest is populated
      only from cycle-dispatched tasks' declared `file_scope`, whose entries are source-tree
      paths rather than another task's own artifact directory, so the bypassed check has nothing
      to match at these sites in practice — and where a shared `specs/` index file *is* contended,
      it is staged by its own explicit path, not by the directory token.
- [ ] In the "Concurrency Qualifier: Targeted Staging Is Necessary But Not Sufficient" section
      (lines ~190-215), add one short paragraph distinguishing the two hazards and pointing at
      `context/patterns/task-lock.md`: that section's remedies (the contended-path lease,
      per-dispatch working-tree isolation) address the *cross-task* shared-file hazard, while the
      per-task-number lock addresses the *same-task* concurrent-write hazard — a different
      question a reader evaluating a same-task staging scope will otherwise re-derive by search.
- [ ] Keep the existing "**Not yet** wired as a `verify-deploy.sh` gate" statement and its
      reasoning intact; the ruling is added beside it, not in place of it.
- [ ] Confirm the addition cites durable anchors only — filenames and section headings — and no
      task number, and that it contains no record-versioning language.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc-lint and
task-reference lint), checked by exit status, together with a diff read-through confirming every
hunk is narrative prose inside an existing paragraph or References entry, is the complete covering
check — this file has no executable surface and `suite_selection_select` returns `__FULL_SWEEP__`
for it, so no suite covers it and none is claimed.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - carve-out ruling with its four supporting arguments and the exact-string-match counter-argument answered, added at the `lint-directory-pathspec-boundary.sh` References entry; Concurrency Qualifier section gains a cross-reference to the per-task lock

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` exits 0.
- The recorded ruling text greps positively for each of the five named arguments: an
  own-territory-confinement phrase, `:(exclude)`, `task-lock`, a rename/both-endpoints
  reference, and an exact-string-equality phrase. A missing one means the ruling was asserted
  rather than argued — fix before closing the phase.
- `grep -n "task-lock" agent-system/extensions/core/context/standards/git-staging-scope.md`
  returns a hit inside the Concurrency Qualifier section, not only in the References list.
- `grep -n "Not yet" agent-system/extensions/core/context/standards/git-staging-scope.md` still
  returns the unwired-gate statement.
- `bash .claude/scripts/check-task-references.sh --quiet` exits 0.

---

### Phase 4: Prove a recipe-level refusal live (exit 3) [NOT STARTED]

**Goal**: One of Phase 1's own edited invocations, run verbatim, refuses with exit 3 on a path
held by another live task — nothing staged, HEAD unmoved, the holder named — so the wiring is
proven live rather than merely present in the text.

**Tasks**:
- [ ] Build an isolated scratch root under the session scratchpad, mirroring
      `scripts/tests/test-git-commit-scoped.sh`'s `build_repo covered` shape (lines ~67-104):
      `mktemp -d`; `git init` with a local `user.email`/`user.name`; `mkdir -p
      <scratch>/.claude/scripts/lib`; copy `git-commit-scoped.sh`, `deploy-root-guard.sh`,
      `task-lock.sh`, `lib/common.sh`, and `lib/task-lookup-lib.sh` from `.claude/scripts/` into
      it (`chmod +x` all but the two `lib/` files); write the four-line ephemeral `.gitignore`
      that fixture uses.
- [ ] Populate the paths the chosen recipe stages: create and commit `specs/TODO.md` and
      `specs/state.json` (a minimal `{"active_projects":[]}` is enough — this probe never reaches
      the `--honest-index-rows` addendum), then modify both so there is something to stage.
- [ ] Write the contention manifest exactly as the suite's `write_manifest` helper does:
      `<scratch>/specs/.contention-manifest/<session>.json` containing
      `{"session_id":...,"cycle":1,"generated_at":...,"contended":[{"path":"specs/state.json","tasks":[<A>,<B>],"granularity":"file"}]}`
      with two synthetic task numbers.
- [ ] Pre-claim the contended path under task A:
      `(cd <scratch> && bash .claude/scripts/task-lock.sh claim-acquire "specs/state.json" <A> <other_session>)`.
- [ ] Run the **exact argv from `commands/task.md` Step 7 as edited in Phase 1** — message,
      `--session <session>`, `--honest-index-rows <B>`, `--task <B>`,
      `-- specs/TODO.md specs/state.json` — from inside the scratch root, with the session id the
      manifest was built under. Capture stdout+stderr and the exit code.
- [ ] Assert all four signals: exit code is exactly 3; `git -C <scratch> diff --cached` is empty;
      `git -C <scratch> rev-list --count HEAD` is unchanged; the captured stderr names the
      holding task number verbatim. Record the captured refusal line in the implementation
      summary as the evidence.
- [ ] Run the positive control in the same scratch root: repeat with `--task` **omitted** and
      confirm the commit proceeds (exit 0, HEAD advances by 1) — proving the refusal came from
      the lease being consulted, not from an unrelated precondition.
- [ ] If the first run exits anything other than 3, record it as a finding
      (`bash .claude/scripts/issue-record.sh ... --kind issue`) and isolate the cause before
      re-asserting; never report a non-3 exit as a demonstration.
- [ ] Release the synthetic claim, remove the scratch root, and confirm the live tree is
      untouched: `git status --porcelain -- specs/.contention-manifest/ specs/.contention-claims/`
      returns empty.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: the probe's own four assertions plus its `--task`-omitted positive
control are the complete covering check for this phase — it adds no repository file, so the only
behavior at issue is the one invocation's exit status and staging state, which the probe measures
directly; `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`
is run alongside it to confirm the untouched primitive's own V1-V8 contention block is still
green.

**Scope Hypothesis**: the probe is asserted to reach V5 and exit 3 even though the recipe's argv
also carries `--honest-index-rows`, on the plan-time reading that `git-commit-scoped.sh`'s V5
block (line ~325) precedes both the `git add` (~565) and the `--honest-index-rows` addendum
(~640). Confirm by re-reading those three line regions in the current script before building the
probe; if the ordering has changed, run the probe without `--honest-index-rows` as well and
report both results rather than treating a non-3 exit as a wiring failure.

**Files to modify**:
- none planned - this phase builds a throwaway scratch root under the session scratchpad and adds no repository file

**Verification**:
- The recipe-level run exits exactly 3, with `git diff --cached` empty, `rev-list --count HEAD`
  unchanged, and the holding task number present in stderr — all four observed in this dispatch,
  not inferred.
- The `--task`-omitted control run on the same scratch fixture exits 0 and advances HEAD by 1.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`
  reports all cases passing.
- `git status --porcelain -- specs/.contention-manifest/ specs/.contention-claims/` is empty
  after cleanup, and the scratch root no longer exists.

---

### Phase 5: Deploy, run the full gate set, and record the follow-ups [NOT STARTED]

**Goal**: The deployed tree carries every edit, the complete gate set is observed green (or every
failure is enumerated, reproduced, and attributed), and each deliberately-deferred item is
recorded where a future dispatch will find it.

**Tasks**:
- [ ] Deploy the source-store changes: `bash .claude/scripts/deploy-headless.sh`. Record the
      reported result verbatim.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` — all gates, not a
      subset. This is the final phase, and the task's cross-cutting surface (nine recipe/contract
      documents across three extensions, plus a redeployed tree) is in scope.
- [ ] Run both staging lints once more against the deployed tree, by their sanctioned entry
      points and checking exit status:
      `bash .claude/scripts/lint/lint-directory-pathspec-boundary.sh --verbose` and
      `bash .claude/scripts/lint/lint-scoped-commit-boundary.sh --verbose`.
- [ ] For any gate failure, reproduce it standalone and determine whether it lies inside this
      task's ten declared files. A failure outside them is enumerated as a reasoned exclusion
      with its reproduction evidence, never waved off; a failure inside them is fixed before the
      phase closes.
- [ ] Record the follow-ups, each with its own `issue-record.sh` entry and
      `--suggested-channel follow_up_task`: (a) a permanent regression case in
      `scripts/tests/test-git-commit-scoped.sh`, parameterized by a recipe's own invocation form,
      replacing this task's throwaway probe — deliberately not landed here to keep `file_scope`
      off the primitive's own test surface; (b) `skill-meta/SKILL.md`'s `tasks_created > 1`
      identity ambiguity, which `--task {N}` inherits and does not resolve; (c) any change to
      `git-commit-scoped.sh` that surfaced as desirable while ruling, which this task is barred
      from making.
- [ ] Confirm the final tree carries no task-number reference or record-versioning language under
      `agent-system/**` that this task introduced (`bash .claude/scripts/check-task-references.sh
      --quiet`, plus a `git diff` read-through of the nine edited files).

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- none planned - this phase deploys and verifies; `.claude/**` is regenerated by `deploy-headless.sh`, never hand-edited

**Verification**:
- `bash .claude/scripts/deploy-headless.sh` completes and its reported result is recorded.
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set (gates 0-22, including
  gate 3 doc-lint, gate 4 task-reference lint, gate 5 manifest parity, gate 8's full
  `tests/run-all.sh` battery, gate 17 scoped-commit boundary lint, and gate 22 shellcheck),
  observed green in this dispatch, never trusted on sight. Any non-zero exit is decomposed into
  per-gate findings, each either fixed (inside the ten declared files) or recorded as a reasoned
  exclusion with reproduction evidence (outside them).
- `bash .claude/scripts/lint/lint-directory-pathspec-boundary.sh --verbose` and
  `bash .claude/scripts/lint/lint-scoped-commit-boundary.sh --verbose` both exit 0 against the
  deployed tree.
- Each of the three follow-ups has an `issues.jsonl` entry with a returned entry id.
- `bash .claude/scripts/check-task-references.sh --quiet` exits 0.

## Testing & Validation

- [ ] Both staging lints exit 0 after every editing phase and again against the deployed tree.
- [ ] The eight `--task` additions each sit beside an `--honest-index-rows` line carrying the
      identical number, with no other change to their invocation.
- [ ] The five inapplicable sites each state a reason for the omission, not merely the omission.
- [ ] The carve-out ruling in `git-staging-scope.md` greps positively for all four supporting
      arguments and for the answered exact-string-match counter-argument.
- [ ] A recipe-level invocation is observed refusing with exit 3, nothing staged, HEAD unmoved,
      holder named — with a `--task`-omitted positive control proving the lease caused it.
- [ ] `test-git-commit-scoped.sh` passes, confirming the untouched primitive is unregressed.
- [ ] `verify-deploy.sh` full gate set observed, with every failure either fixed or enumerated as
      a reasoned exclusion with reproduction evidence.
- [ ] `check-task-references.sh` exits 0; no record-versioning language introduced under
      `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md` — Task Commit template wired;
  Standard Commit and Execution Flow sites ruled and documented
- `agent-system/extensions/core/commands/task.md` — Step 7 wired
- `agent-system/extensions/core/skills/skill-meta/SKILL.md` — postflight commit wired
- `agent-system/extensions/epidemiology/commands/epi.md`,
  `agent-system/extensions/present/commands/grant.md` (two sites),
  `agent-system/extensions/present/commands/slides.md`,
  `agent-system/extensions/present/commands/timeline.md` — wired
- `agent-system/extensions/core/commands/todo.md`,
  `agent-system/extensions/core/agents/meta-builder-agent.md` — inapplicability recorded with
  reasons
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — carve-out ruling and
  task-lock cross-reference
- Captured probe transcript (exit 3 refusal line and the positive control) quoted in the
  implementation summary
- `specs/302_scoped_commit_directory_pathspec_and_task_lease/issues.jsonl` — three follow-up
  entries
- `specs/302_scoped_commit_directory_pathspec_and_task_lease/summaries/01_*-summary.md`

## Rollback/Contingency

Every change is an additive edit to nine markdown files under `agent-system/extensions/**`; no
script, schema, or state file is modified, and the probe writes nothing into the repository.

- **Per-file revert**: `git checkout <commit>~1 -- <file>` for the one file at issue, or
  `git revert <phase commit>` for a whole phase — each phase commits its own explicit file list,
  so reverting one phase never disturbs another.
- **Deployed tree**: re-run `bash .claude/scripts/deploy-headless.sh` after any revert; never
  hand-edit `.claude/**` to undo a change.
- **If the Phase 4 probe cannot be made to refuse**: the eight wiring edits stand on their own
  (the flag is fail-open and inert where nothing is contended) — report the demonstration as
  unachieved with the captured evidence and leave the edits in place rather than reverting them;
  that is a reporting outcome, not a rollback trigger.
- **If a rollback of uncommitted work is genuinely needed**: take a snapshot first per
  `context/contracts/recovery.md`'s rollback rung (never a bare precautionary
  `git-snapshot.sh` in its reverting default mode) and only then run the destructive command.
