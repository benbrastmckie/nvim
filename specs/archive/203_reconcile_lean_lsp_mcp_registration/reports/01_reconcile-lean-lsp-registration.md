# Research Report: Task #203

**Task**: 203 - Reconcile lean-lsp MCP registration with the source store's sanctioned wrapper-free mechanism
**Started**: 2026-09-09T17:02:49Z
**Completed**: 2026-09-09T17:11:43Z
**Effort**: small-to-medium (config reconciliation, not new code)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/setup-lean-mcp.sh`, `verify-lean-mcp.sh`,
  `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`,
  `agent-system/extensions/lean/manifest.json`, `agent-system/extensions/lean/settings-fragment.json`
- Live machine state: `~/.claude.json` (`mcpServers`), `~/.claude/settings.json`,
  `~/Projects/cslib/.claude/scripts/lean-lsp-mcp-wrapper.sh`, `~/Projects/cslib/.git/info/exclude`
- Installed package: `/home/benjamin/.local/share/uv/tools/lean-lsp-mcp/lib/python3.13/site-packages/lean_lsp_mcp/{__init__,config}.py`
- Empirical shell tests (`uvx`, `lake`, `lean`, `env -i`) run directly on this machine
**Artifacts**:
- This report: `specs/203_reconcile_lean_lsp_mcp_registration/reports/01_reconcile-lean-lsp-registration.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All five open questions are resolved with direct evidence, not inference. The wrapper is
  confirmed unnecessary, its PATH export is confirmed non-load-bearing today, both CLI-flag and
  env-var conventions are confirmed genuinely supported by `lean-lsp-mcp` (CLI wins on conflict),
  the registration belongs at global/user scope via the existing `setup-lean-mcp.sh` mechanism,
  and cslib's orphaned wrapper should be retired rather than adopted.
- The remedy is a reconciliation, not new provisioning: re-run `setup-lean-mcp.sh` to overwrite
  the live `~/.claude.json` `mcpServers."lean-lsp"` entry with the sanctioned
  `uvx lean-lsp-mcp` + `LEAN_PROJECT_PATH` env-var form, and delete both orphaned wrapper copies
  (BimodalLogic's dead reference and cslib's still-present file plus its project-scoped
  `~/.claude.json` override).
- A durable invariant worth recording in `mcp-server-ownership.md`: an `mcpServers` `command`
  path must never point inside any repository's own `.claude/` tree, because that tree is a
  disposable, regenerated deploy artifact (per `rules/source-store-deploy-boundary.md`) — this is
  the exact property whose violation produced the ENOENT defect, independent of which repo it
  happens to occur in.

## Context & Scope

Scope is the global source store (`~/.config/nvim/agent-system/`, principally
`core/scripts/setup-lean-mcp.sh`, `core/scripts/verify-lean-mcp.sh`,
`core/context/patterns/mcp-server-ownership.md`, and the lean extension) plus the live
`~/.claude.json` as a configuration-remediation target. Nothing under
`~/Projects/BimodalLogic/` needs editing. Task 204 (drift detection) and task 200 (deploy
propagation) are related but explicitly out of scope here; their content was not read in depth
since neither has produced artifacts yet (both `specs/200_consumer_deploy_propagation_gap/` and
the task-29 directory contain no reports — verified before starting, so there was nothing to
read that could pre-empt their decisions).

## Findings

### (a) Does the wrapper need to exist at all? — NO, confirmed

`grep -rn "lean-lsp-mcp-wrapper" agent-system/` returns zero matches (exit 1). The lean
extension's `manifest.json` `mcp_servers` field (itself an inert/dead second surface per
`mcp-server-ownership.md`'s "Known gaps" section — nothing reads `manifest.json` for
registration) already encodes the wrapper-free shape:
```json
"lean-lsp": {"command": "uvx", "args": ["lean-lsp-mcp"]}
```
`setup-lean-mcp.sh` generates exactly this plus a computed `env.LEAN_PROJECT_PATH`. No script
anywhere in the source store ever authored a wrapper. The live `~/.claude.json` today instead
has:
```json
"lean-lsp": {"type":"stdio","command":".../BimodalLogic/.claude/scripts/lean-lsp-mcp-wrapper.sh",
             "args":["--lean-project-path","/home/benjamin/Projects/BimodalLogic"]}
```
— a file that does not exist. This is a hand-edit of `~/.claude.json`, not a deploy artifact the
system ever produced. **Confirmed: the wrapper is not needed; the remedy is reconciliation, not
authoring or templating a new script.**

### (b) Is the NixOS PATH export load-bearing under `uvx`? — NO, not today

