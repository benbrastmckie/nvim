# Measurements: task 200 (consumer deploy propagation gap)

Recorded during implementation of `plans/01_per-dispatch-freshness-surface.md`. Commands are
given verbatim so every number here is independently reproducible.

## Phase 1: Baseline premises and cost

### 1. Lean call-site confirmation

Command:
```
diff agent-system/extensions/lean/agents/lean-implementation-agent.md \
     ~/Projects/BimodalLogic/.claude/agents/lean-implementation-agent.md
diff agent-system/extensions/lean/agents/lean-implementation-hard-agent.md \
     ~/Projects/BimodalLogic/.claude/agents/lean-implementation-hard-agent.md
diff agent-system/extensions/lean/rules/lean4.md \
     ~/Projects/BimodalLogic/.claude/rules/lean4.md
diff agent-system/extensions/lean/skills/skill-lake-repair/SKILL.md \
     ~/Projects/BimodalLogic/.claude/skills/skill-lake-repair/SKILL.md
```

Result:
- `lean-implementation-hard-agent.md`, `rules/lean4.md`, `skills/skill-lake-repair/SKILL.md`:
  **byte-identical** (diff exit 0).
- `lean-implementation-agent.md`: diff is non-empty, but the non-empty region is a section
  (`### `.orchestrator-handoff.json` (orchestrator-mode dispatches)`) that source has and the
  deployed copy lacks — unrelated to the cited `lake-build-guard.sh` call site. Isolating the
  cited call site specifically:
  ```
  grep -n "lake-build-guard.sh build" agent-system/extensions/lean/agents/lean-implementation-agent.md
  # 288:   bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- build 2>&1
  grep -n "lake-build-guard.sh build" ~/Projects/BimodalLogic/.claude/agents/lean-implementation-agent.md
  # 253:   bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- build 2>&1
  ```
  Both lines are identical text (line numbers differ only because the deployed copy is missing
  the unrelated later section). **Confirmed: all four previously-cited call sites already match
  source as of this measurement.** No lean source edit was made or is needed.
- **This is itself a live demonstration of the task's own "partial staleness" premise**: within
  the single file `lean-implementation-agent.md`, one region (the cited call site) is fresh while
  another region (the `.orchestrator-handoff.json` section) is stale relative to source. This is
  expected to resolve once `~/Projects/BimodalLogic` is redeployed in Phase 7 and is not a defect
  introduced by this task.

### 2. Single-invocation cost of `check-deploy-freshness.sh`

Command (5 runs each, wall clock via `date +%s%N` deltas):
```
for i in 1 2 3 4 5; do
  t0=$(date +%s%N); bash .claude/scripts/check-deploy-freshness.sh . >/dev/null 2>&1; t1=$(date +%s%N)
  echo "run $i: $(( (t1 - t0) / 1000000 )) ms"
done
```

This repo (`/home/benjamin/.config/nvim`, 6 extensions): 115, 115, 116, 119, 122 ms
-> **min 115ms, median 116ms**

`~/Projects/BimodalLogic` (7 extensions): 144, 145, 147, 148, 149 ms
-> **min 144ms, median 147ms**

This is close to the ~0.133s the research report estimated, confirming the same order of
magnitude; the measured values above (115-149ms) supersede the research figure as the recorded
baseline for Phase 6's comparison.

### 3. Extension counts (`jq '.extensions | keys | length'` on each `.claude-extensions.json`)

| Repo | Extensions | Names |
|------|-----------|-------|
| `/home/benjamin/.config/nvim` | 6 | core, email, literature, memory, nix, nvim |
| `~/Projects/BimodalLogic` | 7 | core, filetypes, formal, lean, literature, memory, typst |

Per-extension cost is roughly linear: ~115ms / 6 ext ≈ 19ms/ext (this repo), ~144ms / 7 ext ≈
21ms/ext (BimodalLogic) — consistent across repos.

### 4. Registered-consumer count

