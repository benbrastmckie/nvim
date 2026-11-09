---
description: Analyze memory vault health, score memories for maintenance, and run distillation operations
---

# Command: /distill

**Purpose**: Analyzes the memory vault, scores each memory on staleness/retrieval/size/duplication, generates a health report, and dispatches maintenance and telemetry-sourced sub-modes (purge, merge, compress, refine, gc, auto, revise, learn). The `--meta`, `--review`, and `--dream` sub-modes now live at `/telemetry --meta|--review|--dream` -- they touch no vault store and were moved so they survive this extension's eventual retirement.
**Layer**: 2 (Command File - Argument Parsing Agent)
**Delegates To**: skill-distill mode=distill (direct execution)

**Input**: $ARGUMENTS

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments with sub-mode priority:

    **Sub-Mode Dispatch** (first match wins, 9 sub-modes total):
    1. No arguments (bare invocation) -> Report mode (health report)
    2. `--purge` -> Purge mode (tombstone stale/zero-retrieval memories)
    3. `--merge` -> Merge mode (combine duplicate memories)
    4. `--compress` -> Compress mode (reduce oversized memories)
    5. `--refine` -> Refine mode (improve memory quality)
    6. `--gc` -> Garbage collection (hard-delete tombstoned memories past grace period)
    7. `--auto` -> Automated distillation (Tier 1 refine only)
    8. `--revise` -> Event-and-OTel-correlated memory refactoring proposals
    9. `--learn` -> Retroactive, batch harvest across already-completed tasks

    All 9 sub-modes are available. `--meta`, `--review`, and `--dream` now live at
    `/telemetry --meta|--review|--dream`.

    **Additional Flags**:
    - `--dry-run` -> Show what would happen without making changes
    - `--verbose` -> Show detailed scoring breakdown per memory

    ```
    sub_mode = "report"  # default

    if "--purge" in $ARGUMENTS:
      sub_mode = "purge"
    elif "--merge" in $ARGUMENTS:
      sub_mode = "merge"
    elif "--compress" in $ARGUMENTS:
      sub_mode = "compress"
    elif "--refine" in $ARGUMENTS:
      sub_mode = "refine"
    elif "--gc" in $ARGUMENTS:
      sub_mode = "gc"
    elif "--auto" in $ARGUMENTS:
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
      Check if the requested sub-mode is implemented. All 9 sub-modes are available; each
      row's "Section" column is the durable anchor into `skill-distill/SKILL.md` -- never a
      task number, which is ephemeral and renumbered by vault operations:

      | Sub-Mode | Section |
      |----------|---------|
      | report | `## Memory Vault Health Report` |
      | purge | `### Purge Sub-Mode` |
      | merge | `### Sub-Mode: merge` |
      | compress | `### Sub-Mode: compress` |
      | refine | `### Sub-Mode: refine` |
      | gc | `### GC Sub-Mode` |
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
        "sub_mode": "report",
        "health_report": { ... },
        "scores": [ ... ],
        "memory_health": { ... }
      }
    </expected_return>
  </step_2>

  <step_3>
    <action>Present Results</action>
    <process>
      Report mode:
        - Display formatted health report
        - Show vault overview statistics
        - List maintenance candidates by category
        - Show health score with status indicator
        - Suggest next actions based on scores

      Purge mode:
        - Display tombstoned memory count and IDs
        - Show link-scan warnings (stale [[MEM-{slug}]] references)
        - Log purge operation to distill-log.json (type: "purge")
        - Update memory_health in state.json

      Merge mode:
        - Display merged pair count, primary/secondary IDs, overlap scores
        - Show keyword superset verification results per pair
        - Show cross-reference updates performed
        - Log merge operation to distill-log.json (type: "merge")
        - Update memory_health in state.json

      GC mode:
        - Display deleted memory count and IDs
        - Show before/after token counts
        - Log gc operation to distill-log.json (type: "gc")
        - Update memory_health in state.json (decrement total_memories)

      Compress mode:
        - Display compressed memory count and IDs
        - Show per-memory tokens_before, tokens_after, compression_ratio
        - Verify keyword preservation per memory
        - Log compress operation to distill-log.json (type: "compress")
        - Update memory_health in state.json

      Refine mode:
        - Display Tier 1 automatic fixes applied (keyword dedup, summary gen, topic normalize)
        - Present Tier 2 interactive fixes via AskUserQuestion (keyword enrich, category reclassify, topic correct)
        - Log refine operation to distill-log.json (type: "refine")
        - Update memory_health in state.json

      Auto mode:
        - Run Tier 1 refine fixes only (no interactive operations)
        - Display change summary table
        - Log refine operation to distill-log.json (type: "refine", notes: "auto mode")
        - Update memory_health in state.json

      Revise mode:
        - Ingest the unified event store via events-query.sh (never hand-rolled jq), joined on
          `cc_session_id` against OTel outcome records when available
        - If no events exist yet, display the "no events yet" notice as a normal outcome (not an
          error); if OTel is not enabled, display that degraded-path notice separately
        - Display corroborated/contradicted/gap classification with evidence citations, applied
          via existing UPDATE/EXTEND/CREATE/tombstone primitives behind a mandatory
          AskUserQuestion stop
        - Log the revise operation to .memory/revise-log.json (type: "revise")
        - Update memory_health (last_revise, revise_count) in state.json

      Learn mode:
        - Scan already-archived tasks for unharvested memory_candidates
        - Source from the task's transcript within the 30-day window, falling back to
          history.jsonl + archived specs/ artifacts beyond it
        - Present classified candidates via AskUserQuestion; never auto-create memories
        - Log the operation to .memory/learn-harvest-log.json (type: "learn_harvest")
    </process>
  </step_3>

  <step_4>
    <action>Update State and Log</action>
    <process>
      After any distill operation:
      1. Update memory_health in specs/state.json (sub-modes that track their own run
         bookkeeping -- revise, learn -- use their own log file's summary instead; see State
         Integration in skill-distill/SKILL.md)
      2. Append operation entry to the sub-mode's own log file (.memory/distill-log.json for the
         seven hygiene sub-modes; .memory/revise-log.json, .memory/learn-harvest-log.json for the
         two remaining telemetry-sourced sub-modes)
      3. Git commit changes
    </process>
  </step_4>
