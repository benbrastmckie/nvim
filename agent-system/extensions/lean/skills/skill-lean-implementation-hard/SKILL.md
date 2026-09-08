---
name: skill-lean-implementation-hard
description: Implement Lean 4 proofs using hard-mode behavioral contracts with per-phase dispatch and sorry inventory tracking. Invoke for Lean-language implementation tasks when hard-mode is requested.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Lean Implementation Hard Skill

Thin wrapper that delegates Lean 4 hard-mode proof implementation to
`lean-implementation-hard-agent` subagent with per-phase dispatch context.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent
returns, this skill handles all postflight operations (status update, artifact linking,
sorry_inventory propagation, git commit) before returning.

Hard mode activates H2 (anti-analysis with formal proof line bar) and H9 (sorry inventory
tracking with orchestrator handoff JSON at every dispatch). Cost is approximately 3-5x
standard lean4 implementation.

## Trigger Conditions

This skill activates when:
- Task type is "lean4" or "lean" (either accepted)
- `/implement N --hard` is invoked for a lean4 task
- Dispatched from `skill-orchestrate`'s hard-mode per-phase dispatch (H1) branch — the
  formerly-separate standalone hard-mode engine that used to own this dispatch is deleted and
  merged into `skill-orchestrate` itself
- Routed by `command-route-skill.sh` via `routing_hard.implement.lean4`

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Task status must allow implementation (planned, implementing, partial)
- Task type must be lean4/lean

```bash
# Lookup task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

# Extract fields
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')

# Validate task_type (accept both "lean" and "lean4")
if [ "$task_type" != "lean" ] && [ "$task_type" != "lean4" ]; then
  return error "Task $task_number is not a Lean task (got: $task_type)"
fi

# Check terminal states
if [ "$status" = "completed" ] || [ "$status" = "abandoned" ] || [ "$status" = "expanded" ]; then
  return error "Task $task_number is in terminal state: $status"
fi
```

---

### Stage 1.5: Hard-Mode Cost Note

Before proceeding, emit the cost note for session tracking:

```
[hard-mode] skill-lean-implementation-hard activated (session flag: hard)
Cost multiplier: ~3-5x standard lean4 implementation
Behavioral contracts: H2 (formal proof line bar), H9 (sorry inventory tracking)
Per-phase dispatch: each agent invocation handles exactly one plan phase
```

---

### Stage 2: Preflight Status Update

