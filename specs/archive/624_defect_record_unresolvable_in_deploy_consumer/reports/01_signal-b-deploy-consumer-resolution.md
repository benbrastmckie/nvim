# Research Report: Task #624

**Task**: 624 - Defect record unresolvable in deploy consumer
**Started**: 2026-11-17T00:00:00Z
**Completed**: 2026-11-17T00:00:00Z
**Effort**: small
**Dependencies**: None (both declared dependencies are closed and settled adjacent, unrelated
questions — see Context & Scope)
**Sources/Inputs**: Codebase (`scripts/system-defect-record.sh`, `deploy-root-guard.sh`,
`context/patterns/system-defect-discrimination.md`, `rules/source-store-deploy-boundary.md` and
its narrative companion), live reproduction against a real deploy-consumer repository on this
machine
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is exactly as described and was reproduced live: invoking the deployed
  `system-defect-record.sh --dispatched-agent general-research-agent` from a genuine
  deploy-consumer repository (`/home/benjamin/Projects/cslib`, which carries only the regenerated
  `.claude/**` mirror plus `.claude-extensions.json`, no `agent-system/` tree at all) exits 3 with
  the documented "Signal B attribution unresolvable" message.
- Root cause: `scripts/system-defect-record.sh`'s `--dispatched-agent` resolution (around line
  233) globs `"$PROJECT_ROOT"/agent-system/extensions/*/agents/"${dispatched_agent_arg}.md"` —
  a path relative to the invoking repo's own filesystem root. That path exists only in the
  repository that physically holds the source store; a deploy consumer has no
  `agent-system/` directory on disk at all, so the glob can never match there, regardless of
  which agent name is passed.
- The fix this document recommends is the first candidate direction named in the task
  description: resolve through `.claude-extensions.json`'s per-extension `source_dir` field,
  exactly the procedure `rules/source-store-deploy-boundary.md`'s own resolution steps already
  prescribe for an edit target, and exactly what
  `context/patterns/system-defect-discrimination.md`'s Signal B section already cites that rule
  for — the discrimination document's own prose already promises this resolution path; the
  implementation simply never built it. This was verified mechanically: reading
  `/home/benjamin/Projects/cslib/.claude-extensions.json`'s `.extensions.core.source_dir` field
  resolves to `/home/benjamin/.config/nvim/agent-system/extensions/core`, an absolute path that
  exists on disk on this machine and under which `agents/general-research-agent.md` is present.
- The fix preserves the existing `resolved_path` shape (`agent-system/extensions/<ext>/agents/
  <name>.md`, repo-relative to the source-store-owning repository, never the consumer's own
  root) unchanged, because three downstream consumers depend on that exact shape staying stable
  across repositories: the recursion guard's `self_mod_match` comparison against
  `orchestrator-critical-paths.json`, the `defect_key` dedup identity
  (`${defect_class}:${resolved_path}`), and the `attributed_source_path` field persisted into
  `specs/events.jsonl`'s `detail` payload. Any fix that attributes to a differently-shaped path
  (a bare agent name, or the deployed `.claude/agents/<name>.md` path) would silently fork the
  dedup/recursion-guard key space between the source-store-holding repository and every deploy
  consumer for the same underlying agent file — a correctness regression, not merely a
  missed-attribution one.

## Context & Scope

**What was researched**: the mechanics of Signal B (`--dispatched-agent`) attribution
resolution inside `agent-system/extensions/core/scripts/system-defect-record.sh`, why it is
structurally unable to resolve in a deploy-consumer repository, and which of the task
description's three candidate directions is mechanically sound without destabilizing the
downstream consumers of the resolved path.

**Constraints**: the task's two declared dependencies (a postflight-suite assertion-repair task
and a seven-red-Gate-8-suite closure task) are both closed/completed and, per the task
description itself, settled adjacent questions (which defect class/attribution target applies to
a declined recovery; separating stall from agent fault) rather than this resolver's structural
inability to find an agent file outside the source-store repository. Confirmed during this
research: neither closed record's content bears on Signal B's deploy-consumer resolution gap,
so no further dependency-chain research was needed.

