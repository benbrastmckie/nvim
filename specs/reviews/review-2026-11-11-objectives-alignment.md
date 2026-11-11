# Code Review Report

**Date**: 2026-11-11
**Scope**: Four stated objectives — sapience task completion, meta-task redundancy handling, interactive-selection display quality, default output style
**Reviewed by**: Claude

## Summary

- Objectives reviewed: 4
- Critical issues: 1
- High priority issues: 3
- Medium priority issues: 4
- Low priority issues: 1
- Objectives already satisfied (no action): 1 (sapience tasks)

The single most consequential finding is that the interactive-selection standard this
repository codifies was written against a capability `AskUserQuestion` does not have: a
question accepts at most **4** options, while the standard's threshold table plans for up to
100. Every "ugly, hard to engage with" symptom in the selection UI descends from that one
mismatch, so it is treated here as the root cause rather than as one defect among many.

## Objective 1: Sapience Tasks — Already Complete (No Action)

No open sapience work exists. All tracked sapience-extension tasks are terminal and archived:

| Task directory | Status | Scope |
|---|---|---|
| `specs/archive/482_create_sapience_extension` | completed | Built the extension |
| `specs/archive/496_sapience_per_repo_storage_and_injection` | completed | Per-repo storage/injection |
| `specs/archive/578_sf1_neovim_virtual_plugin_with_split_position` | completed | sf1 Sapience chat plugin |

Three active tasks (498, 554, 579) and three archived ones (423, 483, 488) match a naive
`sapience` grep but are false positives — the term appears only in postflight boilerplate, a
byte-count regression note, and an example filename. A sweep of
`agent-system/extensions/sapience/**` for `TODO`/`FIXME`/"not yet"/"planned" found five hits,
all scope-boundary rationale prose (e.g. `context/project/sapience/domain/per-repo-scoping.md:66`,
`domain/review-gate-boundary.md:71`), not actionable untracked work.

**Conclusion**: the first objective is discharged; nothing to create.

## Critical Issues

### AskUserQuestion option-count ceiling is 4, but the standard plans for up to 100

**File**: `agent-system/extensions/core/context/standards/interactive-selection.md:117-123`
**Description**: The Threshold Guidelines table prescribes behavior for `1-10`, `11-20`,
`21-50`, `51-100`, and `>100` items, with `21-50` handled by merely "Add 'Select all' option"
and `>100` as the "Hard limit". The actual `AskUserQuestion` schema accepts **2-4 options per
question** (`maxItems: 4`). No bracket above `1-10` is representable in a single question, and
even that one overflows past four items.
**Impact**: Every consumer that emits one option per item generates a schema-invalid payload.
At runtime this either fails validation or silently loses items, and the operator sees a
cramped, arbitrarily-truncated list — precisely the reported symptom. The defects below are
consequences of this root cause, not independent bugs.
**Recommended fix**: Rewrite the threshold model around the real ceiling: ≤4 items become one
question; more than 4 require either batched successive questions (chunks of ≤4 with a running
"N of M" progress indicator) or a narrowing step that reduces the candidate set before any
question is asked. Replace the `>100` "hard limit" row, which encodes the wrong constraint.

## High Priority Issues

### Backlog audit detects redundancy but no code path can act on it

**File**: `agent-system/extensions/core/context/workflows/meta-interview.md:558-589`
**Description**: Detection is genuinely sound — Stage 4.6 calls
`scripts/audit-task-proposals.sh`, which unions `specs/state.json` (active + completed-live)
with `specs/archive/state.json` (completed/archived/abandoned) at
`scripts/audit-task-proposals.sh:337-356` and runs both a mechanical file-overlap pass and a
semantic-similarity pass (`:23-28,358-404`) — not a substring match. The verdict then reaches a
table column and stops. `meta-interview.md:578-580` states verdicts are "never auto-applied —
the user decides, via 'Revise' or 'Cancel'", and the confirm gate offers exactly three choices:
"Yes, create tasks" (creates the duplicate anyway), "Revise" ("Go back and adjust the task
breakdown" — this batch's breakdown, not the matched record), and "Cancel" (exits with no
action at all).
**Impact**: On a `duplicate-of-open` or `covered-by-closed` verdict the operator's only options
are to create a known duplicate or to abandon the finding entirely. There is no path that
revises the matched open task or attaches the new findings to it as a report, so correctly
detected redundancy is routinely resolved by discarding work.
**Recommended fix**: Add a fourth confirm option — "Fold into existing" — that, per verdict,
either appends the new findings to the matched open task as a numbered report artifact under
that task's `reports/` directory, or routes to `/revise` for a scope change. For
`covered-by-closed`, surface the discharging artifact's path and offer to record the finding
there rather than re-opening a closed task.

### Four incompatible rendering conventions for the same conceptual choice

**Files**: `agent-system/extensions/core/scripts/tier-selection.sh:130-156`,
`tier-selection.sh:266-271`,
`agent-system/extensions/core/skills/skill-fix-it/SKILL.md:164-169`,
`agent-system/extensions/core/context/workflows/meta-interview.md:443-444`
**Description**: The same "pick which items become tasks" decision renders four different ways
with no shared helper: tier-1 emits a severity comma-list plus a pipe-joined, ellipsis-truncated
file dump; tier-3 emits `"{severity} | {loc} | From: {group_label}"` with a lowercase severity;
fix-it emits a bare `"{file}:{line}"` carrying no severity at all; and meta-interview's
custom-grouping options carry the literal placeholder descriptions `"Item 1"`, `"Item 2"`.
**Impact**: Nothing transfers between flows — the operator relearns the format each time, and
severity is present, lowercase, or absent depending on which command happens to be running.
**Recommended fix**: Extract one option-rendering helper used by all four call sites, emitting a
short imperative label and a single-clause description. Give it the shared severity vocabulary
and one location format.

