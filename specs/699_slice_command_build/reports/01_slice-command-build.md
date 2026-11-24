# Research Report: Task #699

**Task**: 699 - slice_command_build
**Started**: 2026-11-24T00:00:00Z
**Completed**: 2026-11-24T00:00:00Z
**Effort**: medium
**Dependencies**: None (ordered after nothing per the ruling's "Successors" table, row 1)
**Sources/Inputs**:
- `specs/decisions/slice-command-one-path-to-review.md` (the ruling this record owns)
- Codebase: `agent-system/extensions/core/scripts/review-stack-prepare.sh` (the one shared
  primitive, read as a worked pattern, never as a basis), `commands/tag.md`, `commands/merge.md`,
  `hooks/please-grant.sh`, `manifest.json`, `scripts/tests/suite-classification.data`,
  `context/standards/orchestrator-runtime-files.md`, `context/patterns/ref-plumbing-landing.md`,
  `scripts/lib/common.sh`
- Live git state of this repository (`git rev-list`, `git remote -v`)
**Artifacts**:
- This report: `specs/699_slice_command_build/reports/01_slice-command-build.md`
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md,
no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md

## Executive Summary

- The ruling (`specs/decisions/slice-command-one-path-to-review.md`) is a complete, evidence-
  backed design. This record's job is narrow: build exactly the three pieces it names
  (script, series file, command file) and their suite, register them, redeploy, and stop short
  of the operator-only push/open step. No further design research is needed; what remains is
  implementation planning grounded in the ruling's own text and in this repository's existing
  conventions for scripts, suites, and user-only commands.
- The repository's local codebase already contains the one shared primitive the ruling names
  (private index + `read-tree` + per-path `update-index --cacheinfo`/`--force-remove` +
  `write-tree` + `commit-tree` + compare-and-swap `update-ref`), fully worked in
  `scripts/review-stack-prepare.sh`'s `rsp_overlay_tree` (lines 866-892) and `rsp_cut_execute`
  (lines 979-1085). The ruling is explicit that this script is **not the basis** for the new one
  ("Basis": "no existing code is the basis") and is itself deleted by a different, sibling
  record (`delete_review_stack_inference_route`) — but its overlay function is the concrete
  shape of the ~35-line primitive the new script re-implements independently.
- `commands/tag.md` and `commands/merge.md` are the two closest existing command-file patterns:
  `/tag` for the "user-invoked only, no agent/skill/lifecycle caller" class the ruling places
  `/slice` in, and `/merge` for the `allowed-tools` frontmatter shape (`Bash(git:*)`,
  `Bash(gh:*)`, `Bash(glab:*)`, `AskUserQuestion`) a command that both prompts interactively and
  calls the forge directly needs.
- The series file's runtime-file disposition has a direct precedent already documented:
  `context/standards/orchestrator-runtime-files.md` row for
  `specs/.orchestration/reviews/<stack id>/manifest.json` is "Durable provenance, but untracked",
  covered by the pre-existing `**/.orchestration/` gitignore directory-class pattern (no new
  gitignore pattern needed). `specs/.orchestration/slices/<series id>.json` sits under the same
  `**/.orchestration/` prefix, so the only open question for the plan is whether to add a
  documentation row for it (the dispatch defers this decision to the plan explicitly).
- Re-measured, not carried: this repository's `master` is now 412 commits ahead of
  `origin/master` and 0 behind (`git rev-list --left-right --count origin/master...master`,
  checked live during this research pass) — a real, growing difference that satisfies the
  ruling's "VERIFY BY" acceptance precondition (a real difference exists to cut). No command,
  skill, hook, or lifecycle script anywhere under `agent-system/` names `/slice` or
  `slice_bar` today (re-confirmed by a fresh `grep -rln` pass); every other hit for the bare word
  "slice" in the tree is an unrelated use of the common English word.

## Context & Scope

This research covers what Task 699 ("THE /slice BUILD") owns per its dispatch: `commands/
slice.md`, one new script with exactly three subcommands (`check`, `build`, `status`), the
series-file schema, and the suite that proves the two static constraints (no push/checkout/
merge/forge invocation in the script; a union check that the target's tree overlaid with every
slice equals the work ref's tree on every assigned path). It explicitly excludes: deleting
`review-stack-prepare.sh`, narrowing `milestone-review-handoff.sh`, removing `/merge`, binding a
push grant to a pushed ref, and doc parity/the operator runbook — all five are separate records
named in the ruling's "Successors" table and in this dispatch's "NOT THIS RECORD'S" section.

The scope was fixed by the ruling itself; this research's job was to verify that scope against
the live source store (nothing already exists under this name, so there is no collision to
resolve) and to locate the concrete codebase precedents an implementation plan will draw on for:
(a) the shared git-plumbing primitive, (b) the command-file conventions for a user-invoked,
no-agent-caller command that both runs `AskUserQuestion` prompts and calls a forge CLI directly,
(c) the manifest/suite-classification registration mechanics for a new script+suite pair, and
(d) the runtime-file documentation convention for a new `specs/.orchestration/**` state file.

## Findings

### Codebase Patterns

**The shared overlay/commit/CAS primitive** (`scripts/review-stack-prepare.sh`):
- `rsp_overlay_tree` (lines 866-892): builds a tree equal to a base tree with a given path set
  set to its blob (mode+oid) at an end commit, or removed where absent there, entirely inside a
  private `GIT_INDEX_FILE` (a `mktemp` file, removed immediately after `write-tree`). It never
  touches the shared index, working tree, or `HEAD`. This is exactly the overlay step the
  dispatch's `build` subcommand description names ("private index, base tree, overlay of the
  slice's paths at the work ref, write-tree").
- `rsp_cut_execute` (lines 979-1085) chains the primitive end-to-end: resolve the anchor/parent
  commit and tree, call the overlay, `git commit-tree <tree> -p <parent>` for the new commit,
  then move the branch ref by three-argument compare-and-swap `git update-ref <ref> <new>
  <old>` (line 1049), refusing (not silently overwriting) when the CAS fails because the ref
  moved concurrently. This is the literal shape of `build`'s "write-tree, commit-tree,
  compare-and-swap move of refs/heads/slice/<series>/<id>" with HEAD, index, and working tree
  untouched.
- The ruling is unambiguous that none of this script's code is inherited: "Basis" names the
  overlay as "35 lines... cheaper to write again inside a 400 to 600 line script... than to
  carve out of 1,572." The new script's overlay primitive should be independently written
  (same git plumbing, no shared function, no `source` of `review-stack-prepare.sh`), both
  because the ruling says so and because `review-stack-prepare.sh` is itself deleted by a
  different, ordered-after record (`delete_review_stack_inference_route`, ordered after the
  handoff-narrowing record, which is itself ordered after this one — see the ruling's
  "Successors" table and its amendment note). Depending on it would create a dependency this
  record does not have today and would break once the sibling record runs.
- `rsp_refuse` (lines 168-172): the refusal convention — `echo "REFUSED: <script>: <reason>:
  <message>" >&2; exit <code>` — with a comment explaining why refusal resolvers are never
  wrapped in `"$(...)"` (an `exit` inside a command-substitution subshell only kills the
  subshell). The new script's `check`/`build`/`status` refusals should follow the same
  convention: a distinct, named reason string per refusal class, on stderr, with a script-
  specific exit code.
- `rsp_move_commit_onto_new_parent` uses `git merge-tree --write-tree --merge-base=... --merge`
  for a three-way rebase-onto-new-base recompute with named-path conflict refusal. The dispatch's
  own mechanism description does not call for this move primitive for `build`'s normal path (an
  independent slice's base is simply the target's tip overlaid with its dependency closure, not
  a moved existing commit) — but the ruling's "status"/"continue" behavior ("a merged parent...
  rebuilt from its declaration... re-derive, never rebase") explicitly recomputes from scratch
  rather than moving an existing tree onto a new parent, so this three-way recompute primitive is
  **not** needed by the new script; a fresh overlay against the new base each time is simpler and
  matches "Re-derive, never rebase" literally. This is a useful negative finding for the plan:
  do not port `rsp_move_commit_onto_new_parent`.

**Suite/fixture conventions** (`scripts/tests/test-review-stack-prepare.sh`):
- Deployed-shape sandbox pattern: `common_test_workdir_init` (from `scripts/lib/common.sh`),
  then an `install_scripts` helper that copies the script-under-test, its `lib/` dependencies,
  and `deploy-root-guard.sh` into a fixture tree shaped like a real deploy
  (`$d/.claude/scripts/...`), because `deploy-root-guard.sh`'s default structural check requires
  the script's own directory to end in `/.claude` or `/.opencode`.
- Fixture naming deliberately avoids `origin`/`upstream`/`main`/`master` so a hardcoded name
  assumption would fail loudly rather than pass by accident — the new suite should follow the
  same discipline given the ruling's own "Repo-agnostic" constraint (no branch/remote/consumer
  name in a deliverable).
