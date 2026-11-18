# Implementation Plan: Task #644

- **Task**: 644 - Leave a spoken-word recap at the end of an orchestration and recommend /recap to hear it
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: 503, 526, 538, 558, 643 (all territory edges, not subject edges; all five are [COMPLETED] as of this plan's authoring)
- **Research Inputs**: specs/644_orchestration_recap_spoken_on_demand/reports/01_orchestration-recap-design.md
- **Artifacts**: plans/01_orchestration-recap-spoken.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

An `/orchestrate` run's conclusion stage will, as part of its single emission step, compose a
short speech-shaped prose recap of the run and persist it to a session-keyed file beside the
other per-invocation orchestration runtime files, then recommend a new `/recap` command by name
in its written output. `/recap` — a user-only, direct-execution command — reads the most recent
recap, speaks it through piper, and prints it. Nothing on the orchestration path ever invokes
piper, paplay, or any other audio sink; speaking is always a separate step the user starts. Done
means: the seven acceptance criteria in the task description all hold, the source store is the
only edit target, and a redeploy lands clean.

### Premise Re-Validation (Carried-Figure Discipline)

Three description lines were flagged for re-checking. All three were checked against the prior
research report and against live state; results stated explicitly, including where they only
confirm the description unchanged:

1. **"`core/hooks/tts-notify.sh` cannot serve this — closed lifecycle vocabulary, no arbitrary
   text"** — CONFIRMED UNCHANGED, live. The hook accepts only no-argument, `--lifecycle STATUS`,
   and `--stop` forms; its header enumerates the closed status vocabulary
   (researching/researched/planning/planned/implementing/completed/blocked); there is no
   arbitrary-text entry point. `TTS_ENABLED` (default `1`) and `PIPER_VOICE` (default
   `$HOME/.local/share/piper/en_US-lessac-medium.onnx`) are both present as documented. One
   refinement the research pass added and this plan carries forward: the hook's `speak()` helper
   interpolates its message into a single-quoted string inside a nested `bash -c`, which is safe
   only for its punctuation-free vocabulary — the new path must not copy that shape.
2. **"Five dependencies, all territory edges"** — CONFIRMED, with one state change. The task's
   own `specs/state.json` entry carries `dependencies: [503, 526, 538, 558, 643]` exactly as
   described. All five are now `completed`, so no serialization conflict remains against any of
   them; the edges are satisfied, not merely declared.
3. **"The #643 edge was discovered after the breakdown was confirmed; `overlaps-open` with
   `mechanical_class: overlap` on two shared paths"** — CONFIRMED verbatim from the task entry's
   own `audit_verdict`: `verdict: overlaps-open`, `project_number: 643`,
   `mechanical_class: overlap`, `shared_paths: [conclusion-stage.md,
   orchestrate-batch-results-template.md]`, `semantic_score: 0.328`. That record is `completed`.

Every file this plan names as a correction target was read at authoring time and exists:
`scripts/lib/runtime-file-patterns.sh`, `context/contracts/conclusion-stage.md`,
`context/standards/postflight-tool-restrictions.md`,
`context/patterns/orchestrate-batch-results-template.md`, `merge-sources/claudemd.md`,
`manifest.json`, `index-entries.json`, `scripts/tests/suite-classification.data`, and the nvim
extension's `context/project/neovim/guides/tts-stt-integration.md`. Each phase's entry annotation
states what the implementer does if a target has moved by the time that phase runs.

### Research Integration

The research report's architecture is adopted in full and is not re-litigated here:

- A fourth per-session resolver, `runtime_recap_path`, added to `runtime-file-patterns.sh`
  following the three existing resolvers' exact `(specs_dir, session_id)` shape, with **no new
  `RUNTIME_FILE_IDS`/`RUNTIME_FILE_PATTERNS` array member** — `specs/.orchestration/` is already
  covered directory-class, the same reasoning the conclusion-approval ledger file already relies
  on.
- One new script, `orchestrate-recap.sh`, carrying both a `--write` mode (the conclusion stage's
  call) and a default speak mode (the command's call), mirroring the existing one-script-two-modes
  shape of `orchestrate-suggest-next-batch.sh`.
- The recap's prose is composed by the orchestration lead itself at the emission step, where the
  wins / channel-outcome / next-batch data is already in hand; the script stores and plays, never
  synthesizes. The on-demand recompose branch is necessarily mechanical, since no model is in the
  loop when the command runs standalone.
- `/recap` is user-only, mirroring the three-layer enforcement the existing tagging skill
  documents.

Two gate collisions were found at plan-authoring time, beyond the report's findings, and are
designed around rather than discovered at implementation time:

- **A dead-command-recommendation lint exists** (`scripts/lint/lint-dead-command-recommendations.sh`)
  and enumerates valid commands at run time from `*/commands/*.md`. A `/recap` recommendation
  landing in the results template before `commands/recap.md` exists would be flagged. Phase
  ordering closes this: the command file lands in Phase 2, the recommendation in Phase 4.
- **A new test suite needs a classification row.** `scripts/tests/suite-classification.data`'s own
  header states `lint-unit-integration-boundary.sh` fails loudly on any discovered-but-unclassified
  suite, so the new suite's row is part of the same phase that adds the suite.

### Prior Plan Reference

No prior plan. This is the task's first planning round.

### Roadmap Alignment

No `roadmap_path` was supplied to this dispatch and no roadmap flag was set, so no roadmap
consultation was performed and this plan asserts no roadmap alignment.

## Goals & Non-Goals

**Goals**:

- A conclusion stage that reaches its emission step leaves a session-keyed recap file under
  `specs/.orchestration/` and recommends `/recap` by name in its written output.
- `/recap` speaks the latest run's recap through piper, prints it, and exits `0`.
- `/recap` recomposes a recap mechanically when no recap file exists, rather than failing.
- With no piper binary or no voice model, `/recap` prints and exits `0` — no second engine.
- `TTS_ENABLED=0` suppresses audio on every path with printed text intact.
- The conclusion stage's call to the new script is in-contract against the Move 5 Bash allowlist.
- No file landing under `agent-system/**` carries a task-number reference or record-versioning
  language.

**Non-Goals**:

- No session-id argument, no `--list` mode, no recap history browsing.
- No espeak-ng and no second TTS engine on any branch.
- No change to the conclusion stage's channel routing, filter predicate, or exactly-one-channel
  rule.
- No edit to the event-announcement hook family (`tts-notify.sh`, `claude-stop-notify.sh`,
  `settings-hooks.json`, `root-files/settings.json`, `scripts/lifecycle-notify.sh`) — a separate,
  already-completed record owns those, and this work shares only one documentation file with it.
- No audio played by the orchestration itself, on any path, under any condition.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Free-form recap prose breaks shell quoting, or lets stored text influence shell parsing | H | M | The speak path never interpolates recap text into a shell string: text goes to a temp file and reaches piper on stdin; a dedicated regression test feeds text containing an apostrophe and a double quote (Phase 3, case 7) |
| The conclusion stage's recap write fails and blocks the emission step, stranding the pending marker | H | L | The call is non-fatal by contract: a failed write warns on stderr and the step proceeds to its existing final action (marker deletion) unchanged |
| A malformed or truncated runtime metadata file breaks the recompose branch | M | M | The recompose branch validates the JSON parses and carries the expected keys before use, and degrades to one fixed generic sentence with exit `0` — the acceptance bar is that recompose SUCCEEDS, never that it merely attempts |
| A `/recap` recommendation lands while the command file does not yet exist, tripping the dead-command lint | M | M | Phase ordering: the command file (Phase 2) precedes the recommendation (Phase 4) in the dependency graph, not merely in file order |
| A new script or skill directory left out of `manifest.json` trips the undeclared-file doc-lint rules | M | M | Each phase registers its own new files in `manifest.json` in that same phase, never deferring registration to the deploy phase |
| The deployed settings' permission list carries no explicit piper/paplay entry | L | L | Matches existing practice for every other direct-execution skill that invokes scripts; recorded as an advisory finding, not a blocker. If a permission prompt is observed during Phase 5's acceptance walkthrough, record it via `issue-record.sh` rather than widening the permission surface in this task |
| A hand edit lands under `.claude/**` and is silently wiped by the next regeneration | H | L | Every edit target in every phase is a source-store path; Phase 5 redeploys and confirms `RESULT=landed_verify_clean` |

## Decisions

- **`/recap` is user-only — ruling stated explicitly, as the task description requires.** It is
  marked user-only in the same sense the tagging skill is, via all three enforcement layers:
  `user-only: true` in the skill's YAML frontmatter, an explicit "Agents MUST NOT invoke"
  statement in both the skill and the command file, and omission from the Skill-to-Agent Mapping
  table. The rationale is **not** the tagging skill's deployment-timing rationale. It is
  structural: the binding constraint on this work is that an orchestration must never play audio
  by itself, and "nothing currently calls it" is a property of today's code, not a guarantee.
  User-only status is what makes the constraint hold against a future chained dispatch, a
  conclusion-stage follow-up, or a future skill that might otherwise reach for it. The constraint
  itself is restated in the new skill and command files, so a reader of those files alone sees it.
- **One script with two modes, not two scripts.** `--write` (conclusion stage) and the default
  speak mode (the command) share the resolver, the latest-file resolution, and the text-handling
  code; splitting them would duplicate all three. This mirrors the existing next-batch suggester,
  which carries a propose-only and a write form in one file.
- **The lead composes the prose; the script never synthesizes it.** The emission step already
  holds the wins, channel outcomes, and next-batch suggestion when it renders its report; it
  composes the parallel speech-shaped sentences there and hands them to the script. The script's
  job is storage and playback mechanics. The recompose branch is the one exception and is
  deliberately mechanical and lower-fidelity — an accepted trade for a fallback path with no model
  in the loop, not a gap in the primary path.
- **No new runtime-file-pattern array member.** Only a resolver function. The containing directory
  is already covered directory-class; adding an array member would duplicate that coverage and
  create a second place to keep in sync.
- **The recap file is JSON, not bare text.** It carries the session id and a creation timestamp
  alongside the text, so the recompose branch and any future reader can tell a real recap from a
  stale or truncated file rather than inferring it from the filename alone.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel. Phase 4 depends on Phase 2 specifically
because the dead-command-recommendation lint enumerates valid commands from `commands/*.md` at run
time: the `/recap` recommendation Phase 4 adds is only lint-clean once Phase 2's command file
exists.

**Suite selection was run, not asserted.** `suite_selection_select` was run at plan-authoring
time over each phase's own `Files to modify` paths, both per-path and as the union the selector
actually evaluates. The selector's union semantics matter here and were measured, not assumed:
whenever **any** path in a phase has no mapped suite, the union returns the `__FULL_SWEEP__`
sentinel for that whole phase, regardless of how many suites the phase's other paths map to. That
is the case for every non-final phase in this plan — each one either creates a new file or touches
a markdown file with no suite mapping — so every `**Tier Justification**:` below asserts the
sentinel and names a gate subset plus the tier row's own in-phase check, never a suite list. Where
a phase's individual paths DO map to real suites, those suites are named in that phase's
**Verification** block and run there; they are a useful additional check, not the covering claim.
Phase 5's `full` gate is what covers everything these subsets do not.

---

### Phase 1: Resolver and the recap script [COMPLETED]

**Goal**: The path resolver and the `orchestrate-recap.sh` script exist, are registered, and work
standalone — both modes, every fallback branch — with no caller wired up yet.

**Tasks**:

- [x] Append `runtime_recap_path()` to `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh`,
      directly after `runtime_conclusion_pending_marker_path()`, taking `(specs_dir, session_id)`
      and echoing `${specs_dir}/.orchestration/.recap-${session_id}.json`. Carry a header comment
      in the same voice as its three siblings, stating that no new runtime-file-pattern class
      member is needed because the containing directory is already covered directory-class, and
      that the caller owns directory creation. *(completed)*
- [x] Create `agent-system/extensions/core/scripts/orchestrate-recap.sh` with `set -euo pipefail`,
      a header documenting both modes and the environment variables, and `--help`. *(completed)*
- [x] Implement `--write --session <sid>`: read the recap text from **stdin** (never a `--text`
      argument — the text is free-form prose and must not travel through argument quoting), write
      `{session_id, created_ts, text}` JSON to the resolver's path, creating
      `specs/.orchestration/` first. Empty stdin is a loud non-zero refusal with a message naming
      the cause. *(completed)*
- [x] Implement the default speak mode's text resolution: newest `.recap-*.json` under
      `specs/.orchestration/` by mtime; use its `text` when the file parses and the field is
      non-empty. *(completed)*
- [x] Implement the recompose fallback: when no usable recap file exists, take the newest
      `.return-meta-multi-*.json` by mtime, validate it parses and carries the expected metadata
      keys, and compose a short mechanical prose string from the task outcomes it records. When
      that file is absent, unparseable, or missing those keys, fall back to one fixed generic
      sentence. Every branch exits `0`. *(completed)*
- [x] Implement output and playback: always print the resolved text to stdout first. Then exit `0`
      without audio when `TTS_ENABLED=0`, when `piper` is not on `PATH`, or when the resolved
      `PIPER_VOICE` model file does not exist. Otherwise write the text to a `mktemp` file and run
      a backgrounded, `timeout`-bounded `piper --model "$voice" --output_file - --quiet < "$tmp" | paplay`,
      removing the temp file afterwards. Honor `TTS_ENABLED` (default `1`) and `PIPER_VOICE`
      (default `$HOME/.local/share/piper/en_US-lessac-medium.onnx`) with the same spellings and
      defaults the existing notification hook uses. *(completed: also gated on paplay presence,
      an additive safety branch not contradicting any task item)*
- [x] MUST NOT reuse the existing notification hook's `speak()` quoting shape: the recap text is
      never interpolated into a single-quoted string inside a nested `bash -c`. No espeak-ng
      branch anywhere in the file. *(completed: text reaches piper only via file redirection on
      stdin)*
- [x] Add `"orchestrate-recap.sh"` to `manifest.json`'s `provides.scripts` array, in that array's
      existing sort position. *(completed)*
- [x] Smoke both modes by hand: write a recap with an apostrophe in it, read it back with
      `TTS_ENABLED=0`, confirm the text round-trips byte-identically and the exit status is `0`.
      *(completed: via a fake .claude/scripts/ deploy tree under the scratchpad directory, since
      this script's deploy-root-guard.sh gate refuses a bare source-store invocation by the same
      convention as its orchestrate-*.sh siblings — see progress file's approaches_tried)*
- [x] Run `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` (or its deployed
      equivalent) over the new script and clear every finding. *(completed: 0 findings)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel over this phase's paths — the new script maps to no suite at all, so no suite covers this phase and none is claimed — making the covering checks the sanctioned `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` run and the two-mode hand smoke in the task list, plus `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` for the manifest-declaration and task-reference surfaces this phase also moves.

**Scope Hypothesis**: The library currently exposes exactly three per-session resolvers
(`runtime_mt_state_path`, `runtime_return_meta_multi_path`,
`runtime_conclusion_pending_marker_path`) and the new one makes four, additively, with no existing
signature changed. Confirm by grepping the library for `runtime_.*_path()` definitions before
editing; if the count has moved, follow whatever the current siblings do rather than this
sentence.

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` - append the fourth
  per-session resolver; no array-member change. Correction target, confirmed present at authoring
  time; if the three sibling resolvers have moved or been renamed, mirror whatever shape is live
  rather than the names quoted here.
- `agent-system/extensions/core/scripts/orchestrate-recap.sh` - new file, both modes.
- `agent-system/extensions/core/manifest.json` - register the new script in `provides.scripts`.

**Verification**:

- `bash agent-system/extensions/core/scripts/orchestrate-recap.sh --help` exits `0` and documents
  both modes.
- A `--write` call followed by a `TTS_ENABLED=0` speak call prints the exact text written,
  apostrophes and double quotes intact, exit `0`.
- A speak call with no recap file present and no usable runtime metadata file prints the generic
  sentence and exits `0`.
- Additionally run, as a non-covering extra check, the suites `suite_selection_select` maps the
  resolver library and the manifest to individually:
  `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-runtime-file-tracking.sh,test-manifest-scripts-sync.sh,test-script-inventory.sh`.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` exits `0` on the new script.

---

### Phase 2: The `/recap` command and skill [NOT STARTED]

**Goal**: `/recap` exists as a user-only, direct-execution command backed by a user-only skill,
registered in the manifest and in the Command Reference table, with the never-autonomous-audio
constraint restated in both new files.

**Tasks**:

- [ ] Create `agent-system/extensions/core/commands/recap.md`: purpose, `**User Only**: YES -
      Agents MUST NOT invoke this command`, direct-execution layer, delegation to `skill-recap`,
      and a short statement that an orchestration never plays audio by itself — speaking is always
      this separately invoked step.
- [ ] Create `agent-system/extensions/core/skills/skill-recap/SKILL.md` with frontmatter
      `name: skill-recap`, a description ending in the user-only sentence, `allowed-tools: Bash`,
      and `user-only: true`. Body: an "Agent Restrictions" section stating agents MUST NOT invoke
      it, the never-autonomous-audio constraint, and the single call into
      `orchestrate-recap.sh`'s speak mode.
- [ ] Add one Command Reference row to `agent-system/extensions/core/merge-sources/claudemd.md`,
      matching the existing user-only rows' shape, marked `(user-only)`. MUST NOT add a
      Skill-to-Agent Mapping row — the omission is the third enforcement layer.
- [ ] Add `"recap.md"` to `provides.commands` and `"skill-recap"` to `provides.skills` in
      `manifest.json`, each in its array's existing sort position.
- [ ] Add a short subsection to the nvim extension's TTS guide documenting that an arbitrary-text
      speaking path now exists alongside the fixed-vocabulary notification hook, naming the same
      documented piper invocation and the `TTS_ENABLED`/`PIPER_VOICE` conventions it reuses. Keep
      it additive — MUST NOT restructure or renumber the guide's existing sections, and MUST NOT
      touch any event-announcement hook file.
- [ ] Check both new files and the claudemd row for task-number references and record-versioning
      language; neither is permitted under `agent-system/**`.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Tier Justification**: A new skill directory plus a new command file plus a CLAUDE.md merge-source row moves the extension registration and deploy-completeness surface that no cheaper tier covers — `suite_selection_select` maps this phase's skill path alone to 29 suites spanning routing resolution, double-loading, deploy propagation and dispatch composition, so no honest narrowing of the selector's own output exists for this edit.

**Scope Hypothesis**: The merge source currently sits well inside the configured size ceiling the
doc-lint enforces, so a one-row addition has ample headroom. Confirm with `wc -c` against
`context/config/claudemd-size-budget.json`'s current `core.ceiling_bytes` before editing; if
headroom has closed, trim elsewhere in that file rather than exceeding the ceiling.

**Files to modify**:

- `agent-system/extensions/core/commands/recap.md` - new command definition, user-only.
- `agent-system/extensions/core/skills/skill-recap/SKILL.md` - new direct-execution skill,
  `user-only: true`.
- `agent-system/extensions/core/merge-sources/claudemd.md` - one Command Reference row. Correction
  target, confirmed present; if the table's column shape has changed, match whatever the live
  user-only rows use.
- `agent-system/extensions/core/manifest.json` - register the command and the skill.
- `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` - additive
  subsection on the arbitrary-text speaking path. Correction target, confirmed present; if absent,
  skip this entry and record the deviation with `issue-record.sh` rather than creating the guide.
- `agent-system/extensions/nvim/index-entries.json` - coupled generated surface: the guide edit
  moves that entry's `line_count`. The checking rule is advisory here (no commit-blocking hook is
  installed), so reconciliation is deferred to Phase 5's redeploy, which regenerates it; the
  declaration is owed in this phase regardless.

**Verification**:

- Both new files carry the user-only frontmatter flag and the explicit agent-restriction
  statement; neither appears in the Skill-to-Agent Mapping table.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  is clean for the two new markdown files, which the selector reports as `__FULL_SWEEP__`
  (sub-case (b): source-store, non-`specs/**` markdown).
- The merge source stays under its configured byte ceiling.
- The full gate set passes for the registration surface this phase moves.

---

### Phase 3: Test suite for the recap script [NOT STARTED]

**Goal**: Every acceptance-relevant branch of `orchestrate-recap.sh` is covered by a registered,
passing suite, including the quoting-hazard regression guard and the no-second-engine guarantee.

**Tasks**:

- [ ] Create `agent-system/extensions/core/scripts/tests/test-orchestrate-recap.sh` following the
      conventions of the sibling orchestrate suites, with a self-contained fixture directory and
      cleanup.
- [ ] Case: `--write` persists to the resolver's path with `session_id`, `created_ts`, and `text`
      present and the text byte-identical to stdin.
- [ ] Case: speak mode with a recap file present prints that file's text and exits `0`.
- [ ] Case: speak mode with no recap file recomposes from a fixture runtime metadata file and
      exits `0` with non-empty output.
- [ ] Case: speak mode with neither file present prints the generic sentence and exits `0`.
- [ ] Case: a malformed/truncated runtime metadata file yields the generic sentence and exit `0`,
      never a non-zero exit.
- [ ] Case: `TTS_ENABLED=0` prints the text and leaves a `PATH`-shimmed piper stub's marker file
      unwritten — audio suppressed, text intact.
- [ ] Case: with piper absent from a shimmed `PATH`, the script prints and exits `0`, and an
      espeak-ng stub's marker file is never written — the no-second-engine guarantee.
- [ ] Case: recap text containing an apostrophe and a double quote round-trips `--write` → speak
      unmangled — the regression guard against the existing hook's quoting shape.
- [ ] Add the suite's row to `agent-system/extensions/core/scripts/tests/suite-classification.data`
      (TAB-separated, class `unit`) and `"tests/test-orchestrate-recap.sh"` to `manifest.json`'s
      `provides.scripts`.
- [ ] Run `bash agent-system/extensions/core/scripts/lint/lint-unit-integration-boundary.sh` and
      confirm the new suite is classified, not flagged.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel over this phase's paths — the suite file this phase creates maps to no suite of its own — so no suite covers this phase and none is claimed; the covering checks are the new suite run directly against the script it tests, `bash agent-system/extensions/core/scripts/lint/lint-unit-integration-boundary.sh` for the classification row, and `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` for the manifest-declaration surface.

**Scope Hypothesis**: The classification data file's own header states that
`lint-unit-integration-boundary.sh` fails loudly on any discovered-but-unclassified suite, so the
row is mandatory rather than cosmetic, and that the deployed tree's merged test directory — not
the source store's — is the authoritative discovery set. Confirm by running that lint after adding
the row; if it passes without the row, add the row anyway and record the surprise with
`issue-record.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-recap.sh` - new suite, nine cases.
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - one `unit` row.
  Correction target, confirmed present; if the file's column format has changed, match the live
  rows.
- `agent-system/extensions/core/manifest.json` - register the test suite in `provides.scripts`.

**Verification**:

- The new suite passes when run directly, all nine cases.
- `bash agent-system/extensions/core/scripts/lint/lint-unit-integration-boundary.sh` exits `0` and
  reports the new suite classified.
- Additionally run, as a non-covering extra check, the suites the selector maps the
  classification-data and manifest paths to individually:
  `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-unit-integration-boundary.sh,test-run-all-selection.sh,test-manifest-scripts-sync.sh`.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` exits `0` on the new suite.

---

### Phase 4: Conclusion-stage wiring [NOT STARTED]

**Goal**: The conclusion stage composes and persists the recap at its emission step, its call is
in-contract against the Move 5 Bash allowlist, and the rendered report recommends `/recap` by name.

**Tasks**:

- [ ] Amend `context/contracts/conclusion-stage.md`'s Step 6: after the report is rendered and
      **before** the step's existing final action (deleting the invocation's conclusion-stage
      pending marker), instruct the lead to compose a speech-shaped prose recap and persist it via
      `orchestrate-recap.sh --write --session "$session_id"` with the text on stdin through a
      quoted heredoc. Show the invocation shape, and state that the call is non-fatal: a failure
      warns on stderr and the step proceeds to the marker deletion unchanged.
- [ ] In that same amendment, state the prose constraints plainly: short, plainly worded, pleasant
      read aloud; names what landed, what failed if anything, and the single most useful next
      action; no tables, no path strings, no session ids, no command-line flags — those belong in
      the written report, not the spoken text.
- [ ] MUST NOT move, reorder, or re-scope the marker deletion; it stays the step's final action.
      MUST NOT touch the channel routing, the filter predicate, or the exactly-one-channel rule.
- [ ] Add `orchestrate-recap.sh` (its `--write` form only, named as Step 6's own recap
      persistence) to the Move 5 `Bash` row in
      `context/standards/postflight-tool-restrictions.md`, inline with the existing enumerated
      scripts.
- [ ] Add one line to `context/patterns/orchestrate-batch-results-template.md`'s `### Next Steps`
      block recommending `/recap` by name, unconditionally — the recap is written on every
      invocation that reaches the emission step.
- [ ] Re-read all three edited blocks for task-number references and record-versioning language.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel over this phase's paths — two of the three markdown files map to no suite — so no suite covers this phase and none is claimed; this being a source-store, non-`specs/**` markdown edit, the covering check is sub-case (b)'s `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`, which also exercises the dead-command-recommendation surface this phase touches, alongside the tier row's own diff read-through.

**Scope Hypothesis**: The Move 5 allowed-tool table carries exactly one `Bash` row, enumerating
every script the stage may invoke, and Step 6 is the sole emission site and the sole deleter of
the pending marker. Confirm both by reading the two sections before editing; if the table has
grown a second `Bash` row or the marker deletion has moved, place the additions to match live
structure rather than this sentence.

**Files to modify**:

- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - Step 6 amendment: compose
  and persist the recap before the marker deletion. Correction target, confirmed present with
  Steps 1-7 and Step 6 as described.
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - add the
  script to the Move 5 `Bash` row. Correction target, confirmed present.
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - one
  `### Next Steps` line recommending `/recap`. Correction target, confirmed present.
- `agent-system/extensions/core/index-entries.json` - coupled generated surface: all three edits
  above move those files' `line_count` entries. The checking rule is advisory here (no
  commit-blocking hook is installed), so reconciliation is deferred to Phase 5's redeploy, which
  regenerates it; the declaration is owed in this phase regardless.

**Verification**:

- Step 6 shows the recap composition and the `--write` call, and the marker deletion is still the
  step's last action.
- The Move 5 `Bash` row names the script, so the stage's call is in-contract.
- The `### Next Steps` block names `/recap`, and
  `bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh` exits `0`
  (Phase 2's command file makes it a valid command).
- The gate subset above passes.
- Additionally run, as a non-covering extra check, the suites the selector maps the contract file
  to individually:
  `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-conclusion-aggregate.sh,test-orchestrate-conclusion-backstop.sh,test-orchestrate-conclusion-roadmap.sh`.

---

### Phase 5: Deploy, verify, and acceptance walkthrough [NOT STARTED]

**Goal**: The source-store work is deployed, the full gate set is green, and all seven acceptance
criteria are demonstrated against the deployed tree.

**Tasks**:

- [ ] Run `bash .claude/scripts/deploy-headless.sh` and confirm `RESULT=landed_verify_clean`. This
      also regenerates both extensions' `index-entries.json` line counts, reconciling the deferred
      coupled surfaces declared in Phases 2 and 4.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. Resolve every newly
      introduced finding; a pre-existing finding is recorded, not silently absorbed.
- [ ] Acceptance (1): run an orchestration that reaches its conclusion stage, or exercise the Step
      6 invocation shape directly, and confirm a `.recap-{session_id}.json` lands under
      `specs/.orchestration/` and the written output names `/recap`.
- [ ] Acceptance (2): run `/recap` and confirm the recap is spoken through piper.
- [ ] Acceptance (3): move the recap file aside, run `/recap`, and confirm it recomposes rather
      than failing.
- [ ] Acceptance (4): with piper shimmed off `PATH` (or the voice model path pointed at a
      non-existent file), confirm `/recap` prints the text and exits `0`, with no second engine
      invoked.
- [ ] Acceptance (5): with `TTS_ENABLED=0`, confirm audio is suppressed on every path and the
      printed text is unchanged.
- [ ] Acceptance (6): confirm the Move 5 allowlist names the script in the deployed tree.
- [ ] Acceptance (7): grep every file this task touched under `agent-system/**` for task-number
      references and record-versioning language; both must be absent.
- [ ] Confirm no file under `.claude/**` was hand-authored at any point in this task, and that no
      event-announcement hook file was modified.
- [ ] Record issues and wins in `issues.jsonl` as they arise, and write the completion summary.

**Timing**: 1 hour

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via the deploy script, an implicit
  scope claim over the entire deployed tree that no real declared path expresses.
- `agent-system/extensions/core/index-entries.json` - regenerated line counts for the core
  context files edited in Phase 4.
- `agent-system/extensions/nvim/index-entries.json` - regenerated line count for the guide edited
  in Phase 2.

**Verification**:

- `bash .claude/scripts/deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set, no `--skip-slow`, no
  `--only-gate`) passes, with any pre-existing finding recorded and distinguished from a newly
  introduced one.
- All seven acceptance criteria demonstrated, each with its observed result stated.

---

## Testing & Validation

- [ ] `test-orchestrate-recap.sh` passes, all nine cases, including the apostrophe/double-quote
      round-trip and the no-second-engine guarantee.
- [ ] `lint-unit-integration-boundary.sh` reports the new suite classified.
- [ ] `lint-shellcheck.sh` is clean on both new shell files.
- [ ] `lint-dead-command-recommendations.sh` is clean after Phase 4's recommendation lands.
- [ ] `bash .claude/scripts/verify-deploy.sh` — the complete gate set — passes at Phase 5. The
      per-phase `--only`/`--only-gate` subsets above are how each non-final phase discharges its
      own declared tier; none of them is evidence for the full run, and no `--skip-slow` pass is
      evidence that doc-sync pins hold.
- [ ] The orchestration plays no audio on any path: confirmed by grepping every file this task
      touched for `piper`, `paplay`, and any other audio sink, and verifying that every hit lies
      inside `orchestrate-recap.sh`'s speak mode or in documentation prose.
- [ ] No file under `agent-system/**` carries a task-number reference or record-versioning
      language.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-recap.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-recap.sh` (new)
- `agent-system/extensions/core/commands/recap.md` (new)
- `agent-system/extensions/core/skills/skill-recap/SKILL.md` (new)
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` (fourth resolver)
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` (Step 6 amendment)
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` (Move 5 Bash
  row)
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
  (`### Next Steps` line)
- `agent-system/extensions/core/merge-sources/claudemd.md` (Command Reference row)
- `agent-system/extensions/core/manifest.json`,
  `agent-system/extensions/core/scripts/tests/suite-classification.data` (registration)
- `agent-system/extensions/core/index-entries.json`,
  `agent-system/extensions/nvim/index-entries.json` (regenerated line counts)
- `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` (additive
  subsection)
- `specs/644_orchestration_recap_spoken_on_demand/summaries/01_*-summary.md` (completion summary)

## Rollback/Contingency

Each phase commits on its own green sub-steps, so reverting is a matter of dropping the commits
for the phases that landed. The new files (script, suite, command, skill) are purely additive:
deleting them plus their `manifest.json` and `suite-classification.data` rows, then redeploying,
returns the system to its prior behavior. The edits to the contract, the restrictions standard,
the results template, the merge source, and the resolver library are all additive insertions and
are reverted by removing the inserted block.

If a rollback must discard uncommitted working-tree changes, take a snapshot first using the
rollback rung's invocation shape in `context/contracts/recovery.md` — including its
out-of-scope override flag for the deliberate whole-tree case — then perform the revert. Do not
emit a bare snapshot call as a routine start-of-phase precaution; for an ordinary defensive
checkpoint before risky work, use the non-reverting `--no-revert` form instead.

The one irreversible-by-deletion surface is the deployed tree, which Phase 5 regenerates; a
redeploy from a reverted source store restores it.
