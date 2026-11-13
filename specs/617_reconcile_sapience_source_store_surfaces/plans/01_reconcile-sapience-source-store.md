# Implementation Plan: Task #617

- **Task**: 617 - Reconcile sapience extension source store with retired machine-wide surfaces
- **Status**: [IMPLEMENTING]
- **Effort**: 1.75 hours
- **Dependencies**: Companion work `retire_machine_wide_sapience_surface` (sited in
  `/home/benjamin/.dotfiles`) -- confirmed landed, see Overview
- **Research Inputs**: specs/617_reconcile_sapience_source_store_surfaces/reports/01_reconcile-sapience-source-store.md
- **Artifacts**: plans/01_reconcile-sapience-source-store.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research dispatch for this task confirmed the precondition and then carried the edits for
three of the four named surfaces through to a commit (`c4efc1a4e`): `per-repo-scoping.md`'s
Hazards and lean-divergence paragraphs, `injection-site-scoping.md`'s former Owner Action 2
section, and `install-sapience-mcp-session-hook.sh`'s header comment and registration note. What
remains is a narrower, verifiable set: two further scripts in the same source store still assert
companion-gated gaps, the fourth named surface (`EXTENSION.md`) attributes the user-level
`SessionStart` hook solely to this extension's own installer, and the deployed `.claude/` tree is
stale for the sapience extension so none of the landed source-store text is mirrored yet.

### Premise Re-Validation (Carried-Figure Discipline)

The dispatch's flagged line is the constraint "STATE THE CURRENT ARRANGEMENT, never its draft
history". Checked and confirmed unchanged and still binding: every rewrite this plan schedules
describes how registration durability works now, with no reference to a prior draft, a prior
assertion, or which task changed it. Live state re-checked during planning rather than carried
from the report:

- `jq -r '.hooks.SessionStart[].hooks[].command' "$HOME/.claude/settings.json"` returns exactly
  three commands, the third being
  `bash $HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'`.
- `/home/benjamin/.dotfiles/config/claude/settings.json`'s `.hooks.SessionStart` carries the
  byte-identical command string as its own third entry -- the durable companion-owned writer.
- `jq -r '.mcpServers.sapience' "$HOME/.claude.json"` returns `null`; the machine-wide top-level
  registration is gone.
- No `registerMcpServer` assignment exists anywhere in `/home/benjamin/.dotfiles` outside the
  vendored flake module's own option definition, and the machine's active
  `modules/home/services/sapience.nix` defines no such option at all.

The precondition is therefore satisfied: the hazard the source store described is genuinely
discharged, not merely scheduled.

### Research Integration

The report's four substantive findings drive this plan directly: (1) the companion landed and is
verified two ways; (2) the dispatch's named path `merge-sources/claudemd.md` does not exist and
`EXTENSION.md` is the real merge source for `.claude/CLAUDE.md`'s Sapience Extension section,
byte-confirmed; (3) three surfaces were rewritten and committed; (4) `verify-sapience-mcp.sh`
carries the same class of stale framing and was deliberately left unedited as out of the
dispatch's four-surface SCOPE, recorded as a follow-up. This plan reverses that one deferral --
see Decisions below -- and adds `setup-sapience-mcp.sh`, found during planning to carry a
matching companion-gated claim.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation was
performed and no roadmap phases are scheduled.

## Goals & Non-Goals

**Goals**:

- Leave no surface in the sapience source store asserting that the `SessionStart` registration
  entry is wiped by a `home-manager switch`, or that the machine-wide top-level
  `.mcpServers.sapience` entry survives pending a companion task.
- Bring `EXTENSION.md` (the real surface 4) into agreement with `per-repo-scoping.md`'s Hazards
  section on who owns the durable registration entry.
- Re-confirm and record the two checkable properties the acceptance bar names: the installer
  reports a no-op against the live file, and `verify-sapience-mcp.sh`'s check (d) passes for this
  repository.
- Mirror the landed source-store text into the deployed `.claude/` tree, which is currently stale
  for this extension.

**Non-Goals**:

- Editing anything under `/home/benjamin/.dotfiles`. Its surfaces are that repository's to own.
- Editing anything under `.claude/**` by hand. The deployed mirror is regenerated, never
  hand-authored.
- Revisiting `injection-site-scoping.md`'s Owner Action 1, its Foreclosure 1 and 2 measurements,
  or the `verify-sapience-context-scoping.sh` pointer -- all three must survive untouched.
