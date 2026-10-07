# Research Report: Task #357

**Task**: 357 - Fold phase-end handoff into phase commit
**Started**: 2026-10-07
**Completed**: 2026-10-07
**Effort**: small-medium (doc/prose reorder + one standards-doc amendment; no new schema, no new doc)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/agents/general-implementation-agent.md`,
  `agent-system/extensions/books/agents/books-implementation-agent.md`,
  `agent-system/extensions/core/context/standards/git-staging-scope.md`,
  `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`,
  `agent-system/extensions/core/context/contracts/phase-closure.md`,
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `agent-system/extensions/core/scripts/git-commit-scoped.sh`
- `git show --stat` against the live consumer repo at `~/Projects/Logos/Verification` (direct
  re-measurement of the commits cited in the dispatch)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The load-bearing question is answered: **no consumer depends on the per-phase markdown
  handoff landing in its own commit.** The only mtime/`dispatch_seq` freshness gate in the
  codebase guards `.orchestrator-handoff.json` — a different, single, task-root JSON artifact
  written only by hard-mode wrap-up, whose freshness is keyed to file mtime and an embedded
  content field, neither of which depends on commit boundaries. The per-phase
  `handoffs/phase-{P}-handoff-*.md` files have no reader anywhere that checks freshness at all;
  they are plain durable task provenance, explicitly named alongside `reports/`, `plans/`,
  `summaries/` in `git-staging-scope.md`'s own exclusion-set rationale as content that belongs
  inside the ordinary task-directory commit.
- **Recommendation: fold.** The two-commit pattern is not a documented, intentional design — it
  is an emergent deviation from a design that already calls for ONE commit. Both
  `general-implementation-agent.md` and `books-implementation-agent.md` already instruct writing
  the phase-end handoff as part of "mark phase complete," textually *before* the commit step, and
  the commit step's own pathspec (the whole task directory) already sweeps the handoff file in.
  The observed two-commit split happens because the handoff-write instruction is worded as a
  trailing, easy-to-defer afterthought relative to the commit step, not because any script or
  schema enforces separation.
- The measured evidence is re-confirmed exactly via live `git show --stat` against the consumer
  repo. The "correction to the second instance" in the dispatch is also upheld: the `(tracking
  update)` commits carry plan-checklist/progress-file content, not a handoff file, and their
  preceding "work" commit does not even follow the `task {N} phase {P}: {name}` message
  convention — a related but distinct manifestation of the same general anti-pattern family
  (late-sequenced provenance trailing after a work commit), not the identical code path.
- The dispatch's suggested defect location (`skill-orchestrate/SKILL.md` /
  `orchestrate-cycle-postflight.sh`) is corrected by this research: those two files only commit
  once per **dispatch return** (research/plan/implement completion), never per **plan-phase**.
  The per-plan-phase commit pair under investigation is produced entirely inside a single
  `implement` dispatch's own internal loop, in `general-implementation-agent.md`'s Stage
  4D-iii + Phase Checkpoint Protocol (and the equivalent section of every extension
  implementation agent that runs its own phase loop, confirmed for `books-implementation-agent.md`).

## Context & Scope

Researched whether the handoff-then-separate-commit pattern observed in a live consumer-repo
`/orchestrate` batch is load-bearing (required by some freshness/identity consumer) or an
unintended doubling that can be folded into the phase's own work commit. Scope was limited to:
confirming the measured evidence, locating the producing code/prose, searching for any consumer
of handoff-commit separation, evaluating the crash-ordering tradeoff, and classifying the related
`(tracking update)` shape. No files were edited — this is a research-only dispatch; the actual
fold (if accepted) is deferred to planning/implementation.

## Findings

### Codebase Patterns

**Where the two commits actually come from.** `general-implementation-agent.md`'s Stage 4
sequence is: C. Verify Phase Completion -> D. Mark Phase Complete (`update-phase-status.sh`) ->
4D-ii Post-Phase Self-Review (plan-checklist/deviation annotation) -> 4D-iii Progressive Handoff
Update ("**Write a phase-end handoff** to `specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-
{TIMESTAMP}.md`"). Only *after* all of that does the separately-headed "Phase Checkpoint
Protocol" section (near the bottom of the same file) restate the sequence compactly and name the
commit: step 5, `git-commit-scoped.sh --message "task {N} phase {P}: {phase_name}"`, staging
`"${task_dir}/" "specs/TODO.md" "specs/state.json"` plus `files_touched`. Because `task_dir/` is
staged as a whole directory, a handoff file already written under
`specs/{NNN}_{SLUG}/handoffs/` by the time of that commit call rides along automatically — no
separate staging step exists for it. `books-implementation-agent.md` mirrors this exactly: step D
("Mark Phase Complete") ends with "Write a condensed phase-end handoff ... after each phase
completion (see general agent 4D-iii for template)", and only then does step E, "Git Commit
Phase," fire with the same whole-task-directory pathspec.

In both files, the handoff-write instruction is the textual *tail* of a dense step (self-review
annotations, then handoff, both folded into one step's prose) immediately before a
separately-numbered/lettered commit step. This is exactly the shape that produces the observed
behavior: the commit fires as the next distinct action after "mark complete," and the handoff
write — though documented as preceding it — is executed as an afterthought once the agent
(correctly, per 4D-iii's own standalone paragraph) revisits "write a progressive handoff" as a
freestanding obligation, producing a new uncommitted file with no existing message convention to
reuse. The agent then invents `task {N} phase {P}: add phase-end handoff` for it — a message
format that appears nowhere in the source store as a sanctioned convention (confirmed by
`grep -r "add phase-end handoff"` across `agent-system/`), which is itself evidence the second
commit is improvised at execution time, not produced by any scripted/templated call site.

**Confirmation that nothing scripted produces a second, handoff-only commit.**
`orchestrate-cycle-postflight.sh` and `skill-orchestrate/SKILL.md` contain exactly one
`git-commit-scoped.sh` call site each, firing once per dispatch **return** (i.e., once per
research/plan/implement *lifecycle phase*, not once per implementation-*plan*-phase). Their
commit messages are drawn from a `case` over the dispatch's outcome (`complete implementation`,
`orchestration paused`, etc.) — none of them is phase-numbered and none of them is handoff-shaped.
The dispatch's own lead ("the phase-end sequence in `skill-orchestrate/SKILL.md` and/or
`scripts/orchestrate-cycle-postflight.sh` is where the ordering is produced") does not hold up:
those two files never see the inside of a long-running `implement` dispatch's own per-plan-phase
loop at all. This is a correction to the dispatch's framing, offered as a finding rather than a
rebuttal: the actual production site is the implementation-agent prose itself.

**Existing precedent for the "same commit, never deferred" principle.**
`context/contracts/phase-closure.md`'s "Marker/commit synchrony is bidirectional" section already
states, for the phase-heading marker: "A phase's marker promotion ... is committed together with
that phase's final work, never deferred to a later commit or to the end of the dispatch
(agents/general-implementation-agent.md's existing scoped-commit staging set already includes
`{plan_path}` alongside the task directory, so satisfying this is a sequencing requirement ...
not a new staging requirement)." This is the identical pattern the handoff file is in: staging
already covers it (via the task-directory pathspec), the only gap is *sequencing* — writing it
before, not after, the commit. The phase-end handoff is not currently named in that section, but
the same "sequencing, not staging" framing applies verbatim.

**Load-bearing check — the only freshness/identity gate in the codebase.**
`orchestrator-runtime-files.md`'s Class Table covers `.orchestrator-handoff.json` explicitly:
"Overwritten in place each dispatch cycle (static filename, never deleted)... **Durable
provenance**", read by `skill-orchestrate` Move 3 "gated by mtime/`dispatch_seq`"
(`orchestrate-cycle-postflight.sh` lines ~515-575, confirmed read). This file is (a) singular per
task, not per-phase, (b) written only by a hard-mode implementation agent's H9 wrap-up (today:
cslib's and lean's; core's own was deleted), and (c) its freshness check is `mtime`-window-based
plus a `dispatch_seq` *content* comparison — both independent of git commit boundaries. Writing
it and committing it together, or separately, does not change its filesystem mtime (set at
`Write`-time) or its embedded `dispatch_seq` field. **This gate is unrelated to, and would be
unaffected by, folding the per-phase `handoffs/*.md` continuation file into its phase's work
commit.** The Class Table has no row at all for `handoffs/phase-{P}-handoff-*.md` — it is not a
tracked runtime-file class subject to any freshness policy; it is an ordinary durable task
artifact, the same disposition as `reports/`, `plans/`, `summaries/`.
`skill-orchestrate/SKILL.md`'s own "MUST NOT (Context Flatness Constraint)" section, which
forbids reading `handoffs/*.md` during the orchestration loop, is about a different concern
(bounding what the loop reads, not about commit boundaries) and its one parenthetical mention of
"the handoff, gated by mtime/`dispatch_seq`" is the SAME `.orchestrator-handoff.json` singular
artifact, not the per-phase markdown files (confirmed: that section's subject is "the handoff,"
singular, matching the Class Table's one JSON artifact, not the plural `handoffs/*.md` glob it
forbids reading two lines earlier).

**git-staging-scope.md already treats the handoff file as ordinary task content.** Its "Canonical
Runtime-File Exclusion Set" section states explicitly: an allowlist "would also silently drop
legitimate durable content that live task directories carry (`progress/`, `handoffs/`,
`fixtures/`, `tests/`, `HANDOFF.md`)" — i.e., `handoffs/` is already named as content the
exclusion-pathspec design deliberately does NOT exclude from the task-directory commit. Folding
does not widen staging scope: the handoff path was already inside the sanctioned pathspec before
this task existed.

### External Resources

Not applicable — this is a purely internal orchestration-contract question; no external
documentation bears on it.

### Measured-Evidence Re-Confirmation (live `git show`)

Re-ran `git show --stat` against the four cited pairs in `~/Projects/Logos/Verification`
(session `sess_1791350228_cd127f`, task 229, `task 229 phase {3,4,5,6}`). All four pairs
confirmed EXACTLY as described:

```
df392c3c  task 229 phase 3: retire the counts_seen == books_expected construct ...   (work)
91be9b28  task 229 phase 3: add phase-end handoff                                    (handoff: 1 file, handoffs/phase-3-handoff-20261007T0615Z.md, 37 insertions)
a9f3a18a  task 229 phase 4: fixture the shared stage with a stub driver             (work)
70f5e974  task 229 phase 4: add phase-end handoff                                    (handoff)
f9ca5d8f  task 229 phase 5: converge distsys's inline books stage onto the shared stage (work)
87e1fb08  task 229 phase 5: add phase-end handoff                                    (handoff)
faaa0f40  task 229 phase 6: verify end to end, record exclusions and follow-ons      (work)
38533553  task 229 phase 6: add phase-end handoff                                    (handoff)
```

Every handoff commit carries exactly one file under `handoffs/phase-{P}-handoff-<ts>.md`,
matching the dispatch's claim.

**Correction upheld.** Re-ran `git show --stat` on the cited "second instance" pair (task 206,
`sess_1791350228_cd127f_206`): `93818a50 task 206 phase 5: commit the regenerated recheck record
(tracking update)` touches `plans/01_regenerate-framed-channel-recheck.md` (checklist
annotations) and `progress/phase-5-progress.json` — no handoff file. `61a64b09 task 206 phase 6:
amend Decision 10's Validated by marker (tracking update)` touches the same plan file plus
`progress/phase-6-progress.json` — again no handoff file. The dispatch's correction is confirmed:
this is NOT the same pattern as task 229's handoff doubling. Notably, task 206's preceding "work"
commit for phase 5, `2c6a98b0 task 206: regenerate the framed_channel recheck record`, does not
even carry a `phase {P}:` tag in its subject — it deviates from the
`task {N} phase {P}: {phase_name}` convention that both the work and handoff commits in task 229
otherwise follow. This suggests task 206 ran through a different or non-conforming procedure,
not a verified instance of the exact `general-implementation-agent.md` Phase Checkpoint Protocol
code path this task's file-scope covers.

## Decisions

1. **The separation is NOT load-bearing.** No consumer — scripted or documented — depends on the
   per-phase `handoffs/*.md` continuation file landing in a commit separate from its phase's work
   commit. The sole mtime/`dispatch_seq` freshness gate in the system guards a different,
   singular, task-root artifact (`.orchestrator-handoff.json`) whose freshness is independent of
   commit boundaries.
2. **Fold is the chosen outcome.** The phase-end handoff should be written before the phase's
   closing commit and land inside it, exactly as the existing prose in
   `general-implementation-agent.md` (Stage 4D-iii, before the Phase Checkpoint Protocol's commit
   step) and `books-implementation-agent.md` (step D, before step E) already intends — the fix is
   a **sequencing/emphasis correction in the agent prose**, not a staging-scope change (staging
   already covers it) and not a schema or content change to the handoff itself.
3. **Contract home for the ruling.** Record the single-commit-per-phase expectation in
   `context/standards/git-staging-scope.md`'s `implement` Per-Operation Scope section (the
   dispatch's designated home, and the file that already documents `handoffs/` as in-scope
   content) with an explicit sentence: the per-phase progressive handoff, if written, is staged
   and committed together with that phase's own closing work — never as a separate, trailing,
   handoff-only commit. `context/contracts/phase-closure.md`'s existing "Marker/commit synchrony
   is bidirectional" section is flagged as a strong candidate for a follow-on cross-reference
   (same "sequencing, not staging" framing, same author-intent), but is not itself one of the two
   dispatch-designated homes, so the primary ruling record stays in `git-staging-scope.md`.
4. **The actual behavioral fix site** is `general-implementation-agent.md`'s Stage 4D-iii +
   Phase Checkpoint Protocol wording (reorder/emphasize: write the handoff, THEN commit, in the
   same step, with an explicit "this rides in the same commit — do not commit it separately"
   sentence), plus the equivalent section of every extension implementation agent that
   independently restates the same loop (confirmed present in `books-implementation-agent.md`;
   likely present, unverified in this dispatch, in cslib/lean/latex/nix/neovim/python/rust/typst/
   web/z3's implementation agents — several of those files are concurrently claimed by sibling
   task 356's `file_scope` this cycle and must be coordinated, not assumed exclusive, per the
   dispatch's Territory section).
5. **Crash-ordering tradeoff: acceptable, addressed explicitly.** Today's accidental split means
   a crash between the two commits loses only the handoff file — but this is an artifact of the
   bug, not a deliberate design (the written contract already intended one commit at this exact
   point in the timeline). Under folding, a crash immediately before the single commit loses the
   phase-complete marker flip, the self-review annotations, and the handoff together — but NOT
   any of the phase's substantive file-production work, which is already independently protected
   by Stage 4B-iii's mandatory per-objective green-substep commits (`task {N} phase {P}.{O}:
   {objective_description}`), issued well before the phase-closing commit. The folded commit's
   content is therefore bounded to "phase wrap-up bookkeeping" (marker, progress file, self-review
   annotations, handoff) — losing all of it to a crash means re-doing that bookkeeping on resume,
   not re-doing the phase's work. This is a strictly smaller loss window than existed before any
   per-objective commit discipline was in place, and is judged acceptable; it is recorded here in
   writing per the dispatch's requirement rather than left unaddressed.
6. **The `(tracking update)` shape is classified as: same general defect family (late-sequenced
   provenance content trailing after an already-fired work commit), but a DIFFERENT, unverified
   production site** — content is plan-checklist/progress-file updates (Stage 4D-ii's own
   outputs), not the handoff file (4D-iii), and the preceding work commit in the one measured
   instance does not even follow the documented `task {N} phase {P}: {name}` message convention,
   indicating either a deviating execution or a non-`general-implementation-agent.md` procedure
   for that specific task. It is not ruled "legitimate" (no contract anywhere sanctions a
   trailing tracking-only commit either), but it is explicitly OUT OF SCOPE for this task's fold
   (which is scoped to the phase-end handoff only, per the dispatch's non-goals) and is
   recommended as a separate follow-up audit once the handoff fold's prose-sequencing fix pattern
   is in hand, so the same fix shape can be checked against whichever procedure produced task
   206's commits.

## Risks & Mitigations

- **Risk**: an extension implementation agent not inspected in this dispatch (cslib, lean, latex,
  nix, neovim, python, rust, typst, web, z3 — most under sibling task 356's concurrent
  `file_scope` this cycle) might have its own, differently-worded handoff/commit sequencing that
  a core-only prose fix does not reach. **Mitigation**: record the single-commit-per-phase
  expectation in the shared, cross-referenced `git-staging-scope.md` contract (read by every
  implementation agent per their own `## Context References`), and name the extension-agent
  edits as a recommended, coordinated follow-up rather than silently assuming core's fix
  propagates.
- **Risk**: fixing the sequencing prose alone (without a mechanical check) may not reliably
  change agent behavior, since the current prose already places the handoff-write textually
  before the commit and agents still execute it out of order. **Mitigation**: recommend the
  planning phase make the "do not commit the handoff separately" instruction maximally explicit
  (a standalone, bolded sentence immediately adjacent to the commit step, not a trailing clause
  of a denser step) — the same remediation style `phase-closure.md` already used successfully for
  the analogous marker-promotion defect.
- **Risk**: the `(tracking update)` shape, left unaddressed, continues doubling commits under a
  different content shape. **Mitigation**: explicitly logged as a recommended follow-up task
  rather than silently dropped, per Decision 6 above.

## Context Extension Recommendations

- **Topic**: single-commit-per-phase expectation for all Stage-4D-produced provenance (marker,
  self-review annotations, progressive handoff).
- **Gap**: `phase-closure.md`'s "Marker/commit synchrony is bidirectional" section states this
  principle for the marker only; it does not yet name the handoff file, even though the same
  "sequencing, not staging" framing applies verbatim.
- **Recommendation**: when implementing the fold, consider a one-sentence cross-reference from
  `phase-closure.md`'s existing bullet to the new `git-staging-scope.md` sentence (or vice versa)
  so a future reader finds both halves of the same principle from either entry point — net
  document count still does not increase, since this is a sentence addition to two already-
  existing files, not a new document.

## Appendix

- Search queries / commands used: `grep -rn "handoff" .../skill-orchestrate/SKILL.md`;
  `grep -rln "phase-end handoff"` and `"add phase-end handoff"` across `agent-system/`;
  `grep -n "Phase Checkpoint Protocol|^### |^#### |^## "` on
  `general-implementation-agent.md`; `sed -n` reads of Stage 4C/4D/4D-ii/4D-iii and the Phase
  Checkpoint Protocol section; `git show --stat` on all 4 task-229 pairs and both task-206
  `(tracking update)` commits in `~/Projects/Logos/Verification`; `grep` of
  `orchestrator-runtime-files.md`'s Class Table for `.orchestrator-handoff.json` and for any row
  matching `handoffs/*.md` (none found); `grep` of `orchestrate-cycle-postflight.sh` and
  `skill-orchestrate/SKILL.md` for `git-commit-scoped`/`git commit` call sites (one each, both
  per-dispatch-return, not per-plan-phase).
- References: `agent-system/extensions/core/agents/general-implementation-agent.md` (Stage
  4D-iii, Phase Checkpoint Protocol); `agent-system/extensions/books/agents/
  books-implementation-agent.md` (steps D/E); `agent-system/extensions/core/context/standards/
  git-staging-scope.md`; `agent-system/extensions/core/context/standards/
  orchestrator-runtime-files.md` (Class Table); `agent-system/extensions/core/context/contracts/
  phase-closure.md` ("Marker/commit synchrony is bidirectional"); consumer-repo commits
  `df392c3c`/`91be9b28`/`a9f3a18a`/`70f5e974`/`f9ca5d8f`/`87e1fb08`/`faaa0f40`/`38533553`
  (task 229) and `93818a50`/`61a64b09` (task 206) in `~/Projects/Logos/Verification`.
