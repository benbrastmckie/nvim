# Research Report: Task #204

- **Task**: 204 - Wire verify-lean-mcp.sh into a moment where lean-lsp registration drift is actually caught
- **Started**: 2026-09-09T17:40:00Z
- **Completed**: 2026-09-09T17:55:00Z
- **Effort**: ~1 hour research
- **Dependencies**: Task 203 (COMPLETED — reconciled the sanctioned registration shape)
- **Sources/Inputs**: Codebase (agent-system/extensions/{core,lean,nix}/**), live `~/.claude.json`,
  live timing of `verify-lean-mcp.sh`, specs/TODO.md (tasks 200, 203, 204)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md, shell-strict-mode.md, source-store-deploy-boundary.md

## Executive Summary

- `verify-lean-mcp.sh`'s expectations already changed under this task's feet, exactly as the
  dispatch warned: after task 203, command/args mismatches are hard **FAIL**s (exit 1), a new
  Check 3 rejects any `command` resolving inside a `.claude/` deploy tree, and a new Check 9
  rejects a project-scoped entry that shadows the global one. Live proof: running it today from
  `~/Projects/BimodalLogic` exits 2 ("Project path mismatch") because the single global entry
  currently points at `~/Projects/cslib` (task 203 left it there deliberately, per its summary's
  "Current state of LEAN_PROJECT_PATH" section) — not the stale-wrapper ENOENT text quoted in the
  original task description, which is now obsolete.
- **Critical finding that determines the wiring point**: the "lean-extension preflight" candidate
  the dispatch calls natural is not one moment but two different, non-equivalent mechanisms —
  (1) the manifest `hooks.preflight` field (`skill_run_extension_hook`, fired only from inside
  `skill_preflight_update` in `skill-base.sh`), used live today by the `nix` extension, and
  (2) each skill's own Stage 2 preflight block. **None of the four lean skills that actually
  dispatch to a lean-lsp-using agent call `skill_preflight_update`.** `skill-lean-research`
  writes state.json directly via `state-write.sh`; `skill-lean-research-hard`,
  `skill-lean-implementation`, and `skill-lean-implementation-hard` call
  `update-task-status.sh preflight` directly. A manifest `hooks.preflight` declaration for lean
  would therefore be dead code — silently never invoked — unless this task also migrates all four
  skills onto the shared `skill-preflight-flow.md` pattern, which is a materially larger,
  separately-risky refactor (it also touches postflight-marker creation, monotonic-max clamping,
  and each skill's already-customized "skill-internal postflight pattern") that the dispatch does
  not ask for and that is not necessary to satisfy this task's acceptance bar.
- **Recommendation**: wire the check as one direct inline call added to each of the four
  lean-lsp-using skills' existing Stage 2 block, invoking a new thin, lean-owned wrapper script
  (`agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh`) that calls the already
  hardened `verify-lean-mcp.sh --quiet`, silently no-ops in a non-Lean directory, and otherwise
  emits one actionable line naming `setup-lean-mcp.sh` — never a hard failure. `skill-lake-repair`
  and `skill-lean-version` are direct-execution skills that never touch lean-lsp and are correctly
  excluded.
- Measured cost: `verify-lean-mcp.sh --quiet` runs in ~30ms wall clock against the live 183KB
  `~/.claude.json` (5-run average, `~/Projects/BimodalLogic`); a bare single `jq` read of the same
  key is ~7ms. This is a jq-only cost with no repository walk, no network call, and no server
  spawn — well inside "cheap" for a hot path fired once per skill invocation.
- Decision: **WARN, never BLOCK.** A degraded-but-usable toolchain (lean4 work without lean-lsp,
  falling back to compiled probes) is a real, accepted operating mode per task 203's own summary
  ("companion drift-detection task... can wire into an automated moment" — framed as detection,
  not gating). Hard-blocking a dispatch on an MCP registration mismatch would itself become the
  kind of failure task 200 warns against (an unbounded/unnecessary gate). The signal must simply
  stop being silent: it must appear in the same tool-output stream the agent (and the orchestrator
  transcript) already sees at Stage 2, before any lean-lsp tool call is attempted.

## Context & Scope

Researched: where to invoke the already-correct `core/scripts/verify-lean-mcp.sh` so that a lean4
task in a repository with a misregistered lean-lsp server learns this before it silently falls
back to compiled probes, without adding cost or noise to the hot dispatch path. Constrained by:
task 203 (dependency, COMPLETED) having already changed the verifier's exact check shapes and
exit-code semantics; task 200 (NOT STARTED, no report/plan yet — nothing to reuse from it); the
`source-store-deploy-boundary.md` and `no-task-references-in-deliverables.md` rules (edit target
is `agent-system/extensions/{lean,core}/**`, never `.claude/**`, and no task numbers in any
deliverable outside `specs/**`).

Out of scope (per dispatch MUST NOT / SCOPE): re-litigating task 203's registration decisions;
merging with task 200's deploy-staleness detection; migrating the broader lean-skill family onto
the shared `skill_preflight_update`/`skill_create_postflight_marker` pattern (a real, separately
valuable cleanup, called out as a Context Extension Recommendation below, not undertaken here).

## Findings

### Codebase Patterns

**`verify-lean-mcp.sh`, current (post-203) shape** — `agent-system/extensions/core/scripts/verify-lean-mcp.sh`:
- Auto-detects the Lean project path from `lakefile.lean`/`lakefile.toml` (CWD or git root); if
  neither is found it prints `Error: Could not detect Lean project path.` and **exits 1**. This is
  the case WORK item (d) requires preflight to swallow silently — the script itself does not
  distinguish "not a Lean project" from "a Lean project with no command configured" in its exit
  code, so the wrapper (not the verifier) must perform this pre-check.
- Check 3 (new in 203): the `command` must never resolve inside any repo's `.claude/` tree — hard
  fail, exit 1, names `setup-lean-mcp.sh` as remedy.
- Checks 4–5 (promoted to hard fail in 203): wrong `command`/`args` — exit 1, names the remedy.
- Check 6–7: `LEAN_PROJECT_PATH` unset (exit 1) or mismatched vs. the detected/`--project` path
  (exit 2) — both name the remedy (Check 7's message additionally supplies the exact
  `setup-lean-mcp.sh --project '<path>'` invocation).
- Check 8: missing lakefile at the *configured* path — **warn only**, does not fail.
- Check 9 (new in 203): a project-scoped `.projects[<path>].mcpServers."lean-lsp"` entry that
  shadows the global one — hard fail, names the remedy.
- `--quiet` mode suppresses all of the above text and prints only bare `PASS`/`FAIL`; exit codes
  are unchanged (0 / 1 / 2). This is the mode a non-interactive preflight hook should use, since
  the hook must synthesize its OWN one-line actionable message rather than dumping the verifier's
  multi-line, human-oriented `log()` output into every green dispatch.
- **Live-measured cost**: 5 runs of `verify-lean-mcp.sh --quiet` from `~/Projects/BimodalLogic`
  averaged 30ms wall clock (183KB live `~/.claude.json`); a single bare `jq -e` read of the same
  key alone costs ~7ms. The script makes ~6 sequential `jq` invocations plus a `git rev-parse`;
  all of the added cost is process-spawn overhead on tiny JSON, not I/O or computation. No
  network, no repo walk, no server spawn — matches WORK item (c)'s bar directly.

**`setup-lean-mcp.sh`** (the named remedy) — unchanged by this task; confirmed it performs a
whole-entry compare/overwrite (not per-field), so re-running it after any of the failure classes
above fully repairs the entry in one step.

**Lean manifest hook precedent that does NOT apply cleanly** —
`agent-system/extensions/lean/manifest.json` currently declares `"hooks": []` under
`provides.hooks` (a *file-copy-target* list, unrelated to lifecycle hooks) and has **no top-level
`hooks` object** at all (the lifecycle-hook field CLAUDE.md describes, distinct from
`provides.hooks`). The `nix` extension is the one live example of that top-level field:
```json
"hooks": {
  "preflight": "scripts/nix-preflight.sh",
  "context_injection": "scripts/nix-context.sh"
}
```
`skill_run_extension_hook` in `agent-system/extensions/core/scripts/skill-base.sh` resolves and
invokes this **only from inside `skill_preflight_update`** (`skill-base.sh:334-336`), itself
called only by `skill_preflight_update`'s callers. It runs the hook script unconditionally after
the status write, captures nothing but prints "Running extension hook..." plus a non-fatal
WARNING line if the hook exits non-zero — i.e. this call site is already fully non-blocking by
design (`skill-base.sh:155-157`), matching the WARN decision this task needs.

**The gap that rules out relying on that mechanism today**: cross-checked every lean skill file
for how Stage 2 actually updates status:
| Skill | Stage 2 mechanism | Routes through `skill_preflight_update`? |
|---|---|---|
| `skill-lean-research` | raw `bash .claude/scripts/state-write.sh ...` | No |
| `skill-lean-research-hard` | `bash .claude/scripts/update-task-status.sh preflight ...` | No |
| `skill-lean-implementation` | `bash .claude/scripts/update-task-status.sh preflight ...` | No |
| `skill-lean-implementation-hard` | `bash .claude/scripts/update-task-status.sh preflight ...` | No |
| `skill-lake-repair` | none (direct-execution, no lifecycle preflight at all) | N/A |
| `skill-lean-version` | none (direct-execution, no lifecycle preflight at all) | N/A |

None of the four skills that dispatch to `lean-research-agent`/`lean-implementation-agent` (the
only agents that use lean-lsp MCP tools) source `skill-base.sh` or call `skill_preflight_update`.
Contrast with `nix`: `skill-nix-research`/`skill-nix-implementation` explicitly delegate Stage 2+3
to the shared `@.claude/context/patterns/skill-preflight-flow.md` block, which sources
`skill-base.sh` and calls `skill_preflight_update` — this is why nix's `hooks.preflight` is live
and lean's would not be. `context/patterns/skill-preflight-flow.md`'s own header documents this
exact class of drift ("SIX mutually incompatible marker shapes across ~40 writers, purely from
copy-and-drift") as the reason it exists — the lean skill family is simply outside its adoption so
far.

**`skill-lake-repair`/`skill-lean-version` correctly excluded**: both are direct-execution skills
(no subagent dispatch at all) that operate on `lake build` output and toolchain version files
respectively; neither exercises lean-lsp MCP tools, confirmed by absence of any "preflight" or
"lean-lsp" reference in either `SKILL.md`.

**Task 200 status**: `specs/200_consumer_deploy_propagation_gap/{reports,plans,summaries}/` are
all empty — task 200 is `[NOT STARTED]`, no preflight mechanism exists yet to reuse. Its own
description explicitly floats "skill preflight in `core/scripts/skill-base.sh`, or dispatch time"
as its leading candidate (option a) for an unrelated defect class (deployed-tree staleness); there
is nothing concrete there yet to borrow, only the same architectural instinct this task
independently arrives at.

**`utility-scripts-inventory.md`** still describes `verify-lean-mcp.sh` as "Invoked manually by an
operator; no automated caller by design" (`agent-system/extensions/core/docs/reference/utility-scripts-inventory.md:21`)
— this line needs updating once an automated caller exists, matching task 203's summary's own
"left for that companion task to revise if it adds a caller" note.

### External Resources

Not applicable — this is a pure in-repo shell/config wiring task with no external library or API
surface.

### Recommendations

1. **New wrapper script**: `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh`.
   - Positional-arg-free (or accepts the same 5 lifecycle args other hook scripts use, for
     consistency, even though it will be called directly rather than via `skill_run_extension_hook`).
   - Pre-check for Lean-project shape itself (mirrors `verify-lean-mcp.sh`'s own detection: CWD or
     git-root `lakefile.lean`/`lakefile.toml`); if absent, `exit 0` immediately with no output —
     this is WORK item (d), satisfied without touching `verify-lean-mcp.sh`'s own operator-facing
     "Error: Could not detect..." behavior (a real operator running the script by hand outside a
     Lean project should still see that loud error; the preflight caller should not).
   - Otherwise call `verify-lean-mcp.sh --quiet`; on non-zero exit, print ONE actionable line
     (not the verifier's full log) naming `setup-lean-mcp.sh` as the remedy, distinguishing the
     exit-2 ("project path points elsewhere") case from exit-1 ("misconfigured") in the message
     text since the remedy invocation differs (`setup-lean-mcp.sh` bare vs. rerun from the correct
     project directory).
   - Always `exit 0` — matches `nix-preflight.sh`'s own contract and keeps this fully non-blocking
     regardless of caller.
   - `set -euo pipefail` (Class A per `shell-strict-mode.md` — no counter idiom, no sourcing).
2. **Call site**: add one line invoking this script directly inside Stage 2 of
   `skill-lean-research`, `skill-lean-research-hard`, `skill-lean-implementation`, and
   `skill-lean-implementation-hard`'s `SKILL.md` files, immediately after each skill's existing
   status-update call. Do **not** declare a manifest `hooks.preflight` entry for lean at this
   time — it would be simultaneously redundant (once the direct calls exist) and misleading (it
   would imply the mechanism nix uses is active for lean, when today's actual call graph does not
   reach it). Record this explicitly as a follow-up once/if the lean skill family is migrated onto
   `skill-preflight-flow.md`.
3. **Rejected alternatives** (evaluated per WORK item (a)):
   - *Manifest `hooks.preflight`, as-is* — dead code given the current call graph (see Findings);
     rejected as the sole mechanism without a separate, larger skill-migration task.
   - *Dispatch-time invocation (`orchestrate-build-dispatch.sh`)* — only reached by `/orchestrate`
     invocations; `/research N`, `/plan N`, `/implement N` invoked directly (a documented, live
     command surface per this repo's CLAUDE.md) would never see the check. Also would need its
     own `task_type == lean4` gate duplicating the per-skill scoping. Rejected for coverage gaps.
   - *Session start* — `SessionStart` hooks (`agent-system/extensions/core/root-files/settings.json`)
     fire once per Claude Code session, for every repository and every task type, independent of
     whether lean4 work is about to happen; a long session that starts elsewhere and later begins
     lean4 work in a different directory would never get a fresh check; and putting lean-specific
     logic in core's global `settings.json` array crosses the extension-ownership boundary that
     `mcp-server-ownership.md` and the manifest-merge model otherwise maintain. Rejected as the
     wrong moment and the wrong owner.
4. **WARN vs BLOCK**: WARN only (see Executive Summary). The wrapper always exits 0; the calling
   skill's Stage 2 never treats its output as failure.
5. **Documentation follow-through**: update `utility-scripts-inventory.md`'s
   `verify-lean-mcp.sh` line to name the new automated caller (no longer "no automated caller by
   design").

## Decisions

- Wire via direct per-skill Stage 2 calls in the four lean-lsp-using skills, not via manifest
  `hooks.preflight` — justified by the live call-graph gap documented above, not assumed.
- WARN, never BLOCK, with the emitted message always naming `setup-lean-mcp.sh`.
- The wrapper script duplicates a two-line Lean-project detection check ahead of calling
  `verify-lean-mcp.sh --quiet`, rather than modifying `verify-lean-mcp.sh`'s own exit-1
  "not a Lean project" behavior — preserves the operator-facing script's existing loud-error
  contract for manual invocation while giving the automated caller a silent skip.
- `skill-lake-repair` and `skill-lean-version` are out of scope for the call site (neither uses
  lean-lsp).

## Risks & Mitigations

- **Risk**: adding a call to four `SKILL.md` files touches live lifecycle documents; a mis-placed
  or malformed bash block could break preflight entirely for lean4 tasks. **Mitigation**: the
  call is a single, isolated `|| true`-safe invocation appended after the existing, unmodified
  status-update line — no reordering of existing Stage 2 logic.
- **Risk**: `verify-lean-mcp.sh --quiet`'s exit-2 ("project path mismatch") is not really a
  "misregistration" under the single-global-entry model (task 203's accepted trade-off) — it can
  legitimately occur whenever the operator is working across two Lean projects. **Mitigation**:
  message text for exit 2 should be worded as "lean-lsp currently indexes a different project"
  rather than "misconfigured," still naming `setup-lean-mcp.sh` as the one-line fix, so it reads
  as informational rather than alarming on a case that is a known, accepted operating mode.
- **Risk**: shellcheck must run clean per acceptance criteria; this machine has shellcheck only
  via a Nix store path/alias (`shellcheck-0.11.0`), not on a bare `$PATH` `command -v` lookup in
  a non-interactive shell. **Mitigation**: the implementation phase should invoke it via the same
  mechanism `verify-deploy.sh`'s gates use, not assume a bare `shellcheck` binary is on `PATH`.

## Context Extension Recommendations

- **Topic**: lean skill family's non-adoption of `skill-preflight-flow.md`.
- **Gap**: none of the six lean skills route Stage 2/3 through `skill_preflight_update`/
  `skill_create_postflight_marker`, unlike `nix`, `web`, `cslib`, and core's own `skill-spawn`.
  This means lean's manifest `hooks.preflight`/`hooks.postflight` fields (if ever declared) would
  be silently inert, and lean's postflight markers may already diverge from the documented Shape A
  schema (`skill-preflight-flow.md`'s stated motivation for existing at all).
- **Recommendation**: a follow-up task (separate from this one, and separate from task 200) to
  migrate the four lifecycle lean skills onto `skill-preflight-flow.md`'s Stage 2+3 block, at
  which point this task's inline per-skill calls should be replaced by a single lean manifest
  `hooks.preflight` declaration pointing at the same `lean-mcp-preflight-check.sh` (with its
  detection logic unchanged) — collapsing four call sites into one, matching the pattern nix
  already demonstrates working end-to-end.

## Appendix

- Files read: `agent-system/extensions/core/scripts/verify-lean-mcp.sh`,
  `agent-system/extensions/core/scripts/setup-lean-mcp.sh`,
  `agent-system/extensions/core/scripts/skill-base.sh` (hooks section, lines ~80-190),
  `agent-system/extensions/core/context/patterns/skill-preflight-flow.md`,
  `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`,
  `agent-system/extensions/lean/manifest.json`,
  `agent-system/extensions/lean/skills/{skill-lean-research,skill-lean-research-hard,skill-lean-implementation,skill-lean-implementation-hard,skill-lake-repair,skill-lean-version}/SKILL.md`,
  `agent-system/extensions/nix/manifest.json`, `agent-system/extensions/nix/scripts/nix-preflight.sh`,
  `agent-system/extensions/nix/scripts/nix-context.sh`,
  `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`,
  `agent-system/extensions/core/context/standards/shell-strict-mode.md`,
  `specs/200_consumer_deploy_propagation_gap/` (empty artifact dirs — confirmed NOT STARTED),
  `specs/203_reconcile_lean_lsp_mcp_registration/summaries/01_reconcile-lean-lsp-registration-summary.md`,
  `specs/TODO.md` (tasks 200, 203, 204 full descriptions).
- Commands run: `bash verify-lean-mcp.sh --quiet` timed 5x from `~/Projects/BimodalLogic`
  (30ms avg, exit 2 — live global entry currently points at `~/Projects/cslib`); `jq -e
  '.mcpServers."lean-lsp"' ~/.claude.json` timed once (7ms); `command -v shellcheck` (alias-only,
  resolves to Nix store path).
- Search queries: `grep -rn "skill_preflight_update"` across all extensions'
  `skills/*/SKILL.md`; `grep -n '"hooks": {'` across all `agent-system/extensions/*/manifest.json`.
