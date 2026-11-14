# Implementation Plan: Task #623

- **Task**: 623 - Make the `web` extension depend on the `typescript` extension and split the shared TypeScript context down a layer
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None (prerequisite tasks 621 and 622 are both [COMPLETED])
- **Research Inputs**: specs/623_web_extension_depends_on_typescript/reports/01_web-typescript-dependency-split.md
- **Artifacts**: plans/01_web-typescript-dependency-split.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Wire `web` to `typescript` as a declared extension dependency, and remove the two subsections of
`web`'s `typescript-web.md` whose content is generic TypeScript material already authored in the
`typescript` extension's own context tree. Three phases: the content split plus its coupled
`line_count` regeneration (Phase 1), the two web-agent `## Context References` pointers that make
the dependency actually change agent behavior (Phase 2), and the manifest declaration plus
end-to-end deploy/dependency verification (Phase 3). All writes land in the source store under
`agent-system/extensions/`; nothing is hand-authored under any `.claude/` deploy tree.

### Research Integration

Four findings from the research report drive this plan's shape:

1. **The manifest edit alone changes no agent behavior.** `web-research-agent.md` and
   `web-implementation-agent.md` discover context through a static, hand-authored
   `## Context References` `@`-pointer list, not through an `index.json` `load_when` query
   (grep for `load_when`/`jq`/`index.json` in either file returns zero matches). Phase 2 is
   therefore a hard completion requirement of this task, not an optional extra — without it the
   manifest diff looks correct while "Astro work auto-loads the base TypeScript context" remains
   false.
2. **The split is narrow and bounded**: exactly two subsections of the 303-line
   `typescript-web.md` are generic — `### Common Zod Patterns` and `## Import Aliases` — and both
   duplicate content that already exists, independently authored, in `typescript`'s tree. No new
   file is created under `typescript/`.
3. **`line_count` is a commit-blocking coupled surface.** `check-extension-docs.sh`'s Rule R
   runs under `verify-deploy.sh` gate 3 with `INDEX_TRUTH_GATE_MODE` defaulting to `hard`, so a
   stale `line_count` is a hard FAIL, not an advisory. The trim and the regeneration must land in
   the same phase.
4. **Unload is a hard block, not a warning**: once `web` is loaded, unloading `typescript` is
   refused with `ERROR: Cannot unload 'typescript' -- required by: web`. This is an expected
   observation in Phase 3's verification, not a defect.

Two facts were measured directly while authoring this plan, beyond the report:

- `generate-context-line-counts.sh --check` currently reports **604/604 entries exact** across
  every extension, so the post-trim `--write` is expected to touch exactly one file.
- `check-extension-docs.sh`'s `INDEX_TRUTH_GATE_MODE` default is `hard` (line 771), confirming
  Rule R's blocking status rather than assuming it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation
was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- `web`'s `manifest.json` declares `typescript` as a dependency, so loading `web` auto-loads
  `typescript`'s files.
- Both web agents can actually reach the generic TypeScript context tree, via the same one-line
  README-pointer convention `typescript-research-agent.md` already uses.
- `typescript-web.md` carries only Astro/browser/Cloudflare-specific TypeScript material; the two
  generic subsections become named cross-references to their `typescript`-extension homes.
- Both extensions' `index-entries.json` are correct for the post-split state — `web`'s
  `line_count` corrected, `typescript`'s confirmed (and explicitly reported) as needing no change.
- Clean standalone and combined deploys are re-verified, and the dependency auto-load path,
  circular-detection guard, and depth limit are confirmed.

**Non-Goals**:
- Creating any new file under `typescript/context/project/typescript/` — the generic content the
  trimmed subsections duplicate is already there.
- De-duplicating `web-astro.md`'s "TypeScript Standards" table against
  `typescript-style-guide.md`. Named by neither the task description nor this plan's scope;
  flagged by research as a separate follow-up.
- Introducing a synthetic dependency cycle to exercise circular detection. The guard is confirmed
  by code reading plus the real (acyclic) closure, never by fabricating a cycle in a committed
  manifest.
