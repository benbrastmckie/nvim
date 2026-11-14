---
name: skill-roadmap
description: Thin wrapper that dispatches roadmap-agent to maintain the roadmap_batches/roadmap_notes entries specs/ROADMAP.md renders from, then verifies and commits the result. Invoke for /roadmap command.
allowed-tools: Agent, AskUserQuestion, Bash, Read
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

### Stage 1: Session ID, Argument, and Preflight Classify/Approval Gate

```bash
source .claude/scripts/lib/common.sh
session_id="$(common_session_id)"
instruction="$1"   # may be empty -- no argument means a full maintenance pass
```

Before `roadmap-agent` is ever dispatched, classify `specs/ROADMAP.md` so that agent's own
`--regenerate` call always lands on an already-`classic` (or already-`stage`) file, never on
`absent` or `unknown`:

```bash
verdict="$(bash .claude/scripts/lib/roadmap-preflight-lib.sh classify specs/ROADMAP.md)"
```

- **`classic`/`stage`**: proceed straight to Stage 2 -- no question asked, nothing written here.
- **`absent`/`unknown`**: ask a single `AskUserQuestion` for approval to create (`absent`) or
  repair (`unknown`) the file, before any write. **Why this question lives here and not inside
  `roadmap-agent`**: `AskUserQuestion` is measured categorically withheld from every `Agent`-tool
  dispatch of a named `subagent_type`, independent of frontmatter -- see
  `agent-frontmatter-standard.md`'s "Tool Withholding from Dispatched Subagents" section. Every
  user-choice point this command needs must therefore be collected in *this skill's own
  execution*, before Stage 2 dispatches `roadmap-agent` -- the same shape `skill-meta/SKILL.md`
  Section 2 already uses for exactly this withholding reason.

  The question names:
  - the verdict (`absent`: no roadmap tracked yet; `unknown`: the file exists but its section
    headers match neither the classic nor the stage vocabulary, so `--regenerate` refuses loudly
    rather than guess),
  - what the mechanical skeleton write does (the eight classic headers, `## Goal`/`## Checks
    before and after every call`/`## Settled decisions (do not re-litigate)`/`## Standing
    rules`/`## Unfiled observations (none worth a task yet)` get short honest stubs for the
    owner to fill in by hand; `## Next`/`## Open work` are rendered by `--regenerate`
    immediately afterward), and
  - for `unknown` specifically: that the existing file's full content is preserved verbatim
    under `## Unfiled observations (none worth a task yet)`, never discarded, reordered, or
    reinterpreted.

  **On approval**: run the scaffold in this skill's own execution (never inside the dispatched
  agent):
  ```bash
  bash .claude/scripts/lib/roadmap-preflight-lib.sh scaffold specs/ROADMAP.md
  ```
  The file is now `classic`; proceed to Stage 2.

  **On decline**: do not dispatch `roadmap-agent`, do not write anything, and return a named
  summary stating that roadmap rendering is blocked pending an approved scaffold -- stop here.

Pass only the resolved outcome (the verdict this stage ended on, and whether a scaffold was
written) into Stage 2's dispatch prompt as context -- never a flag telling the agent to ask
anything itself; the agent performs no asking of its own.

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
  || echo "WARNING: specs/ROADMAP.md does not yet match a fresh --regenerate render -- the agent may not have invoked --regenerate as its final step. Re-check Stage 1's preflight classify first: if the verdict has drifted back to absent/unknown since this run's gate, that is the first thing to repair before anything downstream of --regenerate."
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
   final step; this skill only verifies the result (Stage 3), never re-renders it. **Carve-out**:
   this boundary is scoped to *after* `roadmap-agent` returns (per the section heading above).
   Stage 1's preflight scaffold (`roadmap-preflight-lib.sh scaffold`) runs *before* dispatch and
   is not `--regenerate` -- it writes only the mechanical classic skeleton, never a
   `--regenerate` render, and never touches `roadmap_batches`/`roadmap_notes`. This item is
   unaffected by that carve-out; it still forbids this skill calling `--regenerate` itself.
4. **Modify any file outside `specs/state.json` and `specs/ROADMAP.md`** - both already live
   under `specs/`, and no third file is ever in scope for `/roadmap`. Still holds for Stage 1's
   scaffold: it writes `specs/ROADMAP.md`, already in scope, and nothing else.

The postflight phase is LIMITED TO:
- Running `validate-state.sh` and a `--regenerate --dry-run` sanity check (Stage 3)
- Reviewing `git status`/`git diff --staged` for the two in-scope files
- A single scoped `git-commit-scoped.sh` commit of `specs/state.json`/`specs/ROADMAP.md` (or
  skipping it, reported, when nothing changed)

## Output

Return the agent's own summary text directly (what changed and why), followed by this skill's
own postflight result: whether `validate-state.sh` was clean, whether the render was confirmed
fresh, and whether a commit was made (and its message) or skipped because nothing changed.