Update task status to "implementing" BEFORE invoking subagent.

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
```

---

### Stage 3: Plan Resolution and Phase Identification

Find the latest plan file and identify the next incomplete phase for per-phase dispatch:

```bash
# Find latest plan
padded_num=$(printf "%03d" "$task_number")
# Absolute anchor handed to the dispatched agent. SKILL_REPO_ROOT is exported by skill-base.sh
# when sourced; $(pwd) is a last-resort fallback for direct invocation.
task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/specs/${padded_num}_${project_name}"
handoff_path_abs="${task_dir_abs}/.orchestrator-handoff.json"
plan_file=$(ls "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)

if [ -z "$plan_file" ]; then
  return error "No plan file found for task $task_number"
fi

# Read plan to find next incomplete phase. Sourced from the shared anchor
# (scripts/lib/phase-heading-patterns.sh) rather than re-derived inline -- this also gains
# decimal sub-phase support (e.g. "Phase 3.1"), which the prior digits-only pattern never had.
#
# Leaf-worker posture (the same posture core's own standalone hard-mode implementer skill once
# had in its Stage 3b, before it was merged into skill-orchestrate and deleted): this check runs
# strictly before any Agent tool dispatch, so no handoff write is owed here, and adopts this
# file's own `return error` convention rather than a raw `exit`.
. .claude/scripts/lib/phase-heading-patterns.sh
phase_number=""
phase_scan_inconclusive=false
# --- resume-scan-conformance-gate:begin ---
# Whole-file conformance check BEFORE the filtered scan below. PHASE_HEADING_ERE admits
# conforming headings only, so a non-conforming heading is not merely unmatched by that grep --
# it is INVISIBLE to it, and the scan would silently select the next conforming OPEN heading
# instead, dispatching out of order on top of unfinished work. has_nonconforming_phase_headings
# is the required boolean predicate; the `nonconforming_phase_headings | grep -q .` pipe form is
# forbidden (unsafe under pipefail).
if has_nonconforming_phase_headings "$plan_file"; then
  warn_nonconforming "$plan_file" "lean-implementation-hard-next-phase" || true
  phase_scan_inconclusive=true
else
  # Extract phase number via the library's extract_phase_number rather than the prior PCRE-based
  # lookbehind extraction -- the PCRE grep flag is not available on every platform and was a
  # second, unnecessary divergence from every other consumer of this grammar.
  next_phase_heading=$(grep -E "${PHASE_HEADING_ERE} .*${PHASE_STATUS_OPEN_ERE}" "$plan_file" | head -1)
  if [ -n "$next_phase_heading" ]; then
    phase_number=$(extract_phase_number "$next_phase_heading") || phase_number=""
    if [ -z "$phase_number" ]; then
      # Defense-in-depth only, and unreachable by construction: the grep above already
      # guarantees this line matches PHASE_HEADING_ERE. Funnelled into the same sentinel so
      # there is exactly one inconclusive path, never a second silent one.
      phase_scan_inconclusive=true
    fi
  fi
fi
# --- resume-scan-conformance-gate:end ---

if [ "$phase_scan_inconclusive" = "true" ]; then
  return error "Non-conforming phase heading(s) found during resume-scan -- the filtered scan cannot see them, so the resume point is UNKNOWN. Refusing to guess. See the named, line-numbered warning above."
fi

# Read handoff for per-phase dispatch context (territory, continuation_context)
handoff_file=$(ls "${handoff_path_abs}" 2>/dev/null | head -1)
territory=null
continuation_context=null

if [ -f "$handoff_file" ] && jq empty "$handoff_file" 2>/dev/null; then
  territory=$(jq -c '.territory // null' "$handoff_file")
  continuation_context=$(jq -c '.continuation_context // null' "$handoff_file")
  # Import sorry_inventory from previous handoff for propagation
  prev_sorry_inventory=$(jq -c '.sorry_inventory // []' "$handoff_file")
fi
```

---

### Stage 4: Prepare Delegation Context

Prepare delegation context for the subagent with per-phase dispatch parameters:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-lean-implementation-hard"],
  "timeout": 7200,
  "effort_flag": "hard",
  "compare_flag": {true|false},
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "lean4"
  },
  "plan_path": "specs/{N}_{SLUG}/plans/MM_{short-slug}.md",
  "phase_number": {N_or_null},
  "territory": {territory_or_null},
  "continuation_context": {continuation_context_or_null},
  "metadata_file_path": "specs/{N}_{SLUG}/.return-meta.json",
  "task_dir": "{ABSOLUTE path to the task directory}",
  "handoff_path": "{ABSOLUTE path the agent MUST write its handoff to}",
  "dispatch_seq": "{dispatch_seq from this skill's own delegation context, forwarded unchanged; omit if absent}"
}
```

**Forward `dispatch_seq` unchanged.** If this skill's own delegation context carries a
`dispatch_seq` field, forward it into the sub-agent's delegation context above verbatim — the
same pass-through treatment already given to `territory` and `handoff_path`. Never invent,
increment, or recompute a value at this layer; only the orchestrator mints one. If absent, omit
the field. See `context/patterns/dispatch-report-not-termination.md`.

**Forward `compare_flag` unchanged, and never let it replace `effort_flag`.** `compare_flag` is
forwarded from this skill's own delegation context unchanged and defaults to `false` when
absent, composing with `"effort_flag": "hard"` above rather than competing with it — both fields
are present together whenever `--compare --hard` was passed. It gates the subagent's advisory
Comparator step (see Stage 5 below).

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "lean-implementation-hard-agent"
  - model: "opus"
  - prompt: [Include task_context, delegation_context, plan_path, phase_number,
             territory, continuation_context, metadata_file_path, handoff_path]
  - description: "Execute hard-mode Lean implementation for task {N} phase {P}"
```

**DO NOT** use `Skill(lean-implementation-hard-agent)` - this will FAIL.

The subagent will:
- Apply H2 anti-analysis contract (formal proof line bar within 30% of tool calls)
- Apply H9 wrap-up discipline (sorry_inventory in every dispatch end)
- Implement ONLY the specified phase (per-phase focus)
- Use lean_goal before and after each tactic application
- Use lean_multi_attempt before applying edits
- Run final verification (sorry check, axiom check, lake build — detached, via the build guard,
  see `context/project/lean4/operations/long-builds.md`)
- Write the orchestrator handoff (with sorry_inventory) to the ABSOLUTE path given as
  `handoff_path` in the delegation context — never a bare `.orchestrator-handoff.json` filename
- Create implementation summary
- Run the advisory Comparator gate against the snapshot Challenge and the implemented Solution
  when `compare_flag` is `true` (no-op, no cost, when absent or `false`)
- Write metadata to `specs/{N}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool, you MUST write a
`.return-meta.json` file now before proceeding to postflight.

If you DID use the Agent tool, skip this stage.

---

## Postflight (ALWAYS EXECUTE)

### Stage 6: Parse Subagent Return

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    phases_completed=$(jq -r '.metadata.phases_completed // 0' "$metadata_file")
    phases_total=$(jq -r '.metadata.phases_total // 0' "$metadata_file")

    # Read verification results (agent is responsible for verification)
    verification_passed=$(jq -r '.verification.verification_passed // false' "$metadata_file")
    sorry_count=$(jq -r '.verification.sorry_count // 0' "$metadata_file")

    # Read sorry_inventory from agent output
    sorry_inventory=$(jq -c '.sorry_inventory // []' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
    verification_passed="false"
    sorry_inventory="[]"
fi
```

---

### Stage 6a: Plan Compliance Check (Read from Metadata)

**This stage only runs if status from metadata is "implemented".**

Read the agent-reported compliance result from metadata:

```bash
if [ "$status" = "implemented" ]; then
    compliance_check=$(jq -r '.metadata.compliance_check // "skipped"' "$metadata_file" 2>/dev/null)

    case "$compliance_check" in
        "failed")
            echo "Stage 6a: Plan compliance check FAILED (agent reported)"
            status="partial"
            ;;
        "passed")
            echo "Stage 6a: Plan compliance check PASSED"
            ;;
        "skipped"|*)
            echo "Stage 6a: INFO — compliance_check absent or skipped; proceeding"
            ;;
    esac
