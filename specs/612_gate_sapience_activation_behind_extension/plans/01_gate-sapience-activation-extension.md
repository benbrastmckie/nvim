# Implementation Plan: Task #612

- **Task**: 612 - Gate every Sapience activation surface behind the sapience extension so Sapience runs only in repos that load it
- **Status**: [IMPLEMENTING]
- **Effort**: 12 hours
- **Dependencies**: Task 611 (completed)
- **Research Inputs**: specs/612_gate_sapience_activation_behind_extension/reports/01_gate-sapience-extension-scope.md
- **Artifacts**: plans/01_gate-sapience-activation-extension.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build the per-repository Sapience activation surface inside this repository's
`agent-system/extensions/sapience/` source store, so that loading the extension into a repo is
what turns Sapience on there. Three building blocks, none of which exist today: a per-project
MCP-registration triad mirroring the lean extension's shipped
`setup-lean-mcp.sh` / `lean-lsp-register-project.sh` / `install-lean-lsp-session-hook.sh` /
`verify-lean-mcp.sh` pattern; seven additional read-tool permission grants in
`settings-fragment.json` (11 total); and the five Sapience hooks moved into that same fragment's
`hooks` object so they exist only when the extension is loaded. No merge-engine work is needed —
the merge engine already handles both key shapes. No file outside
`agent-system/extensions/sapience/` (plus the user-level paths the install script seeds) is
edited, and no `/home/benjamin/.dotfiles` file is touched.

### Premise Re-Validation (Carried-Figure Discipline)

Every figure the dispatch description asserts was re-checked against live state at planning time.
All four extracted trigger lines and the description's three inventory claims hold unchanged:

| Claim | Check | Result |
|---|---|---|
| `manifest.json` has `provides.hooks: []`, no top-level `hooks` object | read `agent-system/extensions/sapience/manifest.json` | CONFIRMED, unchanged |
| `settings-fragment.json` carries only the 4 MCP write-tool grants | read the file | CONFIRMED (`sapience_remember`, `_wrapup`, `_handoff`, `_adddoc`), unchanged |
| `scripts/` holds only `sapience-remember.sh`, `sapience-retrieve.sh`, a capture test | `find` over the extension tree | CONFIRMED, unchanged; none touches `~/.claude.json` |
| The lean triad exists and is the model to mirror | read all four lean scripts + the hook | CONFIRMED, unchanged |
| The 5 hook command strings / timeouts / async flags | read `~/.dotfiles/config/claude/settings.json` (read-only) | CONFIRMED byte-for-byte against the description's item 3 |
| `~/.claude.json` has a top-level `.mcpServers.sapience` and zero `.projects[*].mcpServers.sapience` | `jq` over `~/.claude.json` | CONFIRMED: top-level present, per-project absent; 4 repos carry per-project `lean-lsp` |
| "the companion cannot be a state.json dependency edge" (line 17) | companion lives in `.dotfiles`' own numbering space | CONFIRMED; recorded in prose, companion named by its durable project name |
| "`~/.claude.json` ... never a `settings-fragment.json`/`.claude/` merge target" (line 30) | `merge_targets` in the manifest; merge engine's key handling | CONFIRMED |
| "never the top-level `.mcpServers` key" (line 34) | design constraint for the new writer | ADOPTED as a verified invariant, with one correction below |
| "edits go to the source store, never `.claude/**`" (line 120) | `.claude/` is gitignored (`.gitignore:6`), `.claude-extensions.json` is tracked | CONFIRMED |

**One correction to a premise the description leaves implicit.** The description says the new
writer must never touch the top-level `.mcpServers` key. That is correct as a constraint on what
this task WRITES, but it must not be read as licence to REMOVE the existing top-level
`.mcpServers.sapience` entry either. That entry is re-created unconditionally by
`.dotfiles`' `sapienceMcpServer` activation on every `home-manager switch` while
`programs.sapience.registerMcpServer` is true, so removing it from here would be undone, and
would also disable Sapience in every repo that currently depends on it. The consequence is
stated plainly in Goals/Non-Goals: **this task does not, and cannot, reach the end-state goal on
its own.** Until the companion lands, the top-level entry keeps registering Sapience in every
repo; the per-project entry this task adds simply takes precedence in repos that load the
extension (per `context/patterns/mcp-server-ownership.md`, confirmed empirically there).

### Prior Decisions: obligation check

The one recorded answer (cycle 1) routed through "correct task 612's description in
`specs/state.json`, then proceed to planning normally", with the obligation that the corrected
description state the extension-side scope and retain no instruction to edit `.dotfiles`-owned
files. **Verified discharged**: commit `a45f1cd17` ("correct task description to extension-side
activation-surface scope") landed, and the `## Description` this dispatch carries describes the
extension-side build and adds an explicit `EXPLICITLY OUT OF SCOPE` section naming
`modules/home/services/sapience.nix`, `config/claude/settings.json` and `docs/sapience.md` as the
companion's. No second obstruction remains; no `user_decision` is raised.

### Research Integration

The report's reconstruction is now the description's own content, so the plan is written against
the description directly. Three report findings are carried forward as load-bearing:

- The lean triad is a complete, shipped per-project precedent — this removes the only real
  feasibility risk, and each new script below names its specific model.
- The merge engine already supports a `hooks` object in a `settings-fragment.json`, with tracked
  merge and clean removal on unload. No merge-engine change is in scope.
- The report's correction stands: the per-project shape's precedent lives in the **lean
  extension's own scripts**, not in `sapience.nix` (whose `sapienceMcpServer` entry writes the
  **top-level** key). A planner or implementer looking in `sapience.nix` for a per-project
  example will not find one.

