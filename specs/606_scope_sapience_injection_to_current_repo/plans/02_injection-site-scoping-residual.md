# Implementation Plan: Task #606

- **Task**: 606 - Scope Sapience context injection to the current repository so a session stops
  receiving other repos' facts
- **Status**: [IMPLEMENTING]
- **Effort**: 4.75 hours
- **Dependencies**: 600 (completed), 611 (completed), 612 (completed)
- **Research Inputs**:
  - `specs/606_scope_sapience_injection_to_current_repo/reports/02_injection-site-scoping-findings.md`
  - `specs/606_scope_sapience_injection_to_current_repo/reports/01_seed-cross-repo-injection.md`
- **Artifacts**: plans/02_injection-site-scoping-residual.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research established, by direct live measurement rather than inference, that none of the three
primary-session injection sites can be scoped from this repository: `POST /v1/cli/context`
ignores the `project` field the `UserPromptSubmit` hook already sends, and its response carries
no per-item attribution a local wrapper could filter or label by. The deliverable is therefore
not a filter — it is to convert a measured, vendor-owned residual into durable, source-store
record plus two concrete owner actions, and to ship a small probe script that makes the residual
*falsifiable*, so the day the vendor honors `project` is detected rather than assumed. The task
is done when every injection site is named in the source store with what it does and does not
transmit, the residual and its owner actions are written out verbatim, the probe runs green, and
the deployed tree is regenerated and gated.

### Research Integration

- **The three sites, corrected.** Exactly one of three deployed hooks (`UserPromptSubmit`, via
  `sapience_cli.py hook prompt`) sends a repository identifier; `SessionStart`
  (`mcp.py --briefing-text` -> `GET /briefing` + `GET /v1/outstanding`) and `PreToolUse`
  (`sapience_cli.py hook tool`) send none. The dispatch description's "two of three" framing was
  corrected by research and is superseded here.
- **`project=` is dead on the hook-facing endpoint.** Two live calls differing only in
  `project` (`nvim` vs. a nonexistent sentinel) returned byte-identical bodies, including the
  cross-repo false claim `"Roadmap a780b271a contains 90 tasks across 10 topics"` reproduced
  *inside this repository*. This is the measurement the whole plan is built on.
- **No per-item attribution exists.** Response keys are `enabled, event, level, ms, src, status,
  text, visible`; items carry a title, a date, and a `(matched: ...)` tail, never a project or
  source. The dispatch's own conditional for the client-wrapper lever ("viable ONLY if the
  output carries recoverable source attribution") is settled in the negative by test.
- **Labelling over suppression, and neither is available.** Suppressing the hooks would cost
  exactly the cross-corpus abstraction class acceptance criterion 2 requires to survive, and the
  already-scoped `sapience-retrieve.sh` path feeds only dispatched subagents, never the primary
  session. No phase in this plan suppresses, filters, or narrows any hook.
- **The claim-shape heuristic filter is deliberately NOT built here.** Research scoped it as a
  separately-scoped exploratory follow-up given measured brittleness; this plan records the
  recommendation in the source store and creates no such mechanism.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag is set; this plan adds no
roadmap-review or roadmap-update phase and makes no change to `specs/ROADMAP.md`.

### Premise Re-Validation (Carried-Figure Discipline)

Each line the dispatch flagged was checked live in this planning dispatch, not carried on the
research report's authority alone:

