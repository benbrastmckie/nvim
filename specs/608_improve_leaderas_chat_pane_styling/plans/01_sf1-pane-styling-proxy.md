# Implementation Plan: Task #608

- **Task**: 608 - Improve chat pane styling for `<leader>as` to match Claude Code's appearance, with blank lines or divider lines between message parts so they don't run together
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/608_improve_leaderas_chat_pane_styling/reports/01_chat-pane-styling-scope.md
- **Artifacts**: plans/01_sf1-pane-styling-proxy.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

Build a PTY-proxying wrapper, owned and versioned inside this repository at
`lua/neotex/plugins/ai/sapience/`, that launches `sf1` under its own pseudo-terminal and
rewrites the output byte stream to insert a separator (a blank line by default, optionally a dim
rule) at the three message-part boundaries where sf1 currently prints nothing. `init.lua`'s
command construction is extended to invoke the proxy in place of the bare `sf1` string, with a
graceful fallback to the current unstyled behavior whenever the proxy or `python3` is
unavailable. Nothing outside this repository is edited, and the vendor payload
`~/.sapience/sf1.py` is never written to, so the fix cannot be lost to the vendor's daily
auto-update.

### Research Integration

The research report's Findings 1-3 are load-bearing for this plan and are integrated as follows:

- **Finding 1** (this repo's three sf1 files are pure window-placement code) is why the fix must
  add a new process layer rather than extend `terminal.lua`: there is no existing point in the
  Lua chain that sees sf1's bytes.
- **Finding 2** (sf1 is untracked, auto-updating vendor payload) is why the proxy must be
  *pattern-matching and degrading*, never patch-applying: an output-format change must produce
  "no dividers" rather than a crash or a corrupted pane.
- **Finding 3** (sf1's output is a strictly append-only line stream; the only cursor
  repositioning is the transient `\r\033[2K` status indicator on stderr, explicitly cleared
  before any stdout write) is the feasibility result the whole approach rests on: inserting
  newlines into the stream is not fighting an in-place redraw. The proxy must nonetheless
  suppress injection while that transient indicator is live.
- **Finding 5, option (b)** is the route the user selected (recorded in
  `.decisions.json`, cycle 1), including its own stated risk profile: text-pattern matching on
  another program's literal output.
- **Recommendation 2** (document the literal markers in the module's own comments) is discharged
  by Phase 1's marker-contract docblock, which is a required deliverable of that phase, not a
  nicety.
- **Recommendation 4** (re-verify the anchor points against a freshly-read `~/.sapience/sf1.py`
  at implementation time, not against the report's line numbers) is Phase 1's first task.

Marker facts re-verified against the live `~/.sapience/sf1.py` during this planning pass
(mtime 2026-11-03, 653 lines), which the implementer must re-confirm again before coding:

| Boundary | Marker | Stream | Shape |
|---|---|---|---|
| Handoff banner | `picked up: ...` | stderr | green- or yellow-wrapped, newline-terminated (`Session.start`) |
| Startup banner | `sf1 {ver} on {host}. /help for commands, Ctrl-D to quit.` | stderr | dim, newline-terminated (`main`) |
| Turn prompt | `sf1 > ` / `sf1/{project} > ` | stdout | **plain, deliberately never colored** (documented in `_prompt`'s own docstring), no trailing newline |
| Sources line | `sources: [n] subject  ...` | stdout | dim, newline-terminated (`Session.ask`) |
| Transient status | `\r\033[2K` + dim text | stderr | cleared with a second `\r\033[2K` before any stdout write |

A single pty merges sf1's stdout and stderr into one stream, so the proxy filters one stream, not
two.

### Prior Plan Reference

No prior plan. This is the task's first plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch context, so no roadmap consultation was
performed and this plan advances no recorded roadmap item.

## Goals & Non-Goals

**Goals**:

- `<leader>as` opens a chat pane in which the handoff banner, each user question, each streamed
  answer, the `sources:` line, and the next prompt are visually separated instead of running
  together.
- The separator style is configurable (blank line, or a dim horizontal rule) through the existing
  `setup()` opts surface, honoring the same color-suppression environment variables sf1 itself
  honors.
- The entire fix is contained in `lua/neotex/plugins/ai/sapience/`, is git-tracked in this
  repository, and survives any `~/.sapience` auto-update because it never writes to that
  directory.
- If the proxy cannot run (no `python3`, missing script, pty allocation failure) or sf1's output
  format changes, `<leader>as` still opens a fully working sf1 session — unstyled, never broken.
- The `sapience/` directory keeps its existing dependency-free property: no `neotex.*` require is
  added beyond the single sanctioned `terminal.lua` require already present, and the proxy's path
  is derived self-relatively rather than from `stdpath('config')`.

**Non-Goals**:

- Editing `~/.sapience/sf1.py`, or anything else outside `/home/benjamin/.config/nvim` (research
  option (a) and (c), both rejected by the recorded decision).
- Reproducing Claude Code's full TUI chrome (boxed panels, status footer, syntax-highlighted diff
  blocks). The matched property is turn separation, which is what the task asks for.
- Adding sf1 to the `<C-CR>` two-stage AI tool picker, or touching `ai-tool-picker.lua` (ruled
  out by research Decision 2).
- Correcting the stale `<leader>as` doc comment at `lua/neotex/config/keymaps.lua:25` (research
  Decision 1 notes it as unrelated cosmetic drift; folding it in would widen this task's file
  scope for no benefit to its goal).
- Writing the sapience-extension context note the research report's Context Extension
  Recommendations propose — that is explicitly a separate task in a different source store.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A vendor update changes the prompt string, the `sources:` prefix, or the banner color codes, silently disabling separation | M | M | Pass-through-on-no-match is the design default: an unmatched stream is forwarded byte-for-byte, so the failure mode is "no dividers", never a broken pane. The marker contract is documented in the proxy's own docblock (Phase 1) so a future reader sees in one place what to re-check. |
| readline re-emits the prompt on every line edit (arrow key, backspace), which naive prompt matching would turn into a blank line per keystroke | H | H | Prompt matches count as "fresh" only when reached via a `\n` from the child and never via `\r`; a one-shot latch prevents a second injection for the same prompt. This is Phase 1's single most important unit-test target. |
| Injecting a newline while the transient `\r\033[2K` status indicator is live would leave a stray partial status line in the scrollback | M | M | The filter tracks indicator state and suppresses injection until the indicator is cleared; covered by a dedicated unit test in Phase 1. |
| A naive shell pipe would turn sf1's stdout into a non-tty, killing color and readline line editing | H | H (if built wrong) | Explicitly a pty, not a pipe: the child gets a real controlling terminal via `pty.openpty` + `setsid` + `TIOCSCTTY`, and the parent runs its own stdin in raw mode. Research Finding 5 names this exact trap. |
| The extra process layer swallows Ctrl-C/Ctrl-D, window resizes, or sf1's exit code, leaving a wedged snacks terminal | M | M | Raw-mode verbatim stdin forwarding, `SIGWINCH` -> `TIOCSWINSZ` propagation, and `waitpid`-derived exit status (`128 + signal` for a signal death) are all required deliverables of Phase 2, each with its own stub-child test. |
| Changing `_command()`'s output changes the snacks terminal identity key, orphaning a live terminal opened before a runtime `setup()` change | L | M | Documented in the README's Behavior Notes; a styling change takes effect for terminals opened after it, and the orphaned terminal remains usable and closable. No code mitigation is warranted for a same-session reconfiguration that does not occur in normal use. |
| `python3` is absent from `PATH` in the environment Neovim inherits | H | L | `vim.fn.executable("python3")` is checked in `_command()`; on failure the bare `sf1` string is returned and a single WARN notification is emitted. Verified present at planning time at `/home/benjamin/.nix-profile/bin/python3`, with `pty`/`termios`/`fcntl` importable. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel. Phase 3 is parallel with Phase 2 because it
depends only on the proxy's argv contract (fixed in Phase 1), not on the pty harness being
functional; the end-to-end check that needs both lands in Phase 4.

---

### Phase 1: Marker Contract and Pure Stream Filter [COMPLETED]

**Goal**: Establish the re-verified marker contract and implement the separator-insertion logic
as a pure, pty-free function over byte chunks, with unit tests covering the redraw and
transient-status hazards.

**Tasks**:

- [x] Re-read the live `~/.sapience/sf1.py` and re-confirm every row of the Research Integration
      marker table above: the `picked up:` write in `Session.start`, the startup banner in
      `main`, the `_prompt` format string and its documented plain-text (uncolored) property, the
      `sources:` write in `Session.ask`, and the `\r\033[2K` transient indicator. Record any
      divergence from the table in this phase's commit message and update the proxy's docblock to
      match what the file actually says, not what this plan says. *(completed: re-read sf1.py
      (653 lines, mtime 2026-11-03, unchanged) -- every row of the marker table confirmed
      byte-for-byte with no divergence)*
- [x] Create `lua/neotex/plugins/ai/sapience/sf1_proxy.py` with a module docblock that states, as
      its primary content, the marker contract: each literal string the filter keys on, which
      stream it arrives on, and the one-line consequence if the vendor changes it. *(completed)*
- [x] Implement a `SeparatorFilter` class with a single `feed(chunk: bytes) -> bytes` method and
      no I/O, no global state, and no pty dependency, holding: at-line-start state, a pending
      partial-line tail, transient-indicator-active state, and the one-shot
      already-injected-for-this-prompt latch. *(completed)*
- [x] Implement the three boundary rules: (B1) one separator after the newline that terminates
      the `picked up:` handoff line; (B2) one separator after the echoed newline that follows a
      user-submitted line, driven by a `note_submit()` call the harness makes when it forwards a
      CR/LF from stdin, so this boundary needs no output pattern matching at all; (B3) one
      separator immediately before a *fresh* prompt occurrence. *(completed)*
- [x] Implement the fresh-prompt discrimination rule: a prompt match is fresh only when the
      filter is at line start having arrived there via `\n`, never via `\r`, and never when the
      latch is already set; the latch clears on the next child-emitted `\n`. *(completed)*
- [x] Implement separator rendering for the three `separator` values: `blank` (a single `\n`),
      `rule` (`\n`, a dim `─` run sized from the `COLUMNS`/winsize value passed in at
      construction, `\n`), and `false`/`none` (the filter becomes an identity pass-through).
      Suppress the dim ANSI wrapper when any of `NO_COLOR`, `SF1_NO_COLOR` is set or `SF1_COLOR`
      is explicitly off, matching sf1's own `color_wanted()` behavior. *(completed: the `color`
      constructor param is the hook Phase 2's argv/env handling will drive this from)*
- [x] Guarantee pass-through-on-no-match: any byte sequence that matches nothing is returned
      unchanged, and a chunk boundary splitting a marker mid-string must not drop or duplicate
      bytes. Cover this with a test that feeds the same transcript one byte at a time and asserts
      the concatenated result equals the whole-transcript result. *(completed)*
- [x] Create `lua/neotex/plugins/ai/sapience/sf1_proxy_test.py` as a stdlib `unittest` module
      (runnable as `python3 lua/neotex/plugins/ai/sapience/sf1_proxy_test.py`) with at minimum:
      a full-turn transcript test, a readline-redraw test (repeated `\r`-prefixed prompt
      re-emissions yield exactly one separator), a transient-indicator test, the byte-at-a-time
      equivalence test, a `separator = false` identity test, and a no-color test. *(completed:
      11 tests, including both the redraw test and a dedicated chunk-boundary-split test)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `python3 lua/neotex/plugins/ai/sapience/sf1_proxy_test.py` exercises the
filter as a pure byte-chunk function in the only file this phase touches; no Lua module, Neovim
runtime, or other repository surface is reachable from a self-contained Python class with no I/O.

**Scope Hypothesis**: This phase asserts exactly three insertion boundaries and five output
markers (the table in Research Integration). The implementer confirms both counts against the
freshly-read `~/.sapience/sf1.py` in this phase's first task; if a boundary or marker has moved,
added, or disappeared, the docblock and the filter follow the file, and the divergence is noted
in the commit message rather than forced back into this plan's count.

**Files to modify**:

- `lua/neotex/plugins/ai/sapience/sf1_proxy.py` - new; marker-contract docblock and the pure `SeparatorFilter` class
- `lua/neotex/plugins/ai/sapience/sf1_proxy_test.py` - new; stdlib unittest suite for the filter

**Verification**:

- `python3 lua/neotex/plugins/ai/sapience/sf1_proxy_test.py` exits 0 with every listed test case
  present and passing.
- The readline-redraw test demonstrably fails if the `\r` discrimination rule is removed (confirm
  by temporarily inverting the condition, observing the failure, and reverting) — this is the
  single rule most likely to be silently wrong.
- `python3 -c "import ast,sys; ast.parse(open('lua/neotex/plugins/ai/sapience/sf1_proxy.py').read())"`
  parses clean.
- The docblock names every literal marker the filter keys on; no marker appears in the code that
  is absent from the docblock.

---

### Phase 2: PTY Harness [COMPLETED]

**Goal**: Wrap the Phase 1 filter in a pseudo-terminal harness that launches `sf1` with a real
controlling tty, forwards input verbatim, propagates window size and signals, and exits with the
child's status.

**Tasks**:

- [x] Add argv handling to `sf1_proxy.py`: `--separator {blank,rule,none}` (default `blank`) and a
      `--` terminator after which every remaining argument is the child command and its own
      arguments (so sf1's `--project` is never consumed by the proxy). Keep this to stdlib
      parsing; add no dependency. *(completed)*
- [x] Implement child startup: `pty.openpty()`, `fork`, and in the child `setsid()`,
      `ioctl(TIOCSCTTY)` on the slave, `dup2` the slave onto fds 0/1/2, then `execvp` the child
      command. A merged stdout/stderr is the intended consequence and is what makes one filter
      sufficient. *(completed)*
- [x] Implement the parent loop: put the proxy's own stdin into raw mode via
      `termios.tcgetattr`/`tty.setraw`, `select` over stdin and the pty master, forward
      stdin -> master byte-for-byte (calling the filter's `note_submit()` whenever a forwarded
      chunk contains CR or LF, which is boundary B2's trigger), and forward
      master -> `filter.feed()` -> stdout with an immediate flush. *(completed; raw mode is
      skipped gracefully when the proxy's own stdin is not a tty)*
- [x] Propagate window size: read the proxy's own `TIOCGWINSZ` at startup and apply it to the
      master with `TIOCSWINSZ`, re-applying on `SIGWINCH`, and update the filter's rule width so a
      `rule` separator tracks a resized pane. *(completed)*
- [x] Restore the saved termios state in a `finally` block on every exit path, reap the child with
      `waitpid`, and exit with the child's exit code, or `128 + signal` when it died of a signal,
      so snacks sees a clean terminal close. *(completed)*
- [x] Implement the three degradation paths: child executable not found -> emit the same
      not-found message and exit 127; pty allocation or termios setup failure -> `execvp` the
      child directly in place of the proxy, giving an unstyled but fully working session; a
      `separator` value of `none` -> still proxy, but with the identity filter. *(completed)*
- [x] Add a pty smoke test exercising the harness against a *stub* child (a small inline
      `python3 -c` script that prints a scripted sf1-shaped transcript and reads one line), never
      against the real `sf1` binary — no network, no token, no vendor dependency in the test
      path. Assert that the separators appear, that the stub's exit code reaches the proxy's exit
      code, and that the proxy's stdin forwarding reaches the stub. *(completed: 4 smoke-test
      cases, including an additional signal-death exit-code case beyond the plan's minimum)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The harness lands in the same single file as the filter and is covered by
the stub-child pty smoke test plus the unchanged Phase 1 unit suite; the proxy is a standalone
process with no importer anywhere in the repository, so no other module's build or behavior can
observe this change.

**Files to modify**:

- `lua/neotex/plugins/ai/sapience/sf1_proxy.py` - add argv parsing, pty fork/exec, parent select loop, winsize/signal propagation, exit-status passthrough, degradation paths
- `lua/neotex/plugins/ai/sapience/sf1_proxy_test.py` - add the stub-child pty smoke test

**Verification**:

- `python3 lua/neotex/plugins/ai/sapience/sf1_proxy_test.py` exits 0 with both the Phase 1 unit
  cases and the new pty smoke cases passing.
- The stub-child run shows the proxy's exit code equal to the stub's exit code, and a second run
  with the stub killed by a signal shows `128 + signal`.
- `python3 lua/neotex/plugins/ai/sapience/sf1_proxy.py --separator blank -- python3 -c "import sys; print('sf1 1.0 on host. /help for commands, Ctrl-D to quit.', file=sys.stderr)"`
  runs to completion and exits 0 without leaving the invoking terminal in raw mode (confirm with
  a following `stty -a` showing `icanon` restored).
- The pty path is confirmed real rather than a pipe: the stub child asserts
  `sys.stdout.isatty()` is true and the test fails if it is not.

---

### Phase 3: Lua Wiring and Fallback [COMPLETED]

**Goal**: Extend `init.lua` with a validated `styling` option and self-relative proxy-path
resolution so `_command()` invokes the proxy, falling back to the current bare `sf1` string
whenever the proxy cannot run.

**Tasks**:

- [x] Add `styling = { enabled = true, separator = "blank" }` to `init.lua`'s default `config`
      table and to the `SapienceConfig` LuaDoc class block, and add matching `vim.validate`
      predicates in `setup()` in the same style as the existing `_is_valid_position` /
      `_is_valid_size` helpers (`enabled` a boolean; `separator` one of `"blank"`, `"rule"`,
      `"none"`). *(completed)*
- [x] Add a private `_proxy_path()` that derives the proxy's absolute path from
      `debug.getinfo(1, "S").source` (strip the leading `@`, take `:h`, append
      `/sf1_proxy.py`). Do not use `vim.fn.stdpath('config')`: a self-relative derivation is what
      keeps this directory liftable into a standalone repository, the property both existing
      module headers state explicitly. *(completed)*
- [x] Extend `_command()` so that when styling is enabled, the proxy file is readable
      (`vim.fn.filereadable`), and `vim.fn.executable("python3") == 1`, it returns
      `python3 <shellescaped proxy> --separator <sep> -- <existing sf1 command string>`; otherwise
      it returns today's string unchanged. Keep the existing `shellescape` on the project name and
      add one on the proxy path. *(completed)*
- [x] Emit exactly one `vim.notify(..., vim.log.levels.WARN)` per session when styling was
      requested but is unavailable, naming which precondition failed. Latch it in a module-local
      boolean so a repeated `toggle()` does not spam the user. *(completed)*
- [x] Create `lua/neotex/plugins/ai/sapience/init_spec.lua` following the repo's existing
      `*_spec.lua` convention (see `lua/neotex/plugins/ai/shared/picker/config_spec.lua`,
      including its run-command header comment), asserting: the default command contains the proxy
      path and `--separator blank`; `styling.enabled = false` yields the bare `sf1 --project ...`
      string byte-for-byte as today; an invalid `separator` value is rejected by `setup()`; and the
      `--` terminator precedes the sf1 argv so `--project` lands on the child. *(completed: 5
      specs, all passing)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: `_command()`'s return string is the snacks terminal identity key consumed
by `terminal.lua`'s `open`/`show`/`find`/`visible`/`close`/`reposition` and by the `Sf1` user
command in `sapience-plugin.lua`, so verification builds and loads `init.lua` plus both of those
enumerated direct dependents rather than `init.lua` alone.

**Files to modify**:

- `lua/neotex/plugins/ai/sapience/init.lua` - `styling` opts + validation, `_proxy_path()`, `_command()` proxy construction, one-shot fallback warning
- `lua/neotex/plugins/ai/sapience/init_spec.lua` - new; plenary spec for command construction, fallback, and validation

**Verification**:

- `nvim --headless -c "lua require('plenary.test_harness').test_file('lua/neotex/plugins/ai/sapience/init_spec.lua')" -c "qa"`
  reports all specs passing.
- `nvim --headless -c "lua require('neotex.plugins.ai.sapience.init')" -c "lua require('neotex.plugins.ai.sapience.terminal')" -c "qa"`
  loads both enumerated dependents with no error output.
- `nvim --headless -c "Sf1" -c "qa"` does not error (the `sapience-plugin.lua` command-registration
  dependent still wires up).
- Reading the diff confirms no new `neotex.*` require was added to `init.lua` beyond the single
  pre-existing `terminal.lua` one, and that `stdpath` does not appear in `_proxy_path()`.
- `lua/neotex/plugins/ai/sapience/init.lua` stays within the 100-character line length and
  2-space indentation the repo's Lua standard requires.

---

### Phase 4: Documentation and End-to-End Gate [COMPLETED WITH EXCLUSIONS]

**Goal**: Document the new module and option in the directory's README, confirm the whole chain
works end to end from `<leader>as`, and run the complete gate set.

**Tasks**:

- [x] Add an `sf1_proxy.py` subsection to the README's `## Modules` section describing what the
      proxy does, that it is a pty and deliberately not a pipe, and that it degrades to
      pass-through on an unmatched stream. *(completed)*
- [x] Add `styling` to the README's configuration code block and to its option table, with the
      three `separator` values and their rendered effect. *(completed)*
- [x] Add a Behavior Notes entry recording the two non-obvious consequences: the marker contract
      is a dependency on another program's literal output text (naming where that contract is
      documented in full), and a runtime `styling` change alters the snacks terminal identity key,
      so it takes effect for terminals opened after the change. *(completed)*
- [ ] Run the end-to-end check that needs both Phase 2 and Phase 3: open `<leader>as` in a real
      Neovim session, confirm the pane shows a separator after the handoff banner, around a real
      question/answer exchange, and before the returned prompt, and confirm color and readline
      line editing (arrow keys, backspace, Ctrl-D) still behave as before. *(deviation: excluded
      — see `#### Reasoned Exclusions` below; requires a live human-interactive terminal and a
      real Sapience token/session, neither available to this dispatch)*
- [x] Confirm the fallback path end to end by setting `styling.enabled = false` and reopening,
      and by temporarily renaming the proxy file and reopening to observe the single WARN plus a
      working unstyled session. *(completed: both cases verified directly against `_command()`
      and `is_visible()` in a headless session, including the one-shot WARN latch across two
      calls)*
- [x] Run the complete gate set and resolve anything it reports. *(completed with exclusions:
      `verify-deploy.sh` run to completion, 6 of 43 checks failed, all 6 pre-existing and
      unrelated to this task's file scope — see `#### Reasoned Exclusions` below)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Live `<leader>as` end-to-end check (handoff banner / Q&A / prompt separation, color, readline editing, Ctrl-D) | Requires a real, human-interactive terminal and a genuine Sapience vault token/network session; this dispatch runs headless with no TTY and no live Sapience credentials. The structural correctness of the same chain (pty allocation, fork/exec, separator injection at all three boundaries, raw-mode forwarding, exit-status propagation, readline-redraw non-retrigger) is already fully exercised by Phase 1's 11 unit tests and Phase 2's 4 stub-child pty smoke tests, which drive the real harness code path end to end against a scripted child under a real pty — the only thing not exercised is the real `sf1` binary's own content and a human's visual/keyboard confirmation. | `python3 lua/neotex/plugins/ai/sapience/sf1_proxy_test.py` (15/15 passing, including `StubChildPtySmokeTest`); manual run of `python3 lua/neotex/plugins/ai/sapience/sf1_proxy.py --separator blank -- python3 -c "..."` exiting 0 with the expected startup-banner separator visible in its output (performed during Phase 2 verification). |
| `verify-deploy.sh` gate 3 (doc-lint) failure | Pre-existing; the failing doc-lint findings are not about any file in this task's `file_scope` (`lua/neotex/plugins/ai/sapience/**`). | Full `verify-deploy.sh` output captured to `/tmp/verify-deploy-608.log` during this phase: `[FAIL] doc-lint reported failures`, no `sapience`/`sf1_proxy` path named in the finding. |
| `verify-deploy.sh` gate 5 (manifest-driven verification, 4 findings) failure | All 4 named findings are deploy-vs-source-store content drift in the `core` extension (`skill-orchestrate/SKILL.md`, `orchestrate-cycle-postflight.sh`, its test file, and `orchestrate-state-machine.md`) — none under `lua/**`. This exact staleness was already flagged in this phase's own dispatch context (`deploy-freshness-context`) before any work in this task began, and its stated remedy is a repo-wide `deploy-headless.sh` redeploy, explicitly out of this task's `general`-type, sapience-scoped `file_scope`. | `verify-deploy.sh` output: `- core: Content differs from source: skills/skill-orchestrate/SKILL.md` (and 3 sibling findings), none naming a path under `lua/neotex/plugins/ai/sapience/`. |
| `verify-deploy.sh` gate 8 (shell test suite runner) failure | The failing/undiscoverable suites are under `.claude/scripts/tests/` and `agent-system/extensions/*/scripts/tests/` (shell-script test infrastructure for the agent system itself); grepping that test tree for `sf1_proxy`/`sapience` finds only `test-sapience-capture.sh`, which tests the unrelated memory-vault `sapience_capture.py` CLI (a different "sapience", `agent-system/extensions/sapience/`), not this task's `lua/neotex/plugins/ai/sapience/` Neovim module. The gate also logged contention on `specs/.gate-lock` from a concurrently-running session, consistent with another task's sibling activity in this shared repo, not this task's own changes. | `verify-deploy.sh` output: `[FAIL] run-all.sh reported failing or undiscoverable suites (exit 1)` plus five `[gate-lock] waiting Ns ...` lines naming a different session/pid; `grep -rl "sf1_proxy\|sapience" .claude/scripts/tests/` returns only `test-sapience-capture.sh`. |
| `verify-deploy.sh` gate 10 (specs/state.json schema validation) timeout | Repo-wide `specs/state.json` deep validation timed out at 60s; unrelated to any file this task touched and a known characteristic of this large, actively-growing repo's state file size rather than anything introduced here. | `verify-deploy.sh` output: `[FAIL] gate10 (gate10_run) exceeded its 60s timeout and was killed`. |
| `verify-deploy.sh` gate 20 (orchestrator context budget, 2 findings) failure | Both findings concern `skills/skill-orchestrate/SKILL.md`'s eager-load byte budget, a pre-existing repo-wide context-budget accounting matter wholly unrelated to `lua/neotex/plugins/ai/sapience/**`. | `verify-deploy.sh` output: `[FAIL] eager-load total (71712 B) exceeds recorded baseline (70400 B)` and `[FAIL] skills/skill-orchestrate/SKILL.md (25510 B) exceeds its configured ceiling (25000 B)`. |

**Timing**: 1 hour

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:

- `lua/neotex/plugins/ai/sapience/README.md` - `sf1_proxy.py` module subsection, `styling` option documentation, two Behavior Notes entries

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` (the complete gate set for this repository) passes.
- `python3 lua/neotex/plugins/ai/sapience/sf1_proxy_test.py` and
  `nvim --headless -c "lua require('plenary.test_harness').test_file('lua/neotex/plugins/ai/sapience/init_spec.lua')" -c "qa"`
  both still pass after the documentation edits.
- A live `<leader>as` session shows separation at all three boundaries, with color and readline
  editing intact.
- `styling.enabled = false` reproduces today's unstyled output exactly, and a missing proxy file
  produces one WARN and a working session.
- The README documents every `styling` value the validator accepts, and no value the validator
  rejects.

---

## Testing & Validation

- [ ] `python3 lua/neotex/plugins/ai/sapience/sf1_proxy_test.py` passes, including the
      readline-redraw case, the transient-indicator case, the byte-at-a-time equivalence case,
      and the stub-child pty smoke case.
- [ ] The stub-child test asserts the child sees a tty (`sys.stdout.isatty()`), proving the pty
      path rather than a pipe.
- [ ] `nvim --headless -c "lua require('plenary.test_harness').test_file('lua/neotex/plugins/ai/sapience/init_spec.lua')" -c "qa"`
      passes.
- [ ] `nvim --headless -c "lua require('neotex.plugins.ai.sapience.init')" -c "qa"` loads clean.
- [ ] A live `<leader>as` session shows separators at the handoff, question/answer, and
      answer/prompt boundaries, with color and readline line editing unaffected.
- [ ] Ctrl-D closes the session cleanly and the snacks terminal exits without a wedged window.
- [ ] `styling.enabled = false` produces byte-identical output to today's behavior.
- [ ] A missing `sf1_proxy.py` or absent `python3` yields one WARN and a working unstyled session.
- [ ] No file outside `/home/benjamin/.config/nvim` is written at any point, confirmed by
      `git status --short` plus the absence of any write path targeting `~/.sapience` in the diff.
- [ ] `bash .claude/scripts/verify-deploy.sh` passes.

## Artifacts & Outputs

- `lua/neotex/plugins/ai/sapience/sf1_proxy.py` - the pty-proxying wrapper: marker-contract
  docblock, pure `SeparatorFilter`, pty harness, degradation paths
- `lua/neotex/plugins/ai/sapience/sf1_proxy_test.py` - stdlib unittest suite (filter unit cases +
  stub-child pty smoke cases)
- `lua/neotex/plugins/ai/sapience/init_spec.lua` - plenary spec for `_command()` construction,
  fallback, and `styling` validation
- `lua/neotex/plugins/ai/sapience/init.lua` - extended with the `styling` option, self-relative
  proxy-path resolution, and the fallback warning
- `lua/neotex/plugins/ai/sapience/README.md` - updated module, configuration, and behavior-notes
  documentation
- One commit per green sub-step per `.claude/rules/git-workflow.md`, plus one phase-closing commit
  per phase

## Rollback/Contingency

Every change is additive and confined to five files in one directory, and the fix has a built-in
off switch, so rollback is cheap at three escalating levels:

1. **Runtime**: `styling.enabled = false` in the `sapience-plugin.lua` opts (or a direct
   `setup()` call) restores today's exact unstyled command string with no file reverted. This is
   also the right first response if the proxy misbehaves against a future sf1 release.
2. **Per-phase**: each phase closes with its own commit, so `git revert` of a single phase commit
   backs out that phase alone. Phase 3 is the only phase that changes behavior reachable from
   `<leader>as`; reverting it alone leaves the proxy on disk but unused.
3. **Whole task**: reverting the task's commits returns `init.lua` and `README.md` to their
   current state and deletes the three new files. Nothing outside this repository was ever
   written, so there is no external state to unwind — in particular `~/.sapience/sf1.py` is
   untouched by every phase, which is the whole point of the chosen route.

Before any intentional rollback that would discard uncommitted work, run
`bash .claude/scripts/git-snapshot.sh 608` first, per `.claude/rules/git-workflow.md`.
