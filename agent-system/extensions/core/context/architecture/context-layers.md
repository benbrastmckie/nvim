# Context Layer Architecture

**Created**: 2026-03-25
**Purpose**: Define the three independent context layers and their management boundaries
**Audience**: Agents, extension loader, system developers

---

## Overview

The system uses three independent context layers. Each has a distinct owner, lifecycle, and query mechanism. They are loaded in parallel when agents need comprehensive knowledge.

## Layer Definitions

| Aspect | Agent Context | Project Context | Project Memory |
|--------|--------------|-----------------|----------------|
| **Location** | `.claude/context/` | `.context/` | `.memory/` |
| **Managed by** | Extension loader | User (via index.json) | Agents over time |
| **Contains** | Core patterns + extension domain knowledge | Project-specific conventions | Learned facts and observations |
| **Lifecycle** | Rebuilt each time extensions are loaded | Persistent, user-edited | Persistent, agent-appended |
| **Query** | `.claude/context/index.json` | `.context/index.json` | Direct file reads |
| **Touched by loader** | Yes (copy + merge) | No | No |

## Five-Layer Summary and Storage Decision Tree

The three-layer model above groups "Agent Context" as a single row; in practice it is populated
from two distinct sources (core files vs. extension files), and a fifth layer — Claude Code's own
auto-memory — sits outside this system entirely. The full five-layer picture:

| Layer | Location | Owner | Contains |
|-------|----------|-------|----------|
| Agent context | `.claude/context/` | Extension loader | Core agent patterns + extension domain knowledge |
| Extensions | `.claude/extensions/*/context/` | Extension loader | Language-specific standards, tools, patterns |
| Project context | `.context/` | User (via index.json) | Project conventions not covered by extensions |
| Project memory | `.memory/` | Agents over time | Learned facts, discoveries, decisions |
| Auto-memory | `~/.claude/projects/` | Claude Code | User preferences, behavioral corrections |

**Where to store new content**:

```
Language-specific standard, pattern, or tool reference?
  YES --> extension context (.claude/extensions/*/context/)

Agent system pattern (orchestration, format, workflow)?
  YES --> .claude/context/

Project convention (coding style, naming, domain knowledge)?
  YES --> .context/

Learned fact from development (discovery, decision, pattern)?
  YES --> .memory/

User preference or behavioral correction?
  YES --> auto-memory (automatic, no action needed)
```

This decision tree is the canonical version; CLAUDE.md's own copy is a one-line pointer to here.

## Layer Details

### 1. Agent Context (.claude/context/)

The extension loader assembles this directory during extension loading:

- **Core files**: Agent system patterns, templates, reference docs (always present)
- **Extension files**: Language-specific context copied from `agent-system/extensions/*/context/` during load

The loader calls `copy_category("context", ...)` to copy extension context into `.claude/context/` and `append_index_entries()` to merge extension entries into the single `index.json`. After loading, all agent context (core + extensions) is queryable from one index.

All write operations use `target_dir` derived from `config.base_dir` (which is `.claude/`). The loader has no code path that references or writes to `.context/` or `.memory/`.

### 2. Project Context (.context/)

User-managed directory for project-specific conventions not covered by any extension. Governed by its own `index.json` with the same schema as the agent context index.

Starts empty. The user populates it with project conventions (coding style, naming rules, domain terminology) as needed. The extension loader does not touch this directory.

### 3. Project Memory (.memory/)

Agent-managed directory for persistent learned information. Independent from `.context/` -- neither manages nor references the other. Both are loaded in parallel when agents need project knowledge.

### Contracts directory: convention vs. load path

`context/contracts/` is the "Full details" companion referenced by the top-level
"Where to store new content" decision tree for the "Agent system pattern (orchestration, format,
workflow)?" branch. Two findings about that directory are recorded here so future work does not
have to re-derive them.

