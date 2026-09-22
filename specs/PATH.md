# Implementation Path

*Rewritten 2026-09-22 (second pass, after `/todo`) as a forward-only plan: what remains, in what
order, and the checks that gate each step. Everything finished is gone from this file. The eight
survey passes (2026-09-02 to 2026-09-22), the 2026-09-17 consolidation manifest, the Stage A
thin-lead arc, phase 0's merge/repair pass and all of Batch A but one task live in this file's git
history; nothing from them is repeated here except the standing rules and the settled decisions at
the end.*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's. Both halves are met in shape and in measurement. What remains is making the
engine correct for the Lean and paper work that runs on it in the consumer repos, which is where
every new task this month was filed from.

## Where things stand (re-measured 2026-09-22, after `/todo`)

| Measure | Value | Bearing on the plan |
|---|---|---|
| Open tasks | **32** (29 after archival, +3 filed 2026-09-22: the budget task and two corpus-review tasks) | Batch A is down to its last task |
| Archived this pass | 12 (4 completed, 8 abandoned) | The phase-0 merges are now off the active list |
| Test suites | **91 passed, 1 failed, 92 total** (`run-all.sh`) | Was 89/89. The red is `test-verify-deploy-context-budget.sh`, downstream of the budget row below — not a second defect |
| `verify-deploy.sh --skip-slow` | **FAIL, 3 of 33** | Was PASS 33/33. Two failures are 245 in flight; the third is the context budget |
| `validate-state.sh` | 10 pass, 0 warnings, 0 failures | Clean |
| Dry run over all 29 | 20 admitted, 3 deferred, 0 blocked; `state.json` checksum unchanged | The three deferrals are ordering edges, not errors |
| `skills/skill-orchestrate/SKILL.md` | 19,535 B / ceiling 20,000 B | 465 B of headroom. Unchanged |
| `commands/orchestrate.md` | 20,228 B / ceiling 21,000 B | 772 B of headroom. Unchanged |
| Eager context load | **67,003 B / baseline 65,950 B — over by 1,053 B** | Now a failing gate, not a flat measure |
| Stranded session files in `specs/` root | **48 here** (was 25) | Growth has nearly doubled since 2026-09-08; 51 builds the reaper |
| Consumer deploys | **Every registered consumer STALE or CANNOTVERIFY**; core is 109 behind in `.dotfiles`/Theory, 150 in ModelChecker, 33 in PossibleWorlds, 25 in BimodalLogic | Redeploy before running batches anywhere |
| BimodalLogic `git stash list` | 52 entries (unchanged since 2026-09-22 first pass) | The snapshot-stash growth 199 is meant to end has not stopped |

**Where new tasks come from.** Not `errors.json` (19 entries, none newer than 2026-09-03, none
tied to an open task). They are filed by hand from defects hit live during `/orchestrate` runs in
Logos/Verification, BimodalLogic and PossibleWorlds, under standing rule 1.

**Every open task is accounted for below**: Before Batch B's 2 (245, 249) + Batch B's 11 +
Batch C's 14 + the picker lane's 3 + Batch D's 2 = 32. If that sum stops matching `state.json`,
this file has drifted.

---

## Before Batch B

The first two are new since the last pass: 245 in flight, and a context-budget breach that is
failing both `verify-deploy.sh` and one test suite. Do them in this order.

1. **Finish 245** (Phase 4 of 4, "Full gate run and consumer non-regression check"). Phases 1-3
   are committed. Its in-flight state is what makes `verify-deploy.sh` fail today:
   - `FAIL: deployed script content drift`: `scripts/orchestrate-batch-admit.sh` — source edited,
     `.claude/` not resynced.
   - `FAIL: script file on disk NOT in provides.scripts`:
     `scripts/tests/test-orchestrate-batch-admit.sh` — the new regression suite is unregistered.
   - The manifest-driven verification's 2 findings are the same two facts by a second route.

   Resync `.claude/` and register the test in `provides.scripts`; those three checks then clear.
   ```
   /orchestrate 245
   ```
