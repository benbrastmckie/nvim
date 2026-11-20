---
name: skill-roadmap
description: Thin wrapper that dispatches roadmap-agent to maintain the primary_goals/roadmap_milestones/roadmap_context entries specs/ROADMAP.md renders from, then verifies and commits the result. Invoke for /roadmap command.
allowed-tools: Agent, AskUserQuestion, Bash, Read
---

# Roadmap Skill

Thin wrapper that delegates all roadmap-maintenance judgment to `roadmap-agent`, then performs
this skill's own postflight: verify the render, run `validate-state.sh`, and commit.

**Not task-scoped.** Unlike most skills in this system, `/roadmap` operates on
`specs/state.json` and the roadmap file directly -- there is no `specs/{NNN}_{SLUG}/` task
directory in play, no `.return-meta.json`, no `.orchestrator-handoff.json`. The delegated agent
reports back via its own final text response (see `agents/roadmap-agent.md`'s
`.orchestrator-handoff.json` section), which this skill reads directly.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/roadmap-entry-template.md` - milestone and batch entry shapes, field bounds
- Path: `.claude/context/formats/roadmap-format.md` - generation contract
- Path: `.claude/context/patterns/roadmap-update.md` - per-mode caller contract

## Trigger Conditions

- `/roadmap` is invoked, with or without a quoted instruction argument.

---

## Execution Flow

### Stage 1: Session ID, Argument, and Preflight Classify/Approval Gate

```bash
source .claude/scripts/lib/common.sh
session_id="$(common_session_id)"
instruction="$1"   # may be empty -- no argument means a full maintenance pass
```

Resolve the roadmap's path from the store (`roadmap_context.output_path`, default
`specs/ROADMAP.md`) and classify it before `roadmap-agent` is ever dispatched, so that agent's
own `--regenerate` call always lands on a file the generator owns:

```bash
source .claude/scripts/lib/roadmap-entries-lib.sh
roadmap_path="$(roadmap_entries_output_path specs/state.json)"
verdict="$(bash .claude/scripts/lib/roadmap-preflight-lib.sh classify "$roadmap_path")"
retained_path=""   # set below only when a migration is offered
```

- **`generated`**: proceed straight to Stage 2 -- no question asked, nothing written here.
- **`absent`**: proceed straight to Stage 2 as well. The generator creates the file itself once
  the store holds at least one milestone, and writes nothing while it holds none.
- **`classic`/`stage`/`unknown`**: the file is hand-authored, and the generator refuses to
  overwrite it. Offer the migration behind a single `AskUserQuestion`, with its dry-run
  accounting in hand first:

  ```bash
  retained_path="specs/archive/roadmap-retained-prose-$(date +%Y%m%d).md"
  bash .claude/scripts/migrate-roadmap-to-milestones.sh --dry-run --retained "$retained_path"
  ```

  Exit `3` means an earlier migration is a prerequisite (the script names it): relay that, do
  not dispatch `roadmap-agent`, and stop. Otherwise the question names:
  - the verdict, and that every section of the file stops being hand-edited,
  - the dry run's own accounting, verbatim: batches before and after, items placed in state,
    lines retained, every `WARN` (an item over its field's bound is retained whole, never
    truncated), and the accounting gate's result,
  - where the retained prose goes (the path the dry run printed), and
  - that nothing is written until the gate passes.

  **Why this question lives here and not inside `roadmap-agent`**: `AskUserQuestion` is measured
  categorically withheld from every `Agent`-tool dispatch of a named `subagent_type`,
  independent of frontmatter -- see `agent-frontmatter-standard.md`'s "Tool Withholding from
  Dispatched Subagents" section. Every user-choice point this command needs must therefore be
  collected in *this skill's own execution*, before Stage 2 dispatches `roadmap-agent` -- the
  same shape `skill-meta/SKILL.md` Section 2 already uses for exactly this withholding reason.

  **On approval**: run the migration in this skill's own execution (never inside the dispatched
  agent), with the same retained-prose path:
  ```bash
  bash .claude/scripts/migrate-roadmap-to-milestones.sh --session-id "$session_id" \
    --retained "$retained_path"
  ```
  A non-zero exit is a stop, not something to force: relay the script's own message. On success
  the file is now `generated`; proceed to Stage 2.

  **On decline**: do not dispatch `roadmap-agent`, do not write anything, and return a named
  summary stating that roadmap rendering is blocked pending the migration -- stop here.

Pass only the resolved outcome (the verdict this stage ended on, and whether a migration ran)
into Stage 2's dispatch prompt as context -- never a flag telling the agent to ask anything
itself; the agent performs no asking of its own. The migration places all existing work under
one neutral milestone and draws no boundary of its own; dividing it into real milestones is the
agent's judgment, on this run or a later one.

### Stage 2: Invoke `roadmap-agent`

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent -- never `Skill(roadmap-agent)`.

**Required Tool Invocation**:
```
Tool: Agent
Parameters:
  - subagent_type: "roadmap-agent"
  - prompt: [Include session_id and the instruction (or state explicitly that none was given,
             meaning a full maintenance pass over every open, non-terminal task)]
  - description: "Maintain roadmap milestone entries"
