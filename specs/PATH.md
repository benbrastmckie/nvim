# Implementation Path

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`.
Last rewritten 2026-09-29 (seventh pass).*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's. Both halves are met in shape and in measurement. The engine-convergence lane
that dominated the last two passes is **closed**: the deploy-pending / identical-dispatch
composition defect, the git-safety contracts, and the `file_scope` chain all landed. What remains
splits into three lanes: **cut per-invocation cost and clutter** now that the engine is quiet,
**finish the orchestrator's own operational surface** (queue, liveness, conclusion stage), and
**correct the consumer repos**, which have drifted STALE behind this pass's source-store changes.

## Where things stand (measured 2026-09-29, seventh pass)

| Measure | Value | Bearing |
|---|---|---|
| Open tasks | **28** | Archive holds 190 completed, 48 abandoned, 18 orphan, 1 expanded |
| `validate-state.sh --deep` | 0 failures, **3 warnings** | New: 163's Check 10/11 is live and firing — 268 has no `file_scope`, 270's is coarse enough to overlap 17 tasks. Fix both at creation, not later |
| `verify-deploy.sh --skip-slow` | **PASS, 33 of 33** | Working tree clean at rewrite time |
| Eager context load | 65,949 B / baseline 65,950 | **1 B headroom** — was 1,802 B last pass. Any eager addition now fails the gate; offset before adding |
| `skills/skill-orchestrate/SKILL.md` | 19,983 B / ceiling 20,000 | **17 B headroom** — 263's relay text must be offset |
| `commands/orchestrate.md` | 20,228 B / ceiling 21,000 | 772 B headroom |
| Redeploy checkpoint cost | full-depth verify ×2–3 per fire; Gate 8 ≈ 9 of 11 min | See call A (265) |
| Stranded session files in `specs/` root | **72** (39 multi-state, 32 return-meta-multi, 1 meta-return) | Was 67; grows every run. 51 builds the reaper trigger |
| Consumer deploys | **7 of 11 repos carry a STALE extension** | `core` is 44 behind in .dotfiles, ModelChecker, PersonalWebsite, Hardware, PossibleWorlds; `literature` 9 behind in three; `typst` 1 and `lean` 1 in several. Only BimodalLogic is fully FRESH. This pass's nine completed tasks caused it — redeploy in each repo before running a batch there |

**`MAX_TASKS` is 8**, enforced in `commands/orchestrate.md` (the command truncates to the first 8
with a warning); `orchestrate-cycle-plan.sh` itself accepts any count, so a dry-run over more than
8 is not evidence a call will run them.

**Every open task is accounted for below**: A 8 + B 8 + C 4 + D 8 = 28. If that sum stops
matching `state.json`, this file has drifted.

---

## Next

Call A. The dry-run (2026-09-29) admits all 8 at cycle 0 with nothing deferred and nothing
blocked, and leaves `state.json` unchanged. The engine-convergence work that previously gated
263, 165, 136 and 265 has all landed, so nothing is outstanding before it.

The one thing worth doing first is unrelated to the batch: **the consumer repos are STALE.** If
the next work touches a consumer, run `deploy-headless.sh` there before dispatching into it.

---

## Call A — push consent, admission posture, contracts, checkpoint cost (8)

```
/orchestrate 263, 165, 136, 265, 51, 223, 255, 241
```

| Task | What lands | Note |
|---|---|---|
| **263** (+224, 264) | One grant token; `/please` mint hook with integrity; push guard; grant check in the destructive-git guard; user-only command, never-list, rule exception; dispatch relay + two-cycle non-replay test | 139's predicate landed, so the gate is clear. Offset any SKILL.md growth byte-for-byte — 17 B headroom |
| **165** (+190) | Admission posture for an absent `file_scope`; cross-session visibility for self-modifying candidates | 162 and 163 landed; gate clear. 268's missing key is a live specimen to design against |
| **136** (+166, 14) | Plan-level `Status` ownership and grammar; fan-out prohibition; marker/commit sync; research-report heading conformance | 139 landed; gate clear |
| **265** (+267) | Gate 8 via `run-all.sh --jobs` (conservative default + env override); inline verify in `deploy-headless.sh` narrowed or opt-out | 266 landed; gate clear. Biggest per-checkpoint saving available |
| **51** | Session runtime files out of the `specs/` root; reaper widened and wired into `/todo` | 72 stranded now, and it gates 272 and 275 in call D |
| **223** (+177) (researched) | Comparator-on-NixOS fixes; Lean 4 dependency-tracing recipe | Plan dispatch first |
| **255** | typst scope statement matches what it ships; `chapter-quality-check.sh` Rule 1.3 bib resolution | Deployed to 5 repos, `typst` currently 1 behind in four of them |
| **241** | Drop two playwright grant lists and five dead `mcp_servers` fields; fix ownership doc and nix README | Re-verify the user-scope grant count is 9 first |

Dry-run 2026-09-29: all 8 admit at cycle 0 (223 at `plan`, the rest at `research`); 0 deferred,
0 blocked, `state.json` md5 unchanged. Implement-phase serialization: 51 → 165 → 265 → 263
(self-modifying, lowest first).

## Call B — cost, clutter, corpus probe (8)

```
/orchestrate 250, 89, 44, 127, 217, 39, 185, 184
```

| Task | What lands | Note |
|---|---|---|
| **250** | Script-inventory probe (reuse 261's timing baseline); decompose `orchestrate-cycle-plan.sh` into `lib/`, byte-identical `--dry-run` | 199 and 266 landed; wait on 265 (call A) so the file is quiet |
| **89** | Mode-gate `skill-literature` (84 KB) and `skill-distill` (93 KB) | ~24.8k tokens per invocation |
| **44** (planned) | Slim `commands/task.md` (41 KB per `/task`) into lazy context files | Implement dispatch first. Also fix its abandon-mode text (see observations) |
| **127** | Collapse the routing ladder to the two agent blocks; retire `command-route-skill.sh`; lint nonexistent agent targets | Clears the gate16 WARN |
| **217** (+218, 219) | `/refresh` PSS accounting, CPU-delta idleness, prompt-never-kill | Utility, not engine |
| **39** (planned) | Zotero metadata resolution; MCP decision; quota gate; Zotero 10 swap plan | Needs the dotfiles translation-server |
| **185** | Retarget live "Stage N" / "Stage MT-N" citations to Move vocabulary; keep historical ones | 266 and 199 landed; still after 184. Research adds the rest of the 72 files to scope |
| **184** | Skeleton-plan `sorry_inventory` follow-ups reported append-only at completion | 266 landed; gate clear. Gates 273 in call D |

## Call C — reachability, test isolation, picker lane (4)

```
/orchestrate 251, 170, 22, 29
```

| Task | What lands | Note |
|---|---|---|
| **251** | Context-reachability probe (filename, directory, `index.json`) with the 16 present templates as the fixture; telemetry cross-check; remove what is genuinely dead | After 44, 127. With 1 B of eager headroom, anything this frees is directly useful |
| **170** | Isolate shell suites from ambient host state (memory and timing axes); record the convention; repeated-run acceptance under load | Last: after 51, 250, 251 |
| **22** (+45) | Silence opencode fragment spam; fix the fake-tool line; record the frozen-mirror policy; honest `[Reload All]`/`[Regenerate]`; Global Update registry | Lua, not agent-system |
| **29** (+30) | `merge_targets.mcp` → repository-root `.mcp.json`; register obsidian-memory through it | After 22, 241 |

## Call D — orchestrator queue, liveness, conclusion stage; build-guard and null-safety (8)

```
/orchestrate 268, 269, 270, 271, 272, 273, 274, 275
```

Filed after the sixth pass; **this is a lane, not a runnable batch of 8.** Dry-run 2026-09-29
admits only 268 and 269 at cycle 0 — the other six chain behind 269, 51 (call A), 184 (call B)
and 165 (call A). Run calls A and B first, or dispatch the front pair on their own.

| Task | What lands | Note |
|---|---|---|
| **268** | Reproduce-first on the `lake-build-guard.sh` false green: the `scope_key` sharing condition that would prevent the replay is already implemented and predates the observation, so determine which of the candidate causes actually holds | No deps; admits now. **Has no `file_scope`** — declare one before dispatch |
| **269** | `validate-state.sh --fix`: presence test → type test, so a null `file_scope` cannot abort the repair | No deps; admits now. Gates 270 and 271 |
| **270** | Re-runnable null-safety audit of jq mutation sites across core scripts; rule on a shared guard idiom in `scripts/lib/` | After 269. **`file_scope` is coarse** (`.../core/scripts/`, overlapping 17 tasks) — narrow it or it will serialize against most of the backlog |
| **271** | Finish the `parent_task` edge: declare in schema, validate, render in TODO, survive renumbering | After 269. Gates 273 |
| **272** | Honest session liveness for concurrent same-repo batches: diagnose why the wired heartbeat never fires, add a live-but-stale lock state, re-derive registry scope, give each orchestration its own identity | After 51 (call A) |
| **273** | Three-channel orchestration conclusion stage with per-channel approval, as a distinct post-postflight stage | After 271 and 184 (call B) |
| **275** | Per-repo orchestration queue: registered, live, archived on finish, consumed by admission | After 272 and 51 |
| **274** | Next-admissible-batch suggestion and alternatives-on-conflict, both computed by invoking the real admission script | Tail of everything: after 272, 273, 275, 165. Once it lands, this file's call groupings become computable rather than hand-maintained |

---

## Checks before and after every call

- `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>`
  — **space-separated**; admits what you expect, `md5sum specs/state.json` unchanged. Research and
  plan dispatches are exempt from the self-modifying defer (`--phase-map`), so overlap only
  serializes at implement time.
- `bash .claude/scripts/validate-state.sh --deep` — 0 failures. Three `file_scope` warnings are
  expected today (268, 270); treat any *new* warning as real.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — green, on an idle machine, exit
  code read directly (never through `tail`/`head`). `--jobs 4` is opt-in and reproduces the
  serial pass/fail set except under heavy contention (261's finding).
- `bash .claude/scripts/verify-deploy.sh --skip-slow` — PASS (33 of 33 on 2026-09-29), and
  both engine files under their ceilings. A self-modifying task is not finished until `.claude/`
  is resynced.
- After any call that ran in a consumer: `check-consumer-freshness.sh` here, `deploy-headless.sh`
  there if STALE. **Seven of eleven consumer repos are STALE right now.**

---

## Settled decisions (do not re-litigate)

1. **Batch of one.** One engine; single-task is a batch of one. Team mode is deleted. Hard mode is
   kept in full and is per-invocation.
2. **The orchestrator never asks and never decides.** Only an agent-surfaced `user_decision` reaches
   the user, once, at cycle end.
3. **Research-first is the default** for a fresh task; `--fast` restores planner-first.
4. **`--dry-run` prints the plan it would dispatch.** There is no separate dry-run report.
5. **No fixed consumer validation gates.** The checks above are recommended, not blocking.
6. **A linear chain of small tasks that serialize on one file is one task with phases.** Applied
   six more times in the sixth pass; apply it at creation time.
7. **No analysis surface over `file_scope` until the field is reliably populated.** 162 and 163
   landed, so the field is now harvested at plan postflight and its absence is visible — the
   condition is met. Build the surface in 165, and treat the two live warnings (268, 270) as the
   first real input rather than noise to suppress.
8. **Rule before mechanism** for the vimtex hazard. 167 shipped the rule; the mechanism tasks
   (74–76) stayed abandoned rather than conditional. Re-file only if the rule proves insufficient.
9. **Skeleton plans terminate through the completion-claim gate**; only the sorry-inventory
   follow-up report is ported (184). No `pr_ready` routing outside `type=pr`.
10. **No third automated deploy-trigger site.** The batch postflight defers its redeploy to the
    Inter-Cycle Redeploy Checkpoint. The sanctioned count stays at exactly two.
11. **One grant mechanism.** A push (or any otherwise-blocked git action) is authorized by one
    single-use token bound to action, remote, branch and sha, minted only where the harness can
    prove the user typed it. Nothing the model can write is a grant. PR/MR creation and `/merge`
    stay user-only (263).

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on
   reload.
2. **Propose, then apply, across repos.**
3. **Verify by execution, not by reading.** Every number here was measured the day it was written;
   re-measure before acting on it.
4. **The lead never reads a report, plan, summary, description, or context file during the loop.**
   This is a byte budget with a gate, not a paragraph.

## Unfiled observations (none worth a task yet)

- The runtime wave-split check (`orchestrate-cycle-plan.sh` step 4.5) defers a cross-batch scope
  collision on every run and records nothing. Persisting it as a `dependencies[]` edge is a
  one-line `state-write.sh` call, after 165 rules on absent scope.
- The write-time task-reference hook fires on files in the session scratchpad. Its path filter
  could exempt `/tmp/**`.
- A subagent parked on genuinely slow background work emits repeated interim notifications that
  read like stalling. Notification semantics, not agent behaviour.
- `commands/task.md`'s abandon mode documents the archive target as `completed_projects`; the
  live archive puts abandoned entries in `archived_projects` with `archived_at`. 44 rewrites that
  file and should fix the text.
- `/todo`'s archive-orphan scan checks only `completed_projects`, so the 48 correctly-tracked
  `archived_projects` entries surface as false orphans on every run. Harmless today because the
  prompt is declinable, but it is a real defect in `commands/todo.md` Step 2.5 and the mirrored
  `skill-todo` Stage 3.
- Eager context has 1 B of headroom against its baseline. The next task that adds an eager rule
  or CLAUDE.md line will fail gate 20 outright; 89 and 251 are the two tasks that create room.
