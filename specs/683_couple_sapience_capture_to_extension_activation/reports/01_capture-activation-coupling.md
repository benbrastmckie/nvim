# Research Report: Couple Sapience Capture to Extension Activation

- **Task**: 683 - Couple Sapience capture enablement to sapience-extension activation
- **Started**: 2026-11-21T18:08:00Z
- **Completed**: 2026-11-21T18:13:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` (the hook to extend)
  - `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` (the existing MCP writer/reaper)
  - `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` (check (i))
  - `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
  - Vendor source at `~/.sapience/`: `upload.py` (`projects_cli`, `capture_sync`, `_persist_capture`,
    `_session_candidates`, `sync`), `sapience_capture.py` (`set_project`, `normalize`,
    `is_project_root`, `deny_reason`, `session_allowed`, `allows`, `match_project`),
    `extract_local.py` (onboarding/`--projects` dispatch, `coverage()`), `sapience_cli.py`
  - `~/.sapience/config.json` (live machine state)
  - `/nix-profile/bin/sapience` shim (dispatch table)
  - `~/.dotfiles/.claude/hooks/sapience-mcp-register-project.sh` and
    `~/.dotfiles/scripts/check-sapience-hooks.sh` (companion-owned copy)
  - `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` and
    `test-sapience-capture.sh` (fixture/stub conventions for new test coverage)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The vendor CLI `sapience projects on|off <path>` (`upload.py:projects_cli`) is prompt-free and
  touches only `~/.sapience/config.json`'s `capture.projects[]` — safe to call from a hook, but it
  unconditionally calls `capture_sync()` at the end, which makes two outbound HTTP calls
  (`timeout=8` each). Setting `SAPIENCE_NO_CAPTURE_SYNC=1` in the invocation environment makes
  `capture_sync()` return immediately with no network call at all — this is the clean way to make
  the hook's call fully network-free and bounded, rather than relying only on an outer `timeout`.
- **Critical gap, not previously flagged**: `~/.sapience/config.json`'s legacy top-level `folders`
  list is a SEPARATE, upstream gate on what `extract_local.py`/`upload.py` ever scans at all
  (`_session_candidates()`'s `f.parent.name in chosen` filter, and `sync()`'s outright bail when
  `folders == []`). `sapience projects on <path>` never touches `folders`. On this machine,
  `folders` already happens to list the four currently-enabled projects, but that is a historical
  coincidence of how they were originally enabled (through the interactive chooser, which writes
  both), not something the vendor CLI maintains going forward. A brand-new repo enabled solely via
  `sapience projects on <path>` will show as enabled in `sapience projects` but its transcripts will
  never actually be read until `folders` also grows to include it — and there is no safe,
  non-interactive, single-writer vendor-CLI path to grow `folders` (the onboarding chooser refuses
  outright without a TTY unless `SAPIENCE_ALLOW_ONBOARD=1`, and that override is documented as
  **overwriting the entire saved folder choice**, not adding to it).
- `sapience projects off <path>` works correctly even after the directory has vanished:
  `set_project()` matches an existing entry by string-equal `path_prefix` (no `os.path.isdir`
  check on the existing-entry path), and `normalize()`/`is_project_root()` never drop an entry for
  not existing on disk either. Extending the hook's reap pass to also turn off vanished
  `capture.projects[]` entries is therefore both warranted (nothing else ever does this) and
  mechanically straightforward.
- `deny_reason()` only refuses a hard-coded set of personal/system/hidden locations (home itself,
  system roots, `~/Desktop`/`~/Library`/etc., dotfiles, secrets files, personal-named folders); an
  ordinary git checkout root will essentially never trip it, but the hook must still handle a
  `None` return from `set_project()` (path denied or not a real directory) without ever failing the
  SessionStart contract.
- The companion `~/.dotfiles/.claude/hooks/sapience-mcp-register-project.sh` copy is confirmed
  byte-identical to this source store's copy today, and it is a **different git repository** — this
  task's edit (scoped to `agent-system/extensions/sapience` here) cannot itself keep that copy in
  sync; a matching edit filed as a task in `~/.dotfiles` is required to restore byte-identity, since
  whichever copy's installer/deploy runs last is what actually lands at the stable
  `~/.claude/hooks/sapience-mcp-register-project.sh` path every session invokes.

## Context & Scope

