# Implementation Path

*Rewritten 2026-09-22 as a forward-only plan: what remains, in what order, and the checks that
gate each step. Everything finished is gone from this file. The eight survey passes (2026-09-02 to
2026-09-22), the 2026-09-17 consolidation manifest, the Stage A thin-lead arc and the design
narrative live in this file's git history; nothing from them is repeated here except the standing
rules and the settled decisions at the end. Phase 0 of the eighth pass was applied to
`state.json` the same day (see "Before Batch A").*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's. Both halves are met in shape and in measurement. What remains is making the
engine correct for the Lean and paper work that runs on it in the consumer repos, which is where
every new task this month was filed from.

## Where things stand (measured 2026-09-22)

| Measure | Value | Bearing on the plan |
|---|---|---|
| Open tasks | **33** (41 before phase 0; 8 merged into siblings) | Five are live defects filed from one consumer-repo run; they go first |
| Truly blocked | 10 wait on another open task; 23 dispatch now | Ordering is priority, not dependency, except inside Batch B |
| Test suites | 89 / 89 green (`run-all.sh`, core + loaded extensions) | Nothing red to fix before dispatching |
| `verify-deploy.sh --skip-slow` | PASS, 33 / 33 | Deploy is sound |
| Dry run over all 33 | 23 admitted, 0 deferred, 0 blocked; `state.json` checksum unchanged | Every scope collision now has an explicit edge |
| `skills/skill-orchestrate/SKILL.md` | 19,535 B / ceiling 20,000 B | **465 B of headroom.** Batch A edits the engine's neighbours; watch this gate |
| `commands/orchestrate.md` | 20,228 B / ceiling 21,000 B | 772 B of headroom |
| Eager context load | 65,257 B (~16.3k tokens) / baseline 65,950 B | Flat; not a constraint |
| Stranded session files in `specs/` roots | 25 here, 36 BimodalLogic, 45 Verification, 0 Theory | 51 builds the reaper; a manual sweep is optional until then |
| Consumer deploys | PossibleWorlds core STALE (13 files), lean STALE (9); Logos/Hardware typst CANNOTVERIFY | Redeploy in those repos before running batches there |
| BimodalLogic `git stash list` | 52 entries (44 on 2026-09-09) | The snapshot-stash growth 199 is meant to end has not stopped |

**Where new tasks come from.** Not `errors.json` (19 entries, none newer than 2026-09-03, none
tied to an open task). They are filed by hand from defects hit live during `/orchestrate` runs in
Logos/Verification, BimodalLogic and PossibleWorlds, under standing rule 1. Closing the five in
Batch A is how the inflow slows.

---

## Before Batch A

Done 2026-09-22 (phase 0), recorded here only because the abandoned entries are still visible
until `/todo` runs:

- Merged, no work lost: 74, 75, 76 → **167** (rule first, guard mechanism conditional); 30 → **29**;
  208 → **207**; 140 → **139**; 190 → **165**; 202 → **45**. Each survivor carries the absorbed text
  under an `=== ABSORBED 2026-09-22 ===` header, the unioned `file_scope`, and a new title.
- 22 repaired from an orphaned `researching` (no directory, no artifacts) to `not_started`.
- 170's three whole-directory scope entries removed; 184 ruled and rescoped to one concrete
  change; 241's nine-file scope filled; 163 gains the glob-entry addendum.
- Ordering edges added for every shared file: 224←129, 139←129, 199←242/243, 165←245, 184←242/243,
  29←210, 170←51/129, 45←22. `validate-state.sh`: 10 pass, 0 warnings, 0 failures.

Still to do by hand, in this order:

1. `/todo` — archives the 8 abandoned entries (30, 74, 75, 76, 140, 190, 202, 208). Then re-run the
   dry run once (standing rule 3).
2. `bash .claude/scripts/deploy-headless.sh` in PossibleWorlds (core and lean are stale there).
3. One `.gitignore` line for `agent-system/extensions/literature/scripts/literature-pyenv/`
   (240 MB, untracked, un-ignored since August).
4. In cslib's task list: abandon 595 (satisfied by `validate-state.sh` Check D3 once it redeploys)
   and 608 (its evidence is in 129) with pointers here.

---

## Batch A — live defects from consumer-repo runs (5 tasks, disjoint scopes)

Each of these cost a Verification or BimodalLogic run cycles or a hand intervention in September.
All are unblocked; the dry run admits all five with no deferral once 29 is not in the batch.

