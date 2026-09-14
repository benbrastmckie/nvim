# Implementation Plan: Per-Project lean-lsp Registration

- **Task**: 205 - Replace the single-global lean-lsp entry with per-project scoped registration written automatically at session start
- **Status**: [COMPLETED]
- **Effort**: 13 hours
- **Dependencies**: 203 (COMPLETED), 204 (COMPLETED)
- **Research Inputs**: specs/205_per_project_lean_lsp_registration/reports/01_per-project-lean-lsp-registration.md
- **Artifacts**: plans/01_per-project-lean-lsp-registration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Flip lean-lsp registration from one global `~/.claude.json` `.mcpServers."lean-lsp"` entry to
per-project entries under `~/.claude.json`'s `.projects[<abs path>].mcpServers`, written
automatically by a `SessionStart` hook that detects the enclosing Lake project. Every artifact
that currently *enforces* the single-global model — `verify-lean-mcp.sh` Check 9,
`setup-lean-mcp.sh`'s write target, `mcp-server-ownership.md`'s recorded trade-off,
`lean-mcp-preflight-check.sh`'s remedy text, and the fixture suite — is inverted in the same
task, because a half-flipped system actively fights the fix. Done means: two Lean projects open
concurrently in separate fresh sessions each return a real lean-lsp result resolved against
their own project, proven by a declaration present in one project and absent from the other.

### Research Integration

The research report confirmed by direct `jq` inspection that `.projects[<path>].mcpServers` is a
real, live, currently-empty per-project object on ~30 registered paths — the mechanism needs
writing to, not inventing. It also established the automatic-writer precedent (the email
extension contributes a native harness hook via its own `settings-fragment.json` `hooks` key
plus `provides.hooks`), distinguished this task's CWD-driven `SessionStart` hook from task 204's
rejection of a task-type-driven one, and mapped all seven outstanding issues onto specific files.

Two facts established during planning materially shape the phases below and are NOT in the
research report:

1. **`~/.claude/settings.json`'s `hooks` key is home-manager-enforced.**
   `~/.dotfiles/modules/home/core/dotfiles.nix`'s `activation.claudeSettings` merges
   `~/.dotfiles/config/claude/settings.json` into `~/.claude/settings.json` with
   `["_NOTE","env","hooks","model","permissions","statusLine"]` forced back to the source's
   values on every rebuild. A hook written only into the live file is silently reverted by the
   next `home-manager switch`.
2. **A per-repo `.claude/settings.local.json` hook cannot satisfy the acceptance bar.**
   `/home/benjamin/Projects/cslib-pr648` — the exact worktree named in the task description —
   has **no `.claude/` directory at all** (verified). A hook contributed only through the lean
   extension's `settings-fragment.json` never fires there, so "a freshly created worktree is
   correct on first use with zero manual steps" forces a *user-level* hook registration.

### Prior Plan Reference

No prior plan for this task. Tasks 203 and 204 are its direct predecessors: 203 chose the
single-global "Option A" and explicitly recorded this task's mechanism as its declined "Option
B"; 204 wired WARN-only drift detection onto 203's shape. Effort calibration from those two:
whole-entry (not per-field) reconciliation and fixture mutation checks were the two disciplines
that made them stick, and both are carried forward here as explicit obligations rather than
re-derived.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch context; no roadmap was consulted or modified.

## Decisions Made At Plan Time

These resolve the "confirm during planning" items in the task description. Each is a planning
judgment call recorded here rather than deferred.

- **D1 — Registration surface**: `~/.claude.json` `.projects[<abs path>].mcpServers."lean-lsp"`,
  as recommended. A committed `.mcp.json` is rejected for the stated reasons (git-tracked,
  cannot be committed into cslib upstream, workspace-trust gate on every fresh worktree).
  Phase 1 must *confirm* precedence and subagent reachability empirically before Phase 3 builds
  on it, rather than asserting them.
