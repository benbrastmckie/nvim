# Implementation Summary: Stop writing the Sapience token into the per-project MCP entry

- **Task**: 682 - Stop writing the Sapience token into the per-project MCP entry in ~/.claude.json
- **Status**: [COMPLETED]
- **Started**: 2026-11-21
- **Completed**: 2026-11-22
- **Effort**: 4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_remove-token-from-mcp-entry.md, records/01_mcp-token-resolution-measurement.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`setup-sapience-mcp.sh` wrote the Sapience bearer token in plaintext into every registered
project's `~/.claude.json` entry (`env.SAPIENCE_TOKEN`). `~/.sapience/mcp.py` already resolves
the same token from `~/.sapience/config.json` (mode 0600) when the variable is unset, via one
module-level statement shared by every invocation shape the entry reaches. This task measured
that fallback across all four shapes, changed the writer to omit the token entirely and the
verifier to refuse a token-bearing entry, added a regression test with a negative control,
documented the token's durable homes, and migrated the six live project entries on this machine.

## What Changed

- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` — `generate_sapience_config()` no longer embeds `env.SAPIENCE_TOKEN`; the entry carries `SAPIENCE_HOST` only.
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` — check (b) now fails, naming the remedy, when an entry carries a token.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` — added Cases 54/55a/55b: a sentinel token never leaks into a written entry, a hand-built token-bearing fixture fails the verifier with a named remedy, and the writer's own comparison replaces it with the token-free canonical shape.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` — new subsection documenting the token's durable homes (`~/.sapience/config.json`, its 0600 backups, `~/.config/sf1-hub-ben/{env,sapience-token}`, `/run/secrets/sapience_token`, the sops-encrypted `~/.dotfiles/secrets/secrets.yaml`) and the never-copy-into-`~/.claude.json` boundary.
- `agent-system/extensions/sapience/index-entries.json` — `line_count`/`keywords` reconciled for the edited doc.
- `specs/682_sapience_mcp_entry_carries_no_token/records/01_mcp-token-resolution-measurement.md` — Phase 1 measurement record (all five probes resolve the token from `config.json` with the variable unset).
- `specs/682_sapience_mcp_entry_carries_no_token/plans/01_remove-token-from-mcp-entry.md` — phase/checklist markers closed out.
- Outside the repository: all six registered `~/.claude.json` project entries (`.dotfiles`, this repo, `BimodalLogic`, `sf1-engine`, `sapience-app`, `sapience-pitch`) migrated to the token-free shape; `$HOME/.claude/scripts/setup-sapience-mcp.sh` and `$HOME/.claude/hooks/sapience-mcp-register-project.sh` reinstalled from the edited source store.

## Decisions

- Kept the token-removal unconditional (no per-shape exception): Phase 1 confirmed all four
  invocation shapes share the same module-level resolution statement, so the Phase 1
  contingency ("narrow to the shapes that need it") never triggered.
- Discharged Phase 5's "verifier fails on a regression" criterion against Phase 3's existing
  fixture-based Cases 54/55a/55b rather than hand-rolling a second throwaway fixture in this
  phase — same assertion, same sentinel-token discipline, already covered by the suite that
  this phase re-ran in full (58/58 pass).

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (shell scripts, markdown, JSON)
- Tests: `test-sapience-mcp-registration.sh` 58/58 passed, including Cases 54/55a/55b.
- `verify-sapience-mcp.sh` against this repository: all checks PASS, including (b) against the real, now token-free entry.
- Post-migration authentication re-confirmed with `SAPIENCE_TOKEN` absent: `--statusline` probe returns a live authenticated reply; stdio `initialize` handshake returns a well-formed `result`.
- By-value assertion: zero `env.SAPIENCE_TOKEN` keys and zero strings under `.projects` in `~/.claude.json` equal the configured token.
- Scoped touched-path check (`verify-touched.sh`, Batch Gate Deferral): 98/98 passed; complete gate set deferred to the orchestration close.
- `deploy-headless.sh` redeploy: landed clean, 41 checks, 0 failures.
- Files verified: Yes.

## Impacts

- The raw Sapience bearer token is no longer copied into `~/.claude.json`, closing the
  plaintext-inspection (`jq .projects[...]`, `claude mcp get`) and transcript-capture exposure
  path the task description named.
- A **new** exposure surface was found and flagged during this phase's own live migration (see
  Follow-ups): `setup-sapience-mcp.sh`'s non-quiet divergence diagnostic prints a live entry's
  `env.SAPIENCE_TOKEN` value in cleartext, which happened 6 times in this dispatch's own tool
  output while migrating the (now-historical) token-bearing entries.

## Follow-ups

- **Security finding, flagged for the user's decision (not fixed in this task; out of its
  declared file list and Phase 2 was already closed):** migrating the live entries in this
  phase surfaced that `setup-sapience-mcp.sh`'s own "diverges from the sanctioned shape"
  diagnostic prints the full `Current entry` JSON — including `env.SAPIENCE_TOKEN` in cleartext
  — to stdout whenever a non-`--quiet` run encounters a divergent entry. Because all six live
  entries still carried the token at the start of this phase, running the writer over them
  (needed to perform the migration) printed the live token value into this dispatch's own Bash
  tool-output stream six times — which is part of this agent's session transcript, i.e. exactly
  the transcript-capture exposure vector this task's own premise names as a reason to stop
  writing the token into `~/.claude.json` in the first place. Recommend: (a) the user decide
  whether to rotate the Sapience token now, given this transcript exposure; (b) a fast-follow
  task to redact `env.SAPIENCE_TOKEN`'s value in that diagnostic line (print a fixed placeholder
  or a short fingerprint instead of the raw value) so a future migration of a still-token-bearing
  entry cannot repeat this. Recorded via `issue-record.sh` (kind: issue, severity: blocking)
  during this phase without re-printing the token.
- Reconciling the divergence between the sops-provisioned secret and the currently-active
  `config.json` token (found in Phase 4, `~/.dotfiles`-owned) remains open and outside this
  task's scope.

## References

- Plan: `specs/682_sapience_mcp_entry_carries_no_token/plans/01_remove-token-from-mcp-entry.md`
- Report: `specs/682_sapience_mcp_entry_carries_no_token/reports/01_remove-token-from-mcp-entry.md`
- Phase 1 record: `specs/682_sapience_mcp_entry_carries_no_token/records/01_mcp-token-resolution-measurement.md`
- Edited doc: `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
