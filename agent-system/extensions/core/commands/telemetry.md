---
description: Surface cross-repo agent-system improvement proposals, speculative themes from prompt history, and ad hoc telemetry inquiries
---

# Command: /telemetry

**Purpose**: Hosts the three vault-independent telemetry sub-modes -- `--meta` (cross-repo
agent-system improvement proposals, delegated to `meta-builder-agent`), `--review` (read-only ad
hoc inquiry over all four telemetry source tiers), and `--dream` (speculative direction-finding
over the user's own prompt history). None of these three touches the memory vault; each reads
`specs/events.jsonl`, `~/.claude/history.jsonl`, session transcripts, and Claude Code OTel
(when enabled), and either reports or proposes.
**Layer**: 2 (Command File - Argument Parsing Agent)
**Delegates To**: skill-telemetry (direct execution)

**Input**: $ARGUMENTS

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments with sub-mode priority:

    **Sub-Mode Dispatch** (first match wins, 3 sub-modes total):
    1. No arguments (bare invocation) -> Error: a sub-mode flag is required (see Error Handling)
    2. `--meta` -> Cross-repo agent-system improvement proposals, delegated to `meta-builder-agent`
    3. `--review "<question>"` -> Read-only ad hoc inquiry over all four telemetry source tiers
    4. `--dream` -> Speculative direction-finding over `history.jsonl`'s recurring themes

    All 3 sub-modes are available.

    **Additional Flags**:
    - `--dry-run` -> Show what would happen without making changes (no-op for `--review`, which
      never writes)
    - `--verbose` -> Show detailed evidence breakdown
    - `--local` -> `--meta` only: scope to the invoking repo instead of `$GLOBAL_ROOT`'s
      cross-repo default

    ```
    sub_mode = null  # no default; a bare invocation is an error for this command

    if "--meta" in $ARGUMENTS:
      sub_mode = "meta"
    elif "--review" in $ARGUMENTS:
      sub_mode = "review"
      question = {text following --review, quoted}
    elif "--dream" in $ARGUMENTS:
      sub_mode = "dream"

    dry_run = "--dry-run" in $ARGUMENTS
    verbose = "--verbose" in $ARGUMENTS
    local_scope = "--local" in $ARGUMENTS   # --meta only
    ```
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Validate Sub-Mode Availability</action>
    <process>
      Check if the requested sub-mode is implemented. All 3 sub-modes are available; each row's
      "Section" column is the durable anchor into `skill-telemetry/SKILL.md` -- never a task
      number, which is ephemeral and renumbered by vault operations:

      | Sub-Mode | Section |
      |----------|---------|
      | meta | `### Sub-Mode: meta` |
      | review | `### Sub-Mode: review` |
      | dream | `### Sub-Mode: dream` |
    </process>
  </step_1>

  <step_2>
    <action>Delegate to Telemetry Skill</action>
    <input>
      - skill: "skill-telemetry"
      - args: "sub_mode={sub_mode}, question={question or null}, dry_run={dry_run}, verbose={verbose}, local_scope={local_scope}"
    </input>
    <expected_return>
      {
        "status": "completed",
        "sub_mode": "meta",
        "candidates": [ ... ],
        "task_numbers_created": [ ... ]
      }
    </expected_return>
  </step_2>

  <step_3>
    <action>Present Results</action>
    <process>
      Meta mode:
        - Resolve target_root via $GLOBAL_ROOT (or --local for the invoking repo only)
        - Surface recurring agent-system improvement candidates via AskUserQuestion (Create as
          task / Note in report only / Skip), delegating any task creation to meta-builder-agent
        - State the single-repo signal limitation in the output
        - Log the meta operation to specs/telemetry/meta-log.json (type: "meta")

      Review mode:
        - Strictly read-only: answer the user's free-text question by querying whichever of the
          four source tiers are relevant, with evidence citations naming the tier
        - No AskUserQuestion mutation gate (nothing mutates) -- state this exemption in output
        - When Tier 1 (OTel) is unavailable, announce the degraded path explicitly: "OTel not
          enabled for this session/repo -- outcome evidence unavailable for this question."
        - Funnel any actionable finding to --meta, /distill --revise, or /learn -- never act
          directly

      Dream mode:
        - Read history.jsonl (global), sliced to this repo via each line's `project` field
        - Surface recurring themes/interests with no existing memory or task coverage
        - No AskUserQuestion mutation gate (nothing mutates) -- state this exemption in output
        - Funnel any actionable finding to --meta or /learn -- never act directly
        - Log the dream operation to specs/telemetry/dream-log.json (type: "dream")
    </process>
  </step_3>

  <step_4>
    <action>Update Log</action>
    <process>
      After any telemetry operation:
      1. Append the operation entry to the sub-mode's own log file under `specs/telemetry/`
         (`meta-log.json`, `dream-log.json`; `review-log.json` only when `--review` opts into its
         optional audit log)
      2. Git commit changes, where the sub-mode itself wrote anything (meta/dream log entries;
         `--review` never writes, so there is nothing to commit for a plain inquiry)
    </process>
  </step_4>
</workflow_execution>

---

## Error Handling

<error_handling>
  <argument_errors>
    - No sub-mode flag given -> "Usage: /telemetry --meta | --review \"<question>\" | --dream"
    - Unknown flag -> "Unknown flag: {flag}. Available: --meta, --review, --dream, --dry-run, --verbose, --local"
    - `--review` with no question text -> "Usage: /telemetry --review \"<question>\""
  </argument_errors>

  <execution_errors>
    - `--meta`: zero deviation/blocker/reflection signal at target_root -> "No agent-system
      improvement signal found in this repo's specs/events.jsonl or reflections. Nothing to
      propose this run."
    - `--dream`: zero prompts for this repo -> "No prompt history found for this repo in
      history.jsonl. Nothing to dream over yet."
    - `--review`: a tier is unavailable -> display that tier's own stated degraded-path message
      (see `context/patterns/telemetry-review-submode.md`'s per-tier table) rather than failing
      the whole inquiry
    - Skill failure -> Return error details
  </execution_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    - specs/events.jsonl (via events-query.sh exclusively -- never hand-rolled jq)
    - ~/.claude/history.jsonl (dream and review modes, global, sliced via each line's project field)
    - Session transcripts and `.meta.json` sidecars (review mode, 30-day replay window)
    - Claude Code OTel outcome records, when `CLAUDE_CODE_ENABLE_TELEMETRY=1` (review mode; meta
      and dream do not use OTel)
    - specs/TODO.md (dream mode, existing-coverage check, unconditional)
    - the memory vault's own index, when present (dream mode, existing-coverage check -- see
      `context/patterns/telemetry-dream-submode.md` for the exact conditional path)
    - specs/telemetry/meta-log.json (meta mode, prior run history)
    - specs/telemetry/dream-log.json (dream mode, prior run history -- this log is dream's sole
      `--since` cursor)
  </reads>

  <writes>
    - specs/telemetry/meta-log.json (meta mode only, operation log entries)
    - specs/telemetry/dream-log.json (dream mode only, operation log entries)
    - specs/telemetry/review-log.json (review mode only, optional audit log)
    - specs/{NNN}_{SLUG}/ task directories (meta mode only, delegated to meta-builder-agent --
      this command never writes them directly)
  </writes>
</state_management>