- **D2 — The top-level global entry is RETIRED, not kept as a fallback.** Keeping it reproduces
  the exact defect this task exists to remove: a session in an unregistered Lean project would
  silently index whichever project the global entry names and return confident wrong answers. An
  absent entry fails loudly (no lean-lsp tool at all) and is therefore strictly safer. After
  this task, presence of a top-level `.mcpServers."lean-lsp"` is itself drift.
- **D3 — File-location split (issue 7) resolves by MOVING** `setup-lean-mcp.sh` and
  `verify-lean-mcp.sh` from `core/scripts/` to `lean/scripts/`, joining
  `lean-mcp-preflight-check.sh`. Registration is now lean-specific and per-project; nothing in
  core depends on lean-lsp being registered (confirmed by the research grep). Deployed consumers
  see no path change — every extension's `scripts/` flattens into one `.claude/scripts/`.
- **D4 — The hook is registered at user level**, in `~/.dotfiles/config/claude/settings.json`
  (durable source of truth) *and* mirrored into the live `~/.claude/settings.json` (immediate
  effect without a rebuild), by an idempotent installer script. The lean extension's
  `settings-fragment.json` is NOT the registration surface for this hook, per Overview fact 2.
  The `~/.dotfiles` edit is in a second repository the user owns; the implementer applies it but
  MUST NOT commit in that repository.
- **D5 — The hook script's canonical source** lives in this repo's source store at
  `agent-system/extensions/lean/hooks/lean-lsp-register-project.sh`, and the installer copies it
  to the stable user-level path `~/.claude/hooks/lean-lsp-register-project.sh` (the same stable
  location `statusline-push.sh` already occupies). It is deliberately NOT invoked from any
  repository's disposable `.claude/` tree — that is the separate `mcp-server-ownership.md`
  invariant which this task must leave fully intact.

## Goals & Non-Goals

**Goals**:
- Per-project `lean-lsp` entries under `.projects[<abs path>].mcpServers`, written automatically
  at session start with zero manual steps, including in a brand-new worktree with no `.claude/`.
- Invert `verify-lean-mcp.sh` Check 9: a correct project-scoped entry is the PASS state; its
  absence, a stale path inside it, or a surviving global entry is the drift.
- Preserve whole-entry (command+args+env) reconciliation in the writer, not per-field patching.
- Revise `mcp-server-ownership.md`'s recorded trade-off with the concurrency evidence that
  overturned it, while leaving the `.claude/`-command-path invariant untouched.
- Extend the fixture suite with genuinely concurrent multi-project and fresh-worktree cases,
  keeping the existing mutation-check discipline.
- Re-establish cslib, BimodalLogic, and cslib-pr648 under the sanctioned mechanism.
- Demonstrate acceptance with two concurrent sessions and project-unique evidence.

**Non-Goals**:
- Committing anything in `~/.dotfiles` or in any Lean project repository (cslib, BimodalLogic).
  The implementer applies the `~/.dotfiles` edit and leaves it uncommitted for the user.
- Weakening or re-litigating the invariant that an MCP command path must never resolve inside a
  repository's `.claude/` deploy tree.
- Changing `lean-mcp-preflight-check.sh`'s WARN-only, always-exit-0 contract.
- Registering non-Lean MCP servers per-project, or generalizing this mechanism to other servers.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Session-start snapshot trap: a `SessionStart`-hook write may not take effect until the NEXT session in that directory (`mcp-server-ownership.md` documents the tool registry as a startup snapshot) | H | H | Phase 1 determines this empirically before anything is built on it. If same-session effect is absent, Phase 4's hook additionally emits an `additionalContext`/stderr notice naming the just-written project and telling the session to restart; the first-session degraded state is then *loud and correct-by-absence* (D2), never silently wrong |
| home-manager rebuild reverts a hook written only to the live `~/.claude/settings.json` | H | M | D4: write the durable entry into `~/.dotfiles/config/claude/settings.json` as well; Phase 4 verifies by simulating the enforced-key merge with the same `jq` expression `dotfiles.nix` uses |
| Concurrent sessions racing on `~/.claude.json` read-modify-write | M | M | Keep the existing temp-file-then-`mv` atomic-rename pattern; writes are idempotent to the same canonical value, so a lost update costs a redundant write, not corruption. Phase 4 additionally makes the hook a no-op when the entry already matches |
| Moving two scripts between extensions breaks deploy if only one manifest is updated | M | M | Phase 2 is `atomic-batch`: move + both manifests + all referencing docs land in one commit, verified by a post-move deploy/reference grep |
| Retiring the global entry (D2) breaks a workflow that relied on it | M | L | Phase 9 registers every active Lean project before Phase 10; the acceptance demo would surface any project left without a working tool |
| Fixtures pass vacuously | M | M | Phase 7 extends the existing neutralizing-mutation check to every new fixture, per the discipline already recorded in the suite's header |
| `~/.dotfiles` edit surprises the user | L | M | Recorded as D4 and reported in the summary; no commit is made in that repository |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4, 5 | 3 |
| 4 | 6, 8, 9 | 4, 5 |
| 5 | 7 | 5, 6 |
| 6 | 10 | 7, 8, 9 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Confirm precedence, reachability, and hook timing [COMPLETED]

