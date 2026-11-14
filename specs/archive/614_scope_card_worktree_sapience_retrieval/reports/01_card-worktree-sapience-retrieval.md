# Research Report: Task #614

**Task**: 614 - Resolve a SF-1 card worktree to its parent checkout so card sessions get
repo-scoped Sapience retrieval without hook-injected context
**Started**: 2026-11-13
**Completed**: 2026-11-13
**Effort**: medium
**Dependencies**: Task 606, Task 612, Task 617
**Sources/Inputs**:
- Codebase: `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh`,
  `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh`,
  `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`,
  `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`,
  `agent-system/extensions/sapience/scripts/sapience-retrieve.sh`,
  `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`,
  `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`,
  `agent-system/extensions/sapience/context/project/sapience/domain/subagent-orientation.md`,
  `agent-system/extensions/core/scripts/lib/common.sh`,
  `~/.local/state/sf1-hub-ben/hub/runner/bin/runner.py`,
  `~/.local/state/sf1-hub-ben/hub/runner/config.json`.
- Empirical measurement: `git` worktree behavior in a scratch fixture repo; `claude mcp list`
  behavior against fabricated `HOME` fixtures (no production file touched).
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Headline finding, empirically measured, not assumed**: Claude Code's own `~/.claude.json`
  per-project lookup already resolves a linked git worktree (and any subdirectory inside it) to
  its main checkout's `.projects[<checkout>]` entry. A session whose cwd is a worktree sees
  exactly the MCP servers registered under the checkout's own key, with no bleed from unrelated
  repositories and no "no servers" false negative when the checkout *is* registered. This means
  the registration fix does **not** need to create a new, worktree-keyed `~/.claude.json` entry
  at all — it only needs to resolve activation-detection and the registration *key* to the
  checkout, which Claude Code's own session-start lookup then finds automatically from the
  worktree. This directly and cheaply answers both of the dispatch's first two open questions.
- The fix belongs entirely in `sapience-mcp-register-project.sh` (activation detection +
  `--project` argument) and `verify-sapience-mcp.sh` (the lockstep detection copy); the writer
  `setup-sapience-mcp.sh` needs **no change** — it already accepts an arbitrary `--project PATH`
  and the checkout path is exactly such a path.
- A second, independently confirmed bug: `sapience-retrieve.sh`'s repo-slug derivation
  (`basename "$(git rev-parse --show-toplevel)")`) returns the **worktree's own throwaway
  directory name** (e.g. `C-3-20261113120000`, from the SF-1 runner's `work_dir` naming
  convention measured directly in `runner.py`) when run inside a worktree, not the checkout's
  repo name. The identical git-worktree-resolution technique used for the registration fix also
  fixes this slug computation.
