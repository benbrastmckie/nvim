# Pre-Change Baseline: Sapience Write-Tool Grant Retraction

Captured live during Phase 1 of the implementation. All five repositories were reachable;
no exclusions.

## Tracked-record jq path (children level included)

```
.extensions.sapience.merged_sections.settings.permissions.children.allow.items
```

All five repositories' `.claude-extensions.json` already carry the narrowed 7-item list at
this path — the tracked record is current. The bug is purely that `.claude/settings.local.json`
(the deployed file) has not been retracted to match.

## This repository's fragment (ground truth, 7 read-shaped grants)

```
mcp__sapience__sapience
mcp__sapience__sapience_search
mcp__sapience__sapience_briefing
mcp__sapience__sapience_context
mcp__sapience__sapience_ask
mcp__sapience__sapience_outstanding
mcp__sapience__sapience_papers
```

Set difference (deployed 11 minus fragment 7) = the four write tools that must disappear:
`mcp__sapience__sapience_adddoc`, `mcp__sapience__sapience_handoff`,
`mcp__sapience__sapience_remember`, `mcp__sapience__sapience_wrapup`.

## Per-repository baseline

| Repository | Grant count | hooks+permissions sha256 (settings.local.json) | hooks+permissions sha256 (settings.json) |
|---|---|---|---|
| `/home/benjamin/.dotfiles` | 11 | `01413b0371aa3fb62ec8333b1c11c99506e28742d1e0046ffcd37416b094746c` | `eddc4abc198942ec5e9cde2de353f168b9e4482f193d6cf29862eedbd6f1b60f` |
| `/home/benjamin/.config/nvim` | 11 | `c3c80236d744da03afdedb28d9fb65245b8b33af2906076bacc9a0df47c2246c` | `a9331bc6c81136cf7216dfd2c56181cad39ded3c5dab57312411e3fed29eeabf` |
| `/home/benjamin/Projects/BimodalLogic` | 11 | `ad4c0b54248b109574a277170801fd814523eee1aa8efff8da3e1b329329062a` | `946648096cfb701ee8b979a97cf92560521d2cc4e27127a3b9e4aea731373de7` |
| `/home/benjamin/Projects/Sapience/sf1-engine` | 11 | `b07345248c6775e0b5ae37bc90d183431c21f08481890fcfa4126b387e38b452` | `fde0c46cfbabb9c367ab2e5aa6fc4e587d76dca99c8ba5edc15fdc2fd9ef419b` |
| `/home/benjamin/Projects/Sapience/sapience-app` | 11 | `7ff2c92b892e1b25a055922995d8a822c4c707ee1452dc54e52b9359988c0735` | `b179f5cf1f8af6fbcd7b3c286e172d12e9dcf4593d17049d88964e08cc79384b` |

All five grant lists are identical (all 11 `mcp__sapience__*` tools, sorted):
`mcp__sapience__sapience`, `mcp__sapience__sapience_adddoc`, `mcp__sapience__sapience_ask`,
`mcp__sapience__sapience_briefing`, `mcp__sapience__sapience_context`,
`mcp__sapience__sapience_handoff`, `mcp__sapience__sapience_outstanding`,
`mcp__sapience__sapience_papers`, `mcp__sapience__sapience_remember`,
`mcp__sapience__sapience_search`, `mcp__sapience__sapience_wrapup`.

All five repositories' `.claude-extensions.json` tracked record already matches the narrow
7-item fragment at the `children.allow.items` path above — confirming the gap is entirely a
load-path retraction gap, not a stale fragment or a stale tracked record.

## Exclusions

None. All five repositories were present and readable at capture time.

<!-- Phase 5 appends post-change results and fingerprint-diff verdicts below this line. -->

## Post-Change Results (Phase 5)

Redeployed `agent-system/extensions/core/scripts/deploy-headless.sh` against this repository
first, then each of the four out-of-tree targets, in order, with `--skip-verify` (scoped
verification run separately per the Batch Gate Deferral directive, not the inline full
`verify-deploy.sh` pass). No `--wipe` was passed to any invocation.

