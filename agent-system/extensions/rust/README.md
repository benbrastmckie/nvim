# Rust Extension

Rust development support with cargo-driven compile checking, linting (clippy), formatting
(rustfmt), and test integration.

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `rust` | rust-research-agent | Rust/crate research |
| `rust` | rust-implementation-agent | Rust implementation |

## Installation

Loaded via the extension picker. Once loaded, `rust` becomes a recognized task type.

## Commands

No dedicated commands. Use core `/research`, `/plan`, `/implement` with `task_type: "rust"`.

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-rust-research | rust-research-agent | Rust/crate research |
| skill-rust-implementation | rust-implementation-agent | Rust implementation |

## File Inventory

```
rust/
  manifest.json                                  # Name, version, provides, routing, merge_targets
  EXTENSION.md                                   # CLAUDE.md source content
  README.md                                      # This file
  index-entries.json                             # Context index entry for project/rust/README.md
  opencode-agents.json                           # OpenCode agent definitions
  agents/rust-research-agent.md                  # Research agent
  agents/rust-implementation-agent.md            # Implementation agent (cargo verification loop)
  skills/skill-rust-research/SKILL.md            # Thin wrapper skill
  skills/skill-rust-implementation/SKILL.md      # Thin wrapper skill
  context/project/rust/README.md                 # Cargo layout, MSRV, API lookup pointers
```

## Language Routing

| Task Type | Research Tools | Implementation Tools |
|-----------|----------------|---------------------|
| `rust` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (cargo check/clippy/fmt/test) |

## Verification Loop

```bash
cargo check                                              # Fast compile check, per-edit
cargo clippy --all-targets --all-features -- -D warnings # Lint gate
cargo fmt                                                 # Format
cargo fmt --check                                         # Format gate
cargo test                                                # Final verification
```

The implementation agent runs this loop after each phase of edits and blocks on failures.

## Deliberately Omitted

- **No MCP server**: the Rust MCP ecosystem is fragmented (no `mcp-nixos`-equivalent, broadly
  adopted server). `crates-mcp`/`docsrs-mcp` are candidate optional additions if a mature,
  widely-used server emerges, but are not wired in today.
- **No `rules/rust.md`**: `cargo fmt` and `cargo clippy -D warnings` already mechanically enforce
  the conventions a rules file would otherwise document in prose.
- **No hooks / toolchain preflight script**: rustup-installed cargo is near-universal where Rust
  work happens, and a missing `cargo` surfaces immediately and loudly on the first verification
  command.
- **No `settings-fragment.json`**: nothing extension-specific to configure at the settings layer.

## References

- [The Rust Programming Language](https://doc.rust-lang.org/book/)
- [Rust standard library](https://doc.rust-lang.org/std/)
- [The Rust Reference](https://doc.rust-lang.org/reference/)
- [docs.rs](https://docs.rs/)
- [Clippy lints](https://rust-lang.github.io/rust-clippy/master/)