2. **249 — the eager-context breach.** Now a task, not a hand step. 67,003 B against a
   65,950 B baseline (+1,053 B). This one fact is *both* remaining gate failures — the
   `verify-deploy.sh` eager-load FAIL and the single red suite,
   `test-verify-deploy-context-budget.sh` (confirmed 2026-09-22; its two internal failures are
   `baseline fixture is not clean` and `could not compute a safe eager-load pad amount
   (current_eager='67003', baseline_bytes='65950')`, both downstream of the breach). 245's own
   `test-orchestrate-batch-admit.sh` passes, so the red is not 245's.

   Cause is attributed to the byte: `rules/source-store-deploy-boundary.md` grew 2,746 → 4,443 B
   (+1,697) and `merge-sources/claudemd.md` +49 B, together the exact 65,257 → 67,003 delta. The
   task prefers trimming the rule to a lazy narrative over re-baselining, and aims for headroom
   because 139 and 224 both add eager bytes later.
   ```
   /orchestrate 249
   ```
3. `bash .claude/scripts/deploy-headless.sh` in each consumer before running anything there. Every
   registered consumer is STALE or CANNOTVERIFY, not just PossibleWorlds.
4. One `.gitignore` line for `agent-system/extensions/literature/scripts/literature-pyenv/`
   (240 MB, untracked, un-ignored since August; confirmed still un-ignored today).
5. In cslib's task list: abandon **595** (satisfied by `validate-state.sh` Check D3 once it
   redeploys) and **608** (its evidence is in 129) with pointers here. Both are still
   `not_started` there.

---

## Batch B — guards, contracts, the file_scope chain (11 tasks, three waves)

Serial where files are shared; the edges are declared, so one `/orchestrate` call sequences it.

| Wave | Task | What lands | After |
|---|---|---|---|
| 1 | **129** | Empirical `\b` word-boundary audit under the deployed grep; portable-construct guidance; the `\bsorry\b` double count in `lean-sorry-census.sh` | — |
| 1 | **166** | Required-section heading conformance: the research agent's skeleton and `validate-artifact.sh` agree lexically, not just semantically | — |
| 1 | **162** (researched → plan) | `**Files to modify**:` formalised in `plan-format.md`, harvested into `file_scope` at plan time by `plan-file-scope-harvest.sh`, wired into postflight, reconcile and `/revise`; backfill as the last phase | — |
| 1 | **163** | Absent, empty or glob `file_scope` made visible in `validate-state.sh` and the pre-dispatch review, instead of skipped by construction | — |
| 1 | **244** | `check-task-references.sh` scans roots appropriate to the repo it runs in, not a hard-coded list | — |
| 2 | **139** (+140) | History-rewrite prohibition (`--amend`, `reset` without `--hard`) in `git-workflow.md` and the implementation-agent contract; then a concurrency-gated predicate in `guard-destructive-git.sh` that does not consult tree dirtiness | 129 |
| 2 | **224** | `/please`: tamper-resistant single-use grant hook, `guard-git-push.sh`, grant checks in the destructive-git guard, the user-only command, rule exception and docs | 129 |
| 2 | **165** (+190) | Admission posture for an absent `file_scope` in `orchestrate-batch-admit.sh`; then cross-session visibility so two self-modifying candidates in separate sessions are not both admitted solo | 162, 163, 245 |
| 2 | **184** (ruled) | When the final handoff carries `skeleton=true` with a non-empty `sorry_inventory[]`, postflight reports the `follow_up_task` entries and records them append-only on the task; no auto-created tasks; `status-markers.md` and `handoff-schema.md` say how a skeleton plan terminates now | — (242, 243 now done) |
| 2 | **199** | Decide, then implement, whether concurrent same-repo dispatches share one working tree and `.lake` or each get an isolated one; a split verdict (worktrees for lean/cslib implement, shared tree plus hunk-scoped or refusing commits elsewhere) is acceptable if the selecting predicate is defined | — (242, 243 now done) |
| 3 | **136** | Plan-level `Status` field ownership in the implementation-agent contract and the validator; fan-out prohibition; marker/commit sync | 139, 166 |

```
/orchestrate 129, 166, 162, 163, 244, 139, 224, 165, 184, 199, 136
```

184 and 199 were gated on 242/243, which are now complete — both are free to run in wave 2 with
no remaining predecessor. 199 is the largest open decision; if it stalls, pull it out and run it
alone with `--hard`.

---

## Batch C — extension content, cheap closes, cost and clutter (14 tasks)

