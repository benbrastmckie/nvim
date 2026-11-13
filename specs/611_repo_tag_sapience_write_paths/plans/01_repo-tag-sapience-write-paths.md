# Implementation Plan: Task #611

- **Task**: 611 - Repo-tag every Sapience write path the source store owns so untagged knowledge objects stop being created
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None. The sibling read-side task (`scope_sapience_injection_to_current_repo`) is sequenced AFTER this one and shares file territory under `agent-system/extensions/sapience/**`; do not run them concurrently.
- **Research Inputs**: `specs/611_repo_tag_sapience_write_paths/reports/01_repo-tag-sapience-write-paths.md`
- **Artifacts**: plans/01_repo-tag-sapience-write-paths.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The tagged write path already exists and works: `sapience-remember.sh` emits
`provenance = "[repo:<slug>] via sapience-remember.sh (Claude Code dispatch)"` and `EXTENSION.md`'s
postflight wrapup already calls it rather than the untagged MCP `sapience_wrapup` tool. What is
missing is everything that makes that contract durable and checkable: two domain docs still
describe the superseded MCP-tool mechanism as current, two of the four MCP write tools carry no
recorded disposition at all, the vendor SessionStart nudge is countered only by inference, the
standing rule exists only as one prose sentence with no registered carrier, and the tagged
provenance has zero test coverage. This plan closes those five gaps in four phases, ending with a
redeploy and the full gate set.

### Research Integration

