---
title: "Directory placement is not a context-loading mechanism; @-references are"
created: 2026-08-09
tags: [INSIGHT]
topic: "agent-system/context"
source: "distill --learn retroactive harvest"
modified: 2026-08-09
retrieval_count: 0
last_retrieved: null
keywords:
  - context-loading
  - at-reference
  - context-contracts
  - index-entries.json
  - agent-prompt
summary: "A file under context/contracts/ is loaded only if an explicit @-reference bullet appears in the consuming agent's '## Context References' section. Placing a file in a directory does nothing on its own."
status: tombstoned
tombstoned_at: 2026-09-18
tombstone_reason: "purge"
token_count: 374
---

# Directory placement is not a context-loading mechanism; @-references are

In this agent system, putting a file in a particular context directory does **not** cause it to be loaded. A file under `context/contracts/` reaches an agent only if an explicit `@`-reference bullet appears in that agent's `## Context References` section.

This means authoring a new contract, standard, or pattern file is only half the work. The other half is adding the pointer bullet to every consuming agent — and only some agents carry any given bullet today, so "it exists in contracts/" is never evidence that a given agent sees it.

Two related facts:

- `@`-references in an agent body do **not** auto-resolve at subagent spawn. A shared fragment intended to appear in many agents is a *generated-copy source*, not an import — each agent carries its own literal copy, and a coverage lint is what keeps them from drifting apart.
- When appending a new pointer bullet, if a plan's Context References list ends in a markdown table or a `---` separator rather than a plain bullet, append directly after the last content line and before the next structural element. Do not invent a new subheading.

## Generated-CLAUDE.md side: `@`-refs are directory-relative and fail silently

Inside a CLAUDE.md file, an `@path` ref resolves **relative to the containing file's directory** and, when it resolves, eagerly inlines the entire target into the cached prompt prefix. From `.claude/CLAUDE.md` this creates two path-style classes with opposite behavior:

- `@context/...` resolves to `.claude/context/...` and loads the whole file eagerly, every session.
- `@.claude/...` resolves to the nonexistent `.claude/.claude/...` and silently loads **nothing** — no error, indistinguishable from a working ref when reading the file.

The audited fix direction is **downward normalization**: every `@`-ref in merge sources (`agent-system/extensions/*/merge-sources/claudemd.md`, `*/EXTENSION.md`) becomes a plain backticked path. Never "repair" a broken ref upward to a resolving `@`-form — that direction eagerly inlines files (thousands of tokens/session) and can admit volatile files (`specs/TODO.md`, `state.json`, `errors.json`) into the cached prefix, invalidating the cache on every task operation. Canonical write-up: `context/architecture/context-layers.md`, "Eager vs. Lazy Loading Channels".

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
- [[MEM-insight-index-json-tier]]
- [[MEM-insight-claude-code-contract-facts]]
