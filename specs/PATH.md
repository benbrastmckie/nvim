# Implementation Path

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`.
Last rewritten 2026-09-22 (third pass).*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision
is genuinely the user's. Both halves are met in shape and in measurement. What remains is making
the engine correct for the Lean and paper work that runs on it in the consumer repos — which is
where every new task this month was filed from.

## Where things stand (measured 2026-09-22, third pass)

| Measure | Value | Bearing |
|---|---|---|
| Open tasks | **31** | 252 is new; 245 and 249 closed this pass |
| `verify-deploy.sh --skip-slow` | **PASS, 33/33** | Was FAIL 3/33. All three causes cleared |
| Eager context load | **64,148 B / baseline 65,950** | Was over by 1,053. Now **1,802 B of headroom** (249) |
| `validate-state.sh` | 10 pass, 0 warnings, 0 failures | Clean |
| `skills/skill-orchestrate/SKILL.md` | 19,535 B / ceiling 20,000 | 465 B headroom |
| `commands/orchestrate.md` | 20,228 B / ceiling 21,000 | 772 B headroom |
| `run-all.sh` | **No clean baseline.** Last full run was under concurrent load: 90/92, ~40 min | Re-measure on an idle machine before trusting it. See 250 |
| Stranded session files in `specs/` root | **52** (was 48, was 25 on 2026-09-08) | Still growing; 51 builds the reaper |
| Consumer deploys | **Every registered consumer STALE or CANNOTVERIFY** | Redeploy before running batches anywhere |
| BimodalLogic `git stash list` | 52 entries | The snapshot-stash growth 199 is meant to end has not stopped |

**Where new tasks come from.** Not `errors.json` (19 entries, none newer than 2026-09-03, none
tied to an open task). They are filed by hand from defects hit live during `/orchestrate` runs in
Logos/Verification, BimodalLogic and PossibleWorlds, under standing rule 1.

**Every open task is accounted for below**: 252 + Batch B's 11 + Batch C's 14 + the picker
lane's 3 + Batch D's 2 = 31. If that sum stops matching `state.json`, this file has drifted.

---

## Do first

1. **252 — the batch engine cannot complete a source-store edit.** This gates everything below.
   `update-task-status.sh` refuses postflight with exit 6 when `modified_files` overlap
   `agent-system/extensions/**` and `.claude/` is stale. The sanctioned recovery exists only in
   `command-gate-out.sh` (the retired single-task path); `orchestrate-cycle-postflight.sh` has no
   exit-6 handler, and the refusal aborts before `cycle_modified_files` accumulates — which also
   disarms the inter-cycle redeploy checkpoint that would otherwise catch it. The loop then
   re-dispatches `implement` against a complete plan until `MAX_CYCLES`.

   Every task in Batches B, C and D edits the source store, so every one of them hits this.
   Observed live on 2026-09-22; 249 needed a manual deploy plus a manual
   `reconcile-task-status.sh` replay to reach `completed`.
   ```
   /orchestrate 252
   ```
2. `bash .claude/scripts/deploy-headless.sh` **in each consumer** before running anything there.
   This repo never pushes into a consumer.
3. In cslib's task list: abandon **595** (satisfied by `validate-state.sh` Check D3 once it
   redeploys) and **608** (its evidence is in 129), with pointers here. Both still `not_started`.

---

## Batch B — guards, contracts, the file_scope chain (11 tasks, three waves)

Serial where files are shared; the edges are declared, so one `/orchestrate` call sequences it.

| Wave | Task | What lands | After |
|---|---|---|---|
| 1 | **129** | Empirical `\b` word-boundary audit under the deployed grep; portable-construct guidance; the `\bsorry\b` double count in `lean-sorry-census.sh` | — |
| 1 | **166** | Required-section heading conformance: the research agent's skeleton and `validate-artifact.sh` agree lexically, not just semantically | — |
| 1 | **162** (researched) | `**Files to modify**:` formalised in `plan-format.md`, harvested into `file_scope` at plan time, wired into postflight, reconcile and `/revise`; backfill last | — |
| 1 | **163** | Absent, empty or glob `file_scope` made visible in `validate-state.sh` and the pre-dispatch review | — |
| 1 | **244** | `check-task-references.sh` scans roots appropriate to the repo it runs in | — |
| 2 | **139** (+140) | History-rewrite prohibition in `git-workflow.md` and the implementation-agent contract; then a concurrency-gated predicate in `guard-destructive-git.sh` that does not consult tree dirtiness | 129 |
| 2 | **224** | `/please`: single-use grant hook, `guard-git-push.sh`, grant checks in the destructive-git guard, user-only command, rule exception, docs | 129 |
| 2 | **165** (+190) | Admission posture for an absent `file_scope`; then cross-session visibility so two self-modifying candidates in separate sessions are not both admitted solo | 162, 163 |
| 2 | **184** | Skeleton handoff with a non-empty `sorry_inventory[]` reports `follow_up_task` entries append-only; no auto-created tasks | — |
| 2 | **199** | Decide, then implement, whether concurrent same-repo dispatches share one working tree and `.lake` or each get an isolated one. A split verdict is acceptable if the selecting predicate is defined | — |
| 3 | **136** | Plan-level `Status` ownership in the implementation-agent contract and the validator; fan-out prohibition; marker/commit sync | 139, 166 |

```
/orchestrate 129, 166, 162, 163, 244, 139, 224, 165, 184, 199, 136
```

199 is the largest open decision; if it stalls, pull it out and run it alone with `--hard`.

---

## Batch C — extension content, cheap closes, cost and clutter (14 tasks)

| Order | Task | What lands | Note |
|---|---|---|---|
| 1 | **223** (researched) | Comparator-on-NixOS fixes in the lean extension | Cheapest close in the backlog |
| 1 | **177** | Lean 4 dependency-tracing recipe (why `#print axioms` cannot answer "does X depend on Y") | Doc only |
| 1 | **167** (+74, 75, 76) | vimtex continuous-build safety via the latex extension's existing rule; guard script and lifecycle wiring only if the rule proves insufficient | Rule first |
| 1 | **207** (+208) | `zotero-generate-export.sh` Path 1: jq-argv accumulator truncation and a shrink guard; then the 481-item pagination stop | Data loss today |
| 1 | **39** (planned) | Zotero metadata resolution for web-discovered sources; quota-gated auto-attach; Zotero 10 backend-swap note | Plan exists since August |
| 1 | **43** | The email extension's five safety context pointers actually load | Live defect |
| 1 | **241** | Drop two redundant playwright grant lists and five dead `mcp_servers` fields; correct `mcp-server-ownership.md` and the nix README | Re-verify the user-scope grant count is 9 first. Deferred behind 29 |
| 2 | **51** | Session runtime files out of the `specs/` root and the reap path actually running | **52 stranded now.** Also the designated self-modifying candidate |
| 2 | **217** | `/refresh` idle Lean LSP tree reclamation, PSS accounting, CPU-delta idleness; prompt, never a silent kill | |
| 2 | **89** | Mode-gate the seven sections of `skill-literature/SKILL.md` (84 KB) and `skill-distill` | Protects the eager-context headroom |
| 2 | **44** (planned) | Slim `commands/task.md` (37 KB per `/task` call) into lazily loaded files | Protects the eager-context headroom |
| 2 | **185** | Retarget the ~120 remaining "Stage N" / "Stage MT-N" citations to Move 1-4 vocabulary | Mechanical |
| 2 | **127** | Collapse the four-block routing ladder to `routing_agents`; resolve present's compound values; prune lean/cslib `routing_hard` keys | Manifest rewrite |
| 3 | **170** | Isolate shell test suites from ambient host state (memory and timing axes); record the convention. Research must name the specific suites and add them to `file_scope` before implement | Last; after 51 and 129 |

```
/orchestrate 223, 177, 167, 207, 39, 43, 241
/orchestrate 51, 217, 89, 44, 185, 127, 170
```

**170's premise has changed.** Its notes say Instance A (`test-lake-build-guard.sh`) is already
fixed. On 2026-09-22 that suite failed inside a loaded full run and then passed 47/47 in
isolation, same commit, same machine — the same fails-loaded/passes-isolated shape recorded for
Instance B. The 878043472 fix isolated the *memory* axis only; the suite is not load-independent.
First step is identifying which case fails under load, since the full-suite output does not name
it.

---

## Lane — nvim picker Lua (3 tasks, whenever)

These edit `lua/neotex/plugins/ai/**`, not the agent system, and do not feed the loop.

| Order | Task | What lands |
|---|---|---|
| 1 | **22** | Silence the ~60-notification opencode fragment validation spam on `<leader>al` reload; fix the one fake-tool line; record the frozen-mirror policy |
| 2 | **45** (+202) | Picker: Global Update updates the extension-repo registry; `[Reload All]` / `[Regenerate]` get honest descriptions and previews |
| 3 | **29** (+30) | A `merge_targets.mcp` deploy path writing the repository-root `.mcp.json`; then register obsidian-memory through it |

```
/orchestrate 22, 45, 29
```

29 defers behind 22 on `merge.lua`, and 241 behind 29 on memory's `manifest.json` — ordering
edges the batch engine resolves in sequence, so the call above is correct as written.

---

## Batch D — systematic corpus review (2 tasks, gated behind B and C)

Both exist because task intake here is defect-driven: it surfaces only what *broke*. Complexity
and dead weight break nothing, so they are invisible to the filing process by construction. Each
is shaped as **build a mechanical probe, then act on its ranked output** — a "review everything"
pass that emits prose and no diff is the analysis-paralysis failure mode H2 already names.

| Task | What lands | After |
|---|---|---|
| **250** | A standing script-inventory probe beside `assess-repo-health.sh`; then cut `run-all.sh`'s runtime; then a behaviour-preserving decomposition of `orchestrate-cycle-plan.sh` into `lib/`, gated on byte-identical `--dry-run` output | 199, 252 |
| **251** | A context-reachability probe understanding all three reference styles — filename, **directory**, `index.json` — plus eager/lazy classification; then telemetry cross-check and removal of what is genuinely dead | 44, 127 |

**Scale (measured 2026-09-22):** 182 non-test scripts / 63,740 lines. The orchestrate engine is
8,207 lines across 14 scripts, of which `orchestrate-cycle-plan.sh` alone is **2,279 — 27.8% of
the engine, 6.5× its family's 351-line median**, in a tree that already has 14 extracted libs
totalling 2,564 lines. The context corpus is 523 files / 3.6 MB.

**There are zero confirmed dead context files.** A naive basename check flagged 16; all 16 are
present-extension slide templates referenced by *directory*. The finding is that the check was
inadequate and no adequate one exists — not that anything should be deleted. 251 carries those 16
as its regression fixture: a correct probe reports all of them reachable.

**The `run-all.sh` long pole (profiled 2026-09-22 on an idle machine):** 92 suites, 557 s serial.
`test-verify-deploy-context-budget.sh` alone was **329 s — 59% of the run**; top 5 = 76%; 56 of 92
finish under 1 s. Cause: it `rsync`s the whole 17 MB `extensions/` tree as its fixture (a
*correct* choice — a minimal fixture makes gates 3-13 SKIP into vacuity), then runs
`verify-deploy.sh` over that mirror several times at ~55 s each. Highest-leverage fix:
`verify-deploy.sh` has **no gate selector**, so that suite asserts on gate 20 alone but pays for
~19 others.

**Fix the long pole before parallelising.** While one suite is 329 s, even infinite parallelism
caps at a 41% gain. Order: gate selector → re-measure → per-suite output files (the shared
`SUITE_OUT` mktemp at `run-all.sh:145` is the structural blocker) → `--jobs` → selective
execution. **`--jobs` ships opt-in, serial by default:** 170 documents suites whose wall-clock
assertions break under load, parallelism increases exactly that contention, and 170 depends on
250 — so flipping the default is 170's call. A fast flaky gate is worse than a slow honest one.

```
/orchestrate 250
/orchestrate 251
```

---

## Checks before and after every batch

- `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>`
  — **space-separated task numbers, not comma-separated**; admits what you expect, and
  `md5sum specs/state.json` unchanged across the call.
- `bash .claude/scripts/validate-state.sh` — 0 failures, 0 warnings.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — green, **on an idle machine**.
  Do not pipe it through `tail`/`head`: that masks its exit code and truncates the failing suite's
  inline output, which is how a red run read as green on 2026-09-22.
- `bash .claude/scripts/verify-deploy.sh --skip-slow` — PASS, and both engine files under their
  ceilings. A self-modifying task is not finished until `.claude/` is resynced.
- After any batch that ran in a consumer: `check-consumer-freshness.sh` here, `deploy-headless.sh`
  there if STALE.

---

## Settled decisions (do not re-litigate)

1. **Batch of one.** One engine; single-task is a batch of one. Team mode is deleted. Hard mode is
   kept in full and is per-invocation.
2. **The orchestrator never asks and never decides.** Only an agent-surfaced `user_decision`
   reaches the user, once, at cycle end.
3. **Research-first is the default** for a fresh task; `--fast` restores planner-first. The
   planner's `needs_research` return path survives either way.
4. **`--dry-run` prints the plan it would dispatch.** There is no separate dry-run report.
5. **No fixed consumer validation gates.** The checks above are recommended, not blocking.
6. **A linear chain of small tasks that serialize on one file is one task with phases.** Applied
   twice; apply it at creation time from here on.
7. **No analysis surface over `file_scope`** until the field is reliably populated (162, 163).
8. **Rule before mechanism** for the vimtex hazard: 167's later phases are conditional.
9. **Skeleton plans terminate through the completion-claim gate**; only the sorry-inventory
   follow-up report is ported (184). No `pr_ready` routing outside `type=pr`.

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on
   reload.
2. **Propose, then apply, across repos.**
3. **Verify by execution, not by reading.** Every number here was measured the day it was written;
   re-measure before acting on it.
4. **The lead never reads a report, plan, summary, description, or context file during the loop.**
   This is a byte budget with a gate, not a paragraph.

## Unfiled observations (none worth a task yet)

- `test-verify-deploy-context-budget.sh` does not finish inside 240 s alone, so it cannot serve as
  a quick local check while iterating on the budget. 250's gate selector is the fix.
- The runtime wave-split check (`orchestrate-cycle-plan.sh` step 4.5) defers a cross-batch scope
  collision on every run and records nothing. Persisting it as a `dependencies[]` edge is a
  one-line `state-write.sh` call, after 165 rules on absent scope.
- The write-time task-reference hook fires on files in the session scratchpad. Its path filter
  could exempt `/tmp/**`.
- A subagent parked on genuinely slow background work emits repeated interim notifications that
  read like stalling. Notification semantics, not agent behaviour — do not "fix" it by telling
  agents to run long gates in the foreground.
- `specs/archive/state.json` holds 188 completed and 41 abandoned entries.
