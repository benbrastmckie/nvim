# Research Report: Task #321

**Task**: 321 - Lean language server readiness preflight
**Started**: 2026-10-02
**Completed**: 2026-10-02
**Effort**: medium (one extended script, two new call-site integrations, one test file extension, one context doc update)
**Dependencies**: None blocking; cross-references open task 268 (see Findings)
**Sources/Inputs**: Codebase (agent-system/extensions/lean/, agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh, skill-base.sh), live-process empirical measurement, task 268's state.json record
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The registration-vs-reachability gap named in the dispatch is real and fixable with a cheap,
  precise, already-precedented technique: a single `ps -eo pid,ppid,comm,args` snapshot to find a
  `lean-lsp-mcp` process, then `/proc/<pid>/environ`'s `LEAN_PROJECT_PATH` (or `/proc/<pid>/cwd`)
  to confirm it serves *this* project. Measured cost ~35ms, well inside the ~100ms budget, no
  server spawn, no network call.
- **The deeper, higher-leverage gap is not in the probe's logic but in where it is wired.** The
  four lean skills' Stage 2 inline call (`lean-mcp-preflight-check.sh`) is reached only by a
  direct `/research|/plan|/implement` invocation. `/orchestrate` — the dominant real-world driver,
  and the actual path the motivating incident ran under — resolves agents directly via
  `command-route-agent.sh`/`orchestrate-build-dispatch.sh` and **never touches those four
  SKILL.md bodies at all**. Worse, the manifest `hooks.preflight` mechanism that *does* fire
  during `/orchestrate` (`skill_run_extension_hook`, called from `skill_preflight_update`) resolves
  the hook's owning extension **by `task_type`**, and the incident's task_type was `formal`, not
  `lean4` — `formal`'s own manifest declares no `hooks` key, so even registering the probe there
  would not reach it. The fix must be task-type-agnostic (directory detection, exactly as the
  probe already does internally), called unconditionally from `orchestrate-build-dispatch.sh`.
- The `.olean` staleness half (motivating harm (2)) does **not** belong in this sub-100ms
  dispatch-time preflight: full staleness detection requires walking a dependency graph across
  hundreds of files, which cannot stay sub-100ms, and it is a *build-cache-correctness* concern
  (Lake's own incremental build / `lake-build-guard.sh`'s result cache), not a dispatch-readiness
  concern. Recommend it stay out of this task's file_scope, with the diagnostic tell recorded as
  a durable reference doc and the reproduction relayed to task 268 as evidence (not implemented
  here).
