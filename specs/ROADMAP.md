# Roadmap

*Forward-only: what remains, in what order, and the checks that gate each step. Finished work is
removed, not archived here — it lives in git history, task summaries and `specs/archive/`.
Measured 2026-10-01.*

## Goal

`/orchestrate` is the only lifecycle entry point, and the orchestrator is token-cheap by
construction: it delegates, reads back compact verdicts, and asks the user only when a decision is
genuinely the user's.

What remains splits into seven lanes: **the one red deploy gate** (blocking — see Next), **the
pathspec hard error and the state schema** (call 0), **push consent and admission posture**
(call A), **cost and clutter** (calls B and C), **the orchestrator's own operational surface**
(queue, liveness, conclusion stage — call D), **record-versioning policy plus two contract
defects** (call E), and **the newer filings not yet slotted into a lane** (call F). Orthogonal to
all seven: the consumer repos have drifted badly STALE.

**`MAX_TASKS` is 8**, enforced in `commands/orchestrate.md` (the command truncates to the first 8
with a warning); `orchestrate-cycle-plan.sh` itself accepts any count, so a dry-run over more than
8 is not evidence a call will run them.

**Every open task is accounted for below**: 0 → 2 + A 4 + B 8 + C 4 + D 7 + E 5 + F 18 = 48. If
that sum stops matching `state.json`, this file has drifted. Call 306 makes this accounting
generated rather than hand-maintained, which is why it is filed.

---

## Next

**One gate is red, and it is already filed.** `verify-deploy.sh --skip-slow` returns **FAIL — 1 of
33**, and the single failure is gate 5 (manifest-driven content-hash equality) reporting exactly
three findings:

```
core: Content differs from source: context/contracts/adversarial-verification.md
core: Content differs from source: context/contracts/anti-analysis.md
core: Content differs from source: context/contracts/reference-grounding.md
```

Those are the three paths **290** names as standing false positives: the deployed copies match the
`lean` extension's deliberate override and parity-copy sources byte-for-byte, and `verify.lua`
compares only against core's copy with no notion of which extension legitimately won the path. So
the blocking gate needs no new task — **run 290 before call A.**

**Two gates that used to be red are now green**, and nothing here should still be planned around
them: the postflight boundary lint passes over the full corpus, and the eager-load total is
**65,663 B against a 65,950 B baseline** (under, with gate 20's per-file ceilings also passing —
`commands/orchestrate.md` 19,024 / 21,000 and `skills/skill-orchestrate/SKILL.md` 19,993 / 20,000,
the latter on 7 B of headroom). 89 and 251 in calls B and C are still worth running on cost
grounds, but they are **no longer load-bearing for a red gate**.

Then: **the consumer repos are STALE across the board.** If the next work touches a consumer, run
`deploy-headless.sh` there before dispatching into it.

**Interim exposure, stated rather than assumed.** The worktree isolation layer is gone (decision
14), so the `nothing_to_land` destructive-release path it hosted is gone with it. No open task
still assumes that layer exists.

---

## Call 0 — the pathspec hard error, and the state schema (2)

```
/orchestrate 277, 279
```

Independent of each other and of everything else. The worktree collapse that used to lead this
lane has landed; the ruling it implemented is recorded in
`specs/decisions/worktree-isolation-removal-verdict.md` and is **not re-openable**.

| Task | What lands | Note |
|---|---|---|
| **277** | Make an unresolvable pathspec a **hard error** in `git-commit-scoped.sh` instead of a silent WARN-and-drop | Cause-agnostic: drop-and-continue turns a typo, an unset variable, or a renamed artifact path into a false success on the single sanctioned commit path. The difficulty is the call-site audit — a postflight legitimately passes artifact paths its phase did not produce. Blocks 304 (call F) |
| **279** | State schema rejects live orchestration fields; decide the per-field policy and ship a migration tool if one is warranted | `planned`, needs only its implement phase. **Gates 271** (call D) and 303 (call F) |

---

## Call A — push consent, admission posture, checkpoint cost (4)

```
/orchestrate 263, 165, 265, 241
```

All four are `planned` with plans in hand; each needs only its implement phase. Run 290 (Next)
first.