**Goal**: Establish, by fresh-session experiment rather than assertion, the three mechanism facts
every later phase depends on: that a project-scoped entry takes precedence over the global one,
that a subagent can reach it, and whether a `SessionStart`-hook write is visible in the same
session or only the next one.

**Tasks**:
- [x] Hand-write a project-scoped `lean-lsp` entry for one Lean project (e.g. BimodalLogic) into
      `.projects[<path>].mcpServers` with a `LEAN_PROJECT_PATH` deliberately DIFFERENT from the
      global entry's, so precedence is observable rather than ambiguous
- [x] In a fresh `claude -p` session started in that directory, call a lean-lsp tool and confirm
      which project answered (use a declaration/file unique to one project — never a query both
      projects could satisfy)
- [x] Repeat the same probe from a subagent dispatch to confirm subagent reachability of the
      project-scoped entry
- [x] Install a throwaway `SessionStart` (matcher `startup`) hook that writes a project-scoped
      entry for a directory with none, start a fresh session there, and record whether lean-lsp
      is available in THAT session or only the next one
- [x] Record all three outcomes verbatim (commands + observed output) in the implementation
      progress file; they become inputs to Phase 4's messaging contract and Phase 8's doc text
- [x] Remove every throwaway fixture entry and the throwaway hook before closing the phase

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Verification**:
- Each of the three questions has a recorded answer backed by quoted command output
- `jq '.projects' ~/.claude.json` shows no leftover throwaway entries; no throwaway hook remains
  in `~/.claude/settings.json`

---

### Phase 2: Relocate the registration scripts into the lean extension [COMPLETED]

**Goal**: Resolve issue 7 per D3 — move `setup-lean-mcp.sh` and `verify-lean-mcp.sh` from the
core extension to the lean extension as a pure relocation, with no behavior change, so every
later semantic edit happens in the final location.

**Tasks**:
- [x] `git mv agent-system/extensions/core/scripts/{setup,verify}-lean-mcp.sh agent-system/extensions/lean/scripts/`
- [x] Remove both entries from `agent-system/extensions/core/manifest.json` `provides.scripts`
- [x] Add both entries to `agent-system/extensions/lean/manifest.json` `provides.scripts`
- [x] Update every source-store reference to the old `core/scripts/` path: enumerate with
      `grep -rn "core/scripts/setup-lean-mcp\|core/scripts/verify-lean-mcp\|extensions/core/scripts" agent-system/`
      and fix each (known: `mcp-server-ownership.md`, `docs/guides/permission-configuration.md`,
      `docs/reference/utility-scripts-inventory.md`, `lean/README.md`,
      `lean/context/project/lean4/tools/mcp-tools-guide.md`)
- [x] Confirm `test-lean-mcp-preflight-check.sh`'s dual-layout `VERIFIER_SRC` probe still
      resolves (its source-store candidate `../../../core/scripts/verify-lean-mcp.sh` becomes
      dead; its sibling candidate `../verify-lean-mcp.sh` now hits) and update the header comment
      that explains the two candidates
