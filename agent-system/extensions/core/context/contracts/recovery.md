# Recovery Contract - Fix-Forward Discipline

This contract disambiguates "reach green" / "restore green" / "get back to green" so the
phrase can never again be misread as license to discard uncommitted work. It was authored
after a motivating failure: an orchestrator instruction "if RED, first restore green" was
misread by an implementation agent as "revert to the last green commit", discarding
uncommitted forward progress (new scaffolding and a sorry-count reduction) that had not yet
been committed.

**`--hard`-only for rungs (b)/(c)**: The Recovery Ladder's rung (b) (strategic-sorry skeleton)
and rung (c) (snapshot-then-rollback) mechanics below are loaded exclusively via
`skill-orchestrate`'s hard-mode contract injection (both effort modes' implement dispatches
resolve through this one engine's H1 branch when `hard_mode` is true) and reference
hard-mode-only artifacts (`anti-analysis.md`'s strategic-sorry test, `wrap-up.md`'s
`sorry_inventory` schema). The rung (a) fix-forward
disambiguation statement immediately below carries no hard-mode dependency and is safe to
quote verbatim in standard-mode dispatch prompts and documentation as well.

## "Green" Means Fix Forward

"Reach green" and "restore green" ALWAYS mean: make the current working tree pass its
build/test/verification criteria by adding or correcting code in place.

They NEVER mean: `git reset`, `git checkout -- <path>`, `git restore` (non-`--staged`),
`git clean -fd`, `git stash drop`/`clear`, or any other operation that discards uncommitted
changes to fall back to a prior commit — while uncommitted changes exist.

An agent MUST NOT discard uncommitted work to reach green. If the working tree is RED, the
default and required response is to fix forward: correct the source so the same tree passes,
preserving every line of uncommitted progress already made.

## The Recovery Ladder

Three rungs, tried in order. Each names its actual shipped mechanism — this is not a
paraphrase.

### Rung (a): Fix forward (default)

Correct the source in the current working tree until the build/tests pass again. No external
file, script, or contract is needed for this rung — it is the default behavior for any RED
state and requires no special mechanism beyond ordinary implementation work. Every recovery
attempt starts here.

### Rung (b): Documented strategic-sorry skeleton

**`--hard` only.** If a specific sub-goal is genuinely blocked and rung (a) cannot land the
whole target, land a documented strategic-sorry skeleton instead of discarding structure or
leaving the tree RED. This rung reaches green by shrinking scope, not by reverting.

- The placeholder must meet all five conditions of the strategic-sorry test in
  `.claude/context/contracts/anti-analysis.md` ("Strategic sorries (skeleton division
  points)"): deliberate division boundary, tightly scoped, documented, tracked, build-green.
- The placeholder is recorded in the handoff's `sorry_inventory` using the schema defined in
  `.claude/context/contracts/wrap-up.md` (`{file, line, statement, strategic, assumption,
  why_deferred, follow_up_task}`), with `strategic: true` and a non-null `follow_up_task`.
- An undocumented or untracked sorry is never strategic and does not satisfy this rung — it
  forces `status: "partial"` or `status: "blocked"` per `wrap-up.md`, not `"implemented"`.

### Rung (c): Snapshot, then smallest-scope rollback

**Only if truly required, and only after rungs (a) and (b) have been exhausted or ruled out.**
If a genuine rollback is unavoidable:

1. **Snapshot first.** Run `bash .claude/scripts/git-snapshot.sh <TASK>` — pass TASK
   explicitly rather than relying on inference, which only resolves when exactly one task
   is `implementing`. The default mode reverts the working tree, which is the intended
   handoff here; `--branch` does NOT avoid that revert (it only changes the recovery
   handle from a stash entry to a branch), and `--no-revert` is for defensive checkpoints
   where work continues, not for this rung.
   **Out-of-scope refusal guard**: before reverting, this invocation classifies every
   dirty tracked path against TASK's declared `file_scope` and REFUSES (naming every
   offending path) if any falls outside it — or if TASK has no declared `file_scope` at
   all. This rung's whole-tree rollback is exactly the deliberate case the guard's
   override exists for: run
   `bash .claude/scripts/git-snapshot.sh <TASK> --allow-out-of-scope` when the refusal
   fires and a full-tree revert is genuinely intended.
   (`.claude/scripts/git-snapshot.sh`) before any destructive git operation. This is not
   optional guidance — `.claude/hooks/guard-destructive-git.sh` is a PreToolUse Bash hook that
   blocks `git reset --hard`, `git checkout -- <path>`, `git restore` (non-`--staged`),
   `git clean -fd`, `git stash drop`/`clear`, and forced `git checkout`/`git switch` on a dirty
   tree via `exit 2` unless a fresh snapshot marker exists (see git-workflow.md's "No
   Destructive Git on Uncommitted Work" rule).
2. **Prefer the smallest revert scope.** Roll back the minimum needed (a single file or hunk)
   rather than the whole tree; re-apply anything from the snapshot that turns out to still be
   good.
3. **Never** treat "restore green" as authorization to skip step 1. The snapshot is what makes
   a rollback recoverable instead of destructive.

## Domain Specialization

Rung (b)'s placeholder token is domain-specific: `sorry` in Lean4; `admit`,
`raise NotImplementedError`, or an explicit `-- STUB:` marker in other domains — per
`anti-analysis.md`'s Sub-Sorry Policy. Extensions may declare additional domain-specific
placeholder conventions in their own contract overrides; the fix-forward default (rung a) and
the snapshot-first requirement (rung c, step 1) are domain-agnostic and apply everywhere.
