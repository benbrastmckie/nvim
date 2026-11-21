# Implementation Plan: Task #678

- **Task**: 678 - Sapience linked-repo write and capture policy
- **Status**: [COMPLETED]
- **Effort**: 8 hours
- **Dependencies**: None
- **Research Inputs**: specs/678_sapience_linked_repo_write_and_capture_policy/reports/01_linked-repo-write-capture-policy.md
- **Artifacts**: plans/01_linked-repo-write-capture-policy.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The five questions the task description poses are answered by adopting `sf1-engine`'s
`integration/project-link.md` section 10 rulings by citation (that document names this work by
slug in its own cross-repository register as the obligation owed back), and all five answers come
out as "no change based on link state" except one: nothing today lets an orchestrated run in a
linked repo produce a project-tagged note, because `sapience-remember.sh` — the only sanctioned
write call site — sends no project field at all. The plan therefore writes the rulings into a new
dedicated domain record, threads them into the rule file and the three existing domain docs that
each own a piece of the reasoning, and extends `sapience-remember.sh` with the same runtime
project-key resolution `sapience-publish.sh ko` already implements (plain `project` key field,
never `project_cid`), plus the first test suite that script has ever had.

The settings fragment is deliberately **not** edited: Ruling 1 is that the seven-read-tool grant
is unchanged in a linked repo, so the fragment's "encoding" of that ruling is a regression
assertion that the grant set is exactly those seven and none of the four write tools — a check,
not a diff.

### Research Integration

The report's five rulings are adopted wholesale, including its two load-bearing mechanical
findings: that the already-built `/sapience` write surface is structurally interactive-only
(`AskUserQuestion` is withheld from every `Agent`-tool dispatch, so no mid-run ban needs lifting
for it), and that today's `project:` key field is pre-verification — it never reaches the
server-side origin/suggestion machinery `sf1-engine` ruling 7 gates, which is exactly why writing
it from the postflight path is safe now. The report's Finding 0 (the dispatch names a territory
path that does not exist) is carried into Phase 5 as a corrected edit target.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; `specs/ROADMAP.md` was not consulted and
no roadmap phases are included.

## Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class claim in the dispatch's `## Description` was checked against live state this
dispatch. Results, stated explicitly including the confirmations:

| Carried claim | Verdict |
|---|---|
| "the fragment grants only the seven read-shaped tools" | **CONFIRMED live.** `settings-fragment.json`'s `permissions.allow[]` holds exactly 7 `mcp__sapience__*` entries (`sapience`, `sapience_search`, `sapience_briefing`, `sapience_context`, `sapience_ask`, `sapience_outstanding`, `sapience_papers`); none of the four write tools appears. |
| "so `sapience_remember` and `sapience_wrapup` are denied in headless runs" | **CONFIRMED as a consequence** of the grant set above; not independently probed by issuing a denied call this dispatch. Unchanged. |
| "the extension's own surfaces tell agents not to call `sapience_remember` mid-run and supersede the vendor's save-as-it-lands nudge" | **CONFIRMED live** at `EXTENSION.md:27` ("Do NOT call `sapience_remember` proactively mid-run") and `EXTENSION.md:31` (the supersession paragraph). |
| "capture opt-in ... is unconnected to extension activation, so a repo with the extension loaded is still never extracted" | **CONFIRMED in shape, with one qualification.** `~/.sapience/config.json`'s capture map holds 12 entries, 4 enabled. `/home/benjamin/Projects/Sapience/sf1-engine` is absent from the map entirely and `BimodalLogic` is present-but-`enabled=false`, so the decoupling is real. The qualification matters for verification: **this** repository (`/home/benjamin/.config/nvim`) is `enabled=true`, so the "still never extracted" half is not true here — any check written against this repo's own capture state would measure the wrong case. |
| "orchestrated and subagent transcripts are filtered out of extraction (1013 of 1295 on this machine)" | **CARRIED-UNVERIFIED.** The ratio is sourced from `context/project/sapience/domain/transcript-filter-ceiling.md:34`, not re-measured this dispatch: re-deriving it requires a full census of the on-disk transcript corpus, and no ruling below turns on its exact value (Ruling 4 holds at any ratio). The filter's existence and non-overridability were confirmed by reading that file. |
| "direct `/ingest-kos` writes bypass the `auto_approve` review gate and there is no delete API, so a write is permanent and unreviewed" | **CONFIRMED live** in `scripts/sapience-remember.sh`'s own header (the three-probed-routes-404 note and the bypass statement). |
| "Territory: ... `merge-sources/claudemd.md`" | **REFUTED.** No such path exists in this extension. `manifest.json`'s `merge_targets.claudemd.source` is `EXTENSION.md`. Phase 5 edits `EXTENSION.md`; no file is created at the dispatch's literal path. |
| "a non-creator member's notes, which the server lands as suggestions only the author sees until confirmed" | **CARRIED-UNVERIFIED** (research report + prior session memory). Re-deriving it requires a live API call authenticated as a non-creator member of someone else's project, which is an outward-facing act outside this task's sanctioned surface. Ruling 5 does not depend on re-confirming it: it rules on which local surface *surfaces* such a suggestion, and that surface (`vault.suggestions`) was confirmed present live. |

