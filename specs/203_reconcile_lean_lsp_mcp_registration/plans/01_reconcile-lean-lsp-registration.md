# Implementation Plan: Task #203

- **Task**: 203 - Reconcile lean-lsp MCP registration with the source store's sanctioned wrapper-free mechanism
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/203_reconcile_lean_lsp_mcp_registration/reports/01_reconcile-lean-lsp-registration.md
- **Artifacts**: plans/01_reconcile-lean-lsp-registration.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The live `~/.claude.json` registers `lean-lsp` against a hand-authored wrapper script inside
`~/Projects/BimodalLogic/.claude/scripts/`, a gitignored deploy tree where that file no longer
exists — producing a silent ENOENT at every session spawn for every repository that does not
override the global entry. Research confirmed the wrapper is an orphan of a hand-edit, not a
missing source-store provision: the sanctioned `uvx lean-lsp-mcp` + `LEAN_PROJECT_PATH` shape
already exists in `core/scripts/setup-lean-mcp.sh`. This plan repairs the two source-store
scripts that cannot currently perform or detect that reconciliation, records the durable
invariant whose violation caused the defect, then reconciles the live config and retires
cslib's orphaned copy. Done means an actual lean-lsp server start with a real tool call
succeeding in BOTH `~/Projects/BimodalLogic` and `~/Projects/cslib`, observed from fresh
sessions — never a green verifier alone.

### Research Integration

The research report resolved all five dispatch questions with direct evidence: the wrapper is
unnecessary (a), the NixOS PATH export is not load-bearing because elan is a system package
reachable via `/run/current-system/sw/bin` alone (b), both `--lean-project-path` and
`LEAN_PROJECT_PATH` are genuinely supported with CLI taking precedence (c), user scope remains
the correct registration surface (d), and cslib's wrapper should be retired rather than adopted
(e). Its recommendation to record an explicit "command paths must never resolve inside a repo's
own `.claude/` tree" invariant in `mcp-server-ownership.md` is carried into Phase 3.

**Three defects found during plan construction that the research pass did not surface.** Each
was confirmed empirically and each is load-bearing — without them the report's headline remedy
("re-run `setup-lean-mcp.sh`") does not actually work:

1. **`setup-lean-mcp.sh` cannot repair a divergent entry.** Its "already configured" branch
   compares and updates only `env.LEAN_PROJECT_PATH`; it never rewrites `command` or `args`.
   Simulating the exact jq the script would run against the live broken entry yields:
   ```json
   {"type":"stdio",
    "command":"/home/benjamin/Projects/BimodalLogic/.claude/scripts/lean-lsp-mcp-wrapper.sh",
    "args":["--lean-project-path","/home/benjamin/Projects/BimodalLogic"],
    "env":{"LEAN_PROJECT_PATH":"/home/benjamin/Projects/BimodalLogic"}}
   ```
   — still the dead wrapper, still ENOENT. Worse, had the divergent entry carried a matching
   `LEAN_PROJECT_PATH`, the script would print "already configured with correct project path.
   No changes needed" and exit 0 while entirely blind to the broken command. Shape drift is
   invisible to the script's idempotency check.

2. **`verify-lean-mcp.sh` can PASS on a config that cannot spawn.** A wrong `command` (Check 3)
   and wrong `args` (Check 4) are `warn` only and do not affect the exit code; only a missing
   `LEAN_PROJECT_PATH` fails. Today's entry fails solely because it happens to lack the env var.
   The severity assignment is backwards: an unspawnable command is the more serious condition.
   The companion drift-detection task will wire this verifier into an automated moment, so it
   must fail on a dead command before that wiring can detect anything.

