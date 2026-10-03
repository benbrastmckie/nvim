# Roadmap

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`.
Measured 2026-10-03.*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's.

**`MAX_TASKS` is 8**, enforced in `commands/orchestrate.md`. `orchestrate-cycle-plan.sh` itself
accepts any count, so a dry-run over more than 8 is not evidence a call will run them.

**Every open task is accounted for below**: Next 2 + in-flight 1 + A 3 + B 4 + C 3 + D 2 + E 6 +
F 2 + G 3 + H 3 + I 2 + J 4 = **35**. If that sum stops matching `state.json`, this file has
drifted — which it does within a day or two, because the structure is still hand-derived. Call G
fixes that.

**The deploy gates are green.** `verify-deploy.sh --skip-slow` returns **PASS — 33 checks, 0
failures**. Both reds that previously stood here are closed. Treat any new failure as real.

---

## Next

**One dispatch is still open.** Task **185** has all 9 phases committed (latest `7a89a7871`) but
never wrote its wrap-up artifacts: `.return-meta.json` still says `in_progress`, the handoff still
carries the *planner's* `dispatch_seq` 17 rather than the implement dispatch's 18, and no summary
exists. Until those three land, postflight cannot verify the completion claim and the task cannot
reach `[COMPLETED]`.

Its root cause is a known failure mode, now observed three times in one session: the agent armed a
background wait on the Gate 8 suite, went idle, and nothing resumed it. See the observations
section — prefer a bounded foreground run over arm-and-idle.

Then the next call:

```
/orchestrate 297, 327
```

| Task | What lands | Gating |
|---|---|---|
| **297** | Build the `books` extension in the source store: manifest, four-block routing, agents, skills, commands, rule, registration, tests. Wiring only; source store only | None. **Gates 298, 326** |
| **327** | Repair the extension lifecycle hook mechanism: broken resolver schema, absent return-code channel, uninvoked verification stage | None. Adjacent to 326, which rejects the lifecycle-hook route *for its own purpose* on evidence — that rejection is about `--gate`, not about leaving the mechanism broken |

**Consumer repos: all 8 are STALE.** `.dotfiles`, `BimodalLogic`, `ModelChecker`,
`PersonalWebsite`, `cslib`, `Logos/Hardware`, `Logos/Theory` and `PossibleWorlds` — the last of
which was fully fresh at the previous measurement and is now 61 commits behind on `core`. Several
cores are 225 behind. If the next work touches a consumer, run `deploy-headless.sh` **in that
repo** first; this repo never pushes into a consumer.

---

## Call A — commit-staging and git-exit correctness (3)

```
/orchestrate 322, 325, 318
```

All three are dispatchable now and all three gate **328**.

| Task | What lands | Gating |
|---|---|---|
| **322** | Fix `/todo`'s directory-move staging gap: a moved task directory's vacated SOURCE path is never staged, so every archival commit leaves the deletion half of each `mv` unstaged | None. A verified **regression** from the explicit-pathspec migration, found live during an archival run. **Gates 328** — it owns `commands/todo.md` and `skill-todo/SKILL.md`, the two files 328's folded-in `/todo` work also touches |
| **325** | Stop `git add`'s gitignore advisory exit code from aborting the whole commit when the named file is tracked and was in fact staged | None. Same class as 304: a non-fatal condition treated as fatal in a staging path |
| **318** | Wire `lint-directory-pathspec-boundary.sh` into `verify-deploy.sh` as a numbered gate | Now unblocked. The lint and its 14-case fixture test already exist and pass; only the gate wiring was missing, deferred because the target is an orchestrator-critical path. **Gates 328** — that script is one of the five in the lint duplication cluster 328 de-duplicates |

## Call B — orchestrator defects (4)

```
/orchestrate 299, 300, 311, 284
```

Four independent, all dispatchable now.

| Task | What lands | Gating |
|---|---|---|
| **299** | Guarantee a plan revision landing concurrently with a live implement dispatch is detected, via two complementary remedies | None. Mutual exclusion is asserted between aux *kinds*, never between an aux row and the implement row. Observed cost was real: one dispatch excerpted a phase pre-revision and another post-revision |
| **300** | Resolve `AskUserQuestion` being unreachable from a dispatched subagent: probe the mechanism, correct `agent-frontmatter-standard.md`'s tool-inheritance claim, rehome every user-choice gate inside a dispatched agent | None. **Gates 302, 312.** Carries the only remaining coarse `file_scope` — `scripts/tests/` overlaps **13** non-terminal tasks. Narrow it at plan time or it serializes most of the lane |
| **311** | Replace the static `BUILD_HEAVY_TASK_TYPES=("lean4" "cslib")` list with a measured or probed build-weight signal, and design the no-history fallback | None. The binding constraint on real parallelism for Lean-heavy batches: a Mathlib-free `lean4` package measured at 6 s wall / 17 jobs is refused co-scheduling exactly as a full Mathlib build is |
| **284** | Exempt the dispatching task's own task directory from the postflight `modified_files`-vs-`file_scope` excursion advisory | None. The advisory fires on **every** phase naming only the artifact it was dispatched to produce — pure noise that trains the reader to ignore a real signal. Confirmed live again across all six tasks of the last batch. One file |

## Call C — record-versioning policy (3)

```
/orchestrate 280, 281, 282
```

A three-task chain on declared edges (280 ← 281 ← 282) — run it as one call and let the edges
order it.

| Task | What lands | Gating |
|---|---|---|
| **280** | The rule that deliverables outside `specs/` describe the current design only and never narrate their own draft history, plus `lib/record-version-patterns.sh` as the shared mechanical source of truth | Policy **and** mechanism; consumers deliberately later. Shaped like its sibling `no-task-references-in-deliverables.md` |
| **281** | Repo-wide lint (`check-record-versioning.sh`) over every git-tracked file outside `specs/**`, driven by the shared pattern library, plus fixture test | After **280**. Modeled on `check-task-references.sh` |
| **282** | PreToolUse hook blocking a Write/Edit that introduces forbidden record-version language, plus fixture test and `settings.json` registration | After **280, 281**. Must inherit `validate-no-task-references.sh`'s three contracts verbatim (exit 2 + stderr). **Gates 312** |

## Call D — two contract defects (2)

```
/orchestrate 285, 319
```

| Task | What lands | Gating |
|---|---|---|
| **285** | `orchestrate-record-decision.sh` (a documented `.decisions.json` writer that does not exist), and the postflight handoff-recovery notice, which is mislabelled and factually wrong about which phases write a handoff | None. One root: the contract tells the lead to do something unexecutable, or states something untrue. Confirmed live — the lead had to hand-write `.decisions.json` for a non-blocking `user_decision` because no writer exists. **Gates 319** |
| **319** | Surface the blast radius of a machine-checked refutation: when research refutes a premise or closes a question by supersession, the other open tasks whose filed premises that falsifies must reach human triage | After **285**. Today nothing does this, so a refutation's reach is found only if a human hand-checks sibling descriptions. Observed repeatedly: three of six research dispatches in the last batch refuted their own task's filed premise |

## Call E — parent_task edge, liveness, conclusion stage, queue (6)

```
/orchestrate 271, 303, 272, 273, 275, 274
```

**A lane, not a flat batch.** 271 and 272 carry no outstanding dependency; the rest chain behind
them on declared edges, so one call orders itself.

| Task | What lands | Gating |
|---|---|---|
| **271** | Finish the `parent_task` edge: declare in schema, validate, render in TODO, survive renumbering | None. The per-field schema policy has landed. **Gates 273, 303** |
| **303** | Make `validate-state.sh`'s omitted-argument state-file default resolve against the repository being validated, not the invoking shell's CWD, and survey siblings for the same latent pattern | After **271**. Located at `validate-state.sh:241-243`; the script's own header documents the CWD-relative behaviour. **Gates 328** |
| **272** | Honest session liveness for concurrent same-repo batches: diagnose why the wired heartbeat never fires, add a live-but-stale lock state, re-derive registry scope, give each orchestration its own identity | None. Also owns the runtime-file sweep defect. Confirmed live again: a gate-in reported task 300's lock stale at **2636 minutes** since heartbeat — the heartbeat is not firing at all, exactly as filed |
| **273** | Three-channel orchestration conclusion stage with per-channel approval, as a distinct post-postflight stage | After **271** |
| **275** | Per-repo orchestration queue: registered, live, archived on finish, consumed by admission | After **272** |
| **274** | Next-admissible-batch suggestion and alternatives-on-conflict, both computed by invoking the real admission script | Tail of this lane: after **272, 273, 275** |

## Call F — books extension tail (2)

```
/orchestrate 298, 326
```

Both after **297** (see Next).

| Task | What lands | Gating |
|---|---|---|
| **298** | Author the domain context corpus under `context/project/books/` | After **297**, scoped to `context/project/books/**` only. Write against the design record (`docs/book-convention.md`, 18 accepted decisions; `book-toml-v2.md` normative) in Logos/Verification, not the half-landed tooling, and keep the known-gap register honest |
| **326** | Add a books verification tier at implement dispatch: the `--gate` flag mirroring `--compare` | After **297**. The lifecycle-hook route is rejected **with evidence** for this purpose; that is a scoping ruling about `--gate`, and does not bless leaving the hook mechanism broken — 327 repairs it |

## Call G — roadmap and TODO automation (3)

```
/orchestrate 306
/orchestrate 312, 313
```

**This group automates the hand-maintenance this file still depends on** — the accounting line, the
call groupings and the batch blocks are all hand-derived, and they go stale within a day of being
written. This rewrite is itself the evidence.

| Task | What lands | Gating |
|---|---|---|
| **306** | Turn this file into a generated artifact with a standardized format, its phase/batch structure derived from `state.json` dependencies | None. Verified motivation: `TODO.md`'s generated Dependency Waves table already contains exactly the waves a hand rewrite derives — this rewrite read them straight out of it. **Gates 313** |
| **312** | Require every new task to be compared against the open backlog before creation, via one shared `audit-open-tasks.sh` with a fixed verdict vocabulary and a semantic pass | After **300, 282**. Research must **rule** on the enforcement design (one state-write-boundary hook vs. per-surface wiring) rather than assume it. Its non-goal is load-bearing: no reconciliation verdict beyond a dependency edge may be applied silently to a task a human wrote. Would have caught 307/308/270 against 328 mechanically instead of by hand |
| **313** | Advisory lint validating hand-authored batch blocks here, so an under-inclusive batch is caught at authoring time | After **306, 328**. Observed failure: an agent removed a task from a batch *because* it depended on another task in that batch — wrong, since dispatch is dependency-aware and an intra-batch edge merely sequences them |

## Call H — script and test corpus efficiency (3)

```
/orchestrate 251, 170
/orchestrate 328
```

| Task | What lands | Gating |
|---|---|---|
| **251** | Context-reachability probe (filename, directory, `index.json`) with the 16 present templates as fixture; telemetry cross-check; remove what is dead | None. Cost only — the eager-load gate is green at 65923 B / 65950 B baseline. **Gates 170.** Its method is the one 328 must borrow for the *script* corpus rather than reinvent |
| **170** | Isolate shell suites from ambient host state (memory and timing axes); record the convention; repeated-run acceptance under load | After **251**. Committed target: `known-failures.txt`'s one `intermittent` row (`test-run-all-parallel.sh`) is exactly this class, and an absolute threshold was already tried and rejected there. **Gates 328** — it owns `context/standards/shell-script-testing.md`, the convention 328 refactors the test corpus against |
| **328** | Systematic top-to-bottom efficiency refactor of both corpora, driven by `script-inventory.sh`'s ranked output: de-duplicate the verified clusters into `lib/`, solve reachability honestly, cut Gate 8's cost, close real coverage gaps | The deepest-blocked task in the backlog: after **170, 318, 322, 304, 303**. Supersedes the three hand-filed point versions (307, 308, 270 — all abandoned into it). Measured input: 197 non-test scripts / 72,761 lines, 52 carrying duplicate blocks, a five-script lint cluster at ~2,012 lines with 115–132 shared non-comment lines per pair, and 157 of 197 scripts with no paired test. **Needs a `file_scope` before dispatch** — it has none, and its territory is unusually wide |

## Call I — staging lease and pathspec tolerance (2)

```
/orchestrate 302, 304
```

| Task | What lands | Gating |
|---|---|---|
| **302** | Replace the directory pathspec at every remaining staging site, and pass `--task` so `git-commit-scoped.sh`'s contended-path lease is actually consulted | After **300**. The lease exists (opt-in, fails open) and was simply never consulted. Shares `git-commit-scoped.sh` with 304 — distinct mechanisms, `file_scope` overlap serializes them without an edge |
| **304** | Make an out-of-repository path in a commit pathspec list non-fatal for the rest of the list | After **273, 284, 285, 302**. Its filing hypothesis is **false and must not be carried into research**: `return-metadata-file.md` already states the repo-relative constraint three times over. **Gates 328** — it owns the staging and exit-code contract every incremental refactor commit there rides on |

## Call J — Neovim and opencode hygiene (4)

```
/orchestrate 295, 296
/orchestrate 22, 29
```

Two independent pairs, independent of every agent-system lane.

| Task | What lands | Gating |
|---|---|---|
| **295** | Add the missing `desc` field to the 44 of 88 `vim.keymap.set` calls that lack one | 13 files. Violates this repo's own Lua Code Style standard |
| **296** | Three independent small fixes: delete the stale byte-identical `init.lua.backup`; regenerate the `project-overview.md` still carrying its `<!-- GENERIC TEMPLATE -->` notice; fix `README.md:185`'s link to a nonexistent `.claude/README.md` | No shared file between the three |
| **22** | Silence opencode fragment spam; fix the fake-tool line; record the frozen-mirror policy; honest `[Reload All]`/`[Regenerate]`; Global Update registry | Lua, not agent-system. **Gates 29** |
| **29** | `merge_targets.mcp` → repository-root `.mcp.json`; register obsidian-memory through it | After **22** |

---

## Checks before and after every call

- `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>`
  — **space-separated**; admits what you expect, `md5sum specs/state.json` unchanged. Research and
  plan dispatches are exempt from the self-modifying defer (`--phase-map`), so overlap only
  serializes at implement time.
- `bash .claude/scripts/validate-state.sh --deep` — **17 passed, 3 warnings, 0 failed.** All three
  warnings are `file_scope`: 300's coarse `scripts/tests/` (13 overlaps), 328's missing key, and
  the visibility summary line that reports it. Treat any *new* warning, and any failure, as real.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — read the **end-of-run failure
  roster** and the `EXPECTED`/`NEW` split, not just the tally; exit code read directly (never
  through `tail`/`head`). A NEW failure is yours; an EXPECTED one is in `known-failures.txt` with a
  reason. `--fail-on-new` makes that a gate; `--jobs 4` is opt-in and reproduces the serial
  pass/fail set except under heavy contention. Gate 8 is 117.9 s of a ~2.8 min full run — the
  dominant cost, and 328's target.
- `bash .claude/scripts/verify-deploy.sh --skip-slow` — **currently PASS, 33 checks, 0 failures.**
  Measure it *before* your work as well as after, and compare. A self-modifying task is not
  finished until `.claude/` is resynced.
- After any call that ran in a consumer: `check-consumer-freshness.sh` here, `deploy-headless.sh`
  **there** if STALE. **All 8 consumers are STALE right now**, several cores 225 behind.

---

## Settled decisions (do not re-litigate)

1. **Batch of one.** One engine; single-task is a batch of one. Team mode is deleted. Hard mode is
   kept in full and is per-invocation.
2. **The orchestrator never asks and never decides.** Only an agent-surfaced `user_decision`
   reaches the user, once, at cycle end. A `blocking: false` decision proceeds on the agent's own
   recommendation and is surfaced, not prompted.
3. **Research-first is the default** for a fresh task; `--fast` restores planner-first.
4. **`--dry-run` prints the plan it would dispatch.** There is no separate dry-run report.
5. **No fixed consumer validation gates.** The checks above are recommended, not blocking.
6. **A linear chain of small tasks that serialize on one file is one task with phases.** Apply at
   creation time.
7. **`file_scope` warnings are live input, not noise** — the analysis surface landed, so treat a
   coarse-declaration warning as real. In-batch collisions block; cross-batch ones are advisory.
8. **Rule before mechanism** for the vimtex hazard. Re-file a mechanism task only if the rule
   proves insufficient.
9. **Skeleton plans terminate through the completion-claim gate**, and the sorry-inventory
   follow-up report is now ported and live. No `pr_ready` routing outside `type=pr`.
10. **No third automated deploy-trigger site.** The batch postflight defers its redeploy to the
    Inter-Cycle Redeploy Checkpoint. The sanctioned count stays at exactly two.
11. **One grant mechanism.** A push (or any otherwise-blocked git action) is authorized by one
    single-use token bound to action, remote, branch and sha, minted only where the harness can
    prove the user typed it. Nothing the model can write is a grant. PR/MR creation and `/merge`
    stay user-only.
12. **A grant may authorize a plain push of the default branch** (user ruling). Every force form on
    the default branch, bare `--force` anywhere, and all bulk or deletion refspecs stay
    categorically excluded, checked before any grant lookup. Rationale: `git-workflow.md`'s
    pre-existing "Never Run" is specifically force-to-master, and this repository's working branch
    *is* master, so a blanket default-branch exclusion would exceed the rule being narrowed.
13. **`known-failures.txt` is the only known-failing list.** Advisory by construction: it never
    changes which suites run. Never keep a prose copy anywhere else — that is the drift mechanism.
    A `needs-owner` row is a known gap, not an accepted steady state.
14. **One shared working tree, always.** Per-dispatch `git worktree` isolation is removed, not
    narrowed — no selection predicate survives. Concurrency safety rests entirely on declared
    `file_scope`, dependency edges, and the five contention inputs already in service. Build
    contention, the one hazard `file_scope` cannot reach, is closed by refusing to co-schedule two
    build-heavy implement tasks in one cycle, not by isolation and not by a PATH shim. Cost was not
    the reason for removal and must not be cited as it: provisioning was measured cheap. Full
    record: `specs/decisions/worktree-isolation-removal-verdict.md`.
15. **Gate 8's deployed-tree coverage is knowingly reduced** (accepted trade-off). The redeploy
    checkpoint runs `--skip-slow`, so the ~40 core suites that resolve their subject-under-test
    from the *deployed* tree are not verified against a fresh deploy there. Accepted on wall-clock
    grounds. The narrower fix is no longer unowned: it is in **328**'s declared scope.
16. **A systemic cost is filed as one standing task against a probe's output, not as a stream of
    point defects.** Duplication, dead code and slow tests never break anything, so the
    defect-driven intake cannot see them; 328 is the standing consumer of `script-inventory.sh`,
    and three hand-filed point versions (307, 308, 270) were abandoned into it rather than run
    alongside it.

## Standing rules

1. **Agent-system defects get filed here.** A fix in a consuming repo's `.claude/` is wiped on
   reload.
2. **Propose, then apply, across repos.**
3. **Verify by execution, not by reading.** Every number here was measured the day it was written;
   re-measure before acting on it.
4. **The lead never reads a report, plan, summary, description, or context file during the loop.**
   A byte budget with a gate, not a paragraph.
5. **This file describes the current plan only.** It does not narrate its own revision history —
   no pass numbers, no "was X last pass" except where the delta itself is the finding. 280 makes
   that a repo-wide rule with a lint behind it.

## Unfiled observations (none worth a task yet)

- **An arm-and-idle background wait does not fire, and it strands the dispatch.** Observed **three
  times in one session** on a single implementation dispatch: the agent armed a wait on a long
  `run-all.sh`, reported itself idle, and nothing ever resumed it — all nine phases were committed
  but the wrap-up artifacts were never written, leaving the task unverifiable at postflight.
  Recovery took three successive hand nudges, the last of which had to forbid the pattern outright.
  **Now the strongest candidate here for a real task**: prefer a bounded foreground run
  (`timeout N bash ...; echo "EXIT=$?"`) over arming a monitor, and consider making that a contract
  line in the implementation-agent body rather than advice in this file.
- **A rendered `**Goal**:` line in `TODO.md` cannot survive regeneration, and fails validation
  while present.** `generate-task-order.sh --goal` writes the line; `generate-todo.sh` drops it
  entirely and reads `active_goal` from `state.json` not at all. So the two generators disagree,
  and a `TODO.md` carrying the line is reported OUT OF SYNC by `validate-state.sh --deep`. Net
  effect: `state.json`'s `active_goal` is write-only, and the displayed goal is permanently blank.
  Belongs with 306.
- **The deploy gate's refusal remedy is not discoverable.** A completion postflight whose
  `modified_files` touch `agent-system/extensions/**` is correctly refused with exit 6, leaving
  `state.json` and the plan's `**Status**` header both unwritten. The Inter-Cycle Redeploy
  Checkpoint then promotes the task on the next cycle automatically — observed working on five
  tasks in one batch — so the hazard is only that an operator reading the exit-6 text alone cannot
  tell that no action is required. The remedy for the genuinely stuck case is
  `reconcile-task-status.sh <N> <session>`, documented only inside a subsection about unwinding a
  dispatch.
- **The probe's `inbound_callers` field cannot find dead code**, and reports zero zero-caller
  scripts across 197 files, because a script's own `manifest.json` entry counts as a caller of its
  basename. Its `has_test` field is a filename-convention check and under-reports coverage the same
  way. Both are recorded inside 328 so they are not mistaken for answers.
- `plan-file-scope-harvest.sh` parses a `**Files to modify**:` field and finds nothing in a plan
  using a "Territory Contract" table instead. At least one BimodalLogic plan is invisible to the
  harvester for this reason.
- The write-time task-reference hook fires on files in the session scratchpad. Its path filter
  could exempt `/tmp/**`.
- A subagent parked on genuinely slow background work emits repeated interim notifications that
  read like stalling. Notification semantics, not agent behaviour.
- The in-scope agent set for a contract rolled across implementation agents is **14** files, not
  the 13 a sweep by directory suggests — `founder-implement-agent.md` also edits phase-heading
  markers.