| Task | What lands | Note |
|---|---|---|
| **263** | One grant token; `/please` mint hook with integrity; push guard; grant check in the destructive-git guard; user-only command, never-list, rule exception; dispatch relay + two-cycle non-replay test | 13-phase plan. Push-scope question is **settled** (decisions 11–12). `SKILL.md` now has only 7 B of headroom — offset any growth byte-for-byte |
| **165** | Admission posture for an absent `file_scope`; cross-session visibility for self-modifying candidates | 6-phase plan, fully sequential. Also closes a found defect: the `defer_reason` consumer `case` in `orchestrate-cycle-plan.sh` has no default arm, so a new reason would drop a task from dispatch with no ledger entry. **Gates 312** (call F) |
| **265** | Gate 8 via `run-all.sh --jobs` (conservative default + env override); `deploy-headless.sh --skip-verify` with a distinct exit 4 | 8-phase plan, all single-phase waves. **`--skip-verify` is the urgent half**: it is the fix for the deploying fire that overruns 30 min. The `--jobs` half buys much less, since Gate 8 is no longer the dominant checkpoint cost |
| **241** | Drop two playwright grant lists and five dead `mcp_servers` fields; fix ownership doc and nix README | 7-phase plan, 2.75 h. 10 files: `web/.../playwright-mcp-guide.md`'s Permission-Tiers section is also falsified. Re-verify the user-scope grant count is 9 first |

Implement-phase serialization: **165 → 265 → 263** (self-modifying, lowest first). This is
sequencing advice, not a dependency edge — none of the three declares the others, and `file_scope`
overlap already handles admission. 241 is outside the self-modifying gate and can run alongside any
of them.

## Call B — cost, clutter, corpus probe (8)

```
/orchestrate 250, 89, 44, 127, 217, 39, 185, 184
```

| Task | What lands | Note |
|---|---|---|
| **250** | Script-inventory probe; decompose `orchestrate-cycle-plan.sh` into `lib/`, byte-identical `--dry-run` | Wait on 265 (call A) so the file is quiet |
| **89** | Mode-gate `skill-literature` (84 KB) and `skill-distill` (93 KB) | ~24.8k tokens per invocation. Cost only now — the eager-load gate is green |
| **44** | Slim `commands/task.md` (41 KB per `/task`) into lazy context files | `planned`; implement dispatch first. Also fixes its abandon-mode text (the live archive puts abandoned entries in `archived_projects` with `archived_at`, not `completed_projects`). Blocks 302 (call F) |
| **127** | Collapse the routing ladder to the two agent blocks; retire `command-route-skill.sh`; lint nonexistent agent targets | Clears the gate 16 WARN (`lean` still declares `routing_hard`/`routing_agents_hard`). Note the warning's own text is misleading: `hard_contracts` resolves injected contract files, not skill or agent names |
| **217** | `/refresh` PSS accounting, CPU-delta idleness, prompt-never-kill | Utility, not engine |
| **39** | Zotero metadata resolution; MCP decision; quota gate; Zotero 10 swap plan | `planned`. Needs the dotfiles translation-server |
| **185** | Retarget live "Stage N" / "Stage MT-N" citations to Move vocabulary; keep historical ones | Still after 184. Research adds the rest of the 72 files to scope |
| **184** | Skeleton-plan `sorry_inventory` follow-ups reported append-only at completion | Gate clear. Gates 273 (call D) and 304 (call F) |

## Call C — reachability, test isolation, picker lane (4)

```
/orchestrate 251, 170, 22, 29
```

| Task | What lands | Note |
|---|---|---|
| **251** | Context-reachability probe (filename, directory, `index.json`) with the 16 present templates as the fixture; telemetry cross-check; remove what is genuinely dead | After 44, 127. Cost only now — the eager-load gate is green |
| **170** | Isolate shell suites from ambient host state (memory and timing axes); record the convention; repeated-run acceptance under load | After 250, 251. Concrete committed target: `known-failures.txt`'s one `intermittent` row (`test-run-all-parallel.sh`) is exactly this class, and an absolute threshold was already tried and rejected there |
| **22** | Silence opencode fragment spam; fix the fake-tool line; record the frozen-mirror policy; honest `[Reload All]`/`[Regenerate]`; Global Update registry | Lua, not agent-system |
| **29** | `merge_targets.mcp` → repository-root `.mcp.json`; register obsidian-memory through it | After 22, 241 |