The research report's inventory of all 12 source-store files is adopted wholesale, including its
central negative finding (most of deliverable (a) is already satisfied; this is a
correctness-and-completeness pass, not a from-scratch build). Three of its recommendations are
adopted as written: correct the stale domain files (Rec 1), add explicit dispositions for
`sapience_handoff`/`sapience_adddoc` (Rec 2), and add write-side dry-run test cases (Rec 3). Rec 4
(advisory rule, not a mechanized lint) is adopted with its rationale recorded in the rule's own
text, as Rec 4 itself requires. Rec 5 (name the SessionStart nudge explicitly and redirect rather
than suppress) is adopted. Rec 6 (leave `settings-fragment.json`'s four-tool grant unchanged) is
adopted as this plan's own route and simultaneously surfaced as a non-blocking `user_decision`,
because the residual it accepts is a permanent, undeletable untagged write that a stray MCP call
can still land.

This plan departs from the research report in one place: the report judged
`per-repo-scoping.md` to need no change. Acceptance criterion 6 names it explicitly and requires
it to state "which populations remain untagged and why," and its live Hazards section says the
vault "accumulates two differently-shaped populations" against the task description's measured
census of four. That is a real gap, so Phase 1 extends it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, and the roadmap flag is not
set, so no roadmap consultation applies to this plan.

### Premise Re-Validation (Carried-Figure Discipline)

Every figure the dispatch description carried was re-derived against live files at plan-authoring
time. Results, stated explicitly even where they only confirm the description:

| Carried claim | Verdict |
|---|---|
| Source store is `agent-system/extensions/sapience/**`; `.claude/**` is a regenerated artifact | **CONFIRMED.** 14 files on disk under that path; `manifest.json`'s `merge_targets` confirms `.claude/CLAUDE.md`, `.claude/context/index.json` and `.claude/settings.local.json` are all generated targets |
| `sapience-remember.sh` line 156 writes the `[repo:<slug>]` provenance | **CONFIRMED at the stated line.** Live text: `provenance="[repo:${repo_slug}] via sapience-remember.sh (Claude Code dispatch)"` |
| `--dry-run` exits 0, prints the body with the token redacted, no network call | **CONFIRMED by live invocation** of the deployed copy: exit 0, `"token": "***REDACTED***"`, `"provenance": "[repo:nvim] via sapience-remember.sh (Claude Code dispatch)"`, `"explicit": true` |
| `explicit: true` is unconditional | **CONFIRMED.** Set as a literal inside the `jq -n` body construction, reachable from no flag |
| The four MCP write tools are granted by `settings-fragment.json` | **CONFIRMED.** Exactly four `permissions.allow` entries, explicit names, no wildcard |
| `review-gate-boundary.md` and `transcript-filter-ceiling.md` describe the superseded `sapience_wrapup` mechanism as current | **CONFIRMED.** `review-gate-boundary.md` lines 24-30 ("This extension's gap-2 instruction (call `sapience_wrapup` with 3-8 notes...)") and line 42 ("the same per-task bound this file's gap-2 instruction already applies to `sapience_wrapup`"); `transcript-filter-ceiling.md`'s Conclusion ("An explicit MCP tool call ... is the *only* path into the vault for this kind of work") |
| `sapience_handoff` has no recorded ruling | **CONFIRMED.** It appears only in enumerations (the grant list, `vault-model.md`'s tool inventory, `per-repo-scoping.md`'s Hazards list); no file states a disposition for it |
| `test-sapience-capture.sh` covers only the read side | **CONFIRMED.** 472 lines, 9 cases, every one driving `sapience-retrieve.sh`; zero invocations of `sapience-remember.sh` |
| `manifest.json` declares `provides.rules: []` | **CONFIRMED** |
| The degrade rule (failed write mirrored via `issue-record.sh`, never blocking a transition) | **CONFIRMED** in both `EXTENSION.md` and `per-repo-scoping.md`'s call-site contract; unchanged by this plan |

Two live facts the description did not carry, discovered at plan time and load-bearing for the
phase structure below:

- **`check-extension-docs.sh` Rule H (`check_undeclared_rules`) FAILS** on a rule file present in
  an extension's `rules/` but absent from its `provides.rules`. Creating the rule file and
  registering it therefore cannot be two separate green commits (Phase 4's `atomic-batch`).
- **`sapience-remember.sh` cannot execute from the source store at all.** It sources
  `${SCRIPT_DIR}/lib/common.sh`, which exists only in the post-deploy flattened `.claude/scripts/`
  tree; a direct source-store invocation dies at that line with exit 1. The new test cases must
  therefore use the existing `build_scratch` deployed-layout fixture, not a bare source-store call.

## Goals & Non-Goals

**Goals**:
- Record an explicit, affirmative disposition for each of the four MCP write tools, so deliverable
  (a)'s "or their use must be ruled out and the reason recorded" half is satisfied for the two
  tools that have no call site.
- Correct every source-store statement that describes the superseded untagged mechanism as
  current, and state the four-population census with which populations stay untagged and why.
- Land the standing rule as a registered, path-scoped `rules/` file with its advisory-or-enforced
  verdict and the rejected-mechanization rationale in its own text.
- Make the SessionStart-nudge ruling explicit, naming the nudge and redirecting the write to the
  tagged path rather than only suppressing it.
- Prove the tag mechanically: assert `[repo:<slug>]` in the provenance the postflight call site
  would send, driven with no live vault.

**Non-Goals**:
- The read side: no `source=` filter, no hook narrowing, no change to `sapience-retrieve.sh`. That
  is the sibling task's territory.
- Any edit to `~/.claude/settings.json` or `~/.sapience/**`. Both are outside the source store and
  outside every deploy tree; `mcp.py` self-updates daily, so a hand-patch there would be
  overwritten. Owner actions are written out as runnable instructions, never performed.
- Tagging the vendor-owned transcript-extraction population or objects shared by other people.
  Neither is reachable from this repository.
- Narrowing `settings-fragment.json`'s four-tool grant (see the `user_decision` surfaced with this
  plan). Narrowing it would also leave `core/context/patterns/mcp-server-ownership.md`'s worked
  example stale, and `core/` is outside this task's declared edit target.
- Building a mechanized write-path lint. Phase 4 records this as a deliberate verdict with a
  promotion criterion, not an oversight.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Keeping the four-tool grant leaves a stray MCP call able to land a permanent, undeletable untagged write | M | M | Surfaced as a non-blocking `user_decision`; Phase 4's rule file records the residual and its promotion criterion explicitly rather than implying it away |
| Correcting two of three domain docs while extending the third reads as inconsistent to a future reader | L | M | Phase 1 cross-references `per-repo-scoping.md`'s existing "D3: Why Replace, Not Both" section from the corrected passages instead of restating it (research Risk 1's own mitigation) |
| `EXTENSION.md` crosses Rule U's 60-line ceiling while absorbing the nudge ruling | M | L | Phase 2 carries the arithmetic as a Scope Hypothesis (44 lines measured, ceiling 60) and confirms with `wc -l`; if the ruling cannot fit, it lands in `review-gate-boundary.md` with a one-line pointer from `EXTENSION.md` |
| A new `rules/` file is new deploy surface, so it is inert until a redeploy runs | M | H | Phase 4 is the deploy phase: registration, `deploy-headless.sh`, and the full gate are one phase, so the rule is never left registered-but-undeployed across a phase boundary |
| Rule H makes an intermediate rule-file-without-registration state red | M | H | Phase 4 declares `Commit Mode: atomic-batch` over exactly the rule-file/manifest pair |
| The new test asserts a slug the fixture does not control, making it pass vacuously | H | L | Phase 3 asserts `[repo:<basename of the scratch repo>]`, a slug the fixture mints, and separately asserts the fixture token value appears nowhere in stdout |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Correct the Domain-Doc Write Contract and Record Every Write-Tool Disposition [COMPLETED]

