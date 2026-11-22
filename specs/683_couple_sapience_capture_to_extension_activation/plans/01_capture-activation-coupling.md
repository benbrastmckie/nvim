# Implementation Plan: Couple Sapience Capture to Extension Activation

- **Task**: 683 - Couple Sapience capture enablement to sapience-extension activation
- **Status**: [IMPLEMENTING]
- **Effort**: 9 hours
- **Dependencies**: None
- **Research Inputs**: specs/683_couple_sapience_capture_to_extension_activation/reports/01_capture-activation-coupling.md
- **Artifacts**: plans/01_capture-activation-coupling.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The sapience extension's bidirectional `SessionStart` hook already registers and removes a repo's
own per-project MCP entry in `~/.claude.json` based on `.claude-extensions.json`'s
`.extensions.sapience.status`. This plan extends that same bidirectional mechanism to transcript
capture: the repo's `capture.projects[]` entry in `~/.sapience/config.json` is turned on when the
extension is active and off when it is not, exclusively by shelling out to the vendor's own
`sapience projects on|off <path>` CLI so the vendor client remains the sole writer of that file
under its own lock. The coupling is implemented as two new standalone actions on
`setup-sapience-mcp.sh` -- the writer the hook already resolves from its stable user-level path --
so the hook gains only two invocations in its existing style, the installed-file set is unchanged,
and there is exactly one implementation of the capture-state query. Done means: both hook branches
couple capture idempotently and silently in steady state, the always-exit-0 / exactly-one-JSON-line
contract is preserved, the vanished-directory reap pass covers capture as well as MCP registration,
`verify-sapience-mcp.sh` check (i) reflects that this source store now writes the field,
`per-repo-scoping.md` states the new design and its limits, and fixture-HOME tests with a stubbed
`sapience` binary cover on/off/steady-state/missing-binary/worktree plus the reap sweep.

### Research Integration

The research report settles all five dispatch questions and three of its findings shape this plan
directly:

- **`SAPIENCE_NO_CAPTURE_SYNC=1` makes the vendor call network-free.** `projects_cli`
  unconditionally ends in `capture_sync()`, which makes up to two blocking HTTP calls at
  `timeout=8` each (~16s worst case). The guard at `~/.sapience/upload.py:1023` returns before any
  network call when that variable is `1`. Re-confirmed live this dispatch: the guard line is
  present in the installed vendor copy. Every vendor-CLI call in this plan carries that variable
  plus an outer bounded `timeout` as defense-in-depth.
- **The legacy top-level `folders` list is a second, upstream gate that `sapience projects on`
  does not touch.** `_session_candidates()` filters candidate transcripts by `f.parent.name in
  chosen` before `capture.projects[]` is ever consulted, and `sync()` bails outright when
  `folders == []`. Re-confirmed live this dispatch: `folders` holds exactly the four folder-keys
  of the four `enabled: true` capture projects (`nvim`, `.dotfiles`, `abood`, `sapience-app`), and
  the acceptance-test target `/home/benjamin/Projects/Sapience/sf1-engine` is in **neither** list.
  No safe, non-interactive, single-writer path to grow `folders` exists, so this plan documents the
  gap as a caveat with an operator remedy rather than silently presenting capture-enablement as
  working capture (see Non-Goals and Phase 5).
- **`sapience projects off <path>` works after the directory has vanished.** `set_project()`
  matches an existing entry by string-equal `path_prefix` with no `isdir` check on the lookup
  path, and `normalize()`/`is_project_root()` never drop an entry for not existing on disk -- so a
  vanished project stays `enabled: true` indefinitely unless something turns it off. That makes
  the capture reap sweep in Phase 2 both warranted and mechanically safe.

Research question 4 (`deny_reason()`) resolves to an edge case rather than a design constraint: an
ordinary git checkout root will essentially never be refused, but a `set_project` -> `None` result
must still degrade silently. Research question 5 is carried as a Non-Goal: the companion
`~/.dotfiles` copy is byte-identical today and needs a mirrored edit that cannot be made from this
repository.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class claim in the dispatch description was checked against the research report and
against live state this dispatch. All hold; none required correction:

| Claim | Verdict |
|-------|---------|
| The hook already registers/removes the per-project MCP entry from `.extensions.sapience.status` | **Confirmed** -- `sapience-mcp-register-project.sh`, the `HAVE_PROJECT` branch (`IS_ACTIVE` -> `--scope project`; inactive + existing entry -> `--remove`) |
| A shared worktree-aware `resolve_checkout_toplevel()` block exists | **Confirmed** -- marker-delimited block in the hook, documented byte-identical across five copies with a lockstep test case |
| The hook preserves always-exit-0 / exactly-one-JSON-line | **Confirmed** -- `NOTICES` array joined by a single `jq -cRs` at the end, `exit 0` on every path |
| `projects_cli` ends with `capture_sync()` | **Confirmed** -- research finding 2; the `SAPIENCE_NO_CAPTURE_SYNC` guard is present at `~/.sapience/upload.py:1023` live |
| `per-repo-scoping.md`'s "Capture/Activation Reconciliation" currently rules this extension must NOT write `capture.projects[].enabled`, and that coupling belongs in `~/.dotfiles` | **Confirmed** -- that subsection says exactly this, giving two reasons (new unreviewed surface; a second independent writer) |
| `verify-sapience-mcp.sh` check (i) exists and treats active + not-enabled as informational, "never a failure" | **Confirmed** -- check (i) with a four-outcome table and an inline RECONCILIATION RULING comment repeating the doc's ruling |
| Edit target is the sapience extension source store (`agent-system/extensions/sapience`) | **Confirmed** -- that tree exists here and the deploy-freshness notice flags it stale, consistent with a source-store edit target |
| `sapience` binary is available for the vendor-CLI call | **Confirmed live** -- `/home/benjamin/.nix-profile/bin/sapience`, whose `projects)` arm `exec`s `extract_local.py --projects "$@"` |

One premise the description does **not** state, surfaced here because it changes an
implementation detail: `.claude-extensions.json` is a **tracked** file in this repository, so a
linked worktree carries its own copy at the worktree root. The hook's first project-detection
branch (`[ -f ".claude-extensions.json" ]` -> `PROJECT_PATH="$(pwd)"`) therefore resolves to the
**worktree** path, not the parent checkout, in exactly the case the dispatch requires the capture
call to key on the parent checkout. The capture call must use `resolve_checkout_toplevel()`'s own
output rather than reusing `PROJECT_PATH` -- see Decisions and Phase 3's Scope Hypothesis.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation was
performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Couple `capture.projects[].enabled` bidirectionally to `.extensions.sapience.status`, from the
  same two hook branches that already register/remove the MCP entry.
- Write that field **only** via `sapience projects on|off <path>`, never by editing
  `~/.sapience/config.json` -- the vendor client stays the sole writer, under its own lock, and the
  coupling survives vendor auto-update.
- Key the call on the parent checkout via `resolve_checkout_toplevel()`, so a linked worktree
  enables its checkout rather than itself.
- Keep the call idempotent and silent in steady state: act, and emit an `additionalContext`
  notice, only when the real `capture.projects[]` state differs from the extension state.
- Preserve the hook's always-exit-0 / exactly-one-JSON-line contract and its silent-degrade
  posture when `sapience`, `jq`, the writer, or `~/.sapience/config.json` is absent.
- Extend the existing vanished-directory reap discipline to capture, so an orphaned
  `enabled: true` entry is turned off by some other living session.
- Bring `verify-sapience-mcp.sh` check (i) and `per-repo-scoping.md` into line with the new design,
  including why routing through the vendor CLI removes the two-writers hazard.
- Cover on, off, steady-state-silent, missing-binary, and worktree cases with fixture-HOME tests
  against a PATH-shadowed `sapience` stub.

**Non-Goals**:

- **Reconciling the legacy top-level `folders` list.** No safe, non-interactive, single-writer
  vendor-CLI path to grow it exists (the onboarding chooser refuses without a TTY and, under
  `SAPIENCE_ALLOW_ONBOARD=1`, overwrites the entire saved selection). This plan documents the
  double-gate and names the operator remedy; it does not automate it, and it does not hand-edit
  `folders`.
- **Mirroring the edit into `~/.dotfiles`.** `~/.dotfiles/.claude/hooks/sapience-mcp-register-project.sh`
  is byte-identical to this source store's copy today and will diverge the moment Phase 3 lands.
  That repository is a different git repository, and per
  `rules/source-store-deploy-boundary.md`'s task-siting rule a task whose edit target is a
  source-store path must be created in the repository holding that path on disk. Phase 6 records
  this as an explicit operator follow-up; this task does not perform or commit it.
- **Running the acceptance test.** The dispatch frames it as operator-run. Phase 6 verifies the
  installer would copy the updated files (`--dry-run`) and names the operator's own steps; it does
  not install to `~/.claude/` or restart a session in `sf1-engine`.
- **Changing how the MCP-registration half keys its entry.** The `PROJECT_PATH` divergence noted
  above is handled by giving the capture call its own resolution, not by altering existing
  registration behavior.
- **Scheduling extraction.** `services.sapience.backgroundSync` remains `~/.dotfiles`-owned and
  defaults to `false`; enabling capture does not cause extraction to run.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A slow or hung vendor call delays every session start in every repo with the extension active | H | M | `SAPIENCE_NO_CAPTURE_SYNC=1` removes the network dependency entirely; an outer `timeout 15` bounds the rest. 15s sits deliberately *below* the ~16s two-call network worst case, so if a future vendor version drops the env guard the outer timeout still fires rather than letting session start absorb the full wait |
