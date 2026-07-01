# Implementation Plan: Task #792 — Right-size slash-command `model:` frontmatter

- **Task**: 792 - Right-size slash-command `model:` frontmatter (reserve opus for orchestrators/deep-reasoning)
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: 790 (refreshed tiering rationale, complete)
- **Research Inputs**: specs/792_right_size_command_model_tiers/reports/01_command-model-tier-inventory.md
- **Artifacts**: plans/01_right-size-command-model-tiers.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 790 refreshed the model-tiering rationale and task 789 pinned the sonnet tier to Sonnet 5 (1M context). This task applies the refreshed policy to slash-command `model:` frontmatter: 18 command files currently carry `model: opus`. Six context-accumulating orchestrators and deep-reasoning commands keep opus and are untouched; the other 12 are down-tiered by editing the **canonical extension sources** (never the generated `.claude/commands/` copies/symlinks). Six pure-delegation commands have the `model:` line removed entirely so they inherit their skill/agent's declared tier; six inline/single-shot commands are changed to `model: sonnet`. The root-cause (an embedded command template in `meta.md` that hardcodes opus for every scaffolded command) and two contradictory docs are reconciled so the fix does not recur. Definition of done: greps confirm the intended per-command tiers at the source level, the embedded template no longer hardcodes opus, the two docs agree with the refreshed policy, and the user is told to run the Neovim extension-picker resync twice to propagate to both `.claude/commands/` trees.

### Research Integration

The plan is grounded in `reports/01_command-model-tier-inventory.md`, which provides the verified classification of all 18 opus-tagged command files (6 KEEP-OPUS, 6 OMIT-FIELD, 6 DOWNGRADE-TO-SONNET), the generation-source mapping (all `.claude/commands/*.md` are copies or symlinks of extension sources — edits at `.claude/commands/` are silently reverted on resync), the root-cause location (`meta.md` embedded template ~line 184), and the stale-doc reconciliation targets. Research also verified that zero downgrade candidates have any load-bearing `opus` rationale in their bodies, so all 12 down-tier edits are safe. Pre-planning verification confirmed every current source value and pinned exact edit locations (see "Verified facts" below).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in delegation context; roadmap alignment not evaluated for this plan.

### Verified facts (from source inspection during planning)

- KEEP-OPUS sources currently `model: opus` (untouched): `research.md`, `plan.md`, `implement.md`, `orchestrate.md`, `revise.md`, and `meta.md` frontmatter (line 5).
- `meta.md` contains **two** `model: opus` lines: line 5 (frontmatter — KEEP) and line 184 (embedded "Command Template Reference" — the root cause to FIX). Edits must target only line 184's block, not line 5.
- OMIT-FIELD sources currently `model: opus`: `fix-it.md`, `spawn.md`, `project-overview.md`, `refresh.md`, `tag.md` (core) and `vet.md` (cslib).
- DOWNGRADE sources currently `model: opus`: `merge.md`, `errors.md`, `task.md`, `todo.md`, `review.md` (core) and `pr.md` (cslib).
- `command-template.md` line 5 is already `model: sonnet` (verify-only).
- `creating-commands.md` frontmatter example (~line 48) shows `model: opus`; its "Model Selection" table (~lines 62-73) is inverted versus the refreshed policy (it tells dispatch/orchestrator commands to use sonnet and utility/direct-execution to use opus). Requires rewrite.

## Goals & Non-Goals

**Goals**:
- Remove the `model: opus` line from the 6 OMIT-FIELD command sources so they inherit their skill/agent tier.
- Change the 6 DOWNGRADE command sources from `model: opus` to `model: sonnet`.
- Fix the root-cause `meta.md` embedded command template so newly scaffolded commands no longer hardcode opus.
- Reconcile `creating-commands.md` and `command-template.md` to match the refreshed tiering policy.
- Verify via grep that all three source groups carry the intended tiers and the KEEP-OPUS six are unchanged.
- Flag the two required Neovim extension-picker resyncs (nvim project and dotfiles project) as a user-run manual step.