cslib's wrapper prepends `$HOME/.elan/bin`, nix-profile paths, and
`/run/current-system/sw/bin` to `PATH` before exec'ing `lean-lsp-mcp` directly (not through
`uvx`). Empirical test, run on this machine, with `env -i` stripping the environment to only
`PATH=/run/current-system/sw/bin:/usr/bin:/bin` (i.e. deliberately excluding `~/.elan/bin` and
every nix-profile path the wrapper adds):
```
$ env -i PATH="/run/current-system/sw/bin:/usr/bin:/bin" HOME="$HOME" bash -c \
    'cd ~/Projects/cslib && lake env lean --version'
Lean (version 4.33.0-rc1, ..., Release)
```
`lake` and `lean` resolve and function correctly against cslib's pinned toolchain version with
only `/run/current-system/sw/bin` on `PATH`. The reason: NixOS installs `elan` as a
**system package** — `/run/current-system/sw/bin/lake` and `/run/current-system/sw/bin/lean` are
both symlinks into `/nix/store/.../elan-4.2.1/bin/`. `/run/current-system/sw/bin` is on every
process's `PATH` on this machine (confirmed via the live process tree: Claude Code itself was
launched from an interactive bash shell whose `PATH` already contains it, and every MCP
subprocess Claude Code spawns inherits that same process environment — there is no separate,
stripped spawn environment on this host). A bare `uvx lean-lsp-mcp --version` (no PATH
manipulation) also succeeded directly. **Confirmed: the PATH export the cslib wrapper performs
is redundant on this machine as currently configured.** It may have been necessary at some
earlier point before elan was promoted to a NixOS system package (the wrapper is dated July 1,
this task is filed September 9 — an earlier-elan-was-user-only-install hypothesis is plausible
but unverifiable after the fact and does not change the recommendation). Given (b) is negative,
the toolchain should NOT be baked into a deployed artifact; runtime resolution via the ordinary
inherited `PATH` is sufficient, and a clear, actionable failure message (see Recommendations)
is the correct guard against a future machine where it genuinely is absent, rather than a
silent, baked-in PATH prepend nobody would think to update.

### (c) Is `--lean-project-path` even a supported flag? — YES, and so is the env var

Read directly from the installed package
(`lean_lsp_mcp/__init__.py`, `lean_lsp_mcp/config.py`), confirmed against `--help` output:

- `--lean-project-path PATH` is a real, documented CLI argument.
- `LEAN_PROJECT_PATH` is a real, documented env var (`config.py`:
  `PROJECT_PATH_ENV = "LEAN_PROJECT_PATH"`).
- Precedence is explicit in source, with a comment stating it outright: `__init__.py` line ~132,
  `# Set env vars from CLI args (CLI takes precedence over env vars)` — when `--lean-project-path`
  is passed, it overwrites `os.environ["LEAN_PROJECT_PATH"]` before the server reads it.

So **both conventions are individually valid** against the real server interface — this was
never a case of one being wrong. The two call sites differ for an unrelated reason: the source
store's mechanism (env var, via `uvx lean-lsp-mcp`) needs no wrapper because `uvx` accepts
`env` directly in the MCP JSON shape. The live config's convention (positional `--lean-project-path`
flag) was presumably chosen because a *wrapper script* was the delivery vehicle and wrappers
naturally forward `"$@"` as CLI args — but the wrapper itself is the orphan, not the flag choice.
**Recommendation: keep the source store's existing env-var convention** (already implemented,
already documented in `mcp-server-ownership.md`, requires no interface change) rather than
switching `setup-lean-mcp.sh` to emit a `--lean-project-path` arg — there is no benefit to
changing a working, simpler mechanism to match an orphaned one.

### (d) Should the global-vs-project-scope placement be corrected?

Independently re-confirmed from the dispatch's framing: `~/.claude.json` `mcpServers` top-level
holds exactly `lean-lsp` and `playwright` as siblings of ordinary global keys
(`opusProMigrationComplete`, `hasAvailableSubscription`); `~/Projects/BimodalLogic` has no
project-scoped `mcpServers` entry, so the broken global entry is BimodalLogic's *and every other
non-overriding repo's* effective lean-lsp registration. `~/Projects/cslib` has a project-scoped
override at `.projects["/home/benjamin/Projects/cslib"].mcpServers` (a real, existing local-scope
`~/.claude.json` mechanism — but `mcp-server-ownership.md` states plainly "nothing here writes
to the local scope", i.e. this is a hand-authored pattern outside the documented sanctioned
mechanism, not a second sanctioned path).

**Recommendation, stated as a real trade-off rather than a flat ruling** (this genuinely needs
the plan phase, or the user, to pick a side, since it is a workflow-ergonomics call, not a
correctness call):

