# Implementation Plan: Task #222

- **Task**: 222 - Add Rust extension to agent system
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/222_add_rust_extension_to_agent_system/reports/01_add_rust_extension.md
- **Artifacts**: plans/01_add-rust-extension.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a new, lean `agent-system/extensions/rust/` extension that adds a `rust` task type, using
the `python` extension as the structural template (manifest, EXTENSION.md, README.md,
index-entries.json, opencode-agents.json, one research and one implementation agent, two thin
wrapper skills, one short context README). Rust-specific content is the cargo verification loop
(`cargo check`, `cargo clippy --all-targets --all-features -- -D warnings`, `cargo fmt --check`,
`cargo test`) and a short inline "Rust Best Practices" section. Definition of done: the extension
exists in the source store, is registered in the extensions README table and the agent-contract
lint's in-scope list, and passes the source-store lints (routing wiring, agent contracts, JSON
validity). All edits target `agent-system/extensions/**`, never `.claude/**`.

### Research Integration

Integrated from `reports/01_add_rust_extension.md`:
- Base template is `python` (lean), not `nix` (MCP server, hooks, rules file, large context).
- No MCP server, no `settings-fragment.json`, no `rules/rust.md`, no hooks: the Rust MCP
  ecosystem is fragmented (no `mcp-nixos` equivalent), and `cargo fmt`/`cargo clippy` already
  mechanically enforce what a rules file would document. `crates-mcp`/`docsrs-mcp` are mentioned
  in README prose only as possible future optional additions.