**Goal**: Make the three indexed sapience domain docs state the write path that actually exists,
record an affirmative disposition for all four MCP write tools in one place, and replace the
two-population claim with the measured four-population census. Satisfies acceptance criteria 1, 6
and the "ruled out and the reason recorded" half of deliverable (a).

**Tasks**:
- [x] Confirm the stale passages before editing: `grep -n "sapience_wrapup" agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md agent-system/extensions/sapience/context/project/sapience/domain/transcript-filter-ceiling.md`. Line numbers move as edits land, so locate by text, not by the numbers quoted in this plan. *(completed)*
- [x] In `review-gate-boundary.md`'s "Why This Makes the Postflight-Only Scoping Load-Bearing" section, replace the parenthetical that names `sapience_wrapup` as the instruction's mechanism with the actual one: a bounded 3-8-note set written through `scripts/sapience-remember.sh`'s direct `POST /ingest-kos` call at the `[IMPLEMENTING]` -> `[COMPLETED]` transition. Keep the section's argument intact -- the bypassed `auto_approve: false` gate and the per-completed-task bound are unchanged and remain the reason the bound is load-bearing. *(completed)*
- [x] In the same file's "A Third Direct Write Path" section, correct the closing clause that still attributes the per-task bound to a `sapience_wrapup` instruction, and cross-reference `per-repo-scoping.md`'s "D3: Why Replace, Not Both" rather than restating its argument. *(completed)*
- [x] Add a new `## Write-Tool Disposition` section to `review-gate-boundary.md`: a four-row table, one row per MCP write tool, each stating the disposition and its reason. `sapience_remember` -- never named as a prescribed write path; its connector hardcodes provenance with no injectable repo marker, so no argument can produce a tagged write. `sapience_wrapup` -- replaced by the script call site; keeping both would double permanent unreviewed volume for zero added reachability (D3). `sapience_handoff` -- ruled out, not converted: no instruction surface calls it today, and adding a second session-closing write path would either duplicate the postflight note set under one shared bound or breach that bound, while still landing untagged. `sapience_adddoc` -- out of scope: document ingestion, not finding capture. Close the section with the discussing-versus-prescribing boundary in one sentence: naming a tool in this table is discussion, which the standing rule permits. *(completed)*
- [x] In `transcript-filter-ceiling.md`'s Conclusion, correct the claim that an explicit MCP tool call is the *only* path into the vault for orchestrated work. The claim's structure survives (the transcript-extraction path still cannot reach the vault for this work), but the surviving path is this extension's direct `POST /ingest-kos` script call, not an MCP tool call. *(completed)*
- [x] In `per-repo-scoping.md`'s Hazards section, replace "The vault accumulates two differently-shaped populations" with the four-population census and the resulting contract: tagged (this extension's two scripts); untagged but agent-reachable (the four MCP write tools -- no longer prescribed anywhere, per the disposition table, and the reason this task exists); untagged and vendor-owned (transcript extraction via `~/.sapience/upload.py`, whose server-authored provenance drops the per-chunk project identity -- the largest population, unfixable from this repository); and objects belonging to no repository (documents shared by other people). State for each whether it stays untagged and why. *(completed)*
- [x] Repair the moved line counts in the same phase: `bash /home/benjamin/.config/nvim/.claude/scripts/generate-context-line-counts.sh --write`, then confirm with `--check` exiting 0. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` over this phase's touched paths, so no suite covers them and the covering check is `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` (sub-case (b): source-store markdown, `TARGET` the repository root that holds both the deployed tree and the source store), alongside the diff read-through this tier prescribes.

**Scope Hypothesis**: The three stale-passage locations are carried from `reports/01_repo-tag-sapience-write-paths.md` (review-gate-boundary.md lines 24-30 and 42, transcript-filter-ceiling.md line 40) and were re-derived against the live files at plan-authoring time, confirming all three. Line numbers still move as earlier edits in this phase land, so the first task re-locates them by text before editing.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` - correct the two stale `sapience_wrapup` passages; add the four-row `## Write-Tool Disposition` section. Confirmed present at authoring time (72 lines). If absent when this phase runs, stop and re-plan rather than creating it fresh -- its content is the premise of Phases 2 and 4.
- `agent-system/extensions/sapience/context/project/sapience/domain/transcript-filter-ceiling.md` - correct the Conclusion's MCP-only claim. Confirmed present at authoring time (43 lines); same fallback.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - extend the two-population hazard into the four-population census. Confirmed present at authoring time (153 lines); same fallback.
- `agent-system/extensions/sapience/index-entries.json` - coupled generated surface: each of the three edits above moves that entry's `line_count`, which `check-extension-docs.sh` Rule R checks. The check is not commit-blocking in this repository (no pre-commit hook), but the declaration is owed here regardless, and this phase repairs it in place via `generate-context-line-counts.sh --write` rather than deferring it, because Phase 1's own `--only-gate 3` check would otherwise fail on the stale count. Confirmed present at authoring time, with all six entries' counts currently accurate.

