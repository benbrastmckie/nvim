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
