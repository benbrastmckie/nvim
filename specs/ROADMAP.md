# Roadmap

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`.
Measured 2026-09-30.*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's. Both halves are met in shape and in measurement; the engine-convergence lane
is closed.

What remains splits into five lanes: **restore the deploy gate to green** (blocking — see Next),
**worktree dispatch integrity** (silent data loss — call 0), **cut per-invocation cost and
clutter**, **finish the orchestrator's own operational surface** (queue, liveness, conclusion
stage), and **correct the consumer repos**, which have drifted badly STALE.

## Where things stand

| Measure | Value | Bearing |
|---|---|---|
| Open tasks | **31** | Up from 28: three record-versioning tasks and two live-observed contract defects were filed. Plus 7 `completed` awaiting `/todo` archive; `specs/archive/` holds 211 task directories |
| `validate-state.sh --deep` | 18 passed, **2 warnings**, 0 failed | Both warnings are 270's two coarse `file_scope` entries; the broader one now overlaps **23** non-terminal tasks (was 20). TODO.md is byte-identical to a regenerated one |
| `verify-deploy.sh` | **FAIL — 3 of 33** | The Inter-Cycle Redeploy Checkpoint proceeds anyway on a `pre=N post=N new=0` baseline comparison, so a red tree does not stop a run — it masks whatever finding is genuinely new. See Next |
| Eager context load | 67,980 B / baseline 65,950 | **2,030 B OVER.** Gate 20 fails outright, and it is *also* why `test-verify-deploy-context-budget.sh` is red — one fix clears both. 89 and 251 are the tasks that create room |
| `skills/skill-orchestrate/SKILL.md` | 21,317 B / ceiling 20,000 | **1,317 B OVER**, up from 137 B over. Growing, not shrinking — gate is `warn` mode, so it reports rather than fails |
| `commands/orchestrate.md` | 20,243 B / ceiling 21,000 | 757 B headroom |
| Harness failures | **101 passed, 5 failed (4 expected, 1 NEW), 106 total** | Roster, baseline manifest and `--fail-on-new` all landed and verified end to end: the run names every failing suite and classifies it. The 1 NEW is `test-typst-element-lint.sh`, correctly flagging **uncommitted WIP** in `typst/scripts/typst-element-lint.sh` (Check 4, with a stale fixture) — commit or revert it. `known-failures.txt` carries the 4 EXPECTED rows, 3 `real-defect` + 1 `intermittent`, all `needs-owner` except the accepted flake |
| Redeploy checkpoint cost | `--skip-slow` on all 5 call sites; 13m48s → 2m4s measured | No longer the biggest per-invocation cost. **But** a fire that must actually deploy still exceeded a 30-min budget and was killed; the immediate re-run over a fresh tree finished in under 500 s |
| Consumer deploys | **8 of 8 consumers STALE** | `core` is **75** behind in .dotfiles, ModelChecker, PersonalWebsite, cslib, Logos/Theory, Logos/Hardware, PossibleWorlds; **2** behind in BimodalLogic. Redeploy in a repo before running a batch there |

**`MAX_TASKS` is 8**, enforced in `commands/orchestrate.md` (the command truncates to the first 8
with a warning); `orchestrate-cycle-plan.sh` itself accepts any count, so a dry-run over more than
8 is not evidence a call will run them.

**Every open task is accounted for below**: 0 → 3 + A 4 + B 8 + C 4 + D 7 + E 5 = 31. If that sum
stops matching `state.json`, this file has drifted.

---

## Next

**Fix the three red gates first.** They are not any one task's scope, and a red tree there masks
every new finding behind a baseline comparison:

1. **Manifest content-hash** — `core: context/contracts/adversarial-verification.md` differs from
   source. A `lean`/`core` filename collision in deploy-merge order; the `lean` extension was
   loaded into this repo for the first time on 2026-09-30, which is what exposed it.
2. **Postflight boundary lint** — failures in the full corpus; `skill-lean-research/SKILL.md` is
   missing its postflight-boundary section.
3. **Eager-load total** — 67,980 B against a 65,950 B baseline, accumulated across roughly ten
   unrelated prior tasks. Either offset it or re-derive the baseline deliberately. **This one also
   clears a red test suite** (`test-verify-deploy-context-budget.sh`), so it buys two things.

None of the three is fixable within the scope of any task listed below. File them as one task
(they share a single acceptance check: `verify-deploy.sh` returns 33 of 33) and run it before
call A.

**Call 0 outranks even that.** 276 is verified silent data loss in the worktree dispatch path —
a dispatch that authored correct work can have it destroyed with no error raised.

Then: **the consumer repos are STALE across the board.** If the next work touches a consumer, run
`deploy-headless.sh` there before dispatching into it.

---

## Call 0 — worktree dispatch integrity and state schema (3)

```
/orchestrate 277, 276, 279
```

**This lane comes first.** Ordering is enforced by declared dependency edges (277 ← 276), not left
to `file_scope` serialization — the footprints are disjoint, so admission alone would run them in
parallel. The lane's cheapest member has already landed: the contract fix that stops the hazard
being *triggered* is done and removed from this file, which is why 277 now leads.

| Task | What lands | Note |
|---|---|---|
| **277** | `git-commit-scoped.sh` cannot commit inside a dispatch worktree and fails as a **false negative that reads as success** to its caller: `PROJECT_ROOT` is derived from `BASH_SOURCE[0]`, so it always targets the main tree with no retarget flag | The single sanctioned commit path for every skill postflight. 276's fix is not trustworthy until this lands |
| **276** | `orchestrate-cycle-postflight.sh` folds `landed` and `nothing_to_land` into one success branch, which then releases the worktree — so a dispatch that authored verified work but failed to commit it has that work destroyed silently | **HIGHEST SEVERITY: silent data loss.** Shares `dispatch-worktree.sh` with 268. **Depends on 277**; admits last |
| **279** | State schema rejects live orchestration fields; decide the per-field policy and ship a migration tool if one is warranted | `planned`, needs only its implement phase. No edge: admits in cycle 0 beside 277. **Gates 271** (call D) |

The consequence to know: **`/orchestrate 276` on its own stops with `no_eligible_stuck` and
dispatches nothing.** Either run the lane as the one call above, or name the predecessor alongside
it.

---

## Call A — push consent, admission posture, checkpoint cost (4)

```
/orchestrate 263, 165, 265, 241
```

All four are `planned` with plans in hand; each needs only its implement phase.

| Task | What lands | Note |
|---|---|---|
| **263** (+224, 264) | One grant token; `/please` mint hook with integrity; push guard; grant check in the destructive-git guard; user-only command, never-list, rule exception; dispatch relay + two-cycle non-replay test | 13-phase plan. Push-scope question is **settled** (decisions 11–12). SKILL.md is now 1,317 B over its ceiling — offset any growth byte-for-byte |
| **165** (+190) | Admission posture for an absent `file_scope`; cross-session visibility for self-modifying candidates | 6-phase plan, fully sequential. Also closes a found defect: the `defer_reason` consumer `case` in `orchestrate-cycle-plan.sh` has no default arm, so a new reason would drop a task from dispatch with no ledger entry |
| **265** (+267) | Gate 8 via `run-all.sh --jobs` (conservative default + env override); `deploy-headless.sh --skip-verify` with a distinct exit 4 | 8-phase plan, all single-phase waves. **Less urgent than last pass** — `--skip-slow` already took the checkpoint from 13m48s to 2m4s — but `--skip-verify` remains the fix for the *deploying* fire that still overran 30 min |
| **241** | Drop two playwright grant lists and five dead `mcp_servers` fields; fix ownership doc and nix README | 7-phase plan, 2.75 h. 10 files: `web/.../playwright-mcp-guide.md`'s Permission-Tiers section is also falsified. Re-verify the user-scope grant count is 9 first |

Implement-phase serialization: **165 → 265 → 263** (self-modifying, lowest first). 241 is outside
the self-modifying gate and has no live in-batch collision, so it can run alongside any of them.

## Call B — cost, clutter, corpus probe (8)

```
/orchestrate 250, 89, 44, 127, 217, 39, 185, 184
```

| Task | What lands | Note |
|---|---|---|
| **250** | Script-inventory probe; decompose `orchestrate-cycle-plan.sh` into `lib/`, byte-identical `--dry-run` | Wait on 265 (call A) so the file is quiet |
| **89** | Mode-gate `skill-literature` (84 KB) and `skill-distill` (93 KB) | ~24.8k tokens per invocation. **Load-bearing**: one of two tasks that can clear the eager-load failure, and with it a red test suite |
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
| **251** | Context-reachability probe (filename, directory, `index.json`) with the 16 present templates as the fixture; telemetry cross-check; remove what is genuinely dead | After 44, 127. **Load-bearing**: the other task that can clear the eager-load failure |
| **170** | Isolate shell suites from ambient host state (memory and timing axes); record the convention; repeated-run acceptance under load | After 250, 251. Now has a concrete, committed target: `known-failures.txt`'s one `intermittent` row (`test-run-all-parallel.sh`) is exactly this class, and an absolute threshold was already tried and rejected there |
| **22** (+45) | Silence opencode fragment spam; fix the fake-tool line; record the frozen-mirror policy; honest `[Reload All]`/`[Regenerate]`; Global Update registry | Lua, not agent-system |
| **29** (+30) | `merge_targets.mcp` → repository-root `.mcp.json`; register obsidian-memory through it | After 22, 241 |

## Call D — orchestrator queue, liveness, conclusion stage; build guard, null safety (7)

```
/orchestrate 268, 270, 271, 272, 273, 274, 275
```

**This is a lane, not a runnable batch of 7.** 268 and 272 carry no outstanding dependency; the
others chain behind 279 (call 0), 184 (call B) and 165 (call A). Run calls A and B first, or
dispatch the front pair on their own. The `validate-state.sh --fix` null-safety crash that used to
lead this lane has landed and is removed from this file, which is what unblocks 270 and 271.

| Task | What lands | Note |
|---|---|---|
| **268** | Reproduce-first on the `lake-build-guard.sh` false green: the `scope_key` sharing condition that would prevent the replay is already implemented and predates the observation, so determine which candidate cause actually holds | Already `implementing`. `file_scope` includes `dispatch-worktree.sh`, so it serializes against 276 — take the cross-tree replay hypothesis with it |
| **270** | Re-runnable null-safety audit of jq mutation sites across core scripts; rule on a shared guard idiom in `scripts/lib/` | Unblocked now. **`file_scope` is coarse** (`.../core/scripts/`, overlapping 23 non-terminal tasks) — narrow it or it will serialize against most of the backlog |
| **271** | Finish the `parent_task` edge: declare in schema, validate, render in TODO, survive renumbering | After **279** (the per-field schema policy must land before another field is declared). Gates 273 |
| **272** | Honest session liveness for concurrent same-repo batches: diagnose why the wired heartbeat never fires, add a live-but-stale lock state, re-derive registry scope, give each orchestration its own identity | No outstanding dependency. Pairs naturally with the runtime-sweep defect in observations |
| **273** | Three-channel orchestration conclusion stage with per-channel approval, as a distinct post-postflight stage | After 271 and 184 (call B) |
| **275** | Per-repo orchestration queue: registered, live, archived on finish, consumed by admission | After 272 |
| **274** | Next-admissible-batch suggestion and alternatives-on-conflict, both computed by invoking the real admission script | Tail of everything: after 272, 273, 275, 165. Once it lands, this file's call groupings become computable rather than hand-maintained |

## Call E — record-versioning policy, and two live-observed contract defects (5)

```
/orchestrate 280, 281, 282
/orchestrate 284, 285
```

Two independent groups, filed after the eighth pass. The first is a **three-task chain** on
declared edges (280 ← 281 ← 282), deliberately split policy-then-consumers; run it as one call and
let the edges order it. The second pair is independent of everything and cheap.

| Task | What lands | Note |
|---|---|---|
| **280** | The rule that deliverables outside `specs/` describe the **current design only** and never narrate their own draft history, plus `lib/record-version-patterns.sh` as the single mechanical source of truth both consumers will share | Policy **and** mechanism; the consumers are deliberately later. Shaped exactly like its sibling `no-task-references-in-deliverables.md` |
| **281** | Repo-wide lint (`check-record-versioning.sh`) over every git-tracked file outside `specs/**`, driven entirely by the shared pattern library, plus its fixture test | Modeled line-for-line on `check-task-references.sh`. **Depends on 280** |
| **282** | PreToolUse hook blocking a Write/Edit that introduces forbidden record-version language into a deliverable, plus fixture test and `settings.json` registration | Must inherit `validate-no-task-references.sh`'s three contracts verbatim (exit 2 + stderr). **Depends on 280, 281** |
| **284** | Exempt the dispatching task's own task directory from the postflight `modified_files`-vs-`file_scope` excursion advisory | The advisory currently fires on **every** phase naming only the artifact that phase was dispatched to produce — pure noise that trains the reader to ignore a real signal. One file, narrow scope |
| **285** | `orchestrate-record-decision.sh` (a documented `.decisions.json` writer that does not exist), and the postflight handoff-recovery notice, which is both mislabelled and factually wrong about which phases write a handoff | Both confirmed again live in this pass's own run. One root: the contract tells the lead to do something unexecutable, or states something untrue |

---

## Checks before and after every call

- `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>`
  — **space-separated**; admits what you expect, `md5sum specs/state.json` unchanged. Research and
  plan dispatches are exempt from the self-modifying defer (`--phase-map`), so overlap only
  serializes at implement time.
- `bash .claude/scripts/validate-state.sh --deep` — 0 failures. **Two** `file_scope` warnings are
  expected today, both 270's. Treat any *new* warning as real. Re-measured: 18 passed, 2 warnings,
  0 failed.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — read the **end-of-run failure
  roster** and the `EXPECTED`/`NEW` split, not just the tally; exit code read directly (never
  through `tail`/`head`). A NEW failure is yours; an EXPECTED one is in `known-failures.txt` with
  a reason. `--fail-on-new` makes that a gate; `--jobs 4` is opt-in and reproduces the serial
  pass/fail set except under heavy contention.
- `bash .claude/scripts/verify-deploy.sh --skip-slow` — **currently FAIL, 3 of 33**. Until the
  three gates in Next are fixed this check is red for reasons unrelated to whatever you just
  changed, so measure it *before* your work as well as after, and compare. A self-modifying task
  is not finished until `.claude/` is resynced.
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
   surface in 165, and treat the live warnings as the first real input rather than noise to
   suppress. Measured coverage is uneven across repos — near-complete here, but only about 42% of
   BimodalLogic's non-terminal tasks carry the field, which is why 165's ruling splits by scope
   kind (in-batch blocking, cross-batch advisory) rather than issuing one blanket posture.
8. **Rule before mechanism** for the vimtex hazard. The rule shipped; the mechanism tasks stayed
   abandoned rather than conditional. Re-file only if the rule proves insufficient.
9. **Skeleton plans terminate through the completion-claim gate**; only the sorry-inventory
   follow-up report is ported (184). No `pr_ready` routing outside `type=pr`.
10. **No third automated deploy-trigger site.** The batch postflight defers its redeploy to the
    Inter-Cycle Redeploy Checkpoint. The sanctioned count stays at exactly two.
11. **One grant mechanism.** A push (or any otherwise-blocked git action) is authorized by one
    single-use token bound to action, remote, branch and sha, minted only where the harness can
    prove the user typed it. Nothing the model can write is a grant. PR/MR creation and `/merge`
    stay user-only (263).
12. **A grant may authorize a plain push of the default branch** (user ruling). Every force form on
    the default branch, bare `--force` anywhere, and all bulk or deletion refspecs stay
    categorically excluded, checked before any grant lookup. Rationale: `git-workflow.md`'s
    pre-existing "Never Run" is specifically force-to-master, and this repository's own working
    branch *is* master, so a blanket default-branch exclusion would exceed the rule being narrowed
    and make the mechanism unusable where it lives.
13. **`known-failures.txt` is the only known-failing list.** Advisory by construction: deleting or
    truncating it restores pre-manifest reporting exactly, and it never changes which suites run.
    Prose copies elsewhere are the drift mechanism that produced a stale list, so
    `shell-script-testing.md` points here instead of maintaining one. A `needs-owner` row is a
    known gap, not an accepted steady state.
14. **Gate 8's deployed-tree coverage is knowingly reduced** (agent-surfaced decision, accepted).
    `--skip-slow` on all 5 redeploy-checkpoint call sites bought 13m48s → 2m4s, at the cost of the
    ~40 core suites that resolve their subject-under-test from the *deployed* tree no longer being
    verified against a fresh deploy by this checkpoint. Accepted because a single dispatch had
    previously burned ~45 minutes and still terminated without writing its handoff. The narrower
    fix — running only those ~40 suites post-redeploy — is a live follow-up, not a settled
    dismissal; see observations.

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on
   reload.
2. **Propose, then apply, across repos.**
3. **Verify by execution, not by reading.** Every number here was measured the day it was written;
   re-measure before acting on it.
4. **The lead never reads a report, plan, summary, description, or context file during the loop.**
   This is a byte budget with a gate, not a paragraph.
5. **This file describes the current plan only.** It does not narrate its own revision history —
   no pass numbers, no "was X last pass" except where the delta itself is the finding a reader
   needs. 280 is about to make that a repo-wide rule with a lint behind it.

## Unfiled observations (none worth a task yet)

- **Gate 8's deployed-tree gap needs the narrow fix.** Per decision 14 the trade-off is accepted,
  but the follow-up it names does not exist as a task: run only the ~40 deploy-tree-first suites
  against Gate 8 post-redeploy, so the coverage returns without the 13-minute bill. **This is the
  observation here closest to deserving a task**, and it belongs with 265.
- **A checkpoint fire that must actually deploy still overruns.** With `--skip-slow` live on all
  five call sites, a checkpoint that found the tree stale, deployed, and re-verified exceeded a
  30-minute budget and was killed; the immediate re-run over the now-fresh tree finished in under
  500 s. So the residual cost is the *deploy plus full verify*, not Gate 8 — which is 265's
  `--skip-verify` half, not its `--jobs` half.
- **The deploy gate's refusal path works, and its remedy is not obvious.** A completion postflight
  whose `modified_files` touch `agent-system/extensions/**` is correctly refused with exit 6, and
  leaves `state.json` and the plan's `**Status**` header *both* unwritten — consistent, but the
  operator-visible remedy is `reconcile-task-status.sh <N> <session>`, not a re-run of postflight
  or `/orchestrate`. That is documented, but only inside a subsection about unwinding a dispatch.
- **The runtime-file sweep deletes the live run's own state.** `/todo`'s reap stage (and
  `reap-session-runtime-files.sh` generally) does not exclude the *active* session's runtime files,
  though a session registry exists for exactly that purpose. A sweep that took the `specs/` root
  from 72 stranded files to 0 also removed the in-flight batch's
  `.orchestrator-multi-state-<session>.json`, losing `completed_tasks`, `failed_tasks` and cycle
  bookkeeping mid-run. Recovered by hand from surviving `.dispatch/*.md` mtimes; an unattended run
  would have lost it silently. Belongs with 272's session-identity work.
- A `Monitor`-armed wait can never fire. An implementation agent armed a monitor for a long
  `run-all.sh`, went idle, and no event ever arrived — the dispatch stalled indefinitely until
  resumed by hand. Prefer in-band polling with productive work between checks over arm-and-idle.
- The runtime wave-split check (`orchestrate-cycle-plan.sh` step 4.5) defers a cross-batch scope
  collision on every run and records nothing. Persisting it as a `dependencies[]` edge is a
  one-line `state-write.sh` call, after 165 rules on absent scope.
- The write-time task-reference hook fires on files in the session scratchpad. Its path filter
  could exempt `/tmp/**`.
- A subagent parked on genuinely slow background work emits repeated interim notifications that
  read like stalling. Notification semantics, not agent behaviour.
- `commands/task.md`'s abandon mode documents the archive target as `completed_projects`; the live
  archive puts abandoned entries in `archived_projects` with `archived_at`. 44 rewrites that file
  and should fix the text.
- `/todo`'s archive-orphan scan checks only `completed_projects`, so correctly-tracked
  `archived_projects` entries surface as false orphans on every run. Harmless today because the
  prompt is declinable, but it is a real defect in `commands/todo.md` Step 2.5 and the mirrored
  `skill-todo` Stage 3.
- `plan-file-scope-harvest.sh` parses a `**Files to modify**:` field and finds nothing in a plan
  that uses a "Territory Contract" table instead. At least one BimodalLogic plan is invisible to
  the harvester for this reason.
- The in-scope agent set for a contract rolled across implementation agents is **14** files, not
  the 13 a sweep by directory suggests — `founder-implement-agent.md` also edits phase-heading
  markers.