fi
```

---

### Stage 6b: Sorry Inventory Propagation

After agent returns, propagate sorry_inventory to `.orchestrator-handoff.json`:

```bash
handoff_file="${handoff_path_abs}"

if [ -f "$handoff_file" ] && jq empty "$handoff_file" 2>/dev/null; then
    # Merge with previous sorry_inventory (prev + new — resolved)
    # The agent writes the authoritative sorry_inventory to the handoff JSON
    echo "Stage 6b: sorry_inventory propagated via agent handoff JSON"
    echo "  Current sorry count: $(echo "$sorry_inventory" | jq 'length')"
else
    echo "Stage 6b: WARNING — no .orchestrator-handoff.json found"
    echo "  Agent should have written this file. Check agent output."
fi
```

---

### Stage 6c: Comparator Verdict Surface (Read from Metadata)

Read the agent-recorded `comparator` block, if any, from metadata and surface it. The
Comparator invocation itself was performed by the agent in its Final Verification Stage — this
stage reads that recorded result and MUST NOT re-run it, per
`context/standards/postflight-tool-restrictions.md`, exactly as Stage 6a above reads
`compliance_check` rather than re-running its grep.

**Placement note**: named `Stage 6c` (not inserted literally between the pre-existing Stage 6a
and Stage 6b) to avoid renumbering every downstream stage in this file; it occupies the same
structural slot — immediately after the plan-compliance read, before task-status update — that
`Stage 6c` occupies in the base `skill-lean-implementation/SKILL.md`.

```bash
comparator_ran=$(jq -r '.comparator.ran // false' "$metadata_file" 2>/dev/null)
comparator_verdict=$(jq -r '.comparator.verdict // ""' "$metadata_file" 2>/dev/null)
comparator_verdict_source=$(jq -r '.comparator.verdict_source // ""' "$metadata_file" 2>/dev/null)
comparator_reason_detail=$(jq -r '.comparator.reason_detail // ""' "$metadata_file" 2>/dev/null)

if [ "$comparator_ran" = "false" ] && [ -z "$comparator_verdict" ]; then
    echo "Stage 6c: INFO — no comparator block recorded (--compare not requested, or agent preflight stopped before invocation); proceeding"
elif [ "$comparator_verdict" = "verified" ]; then
    echo "Stage 6c: Comparator PASS — verdict=verified"
else
    echo "Stage 6c: *** COMPARATOR ADVISORY FINDING ***"
    echo "  verdict: ${comparator_verdict} (verdict_source: ${comparator_verdict_source})"
    echo "  reason_detail: ${comparator_reason_detail}"
    echo "  This is ADVISORY ONLY — completion is proceeding regardless. See the implementation"
    echo "  summary's Comparator section for full detail."
fi
```

**Asymmetry note (deliberate, not an omission)**: unlike Stage 6a's `compliance_check == "failed"`
branch above, which sets `status="partial"`, this stage MUST NOT assign `status` on any
`comparator` verdict, however severe. The gate is advisory-only by binding design decision — see
`### comparator (optional)` in `return-metadata-file.md`.

