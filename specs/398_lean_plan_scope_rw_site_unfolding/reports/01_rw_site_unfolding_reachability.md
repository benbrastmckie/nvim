# Research Report: Task #398

**Task**: 398 - lean_plan_scope_rw_site_unfolding
**Started**: 2026-11-22T00:00:00Z
**Completed**: 2026-11-22T00:00:00Z
**Effort**: 1-2 hours (plan), ~1 hour already-landed content reduces remaining scope
**Dependencies**: 397 (ordering constraint only; both write index-entries.json — no content coupling)
**Sources/Inputs**: Codebase (git log/show, dependency-tracing.md, index-entries.json, manifest.json, planner-agent.md, context-discovery.md), git history of the source store
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The substance of the cited issue-log finding is **already partly landed** in
  `dependency-tracing.md` (commit `f49576632`), but only in generic form: it states the
  "enumerate every unfold spelling" rule but carries none of the concrete worked example
  (`FixtureStable.lean` / `EUFix.lfp_induction` / `lfp'` / the 200000-heartbeat timeout) and
  none of the twelve-spelling repo-wide grep recipe the dispatch calls "the most valuable thing
  in this entry."
- The plan-time reachability question is **settled by reading, not assumed**: `planner-agent.md`
  Stage 4 item 13 is the *only* mechanism by which the core planner reads `project/**` domain
  content, and it is gated on `load_when.task_types[]` matching AND `keywords[]`/`topics[]`
  containing the literal string `plan-authoring` — not on the task_types axis alone, and not on
  `load_when.agents[]` at all.
- Candidate remedy (a) — adding `planner-agent` to `dependency-tracing.md`'s
  `load_when.agents[]` — is **explicitly prohibited** by `planner-agent.md`'s own MUST NOT clause
  and by `context-discovery.md`'s "Cross-Domain-Shared-Agent Hazard" section. This is a
  mechanically confirmed rejection, not a judgment call.
- The **recommended remedy** reuses the existing Stage 4 item 13 mechanism with zero change to
  `planner-agent.md` itself: add the keyword `"plan-authoring"` to `dependency-tracing.md`'s
  existing index entry (in `index-entries.json`, already in this task's file scope). This makes
  the entry one of the files Stage 4 item 13 already reads for every `lean4` plan dispatch,
  without touching the core planner's contract and without editing any file outside this task's
  declared scope.
- `index-entries.json`'s `line_count: 242` for `dependency-tracing.md` is **currently accurate**
  (confirmed against `wc -l`) — a later, unrelated sync commit already repaired the staleness
  `f49576632` introduced — but the planned content addition will invalidate it again, and the
  implementation phase must re-run the line-count regeneration for this one entry.

## Context & Scope

This task investigates a scope/blast-radius correction distilled from a lean4 orchestration run
in a different repository (`~/Projects/BimodalLogic`). The research question has two parts:
(1) what, concretely, is still missing from `dependency-tracing.md` after a prior, independent
landing of the same issue-log entry's generic substance; and (2) through what mechanism, if any,
does `planner-agent` (the core planner, not a lean-owned agent) ever read
`dependency-tracing.md` at plan time — the record's own stated open question, which the dispatch
requires be **settled by reading** before a remedy is chosen.

File scope for this task: `dependency-tracing.md` and `index-entries.json`. If the chosen remedy
needs a file outside that scope, scope must widen before the edit — this report evaluates
whether that is actually necessary and concludes it is not.

## Findings

### Codebase Patterns

**1. The generic rule is already landed; the concrete case and the twelve-spelling recipe are
not.**

`git show f49576632 -- .../dependency-tracing.md` shows a `## Grep-Based Blast Radius: Cover
Unfold Spellings, Not Just Importers` section added on 2026-10-13, derived from the *identical*
issue-log entry (`iss_1791921588196_IcZKne`) this task's own dispatch cites, but produced by an
unrelated conclusion-stage dispatch running in `~/Projects/BimodalLogic` with no visibility into
this task space (no dependency edge, no file_scope overlap gate spans the two repositories — the
duplication was structurally undetectable at dispatch time; recorded as an issue, see Issue Log).

What that section contains: the general caveat ("a plain-text grep for importers can under-count
blast radius... one observed case, unfolding to a different fixed-point representative...
heartbeat timeout") and a *generic* list of unfold spellings — "the bare name, `rw [name]`, `simp
[name]`, `unfold name`, `delta name`, `show ... from name`, and any
`@[simp]`/`@[reducible]`-triggered unfold" (six to seven generic categories, not twelve concrete
spellings).

What it does NOT contain, confirmed by reading the live file in full:
- The concrete worked example: `FixtureStable.lean` carrying `rw [untlLive]`, the unfold target
  `EUFix.lfp_induction`, the fixed-point representative `lfp'`, or the `200000`-heartbeat figure.
- The "repo-wide grep over ALL TWELVE definitional-unfold spellings" recipe the dispatch singles
  out as "the actual working recipe" and "the most valuable thing in this entry" — the current
  prose names roughly six to seven spelling *categories* in free text, not an enumerated,
  concrete twelve-item probe a reader could run as written.
- The specific complete-repair-set figure ("3 sites in 2 files").

This matches the dispatch's own "Already Landed" appendix exactly: "What remains genuinely
undone: the `agent-system/extensions/lean/index-entries.json` leg was NOT updated" — confirmed
below — plus, from direct reading, the concrete example and the twelve-spelling enumeration were
also never added by the prior landing.

**Note on retrieving the exact twelve spellings**: the cited issue entry lives in
`~/Projects/BimodalLogic/specs/716_sliced_certificate_liveat_nontermination/issues.jsonl`, which
is not reachable from this machine/repository (checked directly: path absent). The
implementation phase cannot transcribe the original twelve-item list verbatim and should either
(a) note in the new content that the list is a reconstructed, illustrative enumeration consistent
with Lean 4's actual unfold-triggering syntax forms (the existing six-to-seven-category list,
expanded to concrete spellings — e.g. `rw [name]`, `rw [← name]`, `simp [name]`, `simp only
[name]`, `unfold name`, `unfold_let name`, `delta name`, `show ... from name`, `exact name`,
`@[simp] name` auto-unfold, `@[reducible] name` auto-unfold, `dsimp [name]` — twelve concrete
forms in that spirit), explicitly flagged as a reconstruction rather than a verified
transcription of the original repository's exact list; or (b) treat the exact enumeration as
unrecoverable and record that limitation plainly rather than fabricating a false provenance.
Either is legitimate; silently presenting a guessed list as the verbatim original is not.