3. **The sanctioned mechanism refuses to run in cslib at all.** Both scripts auto-detect the
   project path by testing for `lakefile.lean`. `~/Projects/cslib` uses `lakefile.toml`
   (`~/Projects/BimodalLogic` uses `lakefile.lean`). Run from cslib, both scripts exit with
   "Error: Could not detect Lean project path." This is very likely the original reason cslib
   acquired a hand-authored wrapper: the sanctioned path did not work there. Consequently
   `lakefile.toml` support is a prerequisite for retiring cslib's wrapper, not an enhancement.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- Make `setup-lean-mcp.sh` able to reconcile a divergent `lean-lsp` entry to the sanctioned
  `uvx lean-lsp-mcp` + `LEAN_PROJECT_PATH` shape, overwriting `command`/`args`/`env` wholesale.
- Make `verify-lean-mcp.sh` fail (not warn) on a command or args shape that cannot spawn, and
  detect a project-scoped override that shadows the global entry.
- Add `lakefile.toml` detection to both scripts so the sanctioned mechanism works in every Lean
  project on this machine.
- Record the durable invariant: an `mcpServers` `command` path must never resolve inside any
  repository's own `.claude/` deploy tree.
- Reconcile the live `~/.claude.json` global entry and retire cslib's orphaned wrapper and its
  project-scoped override.
- Prove the fix by an observed server spawn plus a real tool call in both repos.

**Non-Goals**:
- Wiring `verify-lean-mcp.sh` into an automated detection moment. That is the companion task in
  this batch, which depends on this one. This task decides WHAT correct registration is; that
  one makes later divergence detectable.
- Authoring, templating, or provisioning any `lean-lsp-mcp-wrapper.sh` anywhere. Research
  question (a) settled this negatively.
- Switching the source store to the `--lean-project-path` CLI convention. Both conventions work;
  the env-var form is already implemented, already documented, and needs no wrapper.
- Baking a NixOS toolchain PATH prepend into any deployed artifact. Question (b) settled this
  negatively; runtime resolution via inherited PATH suffices on this machine.
- The consumer-repo deploy propagation gap (architecturally adjacent, deliberately not merged)
  and the extension-manifest-driven `.mcp.json` generation work (a different mechanism that
  explicitly carves lean-lsp out as user-scope).
- Editing anything under `~/Projects/BimodalLogic/`, with the single sanctioned exception of
  re-running that repo's deploy if the chosen remedy requires it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `~/.claude.json` is live session state; a concurrent Claude Code write clobbers the reconciliation (read-modify-`mv` is not atomic against another writer) | H | M | Take a timestamped backup before any mutation; perform the write with as few other sessions running as practical; re-read and `jq`-validate the entry immediately after |
| Deleting cslib's wrapper/override before a working replacement leaves cslib with no lean-lsp for a session | M | M | Phase 5 is strictly gated on Phase 4 having landed and verified the global entry, so the replacement is live before the override is removed — there is no uncovered window |
| Under the single-global-entry model, `LEAN_PROJECT_PATH` points at one project at a time; the other Lean repo silently indexes the wrong project | M | H | Pre-existing, already-shipped behavior of the sanctioned mechanism, not introduced here. Named explicitly as a `user_decision` (Option A vs. Option B) and stated in `mcp-server-ownership.md`; Phase 6 sequences a `setup` re-run between the two repos' verifications |
| A green `verify-lean-mcp.sh` is mistaken for proof the server spawns | H | M | Phase 6 requires an observed spawn and a real tool call per repo from a fresh session or `claude -p`; the verifier's own severity fix (Phase 2) narrows but does not close this gap, and the acceptance bar is the spawn |
| Editing source-store scripts without redeploying leaves `.claude/scripts/` copies stale | M | M | Phase 4 runs the sanctioned `deploy-headless.sh` resync before any live-config work; source and deployed copies are byte-identical today, so drift after this task is attributable solely to a skipped deploy |
| A hand-authored file lands in a `.claude/` tree, reproducing the defect in a harder-to-diagnose form | H | L | `rules/source-store-deploy-boundary.md` prohibits it; all edits target `agent-system/extensions/**` and `.claude/` is written only by `deploy-headless.sh` |
| `setup-lean-mcp.sh` writes `specs/tmp/` into whatever directory it is run from, polluting consumer repos and failing where CWD is not writable | L | M | Phase 1 replaces the CWD-relative `mkdir -p specs/tmp` + `mktemp -p specs/tmp` with a temp file created alongside `~/.claude.json` (same filesystem, so `mv` stays atomic) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Make setup-lean-mcp.sh reconcile a divergent entry [COMPLETED]