- Recommended shape: extend `lean-mcp-preflight-check.sh` with a machine-readable tier output
  (new flag, existing human-readable WARN-only stderr path untouched), and thread that tier into
  **two** call sites: `orchestrate-build-dispatch.sh` (new `<lean-readiness-context>` dispatch-file
  block, unconditional / directory-gated) and the four lean skills' Stage 3 delegation context
  (so the direct-command path also reaches the dispatched subagent, not just the orchestrating
  skill's own transcript).

## Context & Scope

Task 321 extends an **already-existing, already-wired, WARN-only** preflight probe
(`agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh`) rather than adding a
competing mechanism. The task names three gaps to close:

1. The probe checks MCP *registration* (via `verify-lean-mcp.sh`'s nine checks), not server
   *reachability*.
2. No `.olean` staleness check exists.
3. The probe's finding reaches stderr only, never the dispatched agent's own context.

The task explicitly excludes `lake-build-guard.sh` and its test (open task 268's declared
file_scope) and instructs: if the `.olean` staleness probe turns out to belong here rather than
in 268, say so and claim the path via `proposed_file_scope` — otherwise leave it alone.

## Findings

### Finding 1 — The real dispatch path never reaches the four lean skills' Stage 2 at all

`CLAUDE.md`'s own Quick Reference states core/extension task types "route directly to agents via
`skill-orchestrate`'s dispatch (`command-route-agent.sh`), not through a dedicated
research/plan/implement skill layer." Confirmed directly in
`agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:2021`:

```
source "$SCRIPT_DIR/command-route-agent.sh" "$op" "$ttype" "$default_agent" "${effort_flag:-}"
```

This resolves `lean-research-agent` (etc.) directly from the `lean` extension's
`routing_agents` table in `manifest.json` — the body of `skills/skill-lean-research/SKILL.md`,
including its Stage 2 inline call to `lean-mcp-preflight-check.sh`, is simply never executed by
`/orchestrate`. That inline call (and its three siblings in
`skill-lean-research-hard`/`skill-lean-implementation`/`skill-lean-implementation-hard`) is reached
**only** by a human- or agent-issued direct `/research N` / `/plan N` / `/implement N` for a
`lean4`-typed task — a comparatively rare path next to `/orchestrate`, and not the path the
motivating incident ran under (`/orchestrate 704,705,707,708,710 --lit --fable`).

### Finding 2 — The manifest hook mechanism that *does* fire during `/orchestrate` is keyed by task_type-to-single-owning-extension, and the incident's task_type was `formal`, not `lean4`

`orchestrate-cycle-plan.sh:2642` calls `skill_preflight_update`, which (per `skill-base.sh:387`)
unconditionally calls:

```
skill_run_extension_hook "preflight" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"
```

`skill_run_extension_hook` (skill-base.sh:155-192) resolves the hook's extension via
`skill_get_extension_dir "$task_type"` — i.e. the single extension that *declares* that exact
`task_type`, then reads that extension's own `manifest.json`'s `.hooks[$hook_name]`. This is the
same mechanism the nix extension already uses (`"hooks": {"preflight": "scripts/nix-preflight.sh"}`
in `agent-system/extensions/nix/manifest.json`), and the pattern this script's own header comment
names as the eventual sanctioned home for this probe.

**But the motivating incident's task_type was `formal`** (BimodalLogic's tasks 704/705/707/708/710
are formal-logic proof tasks), and `agent-system/extensions/formal/manifest.json` declares
`routing_agents.implement.formal = "general-implementation-agent"` and **no `hooks` key at all**.
Its `dependencies` array is `["core"]`, not `["core", "lean"]`. So even if this task registered
`lean-mcp-preflight-check.sh` as `lean`'s own `hooks.preflight`, `skill_get_extension_dir("formal")`
would resolve to the `formal` extension, never consult `lean`'s manifest, and the hook would not
fire for exactly the task_type that triggered the original observation. A `formal`-typed task can
be, and in this case was, a Lean project underneath (BimodalLogic proves theorems in Lean 4) —
`task_type` here is a project-domain label, not a reliable signal of "does LSP-backed lookup apply
here."

**Conclusion**: a per-extension, task_type-keyed `hooks.preflight` registration is the wrong
mechanism for this specific fix. The existing probe already does the right thing internally — it
self-gates on `lakefile.lean`/`lakefile.toml` presence at CWD or git root, independent of
task_type — and the fix must preserve that task-type-agnostic gate by calling the probe
**unconditionally** from a script every dispatch passes through, not from a task-type-routed
hook.

### Finding 3 — `orchestrate-build-dispatch.sh` is that script, and already has the right shape to extend

`agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` is called once per dispatch
from `orchestrate-cycle-plan.sh:2705`, runs with CWD at the target repository's root (the repo
`/orchestrate` is driving — e.g. BimodalLogic, not this nvim-config source-store repo), and
already builds exactly one precedented example of a conditionally-injected, tagged context block
computed ahead of the heredoc: `deploy_freshness_context` (lines 341-361), emitted as a
`<deploy-freshness-context>...</deploy-freshness-context>` block and appended into the dispatch
file only `if [ -n "$deploy_freshness_context" ]` (line 507-510). This is the template to follow
for a new `<lean-readiness-context>` block: computed early (a "Stage 3.5 output" by this script's
own internal numbering), gated on the SAME lockstep Lean-project detection the probe already uses
internally (so the 99% non-Lean-dispatch case costs nothing extra — the probe's own early exit is
~6ms), and appended unconditionally into every dispatch file regardless of `task_type`.