**Non-Goals**:
- Re-tiering agent frontmatter (task 790 settled: zero moves).
- Changing the opus default on the KEEP-OPUS orchestrator/deep-reasoning commands.
- Hand-editing any file under `.claude/commands/` or `/home/benjamin/.dotfiles/.claude/commands/` (generated; edits reverted on resync).
- Running the extension-picker resync (implementer cannot; user-run only).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing the wrong `model: opus` line in `meta.md` (frontmatter line 5 instead of embedded template line 184) | H | M | Target the embedded template block by matched context (the `# /{command} Command` scaffold), not a global replace; verify line 5 still reads `model: opus` after the edit. |
| Editing generated `.claude/commands/` copies instead of extension sources | M | M | Plan edits only `.claude/extensions/core/commands/` and `.claude/extensions/cslib/commands/`; Phase 4 greps target the extension sources. |
| Accidentally down-tiering a KEEP-OPUS command | H | L | KEEP-OPUS files are never opened for edit; Phase 4 explicitly greps the six to confirm `model: opus` is intact. |
| Docs left inconsistent, causing recurrence | M | L | Phase 3 reconciles both docs and the embedded template in one pass; Phase 4 verifies consistency. |
| User forgets one of the two resyncs, leaving a tree stale | M | M | Summary/handoff explicitly flags "run the extension-picker resync TWICE — once for nvim, once for dotfiles" as a required manual step. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phases 1, 2, and 3 edit disjoint file sets and may run concurrently; Phase 4 verifies all prior edits.

### Phase 1: OMIT-FIELD edits (remove `model: opus`) [COMPLETED]

**Goal**: Remove the entire `model: opus` frontmatter line from the 6 pure-delegation command sources so they inherit the tier declared by the skill/agent they dispatch to.

**Tasks**:
- [x] Edit `.claude/extensions/core/commands/fix-it.md` — delete the `model: opus` line from frontmatter. *(completed)*
- [x] Edit `.claude/extensions/core/commands/spawn.md` — delete the `model: opus` line. *(completed)*
- [x] Edit `.claude/extensions/core/commands/project-overview.md` — delete the `model: opus` line. *(completed)*
- [x] Edit `.claude/extensions/core/commands/refresh.md` — delete the `model: opus` line. *(completed)*
- [x] Edit `.claude/extensions/core/commands/tag.md` — delete the `model: opus` line. *(completed)*
- [x] Edit `.claude/extensions/cslib/commands/vet.md` — delete the `model: opus` line. *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/commands/{fix-it,spawn,project-overview,refresh,tag}.md` - remove `model:` frontmatter line
- `.claude/extensions/cslib/commands/vet.md` - remove `model:` frontmatter line

**Verification**:
- For each of the 6 files, the frontmatter block (delimited by the leading `---` pair) contains no `model:` line, and the surrounding frontmatter (`description`, `allowed-tools`, `argument-hint`) is intact and still valid YAML.

---

### Phase 2: DOWNGRADE-TO-SONNET edits (`opus` -> `sonnet`) [COMPLETED]

**Goal**: Change the `model:` frontmatter value from `opus` to `sonnet` on the 6 inline/single-shot command sources that do their own mechanical work with no skill/agent dispatch.

**Tasks**:
- [x] Edit `.claude/extensions/core/commands/merge.md` — `model: opus` -> `model: sonnet`. *(completed)*
- [x] Edit `.claude/extensions/core/commands/errors.md` — `model: opus` -> `model: sonnet`. *(completed)*
- [x] Edit `.claude/extensions/core/commands/task.md` — `model: opus` -> `model: sonnet`. *(completed)*
- [x] Edit `.claude/extensions/core/commands/todo.md` — `model: opus` -> `model: sonnet`. *(completed)*
- [x] Edit `.claude/extensions/core/commands/review.md` — `model: opus` -> `model: sonnet`. *(completed)*
- [x] Edit `.claude/extensions/cslib/commands/pr.md` — `model: opus` -> `model: sonnet`. *(completed)*

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/commands/{merge,errors,task,todo,review}.md` - set `model: sonnet`
- `.claude/extensions/cslib/commands/pr.md` - set `model: sonnet`

