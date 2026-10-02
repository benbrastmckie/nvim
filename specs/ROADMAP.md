# Roadmap

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`.
Measured 2026-10-02.*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's.

**`MAX_TASKS` is 8**, enforced in `commands/orchestrate.md`. `orchestrate-cycle-plan.sh` itself
accepts any count, so a dry-run over more than 8 is not evidence a call will run them.

**Every open task is accounted for below**: Next 2 + A 3 + B 6 + C 4 + D 6 + E 5 + F1 4 + F2 5 +
F3 5 + F4 2 + F5 2 = **44**. If that sum stops matching `state.json`, this file has drifted — which
it does within a day or two, because the structure is still hand-derived. Call F3 fixes that.

---

## Next

**Two deploy gates are red, both filed, both cheap.** `verify-deploy.sh --skip-slow` returns
**FAIL — 2 of 33**:

```
/orchestrate 323, 324
```

| Task | What lands | Gating |
|---|---|---|
| **323** | Declare `scripts/migrate-state-legacy-fields.sh` in core's `provides.scripts` (gate 3 doc-lint) | None. The script shipped and deployed without its manifest entry; the filing task is archived, so nothing else returns to it. Also refresh `core/README.md`'s inventory |
| **324** | Whitelist `.claude/scheduled_tasks.lock` in `is_runtime_artifact()` (gate 13 orphan detection) | None. A session-acquired runtime lock, same class as the already-exempt `tmp/workflow-active-*` and `RESUME.md`. False red whenever a scheduled task has run |

One is a real parity violation the gate correctly caught; the other is the gate crying wolf. Fix
both together — leaving the false positive is what makes the true one easy to dismiss.

**Consumer repos: 7 of 8 are STALE** (`.dotfiles`, `BimodalLogic` 5/7 extensions, `cslib`,
`Logos/Hardware`, `Logos/Theory`, `ModelChecker`, `PersonalWebsite`; `PossibleWorlds` is fully
fresh). If the next work touches a consumer, run `deploy-headless.sh` **in that repo** first.

---

## Call A — push consent, admission posture, checkpoint cost (3)

```
/orchestrate 263, 165, 265
```

All three are `planned` with plans in hand; each needs only its implement phase.

| Task | What lands | Gating |
|---|---|---|
| **263** | One grant token; `/please` mint hook with integrity; push guard; grant check in the destructive-git guard; user-only command, never-list, rule exception | 13-phase plan. Push scope is settled (decisions 11–12). `skill-orchestrate/SKILL.md` has **7 B** of headroom under gate 20 — offset any growth byte-for-byte |
| **165** | Admission posture for an absent `file_scope`; cross-session visibility for self-modifying candidates | 6-phase plan, fully sequential. Also closes a found defect: `orchestrate-cycle-plan.sh`'s `defer_reason` `case` has no default arm, so a new reason drops a task from dispatch with no ledger entry. **Gates 274, 312** |
| **265** | Gate 8 via `run-all.sh --jobs`; `deploy-headless.sh --skip-verify` with a distinct exit 4 | 8-phase plan, currently `implementing` at phase 1. **`--skip-verify` is the urgent half** — the fix for the deploy that overruns 30 min. **Gates 250, 318** |

Implement-phase serialization: **165 → 265 → 263**, now pinned by serialization-only
`dependencies` edges (265 declares 165; 263 declares 265), so the order holds regardless of the
argument order typed above. The edges are ordering devices, not semantic ones — neither task
consumes the other's output; rebase on whatever lands. Without them all three are self-modifying
candidates and the engine admits one per cycle by **lowest task number**, which would give
165 → 263 → 265 and push the urgent `--skip-verify` half behind a 13-phase task.

## Call B — cost, clutter, corpus probe (6)

```
/orchestrate 250, 89, 127, 217, 185, 184
```

| Task | What lands | Gating |
|---|---|---|
| **250** | Script-inventory probe; decompose `orchestrate-cycle-plan.sh` into `lib/`, byte-identical `--dry-run` | After **265**, so the file is quiet |
| **89** | Mode-gate `skill-literature` (84 KB) and `skill-distill` (93 KB) | ~24.8k tokens per invocation. **Cost only** — the eager-load gate is green |
| **127** | Collapse the routing ladder to the two agent blocks; retire `command-route-skill.sh`; lint nonexistent agent targets | Clears the gate 16 WARN (`lean` still declares `routing_hard`/`routing_agents_hard`). The warning's own text is misleading: `hard_contracts` resolves contract files, not skill or agent names |
| **217** | `/refresh` PSS accounting, CPU-delta idleness, prompt-never-kill | Utility, not engine |
| **185** | Retarget live "Stage N" / "Stage MT-N" citations to Move vocabulary; keep historical ones | After **184**. Research adds the rest of the 72 files to scope |
| **184** | Skeleton-plan `sorry_inventory` follow-ups reported append-only at completion | Clear. **Gates 273, 304** |

## Call C — reachability, test isolation, picker lane (4)

```
/orchestrate 251, 170, 22, 29
```

| Task | What lands | Gating |
|---|---|---|
| **251** | Context-reachability probe (filename, directory, `index.json`) with the 16 present templates as fixture; telemetry cross-check; remove what is dead | After **127**. Cost only — the eager-load gate is green |
| **170** | Isolate shell suites from ambient host state (memory and timing axes); record the convention; repeated-run acceptance under load | After **250, 251**. Committed target: `known-failures.txt`'s one `intermittent` row (`test-run-all-parallel.sh`) is exactly this class, and an absolute threshold was already tried and rejected there |
| **22** | Silence opencode fragment spam; fix the fake-tool line; record the frozen-mirror policy; honest `[Reload All]`/`[Regenerate]`; Global Update registry | Lua, not agent-system |
| **29** | `merge_targets.mcp` → repository-root `.mcp.json`; register obsidian-memory through it | After **22** |

## Call D — orchestrator queue, liveness, conclusion stage; null safety (6)

```
/orchestrate 270, 271, 272, 273, 274, 275
```

**A lane, not a runnable batch of 6.** 270 and 272 carry no outstanding dependency; the others
chain behind calls A and B. Run those first, or dispatch the front pair alone.

| Task | What lands | Gating |
|---|---|---|
| **270** | Re-runnable null-safety audit of jq mutation sites across core scripts; rule on a shared guard idiom in `scripts/lib/` | None. `file_scope` narrowed to the anticipated check script and its test, the one confirmed defect site (`orchestrate-build-dispatch.sh:389-392`), the inventory doc, and `scripts/lib/` — which still overlaps 3 tasks (263, 280, 281). Widen at plan postflight if the audit finds more sites |
| **272** | Honest session liveness for concurrent same-repo batches: diagnose why the wired heartbeat never fires, add a live-but-stale lock state, re-derive registry scope, give each orchestration its own identity | None. Also owns the runtime-file sweep defect: `/todo`'s reap does not exclude the *active* session's runtime files, and a sweep took an in-flight batch's multi-state file, losing `completed_tasks` and cycle bookkeeping mid-run |
| **271** | Finish the `parent_task` edge: declare in schema, validate, render in TODO, survive renumbering | The per-field schema policy has landed. **Gates 273, 303** |
| **273** | Three-channel orchestration conclusion stage with per-channel approval, as a distinct post-postflight stage | After **271, 184** |
| **275** | Per-repo orchestration queue: registered, live, archived on finish, consumed by admission | After **272** |
| **274** | Next-admissible-batch suggestion and alternatives-on-conflict, both computed by invoking the real admission script | Tail of everything: after **272, 273, 275, 165** |

## Call E — record-versioning policy, and two contract defects (5)

```
/orchestrate 280, 281, 282
/orchestrate 284, 285
```

Two independent groups. The first is a three-task chain on declared edges (280 ← 281 ← 282) —
run it as one call and let the edges order it. The second pair is independent and cheap.

| Task | What lands | Gating |
|---|---|---|
| **280** | The rule that deliverables outside `specs/` describe the current design only and never narrate their own draft history, plus `lib/record-version-patterns.sh` as the shared mechanical source of truth | Policy **and** mechanism; consumers deliberately later. Shaped like its sibling `no-task-references-in-deliverables.md` |
| **281** | Repo-wide lint (`check-record-versioning.sh`) over every git-tracked file outside `specs/**`, driven by the shared pattern library, plus fixture test | After **280**. Modeled on `check-task-references.sh` |
| **282** | PreToolUse hook blocking a Write/Edit that introduces forbidden record-version language, plus fixture test and `settings.json` registration | After **280, 281**. Must inherit `validate-no-task-references.sh`'s three contracts verbatim (exit 2 + stderr). **Gates 312** |
| **284** | Exempt the dispatching task's own task directory from the postflight `modified_files`-vs-`file_scope` excursion advisory | None. The advisory fires on **every** phase naming only the artifact it was dispatched to produce — pure noise that trains the reader to ignore a real signal. One file |
| **285** | `orchestrate-record-decision.sh` (a documented `.decisions.json` writer that does not exist), and the postflight handoff-recovery notice, which is mislabelled and factually wrong about which phases write a handoff | None. One root: the contract tells the lead to do something unexecutable, or states something untrue. **Gates 319** |

---

## Call F — filings not yet in a lettered lane (18)

Five groups by theme; each runnable on its own, and **none may be merged into one call**.

### F1 — commit-staging correctness (4)

```
/orchestrate 322, 302, 304
/orchestrate 318
```

| Task | What lands | Gating |
|---|---|---|
| **322** | Fix `/todo`'s directory-move staging gap: a moved task directory's vacated SOURCE path is never staged, so every archival commit leaves the deletion half of each `mv` unstaged | None. A verified **regression** from the explicit-pathspec migration, found live during an archival run |
| **302** | Replace the directory pathspec at every remaining staging site, and pass `--task` so `git-commit-scoped.sh`'s contended-path lease is actually consulted | After **300**. The lease exists (opt-in, fails open) and was simply never consulted. Shares `git-commit-scoped.sh` with 304 — distinct mechanisms, `file_scope` overlap serializes them without an edge |
| **304** | Make an out-of-repository path in a commit pathspec list non-fatal for the rest of the list | After **184, 263, 273, 284, 285** — the deepest-blocked task in the backlog. Its filing hypothesis is **false and must not be carried into research**: `return-metadata-file.md` already states the repo-relative constraint three times over |
| **318** | Wire `lint-directory-pathspec-boundary.sh` into `verify-deploy.sh` as a numbered gate | After **265**. The lint and its 14-case fixture test already exist and pass; only the gate wiring is missing, deferred because the target is an orchestrator-critical path |

### F2 — orchestrator defects (5)

```
/orchestrate 299, 300, 303, 311
/orchestrate 319
```

| Task | What lands | Gating |
|---|---|---|
| **299** | Guarantee a plan revision landing concurrently with a live implement dispatch is detected, via two complementary remedies | None. Mutual exclusion is asserted between aux *kinds*, never between an aux row and the implement row. Observed cost was real: one dispatch excerpted a phase pre-revision and another post-revision |
| **300** | Resolve `AskUserQuestion` being unreachable from a dispatched subagent: probe the mechanism, correct `agent-frontmatter-standard.md`'s tool-inheritance claim, rehome every user-choice gate inside a dispatched agent | None. **Gates 302, 312.** Carries the worst remaining coarse `file_scope` — `scripts/tests/` overlaps 18 non-terminal tasks. Narrow it at plan time or it serializes most of the lane |
| **303** | Make `validate-state.sh`'s omitted-argument state-file default resolve against the repository being validated, not the invoking shell's CWD, and survey siblings for the same latent pattern | After **271**. Located at `validate-state.sh:241-243`; the script's own header documents the CWD-relative behaviour |
| **311** | Replace the static `BUILD_HEAVY_TASK_TYPES=("lean4" "cslib")` list with a measured or probed build-weight signal, and design the no-history fallback | None. The binding constraint on real parallelism for Lean-heavy batches: a Mathlib-free `lean4` package measured at 6 s wall / 17 jobs is refused co-scheduling exactly as a full Mathlib build is |
| **319** | Surface the blast radius of a machine-checked refutation: when research refutes a premise or closes a question by supersession, the other open tasks whose filed premises that falsifies must reach human triage | After **285**. Today nothing does this, so a refutation's reach is found only if a human hand-checks sibling descriptions. Observed live in a five-task BimodalLogic run |

### F3 — roadmap and TODO automation (5)

```
/orchestrate 306, 307, 308, 313
/orchestrate 312
```

The first four are a chain on declared edges (306 ← 307, 308 ← 313). **This group automates the
hand-maintenance this file still depends on** — the accounting line, the call groupings and the
batch blocks are all hand-derived, and they go stale within a day of being written.

| Task | What lands | Gating |
|---|---|---|
| **306** | Turn this file into a generated artifact with a standardized format, its phase/batch structure derived from `state.json` dependencies | None. Verified motivation: `TODO.md`'s generated Dependency Waves table already contains exactly the waves a hand rewrite derives. **Gates 307, 308, 313** |
| **307** | Make `/todo` faster and cheaper, and wire it to the roadmap prune mode | After **306**. **Phase order is a requirement**: consolidate the duplicated implementation first (`skill-todo/SKILL.md` hand-implements the same 16 stages `commands/todo.md` does, and the command never dispatches it). Frame as consolidation, not deletion — the skill is registered and directly invocable |
| **308** | Wire `/review` to regenerate this file completely, and remove redundant work from the command | After **306**. Also collapses ten jq processes into one pass and removes a duplicated `generate-todo.sh` invocation. **Constraint**: the missing-script and non-zero-exit guards plus the always-on structure marker must survive — they are what stops a regeneration no-op from masquerading as success |
| **313** | Advisory lint validating hand-authored batch blocks here, so an under-inclusive batch is caught at authoring time | After **306, 308**. Observed failure: an agent removed a task from a batch *because* it depended on another task in that batch — wrong, since dispatch is dependency-aware and an intra-batch edge merely sequences them |
| **312** | Require every new task to be compared against the open backlog before creation, via one shared `audit-open-tasks.sh` with a fixed verdict vocabulary and a semantic pass | After **165, 300, 282**. Research must **rule** on the enforcement design (one state-write-boundary hook vs. per-surface wiring) rather than assume it. Its non-goal is load-bearing: no reconciliation verdict beyond a dependency edge may be applied silently to a task a human wrote |

### F4 — the books extension (2)

```
/orchestrate 297, 298
```

| Task | What lands | Gating |
|---|---|---|
| **297** | Build the `books` extension in the source store: the `books` task type for authoring, certifying and documenting lean books | None. Owns the extension's **wiring** only — manifest, four-block routing, agents, skills, commands, rule, registration, tests. Source store only. **Gates 298** |
| **298** | Author the domain context corpus under `context/project/books/` | After **297**, scoped to `context/project/books/**` only. Write against the design record (`docs/book-convention.md`, 18 accepted decisions; `book-toml-v2.md` normative) in Logos/Verification, not the half-landed tooling, and keep the known-gap register honest |

### F5 — Neovim config hygiene (2)

```
/orchestrate 295, 296
```

Independent of each other and of every agent-system lane.

| Task | What lands | Gating |
|---|---|---|
| **295** | Add the missing `desc` field to the 44 of 88 `vim.keymap.set` calls that lack one | 13 files. Violates this repo's own Lua Code Style standard |
| **296** | Three independent small fixes: delete the stale byte-identical `init.lua.backup`; regenerate the `project-overview.md` still carrying its `<!-- GENERIC TEMPLATE -->` notice; fix `README.md:185`'s link to a nonexistent `.claude/README.md` | No shared file between the three |

---

## Checks before and after every call

- `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>`
  — **space-separated**; admits what you expect, `md5sum specs/state.json` unchanged. Research and
  plan dispatches are exempt from the self-modifying defer (`--phase-map`), so overlap only
  serializes at implement time.
- `bash .claude/scripts/validate-state.sh --deep` — **18 passed, 2 warnings, 0 failed.** Both
  warnings are coarse `file_scope`: 300's `scripts/tests/` (18 overlaps) and 270's `scripts/lib/`
  (3). Treat any *new* warning, and any failure, as real.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — read the **end-of-run failure
  roster** and the `EXPECTED`/`NEW` split, not just the tally; exit code read directly (never
  through `tail`/`head`). A NEW failure is yours; an EXPECTED one is in `known-failures.txt` with a
  reason. `--fail-on-new` makes that a gate; `--jobs 4` is opt-in and reproduces the serial
  pass/fail set except under heavy contention.
- `bash .claude/scripts/verify-deploy.sh --skip-slow` — **currently FAIL, 2 of 33**: gate 3
  (doc lint, 323) and gate 13 (orphan detection, 324). Until those land this check is red for two
  known reasons, so measure it *before* your work as well as after, and compare. A self-modifying
  task is not finished until `.claude/` is resynced.
- After any call that ran in a consumer: `check-consumer-freshness.sh` here, `deploy-headless.sh`
  **there** if STALE. 7 of 8 consumers are STALE right now.

---

## Settled decisions (do not re-litigate)

1. **Batch of one.** One engine; single-task is a batch of one. Team mode is deleted. Hard mode is
   kept in full and is per-invocation.
2. **The orchestrator never asks and never decides.** Only an agent-surfaced `user_decision`
   reaches the user, once, at cycle end.
3. **Research-first is the default** for a fresh task; `--fast` restores planner-first.
4. **`--dry-run` prints the plan it would dispatch.** There is no separate dry-run report.
5. **No fixed consumer validation gates.** The checks above are recommended, not blocking.
6. **A linear chain of small tasks that serialize on one file is one task with phases.** Apply at
   creation time.
7. **No analysis surface over `file_scope` until the field is reliably populated** — condition now
   met, so build the surface in 165 and treat live warnings as real input, not noise. Coverage is
   uneven across repos (complete here, ~42% of BimodalLogic's non-terminal tasks), which is why
   165's ruling splits by scope kind: in-batch blocking, cross-batch advisory.
8. **Rule before mechanism** for the vimtex hazard. Re-file a mechanism task only if the rule
   proves insufficient.
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
    grounds; the narrower fix is a live follow-up, not a settled dismissal — see observations.

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

- **A rendered `**Goal**:` line in `TODO.md` cannot survive regeneration, and fails validation
  while present.** `generate-task-order.sh --goal` writes the line; `generate-todo.sh` drops it
  entirely and reads `active_goal` from `state.json` not at all. So the two generators disagree,
  and a `TODO.md` carrying the line is reported OUT OF SYNC by `validate-state.sh --deep`. Net
  effect: `state.json`'s `active_goal` is write-only, and the displayed goal is permanently blank.
  **Closest here to deserving a task**, and it belongs with 306/308.
- **Gate 8's deployed-tree gap needs the narrow fix.** Per decision 15 the trade-off is accepted,
  but the follow-up it names does not exist as a task: run only the ~40 deploy-tree-first suites
  against Gate 8 post-redeploy, so coverage returns without the 13-minute bill. Belongs with 265.
- **The deploy gate's refusal remedy is not discoverable.** A completion postflight whose
  `modified_files` touch `agent-system/extensions/**` is correctly refused with exit 6, leaving
  `state.json` and the plan's `**Status**` header both unwritten. The operator-visible remedy is
  `reconcile-task-status.sh <N> <session>`, not a re-run of postflight or `/orchestrate` —
  documented, but only inside a subsection about unwinding a dispatch.
- `plan-file-scope-harvest.sh` parses a `**Files to modify**:` field and finds nothing in a plan
  using a "Territory Contract" table instead. At least one BimodalLogic plan is invisible to the
  harvester for this reason.
- The write-time task-reference hook fires on files in the session scratchpad. Its path filter
  could exempt `/tmp/**`.
- **A `Monitor`-armed wait can never fire.** An implementation agent armed a monitor for a long
  `run-all.sh`, went idle, and no event arrived — the dispatch stalled until resumed by hand.
  Prefer in-band polling with productive work between checks over arm-and-idle.
- A subagent parked on genuinely slow background work emits repeated interim notifications that
  read like stalling. Notification semantics, not agent behaviour.
- The in-scope agent set for a contract rolled across implementation agents is **14** files, not
  the 13 a sweep by directory suggests — `founder-implement-agent.md` also edits phase-heading
  markers.