| Order | Task | What lands | Note |
|---|---|---|---|
| 1 | **223** (researched → plan) | Comparator-on-NixOS fixes in the lean extension's `comparator-integration.md`, `comparator-guide.md`, `lean-comparator-run.sh` and its test | Cheapest close in the backlog |
| 1 | **177** | Lean 4 dependency-tracing recipe (why `#print axioms` cannot answer "does X depend on Y") in the lean4 extension context | Doc only |
| 1 | **167** (+74, 75, 76) | vimtex continuous-build safety always-in-effect via the latex extension's existing rule; the shared guard script and lifecycle wiring are later phases, built only if the rule proves insufficient | Rule first, then decide |
| 1 | **207** (+208) | `zotero-generate-export.sh` Path 1: the jq-argv accumulator truncation and a shrink guard; then explain the 481-item pagination stop or change the path-preference order | Data loss today |
| 1 | **39** (planned → implement) | Zotero metadata resolution for web-discovered sources, the MCP question, quota-gated auto-attach, the Zotero 10 backend-swap note | Plan exists since August |
| 1 | **43** | The email extension's five safety context pointers actually load | Live defect, extension-internal |
| 1 | **241** | Drop the two redundant playwright grant lists and five dead `mcp_servers` manifest fields; correct `mcp-server-ownership.md` and the nix README; keep memory's `mcpServers` block for 29 | Re-verify the user-scope grant count is 9 first. Dry run defers this behind 29 |
| 2 | **51** | Session runtime files out of the `specs/` root and the reap path actually running (`reap-session-runtime-files.sh`, `task-lock.sh`, `/todo`) | **48 stranded here now, up from 25.** Also the designated self-modifying candidate the dry run orders 245 behind |
| 2 | **217** | `/refresh` idle Lean LSP tree reclamation with PSS accounting and CPU-delta idleness; prompt, never a silent kill | |
| 2 | **89** | Mode-gate the seven sections of `skill-literature/SKILL.md` (84 KB) and `skill-distill` so one mode's bash loads per invocation | Bears on the eager-context breach |
| 2 | **44** (planned) | Slim `commands/task.md` (37 KB per `/task` call) by moving reference material into lazily loaded files | 210 is done; unblocked. Bears on the eager-context breach |
| 2 | **185** | Retarget the ~120 remaining "Stage N" / "Stage MT-N" citations to the Move 1-4 vocabulary | Mechanical |
| 2 | **127** | Collapse the four-block routing ladder to `routing_agents`; resolve present's colon-suffixed compound values; prune lean/cslib `routing_hard` keys | Manifest rewrite |
| 3 | **170** | Isolate shell test suites from ambient host state (memory and timing axes); record the convention in `shell-script-testing.md`. Research must name the specific suites and add them to `file_scope` before implement | Last; after 51 and 129. May absorb the red-suite finding from "Before Batch B" |

```
/orchestrate 223, 177, 167, 207, 39, 43, 241
/orchestrate 51, 217, 89, 44, 185, 127, 170
```

---

## Lane — nvim picker Lua (3 tasks, whenever)

These edit `lua/neotex/plugins/ai/**`, not the agent system, and do not feed the loop.

| Order | Task | What lands |
|---|---|---|
| 1 | **22** | Silence the ~60-notification opencode fragment validation spam on `<leader>al` reload under the frozen-mirror policy; fix the one fake-tool line; record the policy |
| 2 | **45** (+202) | Picker: the Global Update action updates the extension-repo registry; `[Reload All]` / `[Regenerate]` get honest descriptions and Command Details previews; rule on their redundancy |
| 3 | **29** (+30) | A `merge_targets.mcp` deploy path that writes the repository-root `.mcp.json` from loaded extensions; then register obsidian-memory through it with empirically enumerated tool grants |

```
/orchestrate 22, 45, 29
```

29 is no longer gated on 210 (complete). The dry run defers 29 behind 22 on
`lua/neotex/plugins/ai/shared/extensions/merge.lua`, and 241 behind 29 on
`agent-system/extensions/memory/manifest.json` — both are ordering edges the batch engine
resolves in sequence, so the call above is correct as written.

---

## Batch D — systematic corpus review (2 tasks, gated behind B and C)

Both exist because task intake here is defect-driven: it surfaces only what *broke*. Complexity
and dead weight break nothing, so they are invisible to the filing process by construction. Each
task is deliberately shaped as **build a mechanical probe, then act on its ranked output** — a
"review everything" pass that emits prose and no diff is the analysis-paralysis failure mode the
hard-mode contract (H2) already names.

