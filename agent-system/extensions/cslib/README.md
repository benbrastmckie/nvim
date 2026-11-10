# CSLib Extension (v1.0.0)

> **Authoritative source**: `EXTENSION.md` and `manifest.json` are the sources of truth for
> this extension. This README is the consumer-facing summary; EXTENSION.md is auto-merged into
> CLAUDE.md and takes precedence if any content diverges.

CSLib Lean 4 computer science library formalization support. Provides research and implementation agents for CSLib contributions and PR workflows, inheriting `lean-lsp` MCP tools from the lean extension for live goal inspection, proof search, and Mathlib/CSLib lookup.

## Overview

| Task Type | Research | Plan | Implementation | Hard-mode behavior |
|-----------|----------|------|----------------|---------------------|
| `cslib` | skill-cslib-research | planner-agent (direct) | skill-cslib-implementation | SAME skills/agents; `hard_contracts.cslib` injects behavioral contracts into the dispatch prompt |
| `pr` | skill-pr-review-research | planner-agent (direct) | skill-pr-review-implementation | SAME skills/agents; no `hard_contracts` entry for `pr`, so `--hard` reads core's generic contracts only |

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

Use `/orchestrate N --research --hard`, `--plan --hard`, or `--implement --hard` when one or more of the following apply:

1. **Previous research produced analysis-only output** with no actionable proof direction (no Lean code sketches, no Mathlib lemma candidates, no reuse check results)
2. **Task involves faithful transcription of a published CS paper** into Lean 4 (literature-backed: bisimulation theorems, operational semantics rules, type system proofs)
3. **Task has been in [IMPLEMENTING] for 2+ dispatch cycles** without completing any phase
4. **Proof requires BibKey citation traceability** against CSLib's `references.bib`
5. **Task involves multiple parallel proof obligations** requiring territory contracts (H7) to prevent file conflicts between agents

**Hard mode adds** (over standard cslib skills, same agent, injected as behavioral contracts
rather than carried by a separate agent body):
- H2: Strict read budget -- first proof write within 20% of tool calls
- H3: BibKey verification against `references.bib` for all cited theorems
- H4: Adversarial self-verification pass challenging every recommendation (cslib's own
  `cslib-adversarial-verification.md` override, content identical to core's generic H4 contract)
- H7: Territory contracts for parallel implementation phases
- H9: `sorry_inventory` in every orchestrator handoff JSON
- Goal-state context hygiene (targeted `lean_goal` queries, bounded file reads, hypothesis
  pruning) via lean's `lean4-context-hygiene.md`, reused as a deliberate cross-extension
  dependency since cslib's `--hard` dispatches edit Lean theorem files too

**Cost impact**: `--hard` multiplies token cost ~3-5x over standard cslib skills. Use for formally complex or previously-deflected tasks only.

**Hard-mode mechanism**: there is no separate `-hard`-suffixed agent or skill any more --
`routing_agents_hard` (the agent-level ladder rung this section used to describe) is retired.
`--hard` dispatches the SAME agent as standard mode (`cslib-research-agent` /
`cslib-implementation-agent`), and the domain-specific behavioral difference is provided by
manifest.json's `hard_contracts.cslib` block, injected into the dispatch prompt as a
`<hard-mode-contracts>` list — see `context/guides/manifest-routing-schema.md`'s "Override
Contract Placement Convention" subsection and "The `hard_contracts` Block" section for the full
mechanism. `pr` declares no `hard_contracts` entry, so a `pr` task's `--hard` dispatch reads
core's generic contracts only, with no cslib-specific override.

## PR Review Workflow

The `pr` task type supports two paths depending on whether `sources` are present in the task state:

| Condition | Workflow |
|-----------|----------|
| `task_type: "pr"`, `sources` absent or empty | pr-submission: the implement phase produces pr-description.md |
| `task_type: "pr"`, `sources` present | pr-review: the implement phase produces pr-response.md + zulip-response.md |

**PR Submission path** (legacy):
1. Create task via `/task "Submit PR for..."` or `/pr <task|path|desc>`
2. An implement-phase dispatch for N routes to skill-pr-implementation, which produces `pr-description.md`
3. Task transitions to [PR READY]
4. User invokes `/pr N` to create branch, run CI, and submit the PR

**PR Review path**:
1. User invokes `/pr --review <github_pr_url> [zulip_url]` to create a pr-type task with sources
2. A research-phase dispatch for N routes to skill-pr-review-research, which fetches PR data and Zulip threads
3. An implement-phase dispatch for N routes to skill-pr-review-implementation, which composes `pr-response.md` and optionally `zulip-response.md`
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
