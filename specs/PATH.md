# Implementation Path

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`.
Last rewritten 2026-09-30 (eighth pass).*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's. Both halves are met in shape and in measurement. The engine-convergence lane
closed in the seventh pass and has stayed closed. Call A's first half landed on 2026-09-30 — the
session-runtime relocation, the plan-`Status` ownership contract, the comparator NixOS fixes and
the typst scope/bib work are all shipped and removed from this file.

What remains splits into four lanes: **restore the deploy gate to green** (new, and blocking —
see Next), **cut per-invocation cost and clutter**, **finish the orchestrator's own operational
surface** (queue, liveness, conclusion stage), and **correct the consumer repos**, which have
drifted badly STALE behind this pass's source-store changes.

## Where things stand (measured 2026-09-30, eighth pass)

| Measure | Value | Bearing |
|---|---|---|
| Open tasks | **28** | Four verified-defect tasks were filed on 2026-09-30 after this pass's batch (see call 0). Plus 4 `completed` awaiting `/todo` archive; `specs/archive/` holds 211 task directories |
| `validate-state.sh --deep` | 0 failures, **1 warning** | 268 now declares a `file_scope`. The remaining warning is 270's, coarse enough to overlap 20 non-terminal tasks. A TODO.md desync appeared and was cleared by `generate-todo.sh` — regenerate after any direct `state.json` write |
| `verify-deploy.sh` | **FAIL — 3 of 33** | **Regression from 33 of 33.** Blocks the Inter-Cycle Redeploy Checkpoint, so it blocks every multi-cycle batch. See Next |
| Eager context load | 67,980 B / baseline 65,950 | **2,030 B OVER** — was 1 B of headroom. Gate 20 now fails outright; 89 and 251 are the tasks that create room |
| `skills/skill-orchestrate/SKILL.md` | 20,137 B / ceiling 20,000 | **137 B OVER** (gate is `warn` mode, so it reports rather than fails) |
| `commands/orchestrate.md` | 20,243 B / ceiling 21,000 | 757 B headroom |
| Redeploy checkpoint cost | full-depth verify per fire; one fire exceeded a 30-min budget | Still the biggest per-invocation cost. See call A (265) |
| Stranded session files in `specs/` root | **0** (was 72) | Files now live in `specs/.orchestration/`, and `/todo` reaps on every invocation |
| Consumer deploys | **8 of 8 consumers STALE** | `core` is 58 behind in .dotfiles, ModelChecker, PersonalWebsite, cslib, Logos/Theory, Logos/Hardware, PossibleWorlds; 14 behind in BimodalLogic, which was fully FRESH last pass. Redeploy in a repo before running a batch there |

**`MAX_TASKS` is 8**, enforced in `commands/orchestrate.md` (the command truncates to the first 8
with a warning); `orchestrate-cycle-plan.sh` itself accepts any count, so a dry-run over more than
8 is not evidence a call will run them.

**Every open task is accounted for below**: 0 4 + A 4 + B 8 + C 4 + D 8 = 28. If that sum stops
matching `state.json`, this file has drifted.

---

## Next

**Fix the three red gates first. They are not any one task's scope, and they block every
multi-cycle batch.** The Inter-Cycle Redeploy Checkpoint fires whenever a cycle touches an
orchestrator-critical path, redeploys, and re-verifies; a red tree there stops the run. On
2026-09-30 a batch lost its remaining four tasks to exactly this, after the checkpoint's own
verify exceeded a 30-minute budget and still reported red:

1. **Manifest content-hash** — `core: context/contracts/adversarial-verification.md` differs from
   source. A `lean`/`core` filename collision in deploy-merge order; the `lean` extension was
   loaded into this repo for the first time on 2026-09-30, which is what exposed it.
2. **Postflight boundary lint** — failures in the full corpus; `skill-lean-research/SKILL.md` is
   missing its postflight-boundary section.
3. **Eager-load total** — 67,980 B against a 65,950 B baseline, accumulated across roughly ten
   unrelated prior tasks. Either offset it or re-derive the baseline deliberately.

None of the three is caused by, or fixable within, the scope of any task listed below. File them
as one task (they share a single acceptance check: `verify-deploy.sh` returns 33 of 33) and run it
before call A's remainder.

**Call 0 outranks even that.** 276 is verified silent data loss in the worktree dispatch path —
a dispatch that authored correct work can have it destroyed with no error raised. Read call 0
before scheduling anything else; 278 in particular is a contract fix that prevents the loss from
being *triggered* and is cheap.

Then: **the consumer repos are STALE across the board.** If the next work touches a consumer, run
`deploy-headless.sh` there before dispatching into it.

---

## Call 0 — worktree dispatch integrity and state schema (4)

```
/orchestrate 278, 277, 276, 279
```

Filed 2026-09-30, all four verified by reading the source store rather than inferred. **This lane
comes first.** Ordering within it is deliberate and now **enforced by declared dependency
edges** (278 <- 277 <- 276), not left to file_scope serialization -- the three footprints are
disjoint, so admission alone would have run them in parallel. 278 is a contract-only change that
stops the hazard being triggered at all, 277 restores the commit path the fix depends on, 276
removes the destructive branch itself, and 279 is independent (wave 1 alongside 278).

| Task | What lands | Note |
|---|---|---|
| **278** | Forbid forwarding the Agent tool's harness-level `isolation` parameter in Move 2; `orchestrate-cycle-plan.sh` already emits `isolation`/`worktree_path` on every dispatch row with nothing prohibiting their use | Documentation and contract only, no executable logic. **Cheapest of the four and it closes the trigger** — do it first |
| **277** | `git-commit-scoped.sh` cannot commit inside a dispatch worktree and fails as a **false negative that reads as success** to its caller: `PROJECT_ROOT` is derived from `BASH_SOURCE[0]`, so it always targets the main tree with no retarget flag | The single sanctioned commit path for every skill postflight. 276's fix is not trustworthy until this one lands. **Depends on 278**; admits in cycle 1 |
| **276** | `orchestrate-cycle-postflight.sh` folds `landed` and `nothing_to_land` into one success branch, which then releases the worktree — so a dispatch that authored verified work but failed to commit it has that work destroyed silently | **HIGHEST SEVERITY: silent data loss.** Shares `dispatch-worktree.sh` with 268. **Depends on 277**; admits last |
| **279** | State schema rejects live orchestration fields; decide the per-field policy and ship a migration tool if one is warranted | Observed in BimodalLogic; that repo's data migration is its owner's separate action. No edge: admits in cycle 0 beside 278. **Gates 271** (call D) |

Measured on the edges (`--dry-run`, 2026-09-30): cycle 0 dispatches **278 and 279 in parallel**;
277 and 276 are held silently (they appear in neither `deferred[]` nor `blocked[]`) and admit as
their predecessors reach a terminal status. The consequence to know: **`/orchestrate 277` or
`/orchestrate 276` on its own now stops with `no_eligible_stuck` and dispatches nothing.** Either
run the lane as the one call above, or name the predecessor alongside it.

---

## Call A — push consent, admission posture, checkpoint cost (4)

```
/orchestrate 263, 165, 265, 241
```

All four are `planned` with plans in hand as of 2026-09-30; each needs only its implement phase.

| Task | What lands | Note |
|---|---|---|
| **263** (+224, 264) | One grant token; `/please` mint hook with integrity; push guard; grant check in the destructive-git guard; user-only command, never-list, rule exception; dispatch relay + two-cycle non-replay test | 13-phase plan. Push-scope question is **settled** (decision 12). SKILL.md is already 137 B over its ceiling — offset any growth byte-for-byte |
| **165** (+190) | Admission posture for an absent `file_scope`; cross-session visibility for self-modifying candidates | 6-phase plan, fully sequential. Also closes a found defect: the `defer_reason` consumer `case` in `orchestrate-cycle-plan.sh` has no default arm, so a new reason would drop a task from dispatch with no ledger entry |
| **265** (+267) | Gate 8 via `run-all.sh --jobs` (conservative default + env override); `deploy-headless.sh --skip-verify` with a distinct exit 4 | 8-phase plan, all single-phase waves (three are whole-tree timing measurements). Biggest per-checkpoint saving available, and the 30-min checkpoint overrun makes it more urgent than last pass |
| **241** | Drop two playwright grant lists and five dead `mcp_servers` fields; fix ownership doc and nix README | 7-phase plan, 2.75 h. Grew from 9 files to 10: `web/.../playwright-mcp-guide.md`'s Permission-Tiers section is also falsified. Re-verify the user-scope grant count is 9 first |

Implement-phase serialization: **165 → 265 → 263** (self-modifying, lowest first). 241 is outside
the self-modifying gate and has no live in-batch collision, so it can run alongside any of them.

## Call B — cost, clutter, corpus probe (8)

```
/orchestrate 250, 89, 44, 127, 217, 39, 185, 184
```

| Task | What lands | Note |
|---|---|---|
| **250** | Script-inventory probe (reuse 261's timing baseline); decompose `orchestrate-cycle-plan.sh` into `lib/`, byte-identical `--dry-run` | Wait on 265 (call A) so the file is quiet |
| **89** | Mode-gate `skill-literature` (84 KB) and `skill-distill` (93 KB) | ~24.8k tokens per invocation. **Now load-bearing**: one of two tasks that can clear the eager-load failure |
| **44** (planned) | Slim `commands/task.md` (41 KB per `/task`) into lazy context files | Implement dispatch first. Also fix its abandon-mode text (see observations) |
| **127** | Collapse the routing ladder to the two agent blocks; retire `command-route-skill.sh`; lint nonexistent agent targets | Clears the gate 16 WARN (`lean` still declares `routing_hard`/`routing_agents_hard`) |
| **217** (+218, 219) | `/refresh` PSS accounting, CPU-delta idleness, prompt-never-kill | Utility, not engine |
| **39** (planned) | Zotero metadata resolution; MCP decision; quota gate; Zotero 10 swap plan | Needs the dotfiles translation-server |
| **185** | Retarget live "Stage N" / "Stage MT-N" citations to Move vocabulary; keep historical ones | Still after 184. Research adds the rest of the 72 files to scope |
| **184** | Skeleton-plan `sorry_inventory` follow-ups reported append-only at completion | Gate clear. Gates 273 in call D |

## Call C — reachability, test isolation, picker lane (4)

```
/orchestrate 251, 170, 22, 29
```

| Task | What lands | Note |
|---|---|---|
| **251** | Context-reachability probe (filename, directory, `index.json`) with the 16 present templates as the fixture; telemetry cross-check; remove what is genuinely dead | After 44, 127. **Now load-bearing**: the other task that can clear the eager-load failure |
| **170** | Isolate shell suites from ambient host state (memory and timing axes); record the convention; repeated-run acceptance under load | After 250, 251. 265's Phase 1 fixes one instance of exactly this class — an inherited `RUN_ALL_NESTED` making a timing assertion fail deterministically rather than under load, as previously attributed |
| **22** (+45) | Silence opencode fragment spam; fix the fake-tool line; record the frozen-mirror policy; honest `[Reload All]`/`[Regenerate]`; Global Update registry | Lua, not agent-system |
| **29** (+30) | `merge_targets.mcp` → repository-root `.mcp.json`; register obsidian-memory through it | After 22, 241 |

## Call D — orchestrator queue, liveness, conclusion stage; build-guard and null-safety (8)

```
/orchestrate 268, 269, 270, 271, 272, 273, 274, 275
```

**This is a lane, not a runnable batch of 8.** 268 and 269 admit with no dependencies; the other
six chain behind 269, 184 (call B) and 165 (call A). Run calls A and B first, or dispatch the
front pair on their own.

| Task | What lands | Note |
|---|---|---|
| **268** | Reproduce-first on the `lake-build-guard.sh` false green: the `scope_key` sharing condition that would prevent the replay is already implemented and predates the observation, so determine which of the candidate causes actually holds | No deps; admits now. `file_scope` is declared and includes `dispatch-worktree.sh`, so it serializes against 276 — take the cross-tree replay hypothesis with it |
| **269** | `validate-state.sh --fix`: presence test → type test, so a null `file_scope` cannot abort the repair | No deps; admits now. Gates 270 and 271 |
| **270** | Re-runnable null-safety audit of jq mutation sites across core scripts; rule on a shared guard idiom in `scripts/lib/` | After 269. **`file_scope` is coarse** (`.../core/scripts/`, now overlapping 20 non-terminal tasks) — narrow it or it will serialize against most of the backlog |
| **271** | Finish the `parent_task` edge: declare in schema, validate, render in TODO, survive renumbering | After 269 **and 279** (the per-field schema policy must land before another field is declared). Gates 273 |
| **272** | Honest session liveness for concurrent same-repo batches: diagnose why the wired heartbeat never fires, add a live-but-stale lock state, re-derive registry scope, give each orchestration its own identity | No outstanding dependency. Pairs naturally with the sweep defect in observations |
| **273** | Three-channel orchestration conclusion stage with per-channel approval, as a distinct post-postflight stage | After 271 and 184 (call B) |
| **275** | Per-repo orchestration queue: registered, live, archived on finish, consumed by admission | After 272 |
| **274** | Next-admissible-batch suggestion and alternatives-on-conflict, both computed by invoking the real admission script | Tail of everything: after 272, 273, 275, 165. Once it lands, this file's call groupings become computable rather than hand-maintained |

---

## Checks before and after every call

- `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>`
  — **space-separated**; admits what you expect, `md5sum specs/state.json` unchanged. Research and
  plan dispatches are exempt from the self-modifying defer (`--phase-map`), so overlap only
  serializes at implement time.
- `bash .claude/scripts/validate-state.sh --deep` — 0 failures. **One** `file_scope` warning is
  expected today (270's, coarse enough to overlap 20 non-terminal tasks); 268 now declares one.
  Treat any *new* warning as real. Re-measured 2026-09-30: 18 passed, 1 warning, 0 failed.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — green, on an idle machine, exit
  code read directly (never through `tail`/`head`). `--jobs 4` is opt-in and reproduces the
  serial pass/fail set except under heavy contention (261's finding).
- `bash .claude/scripts/verify-deploy.sh --skip-slow` — **currently FAIL, 3 of 33** (2026-09-30).
  Until the three gates in Next are fixed this check is red for reasons unrelated to whatever you
  just changed, so measure it *before* your work as well as after, and compare. A self-modifying
  task is not finished until `.claude/` is resynced.
- After any call that ran in a consumer: `check-consumer-freshness.sh` here, `deploy-headless.sh`
  there if STALE. **All eight consumer repos are STALE right now.**

---

## Settled decisions (do not re-litigate)

1. **Batch of one.** One engine; single-task is a batch of one. Team mode is deleted. Hard mode is
   kept in full and is per-invocation.
2. **The orchestrator never asks and never decides.** Only an agent-surfaced `user_decision` reaches
   the user, once, at cycle end.
3. **Research-first is the default** for a fresh task; `--fast` restores planner-first.
4. **`--dry-run` prints the plan it would dispatch.** There is no separate dry-run report.
5. **No fixed consumer validation gates.** The checks above are recommended, not blocking.
6. **A linear chain of small tasks that serialize on one file is one task with phases.** Apply it
   at creation time.
7. **No analysis surface over `file_scope` until the field is reliably populated.** The field is
   harvested at plan postflight and its absence is visible, so the condition is met. Build the
   surface in 165, and treat the two live warnings (268, 270) as the first real input rather than
   noise to suppress. Measured coverage is uneven across repos — near-complete here, but only
   about 42% of BimodalLogic's non-terminal tasks carry the field, which is why 165's ruling
   splits by scope kind (in-batch blocking, cross-batch advisory) rather than issuing one blanket
   posture.
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
12. **A grant may authorize a plain push of the default branch** (user ruling, 2026-09-30). Every
    force form on the default branch, bare `--force` anywhere, and all bulk or deletion refspecs
    stay categorically excluded, checked before any grant lookup. Rationale: `git-workflow.md`'s
    pre-existing "Never Run" is specifically force-to-master, and this repository's own working
    branch *is* master, so a blanket default-branch exclusion would exceed the rule being
    narrowed and make the mechanism unusable where it lives.

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on
   reload.
2. **Propose, then apply, across repos.**
3. **Verify by execution, not by reading.** Every number here was measured the day it was written;
   re-measure before acting on it.
4. **The lead never reads a report, plan, summary, description, or context file during the loop.**
   This is a byte budget with a gate, not a paragraph.

## Unfiled observations (none worth a task yet)

- **The runtime-file sweep deletes the live run's own state.** `/todo`'s new reap stage (and
  `reap-session-runtime-files.sh` generally) does not exclude the *active* session's runtime
  files, though a session registry exists for exactly that purpose. Observed on 2026-09-30: a
  sweep that took the root from 72 stranded files to 0 also removed the in-flight batch's
  `.orchestrator-multi-state-<session>.json`, losing `completed_tasks`, `failed_tasks` and cycle
  bookkeeping mid-run. Recovered by hand from the surviving `.dispatch/*.md` mtimes, but an
  unattended run would have lost it silently. **This is the one observation here closest to
  deserving a task**; it belongs with 272's session-identity work.
- A `Monitor`-armed wait can never fire. An implementation agent armed a monitor for a long
  `run-all.sh`, went idle, and no event ever arrived — the dispatch stalled indefinitely until
  resumed by hand. Prefer in-band polling with productive work between checks over arm-and-idle.
- The runtime wave-split check (`orchestrate-cycle-plan.sh` step 4.5) defers a cross-batch scope
  collision on every run and records nothing. Persisting it as a `dependencies[]` edge is a
  one-line `state-write.sh` call, after 165 rules on absent scope.
- The write-time task-reference hook fires on files in the session scratchpad. Its path filter
  could exempt `/tmp/**`.
- A subagent parked on genuinely slow background work emits repeated interim notifications that
  read like stalling — confirmed again on 2026-09-30, where most dispatches reported completion
  twice. Notification semantics, not agent behaviour.
- `commands/task.md`'s abandon mode documents the archive target as `completed_projects`; the
  live archive puts abandoned entries in `archived_projects` with `archived_at`. 44 rewrites that
  file and should fix the text.
- `/todo`'s archive-orphan scan checks only `completed_projects`, so correctly-tracked
  `archived_projects` entries surface as false orphans on every run. Harmless today because the
  prompt is declinable, but it is a real defect in `commands/todo.md` Step 2.5 and the mirrored
  `skill-todo` Stage 3.
- `plan-file-scope-harvest.sh` parses a `**Files to modify**:` field and finds nothing in a plan
  that uses a "Territory Contract" table instead. At least one BimodalLogic plan is invisible to
  the harvester for this reason.
- The in-scope agent set for a contract rolled across implementation agents is **14** files, not
  the 13 a sweep by directory suggests — `founder-implement-agent.md` also edits phase-heading
  markers. Worth remembering the next time a contract is rolled out this way.
