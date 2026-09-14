# Implementation Summary: Task #205

- **Task**: 205 - Replace the single-global lean-lsp entry with per-project scoped registration written automatically at session start
- **Status**: [COMPLETED]
- **Started**: 2026-09-09T18:39:00Z
- **Completed**: 2026-09-10T00:00:00Z
- **Effort**: ~5.5 hours
- **Dependencies**: 203 (COMPLETED), 204 (COMPLETED)
- **Artifacts**: plans/01_per-project-lean-lsp-registration.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Flipped `lean-lsp` MCP registration from a single global `~/.claude.json` entry to per-project
entries under `.projects["<abs path>"].mcpServers`, written automatically at session start by a
new `SessionStart` hook. Every artifact that previously enforced the single-global model
(`verify-lean-mcp.sh`'s Check 9, `setup-lean-mcp.sh`'s write target, `mcp-server-ownership.md`'s
recorded trade-off, `lean-mcp-preflight-check.sh`'s remedy text, and the fixture suite) was
inverted in the same pass. All 10 planned phases completed; acceptance was demonstrated, not
merely asserted, with two independent concurrent-session pairs.

## What Changed

- `agent-system/extensions/lean/scripts/setup-lean-mcp.sh` — moved from `core/scripts/`; added
  `--scope project|global|both` (default `project`), `--retire-global`, `--quiet`, and
  per-project read/compare/write against `.projects[$path].mcpServers` with whole-entry
  reconciliation preserved
- `agent-system/extensions/lean/scripts/verify-lean-mcp.sh` — moved from `core/scripts/`; Checks
  2-8 retargeted at the project-scoped entry; Check 9 inverted (a surviving global entry is now
  the drift, remedy names `--retire-global`); exit-code contract (0/1/2) preserved
- `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh` — exit-1 branch message
  changed to "lean-lsp is not registered for this project"; header comment updated
- `agent-system/extensions/lean/hooks/lean-lsp-register-project.sh` — new `SessionStart` hook:
  detects the enclosing Lake project, invokes the writer at project scope in quiet mode, emits an
  `additionalContext` restart notice on a write (same-session visibility is not guaranteed —
  measured in Phase 1), always exits 0
- `agent-system/extensions/lean/scripts/install-lean-lsp-session-hook.sh` — new idempotent
  installer: copies the hook and a stable writer copy to `$HOME/.claude/{hooks,scripts}/`, merges
  the `SessionStart` registration into both `~/.dotfiles/config/claude/settings.json` and the live
  `~/.claude/settings.json`; `--dry-run`/`--remove` supported
- `agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` — fixtures A/B/D
  rewritten for the per-project model; added fixtures F (concurrent two-project), G (fresh
  worktree independence), H (inverted-Check-9 FAIL direction), I (unregistered project); two
  mutation checks (wrapper-level, extended; new verifier-level Check-9 deletion)
- `agent-system/extensions/lean/scripts/tests/test-lean-mcp-registration.sh` — new writer-level
  suite: idempotency, whole-entry replacement, `--dry-run`, `--retire-global`, two-project
  sequential survival, plus a mutation check
- `agent-system/extensions/core/manifest.json` / `agent-system/extensions/lean/manifest.json` —
  moved the two scripts' `provides.scripts` declarations from core to lean; added the new hook,
  installer, and test file
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` — Registration section
  restructured to a three-way scope choice (project / user / local); the single-global trade-off
  record replaced with the concurrency evidence that overturned it; session-start snapshot trap
  cross-referenced with the hook-timing measurement; Decision procedure and Worked Pair updated;
  the `.claude/`-command-path invariant itself left untouched (git-diff-verified)
- `agent-system/extensions/core/docs/architecture/extension-system.md` — new "How an extension
  contributes a native harness hook" subsection (per-repo vs. user-level, citing the email
  extension and this task's hook); two stale "only user-scope" claims corrected
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — 5 entries updated
  or added (setup/verify/preflight scripts, hook, installer)
- `agent-system/extensions/lean/README.md`, `.../tools/mcp-tools-guide.md` — registration
  narrative rewritten for the automatic per-project model; a second, independent stale claim
  about subagent reachability corrected in the latter
- `~/.claude.json` (machine-local): every active Lean project (`BimodalLogic`, `cslib`,
  `cslib-pr648`, `Logos/Theory`) registered with its own `LEAN_PROJECT_PATH`; the top-level global
  entry retired
- `~/.claude/hooks/lean-lsp-register-project.sh`, `~/.claude/scripts/setup-lean-mcp.sh`
  (machine-local, installed copies); `~/.claude/settings.json` and
  `~/.dotfiles/config/claude/settings.json` (machine-local, `SessionStart` hook registered;
  the `~/.dotfiles` edit is deliberately left uncommitted in that repository)

## Decisions

- **D1-D5 (recorded at plan time, executed as planned)**: local scope as the registration
  surface; the global entry retired (not kept as a fallback); the two scripts relocated to the
  lean extension; the hook registered at user level with dual (dotfiles + live) writes; the
  hook's canonical source lives in this repo's source store, installed to a stable
  `~/.claude/` path never inside any repository's own deploy tree
- **Writer/hook split**: rather than duplicate the writer's logic inline in the hook, the
  installer additionally copies `setup-lean-mcp.sh` itself to `$HOME/.claude/scripts/`, and the
  hook resolves the writer from that stable path — required because the acceptance scenario (a
  fresh worktree with no repository `.claude/` deploy at all) rules out any repo-relative
  resolution
- **Logos/Theory added beyond the plan's 3-project hypothesis**: the Lake-marker scan found a 4th
  genuinely active Lean project one directory deeper than the plan's flat `~/Projects/*/` scan
  anticipated; registered per the plan's own "the scan's output governs" instruction

## Plan Deviations

- **Phase 2 verification** ("redeploy and confirm `.claude/scripts/` still carries both scripts")
  — altered: this source-store repo does not itself have the `lean` extension loaded, so its own
  `deploy-headless.sh` cannot exercise this path (a pre-existing fact, not a defect). Verified
  instead against the two real Lean-project consumer repos with `lean` active (`BimodalLogic`,
  `cslib`): both redeploys landed clean and the deployed scripts matched source byte-for-byte.
  Also fixed a real side effect of the move — two now-orphaned files under this repo's own
  `.claude/scripts/` (leftover from core's prior ownership) — deleted after confirming they broke
  `check-extension-docs.sh`'s drift check and `verify-deploy.sh`'s orphan-detection gate.
- **Phase 6 verification** ("run the fixture suite and confirm all branches") — deferred to
  Phase 7: fixture B (the "correctly registered" case) legitimately failed once Phase 5 inverted
  the model, because it only wrote a global entry. Fixtures A, C, D, E and both mutation checks
  passed, confirming Phase 6's own realignment was correct; fixture B's rewrite was Phase 7's
  chartered work and was completed there.
- **Phase 9 scope** — altered: registered a 4th active project (`Logos/Theory`) beyond the plan's
  3-project hypothesis; see Decisions above.

## Verification

- Build: N/A (shell scripts + markdown)
- Tests: `test-lean-mcp-preflight-check.sh` 17/17 PASS; `test-lean-mcp-registration.sh` 7/7 PASS
- Files verified: Yes — every moved/created script confirmed executable, byte-identical between
  source and deployed copies (BimodalLogic, cslib, Logos/Theory), and functionally verified
  against fixture HOMEs never touching the real `~/.claude.json`
- Doc-lint (`check-extension-docs.sh`): PASS across all 20 extensions
- Task-reference lint (`check-task-references.sh`): PASS, 0 unexempted occurrences
- Deploy verification (`deploy-headless.sh`, fast gates): PASS
- Acceptance demonstration: two independent concurrent-session pairs (BimodalLogic + cslib-pr648;
  BimodalLogic + cslib directly, reproducing the originally reported defect), each session
  resolving its own project's identifier and rejecting the other project's — see
  `progress/phase-10-progress.json`'s `command_log` for full verbatim commands and outputs

## Impacts

- Every Lean project on this machine now indexes correctly regardless of how many others are
  open concurrently, closing the silent-wrong-answer defect that motivated this task
- A freshly created worktree (no repository `.claude/` deploy at all) self-registers with zero
  manual steps at first session start
- `setup-lean-mcp.sh`/`verify-lean-mcp.sh` moved extensions (core → lean); any external reference
  to the old `core/scripts/` path is now stale (none found in this repo's source store; a
  deployed consumer's `.claude/scripts/` path is unaffected by the move, since every extension's
  `scripts/` flattens into one directory at deploy time)
- `~/.dotfiles/config/claude/settings.json` now carries the `lean-lsp` `SessionStart` hook entry,
  uncommitted in that repository per this task's Non-Goals — the user should review and commit it
  there when ready

## Follow-ups

- The `~/.dotfiles` edit (`hooks.SessionStart` entry) is uncommitted in that repository by design
  — commit it there when convenient
- `mcp-tools-guide.md`'s own "Blocked Tools" table flags `lean_file_outline` (used throughout this
  task's empirical probes and the Phase 10 acceptance demonstration) as having a known upstream
  bug (`lean-lsp-mcp` #115: the `declarations` field always comes back empty). This did not
  affect any conclusion in this task — every probe relied on the imports-list/file-not-found
  signal, a structurally separate code path from the buggy field — but a future re-verification
  should prefer `lean_hover_info` per the guide's own guidance
- `lean/settings-fragment.json` still carries its own `mcp__lean-lsp__*` wildcard grant alongside
  the one already present in the user's real `~/.claude/settings.json`; both are independently
  correct and neither is wrong, but the redundancy was not investigated further as out of scope
  for this task
- cslib.bak and ProofChecker.bak were excluded from Phase 9's registration as stale backups, per
  the plan; if either becomes active again it will need its own `setup-lean-mcp.sh --scope
  project` run (or will self-register on its next session start once redeployed with the lean
  extension active)

## References

- `specs/205_per_project_lean_lsp_registration/plans/01_per-project-lean-lsp-registration.md`
- `specs/205_per_project_lean_lsp_registration/reports/01_per-project-lean-lsp-registration.md`
- `specs/205_per_project_lean_lsp_registration/progress/phase-{1..10}-progress.json`
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
