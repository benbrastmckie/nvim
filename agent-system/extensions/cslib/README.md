# CSLib Extension (v1.0.0)

> **Authoritative source**: `EXTENSION.md` and `manifest.json` are the sources of truth for
> this extension. This README is the consumer-facing summary; EXTENSION.md is auto-merged into
> CLAUDE.md and takes precedence if any content diverges.

CSLib Lean 4 computer science library formalization support. Provides research and implementation agents for CSLib contributions and PR workflows, inheriting `lean-lsp` MCP tools from the lean extension for live goal inspection, proof search, and Mathlib/CSLib lookup.

## Overview

| Task Type | Research | Plan | Implementation | Hard-mode routing |
|-----------|----------|------|----------------|-------------------|
| `cslib` | skill-cslib-research | planner-agent (direct) | skill-cslib-implementation | skill-cslib-research-hard / skill-cslib-implementation-hard |
| `pr` | skill-pr-review-research | planner-agent (direct) | skill-pr-review-implementation | none — falls back to standard skills under `--hard` |

The extension routes `cslib` task types through dedicated agents that enforce CSLib coding conventions, use the CI verification pipeline, and follow the project's reuse-first and proof-readability principles from CONTRIBUTING.md. The `pr` task type handles both PR submission preparation and PR review response workflows.

## Installation

Loaded via the extension picker. Once loaded, `cslib` and `pr` become recognized task types. The lean and literature extensions are auto-loaded as dependencies.

## Architecture

    cslib/
    +-- manifest.json                    # Extension configuration
    +-- EXTENSION.md                     # CLAUDE.md merge content (authoritative)
    +-- index-entries.json               # Context discovery entries
    +-- README.md                        # This file
    |
    +-- agents/
    |   +-- cslib-research-agent.md           # CSLib formalization research (opus)
    |   +-- cslib-implementation-agent.md      # CSLib proof implementation (sonnet)
    |   +-- cslib-research-hard-agent.md       # Hard-mode CSLib research (opus)
    |   +-- cslib-implementation-hard-agent.md # Hard-mode CSLib implementation (sonnet)
    |   +-- pr-review-research-agent.md        # Fetch/synthesize GitHub PR + Zulip (sonnet)
    |   +-- pr-review-implementation-agent.md  # Compose pr-response.md + zulip-response.md (sonnet)
    |   +-- cslib-vet-agent.md                 # Vet CSLib tasks against standards (sonnet)
    |
    +-- skills/
    |   +-- skill-cslib-research/              # Research skill wrapper
    |   +-- skill-cslib-implementation/        # Implementation skill wrapper
    |   +-- skill-pr-implementation/           # PR description preparation (pr-submission path)
    |   +-- skill-cslib-research-hard/         # Hard-mode research skill wrapper
    |   +-- skill-cslib-implementation-hard/   # Hard-mode implementation skill wrapper
    |   +-- skill-pr-review-research/          # PR review research skill wrapper
    |   +-- skill-pr-review-implementation/    # PR review implementation skill wrapper
    |   +-- skill-cslib-vet/                   # Vet skill wrapper
    |
    +-- commands/
    |   +-- pr.md                              # /pr command (submit CSLib PR, review PRs)
    |   +-- vet.md                             # /vet command (vet tasks against standards)
    |
    +-- rules/
    |   +-- cslib.md                           # CSLib coding conventions (auto-applied to *.lean)
    |   +-- cslib-lint-fix.md                  # Lint-fix workflow rules
    |
    +-- context/
        +-- project/
            +-- cslib/
                +-- domain/        # CSLib architecture, CONTRIBUTING standards, notation
                +-- patterns/      # Proof structure, module organization, reuse-first
                +-- standards/     # CI pipeline, PR conventions, mathlib style
                +-- tools/         # lake commands, linters, checkInitImports, mk_all

## Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-cslib-research | cslib-research-agent | opus | CSLib formalization research with lean-lsp MCP |
| skill-cslib-implementation | cslib-implementation-agent | sonnet | CSLib proof implementation with CI verification |
| skill-pr-implementation | cslib-implementation-agent | sonnet | PR description preparation only -- produces pr-description.md, transitions task to [PR READY]; branch creation and CI handled by /pr |
| skill-cslib-research-hard | cslib-research-hard-agent | opus | Hard-mode CSLib research: adversarial verification (H4), BibKey citation grounding (H3) |
| skill-cslib-implementation-hard | cslib-implementation-hard-agent | sonnet | Hard-mode CSLib proof implementation: anti-analysis (H2), sorry_inventory (H9), territory (H7) |
| skill-pr-review-research | pr-review-research-agent | sonnet | Fetch and synthesize GitHub PR and Zulip discussion for review tasks |
| skill-pr-review-implementation | pr-review-implementation-agent | sonnet | Compose pr-response.md and zulip-response.md for pr-type review tasks; falls back to legacy pr-description workflow when sources are absent |
| skill-cslib-vet | cslib-vet-agent | sonnet | Vet CSLib tasks against standards; run CI; create fix tasks with user confirmation |

## Language Routing

| Task Type | Research Tools | Implementation Tools |
|-----------|----------------|---------------------|
| `cslib` | WebSearch, WebFetch, Read, lean-lsp MCP (inherited) | Read, Write, Edit, Bash (lake build, lake test, lake lint, lake exe checkInitImports, lake exe lint-style, lake shake) |
| `pr` | gh api, python3 zulip client, Read, Bash | Read, Write, Edit, Bash (git, lake build, lake test) |

## Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/pr` | `/pr <task_number\|path\|description> [--draft] [--dry-run]` | Submit CSLib PR: create branch, run CI, create PR on leanprover/cslib (user-only) |
| `/pr` | `/pr --review <sources...>` | Create pr-type review task from GitHub PR URLs, Zulip URLs, or descriptions |
| `/pr` | `/pr N` (when task is [PR READY] with sources) | Push changes, post GitHub PR comment, optionally send Zulip message |
| `/vet` | `/vet <task_numbers> [focus_prompt]` | Quality-gate: vet completed CSLib task(s) against CONTRIBUTING.md, NOTATION.md, ORGANISATION.md; run CI; create fix tasks |

## Hard Mode for CSLib Tasks

Use `/research N --hard`, `/plan N --hard`, or `/implement N --hard` when one or more of the following apply:

1. **Previous research produced analysis-only output** with no actionable proof direction (no Lean code sketches, no Mathlib lemma candidates, no reuse check results)
2. **Task involves faithful transcription of a published CS paper** into Lean 4 (literature-backed: bisimulation theorems, operational semantics rules, type system proofs)
3. **Task has been in [IMPLEMENTING] for 2+ dispatch cycles** without completing any phase
4. **Proof requires BibKey citation traceability** against CSLib's `references.bib`
5. **Task involves multiple parallel proof obligations** requiring territory contracts (H7) to prevent file conflicts between agents

**Hard mode adds** (over standard cslib skills):
- H2: Strict read budget -- first proof write within 20% of tool calls
- H3: BibKey verification against `references.bib` for all cited theorems
- H4: Adversarial self-verification pass challenging every recommendation
- H7: Territory contracts for parallel implementation phases
- H9: `sorry_inventory` in every orchestrator handoff JSON

**Cost impact**: `--hard` multiplies token cost ~3-5x over standard cslib skills. Use for formally complex or previously-deflected tasks only.

**Hard-mode routing entries** (from manifest.json `routing_agents_hard` — the skill-level
`routing_hard` block this used to read from the `skill-cslib-*-hard` SKILL.md files is retired;
`/orchestrate --hard` dispatches the agents below directly):
- `cslib` research: `cslib-research-hard-agent`
- `cslib` implement: `cslib-implementation-hard-agent`
- `pr` research/implement: no `routing_agents_hard` entry — falls back to the standard
  `pr-review-research-agent`/`pr-review-implementation-agent` agents under `--hard`. The `pr` task
  type used to route through core's own standalone hard-mode research/implement skills, which
  have since been deleted; core's `--hard` planning/research/implement for
  `general`/`meta`/`markdown` now resolves through `skill-orchestrate`'s own hard-mode branch
  instead of a separate skill, and `pr` was never given its own dedicated hard-mode agent to fall
  back to.

## PR Review Workflow

The `pr` task type supports two paths depending on whether `sources` are present in the task state:

| Condition | Workflow |
|-----------|----------|
| `task_type: "pr"`, `sources` absent or empty | pr-submission: `/implement` produces pr-description.md |
| `task_type: "pr"`, `sources` present | pr-review: `/implement` produces pr-response.md + zulip-response.md |

**PR Submission path** (legacy):
1. Create task via `/task "Submit PR for..."` or `/pr <task|path|desc>`
2. `/implement N` routes to skill-pr-implementation, which produces `pr-description.md`
3. Task transitions to [PR READY]
4. User invokes `/pr N` to create branch, run CI, and submit the PR

**PR Review path**:
1. User invokes `/pr --review <github_pr_url> [zulip_url]` to create a pr-type task with sources
2. `/research N` routes to skill-pr-review-research, which fetches PR data and Zulip threads
3. `/implement N` routes to skill-pr-review-implementation, which composes `pr-response.md` and optionally `zulip-response.md`
4. Task transitions to [PR READY]
5. User invokes `/pr N` to post the GitHub PR comment and optionally send Zulip message

**Note**: Branch creation, git push, and GitHub API calls are performed only by the user-invoked `/pr` command -- never by agents.

## Keyword Auto-Detection

The extension registers `keyword_overrides` in manifest.json so `/task` can auto-detect task type from keywords in the task description:

| Task Type | Keywords | Aliases |
|-----------|----------|---------|
| `cslib` | lean, lean4, mathlib, theorem, proof, lint-fix | lean4 |
| `pr` | pr, pull request, submit, upstream, branch, rebase, cherry-pick | (none) |

When a task description contains one of these keywords, `/task` assigns the corresponding `task_type` automatically.

## Dependencies

This extension declares three dependencies in manifest.json:

| Dependency | Purpose |
|------------|---------|
| `core` | Base agent infrastructure, standard skills, state management |
| `lean` | lean-lsp MCP server, Lean 4 / Mathlib context, lean4 task type |
| `literature` | `specs/literature/` convention, `--lit` flag injection into prompts |

Dependencies are auto-loaded silently when the cslib extension is loaded (circular detection, depth limit of 5).

## MCP Integration

The `lean-lsp` MCP server is inherited from the lean extension dependency and provides:
- Goal state inspection (`lean_goal`)
- Proof search (`lean_state_search`, `lean_hammer_premise`)
- Mathlib/CSLib lookup (`lean_loogle`, `lean_leansearch`, `lean_leanfinder`)

## CI Verification Pipeline

CSLib implementations must pass:
- `lake test` - Run CslibTests suite
- `lake exe checkInitImports` - Verify Cslib.Init imports
- `lake exe lint-style` - Style linting
- `lake shake --add-public --keep-implied --keep-prefix` - Dependency analysis

## References

- [CSLib Repository](https://github.com/leanprover-community/cslib) (or local: `/home/benjamin/Projects/cslib/`)
- [CSLib CONTRIBUTING.md](../../../../../../../Projects/cslib/CONTRIBUTING.md)
- [Lean 4 Documentation](https://leanprover.github.io/lean4/doc/)
- [Mathlib](https://leanprover-community.github.io/mathlib4_docs/)