- Revisiting the one-session-start removal lag in `per-repo-scoping.md`, which remains accurate.
- Re-editing the three surfaces already reconciled in `c4efc1a4e`, except where Phase 4's sweep
  finds a residual assertion.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The two added scripts are read as scope creep rather than as the acceptance bar's own wording | M | M | Acceptance criterion 1 is source-store-wide ("No surface in the source store asserts..."), and `verify-sapience-mcp.sh`'s check (d) failure note asserts exactly that; the judgment and its boundary are stated in Decisions and must be restated in the summary |
| A rewrite of `setup-sapience-mcp.sh`'s header overstates what the nix side now does, since this repository cannot own that claim | M | M | Phase 2 requires a read-only re-check of `/home/benjamin/.dotfiles`'s nix module before wording the replacement, and the replacement describes only what is observable from this side (the live file's contents), never the other repository's internal configuration |
| Editing `verify-sapience-mcp.sh` regresses its own check logic | H | L | Phase 2 touches comment blocks only, never executable lines; `bash -n` plus a live run of the script are both in that phase's verification |
| Concurrent sibling tasks (615, 616) touch the same sapience extension tree | M | M | Both siblings have undeclared file scope; re-read every file immediately before editing, stage only this task's own explicit file list, and stop and report on any foreign modification found in these paths |
| `EXTENSION.md` edit leaves the deployed `.claude/CLAUDE.md` inconsistent until redeploy | L | H | Phase 4 redeploys and verifies the merged section matches |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Re-confirm the landed arrangement before editing [COMPLETED]

**Goal**: Independently re-establish, at implementation time, that the companion's durable
`SessionStart` entry is in place and the machine-wide surfaces are gone, so no edit in Phases 2-3
discharges a still-live hazard.

**Tasks**:
- [x] Run `jq -r '.hooks.SessionStart[].hooks[].command' "$HOME/.claude/settings.json"` and
      confirm the sapience registration command string is present. *(completed: third command is
      `bash $HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'`)*
- [x] Run `jq -r '.hooks.SessionStart' /home/benjamin/.dotfiles/config/claude/settings.json` and
      confirm the byte-identical command string is carried there as the durable writer.
      *(completed: dotfiles' third SessionStart entry carries the identical command string)*
- [x] Run `jq -r '.mcpServers.sapience // "ABSENT"' "$HOME/.claude.json"` and confirm `ABSENT`.
      *(completed: returns `ABSENT`)*
- [x] Read-only: confirm no `registerMcpServer` assignment exists in
      `/home/benjamin/.dotfiles` outside the vendored flake module's own option definition.
      *(completed: `modules/home/services/sapience.nix` has zero hits; all remaining hits are
      confined to the standalone, non-imported `packages/sapience-flake/` tree)*
- [x] If any check contradicts the above, STOP and report rather than proceeding -- the
      precondition gate has reopened. *(completed: no contradiction found, proceeding)*
- [x] Record the four results verbatim for reuse in the summary. *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: This phase writes no file; its own four `jq`/grep probes against the live
files are the complete check of what it asserts.

**Files to modify**:
- (none -- verification only)

**Verification**:
- All four probes return the stated results, and the outputs are captured for the summary.

---

### Phase 2: Reconcile the two remaining companion-gated scripts [COMPLETED]

**Goal**: Remove the stale companion-gated framing from
`agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` and
`agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh`, so the source store carries no
surface asserting a gap the companion closed.

**Tasks**:
- [x] Re-read both files immediately before editing (sibling tasks 615 and 616 have undeclared
      file scope on this same tree). *(completed: no foreign modification observed)*
- [x] In `verify-sapience-mcp.sh`, rewrite the header comment block that frames the surviving
      top-level `~/.claude.json` `.mcpServers.sapience` entry as "EXPECTED, not drift ... gated on
      a companion task this repository does not own". State the current arrangement: no top-level
      entry is present, registration is per-project, and `--retire-global` has nothing to retire
      on this machine. *(completed)*
- [x] In the same file, rewrite check (d)'s failure note. It currently tells the reader the entry
      is "reset from ~/.dotfiles/config/claude/settings.json on every 'home-manager switch'" --
      the inverse of what now holds, since that file is the durable writer that restores it. The
      replacement must still give the reader an actionable remedy (re-run the installer) without
      asserting the wipe premise. *(completed)*
- [x] In the same file, rewrite the trailing conditional NOTE block that fires when a top-level
      entry is found, so its text does not name a pending companion task. The block's condition
      is correct and stays; only its wording changes. *(completed: condition unchanged, wording
      restated to "stale leftover" framing)*
- [x] In `setup-sapience-mcp.sh`, rewrite the header paragraph asserting the top-level entry is
      "RE-CREATED unconditionally on every `home-manager switch` while
      `programs.sapience.registerMcpServer` is true" and that `--retire-global` is "deliberately
      inert in practice until a companion task ... disables that activation block". Describe only
      what is observable from this side; do not assert what the other repository's nix module now
      contains beyond what Phase 1's read-only check established. *(completed)*
- [x] Touch comment lines only in both files; change no executable line. *(completed: `git diff`
      confirms comment-line changes only in both files)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: Both files are standalone scripts with no importers, so `bash -n` plus a
live run of `verify-sapience-mcp.sh` and `setup-sapience-mcp.sh --dry-run` covers every behavior
either edit could reach.

**Scope Hypothesis**: Four comment blocks are expected to need rewriting -- three in
`verify-sapience-mcp.sh` (its header's top-level-entry paragraph, check (d)'s failure note, and
the trailing conditional NOTE) and one in `setup-sapience-mcp.sh` (its header's
`registerMcpServer` paragraph). The implementer confirms this by grepping both files for
`home-manager switch`, `companion`, and `retire-global` before editing and after, and reports any
block the hypothesis missed rather than silently absorbing or skipping it.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` - three comment blocks
  restated to the current arrangement
- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` - header paragraph restated to
  the current arrangement

**Verification**:
- `bash -n` passes on both files.
- `bash agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` runs and check (d)
  reports `[PASS]`.
- `bash agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh --dry-run` runs clean.
- `git diff` on both files shows comment-line changes only.
- `grep -n "until a companion task\|gated on a companion task\|will be WIPED" ` returns nothing in
  either file.

---

### Phase 3: Bring EXTENSION.md's registration-hook sentence into agreement [NOT STARTED]

**Goal**: Make the fourth named surface state who owns the durable user-level `SessionStart`
entry, rather than attributing it solely to this extension's own installer.

**Tasks**:
- [ ] Re-read `agent-system/extensions/sapience/EXTENSION.md` immediately before editing.
- [ ] Adjust the "Per-repo activation" paragraph's registration-hook sentence -- currently "A
      separate, user-level `SessionStart` hook (installed by
      `scripts/install-sapience-mcp-session-hook.sh`) registers or removes this project's own
      `~/.claude.json` MCP entry" -- so it names the companion-owned durable entry in
      `~/.dotfiles/config/claude/settings.json` as the writer that survives a `home-manager
      switch`, with this extension's installer as the converging second writer.
- [ ] Keep the "six hook surfaces in total, five of which are extension-merged" count intact and
      confirm it still holds after the rewording.
- [ ] Change nothing else in the file; confirm the remaining paragraphs make no durability claim
      needing correction.

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `EXTENSION.md` is a merge source consumed verbatim by the deploy pipeline
with no parser or schema over it, so the only check below the deploy itself is a read -- and
Phase 4's deploy plus merged-section comparison supplies the mechanical one.

**Files to modify**:
- `agent-system/extensions/sapience/EXTENSION.md` - registration-hook sentence restated

**Verification**:
- The edited sentence agrees with `per-repo-scoping.md`'s Hazards paragraph on which writer makes
  the entry durable.
- The hook-surface count sentence is unchanged and still accurate.
- `git diff` shows one paragraph changed, nothing else.

---

### Phase 4: Deploy, sweep, and record the acceptance properties [NOT STARTED]

**Goal**: Mirror the reconciled source store into the deployed tree and demonstrate every
acceptance criterion against the landed result.

**Tasks**:
- [ ] Redeploy with the bounded-wait idiom:
      `timeout 540 bash .claude/scripts/deploy-headless.sh` (Bash tool `timeout` parameter raised
      to 600000, per `context/patterns/external-process-wait.md` Rule 1). This regenerates the
      whole deployed tree, including `.claude/context/project/sapience/**` and
      `.claude/CLAUDE.md`'s Sapience Extension section.
- [ ] Confirm the deployed `.claude/CLAUDE.md` Sapience Extension section matches `EXTENSION.md`
      after the Phase 3 edit.
- [ ] Sweep the whole source store: `grep -rn "home-manager switch" agent-system/extensions/sapience/`
      and read every hit, confirming none asserts the registration entry is wiped.
- [ ] Re-run `bash agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh`
      against the live file and record the no-op result verbatim.
- [ ] Re-run `bash agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` and record
      check (d)'s `[PASS]` line verbatim.
- [ ] Confirm `injection-site-scoping.md` still carries Owner Action 1, the Foreclosure 1 and 2
      measurements, and the `verify-sapience-context-scoping.sh` pointer.
- [ ] Confirm `per-repo-scoping.md` still carries the one-session-start removal lag note.
- [ ] Record the `verify-sapience-mcp.sh` / `setup-sapience-mcp.sh` scope judgment (see Decisions)
      explicitly in the task summary, so a reader sees why the edit set is larger than the
      dispatch's four named surfaces.

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - the deploy regenerates the entire deployed `.claude/` tree

**Verification**:
- `deploy-headless.sh` exits 0 and the deploy-freshness warning for the sapience extension clears.
- `bash agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` exits 0 with check (d)
  `[PASS]`.
- `install-sapience-mcp-session-hook.sh` reports the no-op path, and that output is quoted in the
  summary.
- The whole-source-store `home-manager switch` sweep shows every remaining hit stating the
  current arrangement.
- `injection-site-scoping.md`'s Owner Action 1, both Foreclosures, and the
  `verify-sapience-context-scoping.sh` pointer are present.
- The full gate set for this task type runs clean before the task closes.

## Testing & Validation

- [ ] `bash -n` passes on both edited scripts.
- [ ] `verify-sapience-mcp.sh` exits 0, check (d) `[PASS]`, for this repository.
- [ ] `install-sapience-mcp-session-hook.sh` reports a no-op, not a second registration.
- [ ] `setup-sapience-mcp.sh --dry-run` runs clean.
- [ ] No source-store surface asserts the registration entry is wiped by a `home-manager switch`.
- [ ] `injection-site-scoping.md` retains Owner Action 1, Foreclosures 1 and 2, and the
      `verify-sapience-context-scoping.sh` pointer.
- [ ] `per-repo-scoping.md` retains the one-session-start removal lag note.
- [ ] Deployed tree is fresh for the sapience extension.
- [ ] No file under `/home/benjamin/.dotfiles` and no file under `.claude/**` was hand-edited.

## Artifacts & Outputs

- Edited: `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`
- Edited: `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh`
- Edited: `agent-system/extensions/sapience/EXTENSION.md`
- Regenerated: the deployed `.claude/` tree (whole-tree claim)
- Task summary recording the no-op result, the check (d) result, and the scope judgment

## Decisions

- **`verify-sapience-mcp.sh` is in scope, reversing the research dispatch's deferral.** That
  script's check (d) failure note tells the reader the live registration is "reset from
  ~/.dotfiles/config/claude/settings.json on every 'home-manager switch'", which is the wipe
  premise the acceptance bar forbids -- and criterion 1 is worded source-store-wide ("No surface
  in the source store asserts..."), not limited to the dispatch's four named surfaces. Meeting a
  stated acceptance criterion is not widening scope.
- **`setup-sapience-mcp.sh` is included in the same phase.** Its claim concerns the top-level
  `.mcpServers.sapience` entry rather than the registration entry, so it falls under the task
  GOAL ("stop asserting gaps that no longer exist") rather than criterion 1's literal wording.
  It is included because leaving one companion-gated claim standing in a sibling script of the
  one being corrected reproduces exactly the "reader assumes this is current too" risk the
  research report named -- at the cost of one comment block.
- **`EXTENSION.md` gets the minimal adjustment the dispatch anticipated**, rather than the "or
  nothing at all" branch the research chose. The current sentence is incomplete rather than
  false, but it leaves `EXTENSION.md` and `per-repo-scoping.md` disagreeing on who owns the
  durable entry, and `EXTENSION.md` is the surface merged into every session's `.claude/CLAUDE.md`.
- **The dispatch's named path `merge-sources/claudemd.md` is not created.** `EXTENSION.md` is the
  file the deploy pipeline merges, byte-confirmed against the deployed section; adding a second,
  unused merge source would only create drift risk.

## Rollback/Contingency

Every edit in Phases 2-3 is confined to comment blocks and one documentation paragraph in three
files under `agent-system/extensions/sapience/`, each committed separately per phase. Reverting
is `git revert` of the phase commit followed by a redeploy; no state, schema, or executable path
is touched. If Phase 1's re-confirmation contradicts the landed arrangement, no edit is made at
all and the task stops and reports -- discharging a still-live hazard is worse than leaving the
text alone.