**Goal**: `setup-lean-mcp.sh` restores the sanctioned shape from ANY prior state of
`.mcpServers."lean-lsp"`, including a hand-edited wrapper entry, and works in `lakefile.toml`
projects.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/setup-lean-mcp.sh`, extend project-path
      auto-detection to accept `lakefile.toml` as well as `lakefile.lean`, in both the CWD test
      and the git-root test. Preserve the existing precedence (CWD first, then git root) and the
      existing error message when neither is found. *(completed)*
- [x] Replace the "already configured" branch's env-only comparison and env-only update. Compare
      the WHOLE entry against the shape `generate_lean_lsp_config` would emit for this
      `PROJECT_PATH`; when it differs in any field, overwrite the entire
      `.mcpServers."lean-lsp"` object with the generated config (`jq --argjson leanConfig
      '.mcpServers."lean-lsp" = $leanConfig'`, the same assignment the add-new branch already
      uses), not a targeted `env.LEAN_PROJECT_PATH` assignment. *(completed)*
- [x] Report the reconciliation honestly in the non-dry-run output: name the old `command` and
      `args` being replaced, not only the project-path change, so an operator sees that a
      divergent shape was corrected rather than a path bumped. *(completed)*
- [x] Make `--dry-run` print the same whole-entry before/after for the divergent case, so it can
      be used to inspect the pending repair without mutating the live config. *(completed)*
- [x] Replace `mkdir -p specs/tmp` and both `mktemp -p specs/tmp` call sites with a temp file
      created in the same directory as `$CLAUDE_CONFIG` (e.g. `mktemp
      "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX"`), keeping `mv` same-filesystem and atomic, and removing
      the CWD-relative directory creation entirely. *(completed)*
- [x] Re-run the `--dry-run` reproduction against the live divergent entry and confirm it now
      reports a full-shape replacement rather than an env-only path update. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly one file changes
(`agent-system/extensions/core/scripts/setup-lean-mcp.sh`) and that its divergent-entry branch is
the only place `command`/`args` repair is missing. Confirm at implementation time by re-reading
the script end to end after editing and by re-running the jq simulation from the research
integration note above; if a second write path to `.mcpServers."lean-lsp"` exists in the script,
it must receive the same whole-entry treatment.

**Files to modify**:
- `agent-system/extensions/core/scripts/setup-lean-mcp.sh` - lakefile.toml detection,
  whole-entry reconciliation in the already-configured branch, honest divergence reporting,
  temp-file hygiene

**Verification**:
- `bash -n` clean; `shellcheck` clean if available.
- From `~/Projects/cslib` (a `lakefile.toml` project), `--dry-run` detects the project path
  instead of exiting with "Could not detect Lean project path".
- Against a COPY of the live `~/.claude.json` in the scratchpad (never the live file in this
  phase), the divergent-entry path produces `command: "uvx"`, `args: ["lean-lsp-mcp"]`, and both
  `env.LEAN_LOG_LEVEL` and `env.LEAN_PROJECT_PATH`.
- Running twice against an already-correct entry is a no-op that still reports "no changes
  needed" (idempotency preserved).
- No `specs/tmp` directory is created in the CWD by any invocation.

---

### Phase 2: Make verify-lean-mcp.sh fail on an unspawnable registration [NOT STARTED]

**Goal**: The verifier's severities match what actually breaks a spawn, and it sees a
project-scoped entry that shadows the global one.

**Tasks**:
- [ ] Copy Phase 1's settled `lakefile.toml`-aware detection block verbatim into
      `agent-system/extensions/core/scripts/verify-lean-mcp.sh` so the two standalone operator
      scripts cannot disagree about which directories are Lean projects. Apply the same change to
      Check 7's `lakefile.lean` presence warning.
- [ ] Promote Check 3 (`command != "uvx"`) and Check 4 (`args[0] != "lean-lsp-mcp"`) from `warn`
      to `fail` with a non-zero exit, since neither shape can spawn the sanctioned server. Keep
      the existing remedy line ("Run setup-lean-mcp.sh to fix") on the new failure paths.
- [ ] Add a check that the configured `command` does not resolve inside any repository's
      `.claude/` directory, naming the invariant recorded in Phase 3 in its failure message.
      This is the check that would have caught the original defect by shape rather than by the
      incidental absence of an env var.
- [ ] Add a check for a project-scoped shadow: if
      `.projects["<expected project path>"].mcpServers."lean-lsp"` exists in `~/.claude.json`,
      report it explicitly, since a local-scope entry silently overrides the global one the rest
      of the script inspects. Under Option A (see the user decision below) this is a failure;
      state that framing in the message.
- [ ] Confirm the exit-code contract documented in the script header (`0` valid, `1` missing or
      invalid, `2` path mismatch) still holds for every new failure path, and update the header
      comment if a new class needs its own code.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts one file changes
(`agent-system/extensions/core/scripts/verify-lean-mcp.sh`) and that the four numbered checks
above are the complete set needing severity or coverage change. Confirm by re-reading all seven
existing checks after editing and re-deriving, for each, whether its current severity matches
whether its failure prevents a spawn.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-lean-mcp.sh` - detection parity, WARN-to-FAIL
  promotion for command/args, deploy-tree command-path check, project-scope shadow check

