---
description: Run memory vault auto-maintenance, or telemetry-sourced revise/learn sub-modes against the hosted knowledge store
---

# Command: /distill

**Purpose**: Dispatches `/distill`'s three surviving sub-modes: `--auto` (automated, local
vault scoring and Tier 1 refine fixes) and the two telemetry-sourced sub-modes retargeted onto
the hosted Sapience knowledge store (`--revise`, `--learn`). Consolidation and compaction,
staleness re-confirmation of load-bearing positions, and active conflict detection between a
person's own notes are performed server-side by the hosted store, so `/distill` provides none of
those operations locally -- see `context/project/memory/distill-usage.md` for the full reasoning.
The `--meta`, `--review`, and `--dream` sub-modes live at `/telemetry --meta|--review|--dream` --
they touch no vault store and were moved so they survive this extension's eventual retirement.
**Layer**: 2 (Command File - Argument Parsing Agent)
**Delegates To**: skill-distill mode=distill (direct execution)

**Input**: $ARGUMENTS

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments with sub-mode priority:

    **Sub-Mode Dispatch** (first match wins, 3 sub-modes total):
    1. `--auto` -> Automated distillation (Tier 1 refine only)
    2. `--revise` -> Event-and-OTel-correlated review of hosted knowledge objects
    3. `--learn` -> Retroactive, batch harvest across already-completed tasks
    4. No arguments and no recognized sub-mode flag -> print sub-mode usage and exit; there is no
       default sub-mode.

    **Additional Flags**:
    - `--dry-run` -> Show what would happen without making changes
    - `--verbose` -> Show detailed scoring breakdown per memory (`--auto` only)

    ```
    sub_mode = ""  # no default

    if "--auto" in $ARGUMENTS:
      sub_mode = "auto"
    elif "--revise" in $ARGUMENTS:
      sub_mode = "revise"
    elif "--learn" in $ARGUMENTS:
      sub_mode = "learn"

    dry_run = "--dry-run" in $ARGUMENTS
    verbose = "--verbose" in $ARGUMENTS
    ```
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Validate Sub-Mode Availability</action>
    <process>
      If `sub_mode` is empty, print the Bare-Invocation Usage block below and exit without
      dispatching to the skill. Otherwise check the requested sub-mode's section; each row's
      "Section" column is the durable anchor into `skill-distill/SKILL.md` -- never a task
      number, which is ephemeral and renumbered by vault operations:

      | Sub-Mode | Section |
      |----------|---------|
      | auto | `### Sub-Mode: auto` |
      | revise | `### Sub-Mode: revise` |
      | learn | `### Sub-Mode: learn` |

      `--meta`, `--review`, and `--dream` are dispatched by `/telemetry` instead -- see
      `skill-telemetry/SKILL.md` (core extension).
    </process>
  </step_1>

  <step_2>
    <action>Delegate to Distill Skill</action>
    <input>
      - skill: "skill-distill"
      - args: "mode=distill, sub_mode={sub_mode}, dry_run={dry_run}, verbose={verbose}"
    </input>
    <expected_return>
      {
        "status": "completed",
        "mode": "distill",
        "sub_mode": "auto",
        "memory_health": { ... }
      }
    </expected_return>
  </step_2>

  <step_3>
    <action>Present Results</action>
    <process>
      Auto mode:
        - Run Tier 1 refine fixes only (no interactive operations)
        - Display change summary table
        - Log refine operation to distill-log.json (type: "refine", notes: "auto mode")
        - Update memory_health in state.json

      Revise mode:
        - Ingest the unified event store via events-query.sh (never hand-rolled jq), joined on
          `cc_session_id` against OTel outcome records when available
        - Run the mandatory hosted-store reachability probe before any classification
        - If no events exist yet, display the "no events yet" notice as a normal outcome (not an
          error); if OTel is not enabled, display that degraded-path notice separately; if the
          reachability probe fails, display that degraded-path notice and classify nothing as a
          gap
        - Display corroborated/contradicted/gap classification with evidence citations, applied
          via `sapience-remember.sh` (SUPERSEDE/CREATE) behind a mandatory AskUserQuestion stop
        - Append the revise run record to specs/events.jsonl via events-append.sh
        - Touches no `memory_health` field and no file under `.memory/`

      Learn mode:
        - Scan already-archived tasks for unharvested memory_candidates
        - Source from the task's transcript within the 30-day window, falling back to
          history.jsonl + archived specs/ artifacts beyond it
        - Present classified candidates via AskUserQuestion; never auto-create a knowledge object
        - Write confirmed candidates via `sapience-remember.sh`, bounded to 3-8 notes per
          archived task
        - Append the learn-harvest run record to specs/events.jsonl via events-append.sh
        - Touches no `memory_health` field and no file under `.memory/`
    </process>
  </step_3>

  <step_4>
    <action>Update State and Log</action>
    <process>
      After `--auto`:
      1. Update memory_health in specs/state.json
      2. Append operation entry to .memory/distill-log.json
      3. Git commit changes

      After `--revise` or `--learn`:
      1. Append one run-record event to specs/events.jsonl via events-append.sh (no
         memory_health update, no .memory/ write -- see State Integration in
         skill-distill/SKILL.md)
      2. Git commit changes
    </process>
  </step_4>