| Task | What lands | After |
|---|---|---|
| **250** | A standing script-inventory probe (lines, inbound callers, test coverage, cross-script duplicate blocks, `provides.scripts` drift), registered beside `assess-repo-health.sh`; then a behaviour-preserving decomposition of `orchestrate-cycle-plan.sh` into `lib/`, gated on byte-identical `--dry-run` output | 199, 245 |
| **251** | A context-reachability probe that understands all three reference styles — filename, **directory**, `index.json` — plus eager/lazy classification reusing `measure-eager-context.sh`'s channel model; then telemetry cross-check and removal of what is genuinely dead | 249, 44, 127 |

Measured 2026-09-22: 182 non-test scripts / 63,740 lines; the orchestrate engine is 8,207 lines
across 14 scripts, of which `orchestrate-cycle-plan.sh` alone is **2,279 — 27.8% of the engine and
6.5× its family's 351-line median**, in a tree that already has 14 extracted libs totalling 2,564
lines. The context corpus is 523 files / 3.6 MB.

**There are zero confirmed dead context files.** A naive basename check flagged 16; all 16 are
present-extension slide templates referenced by *directory* (`talk/contents/title/`). The finding
is that the check was inadequate and no adequate one exists — not that anything should be deleted.
251 carries those 16 as its regression fixture: a correct probe reports all of them reachable.

```
/orchestrate 250
/orchestrate 251
```

---

## Checks before and after every batch

- `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>`
  — **space-separated task numbers, not comma-separated**; admits what you expect, and
  `md5sum specs/state.json` unchanged across the call.
- `bash .claude/scripts/validate-state.sh` — 0 failures, 0 warnings (the current baseline).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — green. **Do not pipe it through
  `tail`/`head`**: that masks its exit code and truncates the failing suite's inline output, which
  is how a red run read as green on 2026-09-22.
- `bash .claude/scripts/verify-deploy.sh --skip-slow` — PASS, and both engine files under their
  ceilings. A self-modifying task is not finished until `.claude/` is resynced.
- After any batch that ran in a consumer repo: `bash .claude/scripts/check-consumer-freshness.sh`
  here, and `deploy-headless.sh` there if STALE.

---

## Settled decisions (do not re-litigate)

1. **Batch of one.** One engine; single-task is a batch of one. Team mode is deleted. Hard mode
   is kept in full and is per-invocation.
2. **The orchestrator never asks and never decides.** Only an agent-surfaced `user_decision`
   reaches the user, once, at cycle end.
3. **Research-first is the default** for a fresh task; `--fast` restores planner-first. The
   planner's `needs_research` return path survives either way.
4. **`--dry-run` prints the plan it would dispatch.** There is no separate dry-run report.
5. **No fixed consumer validation gates.** The checks above are recommended, not blocking.
6. **A linear chain of small tasks that serialize on one file is one task with phases.** Applied
   twice (2026-09-17, 2026-09-22); apply it at creation time from here on.
7. **No analysis surface over `file_scope`** until the field is reliably populated (162, 163).
8. **Rule before mechanism** for the vimtex hazard: 167's later phases are conditional on the
   rule proving insufficient.
9. **Skeleton plans terminate through the completion-claim gate**; only the sorry-inventory
   follow-up report is ported (184). No `pr_ready` routing outside `type=pr`.

## Standing rules (carried forward)

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on
   reload.
2. **Propose, then apply, across repos.**
3. **Verify by execution, not by reading.** Every number in this file was measured the day it was
   written; re-measure before acting on it.
4. **The lead never reads a report, plan, summary, description, or context file during the
   loop.** This is a byte budget with a gate (`verify-deploy.sh`), not a paragraph.

## Unfiled observations (still open, none worth a task yet)

- `test-verify-deploy-context-budget.sh` does not finish inside 240 s when run alone, so it cannot
  be used as a quick local check while iterating on the budget. Worth a timing fix if step 2 of
  "Before Batch B" turns into real work; 170 is the task that would own it.
- The runtime wave-split check (`orchestrate-cycle-plan.sh` step 4.5) defers a cross-batch scope
  collision on every run and records nothing. Persisting that deferral as a `dependencies[]` edge
  is a one-line `state-write.sh` call, after 165 rules on absent scope.
- The write-time task-reference hook fires on files in the session scratchpad (it blocked a
  throwaway jq filter on 2026-09-22). Its path filter could exempt `/tmp/**`.
- `specs/archive/state.json` now holds 188 completed and 41 abandoned entries. Completed tasks'
  final state before this pass is recoverable from git history and summaries only.