**Verification**:
- `grep -c "sapience_wrapup" ` on `review-gate-boundary.md` and `transcript-filter-ceiling.md` returns only occurrences that are discussion (the disposition table, the two-paths inventory), with no surviving sentence presenting it as the current mechanism.
- `review-gate-boundary.md` contains a `## Write-Tool Disposition` section with one row for each of `sapience_remember`, `sapience_wrapup`, `sapience_handoff`, `sapience_adddoc`.
- `per-repo-scoping.md` names all four populations and, for each, whether it remains untagged and why.
- `bash /home/benjamin/.config/nvim/.claude/scripts/generate-context-line-counts.sh --check` exits 0.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` exits 0, with no Rule R or Rule T finding for the sapience extension. Check the exit status, not only the output text.
- Because this phase also edits `index-entries.json`, run the suites the selector maps that one path to as an additional criterion beyond the tier's own covering check: `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-context-reachability.sh,test-deploy-orphans.sh,test-index-entries-schema.sh,test-install-uninstall-extension.sh,test-manifest-scripts-sync.sh,test-roadmap-command-registration.sh` exits 0.

---

### Phase 2: Redirect the SessionStart Nudge to the Tagged Path in EXTENSION.md [COMPLETED]

**Goal**: Make deliverable (c)'s ruling explicit and checkable by inspection: name the vendor
SessionStart nudge, state that it is superseded in this repository, and redirect the finding it
would have written to the bounded tagged path so the knowledge is still captured. Satisfies
acceptance criterion 5.

**Tasks**:
- [x] Extend `EXTENSION.md`'s existing "Do NOT call `sapience_remember` proactively mid-run" prohibition with a sentence naming the nudge it counters: the Sapience SessionStart briefing's standing instruction to save a decision, finding, or correction with `sapience_remember` as soon as it lands. State that in this repository that nudge is superseded. *(completed)*
- [x] Make the redirect explicit rather than a bare suppression: the finding is held and surfaces through the bounded postflight `sapience-remember.sh` pass, so it still reaches the vault -- repo-tagged -- instead of being dropped. A reader must be able to see that nothing is lost, only relocated and tagged. *(completed)*
- [x] Record the ruling's class in one clause: this is a counter-instruction inside this extension's own surfaces, NOT an owner action and NOT an accepted residual. The nudge text is vendor-authored and arrives through a hook this repository does not own, so it cannot be edited here; no owner action is requested for it. *(completed)*
- [x] Point at `domain/review-gate-boundary.md`'s new `## Write-Tool Disposition` section instead of re-listing the four tools, keeping the addition short. *(completed)*
- [x] Confirm Rule U's ceiling holds: `wc -l agent-system/extensions/sapience/EXTENSION.md` stays at or below 60. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `test-index-entries-schema.sh,test-manifest-scripts-sync.sh` for this path, covered by `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-index-entries-schema.sh,test-manifest-scripts-sync.sh`.

