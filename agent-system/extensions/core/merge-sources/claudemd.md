Task management and agent orchestration for project development. For comprehensive documentation, see `.claude/docs/docs-README.md`.

## Quick Reference

- **Task List**: `specs/TODO.md`
- **Machine State**: `specs/state.json`
- **Error Tracking**: `specs/errors.json`
- **Architecture**: `.claude/docs/docs-README.md`

## Project Structure

```
.                         # Repository root
├── specs/               # Task management artifacts
│   ├── TODO.md         # Task list
│   ├── state.json      # Task state
│   └── {NNN}_{SLUG}/   # Task directories
└── .claude/             # Claude Code configuration
    ├── commands/       # Slash commands
    ├── skills/         # Skill definitions
    ├── agents/         # Agent definitions
    ├── rules/          # Auto-applied rules
    └── context/        # Domain knowledge
```

**Project-specific structure**: See `.claude/context/repo/project-overview.md` for details about this repository's layout.

**New repository setup**: If project-overview.md doesn't exist or contains the generic template notice (`<!-- GENERIC TEMPLATE`), run `/project-overview` to interactively scan the repository and create a generation task. See `.claude/context/repo/update-project.md` for guidance.

## Task Management

### Status Markers
- `[NOT STARTED]` - Initial state
- `[RESEARCHING]` -> `[RESEARCHED]` - Research phase
- `[PLANNING]` -> `[PLANNED]` - Planning phase
- `[IMPLEMENTING]` -> `[COMPLETED]` - Standard implementation terminus (general, meta, markdown, cslib, and all other non-pr task types)
- `[IMPLEMENTING]` -> `[PR READY]` -> `[COMPLETED]` - type=pr only: implementation + PR submission phase
- `[PR READY]` -> `[IMPLEMENTING]` - type=pr only: if PR review finds issues (re-dispatch)
- `[ABANDONED]`, `[EXPANDED]` - Terminal states (no further transitions)
- `[BLOCKED]`, `[PARTIAL]` - Exception states (non-terminal; any command can resume from these)
- `[HOLD]` - Paused state (non-terminal, but NOT resumable by any ordinary command; only an
  explicit `/orchestrate --research|--plan|--implement` override, which admits the task for one
  dispatch and preserves the hold afterward, or an operator-run lift via
  `update-task-status.sh preflight ... unhold`)

These are *resting* states. A status value passed to `update-task-status.sh` as a target argument
is not always the value that persists — see `.claude/context/standards/status-markers.md`'s
"Target Arguments vs. Resting States" subsection for the full rule and the concrete
`postflight:pr_ready -> completed` mapping it names.

### Artifact Paths
```
specs/{NNN}_{SLUG}/
├── reports/MM_{short-slug}.md
├── plans/MM_{short-slug}.md
└── summaries/MM_{short-slug}-summary.md
```
`{NNN}` = 3-digit zero-padded task directory numbers, `{DATE}` = YYYYMMDD.

**Naming Convention**: Artifacts use `MM_{short-slug}.md` format:
- `MM` = Zero-padded sequence number within task (01, 02, 03...)
- `{short-slug}` = 3-5 word kebab-case description extracted from task title
- Examples: `01_configure-lsp-python.md`, `02_implementation-plan.md`, `03_execution-summary.md`

**Note**: Task numbers remain unpadded (`{N}`) in TODO.md entries, state.json values, and commit messages. Only directory names and artifact sequence numbers use zero-padding for lexicographic sorting.

**System-Specific Naming**: Task directories use different prefixes by system:
- **Claude Code** (.claude/): `specs/{NNN}_{SLUG}/` (no prefix)
- **OpenCode** (.opencode/): `specs/OC_{NNN}_{SLUG}/` (OC_ prefix)

This distinction enables identification of which system created each task.

### Task-Type-Based Routing

**Core Task Types** (always available):

These task types route directly to agents via `skill-orchestrate`'s dispatch
(`command-route-agent.sh`), not through a dedicated research/plan/implement skill layer.

| Task Type | Research Agent | Plan Agent | Implementation Agent | Tools |
|-----------|-----------------|------------|-----------------------|-------|
| `general` | `general-research-agent` | `planner-agent` | `general-implementation-agent` | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `meta` | `general-research-agent` | `planner-agent` | `general-implementation-agent` | Read, Grep, Glob, Write, Edit |
| `markdown` | `general-research-agent` | `planner-agent` | `general-implementation-agent` | Read, Write, Edit |

