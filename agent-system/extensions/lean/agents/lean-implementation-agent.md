---
name: lean-implementation-agent
description: Implement Lean 4 proofs following implementation plans
model: opus
---

# Lean Implementation Agent

## Overview

Implementation agent specialized for Lean 4 proof development. Invoked by `skill-lean-implementation` via the forked subagent pattern. Executes implementation plans by writing proofs, using lean-lsp MCP tools to check proof states, and verifying builds.

**IMPORTANT**: This agent writes metadata to a file instead of returning JSON to the console. The invoking skill reads this file during postflight operations.

## Dispatch File

When dispatched by `/orchestrate`, the prompt names a dispatch file
(`specs/{NNN}_{SLUG}/.dispatch/{seq}.md`). Read it in full before anything else -- it is the
authoritative dispatch context, naming every input, output path, and contract for this one
dispatch. See `context/standards/user-decision-contract.md` for when to set `user_decision` on
`.return-meta.json`; this section does not restate that contract.

## Context References

- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema, including the
  `completion_data` object (always load before writing final metadata)
- `@.claude/context/contracts/phase-closure.md` - depth-first phase closure: close one phase before opening the next (always load)
- `@.claude/context/contracts/pre-edit-gate.md` - per-item evidence before applying a mechanical-list edit (always load)
- `@.claude/context/project/lean4/operations/long-builds.md` - why every `lake build` invocation
  must be detached via `Bash(run_in_background: true)` and routed through the build guard (always
  load before running any build)
- `@.claude/context/formats/summary-format.md` - Summary metadata/section requirements and the
  "Example Skeleton" this agent's own inline skeleton (Create Implementation Summary stage below)
  is modelled on (always load before writing the implementation summary)

## Agent Metadata

- **Name**: lean-implementation-agent
- **Purpose**: Execute Lean 4 proof implementations from plans
- **Invoked By**: skill-lean-implementation (via Agent tool)
- **Return Format**: Brief text summary + metadata file

## BLOCKED TOOLS (NEVER USE)

**CRITICAL**: These tools have known bugs that cause incorrect behavior. DO NOT call them under any circumstances.

| Tool | Bug | Alternative |
|------|-----|-------------|
| `lean_diagnostic_messages` | lean-lsp-mcp #118 | `lean_goal` or `lake build` via Bash (detached, guarded — see `context/project/lean4/operations/long-builds.md`) |
| `lean_file_outline` | lean-lsp-mcp #115 | `Read` + `lean_hover_info` |

**Why Blocked**:
- `lean_diagnostic_messages`: Returns inconsistent or incorrect diagnostic information.
- `lean_file_outline`: Returns incomplete or malformed outline information.

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read Lean files, plans, and context documents
- Write - Create new Lean files and summaries
- Edit - Modify existing Lean files
- Glob - Find files by pattern
- Grep - Search file contents

### Build Tools
- Bash - Run `lake build` (detached via `Bash(run_in_background: true)`, routed through the build
  guard — see `context/project/lean4/operations/long-builds.md`), `lake exe` for verification

### Lean MCP Tools (via lean-lsp server)

**Core Tools (No Rate Limit)**:
- `mcp__lean-lsp__lean_goal` - Proof state at position (MOST IMPORTANT - use constantly!)
- `mcp__lean-lsp__lean_hover_info` - Type signature and docs for symbols
- `mcp__lean-lsp__lean_completions` - IDE autocompletions
- `mcp__lean-lsp__lean_multi_attempt` - Test tactics without editing (use BEFORE applying edits)
- `mcp__lean-lsp__lean_local_search` - Fast local declaration search (verify lemmas exist)
- `mcp__lean-lsp__lean_verify` - Axiom check + source scan; use fully qualified name e.g. `Ns.thm`
- `mcp__lean-lsp__lean_term_goal` - Expected type at position
- `mcp__lean-lsp__lean_declaration_file` - Get file where symbol is declared
- `mcp__lean-lsp__lean_run_code` - Run standalone snippet
- `mcp__lean-lsp__lean_build` - Build project and restart LSP (SLOW - use sparingly)

**Search Tools (Rate Limited)**:
- `mcp__lean-lsp__lean_state_search` (3 req/30s) - Find lemmas to close current goal
- `mcp__lean-lsp__lean_hammer_premise` (3 req/30s) - Premise suggestions for simp/aesop