- Any write under `.claude/**`. That tree is a disposable deploy artifact regenerated from the
  source store.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Trimming the two subsections without the Phase 2 agent pointers silently removes coverage a web agent previously had inline | H | M | Phase 2 is a hard completion requirement and sits in the same wave as Phase 1; Phase 3's verification checklist re-confirms both agent files carry the pointer before the task can close |
| `line_count` drift after the trim trips `check-extension-docs.sh` Rule R (hard FAIL under gate 3) | H | H without mitigation | Regenerate with `generate-context-line-counts.sh --write` in the same phase as the trim; `web/index-entries.json` is declared in that phase's `Files to modify` |
| `generate-context-line-counts.sh --write` walks **every** extension and could rewrite files outside this task's scope | M | L | Pre-census with `--check` (currently 604/604 exact), then `git status --short` after `--write`; stage only `web/index-entries.json` and leave any unrelated correction unstaged, reporting it |
| `verify-deploy.sh` fails on the pre-existing `lean` deploy staleness rather than on this task's work | M | M | Phase 3 attributes every failure to a named extension before acting; a staleness-traced failure is remedied by the bounded-wait redeploy, which is why that phase declares the `__WHOLE_TREE__` sentinel |
| A future maintainer re-adds the trimmed Zod/alias prose, re-introducing drift | M | M | Each replacement pointer names the exact target file path, not a vague "see the typescript extension" |
| Tester surprised by the unload hard block when tearing down the scratch target | L | M | Phase 3's checklist states the expected `Cannot unload 'typescript' -- required by: web` error and the correct unload order (`web` first) |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Split typescript-web.md and regenerate its line_count [COMPLETED]

**Goal**: Remove the two generic subsections from `typescript-web.md`, replace each with a
one-line cross-reference naming its exact `typescript`-extension home, and bring
`web/index-entries.json`'s `line_count` back into agreement with the file.

**Tasks**:
- [x] Run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check`
      and record the pre-edit census (expected: all entries exact). *(completed: 604/604 exact, confirmed before any edit)*
- [x] Locate `### Common Zod Patterns` and `## Import Aliases` by heading text (not by line
      number) in `agent-system/extensions/web/context/project/web/domain/typescript-web.md`. *(completed)*
- [x] Replace the body of `### Common Zod Patterns` with a short pointer that keeps the heading
      and names the target file explicitly: the generic Zod primitives (enum, `coerce.date`, URL,
      constrained string, nested object, discriminated union) live in the `typescript`
      extension's `context/project/typescript/patterns/zod-validation-patterns.md` ("Core
      Primitives"); note that Astro re-exports Zod as `astro/zod` and the primitives are
      identical. *(completed)*
- [x] Replace the body of `## Import Aliases` with a pointer to the `typescript` extension's
      `context/project/typescript/patterns/path-alias-patterns.md` ("Using an Alias"),
      **retaining** the one Astro-specific clause: Astro resolves `tsconfig.json` `paths` aliases
      automatically, in both `.astro` frontmatter and `.ts` files, with no bundler plugin. *(completed)*
- [x] Leave every other section untouched — in particular the Astro-specific
      `## Content Collection Schemas with Zod` block immediately above the first trimmed
      subsection, and `## Type Checking` immediately below the second. *(completed: heading list re-read post-edit, both sections and every other heading intact)*