- `scripts/tests/suite-classification.data` row format: tab-separated `basename  class  reason`,
  e.g. `test-review-stack-prepare.sh	unit	-`. The new suite's row is a one-line addition.

**Manifest registration** (`manifest.json`): `provides.scripts` and `provides.scripts` (tests
subtree, via `tests/test-*.sh` entries) are flat, alphabetically-ish sorted string arrays; adding
the new script and its suite is a two-line insertion (one in each array) at the alphabetically
correct position, following the existing `review-stack-prepare.sh` / `tests/test-review-stack-
prepare.sh` entries as the nearest precedent for insertion point and naming style.
`provides.commands` is a separate flat array (`commands/*.md` basenames, e.g. `"merge.md"`,
`"tag.md"`); the new `slice.md` entry belongs there, not under `scripts`.

**Command-file conventions**:
- `commands/tag.md` is the `/slice`-adjacent precedent the ruling cites directly ("in the same
  class as `/tag`"): a short, declarative frontmatter (`description`, `argument-hint`), an
  explicit "User Only: YES" / agent-restriction section, a numbered `## Workflow`, and a
  `## Requirements` list of preconditions. `/tag` names no `allowed-tools` frontmatter field at
  all (its workflow is described narratively, delegated to `skill-tag`), unlike `/merge`.
- `commands/merge.md` is the precedent for a command that (a) runs interactive
  `AskUserQuestion` prompts and (b) calls a forge CLI (`gh pr create` / `glab mr create`)
  directly from the command body, not from a script: its frontmatter declares `allowed-tools:
  Bash(git:*), Bash(gh:*), Bash(glab:*), AskUserQuestion`. `/slice` needs the same shape of
  `allowed-tools` line (plus whatever invokes the new script, e.g. `Bash(.claude/scripts/slice-*
  .sh:*)` or equivalent), since the ruling places both prompts, the proposal, the per-slice push
  lines, and "the forge call... here and nowhere else" inside `commands/slice.md`, never inside
  the script.
- `AskUserQuestion` is the established tool for every multi-turn/interactive command prompt in
  this codebase (`/orchestrate`, `/meta`, `/merge`, `/fix-it`, `/task` all declare it in
  `allowed-tools`). Prompt 1 (target selection, with free-entry "another branch" as the always-
  last option) and prompt 2 (approve/revise/cancel, with free-text "revise") both map onto this
  tool's existing option-list-plus-free-text affordance; no new interaction primitive is needed.

**Runtime-file documentation precedent** (`context/standards/orchestrator-runtime-files.md`):
the existing row for `specs/.orchestration/reviews/<stack id>/manifest.json` and its sibling
`<NN>-body.md` files is classified "Durable provenance, but untracked — the same third
disposition as the batch record and queue archive rows above, covered by the same pre-existing
`**/.orchestration/` directory-class pattern (no new pattern member needed)." The new series
file (`specs/.orchestration/slices/<series id>.json`) and its sibling PR-body file
(`specs/.orchestration/slices/<series id>/<slice id>.md`) sit under the identical
`**/.orchestration/` prefix, so no new gitignore pattern is needed either way; the open
question the dispatch defers to the plan is purely documentary (whether this file earns its own
row in that standards doc, which is a judgment call about discoverability, not a mechanical
requirement). If the plan decides yes, that one file (plus the new state files) is the only
addition to Territory beyond what the dispatch already lists.

**Cycle-detection nuance for `check`**: the dispatch's own line 24-27 description places "no
glob matches nothing; depends_on names real slices and has no cycle" inside `check`'s
responsibilities, while the ruling's "No inference code is written" sentence bans "union-find,
topological sort, overlap analysis." These are not in tension: a `depends_on`-cycle check is a
bounded graph-reachability validation over a small, already-declared edge set (a DFS with a
visited/in-progress marker, refusing on revisit), not an inference step that recovers groupings
or an ordering from history. It is validation of what the command already wrote, not inference
of what the command should have written. The plan should scope the cycle check narrowly (detect
a cycle and refuse; do not compute or cache a topological order for `build` to consume — `build`
decides per-invocation readiness from each slice's own `depends_on` states, per the mechanism
section's "a slice with two or more unmerged dependencies waits").

**No existing collision**: a fresh `grep -rln` pass over `agent-system/` for `slice_bar` and
`/slice` (word-boundary) returns nothing outside `specs/**` (task/decision records, which are
exempt from the task-reference and record-versioning deliverable rules). All other matches for
the bare substring "slice" in the tree (`commands/telemetry.md`, `commands/refresh.md`,
`scripts/generate-task-order.sh`, etc.) are unrelated uses of the common English word (e.g.
"a slice of," bash array slicing syntax). This reconfirms, independently, the ruling's own
claim that "Nothing in the source store names /slice today."

### External Resources

None consulted. This task is entirely internal: the ruling record is the complete design
authority, and the only open questions are implementation-plan judgment calls (file naming
within the settled territory, exact refusal exit codes, and the orchestrator-runtime-files.md
row decision) that no external documentation bears on. Per the routing table (`general`/`meta`
task type), codebase-first research was the correct and sufficient strategy here.

## Recommendations

- **Do not base the new script on `review-stack-prepare.sh`.** Write the overlay/commit/CAS
  primitive fresh (it is short — the ruling's own estimate is 400-600 lines total for the whole
  script). Reuse only the general shell conventions already common to this codebase's scripts
  (`scripts/lib/common.sh` helpers for repo-root resolution, session/timestamp helpers,
  `set -uo pipefail`), not any review-stack-specific function.
- **Model the command file's frontmatter on `commands/merge.md`**, not `commands/tag.md`:
  `/slice` needs `AskUserQuestion` plus the forge-call tool(s) the ruling assigns to the command
  file itself, which `/tag`'s narrative-workflow, no-`allowed-tools` shape does not need. Carry
  over `/tag`'s "User Only" framing and its explicit "no agent, skill or lifecycle script invokes
  it" structure for the restriction section, since that is the exact class the ruling places
  `/slice` in.
- **Scope the `check` subcommand's cycle detection as a bounded validation, not an inference
  step** (see Findings above) — a DFS/visited-set cycle check over the declared `depends_on`
  edges, with no persisted topological order and no component/overlap analysis.
- **Do not port `rsp_move_commit_onto_new_parent`** (the three-way `merge-tree` recompute for an
  existing commit moved onto a new parent). The ruling's "re-derive, never rebase" principle
  means every slice commit is rebuilt fresh from its declaration against the current base on
  each `build`/`continue` pass, not moved. A conflict during that fresh overlay (a path the base
  and the work ref both touched incompatibly) should be a `check`/`build` refusal naming the
  path, using the same `git ls-tree`-based overlay the primitive already performs — no
  three-way merge primitive is needed because the overlay always writes the work ref's blob for
  the slice's own paths unconditionally; there is no "merge" step at all, only placement.
- **Decide the `orchestrator-runtime-files.md` row question explicitly in the plan** (the
  dispatch defers it there) rather than leaving it implicit: either add a one-row addition
  following the existing review-manifest row's "Durable provenance, but untracked" disposition
  and extend Territory with that one file, or explicitly record the decision not to (e.g. because
  the `**/.orchestration/` class-level documentation already covers it adequately without a
  per-file row). Either choice is consistent with the dispatch; only silence on the question is
  not.
- **Register the three new files in both `manifest.json` (`provides.commands`,
  `provides.scripts` twice — once for the script, once for its test) and
  `scripts/tests/suite-classification.data` (one `unit` row, reason `-`, following the
  `test-review-stack-prepare.sh` precedent)** as the dispatch's Territory section already
  requires; this was independently confirmed as the correct mechanism by reading both files'
  existing structure.
- **Redeploy via `deploy-headless.sh` using the bounded-wait idiom** (`timeout 540`, Bash tool
  timeout `600000`) exactly as the dispatch's Description section already specifies; no
  alternative redeploy mechanism was found or is needed.

## Decisions

- The new script will **not** source, call, or depend on `review-stack-prepare.sh` in any way,
  consistent with the ruling's explicit "no existing code is the basis" and with that script's
  own scheduled deletion by a differently-ordered sibling record.
- The `depends_on`-cycle check belongs inside the script's `check` subcommand as a bounded
  validation (DFS over a small declared edge set), not as "inference code"; this resolves the
  apparent tension between the dispatch's `check` responsibilities and the ruling's "no
  topological sort" prohibition by scoping the latter to *grouping/ordering inference*, which
  this is not.
- No external research was needed or performed; the ruling record together with this
  repository's existing script/command/manifest conventions fully grounds the implementation
  plan.

## Risks & Mitigations

- **Risk**: an implementation plan might be tempted to extract/refactor
  `review-stack-prepare.sh`'s overlay function into a shared `lib/` helper "to avoid
  duplication," reintroducing exactly the dependency the ruling forbids (since that script is
  itself slated for deletion by an ordered-after sibling record, and task 699 is "ordered after
  nothing," i.e. must not acquire a dependency on work ordered after it).
  **Mitigation**: the plan should state explicitly that the overlay primitive is written fresh
  and self-contained in the new script, with no shared-library extraction from the doomed
  script.
- **Risk**: scope creep into the other five "NOT THIS RECORD'S" items (deleting
  `review-stack-prepare.sh`, narrowing the handoff, removing `/merge`, binding the push grant,
  doc parity/runbook), each a separate record with its own ordering per the ruling's
  "Successors" table.
  **Mitigation**: Territory in the dispatch is already narrow (three new files plus two
  registration-data edits, "ordered after nothing"); the plan should not touch
  `scripts/milestone-review-handoff.sh`, `commands/merge.md`, `hooks/please-grant.sh`,
  `scripts/lib/push-grant-lib.sh`, or `context/patterns/ref-plumbing-landing.md` at all.
- **Risk**: the implementing agent, being unable to push or open a pull request
  (`rules/pr-prohibition.md`), might attempt to work around this by having the script itself
  push or call the forge, which the ruling and the dispatch both explicitly forbid ("The script
  contains no push, checkout, merge or forge invocation, and its suite asserts that
  statically").
  **Mitigation**: the suite's static assertion (grepping the script's non-comment lines for
  `git push`, `git checkout`, `git switch`, `git merge`, `git rebase`, `git replay`, `gh`,
  `glab`) must be written and must pass before any other acceptance criterion is checked,
  mirroring `review-stack-prepare.sh`'s own header comment and the suite convention that proves
  it (lines 6-8 of that script's header).
- **Risk**: the implementing agent might try to satisfy "VERIFY BY"'s final clause (one slice
  pushed and opened by the operator) itself, which it structurally cannot do and must not
  attempt.
  **Mitigation**: the dispatch already states this is the expected stop point ("the IMPLEMENTING
  AGENT STOPS SHORT... and returns with the record NOT closed, naming the exact lines the
  operator types"); the plan's final phase should end at "suite green + deploy clean +
  operator-facing instructions printed/recorded," not at a closed task.

## Context Extension Recommendations

- **Topic**: a second worked implementation of the ref-plumbing overlay primitive.
- **Gap**: `context/patterns/ref-plumbing-landing.md` currently names
  `review-stack-prepare.sh` as "the worked implementation" (singular). Once the new slice
  script exists, that document would describe the idiom with its only cited example already
  scheduled for deletion by a different record.
- **Recommendation**: out of scope for this task's Territory (the dispatch's "NOT THIS
  RECORD'S" section and the narrow Territory listing both exclude editing existing files other
  than `manifest.json`/`suite-classification.data`). Flagged here only as a note for whichever
  successor record narrows the handoff or deletes `review-stack-prepare.sh` — that record, not
  this one, is the natural point to re-point `ref-plumbing-landing.md` at the surviving script.

## Appendix

Search queries / commands used:
- `python3 -c "import json; json.load(open('.claude-extensions.json'))..."` to resolve the core
  extension's `source_dir`.
- `find . -maxdepth 2 -type d` under the source store to orient directory layout.
- `wc -l` and targeted `Read`/`sed -n` ranges over `scripts/review-stack-prepare.sh`,
  `commands/tag.md`, `commands/merge.md`, `manifest.json`,
  `scripts/tests/suite-classification.data`, `context/standards/orchestrator-runtime-files.md`,
  `hooks/please-grant.sh`, `scripts/lib/common.sh`, `context/patterns/ref-plumbing-landing.md`.
- `grep -n "review-stack-prepare\|milestone-ref-land" manifest.json scripts/tests/suite-
  classification.data` to find the exact registration precedent.
- `grep -rln "slice" ...` (and narrower `slice_bar`/`/slice` word-boundary passes) over
  `agent-system/` to reconfirm no existing collision.
- `git remote -v`, `git rev-list --left-right --count origin/master...master`, `git branch
  --show-current` to re-measure the live ahead/behind figure rather than carry the ruling's
  "several hundred."
- `grep -n "AskUserQuestion" commands/*.md` to enumerate the existing interactive-prompt
  convention.