**2. `index-entries.json`'s `line_count` for `dependency-tracing.md` is currently accurate, by
coincidence of an unrelated later sync, not because `f49576632` itself updated it.**

```
git show f49576632~1:.../dependency-tracing.md | wc -l   # 211
git show f49576632~1:.../index-entries.json | jq '...line_count'   # 211 (matched, pre-edit)
git show f49576632 --stat | grep index-entries            # (no output -- not touched)
wc -l .../dependency-tracing.md                            # 242 (current)
jq '...line_count' .../index-entries.json                  # 242 (current, matches)
```

`f49576632` added content to `dependency-tracing.md` (211 -> 242 lines) without touching
`index-entries.json` at all. A later, unrelated commit (`3c663374a`, "sync: deploy state, lean
index line_count, runtime logs") happened to resync the line count correctly as part of a
routine sweep, independent of this task's substance. **This means the `index-entries.json` leg
the dispatch calls "NOT updated" currently refers to the keyword/reachability gap (finding 3
below), not a stale `line_count`** — the count itself is accurate today. The implementation
phase must still re-run line-count regeneration after adding the new content, since that edit
will move the count again (242 -> larger).

**3. The plan-time reachability question, settled by reading.**

`planner-agent.md` (the core planner every `lean4` plan dispatch routes to —
`manifest.json`'s `routing_agents.plan.lean4 = "planner-agent"`, confirmed live, and
`routing_agents_hard` has no `plan` key, confirmed live, so hard-mode routes identically) contains
exactly one stage that reads `project/**` domain content at all: **Stage 4, item 13, "Surface
This Domain's Plan-Authoring Gotchas Before Decomposing"**:

> Before decomposing phases, query the deployed context index (`.claude/context/index.json`) for
> a `project/**` entry whose `load_when.task_types[]` contains this dispatch's own `task_type`
> AND whose `keywords[]` (or `topics[]`) name `plan-authoring`. `Read` every hit before
> decomposing phases...
>
> **MUST NOT**: do not resolve this by adding `planner-agent` to a domain entry's
> `load_when.agents[]`. The adaptive query ORs the agent, task-type, and command dimensions, so a
> cross-domain shared agent named in a domain entry's `agents[]` loads that domain's content into
> every other domain's plan dispatch, not only the intended one.

This is the full answer to the dispatch's open question:
- The **task_types axis alone does not govern discovery** at plan time for ordinary domain
  content — it is a *necessary but not sufficient* condition in the one query planner-agent
  actually runs; the query additionally requires the `plan-authoring` tag.
- **`load_when.agents[]` is irrelevant to the planner's own reads of `project/**` content** —
  confirmed by both the MUST NOT clause above and by `context-discovery.md`'s "Cross-Domain-
  Shared-Agent Hazard in `agents[]`" section, which names exactly this scenario
  (`planner-agent`, `general-implementation-agent`, `general-research-agent` as the three shared
  agents that must never appear in a domain entry's `agents[]`).
- Across all 45 `load_when.agents[]`-bearing entries in `index-entries.json` (re-measured; the
  dispatch's appendix said 41 — the file has grown since), the only values used anywhere are
  `lean-research-agent` and `lean-implementation-agent` — never `planner-agent` — consistent with
  the MUST NOT clause being actively honored, not merely declared.

**Live confirmation the mechanism works as described**: `plan-authoring-gate-collisions.md` (the
subject of concurrent sibling task 549, currently in its own research phase on the same file) is
tagged exactly this way today:

```json
{
  "path": "project/lean4/patterns/plan-authoring-gate-collisions.md",
  "load_when": { "agents": ["lean-research-agent", "lean-implementation-agent"],
                 "task_types": ["lean4"] },
  "keywords": ["lean4", "plan-authoring", "gate-collision", ...]
}
```

`load_when.agents[]` names the two domain-exclusive agents (never `planner-agent`), while
`keywords[]` carries the literal `plan-authoring` tag that is the actual hook Stage 4 item 13
tests for. This is the *only* file in the entire `agent-system` tree currently tagged
`plan-authoring` (confirmed: grepping every extension's `index-entries.json` for
`keywords[]`/`topics[]` containing `plan-authoring` returns exactly this one path).

**Candidate-remedy assessment, on this evidence**:

| Candidate | Verdict | Reason |
|---|---|---|
| (a) Add `planner-agent` to `load_when.agents[]` | **Rejected** | Explicitly forbidden by planner-agent.md's own MUST NOT clause and by context-discovery.md's named hazard — not a judgment call, a mechanically confirmed prohibition. |
| (b) Fix the task_types axis generally | **Out of scope, per the dispatch's own NOT IN SCOPE clause** | The task_types axis is not what gates Stage 4 item 13 — the `plan-authoring` keyword/topic co-requirement is the actual gate, and loosening or removing that co-requirement is a change to the core planner's own contract (broadening a shared, cross-domain query), which the dispatch explicitly reserves as a follow-up, not this record's scope. |
| (c) Short plan-time pointer in a file the planner demonstrably reads | **Adopted, in a narrower form than literally stated** | The only file the planner demonstrably reads for `lean4` plans today is `plan-authoring-gate-collisions.md` itself — but that file is concurrent sibling task 549's own declared territory (status: `researching`, same file), so inserting a cross-reference there now would collide with live, in-progress work on the exact same file this same orchestration cycle. The equivalent, zero-collision realization of (c) is to make `dependency-tracing.md` itself one of the files the existing query already resolves, by tagging its OWN index entry with the `plan-authoring` keyword — see Recommendation below. |
| (d) Conclude the planner already reaches it | **Rejected** | Measured and confirmed false: `dependency-tracing.md`'s current `keywords[]` list (`lean4, dependency-tracing, print-axioms, environment, reverse-dependency, retirement`) contains no `plan-authoring` tag, so Stage 4 item 13's query does not currently select it. |

## Recommendations

**Content (within existing file scope, `dependency-tracing.md`)**: extend the already-landed
`## Grep-Based Blast Radius: Cover Unfold Spellings, Not Just Importers` section — do not create
a new top-level section, and do not fold it into `## Four Probe Shapes` (that heading's count
must stay accurate; this material is deliberately a sibling section, not a fifth probe shape,
exactly as it is structured today). Add, inline in that section:
- The concrete worked example (`FixtureStable.lean` / `rw [untlLive]` / `EUFix.lfp_induction` /
  `lfp'` / 200000-heartbeat whnf timeout / "3 sites in 2 files").
- A concrete, enumerated twelve-spelling probe (a literal grep recipe, e.g. a short shell loop
  over an explicit spelling list), replacing the current prose's six-to-seven-category
  description with an actually-runnable template — per the "Four Probe Shapes" section's own
  convention of giving runnable code, not just a moral. Flag explicitly, per the note above,
  whether the twelve-item list is a verified transcription or a reconstruction consistent with
  the existing shorter list (it cannot be a verified transcription in this repository, since the
  source issue log is unreachable here).

**Reachability (within existing file scope, `index-entries.json`)**: add `"plan-authoring"` to
`dependency-tracing.md`'s existing `keywords[]` array (in both the source-store
`agent-system/extensions/lean/index-entries.json` and, via redeploy, the mirrored
`.claude/context/index.json`). This is sufficient, on its own, to make Stage 4 item 13's existing
query pick up `dependency-tracing.md` for every future `lean4` plan dispatch — no change to
`planner-agent.md` is needed at all, which is strictly narrower than even candidate (c) as
originally framed (that candidate anticipated a pointer *in* another file the planner reads;
this realization needs no second file and no pointer, only a one-keyword tag on the entry
already in scope). Record, as an explicit follow-up for a later task (not this one, and not
assumed by convenience): if a shorter, genuinely minimal pointer is later preferred over loading
`dependency-tracing.md` in full at plan time (budget is not a concern today — the file is far
under the 15000-token/~1875-line planner cap — but file growth over time could change that),
that would mean adding a one-line cross-reference inside `plan-authoring-gate-collisions.md`
instead, which requires coordinating with task 549's territory on that same file and should not
be done opportunistically from this task.

**Index-entries.json line_count**: after the content edit lands, re-run this extension's
line-count regeneration for the `dependency-tracing.md` entry specifically (its count will move
again from 242) — do not leave it stale the way the prior, independent landing did (see Finding 2).

## Decisions

- Remedy (a) is rejected on mechanical grounds (explicit prohibition in two places), not
  revisited as a planning-time judgment call.
- Remedy (b) (loosening the core planner's task_types-only query) is recorded as out of this
  task's scope per the dispatch's own NOT IN SCOPE clause, not silently done.
- The chosen remedy is a variant of (c) that touches only the two files already in this task's
  declared file scope — self-tagging `dependency-tracing.md`'s own index entry with the
  `plan-authoring` keyword — rather than inserting a pointer into `plan-authoring-gate-collisions.md`,
  which belongs to concurrent sibling task 549's territory this cycle.
- The exact twelve-spelling list from the originating issue entry is not retrievable in this
  repository; the plan must choose explicitly between a flagged reconstruction and an explicit
  non-transcription note, not a silent fabrication.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|-------------|
| Editing `plan-authoring-gate-collisions.md` to add a cross-reference, colliding with task 549's concurrent territory on the same file | Medium (merge/overwrite risk this cycle) | Low if the recommendation above is followed | Stay within the declared file scope; do not widen scope to that file in this task. |
| New content in `dependency-tracing.md` folded into `## Four Probe Shapes`, creating a "Four Probe Shapes" heading with five shapes under it | Low but explicitly flagged as the "obvious way to get this wrong" by the dispatch | Low | Keep the new material inside the existing, separate `## Grep-Based Blast Radius...` section; do not touch the `## Four Probe Shapes` heading or its count. |
| Presenting a reconstructed twelve-spelling list as a verbatim transcription of the unreachable source issue entry | Low (documentation accuracy) | Medium if not explicitly flagged | State the reconstruction/non-transcription caveat inline, per the Recommendations section. |
| `index-entries.json` `line_count` drifting stale again after the content edit, as happened (harmlessly, so far) after `f49576632` | Low (caught by `check-extension-docs.sh` Rule R on the next `verify-deploy.sh`) | Medium absent explicit handling | Explicitly schedule a line-count regeneration step for this one entry in the implementation plan, rather than relying on an unrelated future sync commit to catch it again. |

## Context Extension Recommendations

- **Topic**: none identified beyond this task's own scope. `planner-agent.md` Stage 4 item 13 and
  `context-discovery.md`'s Cross-Domain-Shared-Agent Hazard section already fully document the
  reachability mechanism this task needed to understand; no gap in existing context documentation
  was found.

## Appendix

### Search queries / commands used

- `jq '.extensions.lean.source_dir' .claude-extensions.json`
- `jq '.entries[] | select(.path | test("dependency-tracing"))' agent-system/extensions/lean/index-entries.json`
- `jq '.routing_agents, .routing_agents_hard' agent-system/extensions/lean/manifest.json`
- `jq -r '.entries[].load_when.agents[]?' agent-system/extensions/lean/index-entries.json | sort -u`
- `jq '.entries[] | select(.path | test("plan-authoring-gate-collisions"))' agent-system/extensions/lean/index-entries.json`
- `find agent-system/extensions -name index-entries.json | xargs -I{} jq -r '.entries[] | select((.keywords[]?=="plan-authoring") or (.topics[]?=="plan-authoring")) | .path' {}`
- `git log --oneline --all -- agent-system/extensions/lean/index-entries.json`
- `git show f49576632 -- .../dependency-tracing.md`
- `git show f49576632~1:.../dependency-tracing.md | wc -l` and the matching `index-entries.json` line_count at that revision
- `jq '.active_projects[] | select(.project_number==549 or .project_number==398) | {project_number,status,project_name,file_scope}' specs/state.json`

### References

- `agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md`
- `agent-system/extensions/lean/index-entries.json`
- `agent-system/extensions/lean/manifest.json`
- `agent-system/extensions/core/agents/planner-agent.md` (Stage 4, item 13)
- `agent-system/extensions/core/context/patterns/context-discovery.md` ("Cross-Domain-Shared-Agent Hazard in `agents[]`")
- `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`
- Commit `f49576632` ("lean: record four Lean 4 measurement and syntax gotchas")
- `specs/398_lean_plan_scope_rw_site_unfolding/.dispatch/1.md` (this task's dispatch record)