Task 683 asks to extend the existing bidirectional SessionStart hook
(`sapience-mcp-register-project.sh`) so that, in the same two branches that already
register/remove the per-project MCP entry, it also calls the vendor's own `sapience projects
on|off <checkout toplevel>` to couple transcript-capture enablement to sapience-extension
activation — never by hand-editing `~/.sapience/config.json` directly. This report investigates
the five settled questions the dispatch named, plus the surrounding mechanism (the hook itself,
`setup-sapience-mcp.sh`'s reap pass, `verify-sapience-mcp.sh` check (i), and
`per-repo-scoping.md`'s current ruling) needed to plan the change.

Scope is research only: no code changes were made. `agent-system/extensions/sapience/**` is the
edit target for a later implementation phase; `~/.sapience/**` is vendor-owned and read-only here;
`~/.dotfiles/**` is a different repository, read-only from this session.

## Findings

### 1. `sapience projects on|off <path>` and the legacy `folders` list — NOT kept in step

- `/home/benjamin/.nix-profile/bin/sapience projects <args>` dispatches to
  `python3 ~/.sapience/extract_local.py --projects <args>`
  (`extract_local.py:1996-1997`, confirmed from the live nix-profile shim), which calls
  `up.projects_cli(argv)` (`upload.py:1126-1180`) when `--projects` is present
  (`extract_local.py` `main()`, around line 1996).
- `projects_cli`'s `on`/`off` branch (`upload.py:1143-1151`) calls
  `sapience_capture.set_project(cap, key, enabled=...)` then `_persist_capture(cap)`
  (`upload.py:854-860`, which calls `_sc.save_capture(CONF, cap)` — `sapience_capture.py:482-489`,
  a merge of only the `capture` key into `config.json`). Neither touches `folders`.
- Separately, `~/.sapience/config.json`'s top-level `folders` array (a list of sanitized
  `~/.claude/projects/<key>` directory names, e.g. `-home-benjamin--config-nvim`) is read in
  `_session_candidates()` (`upload.py:1372-1386`):
  ```
  cand += [(f, False) for f in CLAUDE_DIR.rglob('*.jsonl')
           if (not chosen or f.parent.name in chosen) and not _skip(f) and _capture_allows(f, False)]
  ```
  When `chosen` (the `folders` set, via `with_home()`) is non-empty, only files whose parent
  folder key is IN `chosen` are even considered — this runs BEFORE `_capture_allows()` (which is
  what consults `capture.projects[]`). `sync()` (`upload.py:1485-1490`) additionally bails out
  entirely when `_cfg.get('folders') == []` ("documents-only brain, nothing to do"), independent of
  any `capture.projects[]` entry.
- `folders` is written ONLY by the interactive onboarding chooser
  (`extract_local.py` main, writes at the lines updating `cfg['folders']` after `_folders(fl)`) and
  by `--reset` (which clears it). A non-interactive run without a TTY is explicitly refused unless
  `SAPIENCE_ALLOW_ONBOARD=1` is set, and that path is documented inline
  (`extract_local.py`, "No unattended onboarding... it would keep every in-window folder, overwrite
  the saved folder choice") as **replacing** the whole saved selection, not adding one path to it —
  unsafe to invoke from a SessionStart hook under any circumstance.
- Live confirmation on this machine: `~/.sapience/config.json`'s `folders` currently lists exactly
  the four folder-keys for the four projects that have `capture.projects[].enabled == true`
  (`nvim`, `.dotfiles`, `abood`, `sapience-app`) — consistent with all four having been enabled
  through the interactive chooser (which sets both lists together), not through
  `sapience projects on`.
- **Consequence for this task**: calling `sapience projects on <path>` from the hook will make the
  new repo show up as `enabled` in `sapience projects`' listing (satisfying the literal text of the
  acceptance test), but its transcripts will not actually be read/extracted until its folder key is
  also present in `folders` — which this hook cannot safely add via any vendor-CLI command found in
  this research pass. This is a real reconciliation gap, not merely a theoretical one; see
  Recommendations.

### 2. Non-interactive safety and bounded-timeout behavior of `sapience projects on|off`

- `projects_cli` itself contains no `input()` call on the `on`/`off`/`auto`/`target`/`rename`/`mode`
  branches — only `review_hosted()` (a different subcommand, `sapience review`) prompts
  interactively, and it is never reached by `--projects`. Safe to call non-interactively.
- `projects_cli` unconditionally calls `capture_sync()` at the end (`upload.py:1180`), which makes
  up to two blocking HTTP calls (`urllib.request.urlopen(..., timeout=8)` for a GET then a POST,
  `upload.py:1025` and `:1055`) — worst case roughly 16s if the host is unreachable but not
  immediately refusing.
- `capture_sync()`'s own guard (`upload.py:1023`): `if _sc is None or not TOKEN or
  os.environ.get('SAPIENCE_NO_CAPTURE_SYNC') == '1': return` — set before any network call.
  **Setting `SAPIENCE_NO_CAPTURE_SYNC=1` in the hook's invocation environment makes the call
  entirely network-free**, which is a cleaner mitigation than relying only on an outer `timeout`
  wrapper (though an outer bounded `timeout` is still recommended as defense-in-depth against
  Python/import startup cost or an unrelated hang, per this codebase's existing bounded-wait
  convention for hook-invoked subprocesses).
- No TOKEN present at all is already safe on its own (same guard), so the mitigation is strictly
  additive, not a workaround for a missing token.

### 3. Reap pass and vanished project directories

- `setup-sapience-mcp.sh --reap` (lines 190-236) only touches `~/.claude.json`'s
  `.projects[<path>].mcpServers.sapience`; it has no knowledge of `~/.sapience/config.json`'s
  `capture.projects[]` at all today.
- `sapience_capture.set_project(cap, key, enabled=False)` (`sapience_capture.py:459-479`) matches
  an EXISTING entry purely by `x['path_prefix'] == kp` string equality (after `os.path.realpath`
  normalization, which does not require the path to exist) — the `os.path.isdir(kp)` check
  (line 473) only gates creation of a NEW entry, never lookup of an existing one. So
  `sapience projects off <vanished-path>` succeeds and flips `enabled` to `false` even though the
  directory no longer exists.
- `normalize()` (`sapience_capture.py:192-204`) filters entries through `is_project_root()`
  (`sapience_capture.py:54-64`), which checks only realpath identity against home/system-root/TCC
  paths — **it has no `os.path.isdir` check either**, so an orphaned entry is never silently
  dropped on the next normalize/load. A vanished project therefore stays `enabled: true`
  indefinitely unless something explicitly turns it off.
- Conclusion: extending the hook's existing (ungated, cross-project) reap pass to also iterate
  `capture.projects[]` entries whose `path_prefix` is no longer a directory, and call
  `sapience projects off <path>` (with the same `SAPIENCE_NO_CAPTURE_SYNC=1` + bounded-timeout
  treatment as the register/remove branch) for each, is both warranted — nothing else in this
  surface ever does this — and mechanically safe given the matching behavior above.

### 4. `deny_reason()` and candidate checkout paths

- `deny_reason(path, home=None)` (`sapience_capture.py:117-142`) returns `''` (allowed) unless the
  realpath'd candidate is: the home directory itself; a system root or the home directory's parent;
  under a TCC-protected top-level folder (`~/Desktop`, `~/Library`, etc., unless it is a recognized
  AI-session path); a hidden (dotfile) top-level folder under home; one of `~/Downloads` or
  `~/Documents` taken as a WHOLE (a project folder *inside* them is fine); a path component matching
  a personal-folder name heuristic; or a secrets file.
- `set_project()` only consults `deny_reason` indirectly: `projects_cli` calls it itself
  (`upload.py:1147`) purely to produce a human-readable message when `set_project` returns `(None,
  cap)` because the given key is neither an existing project entry nor
  (`os.path.isdir(kp) and is_project_root(kp)`).
- For this hook's actual call sites, the path passed is always `resolve_checkout_toplevel()`'s
  output — a git checkout root that is, by construction, a real existing directory. The only
  realistic way `set_project` returns `None` here is if someone's git checkout root literally IS
  their home directory or sits directly inside one of the TCC-protected top-level folders — an edge
  case worth a graceful no-op (silent, matching the hook's existing degrade-silently contract), not
  a blocker.

### 5. The `~/.dotfiles` companion copy

- `diff` confirms `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` and
  `~/.dotfiles/.claude/hooks/sapience-mcp-register-project.sh` are byte-identical today.
- The hook's own header comment states the invocation path is deliberately stable
  (`~/.claude/hooks/sapience-mcp-register-project.sh`), independent of which repository's
  deploy/install last wrote it — so BOTH source copies (this source store's, and
  `~/.dotfiles`'s) need to carry the same body for the stable path to behave identically regardless
  of which repository's session last ran the installer.
- `~/.dotfiles` is a separate git repository from this one. Per
  `.claude/rules/source-store-deploy-boundary.md`'s Task Siting subsection, a task whose declared
  edit target is a source-store path must be created in the repository that actually contains that
  path on disk — this nvim-repo task cannot itself perform or commit the mirrored edit in
  `~/.dotfiles`. The existing `~/.dotfiles/scripts/check-sapience-hooks.sh` detector is unrelated
  (it only checks for the vendor's own machine-wide hook injection, not for drift between the two
  copies of THIS hook) — there is no existing automated byte-identity check between the two copies
  of `sapience-mcp-register-project.sh` itself; `test-sapience-mcp-registration.sh`'s own
  "lockstep case" (referenced in this hook's header) only asserts byte-identity of the
  marker-delimited `resolve_checkout_toplevel()` block across the FIVE scripts that embed it within
  THIS repository, not against the `~/.dotfiles` copy of the whole file.

### Supporting mechanism detail (for planning)

- `verify-sapience-mcp.sh` check (i) (lines 427-487) currently only reports, never writes: it
  resolves the longest-prefix `capture.projects[]` match and FAILs only on
  (inactive + capture enabled); (active + capture not enabled) is explicitly informational, "never a
  failure" — this asymmetry exists precisely because, pre-683, nothing in this source store ever
  wrote `capture.projects[].enabled`, so there was no expectation that activation implied capture.
  Once the hook actively writes it, this check's informational branch should be revisited (see
  Recommendations), while accounting for the hook's own documented one-session-start lag.
- `per-repo-scoping.md`'s "Capture/Activation Reconciliation" subsection (lines 343-356) currently
  rules that this source store must NOT write `capture.projects[].enabled`, reasoning that (1) doing
  so would be new unreviewed surface and (2) `~/.dotfiles` already owns a capture-map writer, so a
  second independent writer here would create the same two-writers hazard the MCP-registration
  entry already guards against. Task 683's design changes the premise of reason (2): routing
  through the vendor's own `sapience projects on|off` CLI (which itself owns the single write to
  `config.json`'s `capture` key, under its own file lock) means THIS hook never writes
  `config.json` directly at all — it only ever shells out to the one program that already owns that
  file, exactly mirroring how `setup-sapience-mcp.sh` is the sole writer of `~/.claude.json`. This
  removes the two-writers hazard that justified the existing ruling, rather than contradicting it by
  fiat.
- Existing fixture-test convention for the new coverage requested (`test-sapience-mcp-registration.sh`,
  `test-sapience-capture.sh`): build a scratch `$HOME`-shaped fixture tree, and PATH-shadow the
  external binary with a minimal recording stub script (the `build_curl_stub` pattern in
  `test-sapience-capture.sh:177+` — install an executable named exactly `sapience` ahead of the real
  one on `PATH`, record its argv/env to a file for assertions, exit 0). The missing-binary case is
  simplest: simply don't install the stub and assert the hook still exits 0 with `{}`/degrades
  silently when `command -v sapience` fails.

## Decisions

- Confirmed (research question 1): the legacy `folders` list DOES still gate session-transcript
  discovery independently of `capture.projects[].enabled`, and `sapience projects on|off` does
  NOT keep it in step. No safe single-writer, non-interactive vendor-CLI mechanism to grow
  `folders` was found in this pass — reconciling it is an open design question for the plan phase,
  not something this research settles with a ready answer (see Recommendations).
- Confirmed (research question 2): `sapience projects on|off <path>` is safe to call
  non-interactively (no prompts), but should be invoked with `SAPIENCE_NO_CAPTURE_SYNC=1` in its
  environment to make it fully network-free, plus an outer bounded `timeout` as defense-in-depth.
- Confirmed (research question 3): extending the reap pass to also turn off vanished
  `capture.projects[]` entries is both warranted and mechanically safe — `set_project`/`normalize`
  never require the path to still exist for an existing entry to be found and updated.
- Confirmed (research question 4): `deny_reason()` will not realistically refuse an ordinary git
  checkout root; the hook must still handle a `set_project` → `None` result gracefully (silent,
  exit-0-preserving), for the rare edge case where it would (checkout root == home or a TCC-denied
  top-level folder).
- Confirmed (research question 5): the `~/.dotfiles` companion copy is currently byte-identical and
  WILL need a matching edit to stay that way; that edit cannot be made or committed from this task
  (different repository) and must be sited as its own task in `~/.dotfiles` per
  `source-store-deploy-boundary.md`'s Task Siting rule.
- The prior `per-repo-scoping.md` ruling against writing `capture.projects[].enabled` from this
  source store rested on a two-writers hazard that routing through the vendor's own
  `sapience projects` CLI removes (ground overturned); the outcome (whether THIS source store may
  write the field) should now flip, which is itself the substance of task 683 rather than a
  contradiction of the prior ruling's reasoning at the time it was written.

## Recommendations

1. Invoke the vendor CLI as `SAPIENCE_NO_CAPTURE_SYNC=1 timeout <N> sapience projects on|off
   "$PATH"` (rather than an unwrapped call) from both the per-repo register/remove branch and a new
   reap-for-capture branch of the hook, mirroring the existing `setup-sapience-mcp.sh --reap --quiet`
   invocation style already used in the same hook. Resolve the `sapience` binary via
   `command -v sapience` first and degrade silently (no notice, `{}`/no-op) when it is absent,
   exactly like the existing `jq`/`WRITER` absence guards.
2. Make the write idempotent/silent-in-steady-state by checking the CURRENT
   `capture.projects[]` entry's `enabled` value for this path (via `jq`, mirroring
   `verify-sapience-mcp.sh` check (i)'s own longest-prefix match logic) before calling `on`/`off`,
   and only emit an `additionalContext` notice when the call actually changed something — matching
   the existing MCP-registration branch's notice discipline.
3. Extend `setup-sapience-mcp.sh --reap` (or add a parallel `--reap-capture` action, to keep the
   existing action single-purpose) to enumerate `capture.projects[]` entries whose `path_prefix` is
   no longer a directory and call `sapience projects off <path>` for each, under the same
   `SAPIENCE_NO_CAPTURE_SYNC=1` + bounded-`timeout` treatment — this directly answers research
   question 3 and keeps the extension-side reap symmetric with the MCP-registration reap it already
   performs.
4. Explicitly scope what this task CAN guarantee vs. cannot: the hook can make
   `capture.projects[].enabled` track extension activation (satisfying the literal acceptance test —
   it only asks that the repo show up as `enabled` in `sapience projects`), but cannot by itself
   guarantee transcripts are actually extracted unless `folders` is separately reconciled. Document
   this explicitly as a caveat in the implementation (per-repo-scoping.md and the hook's own header
   comment), rather than silently presenting activation-coupling as equivalent to working capture —
   this is the single most important caveat beyond the three the dispatch already names
   (one-session-start lag, backfill-on-first-sync, off-not-retroactive).
   `folders` reconciliation: in the absence of a safe automated path, the most honest documented
   remedy found in this pass is that the human operator re-run the installer's interactive
   onboarding flow once (from a terminal) after a new repo is enabled, which adds it to `folders`
   alongside whatever is already chosen; this is a manual, occasional step, not something the hook
   can perform. `[CORPUS-UNVERIFIED: whether a future vendor client version grows this mechanism /
   not checked against vendor changelog or update.log beyond this session's installed version]`
5. Rewrite `per-repo-scoping.md`'s "Capture/Activation Reconciliation" subsection to state: this
   source store now writes `capture.projects[].enabled` exclusively via the vendor's own
   `sapience projects on|off` CLI (never by hand-editing `config.json`), which keeps this extension
   a well-behaved CALLER of the vendor's single writer rather than a second independent writer —
   removing the two-writers hazard that justified the prior "must NOT write" ruling — while
   explicitly retaining and restating the `folders`-reconciliation caveat from Recommendation 4 as a
   known, documented limitation of the new design (not resolved by it).
6. Update `verify-sapience-mcp.sh` check (i): once the hook actively writes
   `capture.projects[].enabled`, consider upgrading (active + capture-not-enabled) from purely
   informational to a WARN (not necessarily a hard FAIL, to tolerate the documented
   one-session-start lag) — e.g. only FAIL it when `.claude-extensions.json`'s
   `merged_sections` shows the fragment has been merged for at least one full prior session, if that
   timestamp is available, or otherwise keep it informational but add explicit text noting the lag
   and that a hook failure (missing `sapience` binary, timeout) is a silent, expected non-write.
   This is a plan-level judgment call, not settled by this research pass.
7. New fixture-HOME test coverage: add a stubbed `sapience` executable (PATH-shadowed, recording
   its argv to a file, exit 0) to `agent-system/extensions/sapience/scripts/tests/`, following
   `test-sapience-capture.sh`'s `build_curl_stub` pattern, and cover: (a) `on` when extension active
   and no existing capture entry; (b) `off` when extension inactive and an existing enabled entry;
   (c) steady-state-silent when the capture entry already matches activation state (no stub
   invocation recorded, or a recorded invocation that produces no notice); (d) missing-`sapience`-
   binary (no stub installed) degrading silently; (e) a linked-worktree case asserting the resolved
   path passed to the stub is the PARENT CHECKOUT, not the worktree directory (mirroring check (f)'s
   existing worktree-scoping assertion for MCP registration).
8. File a companion task in the `~/.dotfiles` repository to mirror this task's exact diff into
   `~/.dotfiles/.claude/hooks/sapience-mcp-register-project.sh` (and
   `~/.dotfiles/.claude/scripts/setup-sapience-mcp.sh` if the reap extension lands there too),
   restoring byte-identity — this cannot be done from within task 683 itself per the task-siting
   rule in `source-store-deploy-boundary.md`.

## Risks & Mitigations

- **Risk**: presenting `capture.projects[].enabled == true` as "capture is on" when `folders` has
  not grown to match leaves a silent false sense of coverage. **Mitigation**: Recommendation 4 —
  document the caveat explicitly rather than treating the vendor-CLI call as sufficient.
- **Risk**: a hung or slow `sapience` network call delays every session start in every repository
  with the extension active (SessionStart hooks run synchronously). **Mitigation**:
  `SAPIENCE_NO_CAPTURE_SYNC=1` plus an outer bounded `timeout` (Recommendation 1) removes the
  network dependency entirely rather than merely bounding it.
- **Risk**: a future vendor client update changes `projects_cli`'s behavior (e.g. starts writing
  `folders` itself, or removes the `SAPIENCE_NO_CAPTURE_SYNC` guard). **Mitigation**: none available
  from this source store (vendor-owned, auto-updating); the hook's existing degrade-silently
  contract (never fail the session) already absorbs a behavior change that causes the CLI call to
  error or hang past the outer timeout.
- **Risk**: implementing the reap-for-capture extension (Recommendation 3) inside the already-dense
  `sapience-mcp-register-project.sh` hook grows its complexity further. **Mitigation**: consider a
  parallel `--reap-capture` action on `setup-sapience-mcp.sh` (kept separate from `--reap`'s
  existing MCP-registration-only scope, per that script's own single-purpose-per-action
  convention) rather than interleaving the two reap concerns in one code path.

## Context Extension Recommendations

- **Topic**: the `folders`/`capture.projects[]` double-gate on session-transcript capture.
- **Gap**: no existing context file in `agent-system/extensions/sapience/context/` documents that
  `folders` is a separate, non-automatically-reconciled gate above the per-project capture map — the
  existing memory-context note on this topic (relevance 0, cited in this task's dispatch) is the
  only place this is recorded, and it is a point-in-time measurement, not durable guidance.
- **Recommendation**: add a short subsection to `per-repo-scoping.md` (alongside the rewritten
  Capture/Activation Reconciliation subsection from Recommendation 5) explicitly naming this
  double-gate and its lack of a safe automated reconciliation path, so a future task touching
  capture enablement does not have to re-derive this finding from vendor source again.

## Appendix

- Live `~/.sapience/config.json` inspected directly (`capture.mode`, `capture.projects[]`,
  `folders`, `days`) — not reproduced verbatim here beyond what Findings cites, since it is a
  point-in-time machine state, not a durable reference.
- Vendor CLI dispatch path confirmed via the installed shim at
  `/home/benjamin/.nix-profile/bin/sapience` (`projects) exec python3
  ~/.sapience/extract_local.py --projects "$@"`).
- `~/.dotfiles/.claude/hooks/sapience-mcp-register-project.sh` vs. the source-store copy: `diff`
  produced no output (byte-identical) at the time of this research pass.