## Call D — orchestrator queue, liveness, conclusion stage; build guard, null safety (7)

```
/orchestrate 268, 270, 271, 272, 273, 274, 275
```

**This is a lane, not a runnable batch of 7.** 268, 270 and 272 carry no outstanding dependency;
the others chain behind 279 (call 0), 184 (call B) and 165 (call A). Run calls A and B first, or
dispatch the front group on their own.

| Task | What lands | Note |
|---|---|---|
| **268** | Reproduce-first on the `lake-build-guard.sh` false green | Already `implementing` and nearly done: phases 1–4 complete, only phase 5 (redeploy and final gate) remains. The cross-tree replay hypothesis was **confirmed** and is the root cause. Its `file_scope` has been corrected — the two `dispatch-worktree.sh` paths it declared no longer exist, having gone with the layer 288 deleted; that is expected, not a regression. The durable value (header conventions, recorded dead ends, new test cases) survives |
| **270** | Re-runnable null-safety audit of jq mutation sites across core scripts; rule on a shared guard idiom in `scripts/lib/` | `file_scope` has been **narrowed** from two bare directories (one overlapping 23 tasks) to the anticipated check script and its test, the one confirmed defect site (`orchestrate-build-dispatch.sh:389-392`), the inventory doc, and `scripts/lib/` — which still overlaps 3 tasks (263, 280, 281) and is the narrowest honest declaration while deliverable 2 may land a helper there. If the audit finds further sites, widen at plan postflight |
| **271** | Finish the `parent_task` edge: declare in schema, validate, render in TODO, survive renumbering | After **279** (the per-field schema policy must land before another field is declared). Gates 273, 303 |
| **272** | Honest session liveness for concurrent same-repo batches: diagnose why the wired heartbeat never fires, add a live-but-stale lock state, re-derive registry scope, give each orchestration its own identity | No outstanding dependency. Also owns the runtime-file sweep defect: `/todo`'s reap stage does not exclude the *active* session's runtime files, and a sweep took an in-flight batch's `.orchestrator-multi-state-<session>.json` with it, losing `completed_tasks`, `failed_tasks` and cycle bookkeeping mid-run |
| **273** | Three-channel orchestration conclusion stage with per-channel approval, as a distinct post-postflight stage | After 271 and 184 (call B) |
| **275** | Per-repo orchestration queue: registered, live, archived on finish, consumed by admission | After 272 |
| **274** | Next-admissible-batch suggestion and alternatives-on-conflict, both computed by invoking the real admission script | Tail of everything: after 272, 273, 275, 165 |

## Call E — record-versioning policy, and two live-observed contract defects (5)

```
/orchestrate 280, 281, 282
/orchestrate 284, 285
```

Two independent groups. The first is a **three-task chain** on declared edges (280 ← 281 ← 282),
deliberately split policy-then-consumers; run it as one call and let the edges order it. The second
pair is independent of everything and cheap.

| Task | What lands | Note |
|---|---|---|
| **280** | The rule that deliverables outside `specs/` describe the **current design only** and never narrate their own draft history, plus `lib/record-version-patterns.sh` as the single mechanical source of truth both consumers will share | Policy **and** mechanism; the consumers are deliberately later. Shaped exactly like its sibling `no-task-references-in-deliverables.md` |
| **281** | Repo-wide lint (`check-record-versioning.sh`) over every git-tracked file outside `specs/**`, driven entirely by the shared pattern library, plus its fixture test | Modeled line-for-line on `check-task-references.sh`. **Depends on 280** |
| **282** | PreToolUse hook blocking a Write/Edit that introduces forbidden record-version language into a deliverable, plus fixture test and `settings.json` registration | Must inherit `validate-no-task-references.sh`'s three contracts verbatim (exit 2 + stderr). **Depends on 280, 281.** Gates 312 (call F) |
| **284** | Exempt the dispatching task's own task directory from the postflight `modified_files`-vs-`file_scope` excursion advisory | The advisory currently fires on **every** phase naming only the artifact that phase was dispatched to produce — pure noise that trains the reader to ignore a real signal. One file, narrow scope |
| **285** | `orchestrate-record-decision.sh` (a documented `.decisions.json` writer that does not exist), and the postflight handoff-recovery notice, which is both mislabelled and factually wrong about which phases write a handoff | One root: the contract tells the lead to do something unexecutable, or states something untrue |

