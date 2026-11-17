# Implementation Plan: Task #636

- **Task**: 636 - Close sapience activation-surface scoping gaps: vendor user-level hooks,
  capture coupling, verifier and docs
- **Status**: [COMPLETED]
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/636_sapience_activation_surface_scoping_gaps/reports/01_activation-surface-scoping-gaps.md
- **Artifacts**: plans/01_activation-surface-scoping-gaps.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Five independent closures inside one extension's source store
(`agent-system/extensions/sapience/**`, confirmed as `.extensions.sapience.source_dir` in this
repository's `.claude-extensions.json`): three new named checks in `verify-sapience-mcp.sh`
(machine-wide vendor hook recurrence; "active but hook fragment never merged"; capture/activation
coupling), an N-repeat unanimous-agreement verdict in `verify-sapience-context-scoping.sh`, and
two documentation rewrites that replace claims the measured evidence falsified. The
reconciliation sub-question GOAL (2) poses is ruled on rather than deferred: this source store
stops at the verifier check and records that writing `capture.projects[].enabled` belongs in
`~/.dotfiles`. No file outside the source store is edited; the final phase redeploys and runs the
complete gate set.

### Research Integration

The research report settles four things this plan builds on directly rather than re-deriving.
(1) The vendor mechanism is fully traced: `~/.sapience/sapience_upkeep.py`'s `wire_hooks()`
re-adds three hooks unconditionally on every `auto_update`/`update --wire` pass unless
`hooks_opted_out()` is true (`config.json`'s `hooks` is `false`, or `SAPIENCE_NO_HOOKS=1`), so
detection is a local re-implementation of that same two-part test, and check (d)'s existing
`jq` idiom over `$HOME/.claude/settings.json`'s `.hooks.*` arrays is the pattern to generalize.
(2) The coupling check belongs scoped to the single `EXPECTED_PROJECT_PATH` the script already
resolves, using the longest-`path_prefix`-wins rule `~/.sapience/sapience_capture.py`'s
`for_cwd()` uses, with four outcomes of which only (inactive extension + capture enabled) is a
failure. (3) The unmerged-hook-fragment signal is the ledger's own
`merged_sections.settings` lacking a `hooks` key while `status == "active"` — structurally
distinct from existing check (e)'s deployed-file grant/hook count, so both may legitimately
fail together. (4) GOAL (4)'s agreement rule is **unanimous**, not majority, because the
measured 1-vs-2 split is precisely the case the goal exists to turn into `INCONCLUSIVE`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap phases are
included.

### Premise Re-Validation

Every carried figure the dispatch's Premise Re-Validation block extracted was checked against
live state before this plan was written, and all four hold unchanged:

| Carried claim | Live check | Result |
|---|---|---|
| Source store is `agent-system/extensions/sapience/**`, resolvable from `.claude-extensions.json` | `jq -r '.extensions.sapience.source_dir' .claude-extensions.json` | Confirmed: `/home/benjamin/.config/nvim/agent-system/extensions/sapience` |
| `~/Projects/abood` is `status: "active"` with `merged_sections.settings` carrying only `permissions` | `jq` read of that repository's own `.claude-extensions.json` | Confirmed: `{"status":"active","merged_keys":["permissions"]}`; this repository's own ledger carries `["hooks","permissions"]` for contrast |
| Evidence (a)'s remediation: the three vendor hooks were removed by hand and `config.json` set to `"hooks": false` | scan of `$HOME/.claude/settings.json` for any `.sapience/{mcp,sapience_cli}.py` command; `jq '.hooks'` on `~/.sapience/config.json` | Confirmed: zero vendor hook commands present; `hooks` is `false`. The new check (g) therefore passes today and functions as a recurrence detector, not as a repair |
| Evidence (b)'s capture/activation asymmetry | cross-read of `~/.sapience/config.json`'s `capture.projects[]` against each path's own `.claude-extensions.json` | Confirmed: `BimodalLogic` is `enabled: false` while active; `Sapience/sf1-engine` has no `capture.projects[]` entry at all while active |

The GOAL list in the dispatch matches the research report's scope of record verbatim; no goal
item has moved.

## Goals & Non-Goals

**Goals**:

- `verify-sapience-mcp.sh` gains check (g): fails when `$HOME/.claude/settings.json` carries any
  `~/.sapience/mcp.py` or `sapience_cli.py` injection/reporting hook, and unconditionally reports
  `~/.sapience/config.json`'s `hooks` opt-out value on pass and fail alike.
- `verify-sapience-mcp.sh` gains check (h): a distinctly named failure for "extension active but
  the hook fragment was never merged", read from the ledger's own
  `merged_sections.settings`, naming reload/redeploy as the remedy.
- `verify-sapience-mcp.sh` gains check (i): capture/activation coupling scoped to this project,
  failing on (extension inactive + capture enabled) and reporting (extension active + capture
  not enabled) informationally.
- The reconciliation sub-question is ruled on and the ruling recorded durably: stop at the
  verifier check; writing `capture.projects[].enabled` belongs in `~/.dotfiles` if it is built at
  all.
- `verify-sapience-context-scoping.sh` repeats its two-call comparison N times (default 3) and
  reports `RESIDUAL_HOLDS`/`RESIDUAL_LIFTED` only on unanimous agreement, otherwise
  `INCONCLUSIVE`.
- `injection-site-scoping.md`'s "No Machine-Wide Duplicate Hook Surface" section and
  `per-repo-scoping.md`'s population-3 text state the actual design.
- Every new check and the repeat logic carry regression coverage; the extension redeploys and
  the complete gate set passes.

**Non-Goals**:

- Any edit under `~/.dotfiles` (out of bounds for this task; a companion task is filed there for
  the nix-side default).
- Repairing `~/Projects/abood`'s own merge state. Check (h) names the state; performing the
  reload there is a separate operator action in a different repository.
- The transcript-capture *stall* diagnosis (why `extracted.json` stopped advancing). The
  research report's Decisions section fixes this boundary: GOAL (2) is capture *coupling*, and
  the stall item was never applied to this task's live description.
- Duplicating the orphan MCP-registration reaper (task 627) or the write-grant retraction
  (task 628).
- Softening `EXTENSION.md`'s "loading this extension into a repo is the ONLY thing that turns
  Sapience on there" opening claim, which the vendor-hook finding makes imprecise. GOAL (5) names
  two files and `EXTENSION.md` is not one of them; the research report records this as a
  follow-up task, and this plan honors that boundary. See Reasoned Exclusions.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Check (g) re-derives `hooks_opted_out()`'s two-part test locally; a future vendor change to that function desyncs the mirror silently | M | M | The new check's inline comment names the exact vendor file, function, and the two conditions it mirrors, so a reader comparing it against a newer `sapience_upkeep.py` sees the divergence at a glance |
| Check (i)'s failure branch (capture enabled + extension inactive) has no live fixture on this machine | L | H (certain) | Exercise it with a synthetic fixture, the pattern the existing suite already uses for its verifier cases |
| Check (h) and existing check (e) can both fail on one repository for related-but-distinct reasons, inviting a future maintainer to delete one as redundant | M | M | Each check's inline comment cross-references the other and states why both are needed (ledger-recorded cause vs. deployed-file symptom) |
| N-repeat probe multiplies live network calls against the vendor endpoint (2 calls per iteration, 6 at the default) | L | H | Default of 3 matches the measured evidence's own run count; `--repeat` is a flag, and the per-iteration `--connect-timeout 3 --max-time 8` bounds already in the script are unchanged |
| Scope creep from conflating capture *coupling* with the capture *stall* | M | M | Named as a Non-Goal above and in Reasoned Exclusions, citing the research report rather than re-deriving the distinction |
| Three sequential phases edit one file (`verify-sapience-mcp.sh`) while sibling tasks run on this shared tree | M | M | Re-read the file immediately before each edit; stage only this task's own hunks with an explicit file list; sibling scopes (527: `agent-system/extensions/core/**`; 635, 627: undeclared) do not name any sapience source-store path |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 1, 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Check (g) — Machine-Wide Vendor Hook Recurrence Detector [COMPLETED]

**Goal**: `verify-sapience-mcp.sh` fails when `$HOME/.claude/settings.json` carries any vendor
sapience injection/reporting hook, and reports `~/.sapience/config.json`'s `hooks` opt-out value
unconditionally.

**Tasks**:
- [x] Re-read `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` immediately
      before editing (shared tree, concurrent siblings). *(completed)*
- [x] Add check (g) after check (f), generalizing check (d)'s existing
      `[.hooks.<KEY>[]?.hooks[]?.command // empty]` `jq` idiom to iterate `SessionStart`,
      `SessionEnd`, and `Stop` and match any command containing `.sapience/mcp.py` or
      `.sapience/sapience_cli.py`. Report each match by hook key and command text. *(completed)*
- [x] Set `OVERALL_OK=false` on any match; the remedy line names the vendor opt-out
      (`~/.sapience/config.json`'s `"hooks": false`, or `SAPIENCE_NO_HOOKS=1`) and states that
      hand-removing the entries alone does not prevent recurrence. *(completed)*
- [x] Read `~/.sapience/config.json`'s `.hooks` key and emit its value (`false`, `true`, or
      `absent`) on **every** run, pass or fail — a `log` line, not conditioned on the match
      result. *(completed)*
- [x] Add an inline comment naming the mirrored vendor surface: `sapience_upkeep.py`'s
      `hooks_opted_out()` (env `SAPIENCE_NO_HOOKS` == `1`, else `config.json`'s `hooks` is
      `false`) and `wire_hooks()`'s three `REQUIRED` additions, so a future reader can check the
      mirror against a newer vendor file. *(completed)*
- [x] Update the script's own `# Checks (each reported by name):` header block to document (g).
      This header is what `--help` prints (`sed -n '2,/^$/p' "$0"`), so the edit is user-visible,
      not decorative. *(completed)*
- [x] Add regression cases to
      `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`,
      continuing its existing numbering after case (30): a fixture `HOME` whose
      `settings.json` carries a vendor `SessionStart --briefing-text` entry fails with exit 1 and
      names (g); a fixture with no vendor entry passes (g); the `hooks` opt-out value is reported
      in both; and a fixture whose `config.json` omits `hooks` entirely reports `absent` rather
      than crashing. Extend the suite's own header case list to match. *(completed: cases 37-40,
      inserted after case 22 inside the existing VERIFIER_SRC-gated block)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's two paths returns exactly
`test-sapience-mcp-registration.sh`, so the covering check is
`bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh`.

**Scope Hypothesis**: the vendor surface is exactly three hook keys (`SessionStart`,
`SessionEnd`, `Stop`) and two script basenames (`mcp.py`, `sapience_cli.py`); confirm at
implementation time by re-grepping `~/.sapience/sapience_upkeep.py` for `add_hook` and `REQUIRED`
before fixing the match set, and widen the key/basename lists if the vendor file disagrees.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` - add check (g); extend the
  header check list
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - add the
  check-(g) fixture cases; extend the header case list

**Verification**:
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` passes.
- `bash agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` run from this
  repository root reports (g) as a pass and prints `hooks=false` (the live state confirmed in
  Premise Re-Validation).
- `bash agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh --help` shows the new
  (g) line.
- `bash -n` and `shellcheck` clean on both edited files.

---

### Phase 2: Check (h) — "Active But Hook Fragment Never Merged" [COMPLETED]

**Goal**: a distinctly named failure for a repository whose own ledger records an active sapience
extension whose merged settings never received the hooks fragment, with reload/redeploy as the
stated remedy.

**Tasks**:
- [x] Re-read `verify-sapience-mcp.sh` immediately before editing. *(completed)*
- [x] Add check (h) reading the same `EXTENSIONS_FILE` check (a) already opens — no second file
      read — testing `.extensions.sapience.merged_sections.settings | has("hooks")` only when
      `SAPIENCE_ACTIVE` is true. *(completed)*
- [x] On `false`, `fail` with wording that names the cause (this repository's own ledger records
      a merge that predates the hooks fragment and was never re-run) and the remedy (reload the
      extension / redeploy for this repository), and set `OVERALL_OK=false`. *(completed)*
- [x] Skip with a `log` line, never a pass or a fail, when the extension is inactive or
      `EXTENSIONS_FILE` is unreadable — mirroring check (e)/(f)'s existing skip convention.
      *(completed)*
- [x] Add inline comments cross-referencing check (e): (h) reports the ledger-recorded cause,
      (e) reports the deployed-file symptom; both may legitimately fail on one repository and
      neither is redundant. *(completed)*
- [x] Extend check (e)'s own inline comment with the reciprocal cross-reference. *(completed)*
- [x] Update the script's header check list to document (h). *(completed)*
- [x] Add regression cases to `test-sapience-mcp-registration.sh`: an active-status fixture whose
      `merged_sections.settings` carries only `permissions` fails with exit 1 and names (h); an
      active fixture carrying both `hooks` and `permissions` passes (h); an inactive fixture logs
      a skip and neither passes nor fails (h). Extend the suite header case list. *(completed:
      cases 41-43; case 20's all-green fixture also updated to carry
      merged_sections.settings.hooks so it stays all-green under the new check)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's two paths returns exactly
`test-sapience-mcp-registration.sh`, so the covering check is
`bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh`.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` - add check (h); extend
  check (e)'s comment; extend the header check list
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - add the
  check-(h) fixture cases; extend the header case list

**Verification**:
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` passes.
- `bash agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` passes (h) against this
  repository (ledger carries `["hooks","permissions"]`).
- The same script run with `--project /home/benjamin/Projects/abood` from that directory fails
  (h) by name, which is the live reproduction of the dispatched evidence (c). If that repository
  has been repaired by the time this phase runs, record that and rely on the synthetic fixture
  case instead.
- `bash -n` and `shellcheck` clean on both edited files.

---

### Phase 3: Check (i) — Capture/Activation Coupling, and the Reconciliation Ruling [COMPLETED]

**Goal**: a per-project capture/activation coupling check covering both directions, with the
reconciliation-ownership ruling recorded at the check site.

**Tasks**:
- [x] Re-read `verify-sapience-mcp.sh` immediately before editing. *(completed)*
- [x] Add check (i): resolve the `capture.projects[]` entry in `~/.sapience/config.json` whose
      `path_prefix` is the **longest** prefix of (or equal to) `EXPECTED_PROJECT_PATH`, mirroring
      `~/.sapience/sapience_capture.py`'s `for_cwd()` rather than reinventing a match rule, and
      read that entry's `enabled` field. *(completed)*
- [x] Implement the four outcomes: active + enabled -> silent (or a brief pass line);
      active + not-enabled-or-absent -> informational `log` line naming the repository and the
      resolved entry, **not** a failure; inactive + enabled -> `fail` with
      `OVERALL_OK=false` (a capture-enabled path whose repository never opted into this
      extension's grants and hooks); inactive + not-enabled -> silent. *(completed)*
- [x] Handle an unreadable or `capture`-less `~/.sapience/config.json` as a skip `log` line, not
      a failure. *(completed)*
- [x] Record the ruling in the check's own inline comment block: this source store stops at the
      verifier check and does **not** write `capture.projects[].enabled` from either the
      `SessionStart` registration hook or the installer. Name the two reasons the research
      established — no script here reads or writes the `capture` key today, and `~/.dotfiles`
      already owns a capture-map writer, so a second independent writer would create the
      two-writers-disagreeing hazard this extension's own Hazards census warns about for the
      MCP-registration entry (where byte-identical convergence is deliberately maintained and no
      equivalent guarantee would exist here) — and state that active reconciliation, if built at
      all, belongs in `~/.dotfiles`. *(completed)*
- [x] Update the script's header check list to document (i). *(completed)*
- [x] Add regression cases to `test-sapience-mcp-registration.sh`: an inactive fixture with a
      capture-enabled matching prefix fails with exit 1 and names (i) (synthetic — no live
      instance of this direction exists on this machine); an active fixture with
      `enabled: false` emits the informational line and does **not** fail; an active fixture with
      no matching `path_prefix` emits the same informational line; a nested-prefix fixture
      (a shorter enabled prefix and a longer disabled one both matching) resolves to the
      **longer** entry. Extend the suite header case list. *(completed: cases 44-47)*

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's two paths returns exactly
`test-sapience-mcp-registration.sh`, so the covering check is
`bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh`.

**Scope Hypothesis**: the live `capture.projects[]` map holds 12 entries, of which 5 are
`enabled: true` and none is capture-enabled-with-inactive-extension; confirm at implementation
time by re-reading `~/.sapience/config.json` before relying on the live run as evidence, and fall
back to the synthetic fixture case if the map has moved.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` - add check (i) and the
  reconciliation ruling comment; extend the header check list
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - add the
  check-(i) fixture cases; extend the header case list

**Verification**:
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` passes.
- `bash agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` run from this
  repository root reports (i) as satisfied (`/home/benjamin/.config/nvim` is
  `enabled: true` and active).
- The same script run with `--project /home/benjamin/Projects/BimodalLogic` from that directory
  emits the informational active-but-capture-disabled line and does not fail on (i) — the live
  reproduction of the dispatched evidence (b).
- `bash -n` and `shellcheck` clean on both edited files.

---

### Phase 4: N-Repeat Unanimous-Agreement Verdict in the Context-Scoping Probe [COMPLETED]

**Goal**: `verify-sapience-context-scoping.sh` repeats its comparison N times and reports a
conclusive verdict only on unanimous agreement, with dedicated regression coverage.

**Tasks**:
- [x] Re-read `verify-sapience-context-scoping.sh` immediately before editing. *(completed)*
- [x] Add a `--repeat N` flag (default 3, matching the measured evidence's own run count),
      rejecting a non-integer or `< 1` value with exit 1 and a named reason. *(completed)*
- [x] Wrap the existing two-call body (both `post_context` calls, the inconclusive gate, and the
      text/visible comparison) in an N-iteration loop. Each iteration must mint its own fresh
      session-id pair exactly as a single run does today — the `$$`-plus-epoch `run_tag` already
      in `post_context` — so the server's per-session repeat-suppression starts empty on every
      iteration. Do not change `post_context`'s signature. *(completed: per-iteration suffix
      added to `sid` too, so two iterations landing in the same wall-clock second still mint
      distinct session_ids)*
- [x] Collect each iteration's outcome. Emit the shared outcome only when all N iterations agree;
      a per-iteration `INCONCLUSIVE` disqualifies agreement rather than being discarded as a
      non-vote. *(completed)*
- [x] On disagreement, print `INCONCLUSIVE` with a reason naming the per-iteration tally (e.g.
      `2 RESIDUAL_HOLDS, 1 RESIDUAL_LIFTED over 3 iterations`) and exit 2 — the existing
      inconclusive exit code, unchanged. *(completed)*
- [x] Preserve `--print`'s behavior, scoped to the final iteration's bodies, and keep the
      token-handling invariant intact (never echoed, never written, never in an error message or
      `--print` output). *(completed)*
- [x] Update the script's header: the `Usage:`/`Options:` blocks, the `usage()` heredoc, and the
      `Outcomes` block, so the single-run "treat a single RESIDUAL_LIFTED as
      inconclusive-leaning and re-run" guidance is replaced by the N-repeat rule the script now
      implements. *(completed)*
- [x] Create `agent-system/extensions/sapience/scripts/tests/test-sapience-context-scoping.sh`,
      reusing `test-sapience-capture.sh`'s curl-stub-on-`PATH` technique extended to a sequenced,
      per-call-index response table: unanimous-holds over N iterations yields `RESIDUAL_HOLDS`
      and exit 0; unanimous-lifted yields `RESIDUAL_LIFTED` and exit 0; a mixed tally yields
      `INCONCLUSIVE` and exit 2; one iteration returning a non-200 yields `INCONCLUSIVE` and
      exit 2 even when the rest agree; `--repeat 1` reproduces today's single-run behavior; a
      bad `--repeat` value exits 1. *(completed: 6/6 cases pass; the suite also builds a
      deployed-tree-shaped scratch fixture, mirroring test-sapience-capture.sh's build_scratch,
      since the script under test sources ${SCRIPT_DIR}/lib/common.sh which does not exist
      alongside it in the source store)*
- [x] Declare the new script in the manifest by running
      `bash .claude/scripts/sync-manifest-scripts.sh --write` from the repository root (the
      one-command repair `check-extension-docs.sh` Rule Q names), then review the resulting
      `provides.scripts` diff rather than hand-editing the array. *(completed: the new file had
      to be `git add`-staged first, since the script derives "on disk" from `git ls-files`; diff
      reviewed and confirmed to add exactly one entry)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Tier Justification**: this phase changes `manifest.json`'s `provides.scripts` declaration — the
cross-cutting deploy-pipeline surface that governs which source files are deployed at all, and
which no cheaper tier covers; `suite_selection_select` returns `__FULL_SWEEP__` for this phase's
path set, so no narrower suite subset can be claimed honestly.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh` - add the repeat
  flag, wrap the comparison in the N-iteration unanimous-agreement loop, and rewrite the
  header/usage/outcome blocks
- `agent-system/extensions/sapience/scripts/tests/test-sapience-context-scoping.sh` - new
  curl-stubbed regression suite for the repeat logic
- `agent-system/extensions/sapience/manifest.json` - `provides.scripts` gains the new test
  script (written by `sync-manifest-scripts.sh --write`, not by hand)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set) passes.
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-context-scoping.sh,test-manifest-scripts-sync.sh,test-script-inventory.sh`
  passes.
- `bash agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh --repeat 3`
  against the live endpoint prints exactly one outcome line; if the three iterations disagree it
  prints `INCONCLUSIVE` with the tally and exits 2, which is a correct result for this phase, not
  a failure of it.
- `bash agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh --help`
  documents `--repeat`.
- `bash -n` and `shellcheck` clean on both shell files.

---

### Phase 5: Rewrite the Two Falsified Documentation Sections [COMPLETED]

**Goal**: `injection-site-scoping.md`'s "No Machine-Wide Duplicate Hook Surface" section and
`per-repo-scoping.md`'s population-3 text state the actual design, and the reconciliation ruling
has a durable prose home.

**Tasks**:
- [x] Re-read both documentation files immediately before editing. *(completed)*
- [x] Rewrite `injection-site-scoping.md`'s "No Machine-Wide Duplicate Hook Surface" section to
      describe two independent mechanisms writing into the same file, kept clearly separated:
      (i) the five settings-fragment-merged hooks, still correctly per-repo-gated into a loaded
      repository's own `settings.local.json` — the section's one still-true claim; and (ii) the
      vendor upkeep path, which re-adds three hooks (`SessionStart --briefing-text`,
      `SessionEnd --receipt`, `Stop --effect-line`) to `$HOME/.claude/settings.json` on every
      `auto_update`/`update --wire` pass unless `~/.sapience/config.json`'s `hooks` is `false` or
      `SAPIENCE_NO_HOOKS=1` is set. *(completed)*
- [x] Replace that section's now-misleading inspection-commands framing: keep the commands as
      inspection aids but point the reader at `verify-sapience-mcp.sh`'s check (g) as the
      standing detector, and state that hand-removal alone does not prevent recurrence — the
      opt-out flag is what does. *(completed)*
- [x] Keep the section's existing task-siting statement (owning the registration entry's
      durability and retiring a machine-wide duplicate is sited in `~/.dotfiles`) intact; it is
      unaffected and still correct. *(completed)*
- [x] Extend `per-repo-scoping.md`'s population-3 bullet with the omitted gating layer: capture
      is a separate opt-in list (`~/.sapience/config.json`'s `capture.projects[].enabled`,
      matched by longest `path_prefix`), unconnected to extension activation, and a repository
      with no entry or a disabled one never reaches `upload.py`'s per-chunk `project` field at
      all because the opt-in gate short-circuits before extraction runs. Keep the existing
      sentence about `_chunk()`'s per-chunk `project` and the server-authored provenance drop —
      it is not false, only incomplete. Cross-reference check (i) rather than restating its
      mechanics. *(completed)*
- [x] Add a short named subsection to `per-repo-scoping.md` recording the reconciliation ruling
      durably in prose: this source store stops at the verifier check; writing
      `capture.projects[].enabled` belongs in `~/.dotfiles`, which already owns a capture-map
      writer; a second independent writer here would create the two-writers-disagreeing hazard
      the file's own Hazards census already names for the MCP-registration entry. *(completed:
      "### Capture/Activation Reconciliation")*