`task_type` itself is already in scope in this script (`task_type="$TASK_TYPE"`, line 187, used
for the unrelated `hard_contracts` routing lookup at line 316) — so nothing new needs plumbing
through; the new block simply does not condition on it.

This directly satisfies the Acceptance criterion's literal text ("A `lean4` dispatch... receives,
in its dispatch file...") and, by being task-type-agnostic, additionally fixes the actual
`formal`-typed incident that motivated the task — a strictly larger fix than the literal
acceptance text names, achieved by reusing the one dimension (directory detection) the existing
probe already got right.

### Finding 4 — Direct-command path has a parallel, smaller version of the same gap

For the direct `/research|/plan|/implement` path (skill-lean-research etc.), Stage 2's
`bash .claude/scripts/lean-mcp-preflight-check.sh || true` output goes to the *orchestrating
skill's own* stdout/transcript. The dispatched subagent (lean-research-agent etc.) is a fresh
Agent-tool invocation with no memory of that transcript — Stage 3's delegation-context JSON
(the `focus_prompt` etc. block) is the only channel that actually reaches it, and today nothing
from Stage 2 is threaded into it. This is the same finding-doesn't-reach-the-agent defect as
Finding 1-2, in miniature, on the less-traveled path. In scope for completeness but lower
priority than Finding 3's fix.

### Finding 5 — Reachability probe design: empirically measured, precedented, sub-100ms, no spawn

Live measurement on this machine (a running `lean-lsp-mcp` instance, registered for
`/home/benjamin/Projects/BimodalLogic`):

```
pid=2822632 ppid=2822061 comm=uv     args=".../uv tool uvx lean-lsp-mcp"      <- uvx launcher, comm is "uv" (not exec-replaced)
pid=2823073 ppid=2822632 comm=python args=".../bin/python .../bin/lean-lsp-mcp" <- actual server
/proc/2823073/environ  -> LEAN_PROJECT_PATH=/home/benjamin/Projects/BimodalLogic
/proc/2823073/cwd       -> /home/benjamin/Projects/BimodalLogic   (symlink)
```

Key implications:
- `uvx` does **not** exec-replace itself — there are always two processes (`uv`/launcher and the
  real server), so matching on `comm` alone is useless (a concurrent `mcp-nixos` server also
  shows `comm=uv`). The only reliable identity signal in the process table is an `args` substring
  match on `lean-lsp-mcp` (precise: it does not collide with `mcp-nixos` or any other registered
  server observed on this machine).
- Once a candidate PID is found, `/proc/<pid>/environ`'s `LEAN_PROJECT_PATH` (or
  `/proc/<pid>/cwd`, redundant confirmation) gives an *exact* match against the expected project
  path — no heuristic needed for the project-identity half of the check.
- Measured cost of one `ps -eo pid,ppid,comm,args --no-headers` snapshot plus the `/proc` reads:
  **~35ms** (3-run mean), the same order of magnitude as the existing script's own measured
  ~25ms registered-project path. Comfortably inside the ~100ms budget, especially since this new
  check should only run *after* registration is confirmed present (the common non-Lean-project
  and not-yet-registered cases keep the existing ~6-20ms exits unchanged).
- No server spawn on any path: this only *inspects* an already-running (or absent) process; it
  never launches one.
- Precedent for `/proc`-based PID inspection already exists in this codebase —
  `agent-system/extensions/core/scripts/deprecated/rename-session.sh` reads `/proc/$pid/cwd` and
  `/proc/$pid/cmdline` for an analogous purpose (though that script is itself deprecated, it
  establishes the idiom was previously accepted here).
