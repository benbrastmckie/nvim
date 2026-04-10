# Lean Implementation Execution Flow

Reference: Load when executing lean-implementation-agent after Stage 0.

## Prerequisites

- Early metadata initialized (Stage 0 complete)
- Implementation plan available

---

## Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "task_context": {
    "task_number": 123,
    "task_name": "prove_theorem",
    "description": "...",
    "task_type": "lean"
  },
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "implement", "lean-implementation-agent"]
  },
  "plan_path": "specs/123_theorem/plans/02_theorem-implementation.md",
  "metadata_file_path": "specs/123_theorem/.return-meta.json"
}
```

---

## Stage 2: Load and Parse Implementation Plan

Read the plan file and extract:
- Phase list with status markers ([NOT STARTED], [IN PROGRESS], [COMPLETED], [PARTIAL])
- Files to modify per phase
- Steps within each phase
- Verification criteria

---

## Stage 3: Find Resume Point

Scan phases for first incomplete:
- `[COMPLETED]` -> Skip
- `[IN PROGRESS]` -> Resume here
- `[PARTIAL]` -> Resume here
- `[NOT STARTED]` -> Start here

If all phases are `[COMPLETED]`: Task already done, return completed status.

---

## Stage 4: Execute Proof Development Loop

For each phase starting from resume point:

### 4A. Mark Phase In Progress

Update phase status marker in plan file:
```
### Phase {P}: {phase_name} [NOT STARTED] -> [IN PROGRESS]
```

### 4B. Execute Proof Development

For each proof/theorem in the phase:

1. **Read target file, locate proof point**
2. **Check current proof state** using `lean_goal`
3. **Develop proof iteratively**
   ```
   REPEAT until goals closed or stuck:
     a. Use lean_goal to see current state
     b. Use lean_multi_attempt to try candidate tactics
     c. If promising tactic found, apply via Edit
     d. If stuck, use lean_state_search, lean_hammer_premise
     e. If still stuck, log state and return partial
   ```
4. **Verify step completion** with `lean_goal` and `lake build`

### 4C. Verify Phase Completion

- Run `lake build` to verify full project builds
- Check verification criteria from plan

### 4D. Mark Phase Complete

Update phase status to `[COMPLETED]` or `[PARTIAL]` or `[BLOCKED]`.

---

## Stage 5: Run Final Build Verification

After all phases complete:
```bash
lake build
```

---

## Stage 6: Create Implementation Summary

Write summary to `specs/{N}_{SLUG}/summaries/MM_{short-slug}-summary.md`

---

## Stage 7: Write Metadata File

Write to `specs/{N}_{SLUG}/.return-meta.json`:

```json
{
  "status": "implemented",
  "summary": "Brief summary",
  "artifacts": [...],
  "completion_data": {
    "completion_summary": "Description of proofs accomplished"
  },
  "metadata": {
    "session_id": "...",
    "agent_type": "lean-implementation-agent",
    "phases_completed": 3,
    "phases_total": 3
  }
}
```

---

## Stage 8: Return Brief Text Summary

Return 3-6 bullet points (NOT JSON).

---

## Proof Development Loop Details

### Tactic Selection Strategy

1. **Start Simple**: `simp`, `rfl`, `trivial`, `decide`, `ring`, `omega`
2. **Structural Tactics**: `intro`, `cases`, `rcases`, `induction`
3. **Application Tactics**: `exact h`, `apply lemma`, `have`
4. **Automation**: `simp [...]`, `aesop`, `omega`

### When Stuck

1. Use `lean_state_search` to find closing lemmas
2. Use `lean_hammer_premise` for simp premises
3. Use `lean_local_search` for related definitions
4. Return partial with recommendations

---

## Error Handling

### Build Failure
- Capture error output
- Use `lean_goal` at error location
- Return partial with recommendation

### Proof Stuck
- Save partial progress
- Document current goal state
- Return partial with attempted tactics

### Timeout/Interruption
- Save progress, mark phase `[PARTIAL]`
- Return partial with resume information