</workflow_execution>

---

## Error Handling

<error_handling>
  <argument_errors>
    - Unknown flag -> "Unknown flag: {flag}. Available: --purge, --merge, --compress, --refine, --gc, --auto, --revise, --learn, --dry-run, --verbose (--meta/--review/--dream moved to /telemetry)"
    - Unknown sub-mode -> "Unknown sub-mode. Available: /distill (report), /distill --purge, --merge, --compress, --refine, --gc, --auto, --revise, --learn (--meta/--review/--dream moved to /telemetry)"
  </argument_errors>

  <execution_errors>
    - No memories found -> "No memories in vault. Use /learn to add memories first."
    - memory-index.json missing -> "Memory index not found. Run /learn to initialize."
    - memory-index.json stale -> Auto-regenerate via validate-on-read before scoring
    - Skill failure -> Return error details
  </execution_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    - .memory/memory-index.json (scoring input)
    - .memory/10-Memories/*.md (validation, content analysis)
    - .memory/distill-log.json (operation history, seven hygiene sub-modes)
    - specs/state.json (current memory_health)
    - specs/events.jsonl (revise mode only, via events-query.sh -- never hand-rolled jq)
    - Claude Code OTel outcome records (revise mode only, joined on cc_session_id)
    - specs/archive/ and specs/vault/ task directories (learn mode only, unharvested memory_candidates)
    - .memory/revise-log.json (revise mode only, prior run history for --since {last_revise})
  </reads>

  <writes>
    - .memory/distill-log.json (operation log entries, seven hygiene sub-modes)
    - specs/state.json (memory_health field updates)
    - .memory/10-Memories/*.md (frontmatter mutation for purge/refine/revise; deletion for gc; content merge for merge; content compression for compress; new memories for learn)
    - .memory/memory-index.json (status field updates for purge; entry removal for gc; regeneration for merge/compress/refine/auto/revise/learn)
    - .memory/20-Indices/index.md (regeneration for merge/compress/refine/auto/revise/learn)
    - .memory/10-Memories/README.md (regeneration for merge/compress/refine/auto/revise/learn)
    - .memory/revise-log.json (revise mode only, operation log entries)
    - .memory/learn-harvest-log.json (learn mode only, operation log entries)
  </writes>
</state_management>