- [x] Redeploy and confirm `.claude/scripts/` still carries both scripts

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: 8 source-store files reference these two script paths (the 5 named above
plus the two scripts themselves and `lean-mcp-preflight-check.sh`). Confirm at implementation
time with the `grep -rn` enumeration in the task list; the plan's count is a hypothesis, and the
grep's actual result governs.

**Files to modify**:
- `agent-system/extensions/core/scripts/setup-lean-mcp.sh` -> `agent-system/extensions/lean/scripts/setup-lean-mcp.sh` (move)
- `agent-system/extensions/core/scripts/verify-lean-mcp.sh` -> `agent-system/extensions/lean/scripts/verify-lean-mcp.sh` (move)
- `agent-system/extensions/core/manifest.json` - drop two `provides.scripts` entries
- `agent-system/extensions/lean/manifest.json` - add two `provides.scripts` entries
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` - path references only
- `agent-system/extensions/core/docs/guides/permission-configuration.md` - path references
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - path references
- `agent-system/extensions/lean/README.md`, `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` - path references
- `agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` - header comment

**Verification**:
- `grep -rn "core/scripts/setup-lean-mcp\|core/scripts/verify-lean-mcp" agent-system/` returns nothing
- Both scripts run unchanged from their new location (`--help`, and `verify-lean-mcp.sh` against
  a fixture HOME) with byte-identical behavior to before the move
- `bash agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` still passes

---

### Phase 3: Teach the writer per-project scope [COMPLETED]

**Goal**: Give `setup-lean-mcp.sh` a project-scope write path that reuses
`generate_lean_lsp_config()` and the whole-entry reconciliation discipline, and make
project-scope the default, with the global entry retired per D2.

**Tasks**:
- [x] Add a `--scope project|global|both` flag defaulting to `project`
- [x] Implement the project-scope read/compare/write against
      `.projects[$path].mcpServers."lean-lsp"`, creating the `.projects[$path]` and `.mcpServers`
      objects when absent, using the same temp-file-then-`mv` atomic rename
- [x] Reuse the existing whole-entry comparison (`$existing == $canonical`) and whole-entry
      overwrite — never a targeted `env.LEAN_PROJECT_PATH` assignment — so command/args drift is
      corrected too
- [x] Add `--remove` support at project scope, and a `--retire-global` action that deletes the
      top-level `.mcpServers."lean-lsp"` entry (D2)
- [x] Add a `--quiet` mode suitable for hook invocation: silent and exit 0 when the entry already
      matches, one line when it writes
- [x] Keep `--dry-run` honest for every new path
- [x] Update the script header comment block (its `Usage`/`Options`/behavior narrative) to the
      per-project model

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/lean/scripts/setup-lean-mcp.sh`

**Verification**:
- Against a fixture `HOME`: `--scope project` on a config with no `.projects` key creates the
  full path and the canonical entry; a second run is a silent no-op; a divergent entry (wrong
  command AND wrong path) is replaced wholesale
- `--scope project --dry-run` mutates nothing (`md5sum` of the fixture config unchanged)
- `--retire-global` removes only the top-level entry, leaving `.projects` untouched
- Two different project paths registered in sequence both survive, each with its own
  `LEAN_PROJECT_PATH`

---

### Phase 4: SessionStart hook and its user-level installer [COMPLETED]

**Goal**: Make registration automatic at session start in ANY directory, including a fresh
worktree with no `.claude/` deploy, per D4 and D5.