| Carried claim | Live check run here | Result |
|---|---|---|
| L1: source store is `agent-system/extensions/sapience/**` | `jq -r '.extensions.sapience.source_dir' .claude-extensions.json` | **CONFIRMED** — resolves to `/home/benjamin/.config/nvim/agent-system/extensions/sapience`. Every edit target below is under it; no `.claude/**` path is named in any `Files to modify` block. |
| L43/L60: `upload.py`'s `_chunk()` sends `'project': m['project']` at line 236; `memory_provenance()` at line 1781 | `sed -n '236p'` and `sed -n '1781p'` on `~/.sapience/upload.py` | **CONFIRMED EXACT**, both lines verbatim as described. `upload.py` does not self-update, so these anchors are stable (unlike `sapience_cli.py`/`mcp.py`, whose line numbers research found already drifted). |
| L92 (acceptance criterion 4's local half): every source-store-owned write path is repo-tagged | `grep -n 'repo:' agent-system/extensions/sapience/scripts/sapience-remember.sh`; read of `rules/sapience-write-path.md` | **CONFIRMED CLOSED** by the sibling write-side work — `provenance="[repo:${repo_slug}] via sapience-remember.sh (Claude Code dispatch)"` is unconditional, and the standing rule prohibits naming an MCP write tool as a prescribed path. This plan adds no write-side phase; it references that closure. |

The dispatch description is otherwise unchanged by this check, with the single exception already
noted above: its "two of the three hooks transmit the asking repository" framing is corrected to
one of three.

## Goals & Non-Goals

**Goals**:
- Name all three primary-session injection sites in the source store, each with the exact
  deployed command, the endpoint it calls, whether it transmits a repository identifier, and
  whether the server honors it (acceptance criterion 3).
- Record the two measured foreclosures — `project` ignored on `POST /v1/cli/context`, and no
  per-item attribution in its response — as checkable facts with their reproduction, so a future
  reader does not re-litigate them from inference (acceptance criterion 1's residual).
- Write both owner actions out as exact, runnable/sendable text, not descriptions of text
  (acceptance criterion 5).
- Ship a read-only probe script that re-runs the two-call comparison on demand, so the residual's
  disappearance is detected rather than waited for, and that simultaneously evidences the channel
  still delivers content (acceptance criterion 2).
- Reference, not repeat, the already-closed write-side tagging (acceptance criterion 4).

**Non-Goals**:
- Suppressing, filtering, narrowing, or disabling any of the three hooks. Any such change would
  regress acceptance criterion 2 and is out of scope by construction.
- Building the claim-shape heuristic filter. Recorded as a candidate follow-up only.
- Any edit under `~/.claude/settings.json`, `~/.sapience/**`, or `~/.dotfiles/**` — all owner
  actions, all outside this source store, and the two vendor Python files self-update daily.
- Retagging or deleting existing vault objects. There is no delete API and no retag path for
  server-authored provenance; nothing here is costed on that being possible.
- Any change to per-repo activation gating, which is a different axis and already correct.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The record reads as though the gap is closed when it is not | H | M | Every surface added states plainly that no mechanism available to this repository closes it, and names the vendor ask as the only lever. The probe script's own output distinguishes "still ignored" from "now honored" rather than asserting either. |
| The probe script leaks the vault token into logs or stdout | H | L | The script reads `~/.sapience/config.json` for the token, never echoes it, never writes it to a file, and passes it only in an `Authorization` header built in-process. Phase 2's verification greps the script's own output for the token value and fails if it appears. |
| The probe script fails hard when offline, tokenless, or when the vendor config moves | M | M | It degrades: a missing config, missing token, or network failure exits non-zero with a named reason and no stack trace, and the phase's verification exercises the no-config path explicitly. It is a probe, never a gate anything depends on. |
| A new script lands without its registration surfaces, tripping `check-extension-docs.sh` Rule Q | M | M | Phase 2 adds the `manifest.json` `provides.scripts` entry in the same phase as the script; Phase 3 adds the `README.md` File Inventory row; Phase 4 runs the full gate set that enforces both. |
| `index-entries.json` `line_count` drift against edited context files | L | H | Declared in every phase that moves a line count (coupled-generated-surface obligation) and reconciled in Phase 4 via `generate-context-line-counts.sh --write`, which `deploy-headless.sh` also runs. `check-extension-docs.sh` Rule R is advisory here, not commit-blocking, so later reconciliation is permitted. |
| `__WHOLE_TREE__` in `file_scope` makes this task's lock overlap every other held task lock | M | H | Known and accepted: the declaration is mandatory for a phase invoking whole-tree regeneration, and under-declaring it to dodge the collision would be a false scope claim. Phase 4 is the only phase carrying it, so the collision window is one phase wide, at the end. |
| A task number leaks into a file under `agent-system/**` | M | M | Every deliverable below cites durable anchors (file paths, section headings, rule names, slugs) instead of task numbers; Phase 4's gate 4 (task-reference lint) catches a miss mechanically. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Record the injection-site inventory and the measured foreclosures [COMPLETED]

**Goal**: A new source-store domain note that names every primary-session injection site, states
what each transmits and what the server does with it, records the two foreclosures with their
reproduction, and carries both owner actions verbatim.

**Tasks**:
- [x] Create `context/project/sapience/domain/injection-site-scoping.md` under the source store
      with these sections, in this order:
  - **The three primary-session sites, by name.** A table with one row per site:
    `SessionStart` / `python3 "$HOME/.sapience/mcp.py" --briefing-text` / `GET /briefing` +
    `GET /v1/outstanding` / sends no repository identifier (neither client call sends a body) /
    N/A, the outstanding board is a cross-project aggregate by product design;
    `UserPromptSubmit` / `python3 "$HOME/.sapience/sapience_cli.py" hook prompt` /
    `POST /v1/cli/context` / sends `project=project_of(cwd)`, which resolves this repository to
    the literal slug `nvim` / **ignored by the server, measured**;
    `PreToolUse` / `python3 "$HOME/.sapience/sapience_cli.py" hook tool` / `POST /v1/cli/context`
    / sends only `file=<path>`, no project / N/A.
  - **The fourth path, deliberately contrasted**: `sapience-retrieve.sh` calls `GET /v1/search`
    with a `source=[repo:<slug>]` filter and IS scoped — but it feeds dispatched subagent
    prompts only, never the primary session, so it is not an alternative to the three sites
    above. Cite `per-repo-scoping.md` rather than restating its mechanism.
  - **Foreclosure 1 — `project` is ignored on the hook-facing endpoint.** State the measurement:
    two otherwise-identical `POST /v1/cli/context` calls differing only in `project` (a real
    slug vs. a nonexistent sentinel) return byte-identical `text`/`visible` bodies. Note that
    this is the hook-facing endpoint specifically, distinct from the `/v1/search` result
    recorded in `per-repo-scoping.md`.
  - **Foreclosure 2 — no per-item attribution to filter or label by.** List the response's
    top-level keys (`enabled`, `event`, `level`, `ms`, `src`, `status`, `text`, `visible`) and
    state that each rendered item carries a title, a date, and a `(matched: ...)` tail and
    nothing naming a project or source. State the consequence: a local wrapper around the hook's
    stdout has no attribution signal, so it can neither suppress nor label by source.
  - **The ruling: label, never suppress — and neither is reachable.** Record that suppression is
    rejected because the cross-corpus abstraction class (an abstraction belonging to no single
    repository) is the most valuable part of the channel, and that labelling is unreachable for
    want of attribution. State plainly that no mechanism available to this repository closes the
    gap, and that documents shared by other people (provenance of the form
    `people <name> | shared by <name> <timestamp> | doc {...}`) belong to no repository at all
    and are equally unlabellable.
  - **Owner action 1 — the vendor ask**, as a verbatim, sendable block quote: on
    `POST /v1/cli/context`, either honor `project` as a hard pre-filter (matching `/v1/search`'s
    existing `source=` semantics), or reflect the `project` field `/extract`'s per-chunk metadata
    already carries into each resulting knowledge object's authored `provenance`, so a
    `source=[repo:<tag>]` read-side filter reaches transcript-extracted content; and separately,
    expose `GET /v1/outstanding`'s existing server-side per-project grouping as an optional
    filter. Include the two-call falsification example. State why no local patch substitutes:
    `~/.sapience/mcp.py` and `~/.sapience/sapience_cli.py` self-update daily.
  - **Owner action 2 — the machine-wide duplicate hook surface**, as an exact, runnable
    inspection command the owner can paste
    (`jq -r '.hooks | keys' "$HOME/.claude/settings.json"`, plus the per-key command read), with
    the statement that these same hook commands currently fire from `$HOME/.claude/settings.json`
    in every repository on this machine regardless of per-repo extension activation, and that
    retiring that duplicate is owned by the `retire_machine_wide_sapience_surface` work sited in
    `~/.dotfiles` — a different repository this source store must not edit.
  - **Candidate follow-up, recorded not built**: a claim-shape heuristic that cross-checks a
    bulleted item asserting a countable identifier about "this repo" against this repository's
    own live `specs/state.json`/`specs/ROADMAP.md` before passing, suppressing, or relabelling
    it. Record its measured brittleness risk and that it is deliberately not built here.
- [x] Add a `domain/injection-site-scoping.md` row to
      `context/project/sapience/README.md`'s Loading Strategy table, phrased as "when to read
      it" like its sibling rows.
- [x] Add the matching entry to `index-entries.json` (`path`, `domain: project`,
      `subdomain: sapience`, `topics`, `keywords`, `summary`, `line_count`, empty `load_when`,
      `on_demand: true`), matching the shape of the six entries already there.
- [x] Re-read the new file end to end and confirm it contains no task number, no "task N"
      phrasing, and no record-versioning language ("previously", "no longer", "v1").

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts the site count is exactly three (`SessionStart`,
`UserPromptSubmit`, `PreToolUse`) for the primary-session path. Confirm at implementation time
with `jq -r '.hooks | keys' .claude/settings.local.json` and a read of each key's command; if a
fourth primary-session injecting hook has appeared, add its row rather than keeping the asserted
three (`SessionEnd` and `Stop` are reporting surfaces, not injection sites, and stay out of the
table with one sentence saying so).

**Tier Justification**: `suite_selection_select` over this phase's three paths returns
`__FULL_SWEEP__` (the new domain markdown maps to no suite), so the honest covering check is the
source-store gate subset `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh
--skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`, run alongside a `jq empty` read-back of
the edited `index-entries.json`.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md` - new domain note: site inventory, the two foreclosures, the ruling, both owner actions, the recorded follow-up
- `agent-system/extensions/sapience/context/project/sapience/README.md` - one new Loading Strategy row for the new domain note
- `agent-system/extensions/sapience/index-entries.json` - new index entry for the new domain note; also the coupled generated surface for this phase's context-file line counts (reconciled in Phase 4)

**Verification**:
- `jq empty agent-system/extensions/sapience/index-entries.json` exits 0, and
  `jq -r '.entries[].path' …` lists the new path exactly once.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no new finding attributable to these files.
- `grep -nE '\btasks? [0-9]+\b' agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`
  returns nothing.
- Diff read-through confirms every changed hunk is prose or a JSON data entry, with the three
  site rows naming the exact deployed commands.

---

### Phase 2: Ship the residual-monitor probe script [NOT STARTED]

**Goal**: A read-only, source-store-owned script that replays the two-call `project`-honoring
comparison on demand, reports whether the residual still holds, and shows that the channel still
delivers content — making the vendor ask falsifiable rather than open-ended.

**Tasks**:
- [ ] Create `scripts/verify-sapience-context-scoping.sh` under the source store, modeled on
      `scripts/verify-sapience-mcp.sh`'s header/exit-code style, with:
  - A header block stating what it probes, that it is read-only (no vault write, no local
    mutation), and that a green "still ignored" result is the expected state until the vendor ask
    lands.
  - Config resolution from `$HOME/.sapience/config.json` (`host`, `token`) with a named,
    non-zero, stack-trace-free exit when the file, the host, or the token is absent.
  - Two `POST /v1/cli/context` calls identical except for `project`: the resolved current-repo
    slug, and a sentinel string that is not a configured project. Compare the returned
    `text`/`visible` bodies.
  - Three distinguishable outcomes: **residual holds** (bodies identical — `project` still
    ignored), **residual lifted** (bodies differ — the vendor ask may have landed; say so loudly
    and point the reader at `domain/injection-site-scoping.md`), and **inconclusive** (non-200,
    empty body, or network failure).
  - An option to print the returned block so a reader can confirm content is still being
    delivered (acceptance criterion 2's non-regression evidence), and a `--help`.
  - The token read into a variable, passed only in the `Authorization` header, never echoed,
    never written to a file, and never included in any error message.
- [ ] Add `verify-sapience-context-scoping.sh` to `manifest.json`'s `provides.scripts` array,
      keeping the array's existing alphabetical order.
- [ ] Run `bash -n` and, if available, `shellcheck` on the new script; fix every finding.
- [ ] Exercise the degrade path (point the config lookup at a nonexistent file) and confirm a
      named non-zero exit with no stack trace and no token in the output.

**Timing**: 1.0 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts that `manifest.json`'s `provides.scripts` array is the
only registration surface a new extension script owes in this phase (the `README.md` File
Inventory row is deliberately deferred to Phase 3, which owns every `README.md` edit, so the two
phases never contend for that file). Confirm with
`bash agent-system/extensions/core/scripts/check-extension-docs.sh` after the manifest edit: a
Rule Q finding means the manifest entry is wrong, and a README-table finding is Phase 3's to
clear, not this phase's.

**Tier Justification**: `suite_selection_select` over this phase's two paths returns
`__FULL_SWEEP__` (a brand-new script basename pairs with no suite), so the covering checks are
the script's own `bash -n`/`shellcheck` lint plus
`bash agent-system/extensions/core/scripts/check-extension-docs.sh` for the manifest
declaration — no narrowing suite list is claimed, because the selector names none.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh` - new read-only probe script comparing two `POST /v1/cli/context` calls that differ only in `project`
- `agent-system/extensions/sapience/manifest.json` - declare the new script in `provides.scripts`

**Verification**:
- `bash -n agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh` exits 0;
  `shellcheck` (if present) reports no error-level finding.
- A live run prints one of the three named outcomes and exits with its documented code.
- The degrade run (nonexistent config path) exits non-zero with a named reason and no traceback.
- The script's full output, captured to a file, contains no substring of the configured token:
  verify by comparing against the token read separately, never by printing the token.
- `jq -r '.provides.scripts[]' agent-system/extensions/sapience/manifest.json` lists the new
  script exactly once, in alphabetical position.

---

### Phase 3: Amend the existing domain notes and the extension's top-level docs [NOT STARTED]

**Goal**: The existing source-store surfaces stop implying the vault's scoping story is complete:
the hazards census gains the primary-session item, the CLI inventory names the script that
actually backs two of the three hooks, and the extension's own README/EXTENSION pages carry the
residual, the new probe, and the pointer to the new domain note.

**Tasks**:
- [ ] `context/project/sapience/domain/per-repo-scoping.md`: add one Hazards item stating that
      the primary-session hook path has no scoping mechanism at all, independent of tagging
      state — a repo-tagged knowledge object is exactly as visible to another repository's
      `UserPromptSubmit` hook as an untagged one, because that path never reads `provenance` —
      and pointing at `domain/injection-site-scoping.md` for the measurement. Keep the existing
      four-population census intact; this item is about the read path, not a fifth population.
- [ ] `context/project/sapience/domain/vault-model.md`: scope the existing "The Local CLI's Exact
      Mode Inventory" heading explicitly to `~/.sapience/mcp.py`, and add a short section naming
      `~/.sapience/sapience_cli.py` (the `hook session|prompt|tool|stop` modes) and the
      `POST /v1/cli/context` endpoint those modes share, with the measured fact that its
      `project` field is ignored, pointing at `domain/injection-site-scoping.md` rather than
      restating the reproduction. Do not restate line numbers for either self-updating vendor
      file — cite function names, which are stable.
- [ ] `README.md`: add a "Gap 5" entry to "The Gaps This Extension Closes" naming the unresolved
      content-scoping residual, what it is bounded by (no working filter parameter, no per-item
      attribution), what this extension ships against it (the record, the probe, the owner
      actions), and explicitly that it is NOT closed — so Gaps 1-4 are not read as a complete
      account.
- [ ] `README.md`: add a File Inventory row for `scripts/verify-sapience-context-scoping.sh`
      describing it as the read-only residual probe.
- [ ] `EXTENSION.md`: add one short paragraph on the injection-site residual (one of three hooks
      sends a project identifier, the server ignores it, no local mechanism scopes the primary
      session) pointing at `domain/injection-site-scoping.md`, and add that file to the
      "Context Pointers" list.
- [ ] Update the three affected `index-entries.json` entries' `summary`/`keywords` where the
      amendments change what the file is about.
- [ ] Re-read every changed hunk for task-number references and record-versioning phrasing.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts that the four files above plus `index-entries.json` are
the complete set of source-store surfaces that currently describe Sapience's scoping story and
would be left stale by Phases 1-2. Confirm at implementation time with
`grep -rln 'scoping\|provenance\|v1/search\|hook' agent-system/extensions/sapience` and amend any
additional hit found, rather than keeping the asserted set. `rules/sapience-write-path.md` is
deliberately EXCLUDED: it governs the write path, which this task does not touch — and no task
in this phase edits it.

**Tier Justification**: `suite_selection_select` over this phase's five paths returns
`__FULL_SWEEP__` (the two domain markdown files map to no suite), so the honest covering check is
the source-store gate subset `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh
--skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`, run alongside
`bash agent-system/extensions/core/scripts/check-extension-docs.sh` for the README/manifest
declarations.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - one new Hazards item: the primary-session hook path has no scoping mechanism, independent of tagging
- `agent-system/extensions/sapience/context/project/sapience/domain/vault-model.md` - scope the existing CLI inventory to `mcp.py`; add the `sapience_cli.py` / `POST /v1/cli/context` surface
- `agent-system/extensions/sapience/README.md` - Gap 5 entry for the unresolved residual; File Inventory row for the new probe script
- `agent-system/extensions/sapience/EXTENSION.md` - residual paragraph and a Context Pointers entry for the new domain note
- `agent-system/extensions/sapience/index-entries.json` - summary/keyword updates for the amended entries; also the coupled generated surface for this phase's context-file line counts (reconciled in Phase 4)

**Verification**:
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no Rule Q, Rule S,
  or README/EXTENSION finding for this extension (a Rule R `line_count` finding is expected here
  and is reconciled in Phase 4).
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no new finding attributable to these files.
- `grep -rn 'injection-site-scoping' agent-system/extensions/sapience/` lists a pointer in
  `EXTENSION.md`, `context/project/sapience/README.md`, `index-entries.json`,
  `domain/per-repo-scoping.md`, and `domain/vault-model.md`, and the referenced file exists on
  disk.
- Diff read-through confirms the existing four-population census in `per-repo-scoping.md` is
  intact and the new item sits beside it rather than renumbering it.

---

### Phase 4: Deploy, gate, and walk the acceptance criteria [NOT STARTED]

**Goal**: The source-store changes reach the deployed tree, the complete gate set passes, the
probe runs live, and every acceptance criterion is answered with evidence rather than assertion.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` to
      reconcile `index-entries.json` `line_count` values for every context file this task moved.
- [ ] Redeploy with `bash agent-system/extensions/core/scripts/deploy-headless.sh` so
      `.claude/CLAUDE.md`, `.claude/context/index.json`, `.claude/context/project/sapience/**`,
      and `.claude/scripts/` pick up the new and amended files.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. Resolve every finding
      attributable to this task's files before closing the phase.
- [ ] Run `bash .claude/scripts/verify-sapience-context-scoping.sh` live from this repository and
      record which of the three outcomes it reports, together with the returned block, as the
      evidence for acceptance criteria 1 and 2.
- [ ] Confirm the deployed mirror actually carries the new note:
      `test -f .claude/context/project/sapience/domain/injection-site-scoping.md` and the entry
      is present in `.claude/context/index.json`.
- [ ] Walk the five acceptance criteria explicitly in the task summary, each with its evidence:
      (1) the measured impossibility plus the probe's result; (2) the probe's returned block
      showing the channel still delivers, and the fact that no phase suppressed or narrowed any
      hook; (3) the three-row site table in the new domain note, naming each site; (4) the
      write-side closure referenced via `rules/sapience-write-path.md` and
      `sapience-remember.sh`'s unconditional tag, with the vendor-owned remainder
      (server-authored provenance on transcript extraction) stated as the only residual; (5) both
      owner actions quoted verbatim from the new domain note.
- [ ] Record any issue or win encountered across the task via `issue-record.sh`.

**Timing**: 1.0 hour

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`
- `agent-system/extensions/sapience/index-entries.json` - `line_count` reconciliation for every context file this task moved

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set this repository aggregates —
  passes with no finding attributable to this task's files. This is the full tier's named check;
  no `--skip-slow` or `--only-gate` narrowing substitutes for it here.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports zero Rule R
  `line_count` findings for the sapience extension after the regeneration step.
- `bash .claude/scripts/verify-sapience-context-scoping.sh` runs from the deployed tree and
  reports a named outcome with a non-empty returned block.
- `test -f .claude/context/project/sapience/domain/injection-site-scoping.md` succeeds and
  `jq -r '.entries[].path' .claude/context/index.json | grep -c injection-site-scoping` returns 1.
- The summary contains the five-criterion walkthrough with its evidence.

---

## Testing & Validation

- [ ] `jq empty` passes on `index-entries.json` and `manifest.json` after every edit touching them.
- [ ] `bash -n` and `shellcheck` are clean on `verify-sapience-context-scoping.sh`.
- [ ] The probe's degrade path (missing config) exits non-zero with a named reason, no traceback,
      and no token in the output.
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` is clean for the
      sapience extension after Phase 4's regeneration.
- [ ] `bash .claude/scripts/verify-deploy.sh` passes in full at Phase 4.
- [ ] No file under `agent-system/**` added or modified by this task contains a task-number
      reference or record-versioning phrasing (gate 4 plus a manual grep).
- [ ] No hook, settings fragment, or retrieval path is narrowed, filtered, or disabled by any
      change in this task — confirmed by reading the final diff of `settings-fragment.json`
      (expected: unchanged) and `scripts/sapience-retrieve.sh` (expected: unchanged).

## Artifacts & Outputs

- `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`
  (new) — the site inventory, the two measured foreclosures, the label-not-suppress ruling, both
  owner actions verbatim, and the recorded follow-up.
- `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh` (new) — read-only
  residual probe.
- Amended: `context/project/sapience/README.md`, `context/project/sapience/domain/per-repo-scoping.md`,
  `context/project/sapience/domain/vault-model.md`, `README.md`, `EXTENSION.md`,
  `manifest.json`, `index-entries.json`.
- Regenerated deployed mirror under `.claude/` (disposable; not a tracked deliverable).
- `specs/606_scope_sapience_injection_to_current_repo/summaries/02_*-summary.md` — including the
  five-criterion walkthrough and both owner actions restated for the user.

## Rollback/Contingency

Every change in this task is additive documentation plus one new, unreferenced script: nothing
executes it on any lifecycle path, so reverting is low-risk. If a phase must be undone, revert
that phase's own commit with `git revert` rather than discarding working-tree state. If an
intentional rollback of uncommitted work is genuinely required, follow
`context/contracts/recovery.md`'s rollback rung for the snapshot-then-rollback invocation shape
(including its out-of-scope override flag) before running any destructive git command — never a
bare precautionary snapshot at phase start. If the deploy in Phase 4 produces unexpected drift,
re-running `deploy-headless.sh` is idempotent and is the first remedy; `.claude/` is a disposable
artifact regenerated from the source store, so it is never hand-repaired.
