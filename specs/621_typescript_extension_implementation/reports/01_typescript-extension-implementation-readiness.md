# Research Report: Task #621

**Task**: 621 - Implement the typescript extension in the source store with parity plus a
verification-stage gate
**Started**: 2026-11-14T00:14:08Z
**Completed**: 2026-11-14T00:25:00Z
**Effort**: large (as declared on the task); actual remaining work identified below is small
**Dependencies**: Task 620 (COMPLETED)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/typescript/**` (live tree), `agent-system/extensions/python/manifest.json` (parity comparator), `agent-system/extensions/README.md`
- `specs/620_typescript_extension_design/plans/01_typescript-extension-build.md` (959 lines, the authoritative design/build plan referenced by this task's dispatch)
- `specs/620_typescript_extension_design/summaries/01_typescript-extension-build-summary.md`
- Live end-to-end deploy test via `manager.load` (headless `nvim`) against a disposable scratch
  target directory (not this repository, not the source store)
- Lint tooling: `lint-routing-wiring.sh`, `lint-extension-readme-table.sh`,
  `lint-agent-contracts.sh`, `lint-shellcheck.sh`, `check-extension-docs.sh`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The extension this task's dispatch asks to "create in full" already exists in full**, built
  and committed by task 620's own implementation phases (commits `4676df2a1`..`fd5ca3da9`), not
  merely designed. `git status --short -- agent-system/extensions/typescript/` is empty and
  `git diff --stat HEAD -- agent-system/extensions/typescript/` is empty — nothing is pending,
  nothing is uncommitted.
- All 20 files named in the dispatch's parity list are present, non-empty, and match task 620's
  plan exactly (file-for-file), and all 9 `index-entries.json` `line_count` values match a live
  `wc -l` with zero mismatches.
- The four items the dispatch says `python` lacks — `hard_contracts`, `keyword_overrides`,
  `rules/typescript-rules.md`, and the `verification`-stage lifecycle hook — are all present and
  confirmed correctly declared in `manifest.json` (verified directly against `python`'s manifest,
  which indeed has none of the four).
- **The one genuinely undone item is the dispatch's own VERIFICATION clause**: "Deploy the
  extension into a repository via the loader and confirm it produces the expected `.claude/`
  files, the merged `CLAUDE.md` section, and the merged `index.json` entries." Task 620's summary
  explicitly scoped this out ("Loading the `typescript` extension into a repository ... is a
  separate, user-driven decision, not part of this task"). This research dispatch performed that
  exact end-to-end deploy test against a disposable scratch directory and it **passed cleanly**
  (detail below) — so even this item is now empirically confirmed working, not merely planned.
- Recommended disposition: there is no remaining *build* work for the implementation phase to
  do. The implementation phase's job is narrow — formally re-run (or cite) the verification
  evidence this report already gathered, and decide/record whether this task is better closed as
  a verification-only pass than re-implemented from scratch.

## Context & Scope

Task 621's own description is near-verbatim identical to task 620's Design Specification (same
file list, same "parity with python" framing, same "four things python lacks" framing). Task 620
depends on nothing; task 621 depends on task 620; task 620 is `[COMPLETED]`. The question this
research phase needed to answer was therefore not "what should this extension contain" (already
fully answered and built by task 620) but **"is there anything left for task 621 to actually do,
and if so, what"** — i.e. a gap analysis between the dispatch's stated goal and the live
filesystem/git state, plus direct execution of the one verification step task 620 explicitly did
not perform.

## Findings

### Codebase Patterns

**File manifest — complete, 1:1 with the plan.** `find agent-system/extensions/typescript -type f`
returns exactly the 20 files the plan's Design Specification §1 and the task's own dispatch list
name:

```
manifest.json, EXTENSION.md, README.md, index-entries.json, opencode-agents.json,
agents/typescript-research-agent.md, agents/typescript-implementation-agent.md,
skills/skill-typescript-research/SKILL.md, skills/skill-typescript-implementation/SKILL.md,
rules/typescript-rules.md, scripts/typescript-verify.sh,
context/contracts/typescript-adversarial-verification.md,
context/project/typescript/README.md,
context/project/typescript/standards/typescript-style-guide.md,
context/project/typescript/patterns/{zod-validation-patterns.md,path-alias-patterns.md},
context/project/typescript/domain/{tsconfig-reference.md,module-systems.md},
context/project/typescript/tools/{tsc-cli-guide.md,package-manager-detection.md}
```

Plus the registry correction: `agent-system/extensions/README.md` carries a `typescript` row
(`lint-extension-readme-table.sh` confirms no missing/dangling row across all 23 non-core
extension directories).

**Parity with `python` — confirmed by direct manifest diff.** `python/manifest.json` declares
`task_type: "python"`, `dependencies: ["core"]`, a `provides` block, `routing_agents` for all
three ops, and `merge_targets` for `claudemd`/`index`/`opencode_json` with
`section_id: extension_python` — `typescript/manifest.json` mirrors this shape exactly
(`section_id: extension_typescript`, `plan` routed to `planner-agent` in both).

**The four things `python` lacks — confirmed absent from `python` and present in `typescript`**:

| Item | `python/manifest.json` | `typescript/manifest.json` |
|---|---|---|
| `hard_contracts` | absent (key not present) | `{"typescript": ["typescript-adversarial-verification.md"]}` |
| `keyword_overrides` | absent | 8 keywords + 1 alias (`ts`) |
| `rules/*.md` (`provides.rules`) | `[]` (empty) | `["typescript-rules.md"]` |
| `hooks.verification` (top-level) | `provides.hooks: []`, no top-level `hooks` key at all | `provides.hooks: []` (unchanged — correct, see below), top-level `"hooks": {"verification": "scripts/typescript-verify.sh"}` |

Note the one subtlety worth recording precisely: `provides.hooks` and the top-level `hooks` key
are two different fields with two different shapes. `provides.hooks` is always `[]` in both
extensions — `typescript`'s verification hook is declared via the **separate top-level** `hooks`
map (`{"verification": "scripts/typescript-verify.sh"}`), paired with
`provides.scripts: ["typescript-verify.sh"]` (basename form). Both are present and consistent in
`typescript/manifest.json`; a plan or implementation pass that looked only at `provides.hooks`
and concluded the hook was "missing" would be wrong — this is a two-place declaration, not one.

**Line-count integrity.** Every one of `index-entries.json`'s 9 entries (the 8 context files plus
the 1 contract file) was checked against a live `wc -l` of its actual file; zero mismatches.

**Lint/gate status, re-run fresh for this report** (not carried from task 620's summary):

| Check | Result |
|---|---|
| `lint-routing-wiring.sh` | PASSED — 267 passed, 0 failed |
| `lint-extension-readme-table.sh` | PASSED — 23 directories, 23 table rows, 0 violations |
| `lint-agent-contracts.sh` | PASSED WITH WARNINGS — 393 passed, 12 warnings (pre-existing, unrelated), 0 failed |
| `lint-shellcheck.sh` (on `typescript-verify.sh`) | PASSED — 0 findings at `-S warning` |
| `check-extension-docs.sh` | PASSED — all 22 extensions including `typescript` report PASS |

No drift has occurred since task 620 closed; every check that passed then still passes now.

### External Resources

Not applicable — this is a verification/gap-analysis research pass over an already-built,
already-designed internal artifact; no external documentation research was needed or performed.

### Live Deploy Verification (the dispatch's own VERIFICATION clause, executed directly)

The dispatch names a specific, previously-unperformed check: deploy the extension into a
repository via the loader and confirm the three merge outputs. This was executed directly against
a disposable scratch git repository (created and destroyed entirely under this session's own
scratchpad directory — never under this repository's `.claude/` tree, never under the source
store, and never loaded into this repository's own `.claude-extensions.json`), via the same
headless Lua call `deploy-headless.sh` itself uses (`manager.load(name, {confirm=false,
force=true, project_dir=SCRATCH})`), loading `core` then `typescript`.

Result: **all three merge targets confirmed working end-to-end**:

1. **Expected `.claude/` files** — `manager.load` reported `DEPLOY_OK`, and the scratch target's
   `.claude/` tree contained all of: both agents, both skill directories, the rules file, the
   hook script, the contract file, and the full 8-file `context/project/typescript/` subtree
   (`README.md` plus one file in each of `standards/`, `patterns/` [×2], `domain/` [×2],
   `tools/` [×2]) — 16 installed files total per `.claude-extensions.json`'s own count for the
   `typescript` entry, correctly scoped under `.claude/` (not duplicated at a root, matching the
   no-duplicate rule the plan asserts).
2. **Merged `CLAUDE.md` section** — a `## TypeScript Extension` section appears in the generated
   `.claude/CLAUDE.md`, sourced from `EXTENSION.md`, with the routing table, skill-agent mapping,
   verification description, and context pointers intact.
3. **Merged `index.json` entries** — the generated `.claude/context/index.json` carries all 9
   `typescript`-tagged entries (8 context files + 1 contract), matching `index-entries.json`
   exactly.

One real, worth-recording mechanism surfaced during this test: **`opencode.json` generation is
gated by a `.managed` marker file** (`merge.lua`'s `generate_opencode_json`, "Step 1.2:
Managed/unmanaged gating" — `if vim.fn.filereadable(target_path .. ".managed") ~= 1 then return
true, nil, {} end`). On the first deploy attempt (no marker present), `generate_opencode_json`
reported success (`ok=true`) yet correctly wrote no file — this is the function's own documented
no-op path, not a defect. Creating `opencode.json.managed` in the scratch target and re-running
confirmed the fourth merge target too: the regenerated `opencode.json` carries both
`typescript-research` and `typescript-implementation` agent keys, sourced from
`opencode-agents.json`, alongside the other loaded extensions' agents. This is useful,
previously-unrecorded-for-this-extension detail for whoever writes the verification
criteria/tests for the implementation phase: a plain `manager.load` into a fresh repo will **not**
produce an `opencode.json` at all unless that repo has already opted in via the marker file —
testing the `opencode_json` merge target specifically requires creating that marker first, exactly
as done here.

The scratch test repository and all generated files were deleted after the test; no trace of this
test exists in this repository, the source store, or any target repo's state.

## Recommendations

- **Do not re-run the file-creation work of task 620's plan.** Every file the dispatch names
  already exists, matches budget, passes every available lint, and was independently re-verified
  by this research pass (not merely re-cited from task 620's own summary). Re-creating any of
  these files from scratch would be redundant work against a clean, passing baseline.
- **The implementation phase's actual job is to close out the one item task 620 deliberately
  left open**: formally execute (or cite, since this report already performed it) the
  deploy-and-confirm verification the dispatch names, and record it against *this* task's own
  artifacts (summary/`.return-meta.json`) rather than leaving it attributed only to a research
  report. A plan is still useful here as the vehicle for that formal closing step plus a final
  re-confirmation that nothing has drifted between this research pass and the implementation
  dispatch that follows it (a second, fresh `git status --short -- agent-system/extensions/typescript/`
  and a second lint re-run cost almost nothing and remove any doubt about intervening changes).
- **Record the `opencode.json.managed` gating behavior** somewhere more durable than this report
  if a future extension author needs to test the `opencode_json` merge target end-to-end — it is
  not obviously discoverable from the manifest or the plan, and a tester who does not know about
  it will wrongly conclude the merge target is broken rather than correctly gated.
- Given the near-complete overlap between this task's description and task 620's already-closed
  scope, the planning phase that follows should consider whether a full `plan-format.md`-shaped
  implementation plan is proportionate here, or whether a minimal verification-closing plan (one
  short phase: re-confirm + record) better reflects the actual remaining work — a judgment call
  for the planner, not asserted here as a decision.

## Decisions

- No files were created, edited, or deleted in the source store, this repository's deploy tree,
  or any consumer repository during this research pass. All verification was performed against a
  disposable scratch directory under the session scratchpad, deleted on completion, per the
  source-store/deploy-boundary rule and this agent's research-only role.
- The live end-to-end deploy test (not merely re-reading task 620's summary) was treated as
  necessary rather than optional, because it is the one concrete check the dispatch names that
  task 620's own summary explicitly declined to perform ("a separate, user-driven decision, not
  part of this task") — leaving it unexecuted would have left the dispatch's VERIFICATION clause
  genuinely unanswered rather than merely re-described.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| A future dispatch re-implements already-complete files, wasting effort or introducing drift against the passing baseline | This report's file-by-file and lint-by-lint confirmation, dated to this research pass, should be cited directly by the planning/implementation phases rather than re-derived from scratch each time |
| The `opencode.json.managed` gating mechanism causes a future tester to misdiagnose a correctly-gated no-op as a merge-target defect | Documented explicitly above with the exact code path (`merge.lua`'s `generate_opencode_json`, Step 1.2) and the exact marker-file workaround used to force the test through |
| Scope ambiguity: task 621 may be read as "re-do the build" when the actual gap is "close the one deferred verification item" | This report states the gap explicitly and recommends the planning phase size the remaining work accordingly rather than assuming a full rebuild |

## Context Extension Recommendations

- **Topic**: extension end-to-end deploy testing procedure
- **Gap**: there is no documented, reusable procedure (in `context/guides/extension-development.md`
  or `context/guides/loader-reference.md`) for headlessly loading a new extension into a
  disposable scratch target to verify its three (or four, including `opencode_json`) merge
  targets, nor any mention of the `opencode.json.managed` gating marker. This research pass had to
  reconstruct the exact `manager.load` Lua invocation from `deploy-headless.sh`'s own internals.
- **Recommendation**: a short addition to `context/guides/extension-development.md` (or a new
  `context/patterns/` file) capturing the scratch-target headless `manager.load` invocation shape
  and the `opencode.json.managed` gating behavior would let future extension-authoring tasks
  verify their own merge targets without re-deriving this from `deploy-headless.sh`'s source each
  time.

## Appendix

- Search queries/commands used: `find agent-system/extensions/typescript -type f`,
  `git log --oneline -- agent-system/extensions/typescript/`,
  `git status --short -- agent-system/extensions/typescript/`,
  `git diff --stat HEAD -- agent-system/extensions/typescript/`,
  direct `jq`/`cat`/`grep` reads of `manifest.json` (both `typescript` and `python`),
  `index-entries.json`, `README.md`, agent frontmatter; headless `nvim --headless -c "lua ...
  manager.load(...)"` against a scratch target; `lint-routing-wiring.sh`,
  `lint-extension-readme-table.sh`, `lint-agent-contracts.sh`, `lint-shellcheck.sh`,
  `check-extension-docs.sh`.
- References: `specs/620_typescript_extension_design/plans/01_typescript-extension-build.md`;
  `specs/620_typescript_extension_design/summaries/01_typescript-extension-build-summary.md`;
  `lua/neotex/plugins/ai/shared/extensions/{init,merge}.lua`; `.claude/scripts/deploy-headless.sh`.