**Tasks**:
- [x] Create `agent-system/extensions/lean/hooks/lean-lsp-register-project.sh`: detect the
      enclosing Lake project (`lakefile.lean`/`lakefile.toml` at CWD or git root, in lockstep
      with the two scripts' detection), exit 0 silently when not a Lean project, otherwise invoke
      the Phase 3 writer at project scope in quiet mode
- [x] Make the hook resolve the writer from a stable absolute path, never from the calling
      repository's `.claude/` tree (D5 / the `mcp-server-ownership.md` invariant)
- [x] Apply Phase 1's timing finding: if a same-session write is not visible, emit a one-line
      notice naming the project just registered and stating that a restart is required; if it is
      visible, stay silent on the success path
- [x] Make the hook always exit 0 and never emit non-JSON noise that could break the harness
      hook contract (follow the `2>/dev/null || echo '{}'` shape used by existing hook entries)
- [x] Declare `lean-lsp-register-project.sh` in `agent-system/extensions/lean/manifest.json`
      `provides.hooks` (currently `[]`) so consumer repos get a deployed copy
- [x] Create `agent-system/extensions/lean/scripts/install-lean-lsp-session-hook.sh`: idempotently
      copy the hook to `~/.claude/hooks/lean-lsp-register-project.sh` and merge a
      `hooks.SessionStart` matcher-`startup` entry into BOTH
      `~/.dotfiles/config/claude/settings.json` and live `~/.claude/settings.json`; warn (never
      fail) when the dotfiles source is absent; support `--dry-run` and `--remove`
- [x] Run the installer and confirm the hook fires in a fresh session

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/lean/hooks/lean-lsp-register-project.sh` (new)
- `agent-system/extensions/lean/scripts/install-lean-lsp-session-hook.sh` (new)
- `agent-system/extensions/lean/manifest.json` - `provides.hooks`, `provides.scripts`
- `~/.dotfiles/config/claude/settings.json` - `hooks.SessionStart` entry (applied, NOT committed)
- `~/.claude/settings.json` - same entry mirrored for immediate effect

**Verification**:
- Installer run twice in a row produces no second change (idempotent); `--dry-run` mutates nothing
- Simulating `dotfiles.nix`'s enforced-key merge (`jq -s` with
  `["_NOTE","env","hooks","model","permissions","statusLine"]`, the same expression the
  activation block uses) against the edited dotfiles source keeps the new hook entry present —
  proving a rebuild will not revert it
- A fresh session started in `/home/benjamin/Projects/cslib-pr648` (no `.claude/` present) causes
  `.projects["/home/benjamin/Projects/cslib-pr648"].mcpServers."lean-lsp"` to exist with the
  correct `LEAN_PROJECT_PATH`
- A fresh session started in a non-Lean directory writes nothing and emits nothing

---

### Phase 5: Invert the verifier [COMPLETED]

**Goal**: Rewrite `verify-lean-mcp.sh` so the project-scoped entry is the authoritative subject
of every check and Check 9's polarity flips: absence or staleness of the project-scoped entry is
the drift, and a surviving global entry is drift too (D2).

**Tasks**:
- [x] Redirect Checks 3-8 (`.claude/`-path boundary, command, args, `LEAN_PROJECT_PATH` present,
      path match, path exists + Lake marker) at `.projects[$path].mcpServers."lean-lsp"`
- [x] Rewrite Check 2 to fail when the project-scoped entry is ABSENT for a detected Lean
      project, with remedy text naming `setup-lean-mcp.sh` (project scope), not deletion
- [x] Replace Check 9 with the inverse check: a surviving top-level `.mcpServers."lean-lsp"` is
      reported as drift with a `--retire-global` remedy, since it can silently answer for an
      unregistered project
- [x] Preserve the existing exit-code contract (0 valid, 1 missing/invalid, 2 path mismatch) so
      `lean-mcp-preflight-check.sh`'s exit-2 branch keeps its distinct meaning
- [x] Update the script header comment block to the per-project model

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: nine numbered checks exist today; the hypothesis is that Checks 3-8 need
only a retargeted `jq` path and Checks 2 and 9 need rewritten semantics. Confirm by reading each
check at implementation time — if any of 3-8 turns out to encode global-entry assumptions beyond
its `jq` path, that check is rewritten too and the deviation is recorded.

**Files to modify**:
- `agent-system/extensions/lean/scripts/verify-lean-mcp.sh`

**Verification**:
- Fixture HOME with a correct project-scoped entry and no global entry: exit 0
- Fixture with NO project-scoped entry: exit 1, remedy names `setup-lean-mcp.sh`
- Fixture with a project-scoped entry whose `LEAN_PROJECT_PATH` names a different project:
  exit 2 (mismatch branch preserved)
- Fixture with a correct project-scoped entry PLUS a surviving global entry: non-zero, remedy
  names `--retire-global`
- Fixture whose project-scoped `command` resolves inside a `.claude/` tree: still fails on the
  boundary check (the untouched invariant)

---

### Phase 6: Realign the preflight wrapper [COMPLETED]

**Goal**: Keep `lean-mcp-preflight-check.sh` WARN-only and always exit 0 while its emitted
messages and its copied detection stay truthful under the inverted semantics.

**Tasks**:
- [x] Re-read the wrapper's own emitted strings and update the two branch messages so the exit-1
      branch reads as "not registered for this project" rather than "does not match the
      sanctioned form", and the exit-2 branch still reads as wrong-project indexing
- [x] Confirm the generic `[FAIL]`/`[WARN]`/`Run setup-lean-mcp` filter still captures the
      verifier's new remedy lines; extend the filter pattern if any new remedy line shape escapes it
- [x] Re-verify the copied lakefile detection block is still verbatim-identical to the
      verifier's, per the lockstep note, after Phase 5's edits
- [x] Update the header comment's description of what drift now means

**Timing**: 0.5 hours

**Depends on**: 5

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh`

**Verification**:
- `echo $?` is 0 on every fixture branch (registered, unregistered, mismatched, non-Lean, stub)
- Byte-silent on a correctly registered project and outside a Lean project
- On an unregistered Lean project it emits an actionable, `setup-lean-mcp.sh`-naming message

---

### Phase 7: Extend the fixture regression suite [COMPLETED]

**Goal**: Prove the new behavior by fixture, including the genuinely concurrent multi-project and
fresh-worktree cases the task demands, without weakening the existing mutation-check discipline.

**Tasks**:
- [x] Add a fixture registering two Lean projects at once, asserting each resolves to its OWN
      `LEAN_PROJECT_PATH` (the case a single-global model cannot pass)
- [x] Add a fresh-worktree fixture: a second working directory of an already-registered repo,
      asserting it registers independently rather than inheriting or colliding with the parent
- [x] Add both directions of the inverted Check 9: correct project-scoped entry PASSes; surviving
      global entry FAILs
- [x] Add an unregistered-Lean-project fixture asserting the new exit-1 remedy text
- [x] Extend the neutralizing-mutation check to each new fixture so none can pass vacuously, and
      record in the suite header exactly which mutation neutralizes which fixture
- [x] Add a writer-level suite (or extend this one) covering `setup-lean-mcp.sh --scope project`
      idempotency, whole-entry replacement, and `--retire-global`
- [x] Declare any new test/fixture files in `agent-system/extensions/lean/manifest.json`
      `provides.scripts`

**Timing**: 2 hours

**Depends on**: 5, 6

**Verification Tier**: local

**Scope Hypothesis**: five new fixtures are anticipated (two-project concurrent, fresh worktree,
Check 9 PASS direction, Check 9 FAIL direction, unregistered project). Confirm at implementation
time that each maps to a distinct, independently-failing assertion; merge or split as the actual
behavior requires and record the final count.

**Files to modify**:
- `agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh`
- `agent-system/extensions/lean/scripts/tests/test-lean-mcp-registration.sh` (new, if the writer
  suite is kept separate)
- `agent-system/extensions/lean/manifest.json`

**Verification**:
- Full suite exits 0 with every new case reported PASS
- Each new fixture fails when its targeted behavior is neutralized by the mutation check
- No fixture reads or writes the real `~/.claude.json` (every one points `HOME` at a `mktemp -d`)

---

### Phase 8: Revise the recorded invariants and docs [COMPLETED]

**Goal**: Overturn `mcp-server-ownership.md`'s recorded single-global trade-off with the
concurrency evidence, document local scope as sanctioned, and leave the `.claude/`-command-path
invariant fully intact.

**Tasks**:
- [x] Rewrite the "Trade-off recorded" paragraph under the `.claude/`-path invariant: replace
      "accepted limitation / deliberate non-goal" with the live evidence that overturned it (a
      session orchestrating in BimodalLogic held a lean-lsp pointed at cslib; many concurrent
      projects including PR worktrees; the failure connects successfully and answers wrongly)
- [x] Update the `## Registration` section's claim that "only the user scope is a sanctioned
      registration mechanism in this repo; nothing here writes to the local scope" — local scope
      is now sanctioned for per-project computed arguments, written automatically at session start
- [x] Update "Choosing a registration surface (the hybrid model)" so the `lean-lsp` worked example
      names project-scoped local registration, and update the `core/scripts/`-shaped setup-script
      description to the lean extension's location (D3)
- [x] Cross-reference the "session-start snapshot trap" section with Phase 1's measured finding
- [x] Leave the `.claude/`-command-path invariant text itself unmodified; state explicitly in the
      revised trade-off paragraph that it is unaffected
- [x] Update `docs/reference/utility-scripts-inventory.md` entries for all three scripts plus the
      new hook and installer
- [x] Add the email-precedent + this task's hook to `docs/architecture/extension-system.md`'s
      "Settings Merging" section as the sanctioned "how an extension contributes a native hook"
      pattern, including the user-level vs. per-repo distinction Overview fact 2 establishes
- [x] Update `agent-system/extensions/lean/README.md` and `EXTENSION.md` if either describes
      lean-lsp registration

**Timing**: 1.5 hours

**Depends on**: 4, 5

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`
- `agent-system/extensions/core/docs/architecture/extension-system.md`
- `agent-system/extensions/lean/README.md`, `agent-system/extensions/lean/EXTENSION.md`

**Verification**:
- `grep -n "deliberate non-goal\|accepted limitation" agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
  no longer returns the single-global trade-off text
- The `### Invariant: a command path must never resolve inside a repository's own .claude/ tree`
  heading and its body are unchanged (`git diff` shows edits only in the trade-off paragraph
  beneath it)
- Every changed hunk is prose or a fenced example, not executable code (diff read-through)
- `bash .claude/scripts/check-task-references.sh` (or the repo lint equivalent) passes — no task
  numbers introduced outside `specs/**`

---

### Phase 9: Re-establish every active Lean project [COMPLETED]

**Goal**: Register each live Lean project under the sanctioned mechanism and retire the global
entry (issue 6, D2).

**Tasks**:
- [x] Enumerate the live Lean projects by scanning for Lake markers rather than trusting a list
      (`for d in ~/Projects/*/; do [ -f "$d/lakefile.lean" ] || [ -f "$d/lakefile.toml" ]; done`)
- [x] Register each real, active project at project scope with the Phase 3 writer, excluding
      backup/stale directories (`*.bak`) unless the user actively uses them
- [x] Retire the top-level global entry with `--retire-global`
- [x] Run the Phase 5 verifier from each registered project directory and confirm exit 0
- [x] Record the before/after `jq` output of `.mcpServers."lean-lsp"` and
      `.projects | to_entries[] | select(.value.mcpServers."lean-lsp")` in the progress file

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: three active Lean projects are expected (`cslib`, `BimodalLogic`,
`cslib-pr648`), with `cslib.bak` and `ProofChecker.bak` excluded as stale. Confirm by running the
Lake-marker scan at implementation time; the scan's output governs, and any project added or
removed since planning is handled accordingly.

**Files to modify**:
- `~/.claude.json` (machine-local config, not repository content)

**Verification**:
- `jq '.mcpServers."lean-lsp"' ~/.claude.json` returns `null`
- Every enumerated active project has its own entry whose `LEAN_PROJECT_PATH` equals its own path
- `verify-lean-mcp.sh` exits 0 when run from each of those directories

---

### Phase 10: Acceptance demonstration [COMPLETED]

**Goal**: Demonstrate — not assert — that two Lean projects open concurrently each resolve
lean-lsp against their own project, using evidence a wrong-project answer cannot fake.

**Tasks**:
- [x] Pick a declaration or file present in one project and absent from the other in BOTH
      directions (e.g. a `BimodalLogic`-only declaration and a `cslib`-only one), and record the
      exact identifiers chosen
- [x] Start two fresh sessions (`claude -p`) concurrently, one per project directory — never a
      pre-existing session, per the session-start snapshot trap
- [x] In each, call a real lean-lsp tool (e.g. declaration lookup / diagnostics) for BOTH
      identifiers; the own-project identifier must resolve and the other-project identifier must
      NOT
- [x] Repeat for the `cslib-pr648` worktree, which must have been registered automatically by the
      hook with zero manual steps
- [x] Record the full command lines and verbatim outputs in the implementation summary
- [x] Confirm both sessions ran genuinely concurrently (overlapping wall-clock, recorded)

**Timing**: 1 hour

**Depends on**: 7, 8, 9

**Verification Tier**: full

**Verification**:
- Two concurrent sessions each return a real lean-lsp result resolved against their own project
- The cross-project identifier fails to resolve in each session — a wrong-project answer cannot
  masquerade as success
- The worktree session needed no manual registration step

---

## Testing & Validation

- [x] `bash agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` exits 0
- [x] The new registration/writer suite exits 0, with every new fixture neutralized by the
      mutation check
- [x] `verify-lean-mcp.sh` exits 0 from each registered Lean project and non-zero from an
      unregistered one
- [x] `lean-mcp-preflight-check.sh` exits 0 on every branch and is byte-silent on the two silent
      branches
- [x] A fresh session in a `.claude/`-less worktree self-registers
- [x] The simulated home-manager enforced-key merge preserves the SessionStart hook entry
- [x] Repo lints pass: no task-number references outside `specs/**`; no new hand-authored file
      under `.claude/**` (source store only)
- [x] Deploy/reload succeeds with the relocated scripts and the new hook declared

## Artifacts & Outputs

- `specs/205_per_project_lean_lsp_registration/plans/01_per-project-lean-lsp-registration.md` (this file)
- `specs/205_per_project_lean_lsp_registration/summaries/01_per-project-lean-lsp-registration-summary.md`
- `agent-system/extensions/lean/scripts/setup-lean-mcp.sh` (moved, per-project scope)
- `agent-system/extensions/lean/scripts/verify-lean-mcp.sh` (moved, inverted checks)
- `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh` (realigned messages)
- `agent-system/extensions/lean/hooks/lean-lsp-register-project.sh` (new)
- `agent-system/extensions/lean/scripts/install-lean-lsp-session-hook.sh` (new)
- `agent-system/extensions/lean/scripts/tests/` (extended fixtures/suites)
- `agent-system/extensions/{core,lean}/manifest.json` (script/hook declarations)
- Revised: `mcp-server-ownership.md`, `utility-scripts-inventory.md`, `extension-system.md`,
  lean `README.md`/`EXTENSION.md`
- Machine-local, uncommitted: `~/.claude.json` entries, `~/.claude/settings.json`,
  `~/.claude/hooks/lean-lsp-register-project.sh`, `~/.dotfiles/config/claude/settings.json`

## Rollback/Contingency

- Repository changes are per-phase commits on `master`; revert individual commits in reverse
  phase order. Phase 2's move is one atomic commit, so `git revert` restores both manifests and
  both script locations together.
- Machine-local state: `bash install-lean-lsp-session-hook.sh --remove` withdraws the hook from
  both settings files and deletes the installed copy; `setup-lean-mcp.sh --scope project --remove`
  per project withdraws each entry; `setup-lean-mcp.sh --scope global` restores the single global
  entry for the currently-open project, returning the machine to the task-203 model.
- Snapshot `~/.claude.json` (`cp ~/.claude.json ~/.claude.json.bak-205`) before Phase 9 so the
  full pre-task registration state can be restored in one move.
- The `~/.dotfiles` edit is deliberately left uncommitted; `git -C ~/.dotfiles checkout --
  config/claude/settings.json` reverts it (subject to the repo's own destructive-git rules).
