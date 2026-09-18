# Territory Contract (H7)

This contract implements H7: Territory Contracts for Parallel Dispatch. It has two shipped
consumers today. The first is `skill-orchestrate`'s hard-mode single-phase dispatch (H1, the
merged successor to the now-deleted standalone hard-mode engine), where it governs file ownership
and commit coordination for the one agent currently working a phase, plus the STOP-and-report duty
on any foreign work that agent observes. Parallel-wave dispatch is currently disabled (see
`skill-orchestrate/SKILL.md`'s "Parallel Wave Dispatch: DISABLED" section), but the contract
remains fully applicable to multiple agents dispatched simultaneously to work on different phases
of the same plan should parallel dispatch be re-enabled. The second consumer is the multi-task
cycle planner (`orchestrate-cycle-plan.sh`), which populates a DIFFERENT fact under the same
`--territory` flag and the same `## Territory` dispatch-file section in EVERY mode, not only hard
mode: which OTHER tasks are scheduled for dispatch this same cycle, on this same shared working
tree, and their declared file scope. See "Cross-Task Territory (Base Mode)" below for that half of
the contract — it is a different fact from the within-task H7 territory above and the two are
never conflated, though a single hard-mode implement dispatch can legitimately carry both at once
(its own H1 `owned_files` literal merged with its `concurrent_siblings` list).

## File Territory

When the orchestrator dispatches multiple agents in parallel, each agent receives an
explicit file territory in its dispatch context:

```json
{
  "territory": {
    "owned_files": ["path/to/file1.ext", "path/to/file2.ext"],
    "read_only_files": ["path/to/reference.ext"],
    "forbidden_files": []
  }
}
```

**Rules**:
- Agent may create and modify files in `owned_files` only
- Agent may read (but not write) `read_only_files`
- Agent MUST NOT touch files in `forbidden_files`
- If a needed file is not in territory, request a territory extension via handoff
  (do not unilaterally expand territory)

## Cross-Task Territory (Base Mode)

Unlike the within-task File Territory above (H7/H1, one plan's phases), this section covers a
DIFFERENT fact: which OTHER, independent tasks are scheduled for dispatch this SAME
`/orchestrate` cycle, on this SAME shared working tree, and what file scope each one declared.
`orchestrate-cycle-plan.sh` (the multi-task cycle planner) builds this payload for EVERY dispatch
a cycle builds, in EVERY mode — base mode included, not only hard mode — whenever the cycle
schedules more than one task. This closes a gap where a dispatched agent had no way to know a
concurrent sibling existed at all: two dispatches ran on one tree, one absorbed the other's
uncommitted work on a shared commit, one ran `git-snapshot.sh` in its reverting default mode and
discarded the other's in-flight edits, and one reported the other for a `file_scope` breach that
had never happened. A dispatch file is the ONLY channel that reaches a running dispatch — a
message sent mid-flight does not arrive until after the dispatch has already finished and
committed (see `context/patterns/dispatch-report-not-termination.md`) — so any fact knowable at
dispatch time belongs here, not in a later message.

**Payload shape** (opaque JSON, passed via the same `--territory` flag and rendered under the
same `## Territory` section `orchestrate-build-dispatch.sh` already renders for H7 above):

```json
{
  "concurrent_siblings": [
    {
      "task_number": 542,
      "phase": "implement",
      "file_scope": ["FormalSystem/Metalogic/Soundness.lean"],
      "scope_declared": true,
      "scope_granularity": "file",
      "entries": [
        {"path": "FormalSystem/Metalogic/Soundness.lean", "granularity": "file"}
      ],
      "note": null
    },
    {
      "task_number": 562,
      "phase": "implement",
      "file_scope": null,
      "scope_declared": false,
      "scope_granularity": "undeclared",
      "entries": [],
      "note": "No file_scope declared for this task -- it may touch any file in the repository."
    }
  ],
  "concurrency_note": "..."
}
```

When this same task is ALSO a hard-mode H1 implement candidate, `concurrent_siblings` is merged
into that same JSON object alongside `owned_files`/`read_only_files`/`forbidden_files` rather than
replacing them — hard mode gains this cross-task fact too, instead of it staying a base-mode-only
feature under another name.

**Granularity labels and the undeclared sentinel** — stated plainly, because this is the part a
dispatched agent must act on, not just read: a `file_scope` entry is classified `file` (a literal
path), `directory` (a trailing `/`, or an existing directory relative to the repo root), or `glob`
(contains `*`, `?`, or `[`). A sibling's own roll-up `scope_granularity` is `file` only when EVERY
entry is `file`; any directory or glob entry makes the whole sibling `coarse`; and a `file_scope`
that is absent, `null`, or `[]` makes the sibling `undeclared` — rendered explicitly, NEVER
dropped from the list, because an invisible sibling is exactly the failure mode this section
exists to close. **A `coarse` or `undeclared` sibling may touch ANY file** — within its declared
directory/glob for `coarse`, or anywhere in the repository at all for `undeclared` — and its
`note` field says so. Do not read a narrow `file` classification on every OTHER sibling as proof
your own files are safe from a `coarse` or `undeclared` one.

**Agent obligations** when `concurrent_siblings` is non-empty, adapted from the H1
`concurrency_note` above:
1. Re-read a file immediately before editing it and again immediately before committing it, in
   case a sibling has changed it since you last read it.
2. Stage and commit only THIS task's own hunks — never a directory or glob `git add`, which would
   sweep in a sibling's uncommitted work.
3. Never run `git-snapshot.sh` in its reverting default mode; it can discard a sibling's in-flight
   edits along with your own rollback target.
4. Treat an unexpected build failure in a file outside your own `file_scope` as possibly a
   sibling's in-flight edit, not necessarily your own regression.
5. If you observe a foreign commit, a foreign uncommitted modification, or a running build you did
   not start, STOP and report it — after checking `git log` to confirm the work is not your own —
   rather than proceeding or dismissing it as noise (see
   `context/patterns/dispatch-report-not-termination.md`).

**Over-inclusion is intentional, not a bug**: a dispatch file is built before later same-cycle
siblings acquire their own locks, so a sibling later deferred by the live loop may still be named
here. The wording says "scheduled concurrently this cycle", never "running" — a named-but-deferred
sibling is a false positive an agent can dismiss with one `git log` check; silently omitting a
sibling that IS running is the failure mode this section exists to close.

**Relationship to three separate, adjacent concerns — read this before assuming this section
covers more than it does**:
- **H7 within-task territory (above)**: a DIFFERENT fact (which files THIS task's own plan
  assigns to THIS phase), not cross-task concurrency. The two can coexist on one dispatch (see the
  merge note above) but are never conflated.
- **The absent/coarse-`file_scope` ADMISSION posture**: whether an absent or coarse `file_scope`
  should defer a task's admission into a concurrent batch in the first place is a decision owned
  entirely by `orchestrate-batch-admit.sh`'s own admission gate, a separate piece of work. This
  section only REPRESENTS the absence/coarseness so a dispatched agent can see and react to it —
  it never decides whether that same task should have been admitted at all.
- **Working-tree or build isolation** between concurrent dispatches (e.g. separate worktrees, or
  serialized builds) is a distinct, unimplemented remedy owned elsewhere. This payload is a
  necessary but partial mitigation: it informs agents sharing one tree, it does not give them
  separate trees.

## Plan-Section Territory

When multiple agents work on different phases of the same plan file:

- Each agent edits ONLY the checklist items for its assigned phase
- Phase heading status markers (`[IN PROGRESS]`, `[COMPLETED]`) may only be updated
  by the agent assigned to that phase
- The plan file preamble (Overview, Goals, Risks) is read-only for all implementation agents

## Commit Protocol

When working under territory constraints, agents follow strict commit discipline:

1. **Verify build before commit**: All commits must have a green build (or explicit "no build"
   task type). A failing commit is a territory violation regardless of who caused the failure.

2. **Non-fast-forward handling**: If `git commit` fails due to a non-fast-forward conflict:
   ```bash
   git fetch origin
   git rebase origin/$(git branch --show-current)
   # Re-verify build after rebase
   git commit ...
   ```

3. **Never force-push**: Territory violations by other agents are resolved via rebase,
   not force-push.

4. **Incremental commits**: Commit at each completed sub-task, not one commit at the end.
   Each commit message identifies the territory: "task N phase P: {step description}"

## Handoff Merge Rule

The `.orchestrator-handoff.json` file is a shared state file. Multiple agents may need
to update it. The protocol:

1. **Read current state**: Always read the file immediately before writing
2. **Merge, not clobber**: Merge your results into the existing JSON, do not overwrite
3. **Atomic update**: Write the merged result in a single Write operation
4. **Conflict resolution — reviewed against the `dispatch_seq` contract (Defect A)**: "last-write
   wins" is NOT a safe default for identifying whose write should be trusted — the whole point of
   `dispatch_seq` (see `context/patterns/dispatch-report-not-termination.md`) is that the
   chronologically LAST write to this file is not necessarily the current dispatch's own write; a
   woken predecessor's late write is, by construction, always the most recent one on disk. Do not
   read "last-write wins" as license to trust whichever write happened most recently in time.
   What DOES still hold, and is unaffected by this correction: two DIFFERENT phases' agents
   merging their own PHASE-SPECIFIC fields into the same handoff round-trip (read, add this
   phase's own data, write) do not need to coordinate with each other on those fields, because
   each phase's fields are disjoint. Fields shared across phases (e.g. `status`,
   `phases_completed`) still require re-read-merge, as before. The orchestrator's own Stage 5
   `dispatch_seq` gate — not "most recent mtime" and not "most recent write" — is the actual
   authority for which write is treated as this cycle's own.

## Territory Declaration Template

The orchestrator includes this in each dispatch context:

```
Territory for this dispatch:
- Owned files: [list the exact files this agent creates/modifies]
- Read-only references: [list files this agent consults but must not write]
- Shared state file: .orchestrator-handoff.json (merge-write protocol required)
- Phase: {phase number and name}
- Scope: Do not work outside this phase's checklist items

This declaration asserts only what is locally checkable: which files THIS dispatch owns. It does
NOT assert that no other agent is concurrently active — a dispatch that has reported once may
still be live (a self-armed watcher/monitor, or an operator resume) and may still be committing
or writing files concurrently with this one. See
`context/patterns/dispatch-report-not-termination.md` for why. If you observe work you did not
do — a foreign commit, a foreign uncommitted modification, a running build you did not start —
STOP and report it. Do not proceed as though it were fictitious, and do not silently dismiss it
as noise.
```

**Explicit removal note**: no version of this template, past or present, licenses a dispatched
agent to conclude "I am the only agent working on this task" from anything stated here. If a
future edit reintroduces language that reads that way (e.g. "you have exclusive access" or "no
other agent is active"), that is a regression against this contract's intent — remove it rather
than resolve the tension in the agent's favor.