**Extension Task Types** (available when extensions are loaded via the extension picker):

Extensions provide additional task type support (lean4, latex, typst, python, nix, web, z3, epi, formal, founder, present, etc.). See `.claude/extensions/*/manifest.json` for available extensions and their capabilities.

When an extension is loaded, its routing entries are merged into the command tables and context index.

Extensions can declare dependencies on other extensions via the `dependencies` array in manifest.json. Dependencies are auto-loaded silently when the parent extension is loaded, with circular detection and a depth limit of 5. See `.claude/context/guides/extension-development.md` for details.

Extensions may also declare lifecycle hooks in a top-level `hooks` object in `manifest.json` (distinct from `provides.hooks` which are file-copy targets). Hook scripts run at skill lifecycle stages (preflight, context_injection, verification, postflight) via `skill-base.sh`. See `.claude/docs/guides/creating-extensions.md#lifecycle-hooks` for the hook schema and execution contract.

Extensions can register `keyword_overrides` in their manifest.json to automatically detect their task type from keywords in the task description during `/task` creation. See `.claude/context/guides/extension-development.md` for the keyword_overrides schema.

## Command Reference

All commands use checkpoint-based execution: GATE IN (preflight) -> DELEGATE (skill/agent) -> GATE OUT (postflight) -> COMMIT.

| Command | Usage | Description |
|---------|-------|-------------|
| `/task` | `/task "Description"` | Create task |
| `/task` | `/task --recover N`, `--expand N`, `--sync`, `--abandon N` | Manage tasks |
| `/revise` | `/revise N` | Create new plan version |
| `/review` | `/review` | Analyze codebase |
| `/project-overview` | `/project-overview` | Interactive repo scan and project-overview.md generation |
| `/todo` | `/todo` | Archive completed/abandoned tasks, sync repository metrics |
| `/errors` | `/errors` | Analyze error patterns, create fix plans |
| `/meta` | `/meta` | System builder for .claude/ changes |
| `/fix-it` | `/fix-it [PATH...]` | Scan for FIX:/NOTE:/TODO:/QUESTION: tags |
| `/zulip` | `/zulip <zulip-url> [output-path]` | Fetch a Zulip thread via API and write formatted JSON to a file |
| `/refresh` | `/refresh [--dry-run] [--force]` | Clean orphaned processes and old files |
| `/tag` | `/tag [--patch|--minor|--major]` | Create semantic version tag (user-only) |
| `/orchestrate` | `/orchestrate N[,N-N] [--lit] [--research] [--plan] [--implement]` | Drive task(s) autonomously through full lifecycle (no confirmation gates). See `.claude/docs/architecture/orchestrate-state-machine.md` for the full forced-phase, terminal-task-admission, artifact-keyed-admission and cycle-budget semantics. |
| `/spawn` | `/spawn N [blocker description]` | Spawn new tasks to unblock a blocked task |
| `/merge` | `/merge` | Create pull/merge request for current branch (user-only) |
| `/please` | `/please push origin feature-x` | Authorize one blocked push (user-only) |

**Multi-task syntax**: `/orchestrate` accepts multiple task numbers using commas and ranges (e.g., `/orchestrate 7, 22-24, 59`), processed via dependency-aware wave dispatch. See `.claude/context/patterns/multi-task-operations.md` for the full specification and `.claude/context/patterns/batch-orchestration-guardrails.md`'s "Batching Is the Default" section for which tasks to batch together.

### Utility Scripts

Standalone scripts not invoked as part of the normal research/plan/implement/postflight
lifecycle (repo-health probes, doc/contract lints, one-shot migrations, install helpers) are
catalogued, unabridged, in `.claude/docs/reference/utility-scripts-inventory.md` rather than
injected eagerly here.

## State Synchronization

See `.claude/rules/state-management.md` for the state.json schema, `default_task_type` precedence, completion workflow, and vault operation (task number reset) mechanics.

## Git Commit Conventions

Format: `task {N}: {action}` with session ID in body.
```
task {N}: complete research

Session: sess_1736700000_abc123
```

Standard actions: `create`, `complete research`, `create implementation plan`, `phase {P}: {name}`, `complete implementation`.