- Context stays a single generic `context/project/rust/README.md`; no fabricated downstream
  domain docs (python's ModelChecker files are not a pattern to copy).
- Error-handling convention: `thiserror` for libraries, `anyhow` for applications; avoid
  `unwrap()`/`expect()` outside tests; `#[cfg(test)] mod tests` plus `tests/` integration tests.

### Decisions on the research's optional items

- **`keyword_overrides` -- ACCEPTED.** Add `"keyword_overrides": {"rust": {"keywords": ["rust",
  "cargo", "rustc", "clippy", "crates.io"], "aliases": []}}` to `manifest.json`. It is
  extension-local (no core edit), costs a few lines, and without it `/task` has no way to infer
  `rust` at all (the core 4d hardcoded table has no Rust row). `aliases` stays empty, matching
  the latex/typst rationale. Editing core `commands/task.md`'s hardcoded 4d table is declined:
  the manifest field already short-circuits before 4d when the extension is loaded, and routing
  to `rust` when the extension is not loaded would dispatch to a missing skill.
- **`rust-preflight.sh` toolchain check -- DECLINED.** Rustup-installed cargo is near-universal
  where Rust work happens, and a missing `cargo` surfaces immediately and loudly on the first
  verification command; the hook adds a script, a manifest `hooks` block, and a maintenance
  surface for little value.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap consulted for this dispatch.

## Goals & Non-Goals

**Goals**:
- A loadable `rust` extension in `agent-system/extensions/rust/` mirroring python's file set.
- Research and implementation agents with a Rust-specific toolchain and verification loop.
- Registration in the two existing extension inventories (extensions README table; the
  agent-contract lint's in-scope list).
- Clean source-store lint results.

**Non-Goals**:
- No MCP server, settings fragment, rules file, hooks, or preflight scripts.
- No domain/patterns/standards context tree beyond one README.
- No deploy/regeneration of `.claude/` (regeneration is manual-only per
  `context/patterns/regeneration-is-manual-only.md`), and no loading of the extension into this
  nvim repo's own `.claude-extensions.json`.
- No change to core's hardcoded `/task` keyword table.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Python agent/skill files contain python-specific or ModelChecker-specific text that leaks into the Rust copies | M | M | Phase verification greps the new extension for `python`, `pytest`, `ruff`, `mypy`, `ModelChecker`, `theory` (case-insensitive) and requires zero hits |
| Shared contract fragments in python agents (no-task-references bullet, lit/memory flow imports) drift from what the lints require | M | L | Copy the current python files verbatim first, then substitute; run `lint-agent-contracts.sh` and `lint-routing-wiring.sh` from the source store |
| `index-entries.json` `load_when.agents` references an agent name that does not exist, or an entry points at a context file not created | M | L | Only one index entry (the README); validate path existence and agent names in Phase 4 |
| `"rust"` whole-word keyword produces false-positive routing | L | L | Whole-word matching; "rust" as a standalone word is overwhelmingly Rust-language intent. Revisit only if observed |
| An agent file lacks a valid `model:` frontmatter value | L | L | Copy python frontmatter (`model: sonnet`); Check B of lint-agent-contracts enforces |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Extension scaffold and manifest [COMPLETED]

**Goal**: Create the extension's top-level metadata files so every later file has a declared
home and name.

**Tasks**:
- [x] Read `agent-system/extensions/python/{manifest.json,EXTENSION.md,README.md,index-entries.json,opencode-agents.json}` in full as templates. *(completed)*
- [x] Create `agent-system/extensions/rust/manifest.json`: name/task_type `rust`, version `1.0.0`, description "Rust development with cargo build, clippy, rustfmt, and test integration", `dependencies: ["core"]`, `provides.agents` (`rust-research-agent.md`, `rust-implementation-agent.md`), `provides.skills` (`skill-rust-research`, `skill-rust-implementation`), `provides.context: ["project/rust"]`, empty commands/rules/scripts/hooks; `routing.research/implement` -> skills; `routing_agents.research/plan/implement` -> `rust-research-agent`/`planner-agent`/`rust-implementation-agent`; `merge_targets` claudemd (`section_id: "extension_rust"`), index, opencode_json; plus the `keyword_overrides` block from Decisions. *(completed)*
- [x] Create `EXTENSION.md` (~30 lines, python's section shape): language routing table (`rust` -> skills, tools incl. `Bash (cargo check/clippy/fmt/test)`), skill-agent mapping table, "no dedicated commands" note, context pointer. *(completed)*
- [x] Create `README.md` (~60 lines): purpose, file inventory, verification loop, and a short "Deliberately omitted" section (no MCP server / rules / hooks, with one-line reasons, naming `crates-mcp`/`docsrs-mcp` as possible future optional additions). *(completed)*
- [x] Create `index-entries.json` with a single entry for `project/rust/README.md` (`load_when.agents`: both rust agents; `task_types`: `rust`), matching python's entry schema exactly. *(completed)*
- [x] Create `opencode-agents.json` mirroring python's two-agent shape with rust names. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Five files, all under `agent-system/extensions/rust/`. Confirm by
`find agent-system/extensions/rust -maxdepth 1 -type f | wc -l` == 5 at phase end.

**Files to modify**:
- `agent-system/extensions/rust/manifest.json` - new
- `agent-system/extensions/rust/EXTENSION.md` - new
- `agent-system/extensions/rust/README.md` - new
- `agent-system/extensions/rust/index-entries.json` - new
- `agent-system/extensions/rust/opencode-agents.json` - new

**Verification**:
- `jq empty` succeeds on all three JSON files.
- `jq -S 'keys' manifest.json` matches python's key set plus `keyword_overrides`.

---

### Phase 2: Research agent and skill [COMPLETED]

**Goal**: Provide `rust-research-agent` and its thin wrapper skill.

**Tasks**:
- [x] Read `agent-system/extensions/python/agents/python-research-agent.md` and `skills/skill-python-research/SKILL.md` in full. *(completed)*
- [x] Create `agents/rust-research-agent.md`: same frontmatter shape (`model: sonnet`), same stage structure; Rust research sources (docs.rs, crates.io, doc.rust-lang.org/std, the Rust Reference, Clippy lint list, `cargo doc --open`/`cargo tree` for local exploration); codebase discovery hints (`Cargo.toml`, `Cargo.lock`, `src/lib.rs`/`src/main.rs`, `[workspace] members`, `tests/`, `benches/`). *(completed)*
- [x] Create `skills/skill-rust-research/SKILL.md`: substitute names/task type only; keep all shared flow imports (preflight/postflight/lit-stage4a) unchanged. *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/rust/agents/rust-research-agent.md` - new
- `agent-system/extensions/rust/skills/skill-rust-research/SKILL.md` - new

**Verification**:
- `grep -riE 'python|pytest|ruff|mypy|modelchecker' ` over both files returns nothing.
- `diff` against the python originals shows only domain-substitution hunks (no dropped shared-contract sections).

---

### Phase 3: Implementation agent and skill [COMPLETED]

**Goal**: Provide `rust-implementation-agent` (with the cargo verification loop and inline best
practices) and its wrapper skill.

**Tasks**:
- [x] Read `agent-system/extensions/python/agents/python-implementation-agent.md` and `skills/skill-python-implementation/SKILL.md` in full. *(completed)*
- [x] Create `agents/rust-implementation-agent.md`, preserving every shared contract section (including the no-task-references MUST NOT bullet and the `.claude/**` source-store bullet if present in the python original). Replace "Build Tools" with: `cargo check` (per-edit compile check), `cargo clippy --all-targets --all-features -- -D warnings` (lint gate), `cargo fmt` then `cargo fmt --check` (format gate), `cargo test` (final verification). Replace the Python best-practices block with a short "Rust Best Practices" section: lib vs bin crate layout and workspaces; `thiserror` (libraries) / `anyhow` (applications); no `unwrap()`/`expect()` outside tests and examples; `#[cfg(test)] mod tests` unit tests plus `tests/` integration tests; prefer borrowing over cloning to satisfy the borrow checker only when it does not obscure intent (i.e., do not silence errors with gratuitous `.clone()`); no new `unsafe` without a `// SAFETY:` comment. *(completed)*
- [x] Create `skills/skill-rust-implementation/SKILL.md`: substitute names/task type only. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/rust/agents/rust-implementation-agent.md` - new
- `agent-system/extensions/rust/skills/skill-rust-implementation/SKILL.md` - new

**Verification**:
- Same forbidden-term grep as Phase 2 returns nothing.
- All four cargo commands appear in the agent's tool list and execution-flow verification stages.
- `diff` against the python originals shows no dropped shared-contract sections.

---

### Phase 4: Context README, registration, and full lint pass [NOT STARTED]

**Goal**: Complete the file set, register the extension in existing inventories, and run the
full source-store gate set.

**Tasks**:
- [ ] Create `agent-system/extensions/rust/context/project/rust/README.md` (~40-50 lines, generic): Cargo package/workspace layout, edition/MSRV note (`rust-version` in `Cargo.toml`), where to look up APIs (docs.rs, `cargo doc`), pointer to the implementation agent's best-practices section. No invented downstream project content.
- [ ] Add a `| rust | rust | Rust development | [README](rust/README.md) |` row to `agent-system/extensions/README.md`'s Available Extensions table (after python).
- [ ] Add `"rust/agents/rust-implementation-agent.md"` to `IN_SCOPE_RELATIVE_PATHS` in `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` (after the python line), since the agent authors deliverable files outside `specs/**`.
- [ ] Run the gate set from the repo root against the source store: `bash agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh`, `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`, `jq empty` on all rust JSON files, and the task-reference check over `agent-system/extensions/rust/` (no "task N" citations). Compare failures against a pre-change baseline run so only new failures count.
- [ ] Confirm every `provides` entry in `manifest.json` resolves to an existing file/dir, and every `index-entries.json` path and agent name exists.

**Timing**: 1 hour 15 minutes

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: Three edits outside the new extension directory are needed (extensions
README table, lint in-scope list, nothing else). Confirm by `grep -rn "python-implementation-agent\|python/README.md" agent-system/extensions/core agent-system/extensions/README.md` (excluding `context/project`) -- any other registry site found must get a matching rust entry or a documented reason for omission.

**Files to modify**:
- `agent-system/extensions/rust/context/project/rust/README.md` - new
- `agent-system/extensions/README.md` - add table row
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - add in-scope path

**Verification**:
- Both lint scripts report no new failures relative to baseline.
- Final extension tree has exactly 10 files (5 top-level, 2 agents, 2 skills, 1 context README).

## Testing & Validation

- [ ] All rust JSON files parse (`jq empty`).
- [ ] `lint-routing-wiring.sh`: rust routing keys have routing_agents counterparts and agent files exist.
- [ ] `lint-agent-contracts.sh`: rust agents pass model and no-task-references-bullet checks.
- [ ] No python/ModelChecker residue in any rust file.
- [ ] No task-number references in any deliverable file.
- [ ] No writes under `.claude/**`.

## Artifacts & Outputs

- `agent-system/extensions/rust/` (10 files: manifest.json, EXTENSION.md, README.md, index-entries.json, opencode-agents.json, agents/rust-research-agent.md, agents/rust-implementation-agent.md, skills/skill-rust-research/SKILL.md, skills/skill-rust-implementation/SKILL.md, context/project/rust/README.md)
- Edited `agent-system/extensions/README.md` and `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`
- `specs/222_add_rust_extension_to_agent_system/summaries/01_add-rust-extension-summary.md`

## Rollback/Contingency

All changes are additive: the new directory can be removed with `git rm -r agent-system/extensions/rust`
and the two one-line registry edits reverted with a normal `git revert` of the relevant phase
commits. No deployed `.claude/` state is touched, so no regeneration is needed to roll back.
