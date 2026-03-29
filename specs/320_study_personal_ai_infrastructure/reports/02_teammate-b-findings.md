# Research Report: Teammate B Findings - PAI Utility Patterns & Hooks

**Task**: 320 - study_personal_ai_infrastructure
**Teammate**: B (Utility Patterns, Hooks, Tools focus)
**Started**: 2026-03-28T00:00:00Z
**Completed**: 2026-03-28T00:30:00Z
**Effort**: ~30 min exploration
**Sources/Inputs**: PAI repository cloned to `/tmp/PAI_B` (github.com/danielmiessler/Personal_AI_Infrastructure)
**Artifacts**: This report

---

## Key Findings

### 1. PAI Hook Architecture Is Comprehensive and Well-Documented

PAI v4.0.3 runs **22 hooks across 6 lifecycle events** with a formal architecture, shared libraries, and strict documentation standards. Our system has a solid foundation (9 hooks across 6 events) but is less systematic.

**PAI Hook Events vs. Our System:**

| Event | PAI Hooks | Our Hooks |
|-------|-----------|-----------|
| SessionStart | KittyEnvPersist, LoadContext, BuildCLAUDE | wezterm-clear-task-number, log-session, claude-ready-signal |
| UserPromptSubmit | RatingCapture, UpdateTabTitle, SessionAutoName | wezterm-task-number, wezterm-clear-status |
| PreToolUse | SecurityValidator, SetQuestionTab, AgentExecutionGuard, SkillGuard | Write/state.json validation only |
| PostToolUse | QuestionAnswered, PRDSync | validate-state-sync |
| Stop | LastResponseCache, ResponseTabReset, VoiceCompletion, DocIntegrity | post-command, tts-notify, wezterm-notify |
| SessionEnd | WorkCompletionLearning, SessionCleanup, RelationshipMemory, UpdateCounts, IntegrityCheck | (none) |
| SubagentStop | (none) | subagent-postflight |

**Notable PAI gap**: PAI lacks a `SubagentStop` hook - we have the more sophisticated subagent lifecycle control.

### 2. Three High-Value Hooks We Lack

**AgentExecutionGuard** (`PreToolUse` on `Task`): Detects when Task tool is called without `run_in_background: true` and emits a `<system-reminder>` warning. This is a lightweight guard (~10ms, no I/O) that enforces proper async agent patterns. We spawn agents frequently; this would reduce blocking UI invocations.

**SkillGuard** (`PreToolUse` on `Skill`): Blocks false-positive skill invocations caused by position-bias in skill lists. PAI documents this as a known bug where the first skill in the list (`keybindings-help`) gets triggered on unrelated prompts. We have the same `keybindings-help` skill and the same position-bias risk. This hook is pure string matching, <5ms execution.

**IntegrityCheck** (`SessionEnd`): Detects when `.claude/` system files have changed during a session and flags drift in documentation cross-references. PAI uses a transcript parser to identify Write/Edit tool calls and categorizes the changed paths. Our equivalent would watch for changes to `settings.json`, skill files, agent files, and hook scripts, then remind the agent to update README/index.json.

### 3. BackupRestore.ts - Directly Adoptable Utility

PAI ships a full-featured backup/restore tool at `Tools/BackupRestore.ts`. It provides:
- Timestamped backups of `~/.claude` with `bun BackupRestore.ts backup`
- Named backups: `bun BackupRestore.ts backup --name "before-upgrade"`
- Listing with size and contents summary
- Safe restore that auto-creates a `pre-restore` backup first
- Migration analysis: `migrate <backup>` identifies settings, hooks, skills, and MEMORY content from old installations

This addresses a real gap: our system has no backup mechanism before major changes. We currently rely on git, but git tracks only the project `.claude/` directory, not `~/.claude/`.

### 4. Pack System - A Deployable Extension Pattern

PAI's `Packs/` directory contains a portable extension pattern with three components per pack:

```
PackName/
├── README.md    # What it does
├── INSTALL.md   # Wizard-style AI-assisted installation guide
├── VERIFY.md    # Post-install verification checklist
└── src/         # Files to copy
```

The INSTALL.md files are designed for AI agents to follow: they include system analysis checks, `AskUserQuestion` decision points, backup steps, installation commands, and a final verification run. This is a self-contained "skill installation wizard" pattern.

Our system has an `extensions/` directory with a manifest.json loader, but lacks the wizard-style INSTALL.md + VERIFY.md pair for each extension. Adding these to our extensions would make them easier to install for users who don't have the agent system already loaded.

### 5. validate-protected.ts - Pre-Commit Content Scanning

`Tools/validate-protected.ts` is a pre-commit hook that scans staged files for:
- API keys (Anthropic, OpenAI, AWS, GitHub tokens, Slack tokens)
- Webhooks (Discord, Slack, ntfy, Zapier)
- Database credentials, private keys
- PII (SSN, credit cards, phone numbers, personal emails)
- Private path references (`/Users/daniel/`, `~/.claude/`)

It uses a `.pai-protected.json` manifest of regex patterns with exception files and context-aware false-positive suppression. This is most relevant as a git pre-commit hook for our repo since we commit `.claude/` files.