---

## Call F — newer filings not yet slotted into a lane (18)

Filed after the lanes above were last derived. Five groups by theme; each is runnable on its own,
and **none may be merged into one call** — `MAX_TASKS` is 8.

### F1 — commit-staging correctness (3)

```
/orchestrate 309, 302, 304
```

An ordered chain in practice: 309 fixes the named recipes, 302 generalizes across every staging
site, 304 fixes the failure mode a bad entry causes.

| Task | What lands | Note |
|---|---|---|
| **309** | Replace the bare `-- specs/` directory pathspec in the three source-store commit recipes (`skill-git-workflow/SKILL.md`, `meta-builder-agent.md` Stage 6, `skill-meta/SKILL.md` postflight) | No dependencies. Source-store **drift fix, not a policy change** — `rules/git-workflow.md` already forbids a directory `git add` pathspec outright. The observed harm: under two concurrent batches, session A's commit sweeps session B's in-progress `specs/` artifacts. Blocks 302 |
| **302** | Replace the directory pathspec at **every** remaining staging site, and pass `--task` so `git-commit-scoped.sh`'s contended-path lease is actually consulted | After 44, 300, 309. The lease mechanism already exists (opt-in, fails open) and was simply never consulted. Shares `git-commit-scoped.sh` with 304 — distinct mechanisms, and the `file_scope` overlap serializes them without needing an edge |
| **304** | Make an out-of-repository path in a commit pathspec list non-fatal for the rest of the list | After 184, 263, 273, 277, 279, 284, 285 — the deepest-blocked task in the backlog. Its filing hypothesis was **false and must not be carried into research**: `return-metadata-file.md` already states the repo-relative constraint three times over |

### F2 — orchestrator defects (4)

```
/orchestrate 299, 300, 303, 311
```

| Task | What lands | Note |
|---|---|---|
| **299** | Guarantee a plan revision landing concurrently with a live implement dispatch is detected, via two complementary remedies | No dependencies. Mutual exclusion is asserted between aux *kinds*, never between an aux row and the implement row. Observed cost was real, not hypothetical: a dispatch excerpted one phase pre-revision and another post-revision, noticing only because line numbers shifted |
| **300** | Resolve `AskUserQuestion` being unreachable from a dispatched subagent: probe the mechanism, correct `agent-frontmatter-standard.md`'s tool-inheritance claim, rehome every user-choice gate that sits inside a dispatched agent | No dependencies. Blocks 302 and 312. **Carries the backlog's worst remaining coarse `file_scope`**: `scripts/tests/` overlaps 19 non-terminal tasks — narrow it at plan time or it serializes against most of the lane |
| **303** | Make `validate-state.sh`'s omitted-argument state-file default resolve against the repository being validated, not the invoking shell's CWD, and survey siblings for the same latent pattern | After 271, 279. Precisely located at `validate-state.sh:241-243`; the script's own header documents the CWD-relative behaviour |
| **311** | Replace the static `BUILD_HEAVY_TASK_TYPES=("lean4" "cslib")` family list with a measured or probed build-weight signal, and design the no-history fallback | No dependencies. This is the binding constraint on real parallelism for Lean-heavy batches: a Mathlib-free `lean4` package measured at 6 s wall / 17 jobs is refused co-scheduling exactly as a full Mathlib build is |

### F3 — roadmap and TODO automation (5)

```
/orchestrate 306, 307, 308, 313
/orchestrate 312
```

The first four are a chain on declared edges (306 ← 307, 308 ← 313); run them as one call and let
the edges order it. **This group automates the hand-maintenance this file still depends on** — the
accounting line under Goal, the call groupings, and the batch blocks are all hand-derived today.