| `capture.projects[].enabled == true` read as "capture works" while `folders` has not grown to match | M | H | Phase 5 documents the double-gate in `per-repo-scoping.md` and the hook header, with the operator remedy; Phase 4's amended check (i) text names it |
| A future vendor update changes `projects_cli` (writes `folders` itself, or drops the `SAPIENCE_NO_CAPTURE_SYNC` guard) | M | L | None available -- the file is vendor-owned and auto-updating. The silent-degrade contract absorbs an erroring or timing-out call; the sub-worst-case timeout above absorbs a dropped guard |
| Growing the already-dense hook with a third concern | M | M | The coupling lives in the writer; the hook gains two `bash "$WRITER"` invocations in its existing style and no new logic of its own (see Decisions) |
| Idempotence decided from a longest-prefix match would mis-skip a child repo under an enabled parent | M | M | The idempotence decision reads the **exact-path** entry, matching what `set_project()` actually writes; the longest-prefix match stays the verifier's (reporting) concern (see Decisions) |
| `set_project()` returns `None` (checkout root is `$HOME`, or a TCC-denied top-level folder) | L | L | Notice is emitted only when a post-call re-read shows the state actually changed, so a refused call is silently truthful regardless of the CLI's exit convention |
| New test cases regress the 1264-line existing suite | M | L | Every phase runs the whole suite, not only its own cases; cases are appended with new numbers rather than renumbering existing ones |
| A sibling task's concurrent edit on this shared working tree | M | M | Three siblings are dispatched this cycle with undeclared `file_scope`. Re-read every file immediately before editing; stage only this task's own files by explicit path; never run `git-snapshot.sh` in its reverting default mode |

## Decisions

