## Rust Extension

This project includes Rust development support via the rust extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `rust` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (cargo check/clippy/fmt/test) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-rust-research | rust-research-agent | Rust/crate research |
| skill-rust-implementation | rust-implementation-agent | Rust implementation |

### Commands

No dedicated commands. Use core `/research`, `/plan`, `/implement` with `task_type: "rust"`.

### Verification Loop

- Compile check: `cargo check`
- Lint gate: `cargo clippy --all-targets --all-features -- -D warnings`
- Format gate: `cargo fmt` then `cargo fmt --check`
- Tests: `cargo test`

### Context

- `context/project/rust/README.md` - Cargo layout, edition/MSRV, API lookup, best-practices pointer