Four facts material to the plan were measured this dispatch and are **not** in the description or
the report:

1. **`EXTENSION.md` is exactly 60 lines, against a hard 60-line ceiling.** `check-extension-docs.sh`
   Rule U fails an `EXTENSION.md` over 60 lines, and `SCHEMA_CONFORMANCE_GATE_MODE` defaults to
   `hard`. There is zero headroom: Phase 5's pointer addition must be line-neutral or net-negative.
2. **`rules/sapience-write-path.md`'s own corpus figure is under-counted.** It claims "14 files
   under the source store path, exactly three of which legitimately name the MCP write tools." The
   14 is exact. The three is not: a measured grep over those same 14 instruction surfaces returns
   **five** — `per-repo-scoping.md`, `review-gate-boundary.md`, `EXTENSION.md`, `index-entries.json`,
   and the rule file itself. `EXTENSION.md` (prohibition and supersession prose) and
   `index-entries.json` (a `keywords` array) are legitimate discussion occurrences that the rule's
   sanctioned-site list never names. Phase 3 corrects both the figure and the list.
3. **`index-entries.json` is a coupled, commit-blocking surface for every context-file edit.** Each
   entry carries a `line_count` checked against `wc -l` by `check-extension-docs.sh` Rule R, which
   is verify-deploy Gate 3 and fails hard (`INDEX_TRUTH_GATE_MODE` defaults to `hard`). Every phase
   below that edits a context file declares `index-entries.json` and regenerates in that same phase.
4. **This repository carries no `.sapience/project.json`** — it is an unlinked repo. The "linked
   repo" half of the done-when criterion is therefore verifiable only against a fixture binding
   (the harness `scripts/tests/test-sapience-publish.sh` already has: `write_binding` plus a
   stubbed `GET /v1/people/projects`), unless the user authorizes a real binding. See the
   `user_decision` recorded with this plan.

## Goals & Non-Goals

**Goals**:

- Rule on all five questions, for a repo with and without `.sapience/project.json`, and record the
  rulings in one durable, indexed domain record that cites `sf1-engine`'s
  `integration/project-link.md` section 10 rather than restating it as an independent claim.
- Thread each ruling into the surface that owns its reasoning: the write-path rule (grant and
  mid-run ban), `transcript-filter-ceiling.md` (the filter), `command-draft-and-picker.md` (the
  suggestion-surfacing path), `review-gate-boundary.md` (the write-tool disposition).
- Give an orchestrated run in a linked repo a working path to a project-tagged note, by extending
  `sapience-remember.sh` to send the plain `project` key field, and only that field.
- Give each ruling a check: an executable assertion where one is possible, a reproducible
  command with a stated expected result where it is not.
- Correct the two stale/incorrect figures measured above (the rule file's "three", the dispatch's
  non-existent merge-source path).

**Non-Goals**:

- Granting any of the four MCP write tools, in a linked repo or anywhere else (Ruling 1).
- Lifting the mid-run write-tool ban for any note kind (Ruling 2).
- Sending `project_cid` on any call, ever — an existing non-goal of `sapience-publish.sh`,
  extended to `sapience-remember.sh` for the same reason (`REPO_LINK_FOR` is dark for this
  credential, and the server's `_project_stamp` would overwrite a client-set `project` the day it
  is not).
- Writing or reading `~/.sapience/config.json`'s `capture.projects[]` from any script in this
  extension (Ruling 3). The capture map's owner is unchanged.
- Editing `context/project/sapience/domain/per-repo-scoping.md`. That file is in a concurrent
  sibling task's declared `file_scope` this same cycle (see Risks); Ruling 3 cites it instead.
- Binding this repository (or any repository) to a real Sapience project. That is a permanent,
  undeletable outward write and the user's call, not this task's.