- **Keep the single global/user-scope entry as the sole sanctioned mechanism** (option A). This
  matches what `setup-lean-mcp.sh` already implements and what `mcp-server-ownership.md` already
  documents: lean-lsp is a "per-project computed arguments needed" case that lives in user scope,
  with the expectation that `setup-lean-mcp.sh` is re-run when switching which Lean project you
  are actively working in (the script already handles "already configured but with a different
  project path" by overwriting `LEAN_PROJECT_PATH`). Under this option, cslib's project-scoped
  override is a divergence to retire, not a pattern to formalize — every repo, cslib included,
  shares one global entry and the workflow is "run `setup-lean-mcp.sh` from the repo you're about
  to work in."
  - Cost: working across two Lean projects concurrently (e.g. two terminal tabs, one in
    BimodalLogic and one in cslib) means only the most-recently-`setup-lean-mcp.sh`-run project
    has a correct `LEAN_PROJECT_PATH`; the other silently indexes the wrong project until
    re-run. This is not a new cost introduced by this task — it is the existing, already-shipped
    behavior of the sanctioned mechanism — but it is worth stating plainly since cslib's
    project-scoped override was very likely someone's fix for exactly this friction.
- **Formalize project-scoped local entries as a second sanctioned mechanism** (option B): extend
  `setup-lean-mcp.sh` (or a sibling script) to optionally write into `~/.claude.json`'s
  `.projects["<cwd>"].mcpServers` local scope instead of (or in addition to) the global entry,
  and update `mcp-server-ownership.md` to document local scope as sanctioned. This solves the
  concurrent-multi-project case cleanly but adds a second registration surface to maintain and
  keep in sync with the global one — exactly the kind of duplication `mcp-server-ownership.md`
  already flags as a recurring failure mode elsewhere (see the lean-lsp permission-grant
  enumeration drift it documents, and the mcp_servers-in-manifest.json "second dead surface").

This research recommends **option A** as the smaller, more consistent change that requires no
new script logic and directly matches the documentation already in place — but flags option B as
a legitimate alternative the plan phase should weigh explicitly against the concurrent-project
cost above, rather than silently defaulting to A without naming the trade-off.

**Durable invariant** (the part of (d) that is NOT a judgment call — this should be recorded
outright): `~/.claude.json` (and any `.mcp.json`) `command` paths must never point inside a
repository's own `.claude/` deploy tree. Both `BimodalLogic/.gitignore` (`.claude/` fully
gitignored, 0 tracked files) and cslib's `.git/info/exclude` (`.claude` excluded) confirm both
deploy trees are disposable and regenerated wholesale — exactly the property
`rules/source-store-deploy-boundary.md` already names for hand-authored files landing in
`.claude/`. A command path pointing into `.claude/` is the MCP-registration instance of that same
anti-pattern: it looks configured until the next regeneration or a fresh clone, then produces
exactly the silent ENOENT this task exists to fix. The fix should record this as an explicit rule
in `mcp-server-ownership.md`'s registration section, alongside the existing scope-choice
guidance.

### (e) Adopt or retire cslib's orphaned copy? — RETIRE

Given (a) (no wrapper needed) and (b) (PATH export not load-bearing), there is no functional
reason to adopt cslib's wrapper into the source store. It has additional divergences beyond the
two already named in the dispatch: it execs a hardcoded absolute binary path
(`/home/benjamin/.local/share/uv/tools/lean-lsp-mcp/bin/lean-lsp-mcp`) instead of `uvx
lean-lsp-mcp`, which pins it to whatever version happened to be installed at that path on Jul 1
and bypasses `uvx`'s normal resolution/update behavior — a third, independent reason not to
promote this file to a maintained artifact. **Recommendation: delete
`~/Projects/cslib/.claude/scripts/lean-lsp-mcp-wrapper.sh` and cslib's project-scoped
`~/.claude.json` override**, and let cslib pick up whichever mechanism (d) selects (global entry
under option A, or a local-scope entry under option B) — either way, via the sanctioned
`uvx lean-lsp-mcp` + env-var shape, never a hand-authored file inside `.claude/`.

### Registration vs. permission axis — permission is already correct

Cross-checked per `mcp-server-ownership.md`'s two-axis model: the **permission** axis is already
in its documented correct end state — `agent-system/extensions/lean/settings-fragment.json`
carries exactly the one wildcard grant `mcp__lean-lsp__*`, and the live
`~/.claude/settings.json` also carries `mcp__lean-lsp__*`. There is no 21-entry enumeration or
dead `mcpServers` block left in the lean fragment today (the doc's "Known gaps" narrative
describing that drift appears to already be resolved on the permission side). **This confirms
the defect is purely on the registration axis** — nothing about permissions needs to change as
part of this task.

## Decisions

