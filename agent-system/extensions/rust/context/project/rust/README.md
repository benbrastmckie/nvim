# Rust Context

Generic context for Rust development tasks: Cargo project layout, edition/MSRV conventions, and
where to look up APIs. Project-specific domain knowledge belongs in the target repository's own
context files, not here.

## Cargo Project Layout

- **Single crate (library)**: `Cargo.toml` at the root, public API in `src/lib.rs`, internal
  modules under `src/`.
- **Single crate (binary)**: `Cargo.toml` at the root, entry point at `src/main.rs`.
- **Workspace (multi-crate)**: a root `Cargo.toml` with `[workspace]` and `members = [...]`;
  each member is its own crate directory with its own `Cargo.toml`.
- **Tests**: unit tests colocated in `#[cfg(test)] mod tests` blocks; integration tests as
  separate files under `tests/`, each compiled as its own crate against the public API.
- **Benchmarks**: under `benches/` (criterion or the built-in unstable `#[bench]` attribute).

## Edition and MSRV

- The `edition` field in `Cargo.toml` (`2021`, `2024`, ...) selects the language edition.
- The `rust-version` field in `Cargo.toml`, when present, declares the crate's Minimum Supported
  Rust Version (MSRV). Check it before using a feature that may postdate the declared MSRV.

## Looking Up APIs

- [docs.rs](https://docs.rs/) - published documentation for any crate on crates.io, including
  the exact version pinned in `Cargo.lock`.
- `cargo doc --open` - build and browse documentation for the local crate and its dependencies
  exactly as resolved in this project.
- [The Rust standard library](https://doc.rust-lang.org/std/) and
  [The Rust Reference](https://doc.rust-lang.org/reference/) for language and stdlib questions.

## Best Practices

See the implementation agent's "Rust Best Practices" section
(`agents/rust-implementation-agent.md`) for the error-handling convention (`thiserror` for
libraries, `anyhow` for applications), testing layout, borrowing guidance, and the `unsafe` code
requirement.