- [x] Re-read `agent-system/extensions/web/context/project/web/README.md` lines 14, 53 and 109 and
      confirm each reference to `typescript-web.md` is still accurate post-trim (line 53's "Zod
      schemas and type utilities" remains true: the Astro content-collection Zod section stays).
      Record the confirmation; edit only if a reference has actually become false. *(completed: all three references confirmed accurate, no edit required)*
- [x] Run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`,
      then `git status --short` to confirm which files it rewrote. *(completed: rewrote exactly one file, web/index-entries.json, line_count 303 -> 272)*
- [x] Stage only `typescript-web.md` and `agent-system/extensions/web/index-entries.json`. If
      `--write` corrected any other extension's file, leave it unstaged and report it in the
      phase notes rather than folding it into this task's commit. *(completed: no other extension file was rewritten by --write; the pre-existing, already-dirty lean/index-entries.json modification predates this dispatch and is unrelated)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes the trim removes ~43 lines (the two subsections as
audited at lines 204-232 and 234-247 of the 303-line file), that the replacement pointers add
back ~6 lines for a post-split count in the ~262-266 range, and that
`generate-context-line-counts.sh --write` rewrites exactly one file because the pre-edit census
is 604/604 exact. Confirm all three at implementation time: locate the subsections by heading
text rather than trusting the line numbers, take the real count from the `--check` output rather
than from this estimate, and read `git status --short` after `--write` rather than assuming the
one-file result.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this phase's path set — the markdown file maps to no suite, which collapses the whole selection — so the honest covering check is the source-store gate subset `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`, gate 3 being where `check-extension-docs.sh` Rule R reads the regenerated `line_count`, run alongside the `local` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/web/context/project/web/domain/typescript-web.md` - trim the two generic subsections, replace each with a named cross-reference pointer, keep the Astro-specific alias-resolution clause
- `agent-system/extensions/web/index-entries.json` - `line_count` for the `project/web/domain/typescript-web.md` entry, regenerated (coupled generated surface; `check-extension-docs.sh` Rule R is a hard FAIL under gate 3)

**Verification**:
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check`
  exits 0 with no mismatch reported for `web`.
- `grep -c "z.discriminatedUnion\|z.coerce.date" agent-system/extensions/web/context/project/web/domain/typescript-web.md`
  returns 0 — the generic Zod primitive block is gone.
- Both replacement pointers name a full `context/project/typescript/patterns/...` path; `grep -n
  "zod-validation-patterns\|path-alias-patterns"` on the trimmed file returns both.
- The Astro-specific alias clause survives: the file still states that Astro resolves the aliases
  automatically.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with no new finding (this is the phase's declared covering check).
- Supplementary, for the `index-entries.json` path taken on its own — the selector maps it to
  these six suites: `bash .claude/scripts/tests/run-all.sh --only test-context-reachability.sh,test-deploy-orphans.sh,test-index-entries-schema.sh,test-install-uninstall-extension.sh,test-manifest-scripts-sync.sh,test-roadmap-command-registration.sh`
  exits 0.

---

### Phase 2: Give both web agents a pointer into the TypeScript context tree [NOT STARTED]

**Goal**: Make the declared dependency functionally meaningful by adding the generic TypeScript
context tree's README to each web agent's static `## Context References` list — the verified
channel through which these two agents actually load context.

**Tasks**:
- [ ] In `agent-system/extensions/web/agents/web-research-agent.md`, add one entry to the
      `**Load for Web Research**` list (the `## Context References` section, around line 87):
      `` `@.claude/context/project/typescript/README.md` - Generic TypeScript context tree index
      (loaded via the `typescript` extension dependency) ``.
- [ ] In `agent-system/extensions/web/agents/web-implementation-agent.md`, add the same one-line
      entry to the `**Load for Web Work**` list (the `## Context References` section, around
      line 92), keeping it adjacent to the existing
      `@.claude/context/project/web/domain/typescript-web.md` entry so a reader sees the
      generic/Astro-specific pairing in one place.
- [ ] Use exactly one line per agent, pointing at the tree's README only — do not enumerate the
      seven leaf files. The README's own "Loading Strategy" table is what directs on-demand
      reading, matching `typescript-research-agent.md`'s established convention.
- [ ] Confirm neither agent file gains any `load_when`/`index.json` query text: the pointer is
      static by design, and this plan does not change that mechanism.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: Covered by `bash .claude/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh,test-lint-agent-contracts-heartbeat.sh` — the selector's exact output for these two agent files and the only suites that read agent-definition structure.

**Files to modify**:
- `agent-system/extensions/web/agents/web-research-agent.md` - one `@`-reference line added to `## Context References`
- `agent-system/extensions/web/agents/web-implementation-agent.md` - one `@`-reference line added to `## Context References`

**Verification**:
- `grep -c "project/typescript/README.md"` returns 1 for each of the two agent files.
- `grep -n "load_when\|index.json" ` on both files still returns zero matches.
- `bash .claude/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh,test-lint-agent-contracts-heartbeat.sh`
  passes.
- Each added line's shape matches `typescript-research-agent.md`'s own README pointer (backticked
  `@`-path followed by ` - ` and a short description).

---

### Phase 3: Declare the dependency, reconcile both index files, and verify end to end [NOT STARTED]

**Goal**: Add `typescript` to `web`'s `dependencies`, document the dependency in `web`'s
human-facing and CLAUDE.md-merged docs, confirm the `typescript`-side `index-entries.json`
requires no change, and verify standalone, combined, and unload behavior against a disposable
scratch target plus the complete gate set.

**Tasks**:
- [ ] Edit `agent-system/extensions/web/manifest.json`: `"dependencies": ["core", "typescript"]`.
      Change nothing else in the manifest.
- [ ] Add a one-line dependency note to `agent-system/extensions/web/README.md` (under
      Installation): loading `web` auto-loads `typescript`, whose generic TypeScript context tree
      lives at `context/project/typescript/`.
- [ ] Add the equivalent one-line note to `agent-system/extensions/web/EXTENSION.md`'s
      `### Context` section. That file is a `claudemd` merge source subject to a 60-line limit
      (Rule U) and a byte ceiling (Rule V); it is currently 25 lines, so a two-line addition is
      safe — re-check `wc -l` after editing rather than assuming.
- [ ] Re-confirm `web/index-entries.json` is correct after Phase 1 (the `line_count` edit already
      landed there); make no second edit unless `--check` reports drift.
- [ ] Inspect `agent-system/extensions/typescript/index-entries.json` and confirm **no** change is
      required: nothing moved into `typescript`'s tree, so its nine entries, their `load_when`
      blocks, and their `line_count` values all stand. **State this explicitly in the phase notes
      and the implementation summary** — a reader must not read "no diff" as "forgotten".
- [ ] Compute and record the real dependency closure: `web -> [core, typescript]`,
      `typescript -> [core]` (already loaded, skipped). Maximum loading-stack depth 2, against the
      loader's `max_depth = 5`; no cycle is possible because neither `core` nor `typescript`
      depends on `web`. Confirm the guard itself by reading the loading-stack and depth checks in
      `lua/neotex/plugins/ai/shared/extensions/init.lua`. Do not fabricate a cycle to test it.
- [ ] Scratch-target deploy verification, following the procedure in
      `agent-system/extensions/typescript/README.md`'s "Verifying This Extension's Own Deploy"
      section, in a disposable scratch git repo under this session's scratchpad (never this
      repository, the source store, or any `.claude-extensions.json`-registered target):
      (a) load `typescript` alone and confirm its four merge targets;
      (b) in a **fresh** scratch repo, load `web` alone and confirm `typescript` auto-loads with
      no confirmation prompt, that both extensions' files are present, and that each extension's
      merge targets are correct — including a `## TypeScript Extension` section in the scratch
      `CLAUDE.md` and all nine `typescript` entries in the scratch `context/index.json`;
      (c) in that same repo, attempt `manager.unload('typescript')` and confirm the hard block
      `ERROR: Cannot unload 'typescript' -- required by: web`, then confirm unloading `web` first
      makes the `typescript` unload succeed.