**Verification**:
- `bash -n` clean; `shellcheck` clean if available.
- Run against the CURRENT (unreconciled) live `~/.claude.json` from `~/Projects/BimodalLogic`:
  now exits non-zero citing the dead wrapper command specifically, not only the missing env var.
- Run from `~/Projects/cslib`: detects the project path (no `lakefile.lean` there) and reports
  the project-scoped shadow entry.
- Run against a scratchpad copy holding the correct sanctioned shape: exits 0.
- No check that currently fails on a broken config has been softened.

---

### Phase 3: Record the durable invariant and update lean-extension docs [NOT STARTED]

**Goal**: The rule whose violation produced this defect is written down where a future author
choosing a registration surface will read it, and the lean extension's own docs describe the
sanctioned shape without implying a wrapper.

**Tasks**:
- [ ] Add a short subsection to
      `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`, adjacent to
      "Choosing a registration surface (the hybrid model)", stating the invariant: an
      `mcpServers` `command` path must never resolve inside any repository's own `.claude/`
      deploy tree, because that tree is disposable and regenerated wholesale per
      `rules/source-store-deploy-boundary.md`. Frame the failure mode precisely — it looks
      configured until the next regeneration or a fresh clone, then fails as a silent ENOENT.
- [ ] Give the invariant one worked negative example (this defect, described by shape and never
      by task number) and the two existing positive examples the file already carries:
      `playwright`'s Nix-built wrapper binary and `lean-lsp`'s `uvx`-resolved package, both at
      stable locations outside any `.claude/` tree.
- [ ] Record the single-global-entry trade-off named in the user decision below, so the
      concurrent-two-Lean-projects cost is documented rather than rediscovered.
- [ ] Update `agent-system/extensions/lean/README.md` (its registration paragraph) and
      `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` (its
      "writes an entry shaped like this" block) so the documented shape matches exactly what
      Phase 1's `generate_lean_lsp_config` emits, and so neither implies a wrapper script is
      involved.
- [ ] Verify the claim in `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`
      that `verify-lean-mcp.sh` has "no automated caller by design" is still accurate after
      Phase 2, and leave it for the companion drift-detection task to revise if that task adds
      one.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly three documentation files need edits
