# Research Report

**Task**: Resolve source store target in deployed trees
**Started**: 2026-09-22
**Completed**: 2026-09-22
**Effort**: Small (rule-text-only fix; no deploy-machinery change required)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` (source-store copy)
- `.claude/rules/source-store-deploy-boundary.md` (this repo's own deployed copy)
- `~/Projects/BimodalLogic/.claude/rules/source-store-deploy-boundary.md` and
  `~/Projects/BimodalLogic/.claude-extensions.json` (real consumer repo, used for verification)
- `lua/neotex/plugins/ai/shared/extensions/config.lua`, `state.lua`, `loader.lua`, `init.lua`
- `agent-system/extensions/core/scripts/deploy-headless.sh`,
  `agent-system/extensions/core/scripts/check-deploy-freshness.sh`
- `specs/227_resolve_source_store_target_in_deployed_trees/reports/01_source-store-rule-has-no-target.md`
  (prior round's evidence report, produced 2026-09-16/17)
- `.syncprotect` (both repos)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The deploy engine already stamps the exact absolute source-store path for every loaded
  extension into a project-root file, `.claude-extensions.json`, at
  `extensions.<name>.source_dir` — e.g. in `~/Projects/BimodalLogic/.claude-extensions.json`,
  `extensions.core.source_dir` reads `/home/benjamin/.config/nvim/agent-system/extensions/core`.
  This was confirmed against a real consumer repository, not inferred from code alone.
- This file lives at the project root, outside `.claude/`, specifically so it survives a
  `.claude` wipe (`config.lua`'s `root_state_file` comment), and it is gitignored in both this
  repo and BimodalLogic, so it is regenerated fresh on every deploy — the recorded path can never
  go stale the way a hard-coded path baked into rule text would.
- **Recommendation**: rewrite the rule's "Correct Edit Target" section to resolve the source
  store *indirectly*, at agent-read-time, via this field — not by hard-coding
  `agent-system/extensions/**` (the current defect), and not by having the deploy step rewrite
  the rule's prose (dispatch option (b), which would require new deploy-time templating
  machinery that does not currently exist for the `rules` category). This is cheaper than option
  (b) and more precise/generalizable than option (a) as literally stated, because it reuses
  machinery that already exists and is already treated as authoritative elsewhere in the
  codebase (`check-deploy-freshness.sh`).
- A known, already-handled degraded case exists: `check-deploy-freshness.sh` already documents
  "an entry missing `source_dir` or `source_git_head` (every pre-fix deploy)" as a real
  possibility on older deployed trees. The rewritten rule text needs the same fallback: if the
  file, the extension's entry, or `source_dir` itself is absent/unreadable/nonexistent on disk,
  treat the source store as unreachable and say so, rather than falling through to hand-authoring
  `.claude/**`.

## Context & Scope

Task 227 is a `meta` task confined to the rule's own target-resolution text (per the dispatch's
"COORDINATE, DO NOT DUPLICATE" note, deploy-propagation and consumer-bootstrap tasks own adjacent
surface). The rule's substance is not in question: hand-authoring into a deployed `.claude/**` is
still forbidden. The dispatch supplied three options to evaluate (conditional text, deploy-step
rewrite, scope-out) without pre-committing to one. This round's job was to determine, from the
actual deploy engine and a real consumer repository, which option is both correct and cheap.

## Findings

### Codebase Patterns

**The absolute source-store path is already computed and recorded per extension, at deploy
time, in a project-root file that outlives `.claude/`.**

- `lua/neotex/plugins/ai/shared/extensions/config.lua:61-67` (`M.claude`): `global_dir` defaults
  to `vim.fn.expand("~/.config/nvim")` and `global_extensions_dir = global_dir ..
  "/agent-system/extensions"` — an absolute, machine-local path computed once per deploy
  invocation, independent of which repo is being deployed into.
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua:158,172-185`: each extension's manifest
  is stamped with `manifest._source_dir = extension_dir` (an absolute path under
  `global_extensions_dir`).
- `lua/neotex/plugins/ai/shared/extensions/state.lua:155-170` (`M.mark_loaded`): on every load,
  writes `state.extensions[extension_name] = { source_dir = manifest._source_dir,
  source_git_head = M.resolve_source_git_head(manifest._source_dir), ... }`.
- `config.lua:33-35` (`root_state_file` field comment): "Extension selection manifest file name,
  deployed at the PROJECT ROOT (not inside base_dir) so it survives a `.claude`/`.opencode`
  wipe." — i.e. `.claude-extensions.json` is written outside `.claude/`, by design, precisely so
  it is not itself subject to the `.claude/` regeneration/wipe cycle the boundary rule protects
  against.
- `deploy-headless.sh`'s `--wipe` mode only `rm -rf .claude`; `.claude-extensions.json` sits
  outside that path and is untouched by wipe, then re-verified/re-stamped on the subsequent
  reload of every formerly-active extension.

**Verified against a real consumer repository** (`~/Projects/BimodalLogic`, not this repo):

```json
// ~/Projects/BimodalLogic/.claude-extensions.json
"extensions": {
  "core": {
    "source_dir": "/home/benjamin/.config/nvim/agent-system/extensions/core",
    "source_git_head": "83675df1c65880a4a17c0d7f65164d35d895f42b",
    "version": "1.0.0",
    "loaded_at": "2026-09-22T05:34:16Z"
  },
  ...
}
```

`~/Projects/BimodalLogic/.gitignore` gitignores both `/.claude` and `/.claude-extensions.json`
(and `/CLAUDE.md`), so both are deploy artifacts of the same kind — but only `.claude/**` is what
the boundary rule forbids hand-authoring into; `.claude-extensions.json` is read-only reference
data for an agent, never itself an edit target.

`~/Projects/BimodalLogic/.claude/rules/source-store-deploy-boundary.md` is confirmed still
deployed verbatim with the unresolvable hard-coded path, exactly as the prior round's evidence
report (01) found on 2026-09-16/17 — the defect is still live in that tree as of this research
pass (2026-09-22).

**No templating/substitution machinery exists today for the `rules` category.** `copy_file` in
`loader.lua:54-82` is a byte-for-byte `read_file`/`write_file` copy with no placeholder
substitution; the only content-rewriting path in the extension loader is
`process_merge_targets`/`merge.lua`, which is specific to the `merge_targets` category (used for
generating `CLAUDE.md` from fragments), not `rules`. This means dispatch option (b) — "have the
deploy step rewrite the Correct Edit Target section" — is not a small change: it would require
adding a new per-file content-substitution mechanism to the loader for a category that has never
needed one, register `rules/source-store-deploy-boundary.md` as a special case, and keep that
substitution correct across every future edit to the file's prose. The `.claude-extensions.json`
approach needs none of this: the data is already computed and written; only the rule's prose
needs to change, to point at data that already exists.

**Precedent for treating `.claude-extensions.json`'s `source_dir`/`source_git_head` fields as
authoritative, including their degraded case, already exists in shipped tooling**:
`check-deploy-freshness.sh` (referenced from `state.lua`'s own docstring) reads
`<repo_root>/.claude-extensions.json`, and its header comment explicitly enumerates failure modes
it already handles: "missing or unparseable .claude-extensions.json", "an entry missing
`source_dir` or `source_git_head` (every pre-fix deploy)", "`source_dir` does not exist on disk",
"`source_dir` is not inside a git repository". The rewritten rule text's fallback case can name
the same conditions rather than inventing new ones.

**`.syncprotect` is irrelevant to this fix.** Both repos' `.syncprotect` files only protect
`context/repo/project-overview.md`-shaped entries; the rule file itself is not (and should not
be) listed there — protecting it would only preserve a stale hand edit across future deploys,
which is exactly the failure mode the boundary rule exists to prevent. The correct fix changes
the *source-store copy* of the rule (`agent-system/extensions/core/rules/source-store-deploy-boundary.md`
in this repo), which then propagates to every consumer, including this repo's own deployed
`.claude/rules/source-store-deploy-boundary.md`, on the next ordinary deploy.

### External Resources

Not applicable — this is a closed-system, codebase-internal defect; no external documentation
informs the fix.

### Recommendations

**Primary recommendation — resolve the target indirectly via `.claude-extensions.json`, edited
only in the source-store copy of the rule.**

Rewrite `agent-system/extensions/core/rules/source-store-deploy-boundary.md`'s "Correct Edit
Target" section along these lines (exact wording is an implementation-time decision, not
pre-committed here per the dispatch's "evaluate, do not pre-commit" instruction):

1. State that the source store's absolute location is machine- and deploy-specific, and is
   recorded at `<project-root>/.claude-extensions.json`'s `extensions.<name>.source_dir` field
   (one entry per loaded extension; `core` for core system files, the extension's own name for
   extension-owned files under `agent-system/extensions/<ext>/**`).
2. Instruct the agent: read that field for the relevant extension, confirm the path exists on
   disk, and edit `<that path>/**`.
3. Name the fallback explicitly: if `.claude-extensions.json` is missing, unparseable, lacks the
   relevant extension's entry, or the recorded `source_dir` does not exist on disk, the source
   store is not reachable from this machine/tree. In that case the agent MUST NOT hand-author
   `.claude/**` (the boundary's substance is unchanged) and should instead record the needed
   change for a human to port later — e.g. as a note in its own task's artifacts, using whatever
   task-filing mechanism this deployed tree already provides. Do not invent a new filing
   mechanism as part of this task; the dispatch's own scope note excludes it, and every deployed
   tree with the `core` extension already has `/task` available for exactly this.
4. Keep the existing "Enforcement" section's two-layer framing (advisory hook + agent contract)
   unchanged; it is repository-independent and does not name the broken path.

This satisfies the dispatch's acceptance criterion directly: a deployed consumer tree's copy of
the rule would name `.claude-extensions.json`'s `core.source_dir` field, which — verified above
against BimodalLogic, a real consumer repository — an agent in that tree can actually read and
act on, today, with no further machinery changes.

**Evaluation of the dispatch's three literal options, for completeness:**

- **(a) Conditional text in the rule** ("if this repo contains `agent-system/`, edit there;
  otherwise... report instead"): cheapest, and the "report instead" fallback is right, but as
  literally scoped in the dispatch it gives the consumer agent no filing mechanism and — more
  importantly — is strictly worse than the primary recommendation above, which achieves the same
  cheapness (rule-text-only, no deploy-machinery change) while also giving the consumer agent a
  concrete, reachable target instead of only a "do not edit, report" instruction. Superseded by
  the primary recommendation rather than rejected outright: the primary recommendation *is* a
  refined version of (a) that adds a real resolution path before falling back to (a)'s report-only
  behavior.
- **(b) Deploy-step rewrites the rule's prose**: most precise in principle, but — per the Findings
  above — the loader has no substitution mechanism for the `rules` category today; building one
  is a real (if modest) deploy-machinery change and a second thing to keep correct (the deploy
  step's rewrite logic and the rule's prose would need to stay in sync). The `.claude-extensions.json`
  field already gives equivalent precision without any of that new machinery, because the deploy
  engine already computes and writes the exact same information as a side effect of loading the
  extension at all — it just isn't being pointed to from the rule text yet. Not recommended,
  given the cheaper alternative exists.
- **(c) Scope the rule out of deployed trees, keep only the agent-contract half**: this would
  remove the explanatory "why" from every consumer tree and rely solely on
  `general-implementation-agent.md`'s MUST NOT bullet (referenced in this repo's own rule file's
  Enforcement section but not independently verified in this pass, since it is outside this
  task's file scope) — a narrower audience than "every agent or human that opens the rule file."
  Not recommended: it throws away context that costs nothing to keep once the target is fixed.

## Decisions

- The fix belongs entirely in `agent-system/extensions/core/rules/source-store-deploy-boundary.md`
  (the source-store copy) — never in any deployed `.claude/rules/**` copy, consistent with the
  rule's own substance and with `.claude/rules/source-store-deploy-boundary.md`'s Enforcement
  section.
- No deploy-machinery change (loader.lua, deploy-headless.sh, config.lua) is needed. The fix is a
  prose rewrite of one rule file's "Correct Edit Target" section.
- The resolution mechanism is `.claude-extensions.json`'s `extensions.<name>.source_dir` field,
  already computed and written by the existing deploy engine and already treated as
  authoritative-with-known-degraded-case by `check-deploy-freshness.sh`.

## Risks & Mitigations

- **Risk**: a deployed tree predates the `source_git_head`/`source_dir` stamping feature (task 18
  in this repo's own history) and its `.claude-extensions.json` entry lacks `source_dir`
  entirely. **Mitigation**: the rule's fallback text (point 3 above) already covers this — same
  condition `check-deploy-freshness.sh` already names — by falling back to "unreachable, report
  instead" rather than assuming the field is always present.
- **Risk**: a consumer repo running the deploy engine on a *different machine* than where the
  agent later runs (e.g. a synced dotfiles checkout, or CI) would have a `source_dir` value valid
  only on the machine that ran the deploy. **Mitigation**: this is a pre-existing, orthogonal
  limitation of the whole extension system (the `core` config's `global_extensions_dir` default
  is always machine-local, `~/.config/nvim`), not something this task's narrower target-resolution
  fix introduces or worsens; the same fallback in point 3 handles it (path recorded but not
  present on disk on this machine -> report instead).
- **Risk**: implementers might be tempted to also change the deploy engine (option (b)) since it
  is "more precise." **Mitigation**: this report documents concretely why that is unnecessary
  extra machinery for equivalent precision; the plan phase should hold the line at a rule-text-only
  change unless new evidence emerges.

## Context Extension Recommendations

- **Topic**: how an agent (or human) resolves the absolute, machine-local source-store path from
  inside a deployed tree.
- **Gap**: no existing context file documents `.claude-extensions.json`'s `source_dir` field as a
  general-purpose resolution mechanism; it is currently known only to `check-deploy-freshness.sh`
  and the Lua deploy engine internals. `context/patterns/deploy-orphan-detection.md` and
  `context/patterns/regeneration-is-manual-only.md` are the closest existing neighbors but do not
  cover this specific field.
- **Recommendation**: consider a small `context/patterns/source-store-resolution.md` (or a
  subsection of one of the two files above) documenting the `.claude-extensions.json` ->
  `extensions.<name>.source_dir` -> absolute source-store path chain, so future rule/doc authors
  reuse it instead of re-hard-coding a path. Left as a recommendation, not created in this
  research pass — the plan phase can decide whether it belongs in this task or a follow-up.

## Appendix

### Search queries / commands used

- `grep -rn "gsub\|template\|placeholder" lua/neotex/plugins/ai/shared/extensions/{loader,init}.lua`
- `grep -n "source_dir\|extensions_dir\|repo_root\|stdpath" lua/neotex/plugins/ai/shared/extensions/*.lua`
- `python3 -c "import json; ..."` against `~/Projects/BimodalLogic/.claude-extensions.json`
- `cat ~/Projects/BimodalLogic/.claude/rules/source-store-deploy-boundary.md`
- `cat ~/Projects/BimodalLogic/.gitignore | grep -i claude`
- `git log --oneline --follow -- lua/neotex/plugins/ai/shared/extensions/state.lua`
- `jq -r '.entries[] | select(.path | test("deploy|source-store")) | .path' agent-system/extensions/core/index-entries.json`

### References

- `lua/neotex/plugins/ai/shared/extensions/config.lua:33-67`
- `lua/neotex/plugins/ai/shared/extensions/state.lua:113-170`
- `lua/neotex/plugins/ai/shared/extensions/loader.lua:54-82`
- `agent-system/extensions/core/scripts/deploy-headless.sh:294-345` (line_count auto-repair guard,
  illustrating the source-store-checkout-vs-consumer-tree distinction the deploy step already
  makes)
- `agent-system/extensions/core/scripts/check-deploy-freshness.sh:17-32`
- `specs/227_resolve_source_store_target_in_deployed_trees/reports/01_source-store-rule-has-no-target.md`