### No "Concise" output style exists to point `outputStyle` at

**Files**: `agent-system/extensions/core/root-files/settings.local.json:57`,
`lua/neotex/plugins/ai/claudecode.lua:44`
**Description**: `outputStyle` is currently `"default"` in the source store
(`root-files/settings.local.json:57`) and in the deployed copy
(`.claude/settings.local.json:81`). No `output-styles/` directory exists at project scope, in
the source store, or at `~/.claude/output-styles/` — so `"Concise"` names nothing today, and
setting the key to it would point at a missing style. Separately, the nvim loader at
`lua/neotex/plugins/ai/claudecode.lua:44` sets `command = "claude --dangerously-skip-permissions"`
with no output-style flag, and a sibling comment at `:41-43` records the deliberate convention
that such preferences go in `settings.local.json` rather than a CLI flag, because a flag
bypasses Max-plan context routing.
**Impact**: The objective cannot be met by a one-line value change; the style itself must be
authored first. Following the loader's existing convention, no Lua change is needed.
**Recommended fix**: Author a `Concise` output style in the source store, deploy it to project
scope, and flip `root-files/settings.local.json:57` to reference it. Keep the change entirely
under `agent-system/` so the deploy regenerates both the style file and the setting — this
satisfies the "manage everything in nvim/" constraint and needs no global
`~/.claude/settings.json` edit.

## Medium Priority Issues

### Label truncation cuts mid-word at an inconsistent width

**Files**: `agent-system/extensions/core/scripts/tier-selection.sh:260`,
`agent-system/extensions/core/skills/skill-fix-it/SKILL.md:167`
**Description**: `tier-selection.sh:260` computes
`label = description[:60] + ("..." if len(description) > 60 else "")` — a hard character slice
with no word-boundary check. `skill-fix-it/SKILL.md:167` specifies
`"{content truncated to 50 chars}"` for the same conceptual preview, at a different width.
**Impact**: Labels break mid-word, and the same item previews at two lengths depending on the
command.
**Recommended fix**: Truncate on a word boundary at one width defined in the shared helper.

### Group label repeated on every tier-3 option

**File**: `agent-system/extensions/core/scripts/tier-selection.sh:268-271`
**Description**: Each option's description ends with `From: {group_label}`, repeating a value
already established by the tier-1 selection that produced the list.
**Impact**: Spends the description's limited width on a constant, pushing the per-item
distinguishing detail toward truncation.
**Recommended fix**: State the group once in the question text; drop it from each option.

### Severity and file information duplicated between label and description

**File**: `agent-system/extensions/core/scripts/tier-selection.sh:130-156`
**Description**: The tier-1 label already carries `"[Group] {label} ({N} issues)"` while the
description re-expresses the same magnitude as `"Critical: 2, High: 1"` and appends
`" | Files: a, b, c..."`. The repository's own guidance at
`context/standards/interactive-selection.md:108` ("Avoid redundancy with label") is not met by
its own reference implementation.
**Impact**: Both fields compete to say the same thing, so neither reads cleanly.
**Recommended fix**: Keep the count in the label and reserve the description for the single
most decision-relevant fact.

### Follow-up/unblock tasks are created with no selection step

**File**: `agent-system/extensions/core/skills/skill-spawn/SKILL.md:404-419`
**Description**: Every `new_tasks[]` entry is written straight to state via `state-write.sh`.
The only `AskUserQuestion` in the spawn flow is topic assignment at `SKILL.md:70-73`.
**Impact**: Of the three task-proposal surfaces named as hard to engage with, one presents no
list at all, so spawned follow-ups cannot be reviewed or declined before they land.
**Recommended fix**: Route spawn proposals through the same shared selection helper, so all
three surfaces share one review step.

## Low Priority Issues

### `/review`'s own duplicate check is weaker than the audit it sits beside

**File**: `agent-system/extensions/core/commands/review.md` (Section 5.6.4)
**Description**: Section 5.6.4 matches `project_name` by substring, while Section 3.5 already
invokes the full `audit-task-proposals.sh` corpus check on the same proposal.
**Impact**: Minor — the weak check is redundant rather than harmful, but it implies a guarantee
it does not provide.
**Recommended fix**: Delete Section 5.6.4 and rely on the Section 3.5 audit.

## Code Quality Metrics

| Metric | Value | Status |
|--------|-------|--------|
| TODO count | 44 | Info |
| FIXME count | 2 | OK |
| Build status | Pass (0 structural errors) | OK |
| Phantom paths | 0 | OK |
| Active tasks | 125 | Info |
| `agent-system` / `core-agent-system` topic split | 46 / 43 | Warning — see below |

## Additional Observation

Two topics, `agent-system` (46 tasks) and `core-agent-system` (43 tasks), are both heavily
populated and not obviously distinguishable. This was outside the stated objectives and no
issue is filed for it, but it is worth a disposition — either a documented boundary between
them or a merge.

## Roadmap Progress

`specs/ROADMAP.md` is hand-curated prose. It is updated alongside this review to carry the four
objectives above as the current near-term focus.

## Recommendations

1. Fix the option-count ceiling first. It is the root cause of the display complaints, and the
   shared rendering helper that resolves the other UI defects should be written against the
   corrected threshold model, not the current one.
2. Add the "Fold into existing" remediation to the meta confirm gate. Detection already works;
   only the action is missing.
3. Author the `Concise` output style before flipping the setting, and keep both in the source
   store.