- **Portability caveat, stated honestly per the task's own instruction**: `/proc` is Linux-only.
  This repository's environment is NixOS/Linux-only (per the session environment and every
  existing lean-script comment's framing), and the existing four scripts already assume Linux-
  compatible `ps`/`jq`/`git` idioms with no macOS branch, so this is consistent with existing
  practice, not a new constraint — but it is a real one: on a hypothetical macOS deploy, this
  check would need a different mechanism (`lsof -a -p <pid> -d cwd`, or `ps -o command` text
  parsing for env is not available on macOS at all without `ps -E`, which is also not portable).
  The honest, WARN-safe resolution: if `/proc/<pid>/environ` is unreadable or `/proc` does not
  exist, report the tier as **unknown** (not "reachable" and not silently treated as absent) —
  never let an unavailable introspection mechanism be mistaken for "no server running."
- A separate codebase convention is directly relevant and should be followed: `lake-build-guard.sh`'s
  `cmd_status()` explicitly avoids process-table scanning in its own polling loop, for a
  *self-match* hazard (a polling shell whose own argv contains the string it searches for
  self-matches `pgrep -f`). That hazard does not apply here — this preflight script's own name
  (`lean-mcp-preflight-check.sh`) never contains the string `lean-lsp-mcp`, so no self-match is
  possible — but the broader discipline it demonstrates (one atomic `ps` snapshot per invocation,
  explicit column selection, refuse loudly rather than fall back to an unsafe argv-substring match
  silently) is the right model to copy for this check's implementation.

### Finding 6 — `index: unavailable` vs `warming` vs `consulted` is an already-settled fact, not something to re-derive