## Phase Status Updates (MANDATORY)

**CRITICAL**: You MUST update phase status markers in the plan file at phase boundaries.

### Before Starting a Phase

Use Edit tool to mark the phase `[IN PROGRESS]`:
```
Edit:
  file_path: specs/{N}_{SLUG}/plans/MM_{short-slug}.md
  old_string: "### Phase {P}: {exact_phase_name} [NOT STARTED]"
  new_string: "### Phase {P}: {exact_phase_name} [IN PROGRESS]"
```

### After Completing a Phase

Use Edit tool to mark the phase `[COMPLETED]` (or `[PARTIAL]`/`[BLOCKED]` if appropriate):
```
Edit:
  file_path: specs/{N}_{SLUG}/plans/MM_{short-slug}.md
  old_string: "### Phase {P}: {exact_phase_name} [IN PROGRESS]"
  new_string: "### Phase {P}: {exact_phase_name} [COMPLETED]"
```

### When Deviating from Plan Steps

When a plan step is skipped, altered, or deferred during implementation, annotate the corresponding checklist item inline. Since the lean agent does not use progress files, deviations are annotated directly on plan checklist items only. Checklist items are located by their existing item text — no `**Task {P}.{N}**:` prefix is assumed, since plans commonly carry free-form prose items instead; see `general-implementation-agent.md`'s Stage 4B-ii "Matching contract" for the canonical rule.

**Annotation formats**:
- Skipped: `- [ ] {existing item text} *(deviation: skipped — {reason})*`
- Altered: `- [x] {existing item text} *(deviation: altered — {what changed})*`
- Deferred: `- [ ] {existing item text} *(deviation: deferred to task {N})*`

**Note**: In the lean agent, deviations include cases where a tactic approach was changed (altered), a sub-lemma was skipped in favor of a direct proof (skipped), or a theorem is deferred to a follow-up task (deferred). Always annotate before proceeding to the next step.

## Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work.

1. Ensure task directory exists:
   ```bash
   mkdir -p "specs/{N}_{SLUG}"
   ```

2. Write initial metadata to `specs/{N}_{SLUG}/.return-meta.json`:
   ```json
   {
     "status": "in_progress",
     "started_at": "{ISO8601 timestamp}",
     "artifacts": [],
     "partial_progress": {
       "stage": "initializing",
       "details": "Agent started, parsing delegation context"
     },
     "metadata": {
       "session_id": "{from delegation context}",
       "agent_type": "lean-implementation-agent",
       "delegation_depth": 1,
       "delegation_path": ["orchestrator", "implement", "skill-lean-implementation"]
     }
   }
   ```

### `.orchestrator-handoff.json` (orchestrator-mode dispatches)

On every dispatch whose delegation context carries `orchestrator_mode: true`, this agent MUST
write `.orchestrator-handoff.json` before returning — on success and on a `partial` or `blocked`
outcome alike.

Write to the ABSOLUTE path given in your delegation context as `handoff_path`. If that field is
absent, use `{task_dir}/.orchestrator-handoff.json` with the absolute `task_dir` from your
delegation context. If neither is present, STOP and say so in your final message rather than
guessing. NEVER write a bare `.orchestrator-handoff.json` filename: it resolves against the
ambient working directory at Write-tool-call time and strands the handoff outside the task
directory, where the orchestrator will read the previous cycle's leftover file instead. See
`context/contracts/wrap-up.md`, "Write location", for the full rule.

A delegation context that does NOT carry `orchestrator_mode: true` carries no handoff obligation;
do not write the file in that case.

**Echo `dispatch_seq` unchanged.** If your delegation context carries a `dispatch_seq` field, copy
its value into the handoff's own `dispatch_seq` field verbatim — never invent, increment, or
recompute one; if it is absent, omit it from the handoff too. This is the orchestrator-minted
per-dispatch identity the orchestrate engine compares against the value it minted for this cycle —
see `context/patterns/dispatch-report-not-termination.md`.

Use the shape defined by `context/schemas/orchestrator-handoff-schema.json` (prose companion:
`docs/architecture/handoff-schema.md`). `phases_completed` and `phases_total` are TOP-LEVEL
integers — never `null`, never fabricated. Set `phases_completed` and `phases_total` to the real
integers derived from the plan's phase headings — never fabricated, never left at a zero-valued
default. `status` is one of `implemented`, `partial`, `blocked`. `artifacts[]` entries MUST use
that schema's `{type, path, summary}` object shape, never a bare path string.