```

The agent will build its own working picture of the live repository (open tasks, dependency
waves, existing entries), decide milestones, batch membership/order/description and any missing
dependency edges, write its decisions through `state-write.sh` and the `edge_only` arm, invoke
`bash .claude/scripts/roadmap-integration.sh --regenerate` itself, and return a plain-text summary
of what changed and why.

**Self-Execution Fallback**: If this skill performed the maintenance work itself without
spawning `roadmap-agent` (it must not, except as a last resort when the Agent tool is
unavailable), it must perform every step of the agent's own Write Contract exactly as documented
there before proceeding to postflight below.

### Stage 3: Postflight -- Verify

```bash
# Confirm validate-state.sh's Check 13 (roadmap entries integrity) still passes.
bash .claude/scripts/validate-state.sh specs/state.json || echo "WARNING: validate-state.sh reported findings after /roadmap -- review before committing"

# Confirm the roadmap file actually reflects the current state (idempotence sanity check: a
# second --regenerate right now should report no content change).
bash .claude/scripts/roadmap-integration.sh --regenerate --dry-run 2>&1 | grep -q 'no content change' \
  || echo "WARNING: the roadmap file does not yet match a fresh --regenerate render -- the agent may not have invoked --regenerate as its final step. Re-check Stage 1's preflight classify first: if the verdict is not generated (or absent with no milestone in state), that is the first thing to repair before anything downstream of --regenerate."
```

If either warning fires, do not silently proceed to commit: surface it in this skill's own
returned summary so the `/roadmap` command's output names the discrepancy rather than hiding it
behind a clean-looking commit.

### Stage 4: Postflight -- Commit

Only the files `/roadmap` touches are staged: `specs/state.json`, the roadmap file at its
resolved path, and -- only when Stage 1 ran a migration -- the retained-prose file it wrote. Use
targeted staging, never a directory or glob pathspec:

```bash
paths=(specs/state.json "$roadmap_path")
[ -n "$retained_path" ] && [ -f "$retained_path" ] && paths+=("$retained_path")
git status --short -- "${paths[@]}"
git diff --staged -- "${paths[@]}"
commit_msg="roadmap: full maintenance pass"
[ -n "$instruction" ] && commit_msg="roadmap: maintenance pass ($instruction)"
bash .claude/scripts/git-commit-scoped.sh \
  --message "$commit_msg" --session "$session_id" \
  -- "${paths[@]}"
```

If no staged path has any pending change (the agent's pass found nothing to revise), skip the
commit -- do not force an empty one -- and say so plainly in the returned summary.

---

## MUST NOT (Postflight Boundary)

After `roadmap-agent` returns, this skill MUST NOT:

1. **Perform the roadmap-maintenance judgment itself** - deciding milestones, batch membership,
   order, descriptions, or missing edges is `roadmap-agent`'s job, not this skill's.
2. **Write `specs/state.json`'s `primary_goals`/`roadmap_milestones`/`roadmap_context` entries** -
   the agent already wrote them through `state-write.sh` before returning.
3. **Invoke `roadmap-integration.sh --regenerate`** - the agent already invoked it as its own
   final step; this skill only verifies the result (Stage 3), never re-renders it. **Carve-out**:
   this boundary is scoped to *after* `roadmap-agent` returns (per the section heading above).
   Stage 1's approved migration (`migrate-roadmap-to-milestones.sh`) runs *before* dispatch: it
   is mechanical, draws no milestone boundary, and writes the generated file as its own last
   step. This item still forbids this skill calling `--regenerate` itself.
4. **Modify any file outside `specs/state.json`, the roadmap file, and a migration's
   retained-prose file** - no other file is ever in scope for `/roadmap`.

The postflight phase is LIMITED TO:
- Running `validate-state.sh` and a `--regenerate --dry-run` sanity check (Stage 3)
- Reviewing `git status`/`git diff --staged` for the in-scope files
- A single scoped `git-commit-scoped.sh` commit of those files (or skipping it, reported, when
  nothing changed)

## Output

Return the agent's own summary text directly (what changed and why), followed by this skill's
own postflight result: whether `validate-state.sh` was clean, whether the render was confirmed
fresh, and whether a commit was made (and its message) or skipped because nothing changed.
