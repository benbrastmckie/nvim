# Mathlib Lookup Gate

The Mathlib-lookup step (querying `lean_leansearch`, `lean_loogle`, `lean_leanfinder`, and
`lean_local_search` for relevant theorems) is mandatory only when the task genuinely has a Lean
target AND the lookup tools are actually registered in the session. Every `formal`-extension
research-agent contract and skill wrapper that mentions the step resolves this gate before
treating the step as an obligation, rather than restating the obligation unconditionally.

## Condition (a): Lean-target signal

True when EITHER of the following holds:

- **`file_scope` branch (primary — the one that actually fires for `formal`-routed agents)**:
  the task's `file_scope` array contains at least one `*.lean` path. A research agent does not
  receive its own `file_scope` from the dispatch file (`orchestrate-build-dispatch.sh` echoes
  only sibling tasks' `file_scope`, for the Territory block), so read it directly:

  ```bash
  jq --arg n "$TASK_NUMBER" \
    '.active_projects[] | select(.project_number==($n|tonumber)) | .file_scope' \
    specs/state.json
  ```

  Note the field name is `project_number`, not `task_number`.

- **`task_type` branch (secondary `OR` form)**: the task's `task_type` names the `lean4`
  extension's own routing value. In practice this branch never fires for the four agents this
  gate covers (`logic-research-agent`, `math-research-agent`, `physics-research-agent`,
  `formal-research-agent`) — they route only under `formal`, `formal:logic`, `formal:math`,
  `formal:physics`, never under `lean4` — but the branch is stated for completeness and for any
  future task type that genuinely combines a `formal` routing with a Lean target.

## Condition (b): tool-registration signal

True when a single `ToolSearch` call for
`select:lean_leansearch,lean_loogle,lean_leanfinder,lean_local_search` returns at least one
match. Make this call ONCE, before attempting the step — it is a pre-step check, never a
recovery action taken after a failed lookup attempt.

## Resolution table

| (a) Lean target | (b) tools registered | Outcome |
|---|---|---|
| false | — | Skip. The step is not applicable; (b) is not even checked. |
| true | false | Skip, as an accepted degraded mode — never a `partial` status. This mirrors the framing `lean-mcp-preflight-check.sh`'s `emit_dispatch_block()` already uses for Lean work proceeding without lean-lsp: a missing tool is a known, tolerated gap, not a task failure. |
| true | true | Mandatory, unchanged. Perform the lookup exactly as the surrounding contract already describes. |

## Skip-log wording

When the gate resolves to skip, add exactly one line to the research report, in the same place
and register as the existing "note that Mathlib lookup was limited" convention — for example:

```
Mathlib lookup skipped: no Lean target (no *.lean path in file_scope, task_type not lean4-routed)
```

or

```
Mathlib lookup skipped: lookup tools not registered in this session (ToolSearch: no match)
```

This skip note does NOT go through `issue-record.sh`. That log stays reserved for genuine
deviations and wins, not for a gate resolving exactly as designed.

## Metadata contract

Alongside the existing `mathlib_lookups_performed` field, carry a `mathlib_lookup_gated` field
taking one of:

- `"performed"` — the gate resolved to perform and the lookup was made.
- `"skipped_no_lean_target"` — condition (a) was false.
- `"skipped_tools_unregistered"` — condition (a) was true but condition (b) was false.

`mathlib_lookups_performed` reads `0` when the gate skipped, rather than being omitted — its
existing integer type is preserved in both the performed and skipped cases.

## Relationship to the tool-failure handling block

The tool-failure handling path (covering a lookup call that errors or times out) applies only
once this gate has already resolved to "perform". It is not a second gate: when this gate
resolves to skip, the tool-failure block is simply not reached.