**Task siting check**: the edit target (`agent-system/extensions/core/scripts/
system-defect-record.sh`) is a source-store path per `rules/source-store-deploy-boundary.md`'s
Task Siting subsection. This repository (`/home/benjamin/.config/nvim`) is the repository whose
local filesystem actually contains that `source_dir` (confirmed: `.claude-extensions.json`'s
`.extensions.core.source_dir` resolves to `/home/benjamin/.config/nvim/agent-system/extensions/
core`, which exists on disk here). The task is correctly sited; no re-siting is needed.

## Findings

### Codebase Patterns

**The exact defect location.** `scripts/system-defect-record.sh`'s Signal B attribution block
(comment header at line 209) builds `resolved_path` two ways:
- From `--attributed-path`, via `transform_deploy_to_source()` (lines 211-226), a pure string
  transform with no filesystem I/O: `.claude/extensions/<ext>/X` -> `agent-system/extensions/
  <ext>/X`, and bare `.claude/X` -> `agent-system/extensions/core/X`. This path never touches
  disk and therefore has no deploy-consumer-reachability problem.
- From `--dispatched-agent`, via a glob at line 233:
  `agent_matches=("$PROJECT_ROOT"/agent-system/extensions/*/agents/"${dispatched_agent_arg}.md")`.
  `PROJECT_ROOT` is correctly computed as the invoking repository's own root (via
  `common_repo_root` plus `deploy-root-guard.sh`'s refusal-when-run-from-the-source-store check)
  — the bug is not in `PROJECT_ROOT` computation. The bug is that this glob assumes
  `$PROJECT_ROOT/agent-system/` exists, which is true only in the one repository that physically
  hosts the source store. A deploy consumer's `PROJECT_ROOT` is correct but has no
  `agent-system/` subtree at all.

**Live reproduction.** Ran, from `/home/benjamin/Projects/cslib` (confirmed deploy consumer: has
`.claude/scripts/system-defect-record.sh` and `.claude-extensions.json`, no `agent-system/`
directory):
```
bash .claude/scripts/system-defect-record.sh --defect-class RECOVERY_DECLINED \
  --detecting-site "research-repro-624" --message "repro test" \
  --dispatched-agent general-research-agent --session sess_0_repro624
```
Result: exit 3, stderr `[SYSTEM-DEFECT RECORDER] REFUSING: Signal B attribution unresolvable
(attributed-path='' dispatched-agent='general-research-agent' did not resolve to a path under
agent-system/extensions/**). Log only, no record.` — byte-identical in shape to the task
description's quoted message. `specs/events.jsonl` in that repository was confirmed unmodified
by this call (the two-line diff present there afterward predates this reproduction by several
months per its own embedded timestamps, and was not caused by this research).

**The downstream consumers of `resolved_path` that constrain the fix.** After Signal B
resolution, `resolved_path` feeds three further mechanisms, all of which assume the
source-store-relative shape `agent-system/extensions/<ext>/**`:
1. The recursion guard (`self_mod_match` against `orchestrator-critical-paths.json`'s
   `critical_paths[]` entries, which are themselves recorded in that same source-store-relative
   shape).
2. The dedup `defect_key` (`${defect_class}:${resolved_path}`), looked up against prior
   `system_defect` events already recorded in `specs/events.jsonl` under that shape.
3. The `attributed_source_path` field persisted into the event's `detail` payload, read back by
   the same dedup query on every future call.

Any fix must therefore produce the *same* `agent-system/extensions/<ext>/agents/<name>.md`
string a glob against the source store itself would have produced — not a differently-shaped
substitute — or it silently forks the dedup/recursion-guard key space per repository for what is
conceptually the same agent file.