Two findings this planning pass established that the report did not, both verified by reading
code rather than inferring from it:

- **The hook-merge path is not the one the report's framing implies, and that is fine.**
  `is_hook_event_array` (merge.lua) requires *every* item in an event array to carry a `matcher`
  **string**. Four of the five Sapience hooks (`SessionStart`, `UserPromptSubmit`, `SessionEnd`,
  `Stop`) carry no `matcher`; only `PreToolUse` does. So four of them fall through to
  `deep_merge`'s generic array branch: appended with `vim.deep_equal` dedup and tracked as
  `appended`/`new_array`, which `unmerge_settings`' `remove_tracked` reverses exactly. Only
  `PreToolUse` takes the matcher-aware `merge_hook_event_array` path. **Both paths are tracked
  and cleanly reversible**, and `prune_empty_hooks` drops an emptied `hooks` key, so Phase 1 must
  NOT invent a `matcher` to force the identity path — adding `matcher: "startup"` to
  `SessionStart` would silently narrow the briefing from every session-start source to `startup`
  only, a behavior change nobody asked for.
- **The `prune_empty_hooks` fix that verification item 3 depends on is uncommitted.** It exists
  only as a working-tree diff on `merge.lua`/`merge_spec.lua` (+27/+58 lines). Recorded as Risk 5.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, and `roadmap_flag` is not
set. No roadmap phases are added.

## Goals & Non-Goals

**Goals**:
- A per-project MCP registration triad under `agent-system/extensions/sapience/` that
  registers/repairs `.projects["<abs path>"].mcpServers.sapience` in `~/.claude.json` for one
  project, gated on that repo's `.claude-extensions.json` showing
  `extensions.sapience.status == "active"`, and **removes** that entry again when it does not.
- Eleven permission grants (the 4 existing write-tool grants intact, plus 7 read-tool grants) and
  all five Sapience hooks present in `settings-fragment.json`, so both surfaces exist per-repo.
- Idempotent, `--remove`-capable install to stable user-level paths, and a verification script.
- Every extension doc (`manifest.json`, `EXTENSION.md`, `README.md`, `index-entries.json`, the two
  domain docs) stating the new per-repo activation contract with a correct hook count.

**Non-Goals**:
- Any edit to a `/home/benjamin/.dotfiles` file. The `_SAPIENCE_NOTE` rewrite,
  `modules/home/services/sapience.nix`, `config/claude/settings.json` and `docs/sapience.md`
  belong to the companion `retire_machine_wide_sapience_surface` task in that repository.
- `nix flake check`, `home-manager switch`/`build`, or any `.dotfiles`-rooted verification.
- The `~/.sapience/config.json` `folders`/`capture.projects` reconciliation owner action.
- Removing the top-level `~/.claude.json` `.mcpServers.sapience` entry, or narrowing the four
  write-tool grants (an accepted residual with its own named escape valve in
  `rules/sapience-write-path.md`).
- **Reaching the end-state goal.** Sapience keeps reaching every repo via the top-level entry and
  the machine-wide grants until the companion lands. This task builds the per-repo surface that
  makes the companion safe to run; it does not complete the gating on its own.
- Editing `core`'s `context/patterns/mcp-server-ownership.md`, whose sapience worked example this
  change eventually makes stale (Risk 4).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| 1. A user-level-only SessionStart registration is wiped by the next `home-manager switch`. `hooks` is in the enforced key set `[_NOTE,env,hooks,model,permissions,statusLine]` (verified in `~/.dotfiles/modules/home/core/dotfiles.nix`) and is reset from `.dotfiles`' `config/claude/settings.json` whenever that source has a `hooks` key — which it will keep, for the inhibitor and lean entries, even after the companion removes the Sapience ones. Lean's installer solves this by also writing `.dotfiles`; this task may not. | H | H | Accept and document as a named residual, the same shape as the write-grant residual already recorded in `rules/sapience-write-path.md`. The installer prints a loud, non-fatal warning naming the gap and the companion as the owner of durable user-level registration; `verify-sapience-mcp.sh` detects the missing registration so a post-switch loss is caught rather than silent; Phase 6 records it in `domain/per-repo-scoping.md` with that named escape valve. |