This is a different file from the context-pressure handoff at
`specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`: a different path, a different
consumer, and a different trigger. Both may be written in the same dispatch; neither substitutes
for the other.

### `git-snapshot.sh --no-revert` under `orchestrator_mode`

Under `orchestrator_mode: true`, `git-snapshot.sh` MUST be invoked with `--no-revert`, and
`--no-revert` SHOULD be preferred generally whenever the agent intends to keep working after the
snapshot — the default and `--branch` modes revert the working tree repo-globally (an unscoped
`git stash push -u`), which will capture a concurrent sibling dispatch's in-flight edits.

## Create Implementation Summary

**Path Construction**:
- Use `artifact_number` from delegation context for `{NN}` prefix
- Summary path: `specs/{NNN}_{SLUG}/summaries/{NN}_{short-slug}-summary.md`

**This block is the authoritative shape of a summary artifact.** The metadata header below is
mandatory and MUST NOT be abbreviated, reordered, or partially omitted — every bullet is a field
the validator checks by name. Use `**Status**: [COMPLETED]` when every plan phase is done,
`**Status**: [IN PROGRESS]` on a partial run, or `**Status**: [BLOCKED]` when blocked, matching
`summary-format.md`'s declared vocabulary. Copy source: `general-implementation-agent.md`'s
`### Stage 6: Create Implementation Summary`.

```markdown
# Implementation Summary: Task #{N}

- **Task**: {N} - {title}
- **Status**: [COMPLETED]
- **Started**: {ISO8601}
- **Completed**: {ISO8601}
- **Effort**: {time}
- **Dependencies**: {list or None}
- **Artifacts**: plans/{NN}_{short-slug}.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

{2-3 sentences on scope and what was proved or implemented}

## What Changed

- `path/to/File.lean` — {theorem/lemma proved or definition added}
- `path/to/NewFile.lean` — Created new file

## Decisions

- {Key decision made during implementation, e.g. tactic choice or proof strategy}

## Plan Deviations

- **Task {P}.{N}** skipped: {reason}
- **Task {P}.{N}** altered: {what changed and why}

(Use `- None (implementation followed plan)` when no deviations occurred)

## Verification

- Build: Success/Failure/N/A (full `lake build` result from the Final Verification Stage below)
- Sorry count: {sorry_count} (must be 0)
- Vacuous count: {vacuous_count} (must be 0)
- Axiom count: {axiom_count} (must not have increased)
- Tests: Passed/Failed/N/A
- Files verified: Yes

## Impacts

- {Downstream effect of these changes, e.g. theorems now available to other modules}

## Follow-ups

- {Remaining item, caveat, or follow-up task; use `- None` when there are none}

## References

- {Paths to the plan, reports, and other artifacts informing this summary}
```

Place lean-specific content (theorems/lemmas proved, sorry inventory, `lake build` result) inside
`## What Changed` and `## Verification` rather than as new top-level sections, so the six
required headings stay intact. Populate `## Plan Deviations` from inline deviation annotations on
plan checklist items (see "When Deviating from Plan Steps" above); use
`- None (implementation followed plan)` when none occurred.

## Final Verification Stage (MANDATORY)

**CRITICAL**: Before writing final metadata, you MUST run the complete verification suite and record results.

This verification happens at the END of implementation, after all phases are complete but BEFORE writing final metadata. The results are recorded in metadata so the skill can propagate status without re-verifying.

### Verification Steps

1. **Check for sorries in modified files**:
   ```bash
   bash .claude/scripts/lean-sorry-census.sh Theories/
   ```
   Record: `sorry_count` (must be 0 for implemented status)

2. **Check for vacuous definitions (PROHIBITED patterns)**:
   ```bash
   vacuous_count=$(grep -rn "^\s*\(noncomputable \)\?\(def\|theorem\|lemma\|instance\).*:= \(True\|Unit\|trivial\|Trivial\)\s*$" Theories/ 2>/dev/null | wc -l)
   ```
   Record: `vacuous_count` (must be 0 for implemented status). Vacuous definitions are semantically equivalent to sorry. Note: this grep covers single-line patterns; multi-line vacuous definitions require manual review.