The dispatch file states this as established lean-lsp tool contract (the three-state vocabulary
for `lean_local_search`'s `index` field: `unavailable` = no language server running, `warming` =
index still loading, `consulted` = the only state in which an empty result is proof of absence).
This vocabulary is not documented anywhere in-repo (`agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md`
documents the tool's existence and blocked-tool list but not this three-state result shape) — it
is upstream `lean-lsp-mcp` package behavior. This is itself a context gap (see Context Extension
Recommendations) independent of the preflight-probe mechanism: an agent that has never read this
three-state distinction will misread an `unavailable` empty result as proof of absence regardless
of what the preflight probe reports, unless the dispatch-file block *also* states the
interpretation rule inline (not just "reachable: yes/no").

### Finding 7 — `.olean` staleness does not belong in this preflight; it is a different mechanism than (and only a plausible, unconfirmed relative of) open task 268

Task 268's current (accepted, in-progress) working theory is specifically about
`agent-system/extensions/core/scripts/dispatch-worktree.sh` hardlink-cloning
`$PROJECT_ROOT/.lake` into every dispatch worktree via `cp -al`, causing `lake-build-guard.sh`'s
own **result-cache files** (`build-guard.result`/`.log`/`.lock`/etc.) to be silently shared
(same inode, two paths) across trees — a cross-tree *replay* of the guard's own bookkeeping, not
of Lake's `.olean` build output per se. Task 321's motivating harm (2), by contrast, was observed
directly in a single checkout of `~/Projects/BimodalLogic` across five sequential research
dispatches of the *same* repository (no worktree cloning evident in that run's description) — a
**Lake-native incremental-build/trace staleness** symptom (dependency `.olean` files older than
their sources, with a matching recorded trace hash causing Lake to skip recompilation), which is
a property of Lake's own build cache, not of `lake-build-guard.sh`'s wrapper-level result cache.

These are plausibly the same *root-cause family* (a content/trace-hash-keyed cache believing
stale content is fresh) but are **not demonstrably the same mechanism** — 268's dominant current
theory (hardlink cross-tree replay) requires worktree cloning that this incident's own narrative
does not describe, making 321's reproduction closer to 268's earlier, not-yet-ruled-out (a)/(b)
theories (a `compute_scope_key`/trace-hash collision) than to its current (d) theory. Determining
which is correctly task 268's job, with the reproduction evidence relayed as input — not
something this research task should assert or resolve.

Separately and independent of mechanism identity: a full `.olean` staleness check (walking
638+ files' dependency graphs to confirm every `.olean`'s content postdates every transitive
source it depends on) is **not** a sub-100ms, no-build-tool-invocation operation — it is exactly
the kind of expensive repository walk the existing probe's own header explicitly disclaims
("No repository walk, no network call, no MCP server spawn on any path"). It belongs with
build-time correctness tooling (`lake-build-guard.sh`'s territory), not with a pre-dispatch
readiness probe.

**Decision (see Decisions below): the `.olean` staleness check is excluded from this task's
file_scope.** The one-cheap-check version the dispatch itself surfaces — `PlusGraphPath.lab`/`.st`
resolving while `.decoded` does not, despite `lab`/`st` being *defined as* projections of
`.decoded` — is a project-specific symptom pattern (depends on knowing that particular
definitional relationship), not a mechanically generalizable sub-100ms check; it is worth
preserving as a documented diagnostic technique (see Recommendations), not as automated probe
logic.

### Finding 8 — Existing test suite conventions to extend, not replace

`agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` (583 lines) already
covers fixtures A-I (registration drift shapes) via synthetic `HOME`-pointed `.claude.json`
fixtures plus two independent mutation checks. A new reachability-tier fixture set should follow
the same house style: synthetic fixture repos, no real `uvx`/`lean-lsp-mcp` spawn (a fixture can
instead background a long-lived dummy process — e.g. `sleep 300 &` relaunched under a fake
`comm`/`args` via a wrapper script named to contain the literal substring `lean-lsp-mcp`, with
`LEAN_PROJECT_PATH` exported — to exercise the `ps`+`/proc` matching logic without needing the
real MCP package installed), plus a mutation check proving the new matching logic is actually
exercised. `test-orchestrate-build-dispatch.sh` and `test-deploy-freshness.sh` both already exist
as the analogous test files for the dispatch-file-injection half.

## Decisions

- **`.olean` staleness stays out of this task's file_scope.** It is a build-cache-correctness
  concern (Lake's own incremental build, adjacent to but not identical to task 268's current
  hardlink-replay theory), not a dispatch-readiness concern, and cannot be made sub-100ms at
  real-project scale. No `proposed_file_scope` entry is added for it.
- **The reachability check gates on directory detection (lakefile presence), never on
  `task_type`.** This is required, not a stylistic preference: `skill_get_extension_dir`'s
  task_type-to-single-extension hook resolution cannot reach a lean-owned hook for a
  `formal`-typed (or any non-`lean4`-typed) Lean project, and the motivating incident was exactly
  that case. The fix must be an unconditional call from a script every dispatch passes through
  (`orchestrate-build-dispatch.sh`), not a `hooks.preflight` manifest registration.
- **The probe's existing WARN-only, always-exit-0 contract is preserved exactly.** The new
  reachability check is additive (a new output mode/flag), never changes the script's exit
  behavior, and degrades to an explicit "unknown" tier (never a silent false-positive "reachable")
  on any introspection failure (`/proc` unavailable, `ps` failure, permission denial).
- **Both call-site integrations are in scope**: `orchestrate-build-dispatch.sh` (primary, fixes
  the actual incident) and the four lean skills' Stage 2/3 (secondary, fixes the direct-command
  path's parallel gap, for consistency). Neither alone fully satisfies the dispatch's Goal
  ("before it starts, and before a `lean_local_search` call is misread").

## Recommendations

1. **Extend `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh`** with a new
   machine-readable output mode (e.g. a flag such as `--tier` or a fixed-format single line on a
   dedicated file descriptor/stdout prefix, left to planning to pin down) that, after the existing
   registration checks, adds: (a) the `ps -eo pid,ppid,comm,args --no-headers` snapshot +
   `/proc/<pid>/environ` (`LEAN_PROJECT_PATH`) matching described in Finding 5, producing one of
   `reachable` / `not_reachable` / `unknown`; (b) a short, fixed interpretation sentence
   explicitly naming the `unavailable`/`warming`/`consulted` three-state vocabulary from
   Finding 6, so the dispatch-file text itself teaches the reader how to read a future
   `lean_local_search` result rather than merely asserting a tier label. Keep the existing
   human-readable stderr path byte-identical for the four current call sites (backward
   compatible by construction — a new flag, not a changed default).
2. **Add a new `lean_readiness_context` computation to `orchestrate-build-dispatch.sh`**, modeled
   directly on `deploy_freshness_context` (same file, lines 341-361): gated on the lockstep
   Lean-project directory detection (not `task_type`), invoking the extended probe from
   Recommendation 1, emitting a `<lean-readiness-context>...</lean-readiness-context>` block,
   appended unconditionally alongside the existing `deploy_freshness_context`/`hard_contracts_block`
   injection chain (~line 507). `proposed_file_scope`: this file, plus
   `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`.
3. **Thread the same tier information into the four lean skills' Stage 3 delegation context**
   (`skill-lean-research`, `skill-lean-research-hard`, `skill-lean-implementation`,
   `skill-lean-implementation-hard`), e.g. a new `lean_readiness` field alongside `focus_prompt`
   in the delegation-context JSON, sourced from Stage 2's existing inline call (captured instead
   of discarded). `proposed_file_scope`: the four `SKILL.md` files.
4. **Extend `test-lean-mcp-preflight-check.sh`** with reachability-tier fixtures per Finding 8
   (synthetic fake-server fixtures, no real MCP package dependency), following its existing
   mutation-check discipline. `proposed_file_scope`: this test file.
5. **Do not touch `lake-build-guard.sh` or its test.** Relay the motivating-harm-(2) reproduction
   (24/638 stale `.olean`, trace-match causing skipped recompilation, `err_20261002080500`, the
   `lab`/`st`/`.decoded` asymmetry tell) to task 268 as evidence for its `--no-share`/root-cause
   investigation — as an informational note on task 268, not a file edit, and not something this
   research task performs directly (268 is a concurrent sibling in `[implementing]` with its own
   declared file_scope; adding evidence belongs to the orchestrator/user coordinating across the
   two tasks, not to an out-of-territory write from this task).
6. **Record the `.decoded`/`lab`/`st` diagnostic tell as a durable reference**, not as executable
   probe logic: a short addition to
   `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` (which already covers
   reachability-adjacent material for lean-lsp) or a new sibling doc, documenting the general
   technique — "if field X is defined as a projection of field Y, and X resolves while Y does
   not, the `.olean` and the source provably came from different revisions" — as a cheap manual
   (or future tool-assisted) sanity check distinct from this task's automated preflight.
   `proposed_file_scope`: `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
   (or a new file under the same directory).

## Risks & Mitigations

- **Risk**: the `args`-substring match on `lean-lsp-mcp` could, in principle, collide with an
  unrelated process that happens to carry that string in its command line (e.g. a shell history
  replay, a `grep` for the string itself). **Mitigation**: exclude the probe's own PID/PPID row
  (the same `is_self_row` idiom `lake-build-guard.sh` already uses) and require the
  `/proc/<pid>/environ` `LEAN_PROJECT_PATH` cross-check to match the expected project path
  exactly before reporting `reachable` — a bare argv match alone is not sufficient evidence and
  should never be the sole basis for the tier.
- **Risk**: `/proc` is Linux-only; a hypothetical future macOS deploy would get `unknown` tier
  unconditionally. **Mitigation**: that is the honest, already-decided degrade path (Finding 5) —
  `unknown` is a safe default, never silently promoted to `reachable`.
- **Risk**: adding a new dispatch-file block (`<lean-readiness-context>`) that is wrong (e.g.
  reports `reachable` when the server is actually hung/unresponsive, since a live process does
  not guarantee responsiveness) could give false confidence. **Mitigation**: the interpretation
  text (Recommendation 1b) must state this limitation explicitly — "a running process is a
  necessary, not sufficient, condition for reachability; a `lean_local_search` call reporting
  `index: unavailable` despite this tier still means degrade to the grep-sweep fallback" — keeping
  the WARN-only, never-silently-trust posture intact even when the probe itself is wrong.
- **Risk**: scope creep into task 268's territory via the `.olean`/cross-tree-replay discussion.
  **Mitigated** by the explicit Decision above: no file_scope claimed there, no file touched
  there; only an informational relay recommended.

## Context Extension Recommendations

- **Topic**: `lean_local_search`'s `index` field three-state vocabulary (`unavailable` /
  `warming` / `consulted`) and its interpretation rule.
  **Gap**: not documented anywhere in `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md`
  or any sibling file — it is implicit upstream `lean-lsp-mcp` package behavior that this
  codebase currently relies on without ever writing down.
  **Recommendation**: add a short subsection to `mcp-tools-guide.md`'s `lean_local_search`
  section (or a new file under `context/project/lean4/tools/`) stating the three states and the
  "an empty `consulted` result is proof of absence; an empty `unavailable`/`warming` result is
  not" rule, independent of whether Recommendation 1-3 above are implemented — this is useful to
  any agent reading a raw tool result, with or without the new preflight tier text.
- **Topic**: reachability vs. registration as a general MCP-server concept (not Lean-specific).
  **Gap**: `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` documents the
  per-project registration ownership model in depth but does not currently distinguish
  "registered" from "actually running/reachable" as a named concept — the same distinction likely
  applies to any other per-project MCP server this codebase registers (e.g. `mcp-nixos`, observed
  live on this machine as a `uv`-launched process with the identical two-process shape).
  **Recommendation**: if Recommendation 1-3 is implemented for lean, consider whether the same
  registered-vs-reachable distinction and the `ps`+`/proc` technique should be named generically
  in `mcp-server-ownership.md` so a future non-Lean per-project MCP server does not need to
  rediscover it.

## Appendix

- Searches/commands used: `grep -rn` across `agent-system/extensions/lean/` and
  `agent-system/extensions/core/scripts/` for `lean-mcp-preflight-check`, `hooks.preflight`,
  `skill_run_extension_hook`, `task_type`; live `ps -eo pid,ppid,comm,args` + `/proc/<pid>/environ`
  + `/proc/<pid>/cwd` inspection against a real running `lean-lsp-mcp` instance registered for
  `~/Projects/BimodalLogic`; three-run timing of the proposed check (~34-36ms); inspection of
  `specs/268_lake_build_guard_false_green_scope_key/`'s `state.json` description and artifact list.
- Files read in full or in relevant part: `lean-mcp-preflight-check.sh`, `verify-lean-mcp.sh`,
  `lean-lsp-register-project.sh`, `skill-lean-research/SKILL.md` (Stages 1-3),
  `orchestrate-build-dispatch.sh` (lines 1-541), `skill-base.sh` (lines 155-440),
  `orchestrate-cycle-plan.sh` (grep context around lines 2021, 2642, 2705), `lake-build-guard.sh`
  (header + `cmd_status`/`take_ps_snapshot`), `formal/manifest.json`, `nix/manifest.json`,
  `mcp-tools-guide.md`, `test-lean-mcp-preflight-check.sh` (header), `rename-session.sh`.
- No `proposed_file_scope` entry for `lake-build-guard.sh` or its test (task 268's declared
  territory) — confirmed respected throughout.