| Repository | Grant count (after) | Write grants present | `settings.json {hooks,permissions}` sha256 | Delta vs. Phase 1 baseline |
|---|---|---|---|---|
| `/home/benjamin/.dotfiles` | 7 | 0 | `946648096cfb701ee8b979a97cf92560521d2cc4e27127a3b9e4aea731373de7` | **CHANGED** from baseline `eddc4abc198942ec5e9cde2de353f168b9e4482f193d6cf29862eedbd6f1b60f` -- see finding below |
| `/home/benjamin/.config/nvim` | 7 | 0 | `a9331bc6c81136cf7216dfd2c56181cad39ded3c5dab57312411e3fed29eeabf` | Unchanged (matches baseline exactly) |
| `/home/benjamin/Projects/BimodalLogic` | 7 | 0 | `946648096cfb701ee8b979a97cf92560521d2cc4e27127a3b9e4aea731373de7` | Unchanged (matches baseline exactly) |
| `/home/benjamin/Projects/Sapience/sf1-engine` | 7 | 0 | `b179f5cf1f8af6fbcd7b3c286e172d12e9dcf4593d17049d88964e08cc79384b` | **CHANGED** from baseline `fde0c46cfbabb9c367ab2e5aa6fc4e587d76dca99c8ba5edc15fdc2fd9ef419b` -- see finding below |
| `/home/benjamin/Projects/Sapience/sapience-app` | 7 | 0 | `b179f5cf1f8af6fbcd7b3c286e172d12e9dcf4593d17049d88964e08cc79384b` | Unchanged (matches baseline exactly) |

All five repositories' `settings.local.json` now report exactly the seven read-shaped sapience
grants (`mcp__sapience__sapience`, `_ask`, `_briefing`, `_context`, `_outstanding`, `_papers`,
`_search`, sorted) and zero of the four write tools. No `settings.json` delta involves a
sapience grant (`settings.json` carries 0 `mcp__sapience__*` grants in every repository, before
and after, confirmed in Phase 1).

### Finding: `settings.json` changed for 2 of 5 repositories beyond the sanctioned delta

`.dotfiles` and `sf1-engine` each show a `settings.json {hooks,permissions}` hash change, which
the Risk table's mitigation requires investigating before proceeding rather than ignoring.
Investigated directly (no raw pre-redeploy file content was captured in Phase 1, only a hash, so
a byte-level diff against the OLD content was not possible):

- Each changed repository's POST-redeploy `settings.json` is now byte-identical to a sibling
  repository that had ZERO drift (`.dotfiles` now matches `BimodalLogic`'s unchanged value;
  `sf1-engine` now matches `sapience-app`'s unchanged value) — strong evidence both were simply
  stale (not recently redeployed) and are now correctly caught up to the current source, rather
  than something being wrongly removed.
- Every hand-written, non-source-store hook command in both repositories (identified by
  filtering for a `command` that does not invoke a `.claude/hooks/*.sh` path) survives
  untouched: `.dotfiles` carries exactly one such custom hook, confirmed present after redeploy;
  `sf1-engine` carries none.
- This is consistent with, and expected from, this task's own Goals: `manager.load`'s
  forced-reload retraction block operates "uniformly across every `settings`/`mcp` key,
  permissions-only", so it also retracts and re-merges OTHER extensions' stale merge-target
  content on the same forced reload that fixes sapience's grants — not a sapience-specific
  side effect, and not a regression.

Recorded via `issue-record.sh` (class "unexpected measurement") rather than silently passed
over. **Process gap noted for a future task**: Phase 1's baseline capture should snapshot raw
file content, not only a hash, so a byte-level diff is always possible without this kind of
indirect reasoning.

### Fresh-load criterion

A sixth, never-loaded scratch deployed-tree-shaped fixture, force-loaded with the current
sapience extension, yields exactly the seven read-shaped grants (`mcp__sapience__sapience`,
`_ask`, `_briefing`, `_context`, `_outstanding`, `_papers`, `_search`) and none of the four write
tools — confirmed directly.

### Verification summary

- `bash .claude/scripts/verify-sapience-mcp.sh` (this repository): check (e) passes --
  "all 7 permission grants and all 5 hooks".
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  (the Batch Gate Deferral directive's scoped tier for this phase, re-run post-redeploy): PASS --
  3 check(s), 0 failure(s). Gate 3 (doc-lint content-drift) is now clear for every file this task
  edited in the source store, confirming the redeploy landed.
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh,test-deploy-propagation.sh`:
  2/2 pass, now against the DEPLOYED copies (post-redeploy), including the new Assertion G.
- The complete, untargeted `verify-deploy.sh` gate set is deferred to the batch-level pass per
  this dispatch's Batch Gate Deferral directive, not independently run a second time here.

### Exclusions

None. All five repositories were reachable and successfully redeployed.