1. **The coupling lives in `setup-sapience-mcp.sh`, not in a new installed script and not inline in
   the hook.** The hook already resolves that writer from the stable user-level path
   `$HOME/.claude/scripts/setup-sapience-mcp.sh`, which
   `install-sapience-mcp-session-hook.sh` already seeds alongside the hook (confirmed live: the
   installer's `WRITER_SRC`/`WRITER_DST` pair). Extending it therefore needs **no installer
   change**, **no `manifest.json` `provides.scripts` change**, and keeps exactly one implementation
   of the capture-state query plus one invocation site for the vendor CLI. A new installed script
   would instead have added installer surface, an installer `--remove` path, installer idempotence,
   and a verifier presence check. Accepted trade-off: the script's name understates its scope; its
   header already documents two other standalone cross-cutting actions (`--retire-global`,
   `--reap`), and the new ones are documented the same way.
2. **The idempotence decision reads the exact-path entry, not the longest-prefix match.** The
   research recommendation to mirror check (i)'s longest-prefix logic is right for *reporting* but
   subtly wrong for *writing*: `set_project()` matches and creates an entry keyed on the exact
   realpath'd path, so the exact-path entry is the only state an `on`/`off` call changes. Deciding
   from a parent-prefix match would make a child repo under an enabled parent never get its own
   entry. Both paths are compared in realpath'd form, since `set_project()` normalizes its key.
3. **The capture call keys on `resolve_checkout_toplevel()`'s output, not on the hook's existing
   `PROJECT_PATH`.** `.claude-extensions.json` is tracked, so inside a linked worktree the hook's
   first detection branch sets `PROJECT_PATH` to the worktree. Using it would enable the worktree,
   contradicting the dispatch's explicit requirement. The capture call therefore uses `GIT_ROOT`
   when non-empty and falls back to `PROJECT_PATH` only outside a git repository. Existing MCP
   registration keying is left exactly as it is.
4. **`--reap-capture` is a separate action from `--reap`.** `setup-sapience-mcp.sh`'s own
   convention is one purpose per standalone action, and the two reaps read different files
   (`~/.claude.json` vs `~/.sapience/config.json`) with different failure modes. Keeping them
   separate also lets the hook degrade on one without losing the other.
5. **Check (i)'s active + not-enabled outcome becomes a WARN, not a FAIL.** A hard failure would
   fire on every legitimate one-session-start lag and on every silent, expected non-write (absent
   `sapience` binary, timeout). The research pass explicitly left this a plan-level judgment call.
6. **The `folders` gap is documented, not automated.** Stated as a Non-Goal above, carried into
   `per-repo-scoping.md` and the hook header in Phase 5, and surfaced to the operator in Phase 6.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4 | 3 |
| 5 | 5 | 3, 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential: Phases 1-2
build on each other's shared helpers in one file, and Phases 3-4 both append cases to the single
`test-sapience-mcp-registration.sh` suite, so serializing them avoids same-file contention.

### Phase 1: Writer-Side `--capture-set` Action [COMPLETED]

**Goal**: `setup-sapience-mcp.sh` gains an idempotent, silent-in-steady-state
`--capture-set on|off --project PATH` action that is the single place the vendor capture CLI is
invoked, plus the two helpers the next phase reuses -- with its own fixture test cases.

**Tasks**:
- [x] Re-read `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` immediately before
      editing (three concurrent siblings on this working tree have undeclared scope). *(completed)*
- [x] Add `sapience_cli VERB PATH`: resolve the binary with `command -v sapience`, return non-zero
      silently when absent, and otherwise invoke
      `SAPIENCE_NO_CAPTURE_SYNC=1 timeout 15 sapience projects "$VERB" "$PATH"` with stdout and
      stderr captured, never leaked. Record the 15s choice and its sub-worst-case rationale in a
      comment. *(completed)*
- [x] Add `capture_state_for_path PATH`: realpath-normalize the argument (`realpath`/`readlink -f`,
      falling back to the raw value), read `$SAPIENCE_CONFIG`, and echo `enabled`, `disabled`, or
      `absent` for the **exact-path** `capture.projects[]` entry. Return non-zero silently when
      the file is unreadable or carries no `capture` key. Comment the exact-path-vs-longest-prefix
      choice, pointing at check (i) as the reporting-side counterpart. *(completed)*
- [x] Add the `--capture-set VALUE` flag (`on`|`off`, validated with a loud error on any other
      value, matching the existing `--scope` validation shape) to the argument loop and to the
      header/`--help` usage block. *(completed)*
- [x] Implement the action as a standalone branch placed beside `--retire-global`/`--reap` --
      above `PROJECT_PATH`/`SCOPE` resolution and above `resolve_interpreter`'s hard `exit 1`,
      for the same reason that placement comment already gives: no interpreter is needed. *(completed)*
- [x] Action body: resolve the target path (`--project`, default `pwd`); read the current exact-path
      state; exit 0 silently when it already matches the requested value; otherwise call
      `sapience_cli`, then **re-read** the state and emit the one-line `--quiet` notice only when
      it actually changed. Exit 0 on every path, including a nonzero CLI exit, a timeout, an absent
      binary, and a `set_project` -> `None` refusal. *(completed)*
- [x] Support `--dry-run` for the new action: report the transition it would make and mutate
      nothing. *(completed)*
- [x] Append writer-level cases to
      `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`, using the
      existing `mktemp -d` fixture-HOME convention and a PATH-shadowed recording `sapience` stub
      modelled on `test-sapience-capture.sh`'s `build_curl_stub`: (a) `on` with no existing entry
      invokes the stub with `projects on <path>` and `SAPIENCE_NO_CAPTURE_SYNC=1` in its
      environment; (b) `off` against an `enabled: true` entry invokes `projects off <path>`;
      (c) steady state (`on` against an already-enabled exact entry) records no stub invocation and
      prints nothing; (d) no stub on `PATH` at all exits 0 silently; (e) an enabled **parent**
      prefix with no exact entry for the child still invokes `on` for the child (the exact-path
      decision from Decisions 2); (f) `--dry-run` records no stub invocation. *(completed: cases 56-61)*
- [x] Run the full suite and confirm the pre-existing cases still pass alongside the new ones. *(completed: 64 passed, 0 failed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` -- the selector maps this phase's touched set to `test-sapience-mcp-registration.sh` and `test-sapience-publish.sh`, which together cover the writer and its suite, and the change is additive new actions with no change to any existing action's interface.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` - add the sapience_cli and capture_state_for_path helpers plus the capture-set flag and its standalone action branch; extend the header and help usage
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - append the six writer-level capture-set cases and the sapience stub builder

**Verification**:
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` exits 0 with the new cases reported PASS and no previously-passing case regressed.
- `bash -n agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` parses clean.
- `bash agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh --help` lists `--capture-set`.
- The scoped narrowing invocation named in the Tier Justification above runs green.

---

### Phase 2: Writer-Side `--reap-capture` Sweep [NOT STARTED]

**Goal**: a vanished project directory whose `capture.projects[]` entry is still `enabled: true`
is turned off by any living session, mirroring the MCP-registration reap this writer already owns.

**Tasks**:
- [ ] Re-read `setup-sapience-mcp.sh` immediately before editing.
- [ ] Add the `--reap-capture` flag and a `process_reap_capture()` function placed beside
      `process_reap()`, before `PROJECT_PATH`/`SCOPE` resolution and before `resolve_interpreter`.
- [ ] Enumerate `capture.projects[]` entries whose `enabled` is `true` and whose `path_prefix` is
      not a directory on disk; call `sapience_cli off "$path_prefix"` for each, reusing Phase 1's
      helper unchanged.
- [ ] Degrade silently and exit 0 when `~/.sapience/config.json` is unreadable, carries no
      `capture` key, or the `sapience` binary is absent; support `--dry-run`; under `--quiet` emit
      one line per entry actually turned off, matching `process_reap()`'s convention.
- [ ] Document, in the header beside `--reap`'s existing two-edge-case note, that an unreadable or
      unmounted path reads as absent via `[ ! -d ]` and is turned off as if orphaned -- accepted
      because the next session start in that repo re-enables it via the register branch.
- [ ] Append writer-level cases: (a) a vanished `enabled: true` entry is turned off (stub invoked
      with `projects off <vanished-path>`) while a sibling entry whose path exists is left
      untouched in the same fixture and invocation; (b) a vanished entry already `enabled: false`
      records no stub invocation; (c) `--reap-capture --dry-run` records no stub invocation;
      (d) no `sapience` on `PATH` exits 0 silently.
- [ ] Run the full suite.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` -- same single-writer-plus-its-suite touched set as Phase 1, mapping to `test-sapience-mcp-registration.sh` and `test-sapience-publish.sh`; the new action is additive and reuses Phase 1's already-tested helper.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` - add the reap-capture flag and its process_reap_capture function plus the header and usage entries
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - append the four reap-capture cases

**Verification**:
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` exits 0.
- `bash agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh --reap-capture --dry-run` against the live `$HOME` reports only what it would change and mutates nothing (`md5sum` of `~/.sapience/config.json` unchanged before and after).
- The scoped narrowing invocation named in the Tier Justification above runs green.

---

### Phase 3: Hook Wiring and Caveat Documentation [NOT STARTED]

**Goal**: the `SessionStart` hook couples capture in both of its existing branches and in its
ungated reap pass, keying on the parent checkout, with its contract and its documented caveats
intact.

**Tasks**:
- [ ] Re-read `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh`
      immediately before editing.
- [ ] Confirm the parent-checkout hypothesis below before wiring: inside a linked worktree that
      carries its own tracked `.claude-extensions.json`, check whether the hook's existing
      `PROJECT_PATH` resolves to the worktree or the checkout, and record the observed result in
      the commit message. Wire the capture call to `GIT_ROOT` when non-empty, falling back to
      `PROJECT_PATH` only when the directory is not inside a git repository, regardless of that
      result. Do **not** change how the MCP-registration half keys its own entry.
- [ ] In the ungated reap section, after the existing `--reap` invocation, add a second
      `bash "$WRITER" --reap-capture --quiet` invocation, capturing output and rc the same way,
      and contributing its own distinct notice string on a nonzero-output success.
- [ ] In the `HAVE_PROJECT` half, add one `bash "$WRITER" --capture-set on|off --project
      "$CAPTURE_PATH" --quiet` invocation, choosing the verb from the already-computed `IS_ACTIVE`,
      capturing output and rc, and contributing a notice only on a nonzero-output success.
- [ ] Keep every existing contract intact: the `NOTICES` array still joins into exactly one JSON
      line, every path still `exit 0`, and a nonzero writer rc or empty output still degrades
      silently with no notice.
- [ ] Extend the header comment block with: the capture-coupling mechanism and why it routes
      through the vendor CLI; the one-session-start lag (now applying to capture as well as MCP
      registration); that the first `sapience sync` after an enable backfills the configured `days`
      window; that `off` is not retroactive for already-posted knowledge objects; and the
      `folders` double-gate, naming it as the reason an `enabled` entry is not by itself working
      capture.
- [ ] Append hook-level cases: (a) active repo emits a capture notice and the stub records
      `projects on <checkout>`; (b) inactive repo with an `enabled: true` entry records
      `projects off <checkout>` and emits a notice; (c) steady state records no stub invocation and
      the hook prints `{}`; (d) no `sapience` on `PATH` prints `{}` and exits 0 with the
      MCP-registration half still working; (e) invoked from inside a linked worktree, the stub
      receives the **parent checkout** path and no worktree-keyed capture entry appears;
      (f) a session with both an orphaned capture entry and an active current repo emits exactly
      one parseable JSON line mentioning both actions.
- [ ] Run the full suite.

**Timing**: 2 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: this phase assumes the hook's existing `PROJECT_PATH` resolves to the
*worktree*, not the parent checkout, when invoked from inside a linked worktree carrying its own
tracked `.claude-extensions.json` -- inferred from `.claude-extensions.json` being tracked plus
the hook's `[ -f ".claude-extensions.json" ]` -> `PROJECT_PATH="$(pwd)"` branch, not measured.
The implementer confirms it by running the hook from a fixture worktree that carries the manifest
and observing which path the MCP-registration half keys on. The wiring decision does not depend on
the answer (the capture call keys on `GIT_ROOT` either way); only whether a *separate* follow-up
is warranted for the registration half does, and that follow-up is recorded, never performed here.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` -- the selector maps this phase's touched set to `test-sapience-mcp-registration.sh` and `test-sapience-publish.sh`; the hook is a leaf consumer invoked only by `SessionStart` and is covered end-to-end by that suite's hook cases.

**Files to modify**:
- `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` - add the reap-capture and capture-set writer invocations with GIT_ROOT-based capture path resolution; add their notices and the extended header caveats
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - append the six hook-level capture cases

**Verification**:
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` exits 0, including the pre-existing worktree cases (25)-(30) and the lockstep guard.
- Every new hook case asserts the output is exactly one line and parses as JSON (`jq -e . <<< "$out"`), matching the existing case (15) convention.
- `bash -n` on the hook parses clean.
- The scoped narrowing invocation named in the Tier Justification above runs green.

---

### Phase 4: Verifier Check (i) Update [NOT STARTED]

**Goal**: check (i) stops asserting that this source store never writes
`capture.projects[].enabled`, and reports an active-but-not-enabled repo as a lag-tolerant WARN
instead of a bare informational line.

**Tasks**:
- [ ] Re-read `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` immediately before
      editing.
- [ ] Replace the inline RECONCILIATION RULING comment block above check (i) with the new design:
      this source store now writes the field, exclusively via `sapience projects on|off` invoked
      from `setup-sapience-mcp.sh`'s `--capture-set`/`--reap-capture` actions, so the extension is
      a caller of the vendor's single writer rather than a second independent writer. Point at
      `per-repo-scoping.md` for the full argument rather than restating it.
- [ ] Change the active + not-enabled-or-absent outcome from informational to a WARN that names
      the three legitimate causes -- the one-session-start lag, a silently-degraded hook (absent
      `sapience` binary, timeout), and the `folders` double-gate -- and does **not** set
      `OVERALL_OK=false`. Use the file's existing reporting helper for warnings if one exists;
      otherwise emit via `log` with an explicit `WARN` prefix and state in a comment that this is
      deliberately not a failure.
- [ ] Leave the inactive + enabled FAIL, the active + enabled PASS, the inactive + not-enabled
      silence, and the longest-prefix match rule exactly as they are -- the match rule stays the
      reporting-side counterpart to Phase 1's exact-path write decision, and the comment says so.
- [ ] Amend the existing check (i) cases (45) and (46) to assert the new WARN text and a still-zero
      exit, and add one case asserting the resolved-entry name still appears in the WARN line.
      Leave cases (44) and (47) asserting unchanged behavior.
- [ ] Run the full suite.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` -- the selector maps this phase's touched set to `test-sapience-mcp-registration.sh` and `test-sapience-publish.sh`; the verifier is a standalone diagnostic with no in-repo callers, and its check (i) cases (44)-(47) live in that suite.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` - rewrite check (i)'s ruling comment and change the active + not-enabled outcome to a non-failing WARN
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - amend cases (45) and (46) and add one WARN-text case

**Verification**:
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` exits 0.
- `bash agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` run against this repository reports check (i) with its current live state (this repo is active and capture-enabled, so a PASS) and the run's exit status is unchanged from before the edit.
- The scoped narrowing invocation named in the Tier Justification above runs green.

---

### Phase 5: Documentation -- Reconciliation Rewrite and the `folders` Double-Gate [NOT STARTED]

**Goal**: `per-repo-scoping.md` states the new design, why routing through the vendor CLI removes
the two-writers hazard, and the `folders` double-gate that the new design does not resolve.

**Tasks**:
- [ ] Re-read `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
      immediately before editing. Its "Capture/Activation Reconciliation" subsection was confirmed
      present this dispatch; if it is absent at implementation time (a sibling edit), stop and
      report rather than inventing a replacement target.
- [ ] Rewrite that subsection to state: the `SessionStart` hook now couples
      `capture.projects[].enabled` to `.extensions.sapience.status` in both directions; the write
      goes exclusively through `sapience projects on|off`, invoked from
      `setup-sapience-mcp.sh`'s `--capture-set` and `--reap-capture` actions; the vendor client
      therefore remains the sole writer of `~/.sapience/config.json`'s `capture` key under its own
      lock, so this extension is a well-behaved **caller** of that single writer rather than a
      second independent one -- exactly mirroring how `setup-sapience-mcp.sh` is already the sole
      writer of `~/.claude.json`. State that this removes the two-writers hazard the prior ruling
      rested on, rather than overriding that reasoning by fiat.
- [ ] In the same subsection, record the three caveats: the one-session-start lag; that the first
      `sapience sync` after an enable backfills the configured `days` window; and that `off` is not
      retroactive for knowledge objects already posted.
- [ ] Add a short new subsection documenting the double-gate: `folders` gates which transcript
      directories are scanned at all (`_session_candidates()`'s `f.parent.name in chosen` filter,
      and `sync()`'s bail when `folders == []`), evaluated **before** `capture.projects[]` is
      consulted; `sapience projects on` never touches it; there is no safe non-interactive
      single-writer path to grow it; and the operator remedy is one interactive run of the vendor's
      own onboarding chooser from a terminal. State plainly that an `enabled: true` capture entry
      is therefore not by itself evidence that transcripts are being read.
- [ ] Cross-reference the new subsection from "Capture Scheduling and the Manual-Only Trigger",
      which already names `~/.dotfiles` as the scheduling owner.
- [ ] Update `agent-system/extensions/sapience/index-entries.json`'s `line_count` for
      `project/sapience/domain/per-repo-scoping.md` (currently `410`, matching the file's live
      length) to the file's new length, since this phase moves that derived quantity.
- [ ] Observe the deliverable-file rules while writing: no task-number references
      (`rules/no-task-references-in-deliverables.md`) and no record-versioning language
      (`rules/no-record-versioning-in-deliverables.md`) -- state the current design directly rather
      than narrating that a prior ruling was superseded.

**Timing**: 1 hour

**Depends on**: 3, 4

**Verification Tier**: local

**Scope Hypothesis**: `index-entries.json` currently records `line_count=410` for this file,
matching its live length, so this is the one derived quantity this phase moves. The implementer
confirms by re-reading both values before and after the edit, and by checking that no other
`index-entries.json` field for this path (keywords, topics, `load_when`) needs to change for the
new subsection.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md agent-system/extensions/sapience/index-entries.json` -- the selector maps this phase's touched set to `test-context-reachability.sh`, `test-deploy-orphans.sh`, `test-index-entries-schema.sh`, `test-install-uninstall-extension.sh`, `test-manifest-scripts-sync.sh`, and `test-roadmap-command-registration.sh`, which together cover the index-entry schema and the context file's reachability; the edit is prose plus one numeric field with no executable surface.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - rewrite the "Capture/Activation Reconciliation" subsection (confirmed present) and add the `folders` double-gate subsection
- `agent-system/extensions/sapience/index-entries.json` - update the `line_count` this phase's prose edit moves for `project/sapience/domain/per-repo-scoping.md`

**Verification**:
- The scoped narrowing invocation named in the Tier Justification above runs green.
- `bash .claude/scripts/check-task-references.sh` (or the repo-wide lint's equivalent entry point) reports no new occurrence for the edited file.
- `jq -e '.' agent-system/extensions/sapience/index-entries.json` parses, and the `line_count` for the edited path equals `wc -l` of that file.
- The rewritten subsection names the vendor CLI as the sole writer and carries all four caveats (lag, backfill, non-retroactive `off`, `folders`).

---

### Phase 6: Redeploy, Scoped Verification, and Operator Handoff [NOT STARTED]

**Goal**: the deployed tree carries the change, the touched paths verify green, and the two
operator-owned follow-ups are recorded explicitly rather than implied.

**Tasks**:
- [ ] Run `timeout 540 bash .claude/scripts/deploy-headless.sh` (Bash tool `timeout` parameter
      raised to 600000, per `context/patterns/external-process-wait.md` Rule 1) to clear the
      sapience staleness this dispatch's deploy-freshness notice reported and to converge any
      remaining generated index values.
- [ ] Run the scoped touched-path check over every path this task modified, and state explicitly
      that the complete gate set is deferred to the orchestration close
      (`context/contracts/batch-gate-stage.md`), not run independently here.
- [ ] Run `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`
      once more against the final state of all five edited files.
- [ ] Run `bash .claude/scripts/install-sapience-mcp-session-hook.sh --dry-run` and confirm it
      reports it would copy the updated hook and writer to `$HOME/.claude/{hooks,scripts}/`. Do
      **not** run it for real: it mutates user-level state affecting every repository on this
      machine at next session start, and the acceptance test is operator-run.
- [ ] Record the two operator-owned follow-ups in the task's durable record (its description in
      `specs/state.json`, or a file under this task's `records/` directory -- never an
      orchestration sidecar): (1) run `install-sapience-mcp-session-hook.sh` to refresh the
      user-level hook and writer, then exercise the acceptance test in
      `/home/benjamin/Projects/Sapience/sf1-engine`; (2) file a task in `~/.dotfiles` to mirror
      this diff into that repository's own copies of the hook and the writer, restoring the
      byte-identity confirmed broken by Phase 3.
- [ ] Note in the same record that `/home/benjamin/Projects/Sapience/sf1-engine` is in neither
      `capture.projects[]` nor `folders` today, so the acceptance test will show it as `enabled`
      while its transcripts stay ungated by `folders` until the operator runs the onboarding
      chooser once.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`
- `specs/683_couple_sapience_capture_to_extension_activation/records/operator-followups.md` - the durable record of the two operator-owned follow-ups (created by this phase)

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes and a re-run of the staleness probe no longer reports `sapience` stale.
- Scoped touched-path check, run as this phase's own in-dispatch obligation:
  `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md agent-system/extensions/sapience/index-entries.json`
  runs green.
- The complete gate set is **deferred to the orchestration close** per
  `context/contracts/batch-gate-stage.md`; this phase does not invoke the full battery itself.
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` exits 0.
- `bash .claude/scripts/install-sapience-mcp-session-hook.sh --dry-run` exits 0 and names both
  files it would refresh.
- The operator-followups record exists and names both follow-ups and the `folders` caveat.

---

## Testing & Validation

- [ ] `test-sapience-mcp-registration.sh` exits 0 with every pre-existing case still passing and
      every new case reported PASS.
- [ ] Writer: `--capture-set on`/`off` invoke the stub with `projects on|off <path>` and
      `SAPIENCE_NO_CAPTURE_SYNC=1` in the environment.
- [ ] Writer: steady state, `--dry-run`, and an absent `sapience` binary each record no stub
      invocation and exit 0 silently.
- [ ] Writer: an enabled parent prefix with no exact child entry still triggers an `on` for the
      child (the exact-path decision).
- [ ] Writer: `--reap-capture` turns off a vanished `enabled: true` entry and leaves a sibling
      whose path exists untouched in the same fixture.
- [ ] Hook: active -> `on`, inactive-with-entry -> `off`, steady state -> `{}`, missing binary ->
      `{}`, and a linked-worktree invocation passes the **parent checkout** path.
- [ ] Hook: every invocation emits exactly one line that parses as JSON, including the case where
      both the capture reap and the per-repo half have something to report.
- [ ] Verifier: check (i) reports active + not-enabled as a non-failing WARN naming the lag, the
      silent-degrade causes, and the `folders` gate; the inactive + enabled FAIL is unchanged.
- [ ] `index-entries.json` parses and its `line_count` for the edited context file matches `wc -l`.
- [ ] No task-number references and no record-versioning language in the edited deliverables.
- [ ] Operator-run, outside this task: with the extension loaded in
      `/home/benjamin/Projects/Sapience/sf1-engine` and the installer re-run, the next session start
      there shows `sf1-engine` as `enabled` in `sapience projects`, and unloading the extension
      turns it off at the following session start.

## Artifacts & Outputs

- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` - `--capture-set on|off` and
  `--reap-capture` actions, plus the `sapience_cli` and `capture_state_for_path` helpers
- `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` - bidirectional capture
  coupling in both branches, capture reap in the ungated pass, extended header caveats
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` - check (i) rewritten ruling
  comment and lag-tolerant WARN
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - new writer,
  reap, and hook capture cases plus the `sapience` stub builder
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - rewritten
  reconciliation subsection and the new `folders` double-gate subsection
- `agent-system/extensions/sapience/index-entries.json` - updated `line_count` for the edited
  context file
- `specs/683_couple_sapience_capture_to_extension_activation/records/operator-followups.md` - the
  two operator-owned follow-ups and the `folders` caveat
- `specs/683_couple_sapience_capture_to_extension_activation/summaries/01_capture-activation-coupling-summary.md` -
  implementation summary

## Rollback/Contingency

Every phase is a self-contained commit on five files in one extension's source store, so reverting
is a `git revert` of the phase commits in reverse order -- no schema migration, no state mutation,
and nothing written outside the repository by any agent-run step.

- **Partial landing**: the hook degrades silently whenever the writer errors or the `sapience`
  binary is absent, so a half-landed change (writer actions present, hook not yet wired, or the
  reverse) is a no-op at session start rather than a broken session. There is no intermediate state
  in which a session start fails.
- **Live state**: no agent-run step in this plan writes `~/.sapience/config.json` or
  `~/.claude/`. Every test runs against a `mktemp -d` fixture `HOME` with a PATH-shadowed stub, and
  the only live invocations are `--dry-run` ones. Reverting the commits therefore restores the prior
  behavior completely at the next session start, with no residue to clean up.
- **If the vendor CLI misbehaves in the operator acceptance test**: revert Phase 3's hook commit
  alone. The writer's new actions become unreachable from the session path while remaining
  available for manual diagnosis, and the hook returns to MCP-registration-only behavior.
- **Undoing a wrongly-enabled repo**: `sapience projects off <path>`, the same single-writer path
  this plan uses throughout.
- **If a destructive rollback of uncommitted work becomes necessary**: follow
  `context/contracts/recovery.md`'s rollback rung for the snapshot-then-rollback invocation shape,
  including its out-of-scope override flag. Do not emit a bare reverting `git-snapshot.sh` as a
  precaution, and never run it in its reverting default mode while sibling tasks share this
  working tree.