**Finding (i) — where a contract must live to be loaded by both standard and hard mode.**
Directory placement is not a load mechanism in this codebase. `context/contracts/` is a naming
and genre convention only; historically every occupant of the directory has been loaded
exclusively by `*-hard` agents and skills. What actually causes a contract to load is an
explicit `@`-reference bullet in the consuming agent's or skill's `## Context References`
section. A contract intended for both standard and hard mode may live in `context/contracts/`
provided it is explicitly referenced from both agents' (and both skills') Context References
sections, and its own header should say so plainly so a future reader does not assume
hard-mode-only applicability from placement alone. `contracts/phase-closure.md` and
`contracts/pre-edit-gate.md` are the first two contracts to do this: both are referenced from
`agents/general-implementation-agent.md` (both effort modes — core's own standalone hard-mode
implementation agent is deleted and merged into `skill-orchestrate`'s H1 branch) and
`skills/skill-orchestrate/SKILL.md` at minimum, and
the same explicit-reference mechanism has since been extended to the non-core extension
implementer surface (every extension implementer agent that runs a plan-phase loop, plus any
extension skill file maintaining its own contract-bullet list) — this list is illustrative of the
mechanism, not an exhaustive enumeration of every referrer.

**Finding (ii) — no central injection point exists.** Only core's standard implementation agent
(`agents/general-implementation-agent.md`) runs the adaptive `context-discovery.md` index query
that pulls in matching context by `load_when` criteria; no extension implementation agent and no
hard-mode implementation agent runs that query. `scripts/skill-base.sh`'s `context_injection`
lifecycle stage (`skill_context_injection`, which calls `skill_run_extension_hook
"context_injection" ...`) runs in the opposite direction from what a "central injection point"
would need: it lets an *extension* inject its own domain-specific content into a *core* skill's
dispatch prompt, not the other way around. There is no shared dispatch-prompt builder that a core
contract could hook into once to reach every consumer — each `SKILL.md` and each agent file
constructs its own dispatch prompt and its own Context References section inline.

**Narrower exception, --hard only.** `hard_contracts` (a manifest block, resolved by
`orchestrate-build-dispatch.sh`'s Stage 3.5 via `routing_lookup_flat()`) IS a genuinely central,
non-per-agent-hardcoded injection point — but only for the `<hard-mode-contracts>` block of a
`--hard` dispatch, never for a base-mode dispatch of any task_type. It does not contradict
Finding (ii) above: it resolves WHICH CONTRACT FILES to inject for a `--hard` dispatch of a given
`task_type`, read once per dispatch from the manifest, rather than letting each agent body
hand-copy `@`-reference bullets for the contracts it wants — see
`context/guides/manifest-routing-schema.md`'s "The `hard_contracts` Block" section. A core
contract added today still reaches no extension implementer "for free" outside `--hard`, and even
under `--hard` it reaches an extension only if that extension's manifest explicitly lists it.

**Consequence.** Propagating any core `context/contracts/` file to extension implementation
agents, OUTSIDE the narrow `hard_contracts` exception above, is manual, per-file work with no
shortcut through either the adaptive query or the `context_injection` hook. The in-repo precedent
for how this kind of manual propagation used to be done by hand — before `hard_contracts`
existed — was a now-retired `-hard`-suffixed agent family (e.g. the former
`cslib-implementation-hard-agent.md`) hand-copying core's `anti-analysis.md`, `wrap-up.md`, and
`territory.md` as individually listed `@.claude/context/contracts/...` bullets in its own
`## Context References` section; no surviving agent file does this today (a repo-wide
`grep -rl '@.claude/context/contracts/anti-analysis.md' agent-system/extensions/*/agents/*.md`
returns nothing). Any future task that adds a core contract and assumes it now reaches extension
implementers "for free" — whether via a central hook, or via `hard_contracts` for a task_type
that has not declared it — is working from a false premise.

## Eager vs. Lazy Loading Channels

The layers above describe where content *lives*; this section is the canonical inventory of how
content *enters an agent's context window*, and when. Four channels exist, and each is either
eager (in the session-start prompt prefix, paid on every invocation) or lazy (loaded on demand).

### Channel inventory

1. **Native CLAUDE.md chain (eager)**. Claude Code walks upward from the working directory and
   inlines every `CLAUDE.md` it finds (e.g. `~/.config/CLAUDE.md`, the repo's `CLAUDE.md`, and
   the generated `.claude/CLAUDE.md`). This is unconditional and is the baseline eager surface.

2. **`@`-import resolution (eager when it resolves; silently inert when it does not)**.
   An `@path` reference inside a CLAUDE.md file is resolved **relative to the containing file's
   directory** and, if the target exists, the whole target file is inlined eagerly into the
   prompt prefix. Two consequences of the directory-relative rule, measured during the
   context-loading audit:
   - From within `.claude/CLAUDE.md`, a ref written `@context/...` resolves (to
     `.claude/context/...`) and eagerly inlines the entire file.
   - From within `.claude/CLAUDE.md`, a ref written `@.claude/...` resolves to the nonexistent
     `.claude/.claude/...` and loads **nothing** — no error, no warning. A broken `@`-ref is
     indistinguishable from a working one to a reader of the file.
   Because of this trap, generated-CLAUDE.md merge sources in this repo use **plain backticked
   paths, never `@`-refs**: a path is a pointer an agent may follow with Read, and eager
   inlining is reserved for a deliberate decision, not a side effect of path style.

3. **Rules `paths:` frontmatter (absence = eager; presence = deferred)**. A file under
   `.claude/rules/` with no `paths:` YAML frontmatter is injected eagerly for every session. A
   rule with a `paths:` glob is deferred until a touched or referenced path matches the glob.
   Absence of frontmatter must therefore be a *decision*, not an omission — a deliberately-eager
   rule should carry a comment recording why (see `rules/source-store-deploy-boundary.md` for
   the pattern: its enforcement hook is PostToolUse/non-blocking, so learning the rule only
   after the first matching write would be too late).
   - **Stated unknown**: whether a `paths:`-gated rule fires *before* or only *after* the
     matching write reaches the tool layer has not been empirically established here. Before
     gating any rule whose value depends on pre-write timing (i.e. any enforcement rule), run an
     empirical test; do not assume either timing.
   - **Eager budget ceiling**: the class being bounded is every `rules/*.md` file that eagerly
     loads in a representative session — no `paths:` frontmatter, or a `paths:` glob (`specs/**/*`,
     `.claude/**/*`, or `"**/*"`) that matches a representative touched-path set (at minimum
     `specs/**` and `.claude/**` — see the "Eager-Context Measurement-Harness Correction" section
     of `specs/archive/054_split_eager_rules_budget/baseline-bytes.md` for why a narrower
     "absent-or-universal-only" check under-counts this class; `scripts/measure-eager-context.sh`
     implements the resulting glob-match model directly against the source store). Measurement
     command:
     `cat ~/.config/CLAUDE.md ~/.config/nvim/CLAUDE.md .claude/CLAUDE.md .claude/rules/git-workflow.md .claude/rules/artifact-formats.md .claude/rules/state-management.md .claude/rules/pr-prohibition.md .claude/rules/source-store-deploy-boundary.md .claude/rules/no-task-references-in-deliverables.md | wc -c`
     for the whole-prefix figure, or sum `wc -c` over just the six named rules for the class total
     alone. Measured class total at the time of writing (after a split-and-relocate pass over the
     four largest rules): **23,547 B** (six rules), whole-prefix **70,160 B** — down from a prior
     30,518 B / 80,808 B baseline, but the six-rule total still exceeds the originally-recommended
     20,000 B figure by 3,547 B: the KEEP-list discipline that split pass followed (preserve every
     forbidden-operations list, write-gating prohibition, and terminal-state restriction in full,
     never trim a pre-action constraint to hit a byte target) landed each eager core somewhat
     larger than the pre-split hypothesis. **The ceiling for this class is therefore set at
     24,000 B** (achieved 23,547 B plus a small stated headroom), not the original 20,000 B
     recommendation — stating a ceiling the tree already violates would be worse than no ceiling.
     A future change that pushes the six-rule class total above 24,000 B should trigger the same
     split-and-relocate treatment documented in `context/standards/git-workflow-narrative.md`,
     `context/standards/error-recovery-strategies.md`, and the CSLib
     `context/project/cslib/pr-command-workflow.md` relocation: move reactive/elaborative content
     to a lazily-loaded companion, keep only pre-action-binding constraints eager. Closing the
     remaining gap to a stricter ceiling would require either revisiting the KEEP-list discipline
     above (risky — it exists to prevent constraint loss) or the `artifact-formats.md`
     Example-Flow trim (~700 B, audited but deliberately left untouched by this split pass).

4. **Preflight injection (per-invocation, command-scoped)**. Memory retrieval
   (`<memory-context>`, suppressed by `--clean`) and literature briefing (`--lit`) are injected
   by command preflight stages into a single dispatch — they cost per invocation, not per
   session, and are governed by their own flags.

### The no-volatile-files-in-eager-prefix constraint

Files that change on every task operation — `specs/TODO.md`, `specs/state.json`,
`specs/errors.json`, and anything else mutated by the task lifecycle — must **never** be
`@`-imported into the eager prefix. Two independent reasons:

- **Cache economics**: the eager prefix is a cached prompt prefix; a volatile file in it
  invalidates the cache on every task operation, converting a one-time cost into a
  per-invocation cost.
- **Staleness**: the inlined snapshot is frozen at session start and silently diverges from the
  file on disk, which is worse than not loading it at all — agents should Read these files at
  point of use.

When auditing or "fixing" path references in merge sources, the forbidden direction is repairing
a broken-looking ref *upward* into a resolving `@`-form. The correct normalization is always
downward to a plain backticked path.

## Verification Summary

Confirmed by code review (2026-03-25) of the extension loader source:

- `loader.lua`: All target paths derive from `target_dir` parameter (the `.claude/` base directory). `M.copy_category` writes within this base for every category except `data`, which (per its `target_is_project_root` descriptor field) writes to `project_dir` instead -- but only for declared data directories, not `.context/`.
- `merge.lua`: `append_index_entries` operates on a `target_path` parameter pointing to `.claude/context/index.json`. No `.context/` references.
- `config.lua`: `base_dir` is set to `.claude` (or `.opencode`). No `.context/` configuration.
- Grep for `.context/` across all 8 files in the extensions module: zero matches.