- [x] Touch no other section of either file, and add no page-level version label, supersession
      note, or "previously/no longer" framing (`rules/no-record-versioning-in-deliverables.md`):
      state the current design only. Use no task-number reference
      (`rules/no-task-references-in-deliverables.md`) — cite filenames, section headings, and the
      vendor function names instead. *(completed: verified via check-task-references.sh, 0
      occurrences, and a targeted grep for version/supersession phrasing)*
- [x] Reconcile the coupled derived surface in this same phase: run
      `bash .claude/scripts/generate-context-line-counts.sh --write` from the repository root so
      `index-entries.json`'s `line_count` for both edited files matches `wc -l`, then confirm only
      `line_count` values changed in the diff. *(completed: 325->348, 128->157; diff confirmed
      scoped to the two line_count values only)*

**Timing**: 1 hour

**Depends on**: 1, 3, 4

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's three paths returns
`__FULL_SWEEP__` (the two markdown files map to no suite), so per the source-store markdown
sub-case the covering check is
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`,
whose gate 3 is the `check-extension-docs.sh` run carrying Rule R's `index-entries.json`
`line_count` accuracy check.

**Scope Hypothesis**: exactly two sections need rewriting — `injection-site-scoping.md`'s
`## No Machine-Wide Duplicate Hook Surface` (at the live line count, the section spanning to
`## Candidate Follow-Up, Recorded Not Built`) and `per-repo-scoping.md`'s population-3 bullet
inside the four-population census; confirm at implementation time by re-grepping both files'
headings before editing, since a sibling task may have moved them.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md` -
  rewrite the "No Machine-Wide Duplicate Hook Surface" section
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` -
  extend population-3; add the reconciliation-ruling subsection