**`.claude-extensions.json`'s `source_dir` already carries exactly the needed indirection, and
is reachable from a genuine deploy consumer.** Confirmed by reading three real deploy-consumer
repositories on this machine (`/home/benjamin/Projects/cslib`, `/home/benjamin/Projects/
ModelChecker`, `/home/benjamin/.dotfiles`): each one's own `.claude-extensions.json` records,
for every loaded extension, an absolute `source_dir` path back into
`/home/benjamin/.config/nvim/agent-system/extensions/<ext>` — the very directory this
repository's own `.claude-extensions.json` also points at for itself. This is the identical
mechanism `rules/source-store-deploy-boundary.md`'s "Correct Edit Target" resolution procedure
already names (steps 1-4: read `.claude-extensions.json`, select the extension entry, read
`source_dir`, confirm it exists on disk) and the identical mechanism
`context/patterns/system-defect-discrimination.md`'s Signal B section already cites that rule
document for, in its own prose ("a `.claude/{...}` path is always a deploy artifact of exactly
one source-store path ... see source-store-deploy-boundary.md"). Verified end-to-end for the
concrete case in the task description:
```
jq -r '.extensions.core.source_dir' /home/benjamin/Projects/cslib/.claude-extensions.json
# -> /home/benjamin/.config/nvim/agent-system/extensions/core   (exists on disk)
test -f /home/benjamin/.config/nvim/agent-system/extensions/core/agents/general-research-agent.md
# -> present
```
This resolves identically whether invoked from a true deploy consumer or from this
source-store-holding repository's own `.claude-extensions.json` (whose `core.source_dir` also
resolves to a local, existing path) — the same code path serves both cases without a branch on
"am I the source-store repo or a consumer."

**`deploy-root-guard.sh` already contains a structurally analogous precedent.** Its opt-in
`DEPLOY_ROOT_GUARD_SELF_CORRECT=1` path (used to recover `REPO_ROOT` when a script is
mistakenly invoked from inside the source store itself) accepts a candidate root on either of
two conditions, one of which is: the candidate holds a `.claude-extensions.json` whose
`.extensions.core.source_dir` resolves to an existing directory. That is a different problem
(correcting a wrong invocation root, not resolving an agent file across repositories) but the
same underlying indirection — the codebase already trusts `.claude-extensions.json`'s
`source_dir` field as the authoritative way to find the source store from a location that is
not it.

**No dedicated test coverage exists for this resolver today.** No `test-system-defect-record*.sh`
or similarly named suite exists under `agent-system/extensions/core/scripts/tests/`; other
suites reference `system-defect-record.sh` only incidentally (as a call site inside a larger
flow under test, e.g. `orchestrate-cycle-postflight.sh`'s own suite), not as a direct-unit
target of the Signal B resolution logic itself. This is a pre-existing coverage gap, not
something this research task changes, but it is the reason the deploy-consumer failure mode
went unnoticed until observed live in a real orchestration run.

**A structurally adjacent, out-of-scope risk worth flagging.** `transform_deploy_to_source()`
(the `--attributed-path` transform, lines 211-226) maps *every* bare `.claude/X` to
`agent-system/extensions/core/X`, unconditionally. `.claude/agents/` is deployed as a flat,
extension-agnostic merge (confirmed: `.claude/agents/lean-research-agent.md` exists alongside
`.claude/agents/general-research-agent.md` with no subdirectory distinguishing the owning
extension), so a hypothetical future `--attributed-path .claude/agents/lean-research-agent.md`
call would misattribute to `agent-system/extensions/core/agents/lean-research-agent.md` (wrong —
the real source is under `agent-system/extensions/lean/agents/`) rather than refusing loudly.
Today's actual `--attributed-path` call sites (enumerated by grep across
`agent-system/extensions/core/scripts/*.sh` and `hooks/*.sh`) never pass a `.claude/agents/**`
path — they pass orchestrator/skill-internal paths or `unresolved:` sentinels — so this is
latent, not currently triggered, and is a different defect class (a silent wrong-attribution
risk, not a refusal) from the one this task is scoped to. Noted here so a fix to the
`--dispatched-agent` path does not get conflated with, or asked to also cover, this separate
`--attributed-path` risk.

### External Resources

Not applicable — this is a self-contained shell-script/repository-layout defect with no external
dependency or library involved; all research was codebase- and live-filesystem-based.

## Recommendations