| 2. A new `SessionStart` entry collides with lean's in a repo loading both extensions. | M | L | The two live in different files (lean's in `~/.claude/settings.json`, Sapience's five in the per-repo `.claude/settings.local.json`) and the new registration hook's command string differs from lean's byte-for-byte, so the installer's exact-string idempotency check and the merge engine's dedup both see them as distinct. Verified **empirically** in Phase 7, not inferred — this is verification item 5. |
| 3. The writer cannot reproduce the nix-store interpreter path the current top-level entry uses (`/nix/store/...-python3-3.13.15/bin/python3`). | M | H | Resolved at planning time: `sapience.nix` defines `python = "${pkgs.python3}/bin/python3"` — a plain interpreter, no `withPackages` — and `~/.sapience/mcp.py` imports stdlib only (`json, os, re, sys, urllib.*, hashlib, tempfile, time`). So resolving `python3` to an absolute path via `command -v python3` at write time is functionally equivalent. The writer prefers the existing top-level entry's `command` when present (inheriting the pinned path) and falls back to `command -v python3`, refusing loudly if neither resolves. |
| 4. `core`'s `context/patterns/mcp-server-ownership.md` sapience worked example goes stale: it calls the 4-grant placement a nix-enforced carve-out and asserts a seven-tool read-only allow-list exists at user scope. | M | H | Out of this task's edit surface by acceptance criterion 2. Note that it only becomes *inaccurate* once the companion removes the user-scope read grants — until then both surfaces coexist and the text still holds. Phase 6 records the coming staleness and names a follow-up task (updating that worked example together with the two halves) as the escape valve, keeping `review-gate-boundary.md`'s `## The Permission Grant's Repository-Scoped Tradeoff` heading **anchor text unchanged** so the inbound citation does not dangle. |
| 5. Verification item 3 ("no `[]`-valued `hooks` key left behind") depends on the uncommitted `prune_empty_hooks` working-tree diff on `merge.lua`. | M | M | Phase 7 asserts the fix is present before running the unload check and reports loudly if it is absent, rather than attributing a `[]` residue to this task's own fragment. The fix is additive and pre-existing; this task neither owns nor modifies it. |
| 6. Unloading the extension cannot remove the per-project `~/.claude.json` entry through the merge engine, which only governs in-tree merge targets. | H | H | The registration hook is **bidirectional**: it removes `.projects[<cwd>].mcpServers.sapience` when the repo's `.claude-extensions.json` no longer shows sapience active. One session-start of lag, documented; `install --remove` and `verify-sapience-mcp.sh` cover the immediate case. |
| 7. `provides.scripts` and `index-entries.json`'s `line_count` are derived surfaces whose drift fails Gate 3 (Rules Q and R, both FAIL-severity). | M | H | Each phase that adds a script declares `manifest.json` in its own `Files to modify` and runs `sync-manifest-scripts.sh --write`; Phase 6 runs `generate-context-line-counts.sh --write`. Declared per phase, never deferred to a reconciliation phase. |
| 8. `EXTENSION.md` measures 53 by `wc -l` against the Rule U bound (FAIL under `SCHEMA_CONFORMANCE_GATE_MODE`), so there is little room for a whole new activation contract. | M | H | Phase 6 **replaces** the now-wrong "Already ambient" paragraph rather than appending beside it, and re-checks `wc -l` before closing. Recorded explicitly as that phase's own Scope Hypothesis. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 2, 3, 4 |
| 5 | 6 | 1, 2, 3, 4, 5 |
| 6 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

**Plan-authoring gotcha query (Stage 4 item 13)**: the deployed context index was queried for a
`project/**` entry whose `load_when.task_types[]` contains `meta` AND whose `keywords`/`topics`
name `plan-authoring`. **Zero hits** — the only `plan-authoring` entry is
`project/lean4/patterns/plan-authoring-gate-collisions.md`, whose `load_when.task_types` is
`["lean4"]` only. Zero hits is the normal case for this task type, not an error.

---

### Phase 1: Permission grants and the five hooks in `settings-fragment.json` [COMPLETED]

**Goal**: `settings-fragment.json` carries all 11 permission grants and all 5 Sapience hooks, so
both surfaces are present per-repo whenever the extension is loaded.

**Tasks**:
- [x] Add the 7 read-tool grants to `permissions.allow`, keeping the 4 existing write-tool grants
      byte-identical and in place: `mcp__sapience__sapience`, `mcp__sapience__sapience_search`,
      `mcp__sapience__sapience_briefing`, `mcp__sapience__sapience_context`,
      `mcp__sapience__sapience_ask`, `mcp__sapience__sapience_outstanding`,
      `mcp__sapience__sapience_papers`. Explicit enumeration, never a wildcard (the
      `mcp-server-ownership.md` carve-out's second requirement). *(completed)*
- [x] Add a `hooks` object with the five entries, each command string, `timeout` and `async` flag
      copied byte-for-byte from `~/.dotfiles/config/claude/settings.json` (READ ONLY — confirm by
      diffing, never by retyping): `SessionStart` -> `mcp.py --briefing-text`;
      `UserPromptSubmit` -> `sapience_cli.py hook prompt` (`timeout: 3`); `PreToolUse` with
      `matcher: "Edit|Write|MultiEdit"` -> `sapience_cli.py hook tool` (`timeout: 3`);
      `SessionEnd` -> `mcp.py --receipt` (`async: true`); `Stop` -> `mcp.py --effect-line`
      (`timeout: 3`). *(completed: verified byte-identical via exact-string search over the
      dotfiles JSON, not by eye)*
- [x] Do **not** add a `matcher` to any of the four entries that lack one upstream. See the
      Research Integration finding: `matcher: "startup"` on `SessionStart` would narrow the
      briefing to one session-start source, and the matcher-less entries already merge and
      unmerge correctly through `deep_merge`'s tracked generic-array branch. *(completed)*
- [x] Do **not** add a sixth hook here. The MCP-registration `SessionStart` hook is installed at
      user level by Phase 4, for the reason Phase 3 records. *(completed)*
- [x] Carry forward the two deliberate rulings in prose, in this phase's commit message and in
      Phase 6's docs: `statusLine` belongs to `hooks/statusline-push.sh` and is deliberately NOT
      wired to Sapience; `sapience_cli.py`'s own `hook session` and `hook stop` are deliberately
      NOT wired, because each would duplicate an `mcp.py` hook and print a second line per turn.
      *(completed: ruling recorded here and will be restated in Phase 6's docs)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly 11 grants and exactly 5 hook events, and that
the five command strings are byte-identical to the live `.dotfiles` values read at planning time.
Confirm at implementation time by `jq` over the written fragment
(`.permissions.allow | length == 11`, `.hooks | keys | length == 5`) and by a read-only
string-equality comparison of each command against
`~/.dotfiles/config/claude/settings.json` — not by eye.

**Tier Justification**: `suite_selection_select` maps
`agent-system/extensions/sapience/settings-fragment.json` to exactly one suite, so
`bash .claude/scripts/tests/run-all.sh --only test-lint-hook-registration-paths.sh` is the
cheapest check that covers this edit; the merged-output assertion this fragment feeds is
verification item 1, owned by Phase 7, which pays the deploy.

**Files to modify**:
- `agent-system/extensions/sapience/settings-fragment.json` - 7 read-tool grants added (11
  total); new `hooks` object with the 5 Sapience hooks

**Verification**:
- `jq -e '.permissions.allow | length == 11' agent-system/extensions/sapience/settings-fragment.json`
- `jq -e '[.hooks | keys[]] | sort == ["PreToolUse","SessionEnd","SessionStart","Stop","UserPromptSubmit"]' agent-system/extensions/sapience/settings-fragment.json`
- Each of the 5 command strings compares equal to its `.dotfiles` counterpart (read-only `jq`
  comparison, zero diffs).
- `bash .claude/scripts/tests/run-all.sh --only test-lint-hook-registration-paths.sh` green.

---

### Phase 2: The writer — `scripts/setup-sapience-mcp.sh` and its test suite [COMPLETED]

**Goal**: a per-project writer that registers, repairs, or removes
`.projects["<abs path>"].mcpServers.sapience` in `~/.claude.json` for exactly one project,
preserving every other key in that file, with a test suite that covers it.

**Tasks**:
- [x] Write `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh`, modelled on
      `agent-system/extensions/lean/scripts/setup-lean-mcp.sh`. Options:
      `--project PATH`, `--scope project|global|both` (default `project`), `--dry-run`,
      `--remove`, `--retire-global`, `--quiet`, `--help`. *(completed)*
- [x] Write only `.projects[$path].mcpServers.sapience` via a whole-file `jq` merge with
      `--arg path` (never literal interpolation), relying on jq's assignment autovivification for
      the intermediate objects, and `mktemp` + `mv` for the write. Never the top-level
      `.mcpServers` key. *(completed)*
- [x] Build the entry as `{type:"stdio", command:<interpreter>, args:[$HOME/.sapience/mcp.py],
      env:{SAPIENCE_HOST:<host>} + (SAPIENCE_TOKEN only when the token is non-empty)}`, reading
      the token from `~/.sapience/config.json`'s `.token` with the same
      "register without a token until config.json has one" fallback `.dotfiles`'
      `sapienceMcpServer` entry uses today. *(completed)*
- [x] Resolve `<interpreter>` as: the existing top-level `.mcpServers.sapience.command` if
      present (inheriting the pinned nix-store path), else `command -v python3` resolved to an
      absolute path, else refuse loudly with a non-zero exit. Resolve `<host>` from
      `~/.sapience/config.json` when it carries one, else default to `https://app.spnc.ai`.
      Record in a header comment that `mcp.py` imports stdlib only and `sapience.nix` pins a
      plain `pkgs.python3`, so the fallback is equivalent rather than merely convenient.
      *(completed)*
- [x] `--quiet`: silent and exit 0 when the entry already matches byte-for-byte; exactly one line
      when it writes. This is the contract the Phase 3 hook keys its own silence off. *(completed)*
- [x] `--retire-global`: remove ONLY the top-level entry, leaving `.projects` untouched. Document
      in its own help text that it is **inert in practice** until the companion task disables
      `programs.sapience.registerMcpServer`, because the nix activation re-creates that entry on
      every switch — and that running it today would also disable Sapience in every repo still
      relying on the machine-wide entry. Phase 7 must not run it. *(completed)*
- [x] Add a header paragraph citing `context/patterns/mcp-server-ownership.md` for the ownership
      invariant on this class of outside-the-tree write, and its
      "a command path must never resolve inside a repository's own `.claude/` tree" invariant.
      *(completed)*
- [x] Create `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`,
      modelled on lean's `tests/test-lean-mcp-registration.sh`, exercising the writer against a
      temporary `HOME` fixture: fresh register; idempotent re-run (no write, exit 0, silent under
      `--quiet`); repair of a diverged entry; `--remove`; token-absent fallback; and the
      key-preservation property (an unrelated top-level key and an unrelated
      `.projects[other]` entry both survive a write byte-for-byte). *(completed: 10/10 cases pass;
      hook/installer/verifier cases self-skip with INFO until Phases 3-5 add those scripts)*
- [x] Declare both new files by running
      `bash .claude/scripts/sync-manifest-scripts.sh --write` and reviewing the resulting
      `provides.scripts` insertion (Rule Q is a Gate 3 FAIL; the array is derived, not curated).
      *(completed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that `suite_selection_select` currently returns
`__FULL_SWEEP__` for `scripts/setup-sapience-mcp.sh` (measured at authoring time — no suite
references that basename yet) and that creating `tests/test-sapience-mcp-registration.sh`, which
names it, establishes the mapping via the library's basename-reference stratum. The implementer
MUST confirm this by re-running `suite_selection_select` on the writer's path after the suite
lands and seeing the new suite name returned; if it still returns the sentinel, the suite does
not reference the basename and the mapping has not been created.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` over this phase's
touched-path set, so no existing suite covers it and none is claimed; the cheapest honest check
is the source-store gate subset
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`,
which covers the derived `provides.scripts` insertion (Rule Q) and the task-reference lint.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` - new per-project writer
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - new suite
- `agent-system/extensions/sapience/manifest.json` - `provides.scripts` entries for both, written
  by `sync-manifest-scripts.sh --write` (coupled derived surface, regenerated in this phase)

**Verification**:
- `bash -n` and a `shellcheck` pass on the writer.
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` green.
- `bash .claude/scripts/sync-manifest-scripts.sh --check` exits 0.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no Rule Q finding for this extension.

---

### Phase 3: The bidirectional `SessionStart` hook [COMPLETED]

**Goal**: a `SessionStart` hook that registers the per-project entry when the session's repo has
the sapience extension active, and removes it again when it does not.

**Tasks**:
- [x] Write `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh`, modelled
      on `agent-system/extensions/lean/hooks/lean-lsp-register-project.sh`. *(completed)*
- [x] Detection, as the Sapience analogue of lean's lakefile test: resolve the project root from
      `.claude-extensions.json` at CWD or at the git root, and read
      `.extensions.sapience.status == "active"` from it. `.claude-extensions.json` is **tracked**
      and `.claude/` is **gitignored** (both verified), so this gate works in a fresh worktree
      with no deploy — which is exactly why the install target must be user-level. *(completed)*
- [x] Resolve the writer from the stable user-level path
      `$HOME/.claude/scripts/setup-sapience-mcp.sh`, never from the calling repository's own
      (possibly nonexistent) `.claude/` tree. Record the invariant and its citation
      (`mcp-server-ownership.md`'s `.claude/`-path boundary) in the header. *(completed)*
- [x] Active -> invoke the writer with `--project <root> --scope project --quiet`. *(completed)*
- [x] NOT active (status absent, not `"active"`, or `.claude-extensions.json` missing) **and** a
      `.projects[<root>].mcpServers.sapience` entry exists -> invoke the writer with
      `--project <root> --scope project --remove --quiet`. This is the only mechanism that can
      satisfy verification item 3's per-project-entry clause, since the merge engine governs only
      in-tree merge targets. Document the one-session-start lag. *(completed)*
- [x] Keep lean's measured behavior: silent (`{}`) on an already-correct session; an
      `additionalContext` notice ONLY when it actually writes or removes, because a SessionStart
      hook's own write is not reliably visible within the same session. Always exit 0; always
      emit exactly one line of valid JSON; degrade to a silent `{}` on every failure path
      (unwritable `~/.claude.json`, missing `jq`, writer error, writer not installed).
      *(completed: a one-line-JSON divergence from the lean model was caught and fixed -- `jq
      -Rs` pretty-prints; switched to `jq -cRs`)*
- [x] Extend `tests/test-sapience-mcp-registration.sh` with hook-level cases: active repo
      registers; already-correct repo is silent with `{}`; inactive repo with an existing entry
      removes it and emits a notice; inactive repo with no entry is silent; missing writer is
      silent; and every path emits exactly one line of parseable JSON. *(completed: 6/6 hook
      cases pass)*
- [x] Declare the hook in `manifest.json`'s `provides.hooks` (today `[]`), so it deploys to
      `.claude/hooks/` exactly as lean's does. Re-run
      `bash .claude/scripts/sync-manifest-scripts.sh --check`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the hook path is unmappable by the suite selector.
Measured at authoring time: `suite_selection_select` returns `__FULL_SWEEP__` for
`agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh`, and also for lean's
already-suite-covered `hooks/lean-lsp-register-project.sh` — the `hooks/` tree is outside the one
scripts tree the library maps against, so no suite will ever map it. Confirm by re-running the
selector; do not expect the Phase 2 suite to change this result.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` over this phase's
touched-path set, so no existing suite covers it and none is claimed; the cheapest honest check
is the source-store gate subset
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`,
which covers the `provides.hooks` declaration and the task-reference lint.

**Files to modify**:
- `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` - new bidirectional
  SessionStart hook
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - hook-level
  cases added
- `agent-system/extensions/sapience/manifest.json` - `provides.hooks` populated

**Verification**:
- `bash -n` and `shellcheck` on the hook.
- Every hook invocation path emits exactly one line that `jq -e .` accepts, and exits 0.
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` green.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  clean for this extension.

---

### Phase 4: The install script [NOT STARTED]

**Goal**: an idempotent, `--remove`-capable installer that seeds the hook and the writer to
stable user-level paths and registers the `SessionStart` entry, touching no `.dotfiles` file.

**Tasks**:
- [ ] Write `agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh`,
      modelled on `agent-system/extensions/lean/scripts/install-lean-lsp-session-hook.sh`.
      Options: `--dry-run`, `--remove`, `--help`.
- [ ] Copy (and `chmod +x`) two files:
      `hooks/sapience-mcp-register-project.sh` -> `$HOME/.claude/hooks/`, and
      `scripts/setup-sapience-mcp.sh` -> `$HOME/.claude/scripts/`. User-level, never inside any
      repository's disposable `.claude/` tree.
- [ ] Register the entry in `$HOME/.claude/settings.json` only, idempotently, keyed on an exact
      command string pinned in one variable and never changed casually (the same mechanism lean's
      installer uses for both idempotency and `--remove`).
- [ ] **Deliberately omit lean's second write target.** Lean's installer also writes
      `$HOME/.dotfiles/config/claude/settings.json`; this task is forbidden to touch `.dotfiles`
      (acceptance criterion 2). Record the divergence from the model in a header paragraph so a
      future reader does not "repair" it back.
- [ ] Emit a loud, non-fatal WARNING on every install run naming the resulting durability gap
      precisely: `hooks` is an enforced key (`[_NOTE,env,hooks,model,permissions,statusLine]` in
      `~/.dotfiles/modules/home/core/dotfiles.nix`), reset from `.dotfiles`'
      `config/claude/settings.json` on every `home-manager switch` while that source carries a
      `hooks` key — so this registration must be re-run after a switch until the companion
      `retire_machine_wide_sapience_surface` task takes ownership of a durable entry. Name the
      re-run command in the warning text.
- [ ] `--remove`: delete both installed files and remove the `SessionStart` entry from
      `$HOME/.claude/settings.json`, fully reversing the install. Additionally offer to remove
      this project's own `.projects[...].mcpServers.sapience` entry via the writer's `--remove`,
      so the immediate case does not wait for the next session start.
- [ ] Extend `tests/test-sapience-mcp-registration.sh`: install into a temporary `HOME`; assert a
      second run changes nothing (byte-identical settings file and both installed files);
      `--remove` leaves the fixture `HOME` exactly as it began; `--dry-run` writes nothing; and
      an absent `$HOME/.claude/settings.json` is handled without a crash.
- [ ] `bash .claude/scripts/sync-manifest-scripts.sh --write`, then `--check`.

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the installer is fully idempotent and fully reversible —
"a second run changes nothing" and "`--remove` reverses it" are verification items 4, not
properties to assume. Confirm mechanically: capture a `sha256sum` manifest of the fixture `HOME`
before install, after install, after a second install, and after `--remove`, and assert
run-1 == run-2 and pre-install == post-remove.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` over this phase's
touched-path set, so no existing suite covers it and none is claimed; the installer's whole blast
radius is two user-level paths plus one settings file, and the cheapest honest repository-level
check is
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh` - new installer
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - install /
  idempotency / `--remove` cases added
- `agent-system/extensions/sapience/manifest.json` - `provides.scripts` entry for the installer

**Verification**:
- `bash -n` and `shellcheck` on the installer.
- The four-point `sha256sum` manifest comparison above holds (idempotent; fully reversed).
- The install run's stderr carries the durability warning.
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` green.

---

### Phase 5: The verification script [NOT STARTED]

**Goal**: a verifier that checks this task's acceptance surfaces for one project and exits with a
meaningful status, so a post-`home-manager switch` loss or a partial install is caught.

**Tasks**:
- [ ] Write `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`, modelled on
      `agent-system/extensions/lean/scripts/verify-lean-mcp.sh`. Options: `--project PATH`,
      `--quiet`, `--help`. Exit codes: 0 valid, 1 missing or invalid, 2 project-path mismatch.
- [ ] Checks, each reported by name: (a) `.claude-extensions.json` shows
      `extensions.sapience.status == "active"` for this project; (b)
      `.projects[<abs path>].mcpServers.sapience` exists in `~/.claude.json` and matches the
      canonical entry (`command`, `args`, `env.SAPIENCE_HOST`, and whether `SAPIENCE_TOKEN` is
      present given `~/.sapience/config.json`); (c) both installed user-level files exist and are
      executable; (d) the `SessionStart` entry is present in `$HOME/.claude/settings.json` — the
      check that catches a post-switch loss, and whose failure message names Risk 1 and the
      re-run command; (e) the merged `.claude/settings.local.json` carries all 11 grants and all
      5 hooks when the extension is loaded.
- [ ] Report the surviving top-level `.mcpServers.sapience` entry as **expected, not drift**,
      until the companion lands — the inverse of lean's Check 9. Say so explicitly in the output
      so a reader is not sent to remove it.
- [ ] Extend `tests/test-sapience-mcp-registration.sh` with verifier cases over fixture `HOME`s:
      all-green; missing per-project entry; diverged entry; missing `SessionStart` registration;
      inactive extension; and the exit-code mapping for each.
- [ ] `bash .claude/scripts/sync-manifest-scripts.sh --write`, then `--check`.

**Timing**: 1.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts five named checks and three exit codes. Confirm by
driving the verifier against a fixture `HOME` for each failure mode and asserting both the exit
code and the named check in the output — not by reading the script.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` over this phase's
touched-path set, so no existing suite covers it and none is claimed; the verifier is read-only
over `~/.claude.json`, `~/.claude/settings.json`, `.claude-extensions.json` and
`.claude/settings.local.json`, so the cheapest honest repository-level check is
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` - new verifier
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - verifier
  cases added
- `agent-system/extensions/sapience/manifest.json` - `provides.scripts` entry for the verifier

**Verification**:
- `bash -n` and `shellcheck` on the verifier.
- Each of the five checks fires independently in its own fixture, with the documented exit code.
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` green.

---

### Phase 6: Documentation of the per-repo activation contract [NOT STARTED]

**Goal**: every extension doc states the new per-repo activation contract, with a correct hook
count, and both derived index surfaces are regenerated rather than hand-maintained.

**Tasks**:
- [ ] `EXTENSION.md`: **replace** the now-wrong "Already ambient" paragraph (confirmed present at
      planning time, lines 6-7, asserting the MCP registration and "the three
      SessionStart/SessionEnd/Stop hooks" live in `~/.dotfiles`) with the per-repo activation
      contract: 11 grants, 5 hooks in the fragment, and the user-level MCP-registration triad.
      Replace rather than append — the file is 53 lines against a hard 60-line ceiling.
- [ ] State the correct hook count explicitly and unambiguously: **five** hooks in
      `settings-fragment.json` (SessionStart, UserPromptSubmit, PreToolUse, SessionEnd, Stop),
      **plus one** separate MCP-registration `SessionStart` hook installed at user level by
      `install-sapience-mcp-session-hook.sh` — six hook surfaces in total, of which only five are
      extension-merged. Use the same phrasing in `README.md` and the domain docs so no reader has
      to reconcile two counts.
- [ ] `README.md`: update `## File Inventory` with the four new scripts and the new hook, and
      `## The Three Gaps This Extension Closes` to reflect that the activation surface is now the
      extension's own.
- [ ] `domain/per-repo-scoping.md`: add a section documenting the MCP-registration triad, the
      stable-user-level-path invariant and its `mcp-server-ownership.md` citation, the
      bidirectional hook's one-session-start removal lag, and **Risk 1 as a named residual with a
      named escape valve** (the companion task, or a follow-up, taking ownership of a durable
      user-level `SessionStart` entry) — the same shape as the write-grant residual in
      `rules/sapience-write-path.md`. Its `## Hazards` and `## No Lifecycle Hook` sections both
      exist (confirmed) and are the right homes.
- [ ] `domain/review-gate-boundary.md`: update `## The Permission Grant's Repository-Scoped
      Tradeoff` to cover all 11 grants and to record that, with registration moving to local
      (per-project) scope, the grants become scope-matched to the registration rather than a
      narrower-than-registration carve-out. **Keep that heading's anchor text byte-identical** —
      `core`'s `mcp-server-ownership.md` cites it by name, and `core/` is outside this task's edit
      surface (Risk 4). Record the coming staleness of that worked example and name the follow-up
      that fixes it.
- [ ] `manifest.json`: update the `description` field to state the activation-surface role.
- [ ] `index-entries.json`: refresh the `summary`/`keywords`/`topics` of the two edited domain
      entries, then run `bash .claude/scripts/generate-context-line-counts.sh --write` and
      `--check` for the `line_count` values the edits invalidate (Rule R is a Gate 3 FAIL).
- [ ] Re-check no task-number reference and no record-versioning language entered any file
      outside `specs/**` (acceptance criterion 3): state the contract as it now is, never as "no
      longer in `.dotfiles`" or "previously machine-wide".
- [ ] `bash .claude/scripts/sync-manifest-scripts.sh --check` exits 0.

**Timing**: 2 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts `EXTENSION.md` ends at or below the Rule U bound, from a
measured baseline of 53 (`wc -l`, taken at planning time). The edit must be a net REPLACEMENT of
the stale "Already ambient" paragraph, not an addition beside it. Confirm with
`wc -l agent-system/extensions/sapience/EXTENSION.md` before closing the phase, never by
estimating; if the replacement does not fit, compress it further rather than relaxing the bound.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` over this phase's
touched-path set (the two pure-guidance domain docs are unmappable, which forces the sentinel for
the whole set), so no suite is claimed; this is the source-store markdown sub-case, whose check is
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
— Rules R, T and U plus the task-reference lint, run with the repository root as `TARGET`.

**Files to modify**:
- `agent-system/extensions/sapience/EXTENSION.md` - "Already ambient" paragraph replaced by the
  per-repo activation contract; stays under 60 lines
- `agent-system/extensions/sapience/README.md` - file inventory and gaps sections updated
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` -
  registration triad, user-level-path invariant, removal lag, Risk 1 residual
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` -
  11-grant tradeoff section, anchor text unchanged
- `agent-system/extensions/sapience/manifest.json` - `description` updated
- `agent-system/extensions/sapience/index-entries.json` - summaries and keywords refreshed, and
  the derived line_count values regenerated by `generate-context-line-counts.sh --write` (coupled
  derived surface, regenerated in this phase because Rule R is commit-blocking)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim`
  reports no Rule U finding for this extension (the sanctioned entry point for the
  `EXTENSION.md` length bound; `wc -l` is the in-phase pre-check, not the gate).
- `bash .claude/scripts/generate-context-line-counts.sh --check` exits 0.
- `bash .claude/scripts/sync-manifest-scripts.sh --check` exits 0.
- `bash .claude/scripts/check-task-references.sh` and the record-versioning lint report nothing
  new outside `specs/**`.
- The hook count reads identically in `EXTENSION.md`, `README.md` and both domain docs.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  clean for this extension.

---

### Phase 7: End-to-end verification and acceptance evidence [NOT STARTED]

**Goal**: all five of this task's verification items evidenced empirically against a real deploy,
and the complete gate set green.

**Tasks**:
- [ ] Assert the `prune_empty_hooks` fix is present in
      `lua/neotex/plugins/ai/shared/extensions/merge.lua` before the unload check (Risk 5). If it
      is absent, report that loudly and do not attribute a `[]` residue to this task's fragment.
- [ ] Deploy the source store so the extension's new surfaces reach a tree, then load the
      sapience extension into a repo and capture the merged `.claude/settings.local.json`.
- [ ] **Verification item 1**: the merged `.claude/settings.local.json` carries all 11 permission
      grants and all 5 hooks. Assert with `jq`, not by eye.
- [ ] Run `install-sapience-mcp-session-hook.sh`, then start a session in that repo.
      **Verification item 2**: `.projects["<that repo's abs path>"].mcpServers.sapience` is
      present in `~/.claude.json`, AND no other key in that file was disturbed. Evidence the
      second clause by diffing a `jq -S` snapshot taken before against one taken after and
      confirming the per-project entry is the only addition — the top-level
      `.mcpServers.sapience` entry and all four `.projects[*].mcpServers."lean-lsp"` entries
      included.
- [ ] **Verification item 3**: unload the extension and confirm all three surfaces are gone —
      the 11 grants and 5 hooks removed from `.claude/settings.local.json` with **no `[]`-valued
      `hooks` key** left behind, and the per-project `~/.claude.json` entry removed (by the
      bidirectional hook on the next session start, or immediately via
      `install-sapience-mcp-session-hook.sh --remove`). Note which mechanism produced it.
- [ ] **Verification item 4**: the installer is idempotent and `--remove` fully reverses it,
      re-confirmed outside the fixture, against the real `$HOME`, using the Phase 4
      `sha256sum`-manifest method.
- [ ] **Verification item 5**: in a repo loading **both** lean and sapience, both `SessionStart`
      hooks run and neither displaces the other — verified **empirically**, not inferred from the
      dedup implementation. Record where each entry lives (lean's in `~/.claude/settings.json`,
      Sapience's five in `.claude/settings.local.json`, the registration hook's in
      `~/.claude/settings.json` alongside lean's) and assert both command strings are present and
      distinct after the install.
- [ ] Do **not** run `setup-sapience-mcp.sh --retire-global` (Phase 2's ruling): it would be
      undone by the next `home-manager switch` and would disable Sapience in every repo still
      relying on the machine-wide entry.
- [ ] Re-confirm acceptance criterion 2 mechanically: `git status --short` shows every change
      under `agent-system/extensions/sapience/` (plus `specs/**` artifacts), and
      `git -C /home/benjamin/.dotfiles status --short` shows no change attributable to this task.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (all gates, no
      `--skip-slow`, no `--only-gate`), plus `bash .claude/scripts/tests/run-all.sh` and
      `bash .claude/scripts/validate-state.sh`.
- [ ] Record all five verification items' evidence in this task's own summary artifact
      (acceptance criterion 1).

**Timing**: 2 hours

**Depends on**: 1, 2, 3, 4, 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that a deploy plus one extension load/unload cycle is
sufficient to evidence all five verification items. Confirm item by item as each is captured; if
any item cannot be evidenced from the load/unload cycle (most likely item 2's
"no other key disturbed" clause, which needs before/after snapshots taken around a real session
start), capture the missing evidence directly rather than inferring it from the mechanism.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration (the deploy script and the
  extension picker's load/unload entries), so it claims the entire deployed tree for admission
  purposes
- `specs/612_gate_sapience_activation_behind_extension/summaries/01_gate-sapience-activation-extension-summary.md` -
  acceptance evidence for all five verification items

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` green across the complete gate set (no `--skip-slow`,
  no `--only-gate`).
- `bash .claude/scripts/tests/run-all.sh` green.
- `bash .claude/scripts/validate-state.sh` green.
- All five verification items individually evidenced, each with its captured `jq`/diff output.
- `git -C /home/benjamin/.dotfiles status --short` shows nothing from this task.

## Testing & Validation

- [ ] `test-sapience-mcp-registration.sh` covers the writer (register, idempotent re-run, repair,
      remove, token-absent fallback, key preservation), the hook (all six paths, each emitting one
      line of valid JSON and exit 0), the installer (install, idempotency, `--remove`,
      `--dry-run`, absent settings file), and the verifier (five checks, three exit codes).
- [ ] `settings-fragment.json` asserts 11 grants and 5 hook events, with each command string
      equal to its `.dotfiles` counterpart.
- [ ] Load/unload round trip leaves `.claude/settings.local.json` with no residual grants, no
      residual hooks, and no `[]`-valued `hooks` key.
- [ ] `~/.claude.json` key preservation holds across a write (before/after `jq -S` diff).
- [ ] Lean + sapience coexistence verified empirically in a repo loading both.
- [ ] Gate 3 clean for Rules Q, R, T and U; Gate 4 clean; the complete gate set green in Phase 7.

## Artifacts & Outputs

- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh`
- `agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh`
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`
- `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh`
- Updated `settings-fragment.json`, `manifest.json`, `EXTENSION.md`, `README.md`,
  `index-entries.json`, `domain/per-repo-scoping.md`, `domain/review-gate-boundary.md`
- This task's summary artifact carrying all five verification items' evidence

## Rollback/Contingency

Every change is additive and confined to `agent-system/extensions/sapience/` plus two user-level
files, so rollback is per-surface and needs no snapshot of unrelated work:

- **User-level surfaces**: `bash agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh --remove`
  deletes both installed files and the `SessionStart` entry, and removes this project's
  per-project `~/.claude.json` entry. Verification item 4 is exactly this reversal, so a green
  Phase 4 is also the rollback rehearsal.
- **In-repo surfaces**: unloading the extension removes the 11 grants and 5 hooks from every
  consuming repo's `.claude/settings.local.json` through the merge engine's own `unmerge_settings`
  path. Reverting the source-store commits then restores the extension to its pre-task shape.
- **Nothing to roll back machine-wide**: the top-level `~/.claude.json` entry and the
  `.dotfiles`-held grants and hooks are untouched throughout, so Sapience keeps working in every
  repo regardless of how far this task got. That is the deliberate ordering property the
  description's HARD constraint names, and it is what makes partial completion safe.
- If Phase 7 reveals the merge engine cannot remove a surface cleanly, stop before marking the
  task complete and report it: the defect would be in `merge.lua` (not in this extension), and
  fixing it there is outside this task's declared scope.
