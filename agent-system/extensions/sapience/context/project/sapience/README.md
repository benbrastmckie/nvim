# Sapience Context Index

Navigation for the Sapience extension's domain notes. These files are reference material, read
on demand, never eager-loaded by a hook or an index `load_when` entry -- see
`index-entries.json`, which sets `on_demand: true` and an empty `load_when` on every entry here.

## Loading Strategy

| File | When to read it |
|------|------------------|
| `domain/vault-model.md` | Need to understand the hosted vault, the MCP thin client, or the local CLI's actual mode inventory |
| `domain/review-gate-boundary.md` | Need to understand what "staged" vs. "direct" means for a sapience write, or why the permission grant is scoped the way it is |
| `domain/transcript-filter-ceiling.md` | Need to understand why orchestrated/subagent work cannot reach the vault except by an explicit tool call |
| `domain/subagent-orientation.md` | Need the full refutation of the gap-3 context-injection-hook approach and the accepted per-dispatch retrieval injection |
| `domain/per-repo-scoping.md` | Need the repo-tag-filtered scoping mechanism, `sapience-retrieve.sh`/`sapience-remember.sh`'s contracts, the postflight-wrapup tagged-write call site's bound/dry-run/degrade rules, or the no-delete-API / unreviewed-write / two-population hazards |
| `domain/injection-site-scoping.md` | Need the three primary-session hook sites' exact transmit/honor behavior, the two measured foreclosures on `POST /v1/cli/context`, the label-never-suppress ruling, or the vendor-ask/machine-wide-duplicate owner actions |

None of these files is auto-loaded for any agent or command. Read one explicitly, or `grep`
across `context/project/sapience/` when a sapience-related question arises mid-task.