---

### Stage 7: Update Task Status (Postflight)

**If status is "implemented" AND verification_passed is true AND sorry_count is 0**:

```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id" --phase-check=warn
```

Then add completion_data to state.json:
```bash
completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")

if [ -n "$completion_summary" ]; then
    bash .claude/scripts/state-write.sh \
      '(.active_projects[] | select(.project_number == $num)).completion_summary = $summary' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --arg summary "$completion_summary"
fi

# Add roadmap_items if present (for non-meta tasks only)
if [ "$task_type" != "meta" ] && [ "$roadmap_items" != "[]" ] && [ -n "$roadmap_items" ]; then
    bash .claude/scripts/state-write.sh \
      '(.active_projects[] | select(.project_number == $num)).roadmap_items = $items' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --argjson items "$roadmap_items"
fi
```

**If status is "partial"**:
Keep status as "implementing" but note sorry_inventory and phase progress.
TODO.md stays as `[IMPLEMENTING]`.

**If verification_passed is false**:
Keep status as "implementing" for resume.

---

### Stage 8: Link Artifacts

Add summary artifact to state.json. Update TODO.md per
`@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Summary**`,
`next_field=**Description**`.

```bash
summary_artifact_path=$(jq -r '.artifacts[] | select(.type == "summary") | .path' "$metadata_file" 2>/dev/null | head -1)
summary_artifact_summary=$(jq -r '.artifacts[] | select(.type == "summary") | .summary' "$metadata_file" 2>/dev/null | head -1)

if [ -n "$summary_artifact_path" ]; then
    bash .claude/scripts/state-write.sh \
      '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": "summary", "summary": $summary}]' \
      --session-id "$session_id" \
      --argjson num "$task_number" \
      --arg path "$summary_artifact_path" \
      --arg summary "$summary_artifact_summary"
fi
```

---

### Stage 9: Git Commit

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: complete implementation" \
  --session "${session_id}" \
  --honest-index-rows "${task_number}" \
  -- "Theories/" \
     "specs/${padded_num}_${project_name}/summaries/" \
     "specs/${padded_num}_${project_name}/plans/" \
     "specs/${padded_num}_${project_name}/.orchestrator-handoff.json" \
     "specs/TODO.md" \
     "specs/state.json"
```

---

### Stage 10: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Hard-mode Lean implementation completed for task {N}:
- Phase {P} implemented with H2 and H9 contracts enforced
- Proofs: {theorem names} all sorry-free
- Sorry inventory: {count} entries / {count} resolved this dispatch
- Lake build: Success
- Created summary at specs/{N}_{SLUG}/summaries/MM_{short-slug}-summary.md
- Status updated to [COMPLETED]
- Changes committed
```

If a `comparator` block was recorded and its `verdict` is not `verified`, add a bullet naming the
verdict and its `verdict_source` (e.g. `- Comparator advisory finding: statement_mismatch
(verdict_source: runner) — see summary for detail`). Add no more than a single short line for the
`verified` or absent cases beyond what the example above already shows.

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found, wrong language, or terminal state.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status as "implementing"
2. Report error to user

### Sorry Inventory Mismatch
If agent wrote sorry_inventory but metadata doesn't contain it:
1. Read `.orchestrator-handoff.json` directly for sorry_inventory
2. Log warning: "sorry_inventory read from handoff file, not metadata"

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### Subagent Timeout
Return partial status if subagent times out (default 7200s).
Keep status as "implementing" for resume.

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All Lean proof work is done by agent
2. **Run lake build** - Build verification is done by agent (the agent's build is detached and
   guarded — see `context/project/lean4/operations/long-builds.md`)
3. **Use MCP tools** - lean-lsp tools are for agent use only
4. **Grep for sorries** - Debt analysis is agent work
5. **Write summary/reports** - Artifact creation is agent work
6. **Re-run sorry inventory scan** - Agent populates sorry_inventory
7. **Resolve sorry entries** - That is agent implementation work
8. **Re-run the Comparator** - The advisory gate is agent work; this skill only reads the
   recorded `comparator` block (Stage 6c)
9. **Downgrade status on a Comparator verdict** - The gate is advisory-only by binding design
   decision; see Stage 6c's asymmetry note

> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill MUST NOT
> attempt to continue, complete, or "fill in" the subagent's work. Report the partial/failed
> status and let the user re-run `/implement` to resume.

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Reading agent handoff JSON for sorry_inventory
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the
file and processed internally.