**Verification**:
- For each of the 6 files, the frontmatter `model:` line reads exactly `model: sonnet` and no other `model:` line was introduced.

---

### Phase 3: Root-cause template fix + stale-doc reconciliation [COMPLETED]

**Goal**: Stop the recurrence at its source (the `meta.md` embedded command template that hardcodes opus for every scaffolded command) and reconcile the two docs that describe command model tiers so guidance matches the refreshed policy.

**Tasks**:
- [x] Edit `.claude/extensions/core/commands/meta.md` embedded "Command Template Reference" (the code block around line 184, containing `# /{command} Command`): change `model: opus` to `model: sonnet` so scaffolded commands default to the cheap tier, and add a one-line guidance note just above/below the block stating opus is reserved for context-accumulating orchestrators and deep-reasoning commands and that pure-delegation commands should omit the line. **Do NOT touch the frontmatter `model: opus` on line 5.** *(completed)*
- [x] Edit `.claude/docs/guides/creating-commands.md`: change the frontmatter example (~line 48) from `model: opus` to `model: sonnet`, and rewrite the "Model Selection" table (~lines 62-73) to match the refreshed policy: context-accumulating orchestrators (`/research`, `/plan`, `/implement`, `/orchestrate`) and deep-reasoning commands (`/meta`, `/revise`) = `opus`; pure-delegation commands (dispatch only to a skill/agent that declares its own model) = omit the field; inline/single-shot utility commands (`/todo`, `/review`, `/task`, `/merge`, `/errors`) = `sonnet`. *(completed)*
- [x] Verify `.claude/docs/templates/command-template.md` line 5 already reads `model: sonnet` (no change expected); if it disagrees, align it to `model: sonnet`. *(completed: already correct, no change needed)*
- [x] Ensure the reconciled guidance in `creating-commands.md`, `command-template.md`, and the `meta.md` embedded template are mutually consistent (default `model: sonnet`, opus reserved, omit for pure delegation). *(completed)*

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/commands/meta.md` - embedded template block (~line 184) only; add tiering guidance note
- `.claude/docs/guides/creating-commands.md` - frontmatter example + Model Selection table
- `.claude/docs/templates/command-template.md` - verify-only (line 5)

**Verification**:
- `grep -nE 'model: opus' .claude/extensions/core/commands/meta.md` returns only line 5 (frontmatter), not the embedded-template line.
- `creating-commands.md` Model Selection table lists orchestrators/deep-reasoning as opus and utility/dispatch as sonnet/omit (no remaining "utility = opus" or "dispatch = sonnet-only-because-lightweight" contradictions).
- `command-template.md` line 5 reads `model: sonnet`.

---

### Phase 4: Verification greps + flag two-picker-resync user step [COMPLETED]

**Goal**: Confirm every intended per-command tier at the source level, confirm the KEEP-OPUS six are unchanged and the root-cause template is fixed, and record the required user-run resync steps.

**Tasks**:
- [x] Run the KEEP-OPUS verification grep (expect `model: opus` on all six). *(completed: all six confirmed)*
- [x] Run the OMIT-FIELD verification grep (expect no `model:` line in the six frontmatters). *(completed: all six OK (omitted))*
- [x] Run the DOWNGRADE verification grep (expect `model: sonnet` on all six). *(completed: all six confirmed)*
- [x] Run the meta.md embedded-template grep (expect only line 5 remaining as `model: opus`). *(completed: only "5:model: opus" returned)*
- [x] Confirm docs consistency (`creating-commands.md`, `command-template.md`). *(completed: both agree with refreshed policy)*
- [x] Record in the implementation summary the required manual step: run the Neovim extension-picker resync **twice** — once for the nvim project (`/home/benjamin/.config/nvim`) and once for the dotfiles project (`/home/benjamin/.dotfiles`) — to propagate the edited extension sources into both `.claude/commands/` trees. The implementer must NOT hand-edit `.claude/commands/` or dotfiles files. *(completed: see summary)*

**Timing**: 20 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- None (verification and reporting only; no edits under `.claude/commands/` or dotfiles).

**Verification** (exact commands, run from `/home/benjamin/.config/nvim`):

```bash
# 1. KEEP-OPUS still opus (expect each to print "model: opus")
for f in .claude/extensions/core/commands/{research,plan,implement,orchestrate,revise}.md; do
  echo "$f: $(grep -m1 -E '^model:' "$f")"; done