- **A caveat that must be recorded, not silently absorbed**: the SF-1 runner's own automated
  card-execution process (`runner.py`'s `-p ... --strict-mcp-config --mcp-config
  '{"mcpServers": {}}'` invocation) explicitly zeroes every MCP server for that one specific
  subprocess, regardless of what `~/.claude.json` says. The registration fix makes the checkout's
  MCP registration correctly *visible* from the worktree for any session that does not pass
  `--strict-mcp-config` with an empty `--mcp-config` (an interactive session, a manual resumption,
  a different invocation shape) — but it cannot make `sapience_search` reachable from inside that
  one specific automated subprocess, because that subprocess's own flags refuse all MCP servers
  before `~/.claude.json` is ever consulted. This file (`runner.py`) is vendor/nix-packaged, lives
  under `~/.local/state/sf1-hub-ben/`, and is out of this task's edit scope under
  `.claude/rules/source-store-deploy-boundary.md`'s task-siting rule (it is not in this
  repository's filesystem at all, let alone its source store).
- The SF-1 runner's own `memory_dir` config field and its `guard_bound()` function
  (`runner.py:1217-1227`) are the cited precedent: `memory_dir` is a static, checkout-keyed path
  computed once at config time, and `guard_bound()` independently re-derives the checkout from a
  worktree via the **identical** `git rev-parse --git-common-dir` technique this report
  recommends, confirming the technique is already proven correct in production on this exact
  runner.

## Context & Scope

The task asks for a worktree-aware fix to the Sapience per-project MCP-registration triad
(writer, bidirectional SessionStart hook, installer, verifier, regression suite) so that a SF-1
hub-runner card worktree resolves Sapience activation and registration to its parent checkout,
while (a) never acquiring the extension's hooks or permission grants (already structurally true,
to be verified rather than assumed) and (b) never creating an unbounded, un-retracted
`~/.claude.json` entry per throwaway worktree. The dispatch posed three explicit open questions
this research was asked to measure rather than assume; all three are answered below with direct
evidence.

## Findings

### Codebase Patterns

**The registration triad, as it exists today** (`setup-sapience-mcp.sh`,
`hooks/sapience-mcp-register-project.sh`, `verify-sapience-mcp.sh`,
`scripts/tests/test-sapience-mcp-registration.sh`):

- The writer (`setup-sapience-mcp.sh`) is already path-agnostic: every action
  (`process_write`/`process_remove`) takes `--project PATH` as an opaque string and uses it only
  as a `jq` map key (`.projects[$path]`). It does not call `git` at all. **No change needed here**
  — handing it a checkout path instead of a worktree path is already within its existing
  contract.
- The hook (`hooks/sapience-mcp-register-project.sh`) computes `GIT_ROOT` via
  `git rev-parse --show-toplevel`, which — critically — returns the **worktree's own** toplevel
  when run from inside a linked worktree, not the checkout's. It then looks for
  `.claude-extensions.json` at `$(pwd)` or at that (wrong, worktree-local) `GIT_ROOT`. A fresh
  card worktree has neither, so `IS_ACTIVE` resolves `false` unconditionally and, since no entry
  exists yet either, the hook exits silently with `{}` — exactly the "no tools at all" gap the
  dispatch describes. This is the one place requiring a real code change (see Recommendations).
- The verifier (`verify-sapience-mcp.sh`) carries a **byte-for-byte duplicate** of the same
  `GIT_ROOT`/`.claude-extensions.json` detection block (its own comment: "kept in lockstep with
  sapience-mcp-register-project.sh's own copy"), so it has the identical gap and needs the
  identical fix, applied in lockstep as its header already promises.
- The regression suite's hook cases (10-15) construct a repo fixture via `git init -q` with no
  worktree scenario at all today — case coverage for a worktree-of-a-loaded-checkout,
  worktree-of-an-unloaded-checkout, an unloading-since-registration retraction, and a
  non-worktree-path no-op (scope item 4's four cases) does not exist yet and is new coverage to
  add, not a fix to an existing case.

**`sapience-retrieve.sh`'s slug bug** (independent of the registration triad): line 101-108
derives `repo_slug="$(basename "$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel)")"`. For a
linked worktree this is the worktree's own basename, not the checkout's repo name — confirmed by
direct measurement against the SF-1 runner's actual worktree-naming convention (below). This
script is deployed to `.claude/scripts/sapience-retrieve.sh` and is invoked by
`orchestrate-build-dispatch.sh`'s Stage 3.5 within a repository that has a normal `.claude/`
deploy; it is not itself reachable from inside a bare SF-1 card worktree (which carries no
`.claude/` tree at all — see Channel 1 below). Its slug-derivation bug matters because it is the
one script in this codebase that performs the exact `[repo:<slug>]`-filter construction a human
or agent would otherwise have to hand-derive correctly when manually scoping a `sapience_search`
call from inside a worktree session; fixing its derivation once, via the same
checkout-resolution technique, gives every future caller (this script, documentation, a human
typing the filter by hand) one canonical, worktree-correct way to compute the slug.

### Git Worktree Mechanics (measured in a scratch fixture, not assumed)

Built a disposable fixture (`main` checkout + `git worktree add --detach wt1 HEAD`,
scratchpad-local, never touching this repository or `~/.claude.json`) and measured:

| Query (from) | `git rev-parse --git-dir` | `git rev-parse --git-common-dir` |
|---|---|---|
| checkout root | `.git` (relative) | `.git` (relative) — **equal** |
| worktree root | `<checkout>/.git/worktrees/<name>` (absolute) | `<checkout>/.git` (absolute) — **differs** |
| worktree subdir (nested) | same as worktree root, absolute | same as worktree root, absolute — **differs** |
| plain non-git directory | `fatal: not a git repository` (exit 128) | same failure |

This gives a simple, shellcheck-clean worktree test with no false positives/negatives across
every case scope item 4 asks for: compare `git rev-parse --git-dir` and
`git rev-parse --git-common-dir`; equal (including the "both empty, both failed" case for a
non-git path) means "not a linked worktree, behave exactly as today"; unequal means "linked
worktree — the common dir's **parent directory** is the checkout," since `--git-common-dir`
always resolves to `<checkout>/.git` for a linked worktree, confirmed at every directory depth
tested, including nested subdirectories of the worktree.

This is the identical technique the SF-1 runner's own `guard_bound()`
(`~/.local/state/sf1-hub-ben/hub/runner/bin/runner.py:1217-1227`) already uses in production:
"The guard binds a worktree through the COMMON git dir (guard.fast_root follows .git ->
commondir), so a card worktree sees `<repo>/.git/oliver-ben-guard/config.json`." That function
runs `git(["rev-parse", "--git-common-dir"], str(wt))` and reads a checkout-scoped config file
from the parent of the result — exactly the shape this task's fix needs, already proven correct
on the exact runner this task targets.

### Claude Code's Own Project-Config Resolution (measured, the headline finding)

Built a second fixture: a fabricated `HOME` (never the real `~/.claude.json`) with
`.projects["<checkout>"].mcpServers` entries, then ran `HOME=<fixture> claude mcp list` from
several `cwd`s to observe which entry Claude Code's own CLI resolves to.

| cwd | Registered entries in the fixture | Entry Claude Code reports |
|---|---|---|
| checkout root | `<checkout>` only | checkout's entry (expected, exact match) |
| linked worktree root | `<checkout>` only | **checkout's entry** (worktree, not an exact key match) |
| nested subdir of the worktree | `<checkout>` + unrelated `<other-repo>` | **checkout's entry** (unaffected by key order or the presence of a second, unrelated entry) |
| the unrelated repo's own root | `<checkout>` + `<other-repo>` | `<other-repo>`'s own entry (correct, no cross-bleed) |
| worktree, with **no** entry registered for its checkout at all | `<other-repo>` only | "No MCP servers configured" (correctly reports nothing — no fallback to the unrelated entry) |
| a plain, unrelated, non-git tmp directory | `<checkout>` + `<other-repo>` | "No MCP servers configured" (correctly reports nothing) |

Four independent controls rule out coincidence: swapping JSON key order left the result
unchanged; making the "other" directory its own unrelated git repo (so the match could not be an
accidental path-prefix relationship) left the result unchanged; querying from a worktree whose
checkout has **no** entry correctly reports nothing rather than bleeding into an unrelated
registered entry; and querying from a plain non-git directory with entries present elsewhere
correctly reports nothing.

**Conclusion**: Claude Code already performs git-worktree-to-checkout resolution internally when
looking up `~/.claude.json`'s per-project config (which includes `mcpServers`), with no
cross-repository bleed-through and no silent-wrong-match failure mode. Registering under the
**checkout's own key** — the same key the checkout's own session would already use — is
therefore both correct and sufficient; a session in any worktree of that checkout, at any
nesting depth, automatically resolves to it. **No worktree-specific `~/.claude.json` entry needs
ever to be created**, which eliminates the dispatch's open-question-2 concern about unbounded
dead-entry accumulation by construction rather than by a teardown/retraction mechanism: there is
nothing worktree-specific to retract, because nothing worktree-specific is ever written.

This also directly answers open-question-1 ("does a card session's Claude Code invocation read
`~/.claude.json` project entries by cwd, or by some other resolution that a worktree path would
defeat even once registered?"): it is not a literal cwd-string match, and it does not defeat a
checkout-keyed registration — it is exactly what makes a checkout-keyed registration work from a
worktree.

### Open Question 3 — Is the Checkout Path Already in the Card's Environment?

Measured directly against `runner.py`: `child_env()` (line 623-627) builds the spawned card
process's environment from `os.environ` (minus a fixed drop-list of credential variables) plus a
small `extra` dict. The card-exec call site (line 1206) passes only
`{"SF1_HUB_CARD_DIR": str(d)}` as `extra` — no checkout-path variable is set for the child
process by the runner itself. The checkout path is known to the *runner process* as `cfg["repo"]`
(sourced from `config.json`, or from an optional `SF1_HUB_REPO` environment override on the
*runner's own* startup — not propagated to the card as a dedicated variable), but is not handed
to the spawned card process as a documented, stable contract. **Answer: no** — the checkout path
is not reliably exposed in the card session's environment; the git-derivation technique above is
necessary, not merely a cheaper-alternative-foregone.

### Why Channel 1 (Hook-Injected Context) Staying Absent Needs Verification, Not Assumption

The dispatch requires this task to verify, rather than infer from "the worktree has no `.claude/`
tree," that a worktree session fires no Sapience hooks and carries no Sapience permission grants.
This is a live-session check against the merged settings for an actual worktree session (scope
item 3 / acceptance criterion 2) — it was not re-derived here beyond confirming the structural
claim already recorded in the dispatch and in `settings-fragment.json`'s merge model: hooks and
permission grants are merged only into a repository's own `.claude/settings.local.json` by the
deploy/merge engine while that repository's `.claude-extensions.json` shows the extension
active, and a fresh git worktree (untracked `.claude/`) has no such file to merge into at all.
The planning/implementation phase should still perform the live check this dispatch's acceptance
criterion 2 requires (inspecting the actual merged settings reachable from a worktree session)
rather than treating this research-stage structural confirmation as a substitute for it.

### External Resources

None consulted; this task is entirely internal-codebase and environment measurement (git
semantics, Claude Code CLI behavior, this machine's SF-1 runner installation). No web research
was needed or performed.

## Recommendations

1. **In `hooks/sapience-mcp-register-project.sh`**: replace the single
   `GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"` line with worktree-aware
   resolution: compare `git rev-parse --git-dir` against `git rev-parse --git-common-dir`; if
   they differ, resolve the common-dir to an absolute path (prefixing with `pwd` if relative) and
   set `GIT_ROOT` to that path's parent directory (the checkout); otherwise keep the existing
   `--show-toplevel` call unchanged. Downstream logic (`.claude-extensions.json` lookup,
   `--project "$PROJECT_PATH"` passed to the writer) needs no other change, since `PROJECT_PATH`
   is already derived from `GIT_ROOT` in the existing `elif` branch.
