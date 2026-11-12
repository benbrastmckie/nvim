---
name: skill-roadmap
description: Thin wrapper that dispatches roadmap-agent to maintain the roadmap_batches/roadmap_notes entries specs/ROADMAP.md renders from, then verifies and commits the result. Invoke for /roadmap command.
allowed-tools: Agent, Bash, Read
---

# Roadmap Skill

Thin wrapper that delegates all roadmap-maintenance judgment to `roadmap-agent`, then performs
this skill's own postflight: verify the render, run `validate-state.sh`, and commit.

**Not task-scoped.** Unlike most skills in this system, `/roadmap` operates on
`specs/state.json`/`specs/ROADMAP.md` directly -- there is no `specs/{NNN}_{SLUG}/` task
directory in play, no `.return-meta.json`, no `.orchestrator-handoff.json`. The delegated agent
reports back via its own final text response (see `agents/roadmap-agent.md`'s
`.orchestrator-handoff.json` section), which this skill reads directly.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/roadmap-entry-template.md` - entry/rendered shape, anti-fluff bound
- Path: `.claude/context/formats/roadmap-format.md` - generation contract
- Path: `.claude/context/patterns/roadmap-update.md` - per-mode caller contract

## Trigger Conditions

- `/roadmap` is invoked, with or without a quoted instruction argument.

---

## Execution Flow

### Stage 1: Session ID and Argument

```bash
source .claude/scripts/lib/common.sh
session_id="$(common_session_id)"
instruction="$1"   # may be empty -- no argument means a full maintenance pass
```

### Stage 2: Invoke `roadmap-agent`

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent -- never `Skill(roadmap-agent)`.

**Required Tool Invocation**:
```
Tool: Agent
Parameters:
  - subagent_type: "roadmap-agent"
  - prompt: [Include session_id and the instruction (or state explicitly that none was given,
             meaning a full maintenance pass over every open, non-terminal task)]
  - description: "Maintain roadmap_batches/roadmap_notes entries"
```

The agent will build its own working picture of the live repository (open tasks, dependency
waves, existing entries), decide batch membership/order/description/rationale and any missing
dependency edges, write its decisions through `state-write.sh` and the `edge_only` arm, invoke
`bash .claude/scripts/roadmap-integration.sh --regenerate` itself, and return a plain-text summary
of what changed and why.

**Self-Execution Fallback**: If this skill performed the maintenance work itself without
spawning `roadmap-agent` (it must not, except as a last resort when the Agent tool is
unavailable), it must perform every step of the agent's own Write Contract exactly as documented
there before proceeding to postflight below.

### Stage 3: Postflight -- Verify

```bash
# Confirm validate-state.sh's Check 13 (roadmap_batches integrity) still passes.
bash .claude/scripts/validate-state.sh specs/state.json || echo "WARNING: validate-state.sh reported findings after /roadmap -- review before committing"

# Confirm specs/ROADMAP.md actually reflects the current state (idempotence sanity check: a
# second --regenerate right now should report no content change).
bash .claude/scripts/roadmap-integration.sh --regenerate --dry-run 2>&1 | grep -q 'no content change' \
  || echo "WARNING: specs/ROADMAP.md does not yet match a fresh --regenerate render -- the agent may not have invoked --regenerate as its final step"
```

If either warning fires, do not silently proceed to commit: surface it in this skill's own
returned summary so the `/roadmap` command's output names the discrepancy rather than hiding it
behind a clean-looking commit.

### Stage 4: Postflight -- Commit

Only the two files `/roadmap` ever touches are staged: `specs/state.json` and
`specs/ROADMAP.md`. Use targeted staging, never a directory or glob pathspec:

```bash
git status --short -- specs/state.json specs/ROADMAP.md
git diff --staged -- specs/state.json specs/ROADMAP.md
commit_msg="roadmap: full maintenance pass"
[ -n "$instruction" ] && commit_msg="roadmap: maintenance pass ($instruction)"
bash .claude/scripts/git-commit-scoped.sh \
  --message "$commit_msg" --session "$session_id" \
  -- specs/state.json specs/ROADMAP.md
```

If neither file has any pending change (the agent's pass found nothing to revise), skip the
commit -- do not force an empty one -- and say so plainly in the returned summary.

---

## MUST NOT (Postflight Boundary)

After `roadmap-agent` returns, this skill MUST NOT:

1. **Perform the roadmap-maintenance judgment itself** - deciding batch membership, order,
   descriptions, rationale, or missing edges is `roadmap-agent`'s job, not this skill's.
2. **Write `specs/state.json`'s `roadmap_batches`/`roadmap_notes` entries** - the agent already
   wrote them through `state-write.sh` before returning.
3. **Invoke `roadmap-integration.sh --regenerate`** - the agent already invoked it as its own
   final step; this skill only verifies the result (Stage 3), never re-renders it.
4. **Modify any file outside `specs/state.json` and `specs/ROADMAP.md`** - both already live
   under `specs/`, and no third file is ever in scope for `/roadmap`.

The postflight phase is LIMITED TO:
- Running `validate-state.sh` and a `--regenerate --dry-run` sanity check (Stage 3)
- Reviewing `git status`/`git diff --staged` for the two in-scope files
- A single scoped `git-commit-scoped.sh` commit of `specs/state.json`/`specs/ROADMAP.md` (or
  skipping it, reported, when nothing changed)

## Output

Return the agent's own summary text directly (what changed and why), followed by this skill's
own postflight result: whether `validate-state.sh` was clean, whether the render was confirmed
fresh, and whether a commit was made (and its message) or skipped because nothing changed.