- [ ] Create the `opencode.json.managed` marker in the scratch repo before judging the
      `opencode_json` merge target — without it that target is a documented no-op, and a tester
      who skips it will wrongly conclude the target is broken.
- [ ] Delete the scratch repository and everything it generated.
- [ ] Run the lint set research named, against both extensions:
      `lint-routing-wiring.sh`, `lint-extension-readme-table.sh`, `lint-agent-contracts.sh`,
      `lint-shellcheck.sh`, and `check-extension-docs.sh` (the deployed copies under
      `.claude/scripts/lint/` and `.claude/scripts/`).
- [ ] Run the complete gate set (see Verification below). Before acting on any failure, attribute
      it to a named extension: this repository's deployed tree is already stale for `lean`,
      which is unrelated to this task. If and only if a failure traces to that staleness, remedy
      it with the bounded-wait redeploy
      `timeout 540 bash .claude/scripts/deploy-headless.sh` (Bash tool `timeout` parameter raised
      to 600000, not its 120000 ms default) and re-run — this is the step for which this phase
      declares the whole-tree sentinel.

**Timing**: 1.75 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes `typescript/index-entries.json` needs exactly zero
changes (nine entries, all currently exact) and that the loading closure reaches depth 2 of the
loader's limit of 5. Confirm the first by re-running `generate-context-line-counts.sh --check`
and diffing the file (expect an empty diff) rather than asserting it, and the second by reading
both manifests' `dependencies` arrays at implementation time rather than trusting this
plan's snapshot of them.