- **Primary fix (recommended)**: in the `--dispatched-agent` branch of Signal B resolution
  (`system-defect-record.sh` around line 230-237), before falling back to refusal, attempt
  resolution through `.claude-extensions.json`:
  1. If `"$PROJECT_ROOT/.claude-extensions.json"` exists and parses, iterate its
     `.extensions | to_entries[]` (key = extension name, `.value.source_dir` = absolute path).
  2. For each entry whose `source_dir` is non-empty and exists as a directory, test
     `"$source_dir/agents/${dispatched_agent_arg}.md"` for existence.
  3. On the first match (iteration order can mirror the existing nullglob
     first-match-wins semantics), set
     `resolved_path="agent-system/extensions/${ext_key}/agents/${dispatched_agent_arg}.md"` —
     the source-store-relative string, never the absolute `source_dir`-based path — so the
     recursion guard, dedup key, and persisted `attributed_source_path` are byte-identical to
     what the existing glob already produces when run from the source-store-holding repository
     itself.
  4. Keep the existing `"$PROJECT_ROOT"/agent-system/extensions/*/agents/"${dispatched_agent_arg}.md"`
     glob as a fallback, tried either before or after the `.claude-extensions.json` lookup (order
     is immaterial for correctness since both produce the identical resolved-path shape when
     both would match, which is exactly the source-store-holding-repo case) — this keeps the
     resolver working unchanged in any fixture or test harness that has no
     `.claude-extensions.json` at all but does have a literal `agent-system/` tree (e.g. a
     scratch test fixture built directly under a `PROJECT_ROOT/agent-system/extensions/...`
     layout).
  5. Only refuse with exit 3 if neither path resolves — the existing message and exit code are
     otherwise unchanged.

  This is a minimal, localized change (the `--dispatched-agent` branch only; the
  `--attributed-path` branch, the recursion guard, the dedup logic, and the event payload are
  untouched) and was re-derived and verified against the live corpus above, not merely proposed:
  the exact `.claude-extensions.json`-driven lookup was run by hand against
  `/home/benjamin/Projects/cslib` in this research pass and correctly resolved
  `general-research-agent` to `agent-system/extensions/core/agents/general-research-agent.md`.

- **Candidate direction 2 (accept a bare agent name when no source store is reachable) —
  rejected as the primary fix.** This would require `resolved_path` (or a parallel identity) to
  take on a second, differently-shaped form (`general-research-agent` rather than
  `agent-system/extensions/core/agents/general-research-agent.md`) purely for the
  deploy-consumer case, which forks the dedup/recursion-guard key space per the Findings section
  above: the same agent's defects would dedup separately depending on which repository happened
  to record them first. It also cannot discriminate which extension owns the agent name (two
  extensions could in principle ship same-named agents), where the `.claude-extensions.json`
  lookup in the primary fix resolves this for free by iterating actual `source_dir`s. Workable
  only as a last-resort fallback-of-the-fallback (attempted after both the primary fix and the
  existing glob fail) if the goal were "never refuse," but the task's own governing document
  (`system-defect-discrimination.md`) explicitly prefers refusal-with-logging over an
  unattributed record, so even that residual case should keep refusing rather than record under
  a non-conforming key shape.

- **Candidate direction 3 (record against the deployed `.claude/agents/NAME.md` path) —
  rejected.** `.claude/agents/` is a flat, extension-agnostic merge (confirmed above), so this
  path alone cannot discriminate which extension's source file truly owns the agent, and would
  additionally require relaxing the `case "$resolved_path" in agent-system/extensions/*)`
  acceptance gate (line ~237) to admit a `.claude/`-shaped string, which both breaks the
  recursion-guard match (whose `orchestrator-critical-paths.json` entries are all
  source-store-relative) and produces a second, incompatible key shape for the same dedup
  concern raised against direction 2.

- **Test-coverage recommendation (secondary, not required for the fix itself)**: add a small
  fixture-based test exercising the `--dispatched-agent` path against a scratch directory shaped
  like a genuine deploy consumer (a `.claude-extensions.json` with a `source_dir` pointing at a
  throwaway fixture `agents/` directory, and no `agent-system/` tree at all under the scratch
  root), asserting exit 0/resolved-path-correctness there, alongside the existing
  source-store-shaped case. This closes the coverage gap identified in Findings without which
  this exact regression could recur silently.

## Decisions

