# Research Report: Task #636

**Task**: 636 - Close sapience activation-surface scoping gaps: vendor user-level hooks, capture
  coupling, verifier and docs
**Started**: 2026-11-17T00:00:00Z
**Completed**: 2026-11-17T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: - Codebase (`agent-system/extensions/sapience/**`), live machine state
  (`~/.sapience/*.py`, `~/.sapience/config.json`, `~/.claude/settings.json`), cross-repo
  `.claude-extensions.json` reads under `~/Projects/*` and `~/.dotfiles`, prior research
  (`specs/637_make_sapience_extension_fully_functional/reports/01_*.md`, `02_*.md`)
**Artifacts**: - `specs/636_sapience_activation_surface_scoping_gaps/reports/01_activation-surface-scoping-gaps.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All five GOAL items are implementable from this repository alone, entirely inside
  `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`,
  `scripts/verify-sapience-context-scoping.sh`, `context/project/sapience/domain/
  injection-site-scoping.md`, and `context/project/sapience/domain/per-repo-scoping.md`. None
  requires a `~/.dotfiles` edit, and none duplicates tasks 627 or 628.
- The vendor mechanism behind GOAL (1) is fully traced: `~/.sapience/sapience_upkeep.py`'s
  `wire_hooks()` unconditionally re-adds the three hooks (`--briefing-text`, `--receipt`,
  `--effect-line`) to `$HOME/.claude/settings.json` on `auto_update`/`update --wire` unless
  `hooks_opted_out()` (`config.json`'s `"hooks"` key is `false`, or `SAPIENCE_NO_HOOKS=1`) is
  true. Detection is a direct re-implementation of that same two-part test, reading the live
  settings file and the opt-out flag independently.
- GOAL (2)'s capture-coupling asymmetry is reproducible today: `BimodalLogic` and
  `Sapience/sf1-engine` both show `extensions.sapience.status == "active"` while
  `~/.sapience/config.json`'s `capture.projects[]` lists the former `enabled: false` and omits
  the latter entirely. No path in the opposite direction (capture enabled, extension inactive)
  exists on this machine today, but the check must detect either direction, since GOAL (2)
  explicitly asks for both.
- GOAL (3)'s target state is directly observable: `~/Projects/abood`'s own
  `.claude-extensions.json` shows `extensions.sapience.merged_sections.settings` carrying only
  a `permissions` key and no `hooks` key at all, which is structurally distinguishable from a
  merged-but-wrong-count state (this repository's own `.claude-extensions.json` carries both
  `hooks` and `permissions` under the same path).
- GOAL (4) is a straightforward control-flow change to `verify-sapience-context-scoping.sh`:
  loop the existing two-call comparison N times, require unanimous agreement across all N
  outcomes, and report `INCONCLUSIVE` on any disagreement — stricter than a majority vote, which
  is what the measured evidence (1 `RESIDUAL_LIFTED`, 2 `RESIDUAL_HOLDS` in three runs) would
  need to turn into `INCONCLUSIVE` rather than a false majority verdict.
- GOAL (5)'s two target sections make a factually false claim each, now measured false by this
  task's own owner-performed remediation (hooks found in `$HOME/.claude/settings.json`, removed
  by hand) and by the live `capture.projects` cross-check above. Both rewrites are text-only and
  do not touch the surrounding sections this task does not name.
- A related, already-published research finding (task 637's second report) recommended
  appending a capture-stall diagnosis item (why `extracted.json` stopped advancing) to this
  task's own GOAL section. That recommendation has **not** been applied to task 636's live
  description — the dispatched GOAL list matches the original five items only. This report
  treats the five dispatched GOAL items as the scope of record and flags the unapplied
  recommendation under Risks & Mitigations rather than acting on it unilaterally.

## Context & Scope

This is the first research artifact for task 636. The task closes five named gaps in the
sapience extension's per-repo activation-surface verification and documentation, all sited
under the source store `agent-system/extensions/sapience/**` (resolved via this repository's
`.claude-extensions.json` `.extensions.sapience.source_dir`). `~/.dotfiles` is explicitly out of
bounds; a companion task exists there for any nix-side default. Tasks 627 (orphan MCP
registration reaper) and 628 (write-grant retraction) are related but distinct and are not
duplicated here.

Scope is bounded to the five dispatched GOAL items:

1. A `verify-sapience-mcp.sh` check for machine-wide vendor hooks in `$HOME/.claude/settings.json`.
2. A capture/activation coupling check, plus a ruling on whether reconciliation belongs in a
   hook/installer here or in `~/.dotfiles`.
3. A named "active but hook fragment never merged" failure in `verify-sapience-mcp.sh`.
4. An N-repeat, agreement-only verdict in `verify-sapience-context-scoping.sh`.
5. Rewrites of `injection-site-scoping.md`'s "No Machine-Wide Duplicate Hook Surface" section
   and `per-repo-scoping.md`'s population-3 text.

Out of scope, per the task description and per the prior task-637 scoping report: the
`abood` repair itself, the transcript-capture *stall* diagnosis (distinct from the
*coupling* check GOAL (2) asks for), and anything inside `~/.dotfiles`.

## Findings

### Codebase Patterns

**GOAL (1) — the vendor hook-recurrence mechanism, fully traced.**
`~/.sapience/sapience_upkeep.py` defines `hooks_opted_out(dest)` (line 72) as
`os.environ.get('SAPIENCE_NO_HOOKS') == '1' or _cfg(dest).get('hooks') is False` and
`wire_hooks()` (line 122) as an additive, idempotent writer that, whenever
`os.path.exists(mp)` (the vendor `mcp.py` client), unconditionally calls `add_hook()` three
times: `SessionStart` + `--briefing-text`, `SessionEnd` + `--receipt`, `Stop` + `--effect-line`
(lines 168-170). `wire_hooks()` itself contains no opt-out check — the check lives one level up,
in `update()` (`if hooks_opted_out(dest): ... else: res['hooks'] = wire_hooks(...)`) and in
`auto_update()`'s `hooks_missing = not hooks_opted_out(dest) and not hooks_ok(hooks_bits(...))`
gate, which is what the daily `--auto-update` cron-equivalent path and `sapience update --wire`
both reach. `REQUIRED = 'ebr'` (line 55) names exactly these three hooks as "what every install
writes without asking." This confirms the dispatch's measured evidence (a) is the full
mechanism, not a one-off: any machine whose `~/.sapience/config.json` does not carry
`"hooks": false` (and does not set `SAPIENCE_NO_HOOKS=1`) will have these three hooks re-added
to `$HOME/.claude/settings.json` by the next `auto_update`/`update --wire` pass, regardless of
which repositories load the sapience extension.

A **direct** detection re-implementation (reading `$HOME/.claude/settings.json`'s `.hooks.*`
arrays for a command containing `.sapience/mcp.py`/`.sapience/sapience_cli.py` plus one of the
three flag strings, and reading `~/.sapience/config.json`'s `.hooks` key) is both sufficient and
the only option available — there is no vendor-exposed API to query `hooks_opted_out()`
directly, and the two-part test (`SAPIENCE_NO_HOOKS` env, else `config.json.hooks`) is small
enough to re-derive safely rather than shell out to the vendor's own Python. `verify-sapience-
mcp.sh`'s existing check (d) already reads `$HOME/.claude/settings.json`'s `.hooks.SessionStart`
array with a near-identical `jq` idiom (`[.hooks.SessionStart[]?.hooks[]?.command // empty] |
any(. == $cmd)`), so the new check can follow that established pattern rather than invent a
new one, generalized to iterate `SessionStart`, `SessionEnd`, and `Stop` against the three
`REQUIRED`-equivalent flag strings.

**GOAL (2) — capture/activation coupling, confirmed live.** Cross-checking every
`path_prefix` in `~/.sapience/config.json`'s `capture.projects[]` against that path's own
`.claude-extensions.json` `.extensions.sapience.status`:

| Repository | `capture.projects[].enabled` | `extensions.sapience.status` |
|---|---|---|
| `~/.config/nvim` | `true` | `active` |
| `~/.dotfiles` | `true` | `active` |
| `~/Projects/abood` | `true` | `active` |
| `~/Projects/Sapience/sapience-app` | `true` | `active` |
| `~/Projects/BimodalLogic` | **`false`** | `active` |
| `~/Projects/Sapience/sf1-engine` | **(no entry at all)** | `active` |
| `~/Projects/Logos/{Vision,Theory,Verification}`, `~/Documents/Personal/Wedding`,
  `~/Philosophy/Papers/PossibleWorlds`, `~/Projects/PersonalWebsite`,
  `~/Documents/Employment/Applications` | `false` | *(no `.claude-extensions.json` /
  no sapience entry)* |

This reproduces the dispatch's measured evidence (b) exactly: `BimodalLogic` and
`sf1-engine` are active-extension, capture-disabled-or-absent — the direction GOAL (2) calls the
primary failure ("a capture-enabled path whose repository lacks the active extension" is the
named *failure*; this is its "informationally, the converse" companion — active extension,
capture not enabled). No repository on this machine today shows the reverse (capture enabled,
extension inactive), so the live data cannot exercise that branch, but the check must still be
built to catch it, since it is the branch GOAL (2) names as the actual failure condition (a
capture-enabled, extension-inactive repo is reading transcripts for a repository that never
opted into this extension's grants/hooks at all — a scope violation distinct from merely missing
functionality).

`verify-sapience-mcp.sh` is architecturally per-project (it resolves exactly one
`EXPECTED_PROJECT_PATH` per invocation, via `--project` or CWD/git-root detection), not a
machine-wide scanner. The natural fit for GOAL (2) is therefore a **new check scoped to that
same one project**: resolve `~/.sapience/config.json`'s `capture.projects[]` entry whose
`path_prefix` is a prefix of (or equal to) `EXPECTED_PROJECT_PATH` (the longest-prefix-wins rule
`~/.sapience/sapience_capture.py`'s own `for_cwd()` uses, mirrored rather than reinvented), read
its `enabled` field, and compare against `SAPIENCE_ACTIVE` (already computed by check (a)).
Four outcomes: active+enabled (fine, no line), active+not-enabled (informational line, not a
failure — this is the BimodalLogic/sf1-engine case), not-active+enabled (**the named failure** —
a capture-enabled path whose repository lacks the active extension), not-active+not-enabled
(fine, no line).

**The reconciliation-ownership sub-question GOAL (2) poses has a clear answer from this
research.** No script in `agent-system/extensions/sapience/**` writes or reads
`~/.sapience/config.json`'s `capture` key today — `setup-sapience-mcp.sh` only ever touches
`~/.claude.json`'s `.projects[...].mcpServers.sapience`, and
`hooks/sapience-mcp-register-project.sh` only ever invokes that writer. `capture.projects[]` is
a vendor-schema list (`sapience_capture.py`'s `project_entry()`/`normalize()`) that the
dispatch's own description notes "the dotfiles sapience module also manages a capture map" for
— i.e. `~/.dotfiles` already has its own writer for this same list, for its own nix-side
default. Building a second, independent writer here (in the `SessionStart` registration hook or
the installer) risks exactly the two-writer-converging-on-different-values hazard the existing
`per-repo-scoping.md` Hazards section already warns about for a different surface (the
`SessionStart` MCP-registration entry, where both writers are carefully kept byte-identical).
Unlike that case, there is no existing byte-identical-convergence guarantee between a
hypothetical writer here and `~/.dotfiles`'s own capture-map writer — building one risks the two
disagreeing on *whose* edit wins for a shared mutable list. **The lower-risk ruling available
from this research alone: stop at the verifier check (both directions) and record that active
reconciliation (writing `capture.projects[].enabled` to match extension-load state) belongs in
`~/.dotfiles`, if it is built at all** — consistent with the dispatch's own fallback instruction
("if reconciliation belongs in `~/.dotfiles`, record that and stop at the verifier check") and
with the Sapience Extension's own `rules/source-store-deploy-boundary.md` prohibition on this
source store writing files outside its own tree. This is a plan-phase ruling, not a
research-phase implementation decision, but the research strongly favors the "stop at the
verifier check" branch over building a second writer here.

**GOAL (3) — "active but hook fragment never merged" is structurally distinguishable from a
wrong-count merge.** `~/Projects/abood`'s own `.claude-extensions.json`:

```
extensions.sapience.status            == "active"
extensions.sapience.merged_sections.settings  == {"permissions": {...}}   # no "hooks" key at all
```

compared with this repository's own `.claude-extensions.json`:

```
extensions.sapience.status            == "active"
extensions.sapience.merged_sections.settings  == {"hooks": {...}, "permissions": {...}}
```

The absence of the `hooks` *key itself* (not merely a wrong grant/hook *count* under it) is the
signal check (3) should test for, and it is available from the same `EXTENSIONS_FILE` path
check (a) already reads — no new file read is needed. This is importantly different from
existing check (e), which inspects the *deployed* `.claude/settings.local.json`'s grant count
and hook-key set; `abood`'s own deployed `.claude/settings.local.json` is reported (task 637's
seed report, F1) to carry only 4 grants and 0 hook keys, which check (e) would currently report
as a generic "4/7 grants, hook keys []" failure — technically true but not actionable (it reads
like a partial/successful-but-incomplete merge, not "this repository's own ledger already knows
its merge predates the hooks fragment and was never re-run"). Check (3) should fire from the
*ledger's own record* (`merged_sections.settings` lacking a `hooks` key while `status ==
"active"`) and name the remedy explicitly ("reload/redeploy"), distinct from and in addition to
check (e)'s existing grant/hook-count failure on the same repository.

**GOAL (4) — N-repeat agreement, no existing precedent in this codebase to reuse verbatim.** No
`for i in $(seq ...)` / majority-vote pattern exists elsewhere in
`agent-system/extensions/*/scripts/*.sh` to borrow from; this is new control flow.
`verify-sapience-context-scoping.sh`'s existing single-run body (the `post_context` helper,
the inconclusive gate, and the final `RESIDUAL_HOLDS`/`RESIDUAL_LIFTED` comparison) is already
factored as a self-contained request/compare unit per the file's own session-id-uniqueness
comment ("session_id MUST be unique per invocation... $$ (this process's PID) plus the current
epoch second makes each run's pair of session_ids novel") — each repeat must mint its own fresh
pair of session ids, exactly as a single run does today, so the loop can call the existing
`post_context` helper N times without changing its signature. The dispatch's own wording
("reports a verdict only on agreement, otherwise 'inconclusive'") is **unanimous** agreement
across all N outcomes, not a majority: the measured evidence itself (1 `RESIDUAL_LIFTED`, 2
`RESIDUAL_HOLDS` in 3 consecutive runs) is precisely the disagreeing case this goal exists to
turn into `INCONCLUSIVE` rather than letting either outcome "win" on a tie-break or majority
basis. The script currently has no dedicated test file at all (`test-sapience-mcp-registration.sh`
covers only `verify-sapience-mcp.sh`'s checks 20-24); a new test suite exercising the N-repeat
logic would need the same `curl`-stub-on-`PATH` technique `test-sapience-capture.sh` already
uses for sequenced, call-indexed curl responses (its header already documents a
`CURL_STUB_CODE_1`/`_2` two-tier dispatch convention for exactly this kind of multi-call
sequencing).

**GOAL (5) — the two rewrite targets, read in full.**

`injection-site-scoping.md`'s "No Machine-Wide Duplicate Hook Surface" section currently
asserts: "The five Sapience hook entries ... are merged only into a loaded repository's own
`settings.local.json` ... never into `$HOME/.claude/settings.json`." This is now measured false
by this task's own evidence (a): three of those five hook *commands* (not the settings-fragment
merge mechanism itself, which the section's claim is really about) were found live in
`$HOME/.claude/settings.json`, written by a wholly separate mechanism (`sapience_upkeep.py`'s
`wire_hooks()`) the section does not mention at all. The section's own inspection commands
(`jq -r '.hooks.SessionStart' "$HOME/.claude/settings.json"`) would, at the time of the
measured evidence, have surfaced exactly the vendor-written entries the section claims cannot
exist there.

`per-repo-scoping.md`'s population-3 text ("Untagged and vendor-owned. Transcript extraction via
`~/.sapience/upload.py`. Its `_chunk()` sends `'project': m['project']` per chunk, so the repo
identity does reach the server, but the server-authored provenance drops it before the KO is
stored") is not itself false, but it omits the entire `capture.projects[].enabled` gating layer
this task's own evidence (b) centers on: a repository with the extension active and no
capture-map entry (or a disabled one) never reaches `upload.py`'s per-chunk `project` field at
all, because the opt-in gate (`sapience_capture.py`'s `captured(cwd, cfg)`: `"True when a
session at cwd is captured under this map ... An unknown cwd ('') is captured only under mode
'all'"`) short-circuits before extraction ever runs. The dispatch's own instruction — "capture
is a separate opt-in list" — is the omitted fact to add, not a correction to the existing
sentence about `upload.py`'s chunking.

### External Resources

Not applicable — this is a closed-corpus, codebase-internal and live-machine-state research
task. The only external material consulted is the vendor's own self-updating client under
`~/.sapience/` (`sapience_upkeep.py`, `sapience_capture.py`, `config.json`), which is read-only
reference material for this repository, not a documentation source this task edits.

## Decisions

- **Scope is the five dispatched GOAL items only.** Task 637's second research report
  recommended appending a capture-stall diagnosis item to this task's GOAL section, but that
  recommendation was not applied to task 636's live description (confirmed by reading the
  current `specs/TODO.md` entry for task 636, which matches the dispatch verbatim). This
  research does not unilaterally expand scope to cover the stall diagnosis; see Risks &
  Mitigations.
- **GOAL (2)'s reconciliation sub-question is answered in favor of "stop at the verifier
  check."** No existing writer in this source store touches `~/.sapience/config.json`'s
  `capture` key, a second independent writer here would create a two-writer-disagreement hazard
  this source store's own Hazards section already warns against for an analogous surface, and
  `~/.dotfiles` already owns a capture-map writer for its own nix-side default. Building active
  reconciliation here is not recommended; this is a ruling for the plan phase to formalize, not
  an implementation this research performs.
- **GOAL (3)'s detection key is the ledger's own `merged_sections.settings` missing-`hooks`-key
  state**, read from the same `EXTENSIONS_FILE` check (a) already opens, not a second read of
  the deployed `.claude/settings.local.json` that existing check (e) already covers. The two
  checks are complementary, not redundant: (3) names the ledger-recorded cause, (e) reports the
  deployed-file symptom.
- **GOAL (4)'s agreement rule is unanimous, not majority**, per the dispatch's own wording and
  per the measured evidence's own 1-vs-2 split, which is exactly the case this goal exists to
  turn into `INCONCLUSIVE`.

## Recommendations

1. **GOAL (1) implementation**: add a new lettered check to `verify-sapience-mcp.sh` (after
   check (f), or renumbered to keep the existing checks' documented letters stable — the plan
   phase should decide ordering) that reads `$HOME/.claude/settings.json`'s `.hooks.SessionStart`,
   `.hooks.SessionEnd`, and `.hooks.Stop` arrays for any command matching `.sapience/mcp.py` or
   `.sapience/sapience_cli.py` plus one of `--briefing-text`/`--receipt`/`--effect-line`, and
   separately reads `~/.sapience/config.json`'s `.hooks` key, reporting its value in all cases
   (pass or fail) per the dispatch's own "reports ... the hooks opt-out value" wording — this is
   an unconditional report, not a report-only-on-failure.
2. **GOAL (2) implementation**: add a check scoped to `EXPECTED_PROJECT_PATH` that resolves the
   longest-prefix-matching `capture.projects[]` entry from `~/.sapience/config.json`, and emits
   a `fail` only on (extension inactive) AND (capture enabled for a matching entry); emits an
   informational `log` line (not a `fail`) on (extension active) AND (capture not enabled or no
   matching entry). Record the plan-phase ruling (stop at the verifier check; reconciliation, if
   built, belongs in `~/.dotfiles`) directly in the plan artifact, mirroring this research's
   Decisions section.
3. **GOAL (3) implementation**: extend check (a)'s existing `EXTENSIONS_FILE` read to also test
   `.extensions.sapience.merged_sections.settings | has("hooks")` when `status == "active"`; on
   `false`, emit a distinctly worded `fail` ("active but hook fragment never merged — re-run the
   deploy/reload for this repository") rather than folding it into check (a)'s existing
   active/inactive pass/fail, and leave check (e)'s existing count-based failure unchanged (both
   checks may legitimately fail together on the same repository, for different reasons).
4. **GOAL (4) implementation**: wrap the existing single-comparison body of
   `verify-sapience-context-scoping.sh` in a loop of N iterations (a `--repeat N` flag with a
   sensible default, e.g. 3, matching the measured evidence's own run count), collecting each
   iteration's `RESIDUAL_HOLDS`/`RESIDUAL_LIFTED` outcome (treating any per-iteration
   `INCONCLUSIVE` as itself disqualifying agreement, not as a vote to discard), and emit the
   shared outcome only if all N iterations agree; otherwise print `INCONCLUSIVE` with a reason
   naming the disagreement. Add a dedicated test file (none exists today) reusing
   `test-sapience-capture.sh`'s curl-stub-on-`PATH` technique, extended to a sequenced,
   per-call-index response table for N calls rather than the existing two-tier convention.
5. **GOAL (5) implementation**: rewrite `injection-site-scoping.md`'s "No Machine-Wide Duplicate
   Hook Surface" section to state the measured mechanism (the vendor auto-updater re-adds the
   three `REQUIRED` hooks to `$HOME/.claude/settings.json` on every `auto_update`/`update --wire`
   pass unless `config.json`'s `"hooks"` key is `false` or `SAPIENCE_NO_HOOKS=1` is set), replace
   its now-false inspection-commands framing with a pointer to `verify-sapience-mcp.sh`'s new
   GOAL-(1) check, and keep the section's still-true claim (the settings-fragment-merged five
   hooks are per-repo-gated) clearly separated from the vendor-upkeep three-hook recurrence,
   since these are two independent mechanisms writing into the same file. Extend
   `per-repo-scoping.md`'s population-3 bullet with one added sentence naming
   `capture.projects[].enabled` as the opt-in gate that determines whether a given repository's
   sessions reach `upload.py`'s extraction at all, cross-referencing the new GOAL-(2) verifier
   check rather than restating its mechanics.
6. **Plan-phase file territory**: all five changes are confined to
   `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`,
   `scripts/verify-sapience-context-scoping.sh`,
   `context/project/sapience/domain/injection-site-scoping.md`,
   `context/project/sapience/domain/per-repo-scoping.md`, plus new/extended test files under
   `scripts/tests/`. No `agent-system/extensions/core/**` file is touched, so this task's file
   territory does not overlap sibling tasks 527 or 635's declared scopes.

## Risks & Mitigations

- **Risk**: GOAL (1)'s detection logic re-derives `hooks_opted_out()`'s two-part test
  independently of the vendor source, which is self-updating; a future vendor change to that
  function's logic (e.g. a third opt-out condition) would silently desync the local
  re-implementation from the real gating rule. **Mitigation**: comment the new check with the
  exact vendor file/line/function it mirrors (as this report does), so a future reader checking
  it against a newer `sapience_upkeep.py` can tell at a glance whether the mirror still matches.
- **Risk**: GOAL (2)'s capture-coupling check cannot be exercised against a live
  "capture-enabled, extension-inactive" fixture on this machine today (no such repository
  exists), so the plan phase's test coverage for that branch will necessarily use a synthetic
  fixture rather than a reproduction of a real failure. **Mitigation**: this is an ordinary and
  acceptable test-authoring pattern already used elsewhere in this extension's own test suite
  (e.g. `test-sapience-mcp-registration.sh`'s synthetic case fixtures); no special handling
  needed beyond noting it.
- **Risk**: the unapplied task-637 recommendation (append a capture-stall diagnosis item to this
  task's GOAL section) could resurface as scope creep during planning or implementation if a
  future reader conflates "capture coupling" (GOAL 2, in scope) with "capture stall" (why
  `extracted.json` stopped advancing — explicitly out of scope per the task-637 report).
  **Mitigation**: this report's Decisions section states the boundary explicitly; the plan
  phase should cite this report rather than re-deriving the distinction, and should not add the
  stall-diagnosis item without an explicit task-description update (which is the task-637
  report's own recommended path, not a plan-phase unilateral addition).
- **Risk**: GOAL (3)'s new check and existing check (e) can both fail on the same repository for
  related but distinct reasons (ledger-recorded non-merge vs. deployed-file count mismatch);
  a future maintainer could mistake this as redundant and remove one. **Mitigation**: the
  Findings section above documents why both are needed; the implementation should cross-
  reference each check's own inline comment to the other.

## Context Extension Recommendations

- **Topic**: EXTENSION.md's "Per-repo activation" framing.
- **Gap**: `EXTENSION.md`'s opening claim ("loading this extension into a repo is the ONLY thing
  that turns Sapience on there") is not literally true once GOAL (1)'s vendor-hook finding is
  accounted for — the three vendor-upkeep hooks fire regardless of any repository's extension
  state. `EXTENSION.md` is not named in this task's GOAL (5) rewrite targets, so this report
  does not recommend editing it now, but a future reader should know the claim is imprecise in
  this one respect.
- **Recommendation**: once GOAL (5)'s two rewrites land, consider a follow-up (new task, not
  this one) to soften `EXTENSION.md`'s opening sentence to scope it explicitly to the
  settings-fragment-merged five hooks and grants, distinguishing it from the vendor-upkeep
  three-hook mechanism the rewritten `injection-site-scoping.md` section will now describe.

## Appendix

### Search Queries / Commands Used

- `jq`/`python3 -c` reads of `.claude-extensions.json` (this repository and `~/Projects/abood`),
  `~/.claude.json`, `~/.claude/settings.json` (`.hooks` keys), `~/.sapience/config.json`
  (`capture.projects[]`, `hooks`)
- `grep -n` over `~/.sapience/sapience_upkeep.py` for `wire_hooks`, `hooks_opted_out`,
  `REQUIRED`, `auto_update`; `sed -n` reads of the matched line ranges
- `grep -n "capture"` over `~/.sapience/sapience_capture.py` and the sapience extension's own
  context files
- Cross-repo loop reading `.claude-extensions.json` `.extensions.sapience.status` for every
  `capture.projects[].path_prefix` entry
- `Read`/`cat` of `verify-sapience-mcp.sh`, `verify-sapience-context-scoping.sh`,
  `injection-site-scoping.md`, `per-repo-scoping.md`, `manifest.json`, `EXTENSION.md`,
  `install-sapience-mcp-session-hook.sh`, `test-sapience-mcp-registration.sh`,
  `test-sapience-capture.sh`
- `grep -rn "majority\|for i in \$(seq"` across `agent-system/extensions/*/scripts/*.sh`
  (no precedent found)
- `jq -r '.entries[] | select(.subdomain == "sapience") | .topics[]?'` on `.claude/context/index.json`

### References

- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`
- `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh`
- `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh`
- `agent-system/extensions/sapience/EXTENSION.md`
- `agent-system/extensions/sapience/manifest.json`
- `~/.sapience/sapience_upkeep.py`, `~/.sapience/sapience_capture.py`, `~/.sapience/config.json`
- `specs/637_make_sapience_extension_fully_functional/reports/01_seed-audit-findings.md`
- `specs/637_make_sapience_extension_fully_functional/reports/02_scoping-and-remaining-gaps.md`