| Task | What lands | Files |
|---|---|---|
| **242** | A `partial` handoff with a populated `blocker[]` stops re-dispatch: postflight persists `[PARTIAL]`/`[BLOCKED]` with the blocker text instead of mapping to `defer` and re-hitting the same wall until MAX_CYCLES | `orchestrate-cycle-postflight.sh`, `orchestrate-cycle-plan.sh`, its test, `general-implementation-agent.md` |
| **243** | One rule for whether a research dispatch writes `.orchestrator-handoff.json`; agent contract, `handoff-schema.md` and the dispatch template agree; extension research agents swept | `general-research-agent.md`, `handoff-schema.md`, `orchestrate-build-dispatch.sh` |
| **245** | In-batch deferral computed against the tasks actually admitted this cycle, greedy by number, deterministic; regression test for the A-admitted / C-deferred-on-A / D-deferred-on-C chain | `orchestrate-batch-admit.sh`, its test |
| **227** | The source-store boundary rule states a repository-relative target, so it is followable in consumer repos instead of sending agents into `.claude/` | `rules/source-store-deploy-boundary.md` (+ the deploy step chosen) |
| **210** | `/task` create: topic set after the state write, topic registered in `active_topics`, picker valid with fewer than two topics, task-type keyword false positives | `commands/task.md`, `extension-development.md`, `topic-assignment-pattern.md`, `literature/manifest.json` |

```
/orchestrate 242, 243, 245, 227, 210
```

Gate after Batch A: `SKILL.md` and `commands/orchestrate.md` under their ceilings
(`verify-deploy.sh --skip-slow` prints both); `run-all.sh` green; dry run over the remainder clean.

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
| 2 | **184** (ruled) | When the final handoff carries `skeleton=true` with a non-empty `sorry_inventory[]`, postflight reports the `follow_up_task` entries and records them append-only on the task; no auto-created tasks; `status-markers.md` and `handoff-schema.md` say how a skeleton plan terminates now | 242, 243 |
| 2 | **199** | Decide, then implement, whether concurrent same-repo dispatches share one working tree and `.lake` or each get an isolated one; a split verdict (worktrees for lean/cslib implement, shared tree plus hunk-scoped or refusing commits elsewhere) is acceptable if the selecting predicate is defined | 242, 243 |
| 3 | **136** | Plan-level `Status` field ownership in the implementation-agent contract and the validator; fan-out prohibition; marker/commit sync | 139, 166 |

```
/orchestrate 129, 166, 162, 163, 244, 139, 224, 165, 184, 199, 136
```

199 is the largest open decision. If it stalls, pull it out and run it alone with `--hard`.

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
| 1 | **241** | Drop the two redundant playwright grant lists and five dead `mcp_servers` manifest fields; correct `mcp-server-ownership.md` and the nix README; keep memory's `mcpServers` block for 29 | Re-verify the user-scope grant count is 9 first |
| 2 | **51** | Session runtime files out of the `specs/` root and the reap path actually running (`reap-session-runtime-files.sh`, `task-lock.sh`, `/todo`) | Three repos are accumulating them |
| 2 | **217** | `/refresh` idle Lean LSP tree reclamation with PSS accounting and CPU-delta idleness; prompt, never a silent kill | |
| 2 | **89** | Mode-gate the seven sections of `skill-literature/SKILL.md` (84 KB) and `skill-distill` so one mode's bash loads per invocation | |
| 2 | **44** (planned) | Slim `commands/task.md` (37 KB per `/task` call) by moving reference material into lazily loaded files | After 210 |
| 2 | **185** | Retarget the ~120 remaining "Stage N" / "Stage MT-N" citations to the Move 1-4 vocabulary | Mechanical |
| 2 | **127** | Collapse the four-block routing ladder to `routing_agents`; resolve present's colon-suffixed compound values; prune lean/cslib `routing_hard` keys | Manifest rewrite |
| 3 | **170** | Isolate shell test suites from ambient host state (memory and timing axes); record the convention in `shell-script-testing.md`. Research must name the specific suites and add them to `file_scope` before implement | Last; after 51 and 129 |

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

29 waits on 210 (shared `extension-development.md`); run it after Batch A.

---

## Checks before and after every batch

- `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>`
  — admits what you expect, 0 blocked, and `md5sum specs/state.json` unchanged across the call.
- `bash .claude/scripts/validate-state.sh` — 0 failures, 0 warnings (the current baseline).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — green.
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
   twice now (2026-09-17, 2026-09-22); apply it at creation time from here on.
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

- The runtime wave-split check (`orchestrate-cycle-plan.sh` step 4.5) defers a cross-batch scope
  collision on every run and records nothing. Persisting that deferral as a `dependencies[]` edge
  is a one-line `state-write.sh` call, after 165 rules on absent scope.
- The write-time task-reference hook fires on files in the session scratchpad (it blocked a
  throwaway jq filter on 2026-09-22). Its path filter could exempt `/tmp/**`.
- `/todo` has archived 181 directories; `specs/archive/state.json` holds only the 33 abandoned
  entries, so completed tasks' final state is recoverable from git history and summaries only.

*Uncommitted: `specs/state.json`, `specs/TODO.md`, `specs/events.jsonl` and this file carry the
phase-0 changes.*