## Skill-to-Agent Mapping

Per-skill/per-agent purpose descriptions and model tiers are provided natively by the harness's
own Skill and Agent tool listings, injected free every session — they are not restated here. Each
agent's own file frontmatter (`description:`, `model:`) is the durable source. The table below
keeps only the Skill -> Agent pairing, which the harness does not provide.

| Skill | Agent |
|-------|-------|
| skill-meta | meta-builder-agent |
| skill-status-sync | (direct execution) |
| skill-refresh | (direct execution) |
| skill-todo | (direct execution) |
| skill-tag | (user-only) |
| skill-reviser | reviser-agent |
| skill-spawn | spawn-agent |
| skill-orchestrate | (direct execution) |
| skill-git-workflow | (direct execution) |
| skill-fix-it | (direct execution) |
| skill-zulip | (direct execution) |
| skill-project-overview | (direct execution) |
| /review | (direct execution) — code-reviewer-agent available for future skill integration |

**Model Enforcement**: Agents declare preferred models via `model:` frontmatter using a tiered policy (Opus for deep-reasoning agents, Sonnet for workers), overridable per-invocation by independent effort (`--fast`, `--hard`) and model (`--haiku`, `--sonnet`, `--opus`, `--fable`) flags. See `.claude/docs/reference/standards/agent-frontmatter-standard.md` for the full tier table and flag semantics.

**User-Only Skills**: Skills marked as "user-only" cannot be invoked by agents. These are for human-controlled operations like deployment (`skill-tag`).

**Extension Skills**: When extensions are loaded, additional skill-to-agent mappings are added (e.g., skill-{domain}-research -> {domain}-research-agent). Extension task types use bare values (e.g., `python`) or compound values (e.g., `present:grant`) for sub-routing.

## Hard Mode (`--hard`)

Hard mode encodes behavioral contracts distilled from high-complexity task orchestration (the BimodalLogic per-phase-dispatch baseline: 9 H-techniques, measured outcome: 0 lines -> 2,400+ lines across 13 dispatches).

### What Hard Mode Does

Hard mode activates a set of behavioral contracts and routing changes:
- **Anti-analysis (H2)**: Strict read budget, forbidden analysis-only outputs, defect bar enforcement
- **Reference grounding (H3)**: Source-to-implementation mapping with tier selection (literature/docs/code)
- **Adversarial verification (H4)**: Research output verified before plan dispatch
- **Divergence audit (H5)**: Three-strikes on any target triggers dedicated audit dispatch
- **Convergence policing (H6)**: Churn detection with per-target counters
- **Territory contracts (H7)**: Parallel dispatch with explicit file ownership
- **Phase sizing (H8)**: Each phase bounded to one agent run (~100-500 lines output)
- **Wrap-up discipline (H9)**: Orchestrator handoff JSON + incremental commits at every green milestone

### When to Use `--hard`

Use `--hard` when one or more of the following apply:

1. **2+ plan versions exist** for the same task without convergence
2. **Previous dispatches produced analysis-only output** with no file writes (analysis-paralysis signal)
3. **Task involves formal verification** (lean4, z3) requiring faithful transcription of mathematical sources
4. **Task involves literature-based implementation** (paper to code, spec to implementation)
5. **Task has been in [IMPLEMENTING] for 3+ dispatch cycles** without phase completion
6. **Task description contains "deflection" or "stuck"** indicators in /errors output

### Cost Impact

| Mode | Cost Multiplier |
|------|----------------|
| Standard | 1x |
| `--hard` | ~3-5x |

### Composability

- `--hard` works with model flags: `--hard --opus` uses Opus model with hard-mode contracts (also
  composable with `--fable`, e.g. `--hard --fable`)
- `--hard` works with extension routing: extensions declare `routing_agents_hard` in their manifest
- Graceful fallback: commands without hard variants silently use standard behavior

### Routing Mechanism

Every routing consumer (`command-route-agent.sh`, called from `/orchestrate`) shares one ladder,
implemented once in `scripts/lib/manifest-routing-lib.sh`, resolving `--hard` as a 4th
`effort_flag` argument against the `routing_agents`/`routing_agents_hard` manifest blocks.
See `context/guides/manifest-routing-schema.md` for the full routing model (the two surviving
routing blocks plus the unrelated `hard_contracts` key, agent-name declaration rules) and
`context/guides/hard-mode-routing.md` for `--hard`-specific detail.