- `agent-system/extensions/sapience/index-entries.json` - `line_count` for both edited context
  files, reconciled in this phase by `generate-context-line-counts.sh --write`

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  passes, with gate 3 reporting no Rule R `line_count` drift.
- `grep -nE '\(v[0-9]|supersed|no longer|previously|formerly'` over both edited files returns no
  new record-versioning language, and
  `bash .claude/scripts/check-task-references.sh` reports no new finding for either file.
- A read-through confirms the rewritten section states both mechanisms and names check (g), and
  that population-3 names `capture.projects[].enabled` and cross-references check (i).

---

### Phase 6: Redeploy and Full Gate Set [COMPLETED]

**Goal**: the source-store changes reach this repository's deployed tree, and the complete gate
set passes against the result.

**Tasks**:
- [x] Redeploy with `bash agent-system/extensions/core/scripts/deploy-headless.sh` from the
      repository root. *(completed: RESULT=landed_verify_clean, deploy-headless.sh's own inline
      verification passed 40/40 checks)*
- [x] Confirm the deployed tree carries the three new checks and the `--repeat` flag:
      `grep -c '(g)\|(h)\|(i)' .claude/scripts/verify-sapience-mcp.sh` and
      `grep -c -- '--repeat' .claude/scripts/verify-sapience-context-scoping.sh` both non-zero,
      and `.claude/scripts/tests/test-sapience-context-scoping.sh` exists. *(completed: 20, 12,
      and the file exists)*
