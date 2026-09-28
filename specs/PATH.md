# Implementation Path

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`.
Last rewritten 2026-09-28 (sixth pass).*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's. Both halves are met in shape and in measurement. What remains splits into
three lanes: make the engine **converge without operator help** (every self-modifying task since
2026-09-22 needed a hand reconcile), make it **correct for concurrent Lean and paper work** in the
consumer repos, and **cut dead weight and per-invocation cost** once the engine is quiet.

## Where things stand (measured 2026-09-28, sixth pass)

| Measure | Value | Bearing |
|---|---|---|
| Open tasks | **29** | Archive holds 181 completed, 48 abandoned/orphan, 1 expanded |
| `validate-state.sh --deep` | 0 failures | Clean |
| `verify-deploy.sh --skip-slow` | **PASS, 33 of 33** | Context edits committed and redeployed; the working tree is clean |
| Eager context load | 64,148 B / baseline 65,950 | 1,802 B headroom |
| `skills/skill-orchestrate/SKILL.md` | 19,983 B / ceiling 20,000 | **17 B headroom** — 263's relay text must be offset |
| `commands/orchestrate.md` | 20,228 B / ceiling 21,000 | 772 B headroom |
| Redeploy checkpoint cost | full-depth verify ×2–3 per fire; Gate 8 ≈ 9 of 11 min | See call C (265) |
| Stranded session files in `specs/` root | **67** (36 multi-state, 30 return-meta-multi, 1 meta-return) | 51 builds the reaper trigger |
| Consumer deploys | **all 9 FRESH** | Five consumers (Theory, Hardware, cslib, dotfiles, PersonalWebsite) carry uncommitted hygiene fixes: `init-specs.sh` untracks staged in the index, and stale root-`.gitignore` lines that ignored `.orchestrator-handoff.json` / `.return-meta.json` removed. Commit each in its own repo before running a batch there |

**`MAX_TASKS` is 8**, enforced in `commands/orchestrate.md` (the command truncates to the first 8
with a warning); `orchestrate-cycle-plan.sh` itself accepts any count, so a dry-run over more than
8 is not evidence a call will run them.

**Every open task is accounted for below**: A 1 + B 8 + C 8 + D 8 + E 4 = 29. If that sum stops
matching `state.json`, this file has drifted.

---

## Next

Call A. The dry-run admits 266 at `research` with nothing deferred or blocked, and leaves
`state.json` unchanged. Nothing else is outstanding before it.

---

## Call A — engine convergence, alone

```
/orchestrate 266
```

The deploy-pending refusal (exit 6) and the identical-dispatch guard compose so that every task
whose `modified_files` touch `agent-system/**` — which is every meta task in this repo — halts at
`implementing` and needs `reconcile-task-status.sh` by hand. 266 runs alone for two reasons: the
admission tie-breaker designates the **lowest-numbered** self-modifying candidate each cycle, so in
any shared batch 199 would go first; and 266 is itself self-modifying, so its own convergence
inside one run is the acceptance test.

## Call B — git safety, file_scope chain, isolation decision (8)

```
/orchestrate 139, 162, 163, 244, 43, 199, 207, 167
```

| Task | What lands | Note |
|---|---|---|
| **139** | History-rewrite prohibition (rules, contracts) + concurrency-gated predicate in `guard-destructive-git.sh` | Gates 263 and 136 |
| **162** (researched) | `**Files to modify**:` formalised; harvested into `file_scope` at plan postflight; backfill | Plan dispatch first |
| **163** | Absent / empty / glob `file_scope` visible in `validate-state.sh` and predispatch review | WARN-first |
| **244** (+256) | `check-task-references.sh` scans repo-appropriate roots; `validate-wiring.sh` skips a missing tree root | Two consumer repos reproduce it |
| **43** | The email extension's five safety pointers actually reach an agent | Live defect, small |
| **199** | Working-tree / `.lake` isolation posture for concurrent same-repo dispatches; then implement | Waits for 266 in-run. Largest decision: if it stalls, pull it out and run `/orchestrate 199 --hard` |
| **207** (+208) | Zotero export Path 1: temp-file accumulator, loud failure, shrink guard; then the 481-item stop | Data loss today. Absorbed half needs Zotero **open** |
| **167** (+74–76) | vimtex continuous-build safety in the latex rule; mechanism phases conditional | Rule first (decision 8) |

Dry-run admits 139, 162, 163, 244, 43, 207, 167 in cycle 0; 199 admits once 266 is terminal.
Implement-phase serialization inside the batch: 162 → 199 (both self-modifying).

## Call C — push consent, admission posture, contracts, checkpoint cost (8)

```
/orchestrate 263, 165, 136, 265, 51, 223, 255, 241
```

| Task | What lands | Note |
|---|---|---|
| **263** (+224, 264) | One grant token; `/please` mint hook with integrity; push guard; grant check in the destructive-git guard; user-only command, never-list, rule exception; dispatch relay + two-cycle non-replay test | After 139. Offset any SKILL.md growth byte-for-byte |
| **165** (+190) | Admission posture for an absent `file_scope`; cross-session visibility for self-modifying candidates | After 162, 163 |
| **136** (+166, 14) | Plan-level `Status` ownership and grammar; fan-out prohibition; marker/commit sync; research-report heading conformance | After 139 |
| **265** (+267) | Gate 8 via `run-all.sh --jobs` (conservative default + env override); inline verify in `deploy-headless.sh` narrowed or opt-out | After 266. Biggest per-checkpoint saving available |
| **51** | Session runtime files out of the `specs/` root; reaper widened and wired into `/todo` | 67 stranded now |
| **223** (+177) (researched) | Comparator-on-NixOS fixes; Lean 4 dependency-tracing recipe | Plan dispatch first |
| **255** | typst scope statement matches what it ships; `chapter-quality-check.sh` Rule 1.3 bib resolution | Deployed to 5 repos |
| **241** | Drop two playwright grant lists and five dead `mcp_servers` fields; fix ownership doc and nix README | Re-verify the user-scope grant count is 9 first |

Implement-phase serialization: 51 → 165 → 265 → 263 (self-modifying, lowest first).

## Call D — cost, clutter, corpus probe (8)

```
/orchestrate 250, 89, 44, 127, 217, 39, 185, 184
```

| Task | What lands | Note |
|---|---|---|
| **250** | Script-inventory probe (reuse 261's timing baseline); decompose `orchestrate-cycle-plan.sh` into `lib/`, byte-identical `--dry-run` | After 199, 265, 266 — the file is quiet by then |
| **89** | Mode-gate `skill-literature` (84 KB) and `skill-distill` (93 KB) | ~24.8k tokens per invocation |
| **44** (planned) | Slim `commands/task.md` (41 KB per `/task`) into lazy context files | Implement dispatch first |
| **127** | Collapse the routing ladder to the two agent blocks; retire `command-route-skill.sh`; lint nonexistent agent targets | Clears the gate16 WARN |
| **217** (+218, 219) | `/refresh` PSS accounting, CPU-delta idleness, prompt-never-kill | Utility, not engine |
| **39** (planned) | Zotero metadata resolution; MCP decision; quota gate; Zotero 10 swap plan | Needs the dotfiles translation-server |
| **185** | Retarget live "Stage N" / "Stage MT-N" citations to Move vocabulary; keep historical ones | After 266, 199, 184; research adds the rest of the 72 files to scope |
| **184** | Skeleton-plan `sorry_inventory` follow-ups reported append-only at completion | After 266 |

## Call E — reachability, test isolation, picker lane (4)

```
/orchestrate 251, 170, 22, 29
```

| Task | What lands | Note |
|---|---|---|
| **251** | Context-reachability probe (filename, directory, `index.json`) with the 16 present templates as the fixture; telemetry cross-check; remove what is genuinely dead | After 44, 127 |
| **170** | Isolate shell suites from ambient host state (memory and timing axes); record the convention; repeated-run acceptance under load | Last: after 51, 250, 251 |
| **22** (+45) | Silence opencode fragment spam; fix the fake-tool line; record the frozen-mirror policy; honest `[Reload All]`/`[Regenerate]`; Global Update registry | Lua, not agent-system |
| **29** (+30) | `merge_targets.mcp` → repository-root `.mcp.json`; register obsidian-memory through it | After 22, 241 |

---

## Checks before and after every call

- `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>`
  — **space-separated**; admits what you expect, `md5sum specs/state.json` unchanged. Research and
  plan dispatches are exempt from the self-modifying defer (`--phase-map`), so overlap only
  serializes at implement time.
- `bash .claude/scripts/validate-state.sh --deep` — 0 failures, 0 warnings.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — green, on an idle machine, exit
  code read directly (never through `tail`/`head`). `--jobs 4` is opt-in and reproduces the
  serial pass/fail set except under heavy contention (261's finding).
- `bash .claude/scripts/verify-deploy.sh --skip-slow` — PASS (33 of 33 on 2026-09-28), and
  both engine files under their ceilings. A self-modifying task is not finished until `.claude/`
  is resynced.
- After any call that ran in a consumer: `check-consumer-freshness.sh` here, `deploy-headless.sh`
  there if STALE.

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
   six more times this pass; apply it at creation time.
7. **No analysis surface over `file_scope`** until the field is reliably populated (162, 163).
8. **Rule before mechanism** for the vimtex hazard: 167's mechanism phases are conditional.
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
- `specs/archive/state.json` holds 181 completed, 48 archived (abandoned/orphan) and 1 expanded
  entries.