(`mcp-server-ownership.md`, lean `README.md`, `mcp-tools-guide.md`) plus one file to re-check
(`utility-scripts-inventory.md`). Confirm at implementation time by re-running
`grep -rn "setup-lean-mcp\|verify-lean-mcp\|lean-lsp" agent-system/ --include=*.md` and checking
every hit against the shape Phase 1 emits; the grep, not this list, is authoritative.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` - new invariant
  subsection plus the single-global-entry trade-off note
- `agent-system/extensions/lean/README.md` - registration paragraph matches emitted shape
- `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` - example entry
  matches emitted shape

**Verification**:
- Every changed hunk lies in markdown prose or a fenced example block; no script or JSON
  consumed by code is altered by this phase.
- The JSON example blocks are valid JSON and byte-comparable to `generate_lean_lsp_config`'s
  output modulo the project path.
- No task numbers appear in any file outside `specs/**`
  (`.claude/rules/no-task-references-in-deliverables.md`).
- Internal cross-references resolve (the `source-store-deploy-boundary.md` citation in
  particular).

---

### Phase 4: Deploy the source store and reconcile the live global entry [NOT STARTED]

**Goal**: The repaired scripts are live in `.claude/`, and `~/.claude.json`'s top-level
`mcpServers."lean-lsp"` holds the sanctioned wrapper-free shape.

**Tasks**:
- [ ] Run the sanctioned deploy from `~/.config/nvim`:
      `bash agent-system/extensions/core/scripts/deploy-headless.sh` (default non-destructive
      resync mode; `--dry-run` first to inspect). Do NOT hand-copy any file into any `.claude/`
      tree.
- [ ] Confirm `.claude/scripts/setup-lean-mcp.sh` and `.claude/scripts/verify-lean-mcp.sh` are
      byte-identical to their source-store originals after the deploy (they are today, so any
      difference means the deploy did not land).
- [ ] Back up the live config: `cp ~/.claude.json ~/.claude.json.bak.$(date +%Y%m%d%H%M%S)` and
      record the backup path in the phase notes.
- [ ] From `~/Projects/BimodalLogic`, run `setup-lean-mcp.sh --dry-run`, read the reported
      before/after, then run it for real. Expect the whole-entry replacement path from Phase 1,
      not an env-only update.
- [ ] Confirm the resulting entry with `jq '.mcpServers."lean-lsp"' ~/.claude.json`:
      `command: "uvx"`, `args: ["lean-lsp-mcp"]`, `env.LEAN_LOG_LEVEL: "WARNING"`,
      `env.LEAN_PROJECT_PATH: "/home/benjamin/Projects/BimodalLogic"`, and no path anywhere in
      the entry pointing inside a `.claude/` tree.
- [ ] Confirm `.mcpServers."playwright"` and every other top-level key in `~/.claude.json` are
      untouched (diff the backup against the new file and read the diff in full).
- [ ] Run the repaired `verify-lean-mcp.sh` from `~/Projects/BimodalLogic`: expect exit 0.

**Timing**: 45 minutes

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `~/.claude.json` - top-level `mcpServers."lean-lsp"` reconciled (live machine config, outside
  the repository; not a git-tracked change)
- `.claude/scripts/setup-lean-mcp.sh`, `.claude/scripts/verify-lean-mcp.sh` - regenerated by the
  deploy engine only, never hand-edited

**Verification**:
- `jq` confirms the exact sanctioned entry shape above.
- `diff` of the backup against the new `~/.claude.json` touches only the `lean-lsp` entry.
- `verify-lean-mcp.sh` exits 0 from `~/Projects/BimodalLogic`.
- Deploy verification (`deploy-headless.sh`'s own inline `verify-deploy.sh` step) reports
  success.
- Note explicitly in the phase record that this verifier pass does NOT constitute acceptance —
  Phase 6 owns that.

---

### Phase 5: Retire cslib's orphaned wrapper and project-scoped override [NOT STARTED]

**Goal**: cslib depends on no unreproducible hand-authored file and shares the sanctioned
mechanism.

**Tasks**:
- [ ] Re-confirm Phase 4 landed and `verify-lean-mcp.sh` passes globally before touching cslib,
      so cslib is never left without a registration.
- [ ] Archive rather than blind-delete: copy
      `~/Projects/cslib/.claude/scripts/lean-lsp-mcp-wrapper.sh` to the session scratchpad first,
      so its content is recoverable during this task if a surprise emerges, then remove the file.
- [ ] Remove the project-scoped override with
      `jq 'del(.projects["/home/benjamin/Projects/cslib"].mcpServers."lean-lsp")'` against
      `~/.claude.json`, writing through a same-directory temp file and `mv` (a fresh backup
      first, per Phase 4's pattern).
- [ ] Confirm `.projects["/home/benjamin/Projects/cslib"]` still exists with its other keys
      intact and that only the `lean-lsp` server entry was removed.
- [ ] Confirm no other project key in `~/.claude.json` carries a `mcpServers` entry whose
      `command` resolves inside a `.claude/` tree —
      `jq -r '.projects | to_entries[] | .value.mcpServers // {} | to_entries[] | .value.command'`
      — and report any additional offenders found rather than silently fixing beyond scope.
- [ ] Do not create, restore, or template any replacement wrapper in either repo.

**Timing**: 30 minutes

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts cslib holds the ONLY project-scoped `lean-lsp` override
and the only surviving wrapper copy. Confirm at implementation time with the `jq` sweep over all
`.projects[].mcpServers` above and a `find ~/Projects -name 'lean-lsp-mcp-wrapper.sh'` before
declaring the retirement complete.

**Files to modify**:
- `~/Projects/cslib/.claude/scripts/lean-lsp-mcp-wrapper.sh` - deleted (untracked, inside a
  disposable deploy tree; deletion is the sanctioned direction, never a rewrite in place)
- `~/.claude.json` - `.projects["/home/benjamin/Projects/cslib"].mcpServers."lean-lsp"` removed

**Verification**:
- The wrapper file no longer exists; a scratchpad copy is retained for the duration of the task.
- `jq '.projects["/home/benjamin/Projects/cslib"].mcpServers'` no longer contains `lean-lsp`, and
  the surrounding project entry is otherwise unchanged (diff against the fresh backup).
- The `jq` sweep across all project keys returns no `.claude/`-resident command path.
- `find ~/Projects -name 'lean-lsp-mcp-wrapper.sh'` returns nothing.

---

### Phase 6: Prove it with an observed spawn and a real tool call in both repos [NOT STARTED]

**Goal**: Acceptance. The lean-lsp MCP server actually starts and answers a real tool call in
BOTH `~/Projects/BimodalLogic` and `~/Projects/cslib`.

**Tasks**:
- [ ] From `~/Projects/BimodalLogic`, in a FRESH session (`claude -p` or a new interactive
      session — never the session that made the change, which cannot see a modified
      `~/.claude.json`), confirm the `lean-lsp` server connects with no ENOENT.
- [ ] Make at least one real `mcp__lean-lsp__*` tool call against a BimodalLogic Lean file and
      record the actual response, not merely the connection state.
- [ ] Re-point the shared global entry at cslib: from `~/Projects/cslib`, run
      `setup-lean-mcp.sh` (Phase 1's `lakefile.toml` detection makes this work without
      `--project`; if it still needs the flag, that is a Phase 1 regression, not a workaround to
      accept), then `verify-lean-mcp.sh` for exit 0.
- [ ] From `~/Projects/cslib`, in a fresh session, confirm the server connects and make at least
      one real `mcp__lean-lsp__*` tool call against a cslib Lean file, recording the response.
      This is the run that proves retiring the wrapper did not regress the one repo that
      previously worked.
- [ ] Leave `LEAN_PROJECT_PATH` pointing at whichever project the operator is next working in,
      and state plainly in the summary which one that is and that switching requires re-running
      `setup-lean-mcp.sh` under the single-global-entry model.
- [ ] Record both spawn transcripts (or their salient excerpts) in the implementation summary as
      the acceptance evidence. A green deploy or a green verifier alone does not close this task.

**Timing**: 45 minutes

**Depends on**: 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Verification**:
- No `posix_spawn` ENOENT for `lean-lsp` in either fresh session.
- A successful `mcp__lean-lsp__*` tool call with a real response recorded per repo (two total).
- `verify-lean-mcp.sh` exits 0 in each repo at the moment that repo's spawn is verified.
- The summary states which project `LEAN_PROJECT_PATH` was left pointing at.

## Testing & Validation

- [ ] `bash -n` and (where available) `shellcheck` pass on both modified scripts.
- [ ] `setup-lean-mcp.sh` is idempotent: a second run against an already-correct entry reports no
      changes needed and mutates nothing.
- [ ] `setup-lean-mcp.sh` fully repairs a divergent wrapper-shaped entry, verified against a
      scratchpad copy before it is ever run against the live config.
- [ ] `verify-lean-mcp.sh` exits non-zero on a wrapper-shaped command, on a `.claude/`-resident
      command path, and on a project-scoped shadow entry.
- [ ] Both scripts detect the project path in a `lakefile.toml` project and in a `lakefile.lean`
      project.
- [ ] `~/.claude.json` diffs touch only the `lean-lsp` entries; `playwright` and all unrelated
      keys are byte-identical.
- [ ] No file was hand-authored into any `.claude/` tree; `.claude/` changes came only from
      `deploy-headless.sh`.
- [ ] Repository-wide task-reference lint passes (no task numbers outside `specs/**`).
- [ ] ACCEPTANCE: an observed lean-lsp spawn plus a real tool call in BOTH repos, from fresh
      sessions.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/setup-lean-mcp.sh` (modified)
- `agent-system/extensions/core/scripts/verify-lean-mcp.sh` (modified)
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` (modified — durable
  invariant recorded)
- `agent-system/extensions/lean/README.md` (modified)
- `agent-system/extensions/lean/context/project/lean4/tools/mcp-tools-guide.md` (modified)
- `.claude/scripts/setup-lean-mcp.sh`, `.claude/scripts/verify-lean-mcp.sh` (regenerated by
  deploy, not hand-edited)
- `~/.claude.json` (reconciled: global entry repaired, cslib project-scoped override removed)
- `~/Projects/cslib/.claude/scripts/lean-lsp-mcp-wrapper.sh` (deleted)
- `specs/203_reconcile_lean_lsp_mcp_registration/summaries/01_*-summary.md` (implementation
  summary carrying the two spawn transcripts as acceptance evidence)

## Rollback/Contingency

- **Live config**: every `~/.claude.json` mutation is preceded by a timestamped backup
  (`~/.claude.json.bak.<ts>`). Restore by copying the backup back and starting a fresh session;
  no other state depends on the change.
- **cslib wrapper**: the file is archived to the session scratchpad before deletion, so the exact
  bytes are recoverable within this task. If cslib's spawn fails in Phase 6 for a reason
  traceable to the wrapper's PATH export (contradicting research finding (b)), restore the
  scratchpad copy AND its project-scoped override from the backup, then re-open finding (b)
  rather than baking a PATH prepend into a deployed artifact.
- **Source-store scripts and docs**: ordinary `git revert` of the phase commits, followed by a
  re-run of `deploy-headless.sh` to bring `.claude/` back in line. Because each phase commits
  separately, the script fixes and the doc changes can be reverted independently.
- **Deploy tree**: never rolled back by hand-editing `.claude/`; always by reverting the source
  store and redeploying.
