---
description: Review the books convention's accumulated observation evidence, or propose research-and-revision tasks against it
---

# Command: /books

**Purpose**: Turns the accumulated books observation records into (i) a read-only performance review of the books convention (`--review`) or (ii) an interactive proposal of research-and-revision tasks against that convention (`--revise`). Mirrors `/distill`'s sub-mode shape: this file parses flags only, every sub-mode's full behavior lives in `skill-books-review`.
**Layer**: 2 (Command File - Argument Parsing Agent)
**Delegates To**: skill-books-review mode=books (direct execution)

**Input**: $ARGUMENTS

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments with sub-mode priority:

    **Sub-Mode Dispatch** (first match wins, 2 sub-modes total):
    1. `--review` -> Review mode (strictly read-only convention performance review)
    2. `--revise` -> Revise mode (interactive proposal of research-and-revision tasks)

    **No default.** Unlike `/distill`'s bare invocation (which defaults to a health-report
    mode), a bare `/books` invocation prints a usage message and exits non-zero rather than
    defaulting to either sub-mode. This is a deliberate divergence, not an oversight: no "books
    health report" analogue is specified anywhere in this command's deliverable set, so there is
    nothing a default could sensibly run.

    **Additional Flags**:
    - `--dry-run` -> Show what would happen without making changes. Meaningful for `--revise`
      (suppresses task creation and the watermark advance); an accepted no-op for `--review`,
      which never writes anything beyond its own dated report regardless of this flag.
    - `--verbose` -> Show detailed per-dimension / per-candidate breakdown.

    ```
    sub_mode = null  # no default

    if "--review" in $ARGUMENTS:
      sub_mode = "review"
    elif "--revise" in $ARGUMENTS:
      sub_mode = "revise"

    dry_run = "--dry-run" in $ARGUMENTS
    verbose = "--verbose" in $ARGUMENTS
    ```

    If `sub_mode` is still `null` after parsing (bare invocation, or an invocation with neither
    flag), do NOT delegate. Print the usage message from Error Handling below and exit non-zero.
  </step_1>
</argument_parsing>

---

## Read-Only vs. Mutating, At A Glance

| Sub-Mode | Writes | Proposes |
|----------|--------|----------|
| `--review` | Its own dated report only (`specs/`) | Nothing — it names strong candidates and tells the user to run `--revise` |
| `--revise` | Task entries (via `/task`), after a lead-session confirmation gate; the watermark cursor | Research-and-revision tasks, reconciled against the open backlog first |

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Validate Sub-Mode Availability</action>
    <process>
      Check if the requested sub-mode is implemented. Both sub-modes are available; each row's
      "Section" column is the durable anchor into `skill-books-review/SKILL.md` -- never a task
      number, which is ephemeral and renumbered by vault/backlog operations:

      | Sub-Mode | Section |
      |----------|---------|
      | review | `### Sub-Mode: review` |
      | revise | `### Sub-Mode: revise` |
    </process>
  </step_1>

  <step_2>
    <action>Delegate to Books Review Skill</action>
    <input>
      - skill: "skill-books-review"
      - args: "mode=books, sub_mode={sub_mode}, dry_run={dry_run}, verbose={verbose}"
    </input>
    <expected_return>
      Review mode:
      {
        "status": "completed",
        "mode": "books",
        "sub_mode": "review",
        "report_path": "specs/....md",
        "funnel_candidates": [ ... ]
      }

      Revise mode:
      {
        "status": "completed",
        "mode": "books",
        "sub_mode": "revise",
        "proposals": { "surfaced": 0, "created_as_task": 0, "noted_only": 0, "skipped": 0, "task_numbers_created": [] }
      }
    </expected_return>
  </step_2>

  <step_3>
    <action>Present Results</action>
    <process>
      Review mode:
        - Display the per-dimension figures-and-trends summary (never adjectives)
        - Display the WHAT IS UNMEASURED section explicitly
        - Display cost per task/phase kind, with the capture-time caveat stated
        - Display recurring issue classes, ranked
        - Display burdens created vs. burdens lifted, paired
        - Close by naming the strongest candidates and telling the user to run `/books --revise`

      Revise mode:
        - Every multiSelect, per-candidate choice, and confirmation gate executes in THIS lead
          session (`skill-books-review` carries no `Agent` tool; `AskUserQuestion` is not
          reachable from a dispatched subagent on this harness) -- never report these as having
          been delegated
        - Display backlog reconciliation outcomes (create / widen / dependency edge / narrow
          scope) per candidate before the final confirmation gate
        - Display the watermark advance (or its explicit non-advance on dry-run/abort)
    </process>
  </step_3>

  <step_4>
    <action>Update State and Log</action>
    <process>
      After `--revise` creates any task: those tasks' own TODO.md/state.json entries are written
      by the `/task` primitive during delegation, not by this command. After either sub-mode
      completes: report the sub-mode's own log write (the dated report path for `--review`; the
      `specs/books-evidence/revise-log.json` watermark entry for `--revise`) and git commit per
      the normal artifact-commit convention.
    </process>
  </step_4>
</workflow_execution>

---

## Error Handling

<error_handling>
  <argument_errors>
    - No flag (bare invocation) -> "Usage: /books --review | /books --revise [--dry-run] [--verbose]. There is no default sub-mode: /books --review reports on the convention, /books --revise proposes research-and-revision tasks against it." Exit non-zero; do not delegate.
    - Unknown flag -> "Unknown flag: {flag}. Available: --review, --revise, --dry-run, --verbose"
    - Both `--review` and `--revise` given -> first match wins per the Sub-Mode Dispatch order above (`--review`); this is stated for completeness, not expected to occur in practice
  </argument_errors>

  <execution_errors>
    - No observation records found (`specs/books-evidence/observations.jsonl` absent or empty) -> the skill reports this as its own named early-return message (see `books-review-submode.md` / `books-revise-submode.md`); this command does not pre-check it itself
    - Skill failure -> Return error details
  </execution_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    - `specs/books-evidence/observations.jsonl` (the digest log both sub-modes start from)
    - `specs/{NNN}_{SLUG}/book.observation.json` (the canonical per-task record each digest line points to)
    - `specs/books-evidence/runs.jsonl` (when present; RUN-log-derived fields)
    - `docs/book-convention.md` (the consuming repository's decision record; `--revise` only, mandatory)
    - `specs/books-evidence/revise-log.json` (the watermark cursor; `--revise` only)
    - `specs/state.json` (`active_projects`, for backlog reconciliation; `--revise` only)
  </reads>

  <writes>
    - A dated report under the consuming repository's `specs/` tree (`--review` only; its sole write)
    - `specs/books-evidence/revise-log.json` (`--revise` only, after the confirmed batch, never on dry-run or an aborted confirmation)
    - Task entries, via delegation to the `/task` primitive (`--revise` only, after backlog reconciliation and the final confirmation gate)
  </writes>
</state_management>