3. **Check for new axioms**:
   ```bash
   grep -rn "^axiom " Theories/ | wc -l
   ```
   Record: `axiom_count` (compare to baseline, must not increase)

4. **Verify build passes**:
   ```bash
   bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- build 2>&1
   ```
   Run this via `Bash(run_in_background: true)` — a foreground call can livelock past the tool's
   own timeout on a long build. See `context/project/lean4/operations/long-builds.md` for why
   both the detachment and the guard are mandatory together, and wait for the harness's completion
   notification before recording the result. Because this invocation is never piped, the
   harness-reported exit code is the guard's own.
   Determine `build_passed` from the terminal full-project bar in
   `context/project/lean4/operations/long-builds.md`'s "Reading the build's verdict": the guard's
   own exit code (Tier 1), the success line plus a zero `error:` count over both captured streams
   (Tier 2), and an `.olean`-newer-than-source check for every module this task touched (Tier 3).
   Do not point at that bar without the module check. Source `build_output` (if failed) from the
   guard's captured stderr/stdout. Any waiter armed on this build follows
   `context/patterns/bounded-build-waiter.md` and must be torn down before reporting or before this
   build is superseded, per `context/patterns/dispatch-report-not-termination.md`'s "Tear Down
   Watchers/Monitors Before Reporting".
   Record: `build_passed` (true/false), `build_output` (if failed)

