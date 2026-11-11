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

## Stage 1.5: Check for Literature Source

Before loading the plan, check whether the task involves a literature source:

1. **Scan delegation context** for literature references in task description
2. **Check plan artifacts** (if previously loaded) for literature step annotations
3. **Determine mode**: If literature source found, enter **literature-guided mode**; otherwise, **first-principles mode**

In literature-guided mode:
- Load the literature source (paper, textbook section, proof sketch)
- Identify the proof strategy prescribed by the source
- Map source steps to expected proof development stages
- Carry this mapping into Stage 4B for step-by-step translation

See `literature-fidelity-policy.md` for full mode detection criteria and anti-patterns.

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

## Verification Tiers in Lean Terms

For Lean, `full` is the only Verification Tier that ever discharges a phase's close or commit —
see Stage 4C below for the gate itself and its rationale. `prose`, `local`, and `interface`
describe how broadly verification runs *during* a phase, in line with core's own tiering intent;
none of the three ever substitutes for the phase-end full build.

The standing cross-cutting surface that justifies `full` at every non-final phase is nameable
once: *the project-wide Lean declaration namespace — any new or renamed declaration can collide
with an identically named one anywhere else in the library, invisible to any module-scoped
build.* A lean plan's `**Tier Justification**:` line for a non-final `full` phase may cite this
sentence directly rather than re-deriving it.

| Tier | Lean meaning | In-phase check |
|------|-------------|-----------------|
| `prose` (non-gating) | Edits confined to comments, docstrings, or prose inside a `.lean` or lean-adjacent `.md` file, with zero elaboration surface. | A diff read-through, per core's own `prose` row. |
| `local` (non-gating) | A proof or definition confined to one module with no externally visible signature change. | `lean_goal` plus `lean_verify` per step (already mandated at Stage 4B item 5); optionally one scoped `lake build Module.Name` as a fast, explicitly non-gating interim sanity check. |
| `interface` (non-gating) | A declaration's name, type, arity, or argument order changes, with call sites spanning modules. | A scoped `lake build Module.A Module.B ...` over the changed module plus its enumerated direct dependents — still explicitly non-gating. |
| `full` (the sole gating tier) | The whole-project build, the only check that sees the project-wide declaration namespace. | The whole-project `lake build` (Stage 4C), plus whichever of `check-module-invariants.sh`'s checks require a completed build rather than a pure source-text scan, plus the `.olean`-newer-than-source check per touched module — `long-builds.md`'s "Reading the build's verdict", strongest item. |

These four checks within `full` are covering checks, not additional tiers: this mapping
introduces no fifth tier and renames none of core's four values.

A Lean-only phase's verification criteria has no `suite_selection_select` coverage (it carries no
`.lean` mappings), so core's shell-suite narrowing returns `__FULL_SWEEP__` for it;
`plan-format.md`'s "Unmappable criterion" paragraph is the sanctioned authority for naming and
running the concrete check above directly and recording that run as the scoped discharge.

How to invoke any of the builds above — detachment, the build guard, and the bounded-wait
obligation — is governed entirely by `long-builds.md`'s preference order; this section does not
restate it.

---

## Stage 4: Execute Proof Development Loop

For each phase starting from resume point:

### 4A. Mark Phase In Progress

Update phase status marker in plan file:
```
### Phase {P}: {phase_name} [NOT STARTED] -> [IN PROGRESS]
```

**Section-anchoring rule for any multi-line plan-file edit**: when an edit replaces or splices a
whole section of a markdown plan file, anchor both ends on LINES that begin with heading markers
(a line starting with two or three hash characters and a space), and search the end anchor
FORWARD from the target section's own start line. Never anchor on a bare heading substring: the
same text commonly recurs in prose earlier in the file (for example inside a Goals or Overview
paragraph), and a whole-file match on it splices at the wrong place, duplicating the span between
the two matches. The single-line phase-marker swap shown above is already safe by construction
(the heading text plus its bracketed status marker is unique); this rule governs edits spanning
from one heading to the next.

### 4B. Execute Proof Development

For each proof/theorem in the phase:

1. **Read target file, locate proof point**
2. **Check current proof state** using `lean_goal`
3. **Consult literature source** (literature-guided mode only)
   - Identify which literature step corresponds to the current goal
   - Translate the literature step into Lean tactics/terms
   - If translation is clear, apply directly via Edit
   - If translation is unclear, follow escalation protocol from `literature-fidelity-policy.md`
4. **Develop proof iteratively** (first-principles mode, or when literature step is not applicable)
   ```
   REPEAT until goals closed or stuck:
     a. Use lean_goal to see current state
     b. Use lean_multi_attempt to trial candidate tactics WITHOUT editing (pre-edit trial)
     c. If promising tactic found, apply via Edit
     d. After editing, use lean_goal to confirm goal progress; use lean_verify for axiom/sorry check
     e. If stuck, use lean_state_search, lean_hammer_premise
     f. If still stuck, log state and return partial
   ```
5. **Verify step completion** with `lean_goal` (proof state) and `lean_verify` (axiom/sorry check); do NOT run `lake build` per-step

### 4C. Verify Phase Completion

See the tier-to-action mapping above (just before Stage 4) for why `full` is the sole tier that
discharges this step, and for the cheaper tiers' non-gating in-phase role.

- Run a full `lake build` of the whole library through the build guard — never `lake build
  Module.Name` — and read its verdict per
  `context/project/lean4/operations/long-builds.md`'s "Reading the build's verdict". This is the
  only build that satisfies phase-end verification: a module-scoped build cannot see cross-module
  name clashes or downstream breakage, so a scoped build of one module can pass while the full
  library build fails, because a declaration the phase just introduced collides with an
  identically named declaration in another module.
- A scoped `lake build Module.Name` remains legitimate as a fast, explicitly **non-gating**
  interim check mid-phase; it is never a substitute for the phase-end full build above.
- This makes every phase-end pay a full-library build rather than a single module's — the
  accepted price of catching cross-module breakage in the phase that introduced it — and makes
  the detached-and-guarded invocation contract more load-bearing, not less. See
  `long-builds.md`'s preference order for how to run the build; this stage does not restate it.
- Check verification criteria from plan.

### 4D. Mark Phase Complete

Update phase status to `[COMPLETED]` only on a green full build per 4C; a red or unread verdict
yields `[PARTIAL]` or `[BLOCKED]`, never a closed phase. Plan-file marker edits here follow the
same forward-search anchoring rule stated after Stage 4A's marker code fence.

---

## Stage 5: Run Final Build Verification

After all phases complete, run the full project build as a final re-run over the completed task:
```bash
lake build
```

Note: Per-step verification uses `lean_goal` + `lean_verify`. Phase-end (Stage 4C) and this final
stage both require a full `lake build`; neither is a substitute for the other.

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

0. **Literature step** (literature-guided mode): Follow the tactic/approach prescribed by the source for this step. See `literature-fidelity-policy.md`.
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
