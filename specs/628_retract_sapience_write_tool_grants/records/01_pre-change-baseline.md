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