Command:
```
jq 'length' agent-system/extensions/core/context/reference/known-consumer-repos.json
```
(field is `.consumers`, corrected from the plan's literal invocation which reads the whole file):
```
jq '.consumers | length' agent-system/extensions/core/context/reference/known-consumer-repos.json
```
Result: **5 registered consumers** (`.dotfiles`, `BimodalLogic`, `ModelChecker`,
`PersonalWebsite`, `cslib`).

### Cost-contrast argument (baseline for Phase 6)

- Per-dispatch, pull-side cost measured here: **~115-149ms**, scaling with the *checking repo's
  own* extension count (6-7 extensions in the two repos measured), never with the size of the
  consumer fleet.
- The previously-removed fleet-wide walk (tier 3, `check-consumer-freshness.sh
  --consumer-report`) costs **~10 minutes** walking the registered consumer set — currently 5
  repos, but the cost driver is the fleet size, categorically different from the per-repo,
  per-dispatch cost above.

## Phase 6: Per-dispatch cost vs. the fleet-walk regression it must not reintroduce

### 1. Added per-dispatch cost: `skill_preflight_update` with vs. without the new surface

Method: a fixture repo (isolated, real deployed `update-task-status.sh` dependency chain copied
in) using THIS repo's own real `.claude-extensions.json` shape (6 extensions), with every
`source_dir` repointed at this repo's real `agent-system/extensions/<name>` directories and
`source_git_head` deliberately bogus, so every extension is STALE and the comparison walks real
git history exactly as it would in live use (not a trivial 0-extension or already-cached case).
10 runs each, `date +%s%N` deltas around the function call.

- **`skill_deploy_freshness_stale_names` alone** (10 runs): 102, 101, 107, 110, 104, 100, 101,
  100, 101, 104 ms -> min 100ms, median 101.5ms.
- **`skill_preflight_update` WITH the surface** (10 runs): 254, 263, 262, 279, 274, 255, 257,
  263, 254, 240 ms -> median 259.5ms.
- **`skill_preflight_update` WITHOUT the surface** (10 runs, the helper shadowed with a no-op
  function defined AFTER sourcing -- no file on disk edited, source-store or deployed): 154,
  147, 144, 149, 159, 157, 148, 153, 166, 155 ms -> median 153.5ms.
- **Added per-dispatch delta: ~106ms** (259.5 - 153.5), consistent with the ~101.5ms isolated
  measurement above (the small difference is call overhead/variance, not a second cost driver).

This is higher than Phase 1's ~115-149ms for the WHOLE `check-deploy-freshness.sh` process
because this fixture forces every extension to recompute `git log -1` against a real,
non-trivially-sized `agent-system/extensions/<name>` history (worst-case-shaped), whereas Phase
1's number is this repo's actual current (mostly-fresh, smaller-diff) state. Both are "the same
class" (double-digit-to-low-triple-digit milliseconds), not orders of magnitude apart.

### 2. Session-level total

Dispatch count: rather than inventing a number, reusing the one already recorded in this
project's own documentation (`CLAUDE.md`'s Hard Mode section) for a real, completed
high-complexity task: **13 dispatches** (the BimodalLogic per-phase-dispatch baseline, 9
H-techniques, 0 lines -> 2,400+ lines). A minimal single-round task (research + plan + one
implement phase) is **3 dispatches**.

- 13-dispatch session: 13 x 106ms = **1.38 seconds** total added cost.
- 3-dispatch minimal session: 3 x 106ms = **0.32 seconds** total added cost.

**Stated ceiling** (recorded before comparing, per this phase's own task list): a per-session
total under **5 seconds** counts as "cheap" for a pull-side check that fires only on this
session's own live dispatches. Both figures above (1.38s and 0.32s) are well under this ceiling
-- **no overrun**.

### 3. Contrast against the fleet-wide walk this change must not reintroduce

The previously-removed `--consumer-report` fleet walk costs **~10 minutes (600,000ms)** across
the registered consumer set (5 repos today; historically described as up to ~50 in the
dispatch's own framing).

- 600,000ms / 1,380ms (13-dispatch session) = **~435x cheaper**.
- 600,000ms / 320ms (3-dispatch minimal session) = **~1,875x cheaper**.

### 4. Scaling argument (restated from Phase 1, now with the per-dispatch number folded in)

The added cost scales with **the checking repo's own extension count** (6 in this repo, 7 in
`~/Projects/BimodalLogic`) multiplied by **the number of dispatches in this session** -- it
NEVER scales with the size of the registered-consumer fleet (5 today). This is the categorical
difference between a pull-side check (each repo checks only itself, only when it is actually
being used) and the push-side fleet scan Task 180 correctly removed from the blocking path: the
pull-side cost is bounded by a quantity under THIS session's own control, while the push-side
cost grows with a quantity that is not.