</workflow_execution>

---

## Bare-Invocation Usage

When `sub_mode` is empty (no recognized sub-mode flag given), print this and exit -- there is no
default sub-mode, because every surviving sub-mode either mutates the vault (`auto`) or requires
an interactive gate (`revise`, `learn`), and silently defaulting to one would be wrong:

```
/distill requires a sub-mode flag:
  --auto     Automated local vault scoring and Tier 1 refine fixes
  --revise   Event-and-OTel-correlated review of hosted knowledge objects (interactive)
  --learn    Retroactive batch harvest across already-completed tasks (interactive)

(--meta, --review, --dream moved to /telemetry)
```

---

## Error Handling

<error_handling>
  <argument_errors>
    - `--purge`, `--merge`, `--compress`, `--refine`, or `--gc` given -> "Not available: the
      hosted knowledge store already performs consolidation, compaction, staleness
      re-confirmation, and conflict detection server-side (see
      context/project/memory/distill-usage.md). Available: --auto, --revise, --learn."
    - Unknown flag -> "Unknown flag: {flag}. Available: --auto, --revise, --learn, --dry-run,
      --verbose (--meta/--review/--dream moved to /telemetry)"
    - Unknown sub-mode -> print the Bare-Invocation Usage block above
  </argument_errors>

  <execution_errors>
    - No memories found (`--auto` only) -> "No memories in vault. Use /learn to add memories
      first."
    - memory-index.json missing (`--auto` only) -> "Memory index not found. Run /learn to
      initialize."
    - memory-index.json stale (`--auto` only) -> Auto-regenerate via validate-on-read before
      scoring
    - Hosted store unreachable (`--revise` only) -> announce the degraded path per the
      reachability probe; classify nothing as a gap this run
    - Skill failure -> Return error details
  </execution_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    - .memory/memory-index.json (scoring input, `--auto` only)
    - .memory/10-Memories/*.md (validation, content analysis, `--auto` only)
    - .memory/distill-log.json (operation history, `--auto` only)
    - specs/state.json (current memory_health, `--auto` only)
    - specs/events.jsonl (`--revise` only, via events-query.sh -- never hand-rolled jq)
    - Claude Code OTel outcome records (`--revise` only, joined on cc_session_id)
    - Hosted Sapience knowledge store (`--revise` only, via sapience-retrieve.sh)
    - specs/archive/ and specs/vault/ task directories (`--learn` only, unharvested
      memory_candidates)
  </reads>

  <writes>
    - .memory/distill-log.json (operation log entries, `--auto` only)
    - specs/state.json (memory_health field updates, `--auto` only)
    - .memory/10-Memories/*.md (frontmatter mutation, `--auto` only)
    - .memory/memory-index.json (regeneration, `--auto` only)
    - .memory/20-Indices/index.md (regeneration, `--auto` only)
    - .memory/10-Memories/README.md (regeneration, `--auto` only)
    - Hosted Sapience knowledge store (`--revise`/`--learn`, via sapience-remember.sh)
    - specs/events.jsonl (`--revise`/`--learn` run records, via events-append.sh)
  </writes>
</state_management>