### Per-Invocation Only

`--hard` is a per-invocation flag only. There is no sticky hard mode or `effort_mode` field
in state.json. Each invocation of `/orchestrate` must explicitly pass `--hard` to activate hard
mode.

## Literature Mode (`--lit`) — Extension Pointer

Full `--lit` documentation lives in the literature extension's merge source
(`agent-system/extensions/literature/merge-sources/claudemd.md`); when that extension is loaded,
its own `## Literature Mode (--lit)` section is merged in below with the complete contract. See
`context/patterns/context-discovery.md` for the general context-loading model.

## Rules References

Core rules (auto-applied by file path):
- `.claude/rules/state-management.md` - Task state patterns (specs/**)
- `.claude/rules/git-workflow.md` - Commit conventions
- `.claude/rules/error-handling.md` - Error recovery (.claude/**)
- `.claude/rules/artifact-formats.md` - Report/plan formats (specs/**)
- `.claude/rules/workflows.md` - Command lifecycle (.claude/**)
- `.claude/rules/plan-format-enforcement.md` - Plan format checklist (specs/**)
- `.claude/rules/no-task-references-in-deliverables.md` - No task-number citations outside specs/**
- `.claude/rules/source-store-deploy-boundary.md` - .claude/** is a disposable deploy artifact; resolve the source store via .claude-extensions.json's source_dir and edit there instead

**Extension Rules**: When extensions are loaded, additional rules are added (e.g., {domain}-rules.md for domain-specific development).

**This list is a curated subset, not the sole loading path**: `.claude/rules/*.md` files are
additionally auto-loaded natively by the Claude Code harness whenever a touched or referenced
path matches their own YAML `paths:` frontmatter glob — a mechanism completely independent of
this `@`-import list. A rule absent from the list above (e.g. `pr-prohibition.md`, whose
`paths: "**/*"` glob matches every path) is not thereby unwired; check its frontmatter before
concluding a rule file is dead.

## Context Discovery

See `.claude/context/patterns/context-discovery.md` for the full three-layer discovery model, the adaptive query pattern, and multi-layer discovery examples.

## Context Architecture

See `.claude/context/architecture/context-layers.md` for the full five-layer context model and the "Where to store new content" decision tree.

## Context Imports

Core context (always available):
- `.claude/context/repo/project-overview.md`
- `README.md`

**Extension Context**: Available when extensions are loaded via the extension picker. Query `index.json` for extension-specific context files.

## Multi-Task Creation Standards

See `.claude/docs/reference/standards/multi-task-creation-standard.md` for the full 8-component pattern, per-command compliance table, and reference implementation.

## Error Handling

- **On failure**: Keep task in current status, log to errors.json, preserve partial progress
- **On timeout**: Mark phase [PARTIAL], next `/orchestrate` (or resumed dispatch) picks up from there
- **Git failures**: Non-blocking (logged, not fatal)

## jq Command Safety

Claude Code Issue #1132 causes jq parse errors when using `!=` operator (escaped as `\!=`).

**Safe pattern**: Use `select(.type == "X" | not)` instead of `select(.type != "X")`

```bash
# SAFE - use "| not" pattern
select(.type == "plan" | not)

# UNSAFE - gets escaped as \!=
select(.type != "plan")
```

Full documentation: `.claude/context/patterns/jq-escaping-workarounds.md`

## Syncprotect

The `.syncprotect` file lives at the **project root** (not inside `.claude/`) and lists relative paths (one per line) of artifacts that should never be overwritten during sync operations. Lines starting with `#` are comments, blank lines are ignored. Paths are relative to the base directory (e.g., `rules/my-custom-rule.md`). Protected files are skipped during a full `[Reload All]`/`[Regenerate]` sync (or `deploy-headless.sh`) and individual artifact updates via `Ctrl-l`. The picker preview shows a "Protected Files" section listing which files will be skipped.

## Important Notes

- Update status BEFORE starting work (preflight) and AFTER completing (postflight)
- state.json = machine truth, TODO.md = user visibility
- All skills use lazy context loading: plain backticked path references resolved on demand (never eager `@`-imports)
- Session ID format: `sess_{timestamp}_{random}` - generated at GATE IN, included in commits
