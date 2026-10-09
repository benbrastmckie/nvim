# Research Report: Caller-Side Phase-Commit Completeness Check

**Task**: 375 - Caller-side phase-commit completeness check
**Started**: 2026-10-09T08:55:16Z
**Completed**: 2026-10-09T09:40:00Z
**Effort**: Medium (4 scope items, one cross-repo)
**Dependencies**: None (sibling task's script-side work, concurrent, already landed and verified below)
**Sources/Inputs**:
- `~/.claude/projects/-home-benjamin-Projects-Logos-Verification/95371aec-e4b8-4b00-8973-dc67fe59acd6/subagents/agent-a6a393c380d25ea8b.jsonl` (primary transcript, re-read directly)
- `~/Projects/Logos/Verification` git history (`fc9f786e`, `96986be6`) and `specs/224_.../issues.jsonl`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/context/standards/git-staging-scope.md`
- `agent-system/extensions/core/context/checkpoints/checkpoint-commit.md`
- `agent-system/extensions/core/context/contracts/phase-closure.md`
- `agent-system/extensions/core/scripts/git-commit-scoped.sh`, `update-phase-status.sh`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Confirmed by direct re-read of the primary transcript** (not just the dispatch's framing):
  the `fc9f786e` commit's `stage_paths` array named exactly 9 `components/*.typ` files and never
  named `zigzag.typ`, and the commit's actual diff (`git show --stat`) carries exactly those same
  9 files. Two durable records in the Verification repo — the follow-up commit message
  `96986be6` and `issues.jsonl` entry `iss_1791495993077_nD5IuJ` — both assert zigzag.typ *was*
  listed and dropped by the script. Both are now machine-contradicted; see `claim_invalidations`.
- **Root cause located precisely**: `general-implementation-agent.md`'s Phase Checkpoint
  Protocol (the per-phase closing-commit site) contains only a *comment* instructing the agent to
  append `files_touched` paths — no actual derivation code — unlike the sibling per-objective
  green-substep site five sections earlier, which already has a working `jq` loop. The caller in
  the incident was filling this gap by hand and dropped one path.
- **Recommended enforcement site for scope items 1+2**: a single new mechanized wrapper script
  (around `git-commit-scoped.sh`, not a change to it) that (a) derives `stage_paths` from the
  phase's progress file `files_touched` arrays instead of agent hand-typing, and (b)
  post-commit, verifies every one of those paths is clean against HEAD, failing loudly and
  naming each dirty path otherwise. This mirrors the already-proven `update-phase-status.sh`
  mechanization precedent (a prose heartbeat instruction fired 0/8 times; the mechanized
  version fires 16/16).
- **Scope item 3 (exit-code exposure)**: no documented template in this repo currently pipes
  `git-commit-scoped.sh`'s output through `tail` (the `| tail -25` in the incident was ad hoc,
  not inherited from any template) — but neither the per-objective nor per-phase templates in
  `general-implementation-agent.md` show *any* exit-code check at all, unlike
  `checkpoint-commit.md`'s step 4. Folding the commit into the new mechanized wrapper structurally
  removes the hazard (one command, no pipe) and the wrapper's own exit code becomes the thing
  callers must check.
- **Scope item 4**: the precondition is confirmed failed (per the operator note): both disproven
  causal claims in `git-commit-scoped.sh` (the `.commit-lock` fail-open WARNING, and the V8 header
  entry) are **already corrected** in the current source store (commit `b33aca69c`, verified
  below) — no further action needed there. The one outstanding correction is Verification's own
  `specs/224_.../issues.jsonl`, which still carries the uncorrected claim; a ready-to-append entry
  is drafted below.

## Context & Scope

Scope (from the dispatch, `.dispatch/16.md`):
1. Post-commit completeness check: every phase's `files_touched` path must be clean against HEAD
   after that phase's commit, or fail loudly naming each dirty path.
2. Derive the phase-commit pathspec from `files_touched` + task directory, instead of hand-typing.
3. Expose `git-commit-scoped.sh`'s real exit code to callers (no silent `| tail` truncation).
4. Append a correcting entry to Verification's `specs/224_.../issues.jsonl`, and confirm task
   374's own ruling no longer asserts the disproven cause.

Out of scope: `specs/.commit-lock` fail-closed behavior; any change to `git-commit-scoped.sh`'s
own staging semantics; widening any pathspec beyond `files_touched` + task directory.

## Findings

### F1. Primary-transcript re-verification (scope item 4 precondition)

Read directly from the `tool_use` block (`toolu_01JgkBy3RifdvaRCCs4DZDtt`,
2026-10-08T21:28:54Z) in the cited transcript:

```
stage_paths=("${task_dir}/" ".github/workflows/docs.yml" \
  "typst/manual/generated/certificate-export.json" "typst/manual/generated/certificate-export.typ" \
  "typst/manual/generated/components/channel.typ" "typst/manual/generated/components/crc8.typ" \
  "typst/manual/generated/components/receiver.typ" "typst/manual/generated/components/ring_buffer.typ" \
  "typst/manual/generated/components/seq_num.typ" "typst/manual/generated/components/stuff.typ" \
  "typst/manual/generated/components/stuffed_channel.typ" "typst/manual/generated/components/varint.typ" \
  "typst/manual/generated/components/vec_queue.typ" "typst/manual/generated/status.typ")
bash .claude/scripts/git-commit-scoped.sh ... --task "224" -- "${stage_paths[@]}" 2>&1 | tail -25
```

`zigzag.typ` is absent. `git show --stat fc9f786e` (re-run against the live Verification clone)
lists exactly the same 9 `components/*.typ` names, 15 files total, no `zigzag.typ` — the script
committed precisely what it was handed and the incident is a caller-side omission, confirmed by
both ends (input and output). `--task 224` was passed, also confirmed (contradicting task 374's
research claim that phase commits never pass `--task`). The pipe (`2>&1 | tail -25`, no
`PIPESTATUS`/`pipefail`) is also confirmed as written.

Two durable records in the Verification repo contradict this:
- Commit `96986be6`'s message: "The phase-5 git-commit-scoped.sh invocation for task 224 listed
  this path in its stage_paths but the resulting commit (fc9f786e) did not include it."
- `issues.jsonl` entry `iss_1791495993077_nD5IuJ`: "Phase 5's git-commit-scoped.sh invocation
  listed typst/manual/generated/components/zigzag.typ in its stage_paths alongside nine sibling
  ... fragments."

Both were written at wrap-up time, apparently inferring the cause from the working tree (which
*did* have zigzag.typ regenerated, per `phase-5-progress.json`'s objective 2 `files_touched`)
rather than from the actual commit command. Both are refuted by the tool_use input quoted above.

### F2. The git-staging-scope.md "Containment" passage carries the same error

`agent-system/extensions/core/context/standards/git-staging-scope.md`'s "Staging-Layer
Containment Filter" section (`## Fail-Safe Direction` subsection) cites the same `fc9f786e`
commit as its "Empirical basis," and lists:

```
typst/manual/generated/components/{channel,crc8,receiver,ring_buffer,seq_num,stuff,
stuffed_channel,varint,vec_queue,zigzag}.typ
```

as "ten generated Typst files" the commit "carried." Per F1, the commit carried only the nine
named there minus `zigzag.typ` — ten is wrong, and `zigzag.typ` was never part of it. The
passage's actual point (Containment: the task's declared `file_scope` named only `crc8.typ`;
most of the landed files were outside that declared scope) is unaffected by this count — it is a
different predicate (declared scope vs. landed files) from the drop this task researches — but
the passage should not go on quietly repeating a disproven detail. Recorded as a non-fatal issue
(`iss_` entry, severity minor) during this phase; recommended fix: change "ten" to "nine" and
drop `zigzag.typ` from the enumerated list.

### F3. Where the per-phase template is under-specified (root cause of scope item 2)

`general-implementation-agent.md` has **two** phase-commit sites:

- **4B-iii (per-objective green substep)**, line ~401-407: already derives `stage_paths`
  mechanically —
  ```bash
  while IFS= read -r f; do
    [ -n "$f" ] && stage_paths+=("$f")
  done < <(jq -r '.objectives[] | select(.id == {objective_id}) | .files_touched[]? // empty' "$progress_file" 2>/dev/null)
  ```
- **Phase Checkpoint Protocol step 5 (per-phase closing commit)**, line ~880-887: shows only
  ```bash
  stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")
  # Append every path accumulated in this phase's progress-file files_touched arrays
  # (the same paths summed into modified_files at Stage 6-modified-files)
  bash .claude/scripts/git-commit-scoped.sh ...
  ```
  — a **comment**, not code. This is the exact site the Verification incident's commit message
  matches (`task 224 phase 5: ...`), and the exact gap a hand-typed enumeration fills in by hand.

This mirrors a precedent already recorded in this codebase: `update-phase-status.sh`'s own
header documents that a prose heartbeat instruction in this same agent file fired 0/8 times in a
real incident, while mechanizing the identical step inside a script every agent must call fired
16/16. The same lesson applies here: a prose comment telling the agent to derive a list is not
a derivation.

### F4. No documented template pipes through `tail` (scope item 3)

Searched every `.md`/`.sh` file under `agent-system/extensions/core/` for `git-commit-scoped.sh`
invocations followed by `| tail`, `| head`, or `| grep`: none found. `checkpoint-commit.md`'s
own template (used by research/plan commits and the final "complete implementation" commit)
calls the script directly and then checks `$?` with no intervening pipe — correct. The incident's
`2>&1 | tail -25` was not copied from a documented template; it was an ad hoc addition by that
specific caller. However, **neither of `general-implementation-agent.md`'s two phase-commit
sites (4B-iii, Phase Checkpoint Protocol step 5) shows any exit-code check at all** — not even
`checkpoint-commit.md`'s bare `$?` pattern. That is the real, present-tense gap: there is nothing
in these two call sites today that would have caught a dropped exit code, piped or not.

### F5. Scope item 4's script-side precondition is already discharged in this repo

Checked the current source store directly (not the dispatch's summary of it):
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` line ~478: the `.commit-lock`
  fail-open WARNING now reads "Worst case for the shared-overlapping-path shape is UNDETERMINED,
  not confirmed safe: an earlier research pass's own forced-fail-open two-writer harness reported
  a drop in a minority of trials (3/20, 1/10), but that result was NOT independently reproduced by
  this change and is not relied upon here -- do not cite it as settled." No `(reproduced)` claim
  remains.
- The V8 header (line ~174-189) now states the corrected reading explicitly: "...this comment was
  corrected against the actual tool-call transcript that produced fc9f786e: the dropped path
  (zigzag.typ) was never named in that commit's own pathspec at all... The real incident was
  therefore a CALLER-SIDE omission... not anything this script can see or verify."
- Git history confirms this was a deliberate, documented self-correction: commit `b33aca69c`
  ("task 374 phase 4: record the V8 ruling, git semantics, and corrected fail-open comment"),
  and task 374's own `issues.jsonl` entry `iss_1791536155128_hv53qb` records the correction
  explicitly, including the team-lead challenge that prompted it.

This means scope item 4's remaining work is entirely the **Verification-repo** `issues.jsonl`
append — nothing further is needed inside this repo's `git-commit-scoped.sh` or its header.

### F6. Verification's issues.jsonl correction target, confirmed unaddressed

`~/Projects/Logos/Verification/specs/224_review_and_refactor_fragile_gate_infrastructure/issues.jsonl`
still carries entry `iss_1791495993077_nD5IuJ` unmodified (append-only; confirmed no later entry
in that file mentions `zigzag`, `fc9f786e`, or a correction — the file has 9 lines total, last
entry still being `nD5IuJ`). The git working tree there is clean, and the repo's remote
(`origin`, `github.com:benbrastmckie/SPSLib.git`) is unrelated to this append, which is a
task-management artifact, not a pushed deliverable.

## Decisions

- **D1 (scope item 1+2 enforcement site)**: build one new wrapper script in
  `agent-system/extensions/core/scripts/` (not a change to `git-commit-scoped.sh`'s own staging
  semantics — it is a caller sitting in front of it) that performs, mechanically:
  1. Read the given phase's progress file (`specs/{N}_{SLUG}/progress/phase-{P}-progress.json`),
     union every `objectives[].files_touched` entry across all objectives in that phase
     (flattened, deduplicated) — this is a direct generalization of the existing per-objective
     `jq` one-liner at 4B-iii to "all objectives in this phase" instead of "one objective."
  2. Prepend the task directory, `specs/TODO.md`, `specs/state.json`, and the plan path — exactly
     `git-staging-scope.md`'s existing `implement` scope.
  3. Invoke `git-commit-scoped.sh` with that derived pathspec (unchanged script, unchanged
     staging semantics — satisfies the "no change to git-commit-scoped.sh" out-of-scope line).
  4. **After** the commit returns (whatever its exit code), for every one of the `files_touched`
     paths from step 1, run `git status --porcelain -- <path>`. If any output is non-empty,
     print `ERROR: phase commit completeness check failed — the following files_touched path(s)
     are not clean against HEAD after the commit: <paths>` (naming each one) and exit non-zero.
     This is the mechanical post-commit completeness check scope item 1 asks for, run with full
     knowledge of what the phase actually touched — knowledge `git-commit-scoped.sh` itself does
     not have, which is why the dispatch's candidate-site list excludes that script.
  5. Replace both of `general-implementation-agent.md`'s phase-commit call sites (4B-iii and
     Phase Checkpoint Protocol step 5) with a single call to this wrapper, the same way step 4 of
     the Phase Checkpoint Protocol already replaced manual plan-heading edits with a single call
     to `update-phase-status.sh`.
- **D2 (scope item 3)**: no template needs a `| tail` removed (none exists), but both
  `general-implementation-agent.md` call sites should gain an explicit exit-code check — made
  structurally redundant once D1's wrapper is the only thing either site calls, since the agent
  then checks exactly one command's exit code with nothing piped in between.
- **D3 (scope item 4, this repo)**: no action needed; F5 confirms both causal claims are already
  corrected and landed (commit `b33aca69c`).
- **D4 (scope item 4, Verification repo)**: append (never edit) the following entry to
  `~/Projects/Logos/Verification/specs/224_review_and_refactor_fragile_gate_infrastructure/issues.jsonl`
  during the implementation phase:

  ```json
  {"entry_id":"iss_<new-timestamp>_<rand>","timestamp":"<ISO8601-at-append-time>","kind":"issue","class":"inherited-false-premise-landed","severity":"minor","phase":"implement","dispatch_seq":null,"what_happened":"Correcting entry for iss_1791495993077_nD5IuJ, which wrongly stated that git-commit-scoped.sh's stage_paths for the fc9f786e commit LISTED typst/manual/generated/components/zigzag.typ and that the script dropped it. Direct re-read of the originating tool_use (toolu_01JgkBy3RifdvaRCCs4DZDtt, 2026-10-08T21:28:54Z) shows zigzag.typ was never named in that command's stage_paths array at all, and fc9f786e's actual diff (git show --stat) carries exactly the nine components/*.typ paths that WERE named -- no tenth file, no drop by the script. The follow-up commit 96986be6's message makes the same incorrect claim. The real cause was a caller-side omission: the phase's own progress file (progress/phase-5-progress.json, objective 2 files_touched) already recorded zigzag.typ as regenerated, but the hand-typed commit invocation omitted it. git-commit-scoped.sh behaved correctly throughout -- it committed exactly what it was given and exited 0, since nothing it was given was dropped. This correction does not reopen entry nD5IuJ's 'fixed_inline' resolution (commit 96986be6 genuinely fixed the stale file) -- it corrects only the causal attribution.","evidence_path":"specs/224_review_and_refactor_fragile_gate_infrastructure/issues.jsonl","estimated_cost":null,"resolution":"open","suggested_channel":null,"tags":{},"task_dir":"specs/224_review_and_refactor_fragile_gate_infrastructure","session_id":null}
  ```

  (The implementing agent must mint a fresh `entry_id`/`timestamp` at append time, per that
  file's own `iss_{timestamp}_{rand}` convention — the placeholders above are deliberate, not an
  oversight.)
- **D5**: correct `git-staging-scope.md`'s Containment passage per F2 (change "ten" to "nine,"
  drop `zigzag.typ` from the enumerated list) in the same implementation pass, since it is a
  one-line, low-risk fix adjacent to files this task already touches, and leaving it would plant
  the same disproven detail in a second durable document even after D4/D5's corrections land
  elsewhere.

## Recommendations

1. Implement D1's wrapper script first — it is the single mechanical chokepoint that discharges
   both scope items 1 and 2 at once, following the `update-phase-status.sh` precedent exactly
   (mechanize inside a script every call site must use, rather than re-asking agent prose to
   remember a step that has already been observed to get skipped).
2. Add a fixture test for the wrapper mirroring `test-git-commit-scoped.sh`'s structure: a
   phase whose progress file declares N `files_touched` paths, where the fixture's own staged
   commit (simulated, or via a planted pre-commit hook as in task 374's V8 fixture) lands only
   N-1 of them — assert the wrapper's post-commit check fails loudly, names the missing path, and
   exits non-zero. This directly satisfies the dispatch's Acceptance criterion.
3. Update both `general-implementation-agent.md` call sites (4B-iii, Phase Checkpoint Protocol
   step 5) to call the new wrapper instead of `git-commit-scoped.sh` directly, removing the
   now-redundant derivation comment/prose at the per-phase site.
4. Append D4's entry to Verification's `issues.jsonl` and correct `git-staging-scope.md` per D5,
   as separate phases/steps of the plan (cross-repo write vs. in-repo doc fix), both AFTER
   re-checking the current state of task 374's two files one more time at implementation time
   (per the operator note) in case the concurrent sibling dispatch has already landed something.
5. Do not widen the new wrapper's pathspec beyond `files_touched` + the fixed task-directory
   scope (out of scope), and do not change `git-commit-scoped.sh` itself (out of scope) — the
   wrapper is strictly a caller sitting in front of it.

## Risks & Mitigations

- **Risk**: the new wrapper duplicates logic already in `git-staging-scope.md`'s "Reference
  Template." **Mitigation**: the wrapper supersedes the per-phase half of that template as the
  canonical derivation; the template's prose stays as documentation of the *shape*, with a
  pointer to the wrapper as the sanctioned implementation (the same relationship
  `git-commit-scoped.sh` already has with that same document's inline illustrative snippet).
- **Risk**: a progress file is missing or malformed when the wrapper runs (e.g., an agent not
  using the progress-file machinery). **Mitigation**: fail open to the existing fixed
  task-directory scope with a loud warning, exactly as `git-staging-scope.md`'s "Fail-Safe
  Direction" already mandates for an absent `modified_files` — never block a commit over a
  missing optional input.
- **Risk**: cross-repo append to Verification's `issues.jsonl` runs concurrently with the sibling
  task-374-adjacent correction already in flight per the operator note. **Mitigation**: the
  implementing agent re-reads the file immediately before appending (append-only, so a second
  append cannot conflict destructively) and checks task 374's two in-repo files' current state
  before assuming D3 still needs action.

## Context Extension Recommendations

- **Topic**: per-phase commit staging derivation.
- **Gap**: `context/standards/git-staging-scope.md`'s "Reference Template" documents the overall
  `implement` scope but has no worked example of summing `files_touched` across *every* objective
  in a phase (only the single-objective form exists, at 4B-iii). Once D1's wrapper exists, add a
  short cross-reference from `git-staging-scope.md` to the wrapper script as the canonical
  per-phase implementation, matching how it already treats `git-commit-scoped.sh` for the
  base commit itself.

## Appendix

- Search queries/commands used: `grep -rn "files_touched"`, `grep -rln "| tail"` across
  `agent-system/`, `git show --stat fc9f786e`/`96986be6` in the Verification clone, direct JSON
  parse of the cited transcript's `tool_use`/`tool_result` pair for
  `toolu_01JgkBy3RifdvaRCCs4DZDtt`.
- Related, already-closed sibling work: task 374 (script-side V8 gate, exit code 5, now
  corrected fail-open comment) — confirmed current and unaffected by this task's scope.
- Backlog reconciliation already performed by the dispatch (tasks 302, 304, 318 target different,
  in-script pathspec defects; not folded in here) — re-confirmed no overlap during this research.