**Scope Hypothesis**: `EXTENSION.md` measures 44 lines at plan-authoring time against Rule U's 60-line ceiling, leaving 16 lines of headroom; the ruling is expected to need 4-6. The plan therefore asserts no conformance its own arithmetic contradicts. Confirm with `wc -l` after the edit and with the Rule U verdict in `--only-gate 3`; if the ruling will not fit, move its body to `review-gate-boundary.md` and leave a one-line pointer here.

**Files to modify**:
- `agent-system/extensions/sapience/EXTENSION.md` - add the nudge-superseding counter-instruction and the pointer to the disposition table. Confirmed present at authoring time (44 lines). This file is `manifest.json`'s declared `merge_targets.claudemd.source`, so the generated `extension_sapience` section of the deployed `CLAUDE.md` derives from it; that target is a deployed-tree path, which `plan-format.md` forbids naming in this list, so the regeneration is declared via the `` `__WHOLE_TREE__` `` sentinel in Phase 4 instead. No check refuses a commit on that drift, so deferring the regeneration to Phase 4 is permitted.

**Verification**:
- `grep -n "SessionStart" agent-system/extensions/sapience/EXTENSION.md` finds the counter-instruction, and the surrounding sentence names both the supersession and the tagged path the finding is redirected to.
- The ruling's class (counter-instruction, not owner action, not accepted residual) is stated in the file, not left to inference.
- `wc -l` on the file reports 60 or fewer.
- `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-index-entries-schema.sh,test-manifest-scripts-sync.sh` exits 0.

---

### Phase 3: Assert the Repo Tag in the Provenance the Call Site Would Send [NOT STARTED]

**Goal**: Deliverable (d) and acceptance criterion 4 -- mechanical proof that the tag is present in
what the postflight call site would actually send, driven with no live vault and no network call.

**Tasks**:
- [ ] Re-derive the existing case count before adding: `grep -n "^# Case" agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh`. New cases are numbered after the last existing one.
- [ ] Resolve `sapience-remember.sh` source-store-first alongside the existing `SCRIPT_UNDER_TEST`, using the same `common_test_resolve_subject` convention the suite already applies to `sapience-retrieve.sh`.
- [ ] Add a `build_scratch`-style fixture for the write side. The existing `build_scratch` is reusable in shape but not as-is: it copies only `sapience-retrieve.sh`. The new fixture copies `sapience-remember.sh` into `$scratch/.claude/scripts/` alongside `deploy-root-guard.sh` and `lib/common.sh`, then `git init`s and seeds the scratch repo exactly as the existing one does. This deployed layout is mandatory, not stylistic: `sapience-remember.sh` sources `${SCRIPT_DIR}/lib/common.sh` and exits 1 when invoked directly from the source store.
- [ ] Add a case asserting the tag: `--subject`/`--value` plus `--dry-run` exits 0, and stdout parsed with `jq -r '.kos[0].provenance'` contains the literal `[repo:<basename of the scratch repo>]`. Assert against the fixture's own minted slug, never a hardcoded `nvim`, so the assertion cannot pass vacuously in another checkout.
- [ ] Add a case asserting token redaction: `jq -r '.token'` is exactly `***REDACTED***`, AND the fixture's `SAPIENCE_TOKEN` value appears nowhere in stdout. The second half is the one that would catch a leak the first half misses.
- [ ] Add a case asserting the noise-gate guard and the no-network property: `jq -r '.kos[0].explicit'` is `true`, and `--dry-run` still exits 0 with no `curl` stub installed at all -- which is what makes "no network call" an assertion rather than an assumption.
- [ ] Drive these cases with the argv shape `EXTENSION.md`'s postflight call site prescribes, so the assertion is about what that call site would send rather than about an arbitrary invocation.
- [ ] Update the file's header comment: it currently describes the suite as covering `sapience-retrieve.sh`'s exit-code split and cold-start retry exclusively. Widen that statement to name both scripts and the new cases, and keep the documented stub-dispatch contract accurate (the write-side cases install no `curl` stub).

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `test-sapience-capture.sh` for this path, covered by `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-sapience-capture.sh`.