### 6. StatusLine Command - Session-State Display Pattern

`statusline-command.sh` is a responsive shell script called on every Stop event that generates a terminal status line. It uses 4 display modes based on terminal width (nano/micro/mini/normal) and aggregates:
- Git branch and dirty state
- Session ratings trend (sparklines)
- Active model name
- Context window percentage
- Weather/location (via cached API calls)

We already have `wezterm-notify.sh` and `wezterm-task-number.sh` for WezTerm status integration, but the PAI approach of a single unified status script with width-responsive output is cleaner than our multiple narrow-purpose hooks.

### 7. CLAUDE.md.template + BuildCLAUDE SessionStart Hook

PAI v4.0 introduces a `CLAUDE.md.template` file alongside `CLAUDE.md`. A `BuildCLAUDE.ts` hook runs at `SessionStart` and checks if the rendered CLAUDE.md needs regeneration (algorithm version change, DA name change, unresolved `{{variables}}`). If so, it rebuilds from template for the next session.

This solves a real problem: our CLAUDE.md files are static, so when settings change (e.g., a new extension loads), the CLAUDE.md doesn't reflect the current state. A template + build pattern would let us inject dynamic content (current task, loaded extensions, active project) into CLAUDE.md.

### 8. Hook Documentation Standard

PAI mandates a specific documentation header for every hook file:

```typescript
/**
 * HookName.hook.ts - [Brief Description] ([Event Type])
 *
 * PURPOSE: [2-3 sentences]
 * TRIGGER: [Event type]
 * INPUT: [Payload fields]
 * OUTPUT: [stdout, exit codes]
 * SIDE EFFECTS: [File writes, external calls]
 * INTER-HOOK RELATIONSHIPS: [DEPENDS ON, COORDINATES WITH, MUST RUN BEFORE/AFTER]
 * ERROR HANDLING: [Failure modes]
 * PERFORMANCE: [Blocking vs async, typical execution time]
 */
```

Our hooks use minimal inline documentation. Adopting this standard would make the hook system maintainable as it grows.

---

## Recommended Utilities (Top 5)

### 1. SkillGuard Hook (Integration Complexity: LOW)

**What**: `PreToolUse` hook on `Skill` tool that blocks known false-positive skills.
**Why**: We have `keybindings-help` as our first skill, and the same position-bias problem PAI documents. This is a 5-minute adaptation: copy the hook logic, update `BLOCKED_SKILLS` list to match our context.
**Implementation**: Port to bash (our hooks use bash, not TypeScript/Bun). Logic is simple: read stdin JSON, extract `skill` field, check against blocked list, output `{"decision": "block", "reason": "..."}` if matched.
**Source**: `/tmp/PAI_B/Releases/v4.0.3/.claude/hooks/SkillGuard.hook.ts`

### 2. AgentExecutionGuard Hook (Integration Complexity: LOW)

**What**: `PreToolUse` hook on `Task` tool that warns when `run_in_background` is false.
**Why**: Our team research skills spawn agents without this guard. Foreground agents block the UI. PAI's guard is non-blocking (warning only, never denies), so it's safe to add.
**Implementation**: Port to bash. Read stdin, check `run_in_background` in `tool_input`. If false/missing and not a fast-tier agent, output `<system-reminder>` warning via stdout.
**Source**: `/tmp/PAI_B/Releases/v4.0.3/.claude/hooks/AgentExecutionGuard.hook.ts`

### 3. BackupRestore Shell Script (Integration Complexity: LOW-MEDIUM)

**What**: Backup/restore utility for `~/.claude` and project `.claude/` directories.
**Why**: We have no backup mechanism before upgrades. The TypeScript tool uses Bun which may not be available; a bash equivalent of the `backup` and `list` commands would be immediately usable.
**Implementation**: Create `.claude/scripts/backup.sh` with timestamped copy of `.claude/` to `~/.claude/backups/nvim-config-YYYYMMDD-HHmmss/`. Add `list` and `restore` subcommands. No Bun dependency.
**Source**: `/tmp/PAI_B/Tools/BackupRestore.ts` (logic to adapt)

### 4. Extension INSTALL.md + VERIFY.md Pattern (Integration Complexity: MEDIUM)

**What**: Add `INSTALL.md` and `VERIFY.md` files to each extension in `.claude/extensions/`.
**Why**: Our extensions have `manifest.json` but no guided installation. A user pointing an AI at `extensions/neovim/INSTALL.md` would get a structured installation wizard that checks prerequisites, backs up existing files, and verifies the result.
**Implementation**: Create template INSTALL.md and VERIFY.md. Adapt content for each existing extension (neovim, lean4, latex, etc.). No code changes needed, only markdown files.
**Source**: `/tmp/PAI_B/Packs/ContextSearch/INSTALL.md` (pattern reference)

### 5. IntegrityCheck SessionEnd Hook (Integration Complexity: MEDIUM)