- [x] Confirm the merged `.claude/CLAUDE.md` and `.claude/context/index.json` picked up the
      documentation edits, and that `index.json`'s entries for both edited context files carry
      the reconciled `line_count`. *(completed: index.json entries carry 157/348, matching the
      source-store index-entries.json reconciled in Phase 5)*
- [x] Run the complete gate set and record the result. *(completed under this dispatch's Batch
      Gate Deferral directive, which names Phase 6 as one of the two deferred phases: ran the
      scoped discharge instead of an independent unflagged full sweep --
      `run-all.sh --only test-sapience-mcp-registration.sh,test-sapience-context-scoping.sh,
      test-manifest-scripts-sync.sh,test-script-inventory.sh` (4/4 pass) and
      `verify-deploy.sh --skip-slow --only-gate 3,4` (3/3 pass, doc-drift from Phases 1-4 now
      resolved post-redeploy). The complete unflagged gate set runs once for the whole batch at
      the end of this /orchestrate invocation, per the directive.)*
- [x] Run both verifiers end-to-end from the deployed tree as a final smoke check. *(completed:
      verify-sapience-mcp.sh reports (g)/(h)/(i) all PASS for this repository;
      verify-sapience-context-scoping.sh --help documents --repeat)*

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`

**Verification**:
- `bash agent-system/extensions/core/scripts/deploy-headless.sh` completes without error.
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set, all gates, not a subset and
  not under `--skip-slow` — passes.
- `bash .claude/scripts/verify-sapience-mcp.sh` exits 0 from this repository root, with (g),
  (h), and (i) all reported by name.
- `bash .claude/scripts/verify-sapience-context-scoping.sh --repeat 3` prints exactly one
  outcome line (any of the three outcomes is acceptable; `INCONCLUSIVE` on disagreement is the
  goal working as designed).

---

## Reasoned Exclusions

- **`EXTENSION.md`'s "ONLY thing that turns Sapience on there" opening claim.** The vendor-hook
  finding makes it imprecise: the three vendor-upkeep hooks fire regardless of any repository's
  extension state. GOAL (5) names two files and this is not one of them, and the research report
  records softening it as a follow-up task rather than a scope addition here. Excluded
  deliberately, not overlooked.
- **Repairing `~/Projects/abood`.** Check (h) surfaces the state by name with the remedy; running
  the reload is an operator action in a different repository, outside this task's edit target.
- **Writing `capture.projects[].enabled` from this source store.** Ruled out in Phase 3 on the
  two-writers-disagreeing hazard, with the ruling recorded at the check site and in
  `per-repo-scoping.md`. This is the dispatch's own stated fallback branch, taken explicitly.
- **The transcript-capture stall diagnosis.** Distinct from the coupling check GOAL (2) asks
  for, never applied to this task's live description, and explicitly out of scope per the
  research report's Decisions section.

## Testing & Validation

- [ ] `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` passes
      after each of Phases 1, 2, and 3.
- [ ] `bash .claude/scripts/tests/run-all.sh --only test-sapience-context-scoping.sh` passes
      after Phase 4.
- [ ] Each new check has both a failing and a passing fixture; check (i) additionally has a
      nested-prefix fixture and an informational-only (non-failing) fixture.
- [ ] The N-repeat logic has unanimous-holds, unanimous-lifted, mixed-tally, one-iteration-error,
      `--repeat 1`, and bad-`--repeat` cases.
- [ ] `bash -n` and `shellcheck` clean on every edited or created shell file.
- [ ] `bash .claude/scripts/verify-deploy.sh` (complete gate set) passes in Phase 6.
- [ ] No new task-number reference and no record-versioning language in any file landing under
      `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` — checks (g), (h), (i) and an
  updated header check list.
- `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh` — `--repeat N`
  and the unanimous-agreement verdict.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-context-scoping.sh` — new
  curl-stubbed regression suite.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` — extended
  with the check (g)/(h)/(i) cases.
- `agent-system/extensions/sapience/manifest.json` — the new test script declared in
  `provides.scripts`.
- `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`,
  `.../per-repo-scoping.md`, `agent-system/extensions/sapience/index-entries.json` — rewritten
  sections and reconciled `line_count`.
- Regenerated `.claude/**` deploy tree.
- `specs/636_sapience_activation_surface_scoping_gaps/summaries/01_*-summary.md` at completion.

## Rollback/Contingency

Each phase is a self-contained, separately committed edit to one or two files, so reverting a
single phase is `git revert` of that phase's own commit followed by a redeploy. Before the first
risky edit, take a non-reverting checkpoint with
`bash .claude/scripts/git-snapshot.sh 636 --no-revert` (never the default reverting form,
which is reserved for a genuine rollback and is unsafe on this shared tree with concurrent
siblings). If Phase 6's gate set fails on a cause traceable to one earlier phase, fix forward in
that phase's own files rather than discarding uncommitted work; if a failure is traceable to a
sibling task's in-flight edit outside this task's declared file list, stop and report it rather
than repairing another task's territory.
