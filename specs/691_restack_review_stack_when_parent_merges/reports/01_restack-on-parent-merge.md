# Research Report: Task #691

**Task**: 691 - Restack review stack when parent merges
**Started**: 2026-11-23T22:11:00Z
**Completed**: 2026-11-23T22:29:00Z
**Effort**: 1.5 hours (per the parent plan's Phase 4 timing estimate)
**Dependencies**: None (parent plan Phase 4 depends on Phase 3, already landed)
**Sources/Inputs**:
- `specs/685_stack_pr_submission_from_integration_branch/plans/01_stack-pr-submission.md` (Phase 4 section, PD1/PD6/PD7/PD8/PD9 decisions)
- `agent-system/extensions/core/scripts/review-stack-prepare.sh` (live script, 1219 lines)
- `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` (live suite, 709 lines, 38 passing cases)
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` (`review_base` section)
- `agent-system/extensions/core/context/patterns/ref-plumbing-landing.md`
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh`, `hooks/please-grant.sh`, `commands/please.md`
- `specs/state.json` (task 691's own `file_scope`)
**Artifacts**:
- This report: `specs/691_restack_review_stack_when_parent_merges/reports/01_restack-on-parent-merge.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- This record owns exactly one deliverable: the `restack` subcommand of
  `agent-system/extensions/core/scripts/review-stack-prepare.sh`, filled in to detect a merged
  bottom-of-stack entry and recompute its descendants. The task's own declared `file_scope`
  (confirmed in `specs/state.json`) is exactly the script and its suite — no doc file is in
  scope, which matches the parent plan's Phase 4 "Files to modify" list exactly.
- Every write primitive `restack` needs already exists and is proven by Phase 3's cut
  implementation: `rsp_move_commit_onto_new_parent` (three-way `git merge-tree`, refuses 48 on
  conflict and names the path) and the `git commit-tree` + compare-and-swap `git update-ref`
  idiom used in `rsp_cut_execute`. No new git primitive is required.
- The manifest (`specs/.orchestration/reviews/<stack id>/manifest.json`) already carries every
  field `restack` needs to read and update per entry: `ordinal`, `tasks`, `branch`, `base`,
  `commit`, `parent_commit`, `title`, `body_path`, `state`, `request`. Today `state` is always
  written as `"prepared"`; `restack` is the first writer of `"merged"`.
- Today, `restack` with any arguments (including `--stack-id NAME`) falls through to the
  dispatcher's generic "subcommand body not yet implemented" branch — there is no
  `elif [ "$subcommand" = "restack" ] ...` arm yet, unlike `show`/`record-request`. A new
  `--merged` flag also needs parsing (distinct from the existing `--merge` flag, which is
  cut-only and means something unrelated: forcing two tasks into one unit).
- Three points in PD7's prose are genuinely ambiguous and should be resolved explicitly in the
  plan rather than left to improvisation during implementation: (1) what "the parent" refers to
  in the merge-detection test, (2) what "a local review ref" means in the disagreement refusal,
  and (3) whether `--merged NN` is a required disambiguator or an optional override. This report
  gives a recommended reading for each, grounded in what the existing code already does for the
  closest analogous case.
- The exit-code space is contiguous through 52; this phase should allocate new codes starting at
  53, naming at minimum: a restack-specific "no --stack-id" usage refusal (or a reuse of the
  existing pattern at a new code), a "review base's remote-tracking ref is absent" refusal, and
  a "local/remote ref disagreement the manifest does not explain" refusal. `ref_conflict` (48)
  and `manifest_missing` (50) are directly reusable, unchanged.

## Context & Scope

Task 691 is one of two sibling expansions of a seven-phase parent plan
(`specs/685_stack_pr_submission_from_integration_branch/plans/01_stack-pr-submission.md`) that
closed Phases 1-3 (review-base resolution, unit selection/ordering, cut+manifest) across prior
dispatches. This record owns Phase 4 only: "Restack when a parent merges." The description
explicitly states the parent plan remains the authoritative design record and that this
description does not restate PD1-PD12 or the verification tiers — this report therefore treats
the parent plan's Phase 4 section and its cited decisions (PD1, PD6, PD7, PD8, PD9) as ground
truth, and focuses on mapping that prose onto the concrete, already-landed code it must extend.

Scope is bounded to research only: confirming what already exists, what primitives are reusable
without modification, what is genuinely new, where the current dispatcher and flag parser need
new arms, and what is ambiguous in the design prose that the planning phase should pin down
explicitly rather than leave implicit. No code was written or modified in this phase.

The task's own `file_scope` (read from `specs/state.json`, project_number 691) is exactly:
`agent-system/extensions/core/scripts/review-stack-prepare.sh` and
`agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh`. This matches the
parent plan's Phase 4 "Files to modify" list verbatim (no doc file is listed there, unlike
Phases 1 and 3, which each updated `context/standards/repo-level-declarations.md` or
`context/standards/orchestrator-runtime-files.md`). The plan's own implementation and the
finished script's header comment block (lines 1-115) are both deliberately self-documenting —
the header already names every subcommand, every resolution step, and the full exit-code table,
so this report treats the header as a secondary deliverable the plan phase should keep updated
in place rather than a separate doc.

## Findings

### Landed primitives directly reusable for `restack`

- `rsp_move_commit_onto_new_parent <old_parent> <new_parent> <commit>` (script lines 878-892):
  stdout is the sha of the tree `<commit>` would have if rebased from `<old_parent>` onto
  `<new_parent>`, via `git merge-tree --write-tree --merge-base=<old_parent> <new_parent>
  <commit>`. On conflict it refuses directly with exit 48 (`ref_conflict`), naming the
  conflicting path(s) via a second `--name-only` invocation. This is literally the "recompute
  each descendant with a three-way `merge-tree` onto its new parent" step the Phase 4 task list
  names — no new conflict-handling code is needed, only a caller.
- The `git commit-tree ... -p <parent> <<< "$title"` then `git update-ref <ref> <new> <old>`
  compare-and-swap idiom, used identically in `rsp_cut_execute` (lines 1023-1029) and documented
  generically in `context/patterns/ref-plumbing-landing.md`. `restack` should follow the exact
  same shape: read the existing branch sha as `<old>`, compute `<new>` off-tree, and let
  `update-ref`'s three-argument form fail loudly on a concurrent mover rather than overwrite.
- `git merge-base --is-ancestor <A> <B>` is already used four times in the script (lines 463,
  574, 664, 700) for ancestry checks unrelated to restack — confirms it is an established,
  already-exercised idiom in this file, not something to invent.
- `rsp_manifest_field <manifest_json> <branch> <field>` (lines 944-951) already reads a prior
  on-disk manifest by branch+field via `jq`; `restack` can read the current manifest the same
  way, or iterate `.entries[]` directly as `rsp_show_stack` does (lines 1062-1086, `jq -r
  ".entries[$i].field"` per index) — `rsp_show_stack` is the closest existing template for
  "iterate a stack's manifest entries in order and read fields," since `restack` reads a
  manifest that already exists (unlike `cut`, which builds the manifest from a freshly computed
  selection and `PLAN_*` arrays that do not exist outside `cut`).
- The `refs/remotes/<remote>/HEAD` absence check the Phase 4 task list calls for ("When
  `refs/remotes/<remote>/HEAD` is absent, print `git remote set-head <remote> -a` first") has an
  exact existing idiom to copy: `scripts/lib/push-grant-lib.sh`'s `pg_default_branch()` (lines
  227-230): `git symbolic-ref --short "refs/remotes/${remote}/HEAD" 2>/dev/null`, empty on
  failure. `push-grant-lib.sh` is a different script (not in this task's `file_scope`), so this
  is a pattern to replicate inline in `review-stack-prepare.sh`, not a function to import.
- The printed `/please push <remote> <branch> [--force-with-lease]` form the Phase 4 task list
  specifies is already the exact two-token form `show` prints today (`printf '  /please push %s
  %s\n' "$remote" "$branch"`, line ~1086) and is confirmed accepted by
  `hooks/please-grant.sh`'s parser ("Remote-branch form: push \<remote\> \<branch\>
  [--force-with-lease]", line 128) — `restack`'s print should append ` --force-with-lease` to
  that same two-token form, not switch to the alternate "push \<branch\> to \<remote\>" form
  `please-grant.sh` also accepts.

### The static safety assertions impose no new constraint beyond what `cut` already satisfies

The suite's two static checks (script lines 689-700 in the test file) forbid, over the script's
non-comment lines: `git push|checkout|switch|rebase`, bare `git merge` (followed by whitespace
or end-of-line — `git merge-tree` and `git merge-base` are unaffected, since neither has a space
or line-end immediately after "merge"), `git-replay`, `gh pr|api`, `glab mr`; and separately, the
literal words `origin`/`main`/`master`/`upstream` outside comments. Every primitive `restack`
needs (`merge-tree`, `merge-base`, `commit-tree`, `update-ref`, `rev-parse`, `symbolic-ref`,
`for-each-ref`) is already used elsewhere in the file under the same constraint, so no new
exemption or assertion change is needed — "an existing assertion you had to edit to pass" (the
task's own stated red flag) should not arise here if the implementation stays within these
primitives.

### Manifest schema and the new `state` value

Current manifest shape (`rsp_cut_execute`, lines ~1053-1060), one object per entry:
`{ordinal, tasks, branch, base, commit, parent_commit, title, body_path, state, request}`.
`state` is currently always written as the literal string `"prepared"` (line ~1028: `old_state="prepared"`,
only overridden by reading a prior manifest's own `state` field forward across a re-cut). No
other state value exists in the codebase today. `restack` is the first code to write `"merged"`,
per the Phase 4 task list ("A merged entry's state becomes `merged`"). `show` (both the
human-readable and `--json` forms) does not currently print `state` in its human-readable
output at all — only `--json` exposes it, since that mode emits the manifest verbatim. The plan
should decide whether `show`'s human-readable line also starts printing `state` once it can be
non-default; this is a small, cheap addition within the same file and arguably necessary for an
operator to see which entries have already merged without reaching for `--json`.

### Dispatcher gap: `restack` has no execution arm today

The subcommand dispatch block (lines ~1205-1218) is:

```bash
if [ "$subcommand" = "cut" ]; then ...
elif [ "$subcommand" = "show" ] && [ -n "$stack_id" ]; then rsp_show_stack "$json_flag"
elif [ "$subcommand" = "record-request" ] && [ -n "$stack_id" ]; then rsp_record_request ...
else
  echo "NOTE: ... subcommand body not yet implemented, nothing written." >&2
fi
```

`restack --stack-id NAME` currently always falls into the final `else` branch regardless of
whether `--stack-id` was given, because no `elif [ "$subcommand" = "restack" ] ...` arm exists.
This phase must add one, parallel to `show`/`record-request`. A `restack` invocation given with
no `--stack-id` at all has no refusal today (it silently resolves and prints the generic
"not yet implemented" NOTE); the plan should decide whether a missing `--stack-id` for `restack`
refuses with the existing `stack_id_required` (41) — currently scoped to `cut`'s `--batch`/
`--tasks` paths — or with a new, restack-specific code. Reusing 41 is simpler and keeps the
reason vocabulary small; introducing a new code keeps error messages precise about which
subcommand required it. Either is defensible; this report recommends reuse (see Decisions).

### A new flag is needed: `--merged NN`, distinct from the existing `--merge`

The existing `--merge` flag (parsed at line ~1157, feeding `MERGE_PAIRS`) is `cut`-only and
means "force these two task numbers into one review unit" (PD3) — unrelated to Phase 4's
`--merged NN`, which the Phase 4 task list and PD7 both describe as letting the operator assert
that a specific manifest entry (by ordinal, the same `NN` convention `record-request` already
uses) has merged. These are different flags with similarly-spelled names; the plan should keep
them lexically distinct in both code and documentation to avoid an operator or a future reader
confusing `--merge` (cut, task-pair) with `--merged` (restack, entry ordinal).

### Three ambiguities in PD7's prose worth pinning down before implementation

PD7 reads: *"Detection is local, against the fetched remote-tracking ref of the review base: the
parent's commit is an ancestor of it, or merging the parent into it yields the base's own tree.
`--merged NN` lets the operator state it. Descendants are recomputed and local refs moved by
compare-and-swap. A conflicting restack refuses and names the path. The push and the forge base
change are prepared, never run."*

1. **What "the parent" means in the detection test.** Read literally, "the parent" most plausibly
   denotes the bottom-of-stack entry's own review commit (the thing based on, i.e. logically
   parented under, the review base) — not some other commit called "parent" elsewhere in the
   script. Under that reading, detection for the current bottom entry `E` (whose manifest
   `base` field names the review base) is: `git merge-base --is-ancestor <E.commit>
   <remote_tracking_sha>` (fast-forward / rebase-and-merge case), OR
   `rsp_move_commit_onto_new_parent <E.parent_commit> <remote_tracking_sha> <E.commit>` yields a
   tree identical to `<remote_tracking_sha>^{tree}` (squash-merge case: merging `E`'s diff into
   the already-landed tip introduces no further change, because it is already there). This
   reuses `rsp_move_commit_onto_new_parent` for detection, not just for the subsequent recompute
   step — one function, two call sites, exactly as PD6 already does for `cut`'s "one primitive
   serves both the first cut and every restack" design intent.
2. **What "a local review ref" means in the disagreement refusal.** Two readings are available:
   (a) a stack branch's local ref vs. its own remote-tracking ref (the exact case
   `rsp_cut_execute`'s `unknown_remote_commit` guard, exit 49, already covers — reusable
   verbatim for restack's own ref-moving step); or (b) the review base's own local ref (e.g. a
   local `main`/`develop`-style branch) vs. `refs/remotes/<remote>/<review base>` disagreeing in
   a way nothing in the manifest accounts for (a genuinely new check, since the manifest never
   records the review base's own history). This report recommends treating the refusal as
   covering *both*: reuse exit 49 unchanged for case (a) on every stack branch `restack` moves,
   and add one new, distinctly-named refusal for case (b) scoped to the review base ref itself.
   Collapsing both into one exit code would make a future refusal message ambiguous about which
   ref disagreed.
3. **Whether `--merged NN` is a required disambiguator, an optional override, or both.** The
   Phase 4 task list's `restack --stack-id NAME [--merged NN]` signature marks it optional. PD7's
   "`--merged NN` lets the operator state it" reads as an override on top of automatic detection
   (for the case where the squash-merge test above cannot run — e.g., no fetch has happened
   recently enough for the remote-tracking ref to reflect the merge, yet the operator knows it
   landed by other means) rather than a value required for ordinary operation. The Phase 4 task
   list's bullet on the remote-tracking ref requirement ("read ... the remote-tracking ref of
   the review base... if that ref is absent, refuse") does not carve out an exception for
   `--merged NN` being supplied, so the recommended reading is: the remote-tracking-ref-absent
   refusal applies unconditionally, and `--merged NN` only changes which entries are *treated as
   merged* once that ref is present, never bypasses needing it. This keeps "never fetches" (a
   hard constraint stated directly in the description) uniformly enforced.

### Reusable test-fixture scaffolding

The suite (`test-review-stack-prepare.sh`) already has every building block the Phase 4 cases
need, confirmed by the Phase 3 "moved-base foreign line" and "unknown remote commit" cases
(lines ~616-665), which are structurally the closest existing analogues to what Phase 4 must
add:

- `stack_fixture_repo`, `stack_write_batch`, `stack_add_task_entry`, `stack_commit`,
  `stack_add_proof` build a fixture repo with landing proofs for arbitrary task numbers (the
  suite's existing convention is synthetic numbers in the 9xx range, `task-ref-ok`-marked where
  needed — though Phase 1's own note records that no marker was actually needed in this suite).
- `run_rsp`, `assert_refusal`, `manifest_entry_field`, `unit_field` are generic across
  subcommands and need no change for `restack` cases.
- Simulating "the remote already has this" needs no real push or fetch (consistent with
  `pr-prohibition.md` and the description's hard constraint): the existing moved-base and
  unknown-remote-commit cases both write directly to `refs/remotes/<remote>/<branch>` via
  `git update-ref`, bypassing any network or forge entirely. The same technique directly
  simulates "the bottom entry was squash-merged": after a `cut`, advance
  `refs/remotes/<REMOTE_NAME>/<review-base-branch>` (via `git commit-tree` + `update-ref`, never
  a real merge) to a commit whose tree equals what merging the bottom entry's diff into the
  review base would produce — exactly the Phase 3 "review base past the merge base" fixture
  pattern (lines ~616-644), reused with the review base's remote-tracking ref as the moving
  target instead of a branch.
- A fixture for the "merge-commit parent detected by ancestry" case (named in the Phase 4 task
  list's suite-case bullet) needs the remote-tracking ref of the review base to carry an actual
  two-parent merge commit whose first-parent history already contains the bottom entry's
  commit — buildable with a second `git commit-tree -p <old tip> -p <entry commit>` without any
  real `git merge` invocation, keeping the suite's own static assertions satisfied even in its
  fixture-construction code (the suite file is not scanned by those assertions, which only run
  against `review-stack-prepare.sh` itself, but keeping the same discipline in the fixture
  avoids modeling a merge the production code is forbidden from performing).
- An absent-remote-tracking-ref case is the simplest possible fixture: a stack cut normally,
  then `restack` run with no corresponding `refs/remotes/<REMOTE_NAME>/<review-base>` ref ever
  created (the default state of any fixture that never wrote one) — no new scaffolding needed.

## Decisions

- **Treat the parent plan's Phase 4 section (and its cited PD1/PD6/PD7/PD8/PD9 decisions) as the
  controlling design record**, per the description's explicit instruction; this report does not
  propose superseding or amending any of PD1-PD12.
- **Confirmed via `specs/state.json`**: task 691's `file_scope` is exactly
  `review-stack-prepare.sh` and `tests/test-review-stack-prepare.sh` — no doc file (e.g.
  `repo-level-declarations.md`) is in scope for this phase, matching the parent plan's own
  Phase 4 "Files to modify" list. The plan phase should not add a doc-file edit beyond updating
  this script's own header comment block, which already documents its exit-code table in place.
- **No new git primitive is required.** `restack` is built entirely from primitives the script
  already uses elsewhere under the same static-assertion constraints: `git merge-tree`,
  `git merge-base`, `git merge-base --is-ancestor`, `git commit-tree`, `git update-ref`,
  `git symbolic-ref`, `git rev-parse`, `git for-each-ref`.

## Recommendations

1. **Reuse `rsp_move_commit_onto_new_parent` for both detection and recompute**, per the
   recommended reading of PD7's "merging the parent into it yields the base's own tree" test
   (Findings, ambiguity 1). This keeps PD6's "one primitive serves both the first cut and every
   restack" intent literally true for Phase 4 as well, rather than introducing a second
   merge-tree wrapper.
2. **Split the disagreement refusal into two cases with two distinct reasons** (Findings,
   ambiguity 2): reuse exit 49 (`unknown_remote_commit`) unchanged for any stack branch
   `restack` is about to move whose remote-tracking ref holds an unexplained commit, and add one
   new, separately-named exit code for the review base's own local-vs-remote-tracking
   disagreement. Reusing one code for both would make a refusal message ambiguous about which
   ref disagreed, working against the task's own "refuses, naming the path" requirement.
3. **Allocate new exit codes starting at 53** (the next free value after `record_request_entry_not_found`/52), at minimum for: the review base's remote-tracking-ref-absent refusal, and the review-base-ref-disagreement refusal recommended in item 2. Update the script's own header exit-code table (lines ~95-115) in the same edit, since it is this script's authoritative, self-contained documentation of its own exit codes and is itself inside this task's `file_scope`.
4. **Add the missing `elif [ "$subcommand" = "restack" ] && [ -n "$stack_id" ]` dispatch arm**, parallel to `show`/`record-request`, and reuse exit 41 (`stack_id_required`) for a `restack` invocation given with no `--stack-id`, rather than introducing a fourth near-duplicate reason string for the same situation.
5. **Parse `--merged NN` as a new, separate flag**, keeping it lexically and semantically distinct from the existing `--merge` (cut-only, task-pair-forcing) flag in both the parser and the header comment, to avoid the two being confused by a future reader or operator.
6. **Enforce the remote-tracking-ref-absent refusal unconditionally**, even when `--merged NN` is supplied (Findings, ambiguity 3) — `--merged NN` should only ever change which already-visible entry is treated as merged, never substitute for the ref this script is constitutionally forbidden from fetching.
7. **Extend `show`'s human-readable output to print `state`** once `restack` can write a non-default value, so an operator can see which entries have already merged without passing `--json`. Small, in-scope, and arguably required for the operator-facing workflow PD8 describes.
8. **Build the four plan-required suite fixtures using the existing `git update-ref`-only simulation technique** already proven by the Phase 3 moved-base and unknown-remote-commit cases (Findings' scaffolding subsection) — no real push, fetch, or `git merge` invocation is needed anywhere in the new fixtures, keeping both the production code and the test fixtures within the same no-network, no-merge discipline the static assertions enforce on the former.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|-------------|
| PD7's "the parent" / "a local review ref" wording is read differently during implementation than this report's recommendation, producing a detection or refusal that doesn't match what a later suite case expects | M | M | This report's recommended readings (Findings, ambiguities 1-2) should be restated explicitly as plan-level decisions before implementation starts, not left to be re-derived from PD7's prose a second time. |
| `--merged NN` is implemented as bypassing the remote-tracking-ref-absent refusal, silently weakening the "never fetches" constraint | H | L | Recommendation 6 states the required ordering explicitly; a suite case asserting the refusal fires even with `--merged NN` supplied and no remote-tracking ref present would catch a regression here. |
| A new exit code collides with one already reserved by a concurrent sibling task editing the same file | L | L | Task 691's `file_scope` is this script alone, with no concurrent sibling in the Territory block touching it (siblings 692/693 touch unrelated files); still, re-read the live exit-code table immediately before allocating new numbers, per the territory contract's general re-read-before-editing rule. |
| Reusing exit 49 for the review base's own ref disagreement (rather than splitting as recommended) produces an ambiguous refusal message that satisfies the suite's exit-code assertion but not the task's "naming the path" requirement in spirit | M | L | Recommendation 2 names this explicitly; the plan should require the refusal message's reason string, not just its exit code, to say which kind of ref disagreed. |

## Context Extension Recommendations

- **Topic**: `restack`'s eventual implementation detail (the final exit-code table, the
  `--merged` flag's final semantics, and the `state: merged` manifest value).
- **Gap**: `context/standards/repo-level-declarations.md`'s `review_base` section documents only
  PD1's cut-time refusals (exit codes 10-13); it has no mention of restack-time refusals because
  Phase 4 had not landed when that section was last written, and this phase's own `file_scope`
  does not include that doc.
- **Recommendation**: once Phase 4 lands, a later, separately-scoped record (or Phase 7's own
  redeploy/doc-reconciliation pass, which already has `index-entries.json` line-count
  reconciliation in its own file_scope) should extend that section with a parallel table for the
  restack-specific exit codes, mirroring the PD1 table's shape. This report does not create that
  task; it only notes the gap it will leave behind.

## Appendix

- Script line references (subject to drift on edit, given as of this research pass):
  header/exit codes 1-115; `rsp_resolve_review_base` 197-224; `rsp_resolve_remote` 228-247;
  `rsp_move_commit_onto_new_parent` 878-892; `rsp_manifest_field` 944-951; `rsp_cut_execute`
  955-1060 (including the `unknown_remote_commit` guard and the manifest-write jq pipeline);
  `rsp_show_stack` 1062-1086; flag parser 1140-1178; subcommand dispatch 1205-1218.
- Parent plan Phase 4 section: `specs/685_stack_pr_submission_from_integration_branch/plans/01_stack-pr-submission.md`, lines 439-485. PD6/PD7/PD8/PD9 decisions: same file, lines 148-166.
- `please-grant.sh` accepted push-grant text forms: `agent-system/extensions/core/hooks/please-grant.sh`, lines 113-130.
- `refs/remotes/<remote>/HEAD` idiom source: `agent-system/extensions/core/scripts/lib/push-grant-lib.sh`, lines 227-230.
- Static suite assertions: `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh`, lines 689-700.
- Task 691's `file_scope`, read from `specs/state.json` (`active_projects[]` entry with `project_number == 691`).

## Search Queries / Methods Used

- `grep`/`sed` over `review-stack-prepare.sh` for function names, exit codes, and every
  `merge-tree`/`merge-base`/`update-ref`/`commit-tree` call site.
- `grep` over the test suite for existing fixture helpers and the two static-assertion regexes.
- `grep` over the wider `agent-system/extensions/core/` tree for `force-with-lease` and
  `refs/remotes/.*HEAD` to locate the existing `remote set-head`/default-branch idiom, since it
  is not present in `review-stack-prepare.sh` itself yet.
- `python3`/`jq` reads of `specs/state.json` to confirm task 691's own `file_scope` and
  distinguish it from a same-titled but numerically different sibling task (694) that also
  quotes this same description text (an expansion artifact noted directly in the dispatch's own
  `User focus` instruction).