- The wrapper-per-repo templating framing is rejected; confirmed by direct evidence (a).
- The env-var (`LEAN_PROJECT_PATH`) convention is retained as the sanctioned mechanism over the
  CLI-flag convention; both work against the real server, but the env-var path requires no
  wrapper and is already implemented (c).
- cslib's orphaned wrapper and its project-scoped override are to be deleted, not adopted (e).
- A durable invariant — MCP `command` paths must never point inside a repo's own `.claude/`
  deploy tree — should be added to `mcp-server-ownership.md` as part of this task's remedy (d).
- The global-vs-local scope question (d) is left as an explicit trade-off for the plan phase /
  user to resolve (option A recommended, option B named as the legitimate alternative), rather
  than silently decided here, since it is a workflow-ergonomics judgment call, not something the
  evidence gathered settles one way outright.

## Risks & Mitigations

- **Risk**: re-running `setup-lean-mcp.sh` from BimodalLogic will point the (shared, global)
  `LEAN_PROJECT_PATH` at BimodalLogic, which is correct for BimodalLogic but would be wrong for
  cslib the next time cslib is worked on without re-running the script there too. Mitigation:
  this is the known, already-documented behavior of the global-scope mechanism (see (d)); the
  plan phase should decide once, explicitly, whether that cost is accepted (option A) or solved
  by formalizing local scope (option B) — not rediscover it as a surprise during implementation.
- **Risk**: deleting cslib's wrapper before the replacement registration is live would leave
  cslib without a working lean-lsp server for one session. Mitigation: sequence the plan so the
  new registration (global env-var form, or local-scope form per (d)) is written and verified
  (fresh session, real tool call, per the dispatch's verification requirement) BEFORE the old
  wrapper file and its `~/.claude.json` override are deleted.
- **Risk**: config verification (`verify-lean-mcp.sh`) alone does not prove the server actually
  spawns — this is the dispatch's own explicit acceptance requirement. Mitigation: the plan
  should schedule an actual spawn-and-tool-call check in a fresh `claude -p` session (never the
  authoring session) against BOTH `~/Projects/BimodalLogic` and `~/Projects/cslib`, exactly as
  the dispatch specifies, before marking the task complete. This research pass did not perform a
  full MCP handshake by hand (out of scope for research; verified only the underlying
  `lake`/`lean`/`uvx` mechanics the server depends on).

## Context Extension Recommendations

- **Topic**: MCP registration durable invariants (command paths vs. disposable deploy trees).
- **Gap**: `mcp-server-ownership.md` documents scope choice, registration mechanism, and the
  permission/registration axis split thoroughly, but does not yet state the invariant that a
  `command` path must never resolve inside any repository's own `.claude/` tree. This defect is
  a direct, concrete instance of that unstated invariant being violated.
- **Recommendation**: add a short subsection to `mcp-server-ownership.md` (near "Choosing a
  registration surface") stating the invariant explicitly, citing this defect as the worked
  negative example, alongside `playwright`'s Nix-built-wrapper-binary and `lean-lsp`'s
  `uvx`-resolved-package as worked positive examples of "stable location outside any `.claude/`
  tree."

## Appendix

### Search queries / commands used

- `grep -rn "lean-lsp-mcp-wrapper" agent-system/` (source store — zero matches)
- `jq '.mcpServers'` / `jq '.projects["<path>"].mcpServers'` on `~/.claude.json`
- `uvx lean-lsp-mcp --help` / `--version`
- `grep -n "LEAN_PROJECT_PATH\|lean-project-path"` across `lean_lsp_mcp` package source
- `env -i PATH="/run/current-system/sw/bin:/usr/bin:/bin" ... lake env lean --version` (empirical
  PATH-minimality test against cslib)
- `ls -la /run/current-system/sw/bin/lake /run/current-system/sw/bin/lean` (confirms elan is a
  NixOS system package, not merely a user-level install)
- `cat ~/Projects/cslib/.claude/scripts/lean-lsp-mcp-wrapper.sh`, `stat`, `git ls-files
  --error-unmatch` (confirms untracked, hand-authored, dated Jul 1)
- `grep -n "lean-lsp" agent-system/extensions/lean/settings-fragment.json ~/.claude/settings.json`

### References

- `agent-system/extensions/core/scripts/setup-lean-mcp.sh`
- `agent-system/extensions/core/scripts/verify-lean-mcp.sh`
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
- `agent-system/extensions/lean/manifest.json`, `agent-system/extensions/lean/settings-fragment.json`
- `.claude/rules/source-store-deploy-boundary.md` (invariant this defect violates)
- Installed package: `lean_lsp_mcp/__init__.py`, `lean_lsp_mcp/config.py` (v0.27.0 on this
  machine's cached tool install; `uvx` itself resolved v0.30.0 fresh — server interface for
  `--lean-project-path`/`LEAN_PROJECT_PATH` is stable across both)