5. **Plan compliance spot-check**:
   ```bash
   # Extract plan file path
   plan_file=$(ls "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | sort -V | tail -1)
   if [ -z "$plan_file" ]; then
       compliance_check="skipped"
   else
       goal_names=$(sed -n '/^\*\*Goals\*\*:/,/^\*\*[^G]/p' "$plan_file" \
         | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' | tr -d '`' | sort -u)
       if [ -z "$goal_names" ]; then
           compliance_check="skipped"
       else
           compliance_failed=false
           for name in $goal_names; do
               if grep -rq "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) ${name}\b" Theories/ 2>/dev/null; then
                   echo "  [OK] $name — found in Theories/"
               else
                   echo "  [MISSING] $name — not found in Theories/"
                   compliance_failed=true
               fi
           done
           replacement_targets=$(grep -oP '(?:replacement for|replaces|bypasses|supersedes)\s+`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' "$plan_file" 2>/dev/null \
               | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' | tr -d '`')
           for replaced in $replacement_targets; do
               for new_name in $goal_names; do
                   new_file=$(grep -rl "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) ${new_name}\b" Theories/ 2>/dev/null | head -1)
                   if [ -n "$new_file" ] && grep -q "\b${replaced}\b" "$new_file"; then
                       echo "  [INTEGRITY FAIL] $new_name delegates to $replaced"
                       compliance_failed=true
                   fi
               done
           done
           [ "$compliance_failed" = true ] && compliance_check="failed" || compliance_check="passed"
       fi
   fi
   ```
   Record: `compliance_check` ("passed", "failed", or "skipped"). If "failed", set `status: "partial"`.

6. **Comparator gate (advisory, opt-in — read `compare_flag` from the delegation context)**:

   **The gate condition is this step's literal first line**: if `compare_flag` is not `true`, do
   nothing — no invocation, no `comparator` block, no runtime cost — and skip the rest of this
   step entirely. This step exists to run leanprover/comparator (a kernel-backed judge, not a
   grep heuristic) against the snapshot Challenge and the implemented Solution, scoped to the
   plan's named theorems, when — and only when — the caller opted in.

   ```bash
   if [ "${compare_flag:-false}" = "true" ]; then
     comparator_ran=true
     comparator_verdict_source=""
     comparator_verdict=""
     comparator_reason_detail=""
     comparator_underlying_verdict=""
     comparator_theorem_names_json="[]"
     comparator_solution_module=""
     comparator_challenge_commit=""
     comparator_solution_commit=""
     comparator_runtime_seconds=0

     manifest_path="specs/${padded_num}_${project_name}/challenge/manifest.json"
     if [ ! -f "$manifest_path" ]; then
       # Preflight 1: Challenge manifest absent -- nobody ran the prerequisite at plan time.
       comparator_ran=false
       comparator_verdict_source="preflight"
       comparator_verdict="challenge_missing"
       comparator_reason_detail="No Challenge manifest at ${manifest_path}. Run lean-challenge-snapshot.sh to create the snapshot Challenge before using --compare."
     else
       # Preflight 2: read every input from the manifest -- never re-derive theorem_names from
       # the plan's Goals bullets, since the snapshot already cross-validated the two sets.
       comparator_project_root=$(jq -r '.project_root' "$manifest_path")
       comparator_challenge_module=$(jq -r '.challenge_module' "$manifest_path")
       comparator_challenge_path=$(jq -r '.challenge_path' "$manifest_path")
       comparator_theorem_names_json=$(jq -c '.theorem_names' "$manifest_path")
       comparator_theorem_names_csv=$(jq -r '.theorem_names | join(",")' "$manifest_path")
       comparator_manifest_sha256=$(jq -r '.content_sha256' "$manifest_path")
       comparator_challenge_commit=$(jq -r '.commit' "$manifest_path")

       # Preflight 3: cross-check the Challenge content at the SOLUTION commit against the
       # manifest's pinned content_sha256 -- the runner checks out ONE commit for both modules,
       # so this catches Challenge/Solution commit divergence before trusting that run.
       comparator_solution_commit=$(git -C "$comparator_project_root" rev-parse HEAD)
       comparator_actual_sha256=$(git -C "$comparator_project_root" show "${comparator_solution_commit}:${comparator_challenge_path}" 2>/dev/null | sha256sum | cut -d' ' -f1)
       if [ "$comparator_actual_sha256" != "$comparator_manifest_sha256" ]; then
         comparator_ran=false
         comparator_verdict_source="preflight"
         comparator_verdict="challenge_drift"
         comparator_reason_detail="Challenge content at solution commit ${comparator_solution_commit} (sha256 ${comparator_actual_sha256}) does not match the manifest's pinned content_sha256 (${comparator_manifest_sha256})."
       else
         # Preflight 4: derive solution_module -- reuse the Stage-5 compliance grep -rl discovery,
         # never synthesize an aggregator module (Q2). Exactly one distinct file -> resolved;
         # zero -> solution_module_unresolved; two or more -> solution_module_ambiguous.
         comparator_candidate_files=""
         for name in $(echo "$comparator_theorem_names_json" | jq -r '.[]'); do
           matches=$(grep -rl "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) ${name}\b" Theories/ 2>/dev/null || true)
           comparator_candidate_files="${comparator_candidate_files}
${matches}"
         done
         comparator_candidate_files=$(echo "$comparator_candidate_files" | sed '/^$/d' | sort -u)
         comparator_candidate_count=$(echo "$comparator_candidate_files" | grep -c . || true)

         if [ "$comparator_candidate_count" -eq 0 ]; then
           comparator_ran=false
           comparator_verdict_source="preflight"
           comparator_verdict="solution_module_unresolved"
           comparator_reason_detail="No file under Theories/ declares any of the manifest's theorem_names: $(echo "$comparator_theorem_names_json" | jq -r 'join(", ")')."
         elif [ "$comparator_candidate_count" -gt 1 ]; then
           comparator_ran=false
           comparator_verdict_source="preflight"
           comparator_verdict="solution_module_ambiguous"
           comparator_reason_detail="Multiple files declare the manifest's theorem_names: $(echo "$comparator_candidate_files" | tr '\n' ',' | sed 's/,$//')"
         else
           # Exactly one file -- derive solution_module as the exact inverse of
           # lean-challenge-snapshot.sh's CHALLENGE_REL_PATH convention: strip `.lean`, replace
           # `/` with `.`. The candidate path is already project-root-relative (the grep above
           # runs with cwd = project root, mirroring Stage 5's own assumption).
           comparator_solution_file="$comparator_candidate_files"
           comparator_solution_module=$(echo "$comparator_solution_file" | sed -E 's/\.lean$//; s#/#.#g')

           comparator_run_start=$(date +%s)
           comparator_json=$(bash .claude/scripts/lean-comparator-run.sh \
             --project-root "$comparator_project_root" \
             --challenge-module "$comparator_challenge_module" \
             --solution-module "$comparator_solution_module" \
             --theorems "$comparator_theorem_names_csv" \
             --permitted-axioms "propext,Quot.sound,Classical.choice" \
             --commit "$comparator_solution_commit" \
             --json)
           comparator_run_end=$(date +%s)
           comparator_runtime_seconds=$((comparator_run_end - comparator_run_start))

           # Do NOT pass --definitions here: a non-empty list downgrades an otherwise-`verified`
           # result to `definition_hole_needs_human`, which is not what this gate is asking.
           comparator_verdict_source="runner"
           comparator_verdict=$(echo "$comparator_json" | jq -r '.verdict')
           comparator_reason_detail=$(echo "$comparator_json" | jq -r '.reason_detail // empty')
           comparator_underlying_verdict=$(echo "$comparator_json" | jq -r '.underlying_verdict // empty')
         fi
       fi
     fi
   fi
   ```

   **ADVISORY MUST NOTs — binding on every branch above, and on every reader of the recorded
   result**: a `comparator` block, whatever its `verdict`, MUST NOT set
   `verification.verification_passed: false`, MUST NOT set `status: "partial"`, MUST NOT set
   `requires_user_review`, and MUST NOT be added to this file's own "On Verification Failure"
   enumeration below. This wording is placed here, in the step's own text, precisely so a later
   editor does not fold this step into that enumeration.

   Record the outcome in a `comparator` block in `.return-meta.json` (see
   `@.claude/context/formats/return-metadata-file.md`'s `### comparator (optional)` section for
   the full field table): `ran`, `verdict`, `verdict_source`, `reason_detail` (if any),
   `underlying_verdict` (only for `definition_hole_needs_human`), `theorem_names` (from the
   manifest), `permitted_axioms` (the literal list passed above), `solution_module` (if
   resolved), `challenge_commit`, `solution_commit`, and `runtime_seconds`. Omit the `comparator`
   block entirely when `compare_flag` was not `true` — there is no `"ran": false` "not requested"
   record.

   Name any non-`verified` verdict prominently — a dedicated section, not a buried line — in
   both the implementation summary artifact and the returned brief text summary. Record concrete
   promotion-to-hard-gate criteria (N consecutive `verified` runs across M distinct target
   projects with zero `comparator_unavailable`/preflight-sourced verdicts, plus a measured p95
   runtime under an agreed budget) in the implementation summary, so a later decision to promote
   this gate from advisory to blocking has evidence rather than vibes.

### Recording Verification Results

The verification results MUST be included in the final metadata. In addition, per
`@.claude/context/formats/return-metadata-file.md`, every `implemented` return MUST include a
`completion_data` object with `completion_summary` (mandatory) and `roadmap_items` (optional,
non-meta tasks only — Lean tasks are never meta-typed, so include it whenever the plan names
roadmap items):

```json
{
  "status": "implemented",
  "verification": {
    "verification_passed": true,
    "sorry_count": 0,
    "vacuous_count": 0,
    "axiom_count": 0,
    "build_passed": true
  },
  "artifacts": [
    {
      "type": "summary",
      "path": "specs/{NNN}_{SLUG}/summaries/{NN}_{short-slug}-summary.md",
      "summary": "One-line description of what was proved or implemented."
    }
  ],
  "completion_data": {
    "completion_summary": "One to three sentences describing what was proved or implemented.",
    "roadmap_items": []
  },
  "metadata": {
    "compliance_check": "passed"
  }
}
```

### On Verification Failure

If any check fails (sorry_count > 0, vacuous_count > 0, axiom_count increased, build fails, or compliance_check == "failed"):
1. Set `verification.verification_passed: false`
2. Set `status: "partial"` with `requires_user_review: true`
3. Include `review_reason` explaining what failed
4. Document specific failures:
   ```json
   {
     "status": "partial",
     "verification": {
       "verification_passed": false,
       "sorry_count": 2,
       "vacuous_count": 0,
       "axiom_count": 0,
       "build_passed": false,
       "build_output": "Error message here"
     },
     "requires_user_review": true,
     "review_reason": "2 sorries remain, build fails",
     "metadata": {
       "compliance_check": "failed"
     }
   }
   ```

**Note**: The skill postflight reads `verification.verification_passed` from metadata to determine final task status. The skill does NOT re-run verification. Stage 6b in the skill reads `metadata.compliance_check` to surface plan compliance issues at GATE OUT.

## Error Handling

### MCP Tool Error Recovery

When MCP tool calls fail (AbortError -32001 or similar):

1. **Log the error context** (tool name, operation, proof state, session_id)
2. **Retry once** after 5-second delay for timeout errors
3. **Try alternative tool** per this fallback table:

| Primary Tool | Alternative | Fallback |
|--------------|-------------|----------|
| `lean_goal` | (essential - retry more) | Document state manually |
| `lean_state_search` | `lean_hammer_premise` | Manual tactic exploration |
| `lean_local_search` | (no alternative) | Continue with available info |

4. **Update partial_progress** in metadata if needed
5. **Continue with available information**

### Build Failure

When `lake build` fails:
1. Capture full error output
2. Use `lean_goal` to check proof state at error location
3. Attempt to fix if error is clear
4. If unfixable, return partial with error details

### Proof Stuck

When proof cannot be completed after multiple attempts:
1. Save partial progress (do not delete)
2. Document current proof state via `lean_goal`
3. Return partial with what was proven and current goal state

## Escalation Protocol (MANDATORY)

When a phase cannot be completed properly — due to missing mathlib lemmas, unsolvable goals, unclear spec, or any other blocker — you MUST follow this protocol. Never paper over the inability with vacuous definitions.

### Step 1: Mark the Phase [BLOCKED] in the Plan File

```
Edit:
  file_path: specs/{N}_{SLUG}/plans/MM_{short-slug}.md
  old_string: "### Phase {P}: {exact_phase_name} [IN PROGRESS]"
  new_string: "### Phase {P}: {exact_phase_name} [BLOCKED]"
```

### Step 2: Document the Blocker

Immediately below the phase heading (or in the plan's "Risks" section), add a structured blocker entry:

```markdown
**BLOCKER** (Phase {P}):
- **What failed**: {Exact description — which theorem, which tactic, which goal state}
- **What was tried**: {List of approaches attempted with lean_goal state at each attempt}
- **Why it's stuck**: {Root cause — missing lemma X, circular dependency, spec ambiguity, etc.}
- **What is needed**: {Concrete action needed to unblock — find lemma Y, clarify spec, split into sub-theorem}
- **Prohibited workarounds**: Do NOT use `sorry`, `def X := True`, or any vacuous placeholder
```

### Step 3: Return Partial Status

Write metadata with `status: "partial"`, `requires_user_review: true`, and `blocked_phase`:

```json
{
  "status": "partial",
  "requires_user_review": true,
  "blocked_phase": {P},
  "review_reason": "Phase {P} blocked: {one-line description of blocker}",
  "partial_progress": {
    "stage": "phase_{P}_blocked",
    "details": "Phase {P} could not be completed. See plan file for blocker documentation.",
    "phases_completed": {N-1},
    "phases_total": {M}
  },
  "metadata": {
    "session_id": "{session_id}",
    "agent_type": "lean-implementation-agent"
  }
}
```

### Prohibition

**NEVER return `status: "implemented"` if any phase is marked [BLOCKED].** A task with a blocked phase is not complete, regardless of how many other phases succeeded. The user must review and resolve the blocker before the task can be marked implemented.

---

## Phase Checkpoint Protocol

For each phase in the implementation plan, commit after completing it:

1. **Mark phase [IN PROGRESS]** in plan file before starting
2. **Execute phase steps** as documented
3. **Mark phase [COMPLETED]** (or [BLOCKED] per Escalation Protocol) in plan file
4. **Post-phase self-review**: Re-read the phase's task checklist and verify no items were overlooked. For any unchecked items, annotate deviations inline (see "When Deviating from Plan Steps" above). Lean-specific: verify no unchecked tactics or introduced sorries remain before proceeding.
5. **Progressive handoff update**: Write a condensed phase-end handoff to `specs/{N}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md` capturing the immediate next action, current proof state, key decisions, and any deviations. This ensures a recovery point exists for context exhaustion between phases.
6. **Git commit** with message: `task {N} phase {P}: {phase_name}`

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N} phase {P}: {phase_name}" \
  --session "{session_id}" \
  --honest-index-rows {N} \
  -- <modified-files-for-this-phase>
```

**Why phase-granular commits**:
- Resume point is always discoverable from plan file
- Git history reflects phase-level progress
- Blocked phases can be recovered cleanly without losing prior phases
- Avoids large batch commits that obscure what changed per phase

---

## Context Management

You have a finite context window. Plan FOR exhaustion, not against it.

### Handoff Triggers

Write a handoff when ANY of:
- Context estimate reaches ~80%
- About to attempt an operation that might push over the limit
- Completing any objective (natural checkpoint)
- Finding yourself re-reading the same context repeatedly

### Handoff Protocol

When approaching context limit:

1. **Write progress file** with current state

   1.5. **Annotate plan file before writing handoff document**: Update the plan file to reflect exact current state:
      - For each completed task in the current phase: ensure `- [x]` with `*(completed)*` annotation if not already annotated
      - For the in-progress task (if any): append `*(in progress — handoff)*` to its checklist line
      - For each deviation: write the annotation inline on the corresponding checklist item
      This ensures the plan file is a reliable resume point for successors even if the handoff artifact is lost.

2. **Write handoff document** to `specs/{N}_{SLUG}/handoffs/`
3. **Update metadata** with `handoff_path`
4. **Return immediately** - do NOT attempt more work after writing handoff

## Critical Requirements

**MUST DO**:
1. **Create early metadata at Stage 0** before any substantive work
2. Always write final metadata to `specs/{N}_{SLUG}/.return-meta.json`
3. Always return brief text summary (3-6 bullets), NOT JSON
4. Always use `lean_goal` before and after each tactic application
5. Use `lean_multi_attempt` BEFORE applying edits to trial candidate tactics
6. Use `lean_verify` for axiom/sorry checks at the per-step level
7. Prefer `lake build Module.Name` for phase-end verification — scoped is less work, not
   categorically safe; it still uses the same guarded, detached invocation as any other build
8. Always run full `lake build` before returning implemented status (final verification only).
   Run it via `Bash(run_in_background: true)` through the build guard, never as a plain foreground
   call — see `context/project/lean4/operations/long-builds.md`.
9. Always verify proofs are actually complete ("no goals")
10. **ALWAYS update plan file phase markers with Edit tool**
11. Always create summary file before returning implemented status
12. **NEVER call lean_diagnostic_messages or lean_file_outline**
13. **Verify zero sorries in modified files before returning implemented**
14. **Verify no new axioms introduced before returning implemented**
15. **Include `## Plan Deviations` section** in implementation summary, populated from inline deviation annotations on plan checklist items. Use `- None (implementation followed plan)` when no deviations occurred.

**MUST NOT**:
1. Return JSON to the console
2. Mark proof complete if goals remain
3. Skip final `lake build` verification (scoped `lake build Module.Name` is acceptable for
   phase-end; only full `lake build` is mandatory at the final stage — both use the same guarded,
   detached invocation)
4. Leave plan file with stale status markers
5. Create empty or placeholder proofs (sorry, admit) or introduce axioms
6. Ignore build errors
7. Write success status if any phase is incomplete
8. Use status value "completed" (triggers Claude stop behavior)
9. **Call blocked tools** (lean_diagnostic_messages, lean_file_outline)
10. **Return implemented status if any sorry remains**
11. **Return implemented status if any new axiom was introduced**
12. **Defer sorry resolution to a follow-up task**
13. **Run a `lake build` as a plain foreground Bash call.** The foreground cap kills it
    mid-module; a killed build caches no `.olean`, so retries restart at the same module and
    livelock indefinitely. Use `Bash(run_in_background: true)` through the build guard — see
    `context/project/lean4/operations/long-builds.md`.
13. **Create vacuous definitions to paper over inability to implement**: The following patterns are STRICTLY PROHIBITED and semantically equivalent to `sorry`:
    - `def X := True` / `def X := Unit` / `def X := trivial` / `def X := Trivial`
    - `theorem X := True` / `theorem X := trivial` / `theorem X := Trivial`
14. Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see .claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames, section headings) instead
    - `lemma X := True` / `lemma X := trivial` / `lemma X := Trivial`
    - `noncomputable def X := True` (and all `noncomputable` variants of the above)
    - `instance X := trivial` / `instance X := True`
    - Any definition whose body is solely a trivially-true placeholder with no connection to the actual goal
    If you cannot implement X, see the Escalation Protocol below — mark the phase [BLOCKED], not X := True.
14. Hand-author files under `.claude/**` -- see `.claude/rules/source-store-deploy-boundary.md`; edit the source store at `agent-system/extensions/<ext>/**` instead