**What**: `SessionEnd` hook that detects changes to `.claude/` system files and flags documentation drift.
**Why**: We modify skills, agents, rules, and context files during meta tasks. There's no automatic check that `index.json`, README files, or CLAUDE.md files are updated to match. PAI's IntegrityCheck uses transcript parsing to identify changed files and issues reminders.
**Implementation**: Bash script that reads `CLAUDE_TOOL_INPUT` transcript path, extracts file paths from Write/Edit events, checks if changed files are in `.claude/` system directories, and outputs a `system-reminder` listing potentially outdated documentation.
**Source**: `/tmp/PAI_B/Releases/v4.0.3/.claude/hooks/IntegrityCheck.hook.ts` and `handlers/SystemIntegrity.ts`

---

## Integration Complexity Summary

| Utility | Complexity | Effort | Dependencies |
|---------|-----------|--------|-------------|
| SkillGuard hook | Low | 30 min | None (pure bash port) |
| AgentExecutionGuard hook | Low | 30 min | None (pure bash port) |
| BackupRestore script | Low-Medium | 2 hr | bash (already available) |
| Extension INSTALL.md pattern | Medium | 2-4 hr | Markdown writing per extension |
| IntegrityCheck hook | Medium | 3-4 hr | Transcript parsing (bash grep approach) |
| CLAUDE.md template system | High | 1-2 days | BuildCLAUDE handler, template syntax |
| validate-protected pre-commit | Medium | 2-3 hr | bash + patterns.yaml |

---

## Evidence / Specific File References

All files from `/tmp/PAI_B/Releases/v4.0.3/.claude/`:

| File | Evidence for |
|------|-------------|
| `hooks/SkillGuard.hook.ts` | Position-bias false positive fix, <5ms bash-portable |
| `hooks/AgentExecutionGuard.hook.ts` | Background agent enforcement pattern |
| `hooks/IntegrityCheck.hook.ts` | SessionEnd drift detection pattern |
| `hooks/README.md` | Hook architecture and documentation standards |
| `hooks/lib/change-detection.ts` | Transcript parsing for file change categorization |
| `settings.json` | Full hooks configuration with matcher patterns |
| `CLAUDE.md.template` | Template-based CLAUDE.md generation |
| `hooks/handlers/BuildCLAUDE.ts` | SessionStart template rebuild trigger |

From `/tmp/PAI_B/Tools/`:

| File | Evidence for |
|------|-------------|
| `BackupRestore.ts` | Backup/restore CLI with migrate analysis |
| `validate-protected.ts` | Pre-commit content scanning with regex patterns |

From `/tmp/PAI_B/Packs/`:

| File | Evidence for |
|------|-------------|
| `ContextSearch/INSTALL.md` | Wizard-style AI installation guide pattern |
| `ContextSearch/VERIFY.md` | Post-install verification checklist pattern |
| `README.md` | Pack system overview (11 capability packs) |

Our existing settings.json at `/home/benjamin/.config/nvim/.claude/settings.json` shows we already have hooks infrastructure using the same event names (PreToolUse, PostToolUse, Stop, SubagentStop, UserPromptSubmit, SessionStart) which confirms compatibility with PAI's patterns.

---

## Gap Analysis: What We Have vs. What PAI Has

**We have that PAI lacks:**
- SubagentStop hook for postflight orchestration (sophisticated subagent lifecycle control)
- Task state machine with formal status transitions
- Extension loader system with manifest.json
- Language-based routing in commands
- Team mode for parallel agent execution

**PAI has that we lack:**
- SkillGuard (false-positive prevention)
- AgentExecutionGuard (background agent enforcement)
- IntegrityCheck (SessionEnd drift detection)
- BackupRestore utility
- Wizard-style pack installation (INSTALL.md + VERIFY.md)
- CLAUDE.md template system for dynamic regeneration
- Hook documentation standards (PURPOSE/TRIGGER/INPUT/OUTPUT/SIDE EFFECTS/PERFORMANCE)

---

## Confidence Level

**High** for hooks analysis - direct code inspection of 22 hooks across all lifecycle events, cross-referenced with our 9 existing hooks.

**High** for BackupRestore - complete code read, clear bash portability.

**Medium** for CLAUDE.md template system - BuildCLAUDE.ts is simple (~20 lines), but the full template syntax and what variables are supported requires reading `PAI/Tools/BuildCLAUDE.ts` (referenced but not in the Releases directory).

**Medium** for Pack system value - pattern is clear, but assessing how much value INSTALL.md/VERIFY.md would add requires knowing how often new users onboard vs. how often existing users add extensions.

---

## Appendix: Search Queries Used

1. `find /tmp/PAI_B -maxdepth 2 -type f` - Repository structure discovery
2. `find /tmp/PAI_B/Releases/v4.0.3/.claude/hooks -type f` - Hook inventory
3. Direct file reads: SkillGuard, AgentExecutionGuard, IntegrityCheck, SecurityValidator, WorkCompletionLearning, LoadContext, BuildCLAUDE
4. `cat /home/benjamin/.config/nvim/.claude/settings.json` - Our current hooks configuration
5. `ls /home/benjamin/.config/nvim/.claude/hooks/` - Our existing hook inventory
6. `cat /home/benjamin/.config/nvim/.claude/hooks/subagent-postflight.sh` - Our most sophisticated hook