2. **In `verify-sapience-mcp.sh`**: apply the identical change to its lockstep-duplicated
   detection block, preserving the "kept in lockstep" invariant its own header already states.
3. **In `scripts/sapience-retrieve.sh`**: apply the same checkout-resolution technique before
   taking `basename` for `repo_slug`, so a (hypothetical, currently unreachable from inside a bare
   worktree, but worth correcting for any future caller or documentation reference) invocation
   from a worktree produces the same slug its checkout would.
4. **No change needed in `setup-sapience-mcp.sh`** — confirmed above, its contract is already
   path-opaque.
5. **New regression coverage** (scope item 4's four cases) in
   `scripts/tests/test-sapience-mcp-registration.sh`: construct a checkout fixture plus a real
   `git worktree add` of it, and exercise (a) worktree of a loaded checkout registers under the
   checkout's key with the correct slug, (b) worktree of an unloaded checkout does not register,
   (c) an existing checkout-keyed entry is retracted once the checkout's own
   `.claude-extensions.json` flips to inactive (exercised from the worktree, confirming the
   bidirectional contract survives), (d) a worktree-shaped path that is not actually a git
   worktree (or not a git repo at all) is a silent no-op.
6. **`per-repo-scoping.md` update** (scope item 5): record the two-channel asymmetry using this
   report's verified mechanics — the worktree-to-checkout resolution is the fix for Channel 2
   (registration/retrieval), Channel 1 (hooks/grants) stays absent by construction (no
   `.claude/` tree to merge into), and this must not be "fixed" by a future reader who notices the
   missing hooks and tries to extend the merge engine into worktrees.
7. **Record the `--strict-mcp-config` caveat explicitly** wherever the fix is documented
   (`per-repo-scoping.md` and/or the plan's own scope note): the registration fix is necessary and
   sufficient for any interactive or non-`--strict-mcp-config` session in the worktree, but the
   SF-1 runner's own automated card-exec subprocess is architected to see zero MCP servers
   regardless, by a flag combination in vendor-owned, out-of-repo code this task cannot and should
   not edit. Acceptance testing (criterion 1) should be performed via a session shape that does
   **not** pass `--strict-mcp-config`/empty `--mcp-config`, and the gap for the literal automated
   card-exec process should be named as a known, deliberate, out-of-scope limitation rather than
   silently assumed closed.

## Decisions

- The fix is scoped to the hook and the verifier's detection logic only; the writer needs no
  change (confirmed by inspection of its existing `--project PATH` contract).
- Registration will key on the checkout path exclusively — no worktree-specific
  `~/.claude.json` entry is ever created, and consequently no new retraction-at-teardown
  mechanism is needed for a worktree-specific entry, because none exists to retract. (This
  resolves the dispatch's open question 2 by elimination rather than by building the
  accumulation-bounding mechanism it anticipated might be needed.)
- The detection test for "is this path a linked worktree" is
  `git rev-parse --git-dir` vs. `git rev-parse --git-common-dir` (string inequality after
  resolving the common-dir to an absolute path), not a `.git`-file-vs-directory test or a
  `git worktree list` parse — this is the simplest test that was directly measured to behave
  correctly at the checkout root, the worktree root, a nested worktree subdirectory, and a
  non-git path.

## Risks & Mitigations

- **Risk**: a future reader "fixes" the missing hooks/grants in a worktree, reopening the
  unscoped cross-repo injection hazard Channel 1's absence is deliberately preserving.
  **Mitigation**: scope item 5's `per-repo-scoping.md` update, explicit and prominent.
- **Risk**: the `--strict-mcp-config` caveat is silently dropped during planning/implementation,
  and acceptance criterion 1 is declared met against evidence that does not actually cover the
  runner's real automated card-exec invocation shape. **Mitigation**: Recommendation 7 above;
  the plan should name the exact session shape under which criterion 1 is verified.
- **Risk**: the `--git-dir`/`--git-common-dir` comparison could, in principle, behave
  differently under a bare repository or a submodule boundary that was not measured here (only a
  plain checkout + one linked worktree was tested). **Mitigation**: scope item 4's "not a git
  worktree at all" case gives a no-op fallback for any shape this comparison does not correctly
  recognize as a worktree; nothing in the recommended change narrows the existing non-worktree
  behavior, so an unanticipated topology degrades to "unchanged," not "broken."

## Context Extension Recommendations

- **Topic**: git-worktree-to-checkout resolution as a reusable bash technique.
- **Gap**: this technique (`--git-dir` vs `--git-common-dir` inequality, common-dir's parent is
  the checkout) is not documented anywhere in `context/patterns/` today, despite now having two
  independent production uses on this machine (the SF-1 runner's `guard_bound()`, and this task's
  Sapience registration fix) plus a third latent one (`sapience-retrieve.sh`'s slug bug).
- **Recommendation**: a short pattern note (e.g.
  `context/patterns/git-worktree-checkout-resolution.md`) capturing the measured truth table in
  this report's "Git Worktree Mechanics" section, so a future per-project-registration consumer
  (the lean-lsp triad this extension already mirrors, or any future one) does not have to
  re-derive or re-measure it. Not created in this pass, since this report's own task scope is
  research, not context authoring; recorded here as a candidate for the planning phase to
  schedule as a scope item or a follow-up task.

## Appendix

### Search Queries / Commands Used

- Read of the full registration triad (`setup-sapience-mcp.sh`,
  `sapience-mcp-register-project.sh`, `verify-sapience-mcp.sh`,
  `test-sapience-mcp-registration.sh`), `sapience-retrieve.sh`, `per-repo-scoping.md`,
  `injection-site-scoping.md`, `subagent-orientation.md`.
- `grep -rn "sf1" -i .` (this repository) to locate prior SF-1-related task history.
- `find ~/.local/state/sf1-hub-ben`, direct reads of `runner.py` and `config.json` on this
  machine to find the memory-sync precedent, the `guard_bound()` precedent, the card-exec
  `argv`/`child_env` construction, and the worktree-naming convention
  (`work_dir / "<card-id>-<timestamp>"`).
- Scratch-fixture `git init` + `git worktree add --detach` to measure
  `--git-dir`/`--git-common-dir`/`--show-toplevel` at the checkout root, the worktree root, a
  nested worktree subdirectory, and a non-git directory.
- Scratch-fixture `HOME=<fixture> claude mcp list` (against fabricated `~/.claude.json` content
  only, never the real file) run from six distinct `cwd`/fixture combinations to measure Claude
  Code's own per-project MCP resolution behavior, with swapped-key-order and
  unrelated-second-repo controls to rule out coincidence.

### References

- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh`
- `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh`
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh`
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`
- `~/.local/state/sf1-hub-ben/hub/runner/bin/runner.py` (read-only reference; not in this
  repository and not an edit target)