- The fix is scoped to `system-defect-record.sh`'s `--dispatched-agent` resolution branch only;
  `--attributed-path`'s `transform_deploy_to_source()` is explicitly left unchanged by this
  research's recommendation (see the flagged latent risk in Findings, which is a distinct defect
  class and out of this task's scope).
- The resolved-path output shape (`agent-system/extensions/<ext>/agents/<name>.md`,
  source-store-relative) must not change — this is a hard constraint derived from the three
  downstream consumers (recursion guard, dedup key, persisted detail payload), not a style
  preference.
- Candidate directions 2 and 3 named in the task description are both rejected as primary fixes,
  for the reasons in Recommendations; direction 1 is adopted.

## Risks & Mitigations

- **Risk**: an extension's `source_dir` recorded in `.claude-extensions.json` could point to a
  path that no longer exists on the current machine (a moved or deleted source-store checkout).
  **Mitigation**: the recommended fix already requires testing `-d "$source_dir"` before using
  it, matching the existing "confirm `source_dir` exists on disk" step in
  `rules/source-store-deploy-boundary.md`'s resolution procedure; a non-existent `source_dir`
  simply fails that entry and the loop proceeds to the next extension or to the existing glob
  fallback, never crashing.
- **Risk**: two loaded extensions could in principle ship an agent of the same bare name,
  making first-match-wins order-dependent. **Mitigation**: this is already true of the existing
  glob (`agent_matches[0]` wins under shell glob expansion order) — the recommended fix
  preserves, not introduces, this pre-existing (and in practice unexercised, since agent names
  are unique in the current manifest) ambiguity rather than creating a new one.
- **Risk (flagged, not mitigated by this task)**: `transform_deploy_to_source()`'s
  `--attributed-path` branch's core-only default for bare `.claude/*` paths is a latent
  misattribution risk for a non-core-owned deployed file under a flat merge directory (e.g.
  `.claude/agents/`). Not exercised by any current call site (verified by grep across all
  `--attributed-path` call sites); left unaddressed here as out of scope, but worth a dedicated
  follow-up task if a future call site ever passes a `.claude/agents/**` or similarly
  flat-merged path.

## Context Extension Recommendations

- **Topic**: deploy-consumer resolution pattern for source-store-relative identity strings.
- **Gap**: `rules/source-store-deploy-boundary.md`'s narrative companion documents the
  `.claude-extensions.json` → `source_dir` resolution procedure as an *edit-target* convention
  (where to write a change), but no context file documents the same procedure's second use —
  *resolving an identity/attribution string* (like Signal B's `agent-system/extensions/<ext>/**`
  paths) from a repository that does not itself hold the source store. This research treated
  that second use as a direct extension of the first, but a future script facing the same
  "I need a source-store-relative path, and I might be running in a deploy consumer" problem
  would benefit from this being named explicitly rather than re-derived per call site.
- **Recommendation**: if this fix lands, consider a short addendum to
  `rules/source-store-deploy-boundary.md`'s narrative companion (or a new, narrowly-scoped
  pattern file) naming this as a reusable technique: "resolving a source-store-relative identity
  string from any repository, not just the source-store-holding one, via
  `.claude-extensions.json`'s `source_dir`" — generalized beyond this one call site so the next
  script facing the same problem does not have to re-derive it from first principles.

## Appendix

- Commands run: `jq` queries against `.claude-extensions.json` in this repository and in
  `/home/benjamin/Projects/cslib`, `/home/benjamin/Projects/ModelChecker`,
  `/home/benjamin/.dotfiles`; a live invocation of
  `/home/benjamin/Projects/cslib/.claude/scripts/system-defect-record.sh --dispatched-agent
  general-research-agent --defect-class RECOVERY_DECLINED` (confirmed exit 3, no event
  written); `grep`/`sed` reads of `agent-system/extensions/core/scripts/system-defect-record.sh`,
  `agent-system/extensions/core/scripts/deploy-root-guard.sh`,
  `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`, and
  `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md`.
- References: `rules/source-store-deploy-boundary.md`,
  `context/standards/source-store-deploy-boundary-narrative.md`,
  `context/patterns/system-defect-discrimination.md` (Signal B section),
  `scripts/deploy-root-guard.sh` (the `DEPLOY_ROOT_GUARD_SELF_CORRECT` precedent).
