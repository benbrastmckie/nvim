# Research Report: Task #222

**Task**: 222 - Add a Rust extension to the agent system
**Started**: 2026-09-16T00:00:00Z
**Completed**: 2026-09-16T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: - Codebase (agent-system/extensions/{python,nix,web}/**, core extension-development guide), WebSearch
**Artifacts**: - specs/222_add_rust_extension_to_agent_system/reports/01_add_rust_extension.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The agent-system's extension architecture already provides two directly comparable precedents:
  `python` (lean — no MCP server, no hooks, no rules file) and `nix` (rich — MCP-NixOS server,
  preflight/context-injection hooks, a `rules/nix.md` path-scoped rule, and ~2,460 lines of
  domain/patterns/standards/tools context). The task explicitly asks for a lean Rust extension,
  so `python`'s shape is the base template; `nix`'s extras should only be copied where a
  Rust-specific analogue is independently well-motivated.
- **Recommended shape for `agent-system/extensions/rust/`**: `manifest.json`, `EXTENSION.md`,
  `README.md`, `index-entries.json`, `opencode-agents.json`, two agents
  (`rust-research-agent.md`, `rust-implementation-agent.md`), two skills
  (`skill-rust-research/SKILL.md`, `skill-rust-implementation/SKILL.md`), and a small
  `context/project/rust/README.md`. No `rules/rust.md`, no `settings-fragment.json`, no MCP
  server, no hooks — see Decisions for why each omission is well-motivated rather than merely
  lazy.
- **Toolchain**: `cargo check` (fast compile-check, analogous to `python -m py_compile`/`mypy`),
  `cargo clippy --all-targets --all-features -- -D warnings` (lint gate, analogous to `ruff
  check`), `cargo fmt --check` (format gate, analogous to `ruff format --check`), `cargo test`
  (analogous to `pytest`). These four commands cover the same verification loop shape the
  Python extension already uses, run directly via `Bash` — no LSP/MCP wiring is needed for this.
- **MCP servers researched and NOT recommended for default inclusion**: `crates-mcp`,
  `docsrs-mcp`, `rust-analyzer-mcp`/`rust-mcp`, `cargo-mcp` all exist but are small, fragmented,
  community-maintained crates without the single-project consensus that `mcp-nixos` (the nix
  extension's MCP server) has in the Nix community. `WebSearch`/`WebFetch` against
  `docs.rs`/`crates.io` cover the same research need the way the Python extension already covers
  `docs.python.org`/PyPI without an MCP server. This can be revisited later as an
  additive, optional merge target if a de facto standard Rust MCP server emerges.
- Rust conventions worth capturing belong inline in the agent files' "Rust Best Practices"
  section (mirroring `python-implementation-agent.md`'s inline module-structure/testing-pattern
  blocks), not in a separate `rules/rust.md` — `cargo fmt` and `cargo clippy` already
  auto-enforce formatting/idiom, unlike Nix (no single canonical auto-formatter is assumed) or
  Astro (component conventions aren't mechanically enforceable).

## Context & Scope

Researched how to add a new `rust` task type to this repo's portable agent-system extension
architecture (`agent-system/extensions/*`, deployed into `.claude/` at reload time — see
`.claude/rules/source-store-deploy-boundary.md`), modeled on the existing `python` and `nix`
extensions per the task description, while keeping the new extension lean and adding nothing not
well-motivated. Scope covered: (1) structural comparison of the `python`, `nix`, and `web`
extensions to determine which files are load-bearing vs. optional: (2) the canonical
extension-authoring contract in `agent-system/extensions/core/docs/guides/creating-extensions.md`
and `context/guides/extension-development.md`; (3) external research into the current (2026)
recommended toolchain and MCP-server landscape for Rust development with AI coding agents. No
code was written — this is a research-only dispatch; a subsequent `/plan 222` should turn these
findings into the phased file list.

## Findings

### Codebase Patterns

**Required extension files** (per `creating-extensions.md`'s Quick Start, confirmed against
`python`/`nix`/`web`): `manifest.json`, `EXTENSION.md`, `README.md` are required;
`index-entries.json` is "recommended" (all three existing extensions include it). This repo has
no Rust files or `Cargo.toml` anywhere, confirming the extension is pure portable infrastructure,
not tailored to this repo's own content (consistent with how `python`'s domain context targets a
different downstream consumer project, "ModelChecker," entirely unrelated to this nvim config
repo — extensions are written to be loaded by *any* project, not this one specifically).

**`python` (lean model, 823 lines total across all files)**:
- No `rules/`, no `settings-fragment.json`, no `scripts/` (hooks), no MCP server.
- `manifest.json`: `dependencies: ["core"]`; `routing.research/implement` map `python` to
  `skill-python-research`/`skill-python-implementation`; `routing_agents` additionally names
  `planner-agent` for the `plan` phase (shared, not extension-owned); `merge_targets` covers
  `claudemd`, `index`, `opencode_json` (no `settings` merge target, since there is no
  `settings-fragment.json`).
- Agents (`agents/python-research-agent.md` 140 lines, `agents/python-implementation-agent.md`
  184 lines) are self-contained: Allowed Tools list, a short "Python Best Practices" section
  with inline code blocks (module structure, testing pattern) instead of a separate rules file,
  an 8-stage Execution Flow, and MUST DO/MUST NOT lists. Verification commands
  (`pytest -v`, `python -m py_compile`, `mypy`, `ruff check`) are listed directly under "Build
  Tools" — no MCP indirection.
- Skills (`skills/skill-python-{research,implementation}/SKILL.md`, ~90-110 lines each) are thin
  wrappers delegating to the agent via the `Agent` tool, following the shared
  `skill-preflight-flow.md`/`skill-postflight-flow.md`/`lit-stage4a-flow.md` patterns already
  used by every research/implementation skill in this system — no Rust-specific work needed here
  beyond substituting names.
- `context/project/python/` exists but its content (`domain/model-checker-api.md`,
  `domain/theory-lib-patterns.md`, `patterns/semantic-evaluation.md`) is specific to a particular
  downstream Python framework the extension was evidently built alongside. This is **not** a
  pattern to imitate verbatim for Rust — there is no analogous concrete downstream project to
  document here, and inventing one would violate "adding nothing not well-motivated." A short,
  generic `context/project/rust/README.md` (workspace/crate layout, error-handling convention
  pointer, testing convention pointer) is the lean equivalent; it can stay a single file unless a
  concrete downstream Rust project later needs deeper domain docs (mirroring how `python`'s
  domain files exist because ModelChecker specifically needed them).

**`nix` (rich model, ~2,558 lines excluding context, ~2,461 more in context)**:
- Has `rules/nix.md` (path-scoped to `**/*.nix`, formatting + module-structure conventions),
  `scripts/nix-preflight.sh` (non-fatal warning if `nix` binary or `flake.nix` missing) and
  `scripts/nix-context.sh` (injects `nix --version` and flake-input count before agent
  delegation), wired via `manifest.json`'s `hooks.preflight`/`hooks.context_injection` fields.
  `settings-fragment.json` allowlists `mcp__nixos__nix` and `mcp__nixos__nix_versions`, and
  `manifest.json` declares `mcp_servers.mcp-nixos: {command: "uvx", args: ["mcp-nixos"]}`.
- The richness here is directly motivated by two things this repo's own environment makes
  visible: (1) `nix` is genuinely large/foreign-syntax territory (module system, flakes, overlays
  — hence ~2,460 lines of domain/patterns/standards/tools context) and (2) `mcp-nixos` is a
  single, well-established, `uvx`-installable server the Nix community has converged on for
  package/option search, closely paralleling how this same repo is itself a NixOS-adjacent
  config tree. Neither condition holds for Rust to the same degree (see External Resources).

**`web` (lean-plus-one-rule model)**: Same shape as `python` (no `context/project/web/`
directory at all — context files are fully optional), plus one `rules/web-astro.md` scoped to
`src/**/*.astro,*.ts,*.tsx` documenting naming conventions and Astro's three-section component
structure — conventions that are *not* mechanically auto-enforced by any single formatter, unlike
Rust where `cargo fmt`/`cargo clippy` already own that role. `web`'s `settings-fragment.json`
allowlists Playwright MCP tools already available system-wide, not a web-specific MCP server it
installs itself.

**Manifest/routing contract** (from `creating-extensions.md` and cross-checked against all three
existing manifests): a new `rust` extension needs `provides.agents`, `provides.skills`,
`provides.context: ["project/rust"]`; `routing.research/implement` -> `skill-rust-research`
/`skill-rust-implementation`; `routing_agents.research/implement` -> `rust-research-agent`
/`rust-implementation-agent`, `routing_agents.plan` -> `planner-agent` (shared); `merge_targets`
for `claudemd` (source `EXTENSION.md`, target `.claude/CLAUDE.md`, `section_id:
"extension_rust"`), `index` (source `index-entries.json`), `opencode_json` (source
`opencode-agents.json`). No `settings` merge target unless an MCP server/tool allowlist is added
later. `keyword_overrides` (documented in `context/guides/extension-development.md` lines
87-109) is optional and unused by any of the three precedent extensions today; it would let
`/task` auto-detect `task_type: rust` from whole-word keywords like `"cargo"`/`"rustc"` in a task
description before falling through to the hardcoded routing table — low-cost, worth considering
in planning but not load-bearing.

### External Resources

- **Toolchain fundamentals** (WebSearch, "best practices AI coding agent Rust toolchain cargo
  clippy rustfmt rust-analyzer agent instructions"): Clippy and rustfmt are described as
  foundational alongside rust-analyzer; the recommended AI-agent loop is "iterating against
  `cargo check` in a loop," running `cargo test`/`cargo clippy`/`cargo fmt` on every change so
  the agent can self-verify before human review, and rust-analyzer's LSP diagnostics are called
  out as a *complement* to, not replacement for, `cargo clippy`/`cargo test`. Error-handling
  convention consensus: `thiserror` for library error types, `anyhow` for application-level error
  propagation. This maps directly onto the Python extension's four-command verification set
  (`pytest`, `mypy`, `ruff check`, `ruff format`) with Rust's own four (`cargo test`, `cargo
  clippy -- -D warnings`, `cargo check`, `cargo fmt --check`).
- **MCP server landscape** (WebSearch, "MCP server rust cargo clippy docs.rs crates.io Claude
  Code 2026" and "rust-analyzer MCP server official rmcp claude code integration 2026"): multiple
  independent, small community projects exist — `crates-mcp` (pato/crates-mcp, crates.io/docs.rs
  search), `docsrs-mcp` (docs.rs API access), `cargo-mcp` (wraps `cargo_clippy` etc.),
  `rust-analyzer-mcp` (zeenix/rust-analyzer-mcp) and a separate `rust-mcp`
  (dexwritescode/rust-mcp), also wrapping rust-analyzer. `rmcp` is the official Rust *SDK* for
  building MCP servers (4.7M+ crates.io downloads as of early 2026) — that download count
  reflects `rmcp`'s use as a library by many unrelated MCP server authors, not adoption of any
  one Rust-tooling MCP server itself. None of these has the single-project, package-manager-blessed
  status `mcp-nixos` has for Nix (a single `uvx mcp-nixos` invocation the nix extension already
  depends on). Given the "lean, nothing not well-motivated" instruction, none is recommended for
  default inclusion; `WebSearch`/`WebFetch` against `docs.rs` and `crates.io` pages is the direct
  substitute, exactly as the Python extension already relies on `WebSearch`/`WebFetch` rather than
  a PyPI-specific MCP server.
- **rustup/cargo baseline**: `cargo`/`rustc` availability checks (mirroring
  `nix-preflight.sh`'s non-fatal `command -v nix` check) are cheap to add if the planning phase
  wants preflight parity with `nix`, but are lower-priority than for Nix, where toolchain
  presence is a much more common failure mode on non-NixOS systems; Rust via `rustup` is close to
  universal on developer machines already running Claude Code. This is a "nice, optional" item,
  not a gap.

### Recommendations

1. **File set** (lean base + nothing extra): `manifest.json`, `EXTENSION.md`, `README.md`,
   `index-entries.json`, `opencode-agents.json`, `agents/rust-research-agent.md`,
   `agents/rust-implementation-agent.md`, `skills/skill-rust-research/SKILL.md`,
   `skills/skill-rust-implementation/SKILL.md`, `context/project/rust/README.md`. Directly
   copy the Python extension's file shapes/stage structure, substituting Rust tools/conventions.
2. **Verification command set** for the implementation agent's "Build/Verification Tools" and
   Execution-Flow Stage 4/5, mirroring `python-implementation-agent.md`'s pytest/mypy/ruff triple:
   - `cargo check` (fast compile-check per edit)
   - `cargo clippy --all-targets --all-features -- -D warnings` (lint gate)
   - `cargo fmt --check` (format gate; `cargo fmt` to auto-fix before the check)
   - `cargo test` (final verification, Stage 5)
3. **Inline "Rust Best Practices" section** (like Python's inline module-structure/testing-pattern
   blocks) covering: crate/workspace layout (`src/lib.rs` vs `src/main.rs`, `[workspace]
   members`), `thiserror` for library errors / `anyhow` for application errors, avoiding
   `unwrap()`/`expect()` outside tests, `#[cfg(test)] mod tests` for unit tests plus `tests/` for
   integration tests. No separate `rules/rust.md` — `cargo fmt`/`cargo clippy` already
   mechanically enforce formatting/idiom, which is precisely why Python also has no rules file
   while Nix and Astro (whose conventions aren't mechanically enforced) do.
4. **No MCP server / no `settings-fragment.json` by default.** Document the existence of
   `crates-mcp`/`docsrs-mcp` as a possible future *optional* addition in `EXTENSION.md`/`README.md`
   prose, not wired into `manifest.json`'s `mcp_servers`, unless the user specifically wants one
   installed.
5. **`context/project/rust/README.md`** should stay generic and short (crate/workspace layout,
   pointer to `cargo doc`/docs.rs for API lookups, pointer to the inline best-practices section in
   the implementation agent) — do not fabricate a specific downstream framework's domain docs the
   way `python`'s ModelChecker-specific files do; there is no analogous concrete consumer to
   document against yet.
6. **`task_type: "rust"`**, `dependencies: ["core"]`, `routing`/`routing_agents` exactly
   mirroring the `python` manifest shape (see Codebase Patterns above for exact keys).
7. Optional, lower-priority items for the planning phase to explicitly accept or decline rather
   than silently add: (a) a `nix-preflight.sh`-style `rust-preflight.sh` checking `cargo`/`rustc`
   presence (cheap, ~30 lines, but lower value than for Nix); (b) a `keyword_overrides` block in
   `manifest.json` for `/task` auto-routing on `"cargo"`/`"rustc"`/`"clippy"` keywords.

## Decisions

- **Base template = `python`, not `nix`.** The task explicitly requests leanness; `nix`'s extra
  machinery (MCP server, hooks, rules file, large context tree) is motivated by conditions
  (canonical MCP server, foreign module-system syntax, weaker auto-formatting consensus,
  toolchain-availability risk) that this research did not find equally true for Rust.
- **No MCP server bundled by default.** The Rust MCP-server ecosystem is fragmented and
  community-maintained with no single converged choice comparable to `mcp-nixos`; bundling one
  would be exactly the kind of "not well-motivated" addition the task warns against. This is
  reversible later as an additive `merge_targets.settings` + `manifest.json.mcp_servers` change.
- **No `rules/rust.md`.** `cargo fmt`/`cargo clippy` already auto-enforce the two things a rules
  file would otherwise hand-document (formatting, idiom warnings); Rust conventions instead go
  inline in the two agent files, matching `python`'s (not `nix`'s or `web`'s) precedent.

## Risks & Mitigations

- **Risk**: Omitting an MCP server could be reversed later as a breaking mismatch if a de facto
  standard Rust MCP server emerges. **Mitigation**: `manifest.json`'s `mcp_servers` and
  `merge_targets.settings` are purely additive fields — adding them in a future task requires no
  restructuring of the extension already proposed here.
- **Risk**: Without a `rules/rust.md`, an agent editing `.rs` files outside the normal
  research/implementation dispatch (e.g., a generic-task-type dispatch touching a `.rs` file)
  gets no auto-applied Rust guidance via path-matched rules. **Mitigation**: this is the same
  tradeoff `python` already accepts; low risk since `cargo fmt`/`cargo clippy` catch the
  consequences mechanically at verification time regardless of which agent made the edit.
- **Risk**: A short, generic `context/project/rust/README.md` may prove too thin once a specific
  downstream Rust project actually uses this extension. **Mitigation**: `context/` is additive;
  domain/patterns/standards subdirectories can be added later exactly as `python`'s were,
  without touching the manifest's other fields.

## Context Extension Recommendations

- **Topic**: Rust extension itself.
- **Gap**: No `agent-system/extensions/rust/` exists yet; this report is the basis for the
  `/plan 222` phase that will create it.
- **Recommendation**: `/plan 222` should produce the file list in Recommendations item 1 above,
  in phases mirroring how `python`'s files divide: (Phase 1) manifest + EXTENSION.md + README.md
  + index-entries.json + opencode-agents.json; (Phase 2) `rust-research-agent.md` +
  `skill-rust-research/SKILL.md`; (Phase 3) `rust-implementation-agent.md` +
  `skill-rust-implementation/SKILL.md`; (Phase 4) `context/project/rust/README.md` + deploy/
  reload verification (`bash .claude/scripts/deploy-headless.sh` or equivalent reload, then
  confirm `rust` appears as a loadable extension).

## Appendix

### Search queries used
- WebSearch: "MCP server rust cargo clippy docs.rs crates.io Claude Code 2026"
- WebSearch: "best practices AI coding agent Rust toolchain cargo clippy rustfmt rust-analyzer agent instructions"
- WebSearch: "rust-analyzer MCP server official rmcp claude code integration 2026"
- WebFetch: https://crates.io/crates/docsrs-mcp (page content insufficient for detail; superseded by WebSearch snippets)

### Codebase files examined
- `agent-system/extensions/python/{manifest.json,EXTENSION.md,README.md,index-entries.json,opencode-agents.json}`
- `agent-system/extensions/python/agents/{python-research-agent.md,python-implementation-agent.md}`
- `agent-system/extensions/python/skills/skill-python-{research,implementation}/SKILL.md`
- `agent-system/extensions/python/context/project/python/README.md`
- `agent-system/extensions/nix/{manifest.json,README.md,settings-fragment.json,index-entries.json,opencode-agents.json}`
- `agent-system/extensions/nix/scripts/{nix-preflight.sh,nix-context.sh}`
- `agent-system/extensions/nix/rules/nix.md`
- `agent-system/extensions/nix/context/project/nix/README.md`
- `agent-system/extensions/web/{manifest.json,settings-fragment.json,rules/web-astro.md}`
- `agent-system/extensions/core/docs/guides/creating-extensions.md`
- `agent-system/extensions/core/context/guides/extension-development.md` (keyword_overrides section)
- `.claude-extensions.json` (confirms `rust` not currently loaded; email extension shown as reference for the loaded-extension record shape)

### References
- [crates-mcp on crates.io](https://crates.io/crates/crates-mcp)
- [docsrs-mcp on crates.io](https://crates.io/crates/docsrs-mcp)
- [pato/crates-mcp on GitHub](https://github.com/pato/crates-mcp)
- [zeenix/rust-analyzer-mcp on GitHub](https://github.com/zeenix/rust-analyzer-mcp)
- [dexwritescode/rust-mcp on GitHub](https://github.com/dexwritescode/rust-mcp)
- [cargo-mcp on crates.io](https://crates.io/crates/cargo-mcp)