- Creating any file at the dispatch's literal `merge-sources/claudemd.md` path.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent sibling task holds `per-repo-scoping.md` in its declared `file_scope` this same cycle; an edit there would collide | M | H | That file is excluded from every phase's `Files to modify`. Ruling 3 lives in the new domain record and cites `per-repo-scoping.md`'s Capture/Activation Reconciliation subsection by heading rather than editing it. Accepted cost: that subsection carries no forward pointer to the ruling; recorded as a follow-up, not smuggled in. |
| `EXTENSION.md` has zero line headroom (exactly 60 of 60) | H | H | Phase 5 is a separate phase whose verification is a `wc -l` check plus Rule U, so a net-positive edit fails loudly there instead of surfacing as an unrelated Gate 3 failure in Phase 6. |
| A `REPO_LINK_FOR` flag flip later makes a verified `project_cid` live, silently reopening `sf1-engine` ruling 7's gate for the postflight write | H | L | Phase 2 encodes "never send `project_cid`" as an explicit header non-goal in `sapience-remember.sh` (mirroring `sapience-publish.sh`'s) and as a test case asserting no `project_cid` key appears anywhere in the dry-run payload — so a future editor meets the constraint before adding the field. |
| Project-key resolution failure in a linked repo silently drops a postflight note | H | M | Phase 2's ruling: resolution failure degrades to an **untagged** write with a stderr warning — never a refusal, never a dropped note. This deliberately differs from `sapience-publish.sh ko`, which refuses to write untagged; the difference is justified in the script and tested. |
| One live `GET /v1/people/projects` per note means up to 8 redundant calls per completed task | M | H | Phase 4 adds an optional `--project-key` passthrough and resolves once at the `postflight-sapience-notes.sh` call site. Phase 2 remains correct standalone without it. |
| Editing a context file without regenerating `line_count` fails Gate 3 hard | M | M | `index-entries.json` is declared in every context-editing phase and `generate-context-line-counts.sh --write` runs in that same phase. |
| The linked half of the done-when criterion cannot be exercised live in this repo | M | H | Fixture-based verification in Phase 6, modelled on the existing `write_binding` + `STUB_PROJECTS_BODY` harness; the limit is stated in the summary rather than papered over, and the alternative is raised as a non-blocking `user_decision`. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4, 5 | 1 (phases 3, 5), 2 (phase 4) |
| 3 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Rulings Record and Index Wiring [COMPLETED]

**Goal**: One durable, indexed domain record stating Rulings 1-5, each with its check, citing
`sf1-engine`'s `integration/project-link.md` section 10 rather than paraphrasing it into a second
drifting copy.

**Tasks**:

- [x] Create `agent-system/extensions/sapience/context/project/sapience/domain/linked-repo-write-policy.md`
      with one section per ruling: *(completed: 126 lines, within the 90-130 scope hypothesis)*
      - **Ruling 1** (write-tool grant and per-session bound): unchanged in a linked repo — the
        seven read-shaped grants stand, the four write tools stay withheld, and a linked repo's
        project-tagged writes share the SAME existing 3-8-note postflight bound, never a second
        independently-sized one. Cite `sf1-engine` ruling 3 and `rules/sapience-write-path.md`'s
        existing inherit-the-bound sentence.
      - **Ruling 2** (mid-run ban): not lifted, for either note kind. State why the ban was never
        about note kind (the connector's hardcoded `provenance`, cited to
        `per-repo-scoping.md`'s "Why the MCP Write Tools Cannot Produce a Tagged Write"), and that
        `/sapience`'s Stage 9 picker is a structurally different, already-interactive-only path
        that was never subject to the ban — not an exception carved into it.
      - **Ruling 3** (capture opt-in): a link file implies nothing about capture; the capture-map
        entry's writer is unchanged. Cite `per-repo-scoping.md`'s "Capture/Activation
        Reconciliation" subsection by heading (do not edit that file).
      - **Ruling 4** (orchestrated transcripts): stay filtered; the postflight pass is a bounded
        curated set, not a substitute for the raw transcript, so its existence is not grounds to
        loosen the filter.
      - **Ruling 5** (non-creator member's suggestions): `GET /v1/people/projects/suggestions`,
        already read into `sapience-vault-read.sh`'s `vault.suggestions` and already folded into
        the `/sapience` draft, is the ruled surfacing path; promoting a suggestion to a confirmed
        note stays the member's own action in the app, never an agent's.
      - A **cross-harness agreement** section naming `sf1-engine`'s
        `integration/project-link.md` section 10 as the governing contract and stating that the
        rulings here agree with it by citation, discharging the obligation that document's
        cross-repository register records.
- [x] Add the matching entry to `agent-system/extensions/sapience/index-entries.json`, copying the
      field set of the existing `transcript-filter-ceiling.md` entry (`path`, `domain`,
      `subdomain`, `topics`, `keywords`, `summary`, `line_count`, `load_when`, `on_demand`) so
      Rule T schema conformance holds. *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` so
      the new entry's `line_count` matches `wc -l` (Rule R, hard-FAIL). *(completed: 9 sapience
      entries, 9 exact, 0 changed — line_count 126 was already correct)*
- [x] Add a one-line pointer to the new file in
      `agent-system/extensions/sapience/context/project/sapience/README.md`'s index. *(completed;
      README.md's own line_count bumped 20 -> 21 in the same line-count regeneration pass)*
- [x] Use no task-number references anywhere in the new file (it is a deliverable outside
      `specs/**`): cite filenames, section headings, and `sf1-engine`'s document instead.
      *(completed: grep returns no match)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/context/project/sapience/domain/linked-repo-write-policy.md agent-system/extensions/sapience/index-entries.json agent-system/extensions/sapience/context/project/sapience/README.md` covers this set, plus `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim` for the Rule R/S/T index-truth checks this phase's `index-entries.json` edit is the direct input to.

**Scope Hypothesis**: the new record is expected to run roughly 90-130 lines and to be the 9th
entry in `index-entries.json` (measured today: 8 entries). Confirm both at implementation time
with `wc -l` on the new file and `jq '.entries | length'` on the edited index, and let the
regenerator — not this estimate — set `line_count`.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/linked-repo-write-policy.md` - new; the five rulings and the cross-harness agreement section
- `agent-system/extensions/sapience/index-entries.json` - new index entry; `line_count` regenerated (coupled, commit-blocking via Rule R)
- `agent-system/extensions/sapience/context/project/sapience/README.md` - one-line pointer to the new record

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim`
  reports no Rule R (`line_count` mismatch), Rule S (unindexed context file), or Rule T (schema
  field set) finding for the sapience extension.
- `jq -e '[.entries[] | select(.path == "project/sapience/domain/linked-repo-write-policy.md")] | length == 1'`
  on `agent-system/extensions/sapience/index-entries.json` exits 0.
- `grep -nE 'task [0-9]+|tasks [0-9]+' ` over the new file returns nothing.
- Diff read-through confirming every ruling section names the `sf1-engine` document where it
  adopts a ruling, rather than asserting the ruling independently.

---

### Phase 2: `sapience-remember.sh` Project Tagging and Its First Test Suite [COMPLETED]

**Goal**: An orchestrated run in a linked repo produces a project-tagged note through the existing
sanctioned write path, with unlinked behavior byte-identical to today.

**Tasks**:

- [x] Add optional project-key resolution to `agent-system/extensions/sapience/scripts/sapience-remember.sh`: *(completed)*
      resolve the git toplevel, read `.sapience/project.json`'s `.project` cid, resolve it to a
      `key` via `GET /v1/people/projects`, and add `project: "<key>"` to the KO body. Reuse the
      shape `sapience-publish.sh`'s `ko` subcommand already implements (its runtime-resolution
      block and its defensive response-unwrapping), consistent with that script's own precedent of
      copying rather than extracting a shared helper.
- [x] Add an optional `--project-key <key>` flag that short-circuits the `GET` (consumed by *(completed)*
      Phase 4), mirroring `sapience-publish.sh`'s `--project` override precedence: explicit flag
      wins, then the binding file, then nothing.
- [x] Encode the degrade rule explicitly, in code and in the header: **no `.sapience/project.json` *(completed)*
      → write untagged, exactly as today, byte-identical body**; **binding present but resolution
      fails (non-JSON response, no matching entry, no `key`) → write untagged with a warning on
      stderr**, never a refusal and never a dropped note. State in the header why this differs
      from `sapience-publish.sh ko`, which refuses to write untagged: that script serves a
      human-confirmed single write, this one serves a bounded postflight set where losing a note
      is the worse failure.
- [x] Add the `project_cid` non-goal to the header as an explicit, checkable statement (mirroring *(completed)*
      `sapience-publish.sh`'s), naming the `REPO_LINK_FOR`-is-dark reason, so a future editor meets
      the constraint before adding the field.
- [x] Create `agent-system/extensions/sapience/scripts/tests/test-sapience-remember.sh` — the first *(completed: 11 assertions passing, numbered cases 1-7 covering (a)-(g))*
      suite for this script — modelled on `test-sapience-publish.sh`'s harness (`write_binding`,
      `STUB_PROJECTS_BODY`, `common_test_pass`), covering: (a) a fixture binding plus stubbed
      project list yields a `--dry-run` body containing `"project": "<key>"`; (b) no binding yields
      a body with no `project` key at all; (c) no `project_cid` key appears anywhere in any body;
      (d) `--project-key` wins over the binding and makes no `GET`; (e) binding present but the
      project list has no matching entry still writes, untagged, with a stderr warning and exit 0.
- [x] Add two policy-invariant cases to the same suite, as the checks for Rulings 1 and 3 (noting *(completed: cases 6-7)*
      in the suite header why they live here rather than in a suite of their own): (f)
      `settings-fragment.json`'s `permissions.allow[]` holds exactly the seven `mcp__sapience__*`
      read grants and none of `sapience_remember`/`sapience_wrapup`/`sapience_handoff`/
      `sapience_adddoc`; (g) `sapience-project-bind.sh` contains zero references to
      `~/.sapience/config.json` or `capture.projects` (measured baseline today: zero).
- [x] Register the new suite by running `bash .claude/scripts/sync-manifest-scripts.sh --write`
      (Rule Q requires every script on disk to appear in `provides.scripts`). *(completed; required
      `git add`-ing the new untracked file first, since the sync script derives its "on disk" set
      from `git ls-files`)*
- [x] Re-run `suite_selection_select` over `scripts/sapience-remember.sh` and confirm
      `test-sapience-remember.sh` now appears in its output (it cannot today, the file not
      existing), so the narrowing mechanism actually covers this script going forward. *(completed;
      required a redeploy first, since the lib's grep-based reference stratum reads deployed
      fixtures)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Tier Justification**: `bash .claude/scripts/verify-touched.sh` over this phase's declared `Files to modify` set covers the changed script together with its one enumerated direct dependent, the postflight call site.

**Scope Hypothesis**: the resolution block is expected to be roughly 35-55 added lines in
`sapience-remember.sh` and the new suite roughly 7 cases. Confirm by `diff --stat` against the
pre-change file and by the suite's own pass count, not by this estimate.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-remember.sh` - optional project-key resolution, `--project-key` flag, degrade rule, `project_cid` non-goal header
- `agent-system/extensions/sapience/scripts/tests/test-sapience-remember.sh` - new; the script's first suite, plus the Ruling 1 and Ruling 3 policy-invariant cases
- `agent-system/extensions/sapience/manifest.json` - `provides.scripts` registration of the new suite (coupled, commit-blocking via Rule Q)

**Verification**:
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-remember.sh` passes every case.
- `bash agent-system/extensions/sapience/scripts/tests/test-postflight-sapience-notes.sh` still
  passes unchanged (the caller is untouched in this phase).
- From this repository's own root (unlinked), `bash .claude/scripts/sapience-remember.sh --subject X
  --value Y --dry-run` prints a body whose `jq 'has("project")'` on the KO is `false` and which is
  identical to the pre-change output for the same arguments.
- `grep -c project_cid` over the printed dry-run bodies of every case is 0.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim`
  reports no Rule Q finding for the sapience extension.

---

### Phase 3: Rule File and Existing-Doc Ruling Pointers [COMPLETED]

**Goal**: Each ruling reachable from the surface that already owns its reasoning, and the rule
file's own corpus figures corrected to measured values.

**Tasks**:

- [x] Add a "Link State Does Not Change the Write Path" section to
      `agent-system/extensions/sapience/rules/sapience-write-path.md` stating Rulings 1 and 2: the
      grant is link-state-independent; the mid-run ban holds for both the person's typed decisions
      and agent-authored findings; a linked repo's project-tagged writes inherit the existing
      3-8-note bound and never add a second one. Point to the new record for the full rulings and
      to `sf1-engine`'s `integration/project-link.md` section 10 for the cross-harness contract.
      *(completed)*
- [x] Correct that file's corpus figure. It currently reads "14 files under the source store path,
      exactly three of which legitimately name the MCP write tools." The 14 is accurate; re-measure
      the second number after Phase 1 landed its new record and write the measured value.
      *(completed: measured 5 of 14 via the named grep; wrote 5 and named all five files)*
- [x] Add the sanctioned-discussion sites the list is missing — `EXTENSION.md` (its prohibition and
      vendor-supersession prose) and `index-entries.json` (its `keywords` array) — plus the new
      `linked-repo-write-policy.md` record, so the advisory inspection the rule prescribes has a
      correct baseline instead of flagging four legitimate sites.
      *(completed: also added the rule file's own "Permission Grant" section as the fourth
      previously-missing legitimate site)*
- [x] Add Ruling 4 to `context/project/sapience/domain/transcript-filter-ceiling.md`: the
      `source_skip()` filter stays in force in a linked repo, and the postflight pass does not make
      it redundant — a bounded curated set is a different object from the raw transcript, and
      admitting the latter would reopen the leak surfaces `sf1-engine` ruling 7 names. *(completed)*
- [x] Add Ruling 5 to `context/project/sapience/domain/command-draft-and-picker.md`, next to the
      Stage 3 draft-assembly material it concerns: `vault.suggestions` is the ruled surfacing path
      for a member's own pending suggestions, and promoting one stays the member's action.
      *(completed)*
- [x] Add a Ruling 2 pointer to `context/project/sapience/domain/review-gate-boundary.md`'s
      `## Write-Tool Disposition` section: the disposition is unchanged in a linked repo.
      *(completed)*
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` to
      resync the three edited context files' `line_count` values. *(completed: review-gate-boundary.md
      114->119, transcript-filter-ceiling.md 45->61, command-draft-and-picker.md 108->126)*
- [x] Use no task-number references in any edited file (all are deliverables outside `specs/**`).
      *(completed: verified via grep, zero matches)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/rules/sapience-write-path.md agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md agent-system/extensions/sapience/context/project/sapience/domain/transcript-filter-ceiling.md agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md agent-system/extensions/sapience/index-entries.json` covers this set, plus `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim` for the Rule R resync this phase's `index-entries.json` edit discharges.

**Scope Hypothesis**: measured today, 5 of the 14 instruction surfaces under the source store name
an MCP write tool; after Phase 1's record (which names them when stating Ruling 2) the figure
should be 6 of 15. Confirm at implementation time by re-running
`grep -rln 'sapience_remember\|sapience_wrapup\|sapience_handoff\|sapience_adddoc'` over the 14-plus-new
instruction-surface set and writing what it returns, not these numbers.

**Files to modify**:
- `agent-system/extensions/sapience/rules/sapience-write-path.md` - Rulings 1-2 section; corrected corpus figure; completed sanctioned-site list
- `agent-system/extensions/sapience/context/project/sapience/domain/transcript-filter-ceiling.md` - Ruling 4
- `agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md` - Ruling 5
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` - Ruling 2 pointer in the Write-Tool Disposition section
- `agent-system/extensions/sapience/index-entries.json` - `line_count` resync for the three edited context files (coupled, commit-blocking via Rule R)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim`
  reports no Rule R finding for the sapience extension.
- The grep named in the Scope Hypothesis is re-run and its output matches the figure written into
  the rule file, verbatim.
- Every file named in the rule file's sanctioned-discussion list exists on disk and does name at
  least one of the four tools (`grep -l` over the list returns every entry).
- Diff read-through confirming every added hunk is prose, and that no added sentence names an MCP
  write tool as a path a write SHOULD take — the rule's own standing contract applied to its own
  edit.

---

### Phase 4: Resolve-Once Pass-Through at the Postflight Call Site [COMPLETED]

**Goal**: One `GET /v1/people/projects` per completed task rather than one per note.

**Tasks**:

- [x] In `agent-system/extensions/sapience/scripts/postflight-sapience-notes.sh`, resolve the
      project key once (reusing the same resolution path, or by one `sapience-remember.sh`-side
      call whose result is reused) before the per-note loop, and pass it to every
      `sapience-remember.sh` invocation as `--project-key`.
      *(completed: resolution path reused by duplicating sapience-remember.sh's PROJECT-KEY
      RESOLUTION block directly into this script, since adding a resolve-only flag to
      sapience-remember.sh itself was outside this phase's declared file_scope)*
- [x] Keep the script's existing posture exactly: a resolution failure degrades to untagged writes
      for the whole set, records one `infrastructure/transport unavailable` issue row, and never
      aborts the loop or drops a note; the unlinked path is unchanged and issues no `GET` at all.
      *(completed)*
- [x] Forward `--dry-run` to the new flag path so the existing dry-run preview still prints each
      note's real body. *(completed: --project-key and --dry-run are independent conditional
      appends to the same remember_args array; neither one's presence affects the other)*
- [x] Extend `agent-system/extensions/sapience/scripts/tests/test-postflight-sapience-notes.sh`
      with: a linked fixture producing N notes each carrying the same resolved key with exactly one
      `GET` observed; and an unlinked fixture producing byte-identical bodies to today's.
      *(completed: Cases 10 and 11; full suite 41/41 passing)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/verify-touched.sh` over this phase's declared `Files to modify` set covers it entirely — every touched path in this phase resolves to a real suite, with no unmapped path.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/postflight-sapience-notes.sh` - resolve once, pass `--project-key` per note, degrade untagged on failure
- `agent-system/extensions/sapience/scripts/tests/test-postflight-sapience-notes.sh` - linked and unlinked fixture cases, including the one-`GET` assertion

**Verification**:
- `bash agent-system/extensions/sapience/scripts/tests/test-postflight-sapience-notes.sh` passes
  every case, old and new.
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-remember.sh` still passes
  (the flag contract Phase 2 introduced is unchanged).
- The linked fixture's stub records exactly one `GET /v1/people/projects` hit for a multi-note set.

---

### Phase 5: Line-Neutral `EXTENSION.md` Pointer [COMPLETED]

**Goal**: The new record reachable from the merged `.claude/CLAUDE.md` section, without breaching
the 60-line ceiling.

**Tasks**:

- [x] Record `wc -l agent-system/extensions/sapience/EXTENSION.md` before editing (expected 60). *(completed: measured 60, matching the expectation)*
- [x] Add `context/project/sapience/domain/linked-repo-write-policy.md` to the `### Context
      Pointers` list, and offset the addition by condensing an existing wrapped paragraph in the
      same file so the total does not grow. Do not drop an existing pointer to make room.
      *(completed: appended as the 8th list entry; offset by rejoining the two-line `/sapience`
      paragraph into one source line, a pure line-count reduction with no change to rendered
      content since Markdown already treated the pair as one soft-wrapped paragraph)*
- [x] Do not create or reference `merge-sources/claudemd.md`; `manifest.json`'s
      `merge_targets.claudemd.source` is `EXTENSION.md` and that is the only merge source.
      *(completed: confirmed no `merge-sources/` directory exists under
      agent-system/extensions/sapience/)*
- [x] Re-record `wc -l` and confirm it is at most 60. *(completed: measured 60, at the ceiling)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/EXTENSION.md` covers this set, which maps entirely to real suites with no unmapped path, and `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim` covers Rule U specifically.

**Scope Hypothesis**: `EXTENSION.md` is exactly 60 lines today against a hard 60-line Rule U
ceiling, so this edit has zero headroom and must be net-zero or net-negative. Confirm with the
before/after `wc -l` the task list already requires, not with this statement.

**Files to modify**:
- `agent-system/extensions/sapience/EXTENSION.md` - new context pointer, offset by condensing existing prose; stays at most 60 lines

**Verification**:
- `test "$(wc -l < agent-system/extensions/sapience/EXTENSION.md)" -le 60` succeeds.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim`
  reports no Rule U or Rule V finding for the sapience extension.
- `grep -q 'linked-repo-write-policy' agent-system/extensions/sapience/EXTENSION.md` succeeds.
- No file exists at `agent-system/extensions/sapience/merge-sources/claudemd.md`.

---

### Phase 6: Deploy, Done-When Verification, and Orchestration-Close Deferral [COMPLETED]

**Goal**: The deployed tree carries every change, and both halves of the done-when criterion are
demonstrated — the linked half against a fixture binding, the unlinked half live in this repository.

**Tasks**:

- [x] Regenerate the deployed tree: `timeout 540 bash .claude/scripts/deploy-headless.sh` (the
      dispatch reports the sapience extension's deployed copy already stale before this task's
      changes; the Bash tool `timeout` parameter must be raised to 600000, not its 120000ms
      default). Do not hand-patch any file under `.claude/**` as a substitute. *(completed:
      `deploy-headless.sh` reported `RESULT=landed_verify_clean`, 41 checks/0 failures; the
      sapience extension's `source_git_head` now matches the current source HEAD)*
- [x] Linked half, fixture-based: in a scratch git repo carrying a `.sapience/project.json`
      fixture with a stubbed `GET /v1/people/projects`, run the postflight path end to end under
      `--dry-run` and confirm each emitted body carries `"project": "<key>"` and no `project_cid`.
      *(completed: `postflight-sapience-notes.sh --dry-run` against the fixture repo emitted
      `"project": "oliver-ben"` with no `project_cid` key anywhere, exit 0)*
- [x] Linked half, interactive path: confirm by inspection plus the existing
      `test-sapience-publish.sh` cases that `/sapience`'s Stage 9 picker remains the ruled path for
      a person's typed decision, and record in the summary that this path cannot be exercised by an
      agent at all (`AskUserQuestion` is withheld from every `Agent`-tool dispatch) — a stated
      verification limit, not a silent gap. *(completed: `skill-sapience/SKILL.md` Stage 9 is
      still the single `AskUserQuestion` approval picker; `test-sapience-publish.sh` 53/0; the
      interactive run itself is agent-exercise-limited, recorded in the summary rather than
      silently skipped)*
- [x] Unlinked half, live: from this repository's own root, confirm `sapience-remember.sh --dry-run`
      and the postflight path emit bodies with no `project` key, byte-identical to the pre-change
      output captured in Phase 2. *(completed: both the pre-Phase-2 `sapience-remember.sh` and
      the pre-Phase-4 `postflight-sapience-notes.sh`, run live and unlinked, produced
      sorted-key-identical bodies to the current deployed scripts)*
- [x] Re-read every ruling's check in the new record and confirm each one, as written, actually
      runs and reports what the record claims it reports. *(completed: all 5 rulings' checks
      re-run and confirmed — see Phase 6 Verification Notes in the summary)*
- [x] Run the scoped touched-path check for this dispatch:
      `bash .claude/scripts/verify-touched.sh <every path this task touched>`. *(completed:
      `verify-touched.sh` (no-args form) selected 61 suites + 5 owed across 16 touched paths —
      98 passed, 0 failed, 0 NEW)*
- [x] State explicitly, in the phase's own verification notes and in the summary, that the complete
      gate set is **deferred to the orchestration close** (the once-per-invocation batch gate stage)
      rather than independently run in this dispatch. *(completed: stated below and in the summary;
      this dispatch ran the scoped `verify-touched.sh` battery plus the plan's own
      `--only-gate 3` check, never the full `verify-deploy.sh` sweep)*

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree from the source store
- (no source-store file is edited in this phase except as a fix-forward correction to an earlier phase's own declared file)

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes and the dispatch's
  stale-extension warning for `sapience` no longer reproduces.
- The fixture run emits `"project": "<key>"` on every note and `grep -c project_cid` over the
  emitted bodies is 0.
- The live unlinked run's body is byte-identical to the Phase 2 pre-change capture.
- `bash .claude/scripts/verify-touched.sh <touched paths>` reports green.
- Under `/orchestrate`, the complete gate set is explicitly deferred to the orchestration close
  per `context/contracts/batch-gate-stage.md`; this phase runs the scoped check above and records
  the deferral rather than invoking the full battery itself. In a standalone, non-orchestrated run
  with no such close to defer to, `bash .claude/scripts/verify-deploy.sh` runs here directly.

## Testing & Validation

- [x] `bash agent-system/extensions/sapience/scripts/tests/test-sapience-remember.sh` — all cases,
      including the Ruling 1 grant assertion and the Ruling 3 zero-reference assertion.
      *(completed: 11 passed, 0 failed)*
- [x] `bash agent-system/extensions/sapience/scripts/tests/test-postflight-sapience-notes.sh` —
      all cases, old and new. *(completed: 41 passed, 0 failed)*
- [x] `bash agent-system/extensions/sapience/scripts/tests/test-sapience-publish.sh` — still green
      (its `ko` project-resolution cases are the model this task copies and must not regress).
      *(completed: 53 passed, 0 failed)*
- [x] `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim`
      — no Rule Q/R/S/T/U/V finding for the sapience extension. *(completed: ran with
      `--skip-unchanged` added per this dispatch's Batch Gate Deferral directive; 2 checks, 0
      failures — the Phase 2-4 deploy-drift FAIL seen before this phase's deploy is gone)*
- [x] Every ruling in the new record has a check that was actually executed, with its observed
      result recorded in the summary — never a check asserted to pass on sight. *(completed: see
      Phase 6 Verification Notes in the summary — all 5 rulings' checks re-run live)*
- [x] No deliverable file outside `specs/**` contains a task-number reference or
      record-versioning language. *(completed: this phase added no new deliverable prose outside
      `specs/**`; only `.claude-extensions.json` and the whole-tree deploy regeneration changed
      outside `specs/**`, neither of which is prose)*

## Artifacts & Outputs

- `agent-system/extensions/sapience/context/project/sapience/domain/linked-repo-write-policy.md`
  (new) — Rulings 1-5 and the cross-harness agreement.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-remember.sh` (new) — the script's
  first suite plus two policy-invariant cases.
- Edits to `rules/sapience-write-path.md`, `EXTENSION.md`, `index-entries.json`, `manifest.json`,
  `context/project/sapience/README.md`, and the three domain docs named in Phase 3.
- Edits to `scripts/sapience-remember.sh` and `scripts/postflight-sapience-notes.sh`.
- A regenerated deployed `.claude/` tree.

## Rollback/Contingency

Every phase is an additive edit to a tracked file plus two new files; no deletion, no migration,
no outward-facing write. To revert, `git revert` the phase commits in reverse order and re-run
`bash .claude/scripts/deploy-headless.sh`. The two highest-risk partial states have specific
contingencies:

- If Phase 2's resolution block misbehaves against the live API, the degrade rule it encodes means
  the worst outcome is an untagged note plus a stderr warning — today's behavior — so the postflight
  path is never left worse than before the change. Reverting that one file restores it exactly.
- If Phase 5's line-neutral edit cannot be made without dropping a pointer, leave `EXTENSION.md`
  unchanged and record the exclusion: the new record stays reachable through the context index and
  `context/project/sapience/README.md` regardless, so the pointer is a convenience, not the
  reachability mechanism.

A defensive checkpoint before Phase 2 or Phase 6, if wanted, is
`bash .claude/scripts/git-snapshot.sh 678 --no-revert` — never the default reverting form, which
belongs only to a genuine rollback.