**Files to modify**:
- `agent-system/extensions/web/manifest.json` - add `"typescript"` to the `dependencies` array
- `agent-system/extensions/web/README.md` - one-line dependency note under Installation
- `agent-system/extensions/web/EXTENSION.md` - one-line dependency/context note in `### Context`
- `agent-system/extensions/typescript/index-entries.json` - inspected and confirmed unchanged; declared here because this phase's goal includes reconciling it, and an empty diff is the expected, reported outcome
- `__WHOLE_TREE__` - the conditional `deploy-headless.sh` remediation step above regenerates the entire deployed tree

**Verification**:
- `jq -r '.dependencies | join(",")' agent-system/extensions/web/manifest.json` returns
  `core,typescript`.
- `git diff --stat agent-system/extensions/typescript/index-entries.json` is empty, and the phase
  notes state that this no-op was verified rather than skipped.
- Scratch cases (a), (b) and (c) all behave as described, including the unload hard block; the
  scratch repository is deleted afterward.
- The five lints above all pass for both `web` and `typescript`.
- The complete gate set runs green: `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`), with no `--skip-slow` and no
  `--only-gate` narrowing, observed green in this dispatch rather than trusted on sight.
- `wc -l agent-system/extensions/web/EXTENSION.md` is well under 60.

---

## Testing & Validation

- [ ] `generate-context-line-counts.sh --check` passes with no `web` or `typescript` finding.
- [ ] Both web agent files reference `@.claude/context/project/typescript/README.md` exactly once.
- [ ] `typescript-web.md` contains no generic Zod primitive block and no generic alias example,
      but retains every Astro-specific section and the Astro alias-resolution clause.
- [ ] A scratch-target `web`-only load deploys both extensions' files with no prompt.
- [ ] Unloading `typescript` while `web` is loaded is refused with the dependent-naming error.
- [ ] `bash .claude/scripts/verify-deploy.sh` (complete gate set) passes.
- [ ] No file under any `.claude/` tree was hand-authored; `git status --short` shows changes only
      under `agent-system/extensions/` and `specs/`.

## Artifacts & Outputs

- `agent-system/extensions/web/manifest.json` (dependency declared)
- `agent-system/extensions/web/context/project/web/domain/typescript-web.md` (split)
- `agent-system/extensions/web/index-entries.json` (`line_count` regenerated)
- `agent-system/extensions/web/agents/web-research-agent.md`,
  `agent-system/extensions/web/agents/web-implementation-agent.md` (context pointers)
- `agent-system/extensions/web/README.md`, `agent-system/extensions/web/EXTENSION.md`
  (dependency documented)
- An implementation summary recording the verified `typescript/index-entries.json` no-op, the
  post-split line count, and the three scratch-target verification results.

## Rollback/Contingency

Every edit is a small, reviewable diff in the source store, and each phase commits separately, so
reverting is a per-phase `git revert` of that phase's commit. Neither `web` nor `typescript` is
currently loaded in this repository's `.claude-extensions.json`, so no live deploy state depends
on these files and a revert needs no redeploy to take effect here. If the scratch-target
verification in Phase 3 fails in a way the manifest edit caused, revert Phase 3's commit alone:
Phases 1 and 2 stand on their own (the trimmed file's pointers name real files in the
`typescript` extension's source tree whether or not `web` declares the dependency, and the agent
pointers are inert until the dependency deploys the tree). If a destructive rollback of
uncommitted work ever becomes necessary, snapshot first with
`bash .claude/scripts/git-snapshot.sh 623`.