**Scope Hypothesis**: The suite holds 9 cases in 472 lines, carried from `reports/01_repo-tag-sapience-write-paths.md` and re-derived at plan-authoring time against the live file (confirmed: cases 1-9, all driving `sapience-retrieve.sh`). The first task re-runs that grep before adding, since the count is what the new case numbering depends on.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` - add the write-side fixture and cases; widen the header comment's stated scope. Confirmed present at authoring time (472 lines, 9 cases). If its case numbering has advanced by the time this phase runs, append after the last existing case rather than assuming the numbers above.

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/tests/run-all.sh --only test-sapience-capture.sh` exits 0 with every case passing, old and new.
- Each new case fails for the right reason when inverted: temporarily breaking the provenance tag, the redaction, or `explicit: true` in a scratch copy of the script makes the corresponding case FAIL rather than silently pass. Confirm the inversion on a copy, never by editing `sapience-remember.sh` itself.
- The suite still passes with no network access and with no `curl` on `PATH` for the write-side cases.

---

### Phase 4: Land the Standing Rule, Register It, Redeploy, and Run the Full Gate Set [NOT STARTED]

**Goal**: Deliverable (b) and acceptance criterion 3 -- a standing, checkable rule with its
advisory-or-enforced verdict recorded -- then make every edit in this task live via a redeploy and
verify the whole result against the complete gate set.

**Tasks**:
- [ ] Create `agent-system/extensions/sapience/rules/sapience-write-path.md` with YAML `paths:` frontmatter scoped to this extension's source store and its deployed context mirror, following the `rules/*.md` frontmatter convention the harness auto-loads on a path match (the `nvim` extension's `neovim-lua.md` is the registration precedent).
- [ ] State the standing contract in the rule's own text: no instruction surface may name an MCP write tool as the path a write SHOULD take; every prescribed write routes through `scripts/sapience-remember.sh`; and each converted or prescribed call site carries an explicit note bound, so total unreviewed volume per completed task does not rise above the existing 3-8-note postflight set.
- [ ] State the discussing-versus-prescribing boundary in the rule itself, and name the sanctioned discussion sites by path: `context/project/sapience/domain/per-repo-scoping.md`'s mechanism section and `review-gate-boundary.md`'s two-paths inventory and new disposition table both legitimately name all four tools, and a check that flagged them would be wrong.
- [ ] Record the verdict and its rationale in the rule's own text so a future reader cannot mistake "advisory" for "unconsidered": the rule is ADVISORY, not mechanized. The corpus is 14 source-store files, exactly three of which legitimately name the tools; the only mechanized shape this codebase has evidence it trusts for this false-positive class is marker suppression (`scripts/lib/task-reference-patterns.sh`, `scripts/lib/record-version-patterns.sh`), and that build is disproportionate for a corpus this small and this static. Name the promotion criterion that would justify mechanizing it -- a measured recurrence of an untagged prescribed write, or growth of the surface set past what inspection covers.
- [ ] Record the `settings-fragment.json` residual in the same file: the four-tool grant is deliberately left intact (keeping `core/context/patterns/mcp-server-ownership.md`'s worked example accurate, which is outside this task's edit target), so a stray proactive MCP call still succeeds non-interactively and lands a permanent, undeletable untagged write. State this as an accepted residual with its own named escape valve, not as an unnoticed gap.
- [ ] Register the new rule in `agent-system/extensions/sapience/manifest.json`'s `provides.rules` array **in the same commit as the file's creation**. `check-extension-docs.sh` Rule H (`check_undeclared_rules`) FAILS on a `rules/` file absent from `provides.rules`, so the single-file intermediate state is expected red and must not be committed on its own.
- [ ] Redeploy: `bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh`. This regenerates the whole deployed tree -- the `extension_sapience` section of `CLAUDE.md` from Phase 2's `EXTENSION.md`, the deployed context index from Phase 1's `index-entries.json`, and the newly registered rule into the deployed `rules/` tree.
- [ ] Confirm the tagged write end-to-end after the redeploy: `bash /home/benjamin/.config/nvim/.claude/scripts/sapience-remember.sh --subject <s> --value <v> --dry-run` exits 0 and its provenance carries `[repo:nvim]` with the token redacted. Use `--dry-run` only; never land a real write as a verification step, because there is no delete API.
- [ ] Write out any owner action as an exact, runnable instruction rather than a description of one. This plan's route requests none: the SessionStart nudge is handled by counter-instruction (Phase 2) and the grant is left intact, so no `~/.claude/settings.json` or `~/.sapience/**` change is asked of the user. If the surfaced `user_decision` is answered in favor of narrowing the grant, that becomes a follow-up task, not an edit here.

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3