| Task | What lands | Note |
|---|---|---|
| **306** | Turn this file into a generated artifact with a standardized format, its phase/batch structure derived from `state.json` dependencies | No dependencies. Verified motivation: `TODO.md`'s generated Dependency Waves table already contains exactly the waves a hand rewrite derived by hand — identical task sets, identical Blocked-by and Topics columns. Gates 307, 308, 313 |
| **307** | Make `/todo` faster and cheaper, and wire it to the roadmap prune mode | After 306. **Phase order is a requirement**: consolidate the duplicated implementation first (`skill-todo/SKILL.md` hand-implements the same 16 stages `commands/todo.md` implements, and the command never dispatches it). Frame as consolidation, not deletion — the skill is registered and directly invocable. Already absorbed the archive-orphan defect (`/todo`'s scan checked only `completed_projects`, so correctly-tracked `archived_projects` entries surfaced as false orphans every run) |
| **308** | Wire `/review` to regenerate this file completely, and remove redundant work from the command | After 306. Also collapses ten separate jq processes over one in-memory string into a single pass, and removes the duplicated `generate-todo.sh` invocation. **Constraint**: the missing-script and non-zero-exit guards plus the always-on structure marker must survive — they are what stops a regeneration no-op from masquerading as success |
| **313** | Advisory lint validating hand-authored batch blocks in this file, so an under-inclusive batch is caught at authoring time | After 306, 308. Observed failure: an agent removed a task from a batch *because* it depended on another task in that batch — wrong, since dispatch is dependency-aware and an intra-batch edge merely sequences the two into successive waves |
| **312** | Require every new task to be compared against the open backlog before creation, via one shared `audit-open-tasks.sh` with a fixed verdict vocabulary and a semantic pass | After 165, 300, 282. Research must **rule** on the enforcement design (one state-write-boundary hook vs. per-surface wiring) rather than assume it; both cost ~5 edges, so uniformity versus blocking depth decides. Its own non-goal is load-bearing: no reconciliation verdict beyond a dependency edge may be applied silently to a task a human wrote |

### F4 — the red gate, and the books extension (3)

```
/orchestrate 290
/orchestrate 297, 298
```

290 is the blocking gate fix from Next and should run first, alone. 297 ← 298 is an independent
chain.

| Task | What lands | Note |
|---|---|---|
| **290** | Teach gate 5 (`verify.lua` content-hash equality) about cross-extension override precedence, so a deployed path resolves against its actual deploying owner | **The one red gate — run before call A.** Three standing false positives, verified by diff: the `lean` extension deliberately owns those three deployed contract paths (two overrides, one parity copy). Must not weaken real divergence detection for single-owner paths |
| **297** | Build the `books` extension in the source store: the `books` task type for authoring, certifying and documenting lean books | Owns the extension's **wiring** only — manifest, four-block routing, agents, skills, commands, rule, registration, tests. Source store only; nothing hand-authored under `.claude/**`. Gates 298 |
| **298** | Author the domain context corpus under `context/project/books/` | After 297, and scoped to `context/project/books/**` only — it does not touch the wiring files. Write against the design record (`docs/book-convention.md`, 18 accepted decisions; `book-toml-v2.md` normative) in Logos/Verification, not the half-landed tooling, and keep the known-gap register honest |

### F5 — Neovim config hygiene (3)

```
/orchestrate 294, 295, 296
```

Filed by an earlier `/review` pass over this repo's own Lua and docs. Independent of each other and
of every agent-system lane; all three had no `file_scope` and now carry one.

| Task | What lands | Note |
|---|---|---|
| **294** | Fix root `CLAUDE.md`'s four standards pointers | The paths cited under `.claude/extensions/nvim/context/project/neovim/standards/` do not resolve, though all four files exist in the source store — so this is a wrong-pointer fix, not a missing-content one |
| **295** | Add the missing `desc` field to the 44 of 88 `vim.keymap.set` calls that lack one | 13 files. Violates this repo's own Lua Code Style standard and the Neovim extension's Common Operations note |
| **296** | Three independent small fixes: delete the stale byte-identical `init.lua.backup`; regenerate the `project-overview.md` still carrying its `<!-- GENERIC TEMPLATE -->` notice; fix `README.md:185`'s link to a nonexistent `.claude/README.md` | No shared file between the three |

---

## Checks before and after every call

- `bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <tasks>`
  — **space-separated**; admits what you expect, `md5sum specs/state.json` unchanged. Research and
  plan dispatches are exempt from the self-modifying defer (`--phase-map`), so overlap only
  serializes at implement time.
- `bash .claude/scripts/validate-state.sh --deep` — 0 failures. Re-measured: **18 passed, 2
  warnings, 0 failed.** Both warnings are coarse `file_scope`: 300's `scripts/tests/` (19 overlaps)
  and 270's `scripts/lib/` (3). Treat any *new* warning as real.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — read the **end-of-run failure
  roster** and the `EXPECTED`/`NEW` split, not just the tally; exit code read directly (never
  through `tail`/`head`). A NEW failure is yours; an EXPECTED one is in `known-failures.txt` with
  a reason. `--fail-on-new` makes that a gate; `--jobs 4` is opt-in and reproduces the serial
  pass/fail set except under heavy contention.
- `bash .claude/scripts/verify-deploy.sh --skip-slow` — **currently FAIL, 1 of 33**, gate 5 only
  (290). Until that lands this check is red for a known reason, so measure it *before* your work as
  well as after, and compare. A self-modifying task is not finished until `.claude/` is resynced.
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
   suppress. Measured coverage is uneven across repos — complete here, but only about 42% of
   BimodalLogic's non-terminal tasks carry the field, which is why 165's ruling splits by scope
   kind (in-batch blocking, cross-batch advisory) rather than issuing one blanket posture.
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
    pre-existing "Never Run" is specifically force-to-master, and this repository's own working
    branch *is* master, so a blanket default-branch exclusion would exceed the rule being narrowed
    and make the mechanism unusable where it lives.
13. **`known-failures.txt` is the only known-failing list.** Advisory by construction: it never
    changes which suites run, and deleting it only removes the EXPECTED/NEW annotation. Never keep
    a prose copy anywhere else — that is the drift mechanism, so `shell-script-testing.md` points
    here. A `needs-owner` row is a known gap, not an accepted steady state.
14. **One shared working tree, always.** Per-dispatch `git worktree` isolation is removed, not
    narrowed — no selection predicate survives. Concurrency safety rests entirely on declared
    `file_scope`, dependency edges, and the five contention inputs already in service. Build
    contention, the one hazard `file_scope` cannot reach, is closed by refusing to co-schedule two
    build-heavy implement tasks in one cycle, not by isolation and not by a PATH shim — the shim is
    declined for now with its residual named. Cost was not the reason for removal and must not be
    cited as it: provisioning was measured cheap. Full record, including the structural argument
    that outlives the three individual defects:
    `specs/decisions/worktree-isolation-removal-verdict.md`.
15. **Gate 8's deployed-tree coverage is knowingly reduced** (accepted trade-off). The redeploy
    checkpoint runs `--skip-slow`, so the ~40 core suites that resolve their subject-under-test
    from the *deployed* tree are not verified against a fresh deploy there. Accepted on wall-clock
    grounds; the narrower fix — running only those ~40 suites post-redeploy — is a live follow-up,
    not a settled dismissal. See observations.

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

- **Gate 8's deployed-tree gap needs the narrow fix.** Per decision 15 the trade-off is accepted,
  but the follow-up it names does not exist as a task: run only the ~40 deploy-tree-first suites
  against Gate 8 post-redeploy, so the coverage returns without the 13-minute bill. **This is the
  observation here closest to deserving a task**, and it belongs with 265.
- **The deploy gate's refusal remedy is not discoverable.** A completion postflight whose
  `modified_files` touch `agent-system/extensions/**` is correctly refused with exit 6, and leaves
  `state.json` and the plan's `**Status**` header *both* unwritten — consistent, but the
  operator-visible remedy is `reconcile-task-status.sh <N> <session>`, not a re-run of postflight
  or `/orchestrate`. That is documented, but only inside a subsection about unwinding a dispatch.
- `plan-file-scope-harvest.sh` parses a `**Files to modify**:` field and finds nothing in a plan
  that uses a "Territory Contract" table instead. At least one BimodalLogic plan is invisible to
  the harvester for this reason.
- The write-time task-reference hook fires on files in the session scratchpad. Its path filter
  could exempt `/tmp/**`.
- A `Monitor`-armed wait can never fire. An implementation agent armed a monitor for a long
  `run-all.sh`, went idle, and no event ever arrived — the dispatch stalled indefinitely until
  resumed by hand. Prefer in-band polling with productive work between checks over arm-and-idle.
- A subagent parked on genuinely slow background work emits repeated interim notifications that
  read like stalling. Notification semantics, not agent behaviour.
- The in-scope agent set for a contract rolled across implementation agents is **14** files, not
  the 13 a sweep by directory suggests — `founder-implement-agent.md` also edits phase-heading
  markers.