echo "meta.md frontmatter: $(sed -n '1,6p' .claude/extensions/core/commands/meta.md | grep -E '^model:')"

# 2. OMIT-FIELD sources have NO frontmatter model: line (expect "OK (omitted)" for all six)
for f in .claude/extensions/core/commands/{fix-it,spawn,project-overview,refresh,tag}.md \
         .claude/extensions/cslib/commands/vet.md; do
  if awk '/^---$/{c++; next} c==1 && /^model:/{found=1} c>=2{exit} END{exit !found}' "$f"; then
    echo "FAIL (still has model): $f"; else echo "OK (omitted): $f"; fi
done

# 3. DOWNGRADE sources are sonnet (expect each to print "model: sonnet")
for f in .claude/extensions/core/commands/{merge,errors,task,todo,review}.md \
         .claude/extensions/cslib/commands/pr.md; do
  echo "$f: $(grep -m1 -E '^model:' "$f")"; done

# 4. meta.md embedded template no longer hardcodes opus (expect ONLY "5:model: opus")
grep -nE 'model: opus' .claude/extensions/core/commands/meta.md

# 5. Docs consistency (manual read)
sed -n '45,75p' .claude/docs/guides/creating-commands.md
sed -n '1,6p'   .claude/docs/templates/command-template.md
```

Pass criteria: (1) all six print `model: opus`; (2) all six print `OK (omitted)`; (3) all six print `model: sonnet`; (4) grep returns only `5:model: opus`; (5) docs describe orchestrators/deep-reasoning = opus and utility/dispatch = sonnet/omit, template line 5 = `model: sonnet`.

---

## Testing & Validation

- [x] KEEP-OPUS grep: all 6 sources still `model: opus` (5 core + meta.md line 5). *(completed)*
- [x] OMIT-FIELD grep: all 6 sources have no frontmatter `model:` line. *(completed)*
- [x] DOWNGRADE grep: all 6 sources read `model: sonnet`. *(completed)*
- [x] Root-cause grep: `meta.md` has `model: opus` only on line 5 (embedded template fixed). *(completed)*
- [x] Docs consistency: `creating-commands.md` table and `command-template.md` line 5 agree with the refreshed policy. *(completed)*
- [x] Frontmatter validity: each edited file's YAML frontmatter still parses (delimiters intact, remaining keys present). *(completed: verified via grep/sed inspection above)*

## Artifacts & Outputs

- `plans/01_right-size-command-model-tiers.md` (this file)
- `summaries/01_right-size-command-model-tiers-summary.md` (produced by /implement) — must include the two-resync manual-step flag
- Edited sources: 6 OMIT + 6 DOWNGRADE command files + `meta.md` embedded template + `creating-commands.md` (+ `command-template.md` verify-only)

## Rollback/Contingency

- All changes are one-line frontmatter edits and doc-text edits under version control. To revert, `git checkout -- <file>` the affected extension sources and docs, or revert the task commit.
- Because only extension **sources** are edited (never generated `.claude/commands/`), no cleanup of generated trees is needed; the generated copies remain on their old values until the user runs the picker resync, so a rollback before resync leaves both `.claude/commands/` trees untouched.
- If a downgrade later proves incorrect for a specific command, re-add `model: opus` to that single source and resync — the change set is per-command and independently reversible.