**Commit Mode**: atomic-batch

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/sapience/rules/sapience-write-path.md` - new file created by this phase; carries the standing contract, the discussing-versus-prescribing boundary with its sanctioned sites named, the advisory verdict with its rejected-mechanization rationale and promotion criterion, and the grant residual.
- `agent-system/extensions/sapience/manifest.json` - add the rule to `provides.rules`. Confirmed present at authoring time with `provides.rules: []`. Atomic with the file above, per Rule H.
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed tree. Declared with the reserved sentinel rather than any real wide path or `.claude/**` entry, per `plan-format.md`'s whole-tree-claim declaration rule.

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh` -- the complete gate set for this repository -- exits 0. Check the exit status, not only the summary text. This is the full tier's ceiling and is not narrowed by `--skip-slow` or `--only-gate` for this phase.
- `jq -r '.provides.rules[]' agent-system/extensions/sapience/manifest.json` lists the new rule, and `check-extension-docs.sh` reports no Rule H, Rule I, Rule R or Rule T finding for the sapience extension.
- The deployed `.claude/rules/sapience-write-path.md` exists and is byte-identical to its source (Rule I's drift check).
- `bash /home/benjamin/.config/nvim/.claude/scripts/sapience-remember.sh --subject <s> --value <v> --dry-run` exits 0 with `[repo:nvim]` in `.kos[0].provenance`, `***REDACTED***` as `.token`, and `true` as `.kos[0].explicit`.
- No real vault write was made at any point during this task.

---

## Testing & Validation

- [ ] `bash .claude/scripts/tests/run-all.sh --only test-sapience-capture.sh` passes, with the new write-side cases asserting `[repo:<slug>]` in provenance, exact token redaction with no leak of the fixture token, and `explicit: true`, all with no network call.
- [ ] Each new test case is confirmed to fail when its asserted property is inverted in a scratch copy, so none of them passes vacuously.
- [ ] `bash .claude/scripts/generate-context-line-counts.sh --check` exits 0.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 after the redeploy.
- [ ] No instruction surface under `agent-system/extensions/sapience/**` names an MCP write tool as a path a write should take; every remaining mention is discussion, located in one of the sites the rule names as sanctioned.
- [ ] Unreviewed write volume per completed task is unchanged at 3-8 notes: no new call site is added by this plan, and the two ruled-out tools gain none.

## Artifacts & Outputs

- Corrected `review-gate-boundary.md` with a new `## Write-Tool Disposition` section covering all four MCP write tools.
- Corrected `transcript-filter-ceiling.md` Conclusion.
- `per-repo-scoping.md` extended to the four-population census with per-population tagging status.
- `EXTENSION.md` carrying the explicit SessionStart-nudge supersession and redirect.
- New `rules/sapience-write-path.md`, registered in `manifest.json`'s `provides.rules`.
- `test-sapience-capture.sh` extended with write-side dry-run cases.
- `index-entries.json` line counts repaired.
- A regenerated deployed tree.

## Rollback/Contingency

Every edit in this plan is a source-store text edit plus one manifest array entry; nothing mutates
state outside the repository and no vault write is ever landed (`--dry-run` only, by design,
because there is no delete API). Each phase commits independently, so reverting one phase's commit
restores that file set without touching the others -- except Phase 4's rule-file/manifest pair,
which is one `atomic-batch` commit precisely so that reverting it cannot leave a Rule H violation
behind.

If a later phase must be abandoned, re-run `bash .claude/scripts/deploy-headless.sh` after the
revert so the deployed tree matches the source store again; the deployed tree is a disposable
artifact and is always recoverable from the source store by regeneration, never by hand-editing.

If Rule U's 60-line ceiling blocks Phase 2's ruling, the contingency is stated in that phase's
Scope Hypothesis: relocate the ruling's body to `review-gate-boundary.md` and leave a one-line
pointer in `EXTENSION.md`. This is a relocation, not a reduction -- the ruling itself is an
acceptance criterion and is not dropped.
