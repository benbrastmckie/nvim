# Research Report: Task #349

**Task**: 349 - Add an /approve command to the agent system so a specification approval is given by answering one interactive question instead of a terminal round-trip
**Started**: 2026-10-09
**Completed**: 2026-10-09
**Effort**: 3-6 hours (plan/implement)
**Dependencies**: 300 (askuserquestion_unreachable_in_subagents — archived, SATISFIED)
**Sources/Inputs**:
- `~/Projects/Logos/Verification/specs/state.json` and task 233's artifacts (companion task)
- `~/Projects/Logos/Verification/components/framed_channel/{approve.sh,scripts/check-approvals.sh,certificate/README.md,tests/approvals/*}`
- `~/Projects/Logos/Verification/books/convention/09-trust-unit-is-the-export.md`, `books/lean/BookCert/Depends.lean`
- `specs/archive/300_askuserquestion_unreachable_in_subagents/{reports,summaries}/*` (this repository)
- `agent-system/extensions/{books,formal,z3,email,core}/**` (this repository)
- `agent-system/extensions/core/context/standards/interactive-selection.md`
- `agent-system/extensions/email/context/project/email/patterns/bulk-bucket-review.md`
- `agent-system/extensions/core/commands/{tag,please,merge,review}.md`
**Artifacts**:
- This report: `specs/349_add_approve_command_owner_labeled_approvals/reports/01_approve-command-owner-labeled-approvals.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The cross-repository prerequisite is satisfied, not pending.** `Logos/Verification` task 233
  (`owner_labeled_agent_assisted_approvals`) is `status: completed`. `approve.sh` already accepts
  `--via-prompt --assisted-by "Name (agent) <email>"`, writing `by: person`,
  `confirmed_via: prompt`, `assisted_by: "..."`; `check-approvals.sh` enforces both suffix rules
  independently. This command has an honest mechanism to drive today.
- **Placement: a new small extension, not `books`.** `books`' own charter (EXTENSION.md,
  README.md) scopes it to the `book.toml`/`book.cert.json` metadata layer and its "certificate
  boundary" is that layer's boundary, explicitly excluding "originating or verifying new Lean
  content." The component-level release certificate this command drives
  (`components/<name>/certificate/{digests,axioms,ladder,countermodels,recheck}.txt` +
  `approvals.yaml`, Comparator-based) is a different, unrelated certificate concept that predates
  and sits outside `books`. `core` is also the wrong home: `core` is always loaded in every
  deployment (including plain non-Lean repositories), while `/approve` is meaningful only in a
  repository shaped like `Logos/Verification` (a `components/<name>/approve.sh` to drive). The
  nearest working precedent for an opt-in, narrowly-scoped utility extension with no task-type
  routing is `z3`/`formal`'s minimal shape, and for a no-task-routed command living beside
  research/plan/implement, `core`'s own `/tag`, `/please`, `/merge` (listed in `manifest.json`
  with no `routing_agents` entry).
- **The settled AskUserQuestion-unreachability finding (task 300) already has a working rehome
  pattern to copy**: `skill-meta`'s `allowed-tools: Agent, AskUserQuestion, ...` plus a
  pre-delegation "Run the Interview" stage that calls `AskUserQuestion` directly in the skill,
  before any `Agent` dispatch. `/approve`'s skill should declare `AskUserQuestion` in its own
  `allowed-tools` and never delegate the asking step to a dispatched agent.
- **Scope items (3) and (8) reconcile cleanly inside the 4-option cap** using the email
  extension's `bulk-bucket-review.md` idiom (consolidated-approval-with-escape) composed with a
  per-item step-through: an optional bulk "approve all mechanical-only items" gate first, then one
  `AskUserQuestion` per remaining item with exactly `Approve` / `Decline` / `Discuss this item` /
  `Decide later`. Escape 2 (open the files) needs no dedicated option at all — it falls out for
  free once item (6)'s persisted path is real, because the owner is talking to the root session
  directly and can read the file in their editor at any time, independent of what the tool is
  asking.
- **Item (7)'s confidence vocabulary should be exactly two tiers, MEASURED / INFERENCE**, taken
  verbatim from `books/convention/09-trust-unit-is-the-export.md` (Decision 9) and
  `BookCert/Depends.lean`'s own comments — not a graded scale. The task description's citation
  path (`docs/book-convention.md`) is stale: the convention was split into
  `books/convention/{01..19}-*.md`; Decision 9 now lives at
  `books/convention/09-trust-unit-is-the-export.md`.
- **The naming convention for (6) should compose two precedents already in this repository**
  rather than invent a third: `/review`'s no-task date-keyed identity (`review-{DATE}.md`,
  with a `-{suffix}` disambiguator already used for `review-2026-09-22-roadmap.md`) for the
  no-task case, and `artifact-formats.md`'s zero-padded `MM_` sequence-number convention for the
  instance axis.

## Context & Scope

Researched what this task needs to decide before any file is written: (1) extension placement,
(2)/(5) the command/generalization shape against the now-landed `approve.sh --via-prompt`
contract, (3)+(8) the interaction design under the AskUserQuestion option cap, (4) the three
refusal cases, (6) the persisted-artifact naming convention including the no-task case and the
`specs/.gitignore` tracking decision, and (7) the confidence vocabulary. Out of scope (per the
dispatch): changing `approve.sh`/`check-approvals.sh` themselves, and any policy question about
which specifications deserve scrutiny. This report does not write any extension files; it
surfaces grounded recommendations for the plan to adopt as the actual rulings the acceptance
criteria require.

## Findings

### Codebase Patterns

**The companion mechanism (Verification task 233) is complete and its interface is this
command's actual load-bearing dependency.**

```
bash components/framed_channel/approve.sh --review (--core-only|--aeneas) [--out FILE] [--selection] [--spec MODULE]... [--all]
bash components/framed_channel/approve.sh --record FILE --approver "Name (owner) <email>" \
    --via-prompt --assisted-by "Name (agent) <email>" (--core-only|--aeneas)
```

- `--review` never needs a terminal; it writes one Markdown review file containing a `## Notes`
  section, a `## Decisions` fenced block (`no  selection  ...` / `no  spec  MODULE  ...` lines,
  each to be flipped to `yes`), and per-item evidence: `diff_since` — a real `git diff` against
  the commit that recorded the *previous* approval's digest for that item, or
  `(never approved: review the full text)` when there is none.
- `--record` re-verifies every digest and **refuses** ("the Rust or the candidate set changed
  since the review was written: review again" / "$m changed since the review") if anything moved
  between `--review` and `--record` — this is the mechanical half of scope item (4)'s "stale
  review" refusal; `/approve`'s own job is to not swallow that non-zero exit, not to re-implement
  the check.
- For `--via-prompt`, the Notes section **must** carry a `^Question:` line and a `^Answer:` line
  (verbatim grep match, `components/framed_channel/approve.sh` lines ~383-387) or `--record`
  refuses. This is exactly scope item (2)'s requirement to put "the question and the answer
  verbatim into the review file's Notes."
- `approvals.yaml`'s per-record shape (`certificate/README.md`): `by: person`,
  `confirmed_via: prompt`, `assisted_by: "Name (agent) <email>"` — the agent's name must
  independently end `(agent)`, the approver's must not, and `check-approvals.sh` enforces both
  pairings as **two independent predicates**, neither satisfiable by the other's value.
- Only `components/framed_channel/approve.sh` exists today; `distsys`, `fault_tolerance`,
  `rle_codec` have none yet. This matches scope item (5)'s framing exactly ("other components may
  grow one") and confirms the generalization is forward-looking, not retrofitting an existing
  second user.
- `--core-only`/`--aeneas` are `framed_channel`'s own bridge-scope flags (mirroring
  `spec-check.sh`), not a generic `approve.sh` contract. `/approve`'s generalization (item 5)
  should resolve `components/<component>/approve.sh` relative to the repository root and forward
  any trailing flags verbatim, rather than hardcoding `--core-only`/`--aeneas` as the universal
  flag set — a future component's `approve.sh` may have different scope flags, and `/approve`
  should not need to know them.
- **"Stale against the tree"** (scope item 4) already has a mechanical detector baked into
  `--record`'s digest re-check; `/approve`'s refusal-with-a-test obligation is to surface that
  non-zero exit as its own named refusal case (not reinterpret or paper over it), and to never
  retry with a weaker channel.

**Why `books` is the wrong home (scope item 1), with evidence, not just the task's own framing.**

`agent-system/extensions/books/EXTENSION.md`: "**Originating or verifying new Lean content is out
of scope**... `books` owns the metadata layer and its own convention's health, not the content
itself." `README.md` line 88 ties "the certificate boundary" explicitly to `book.toml`/
`book.cert.json` — the per-book metadata certificate, built by `books-certify.sh`. This is a
different artifact from the component-level release certificate `/approve` drives
(`components/<name>/certificate/{digests,axioms,ladder,countermodels,recheck}.txt` plus
`approvals.yaml`, built by `check.sh --aeneas`/`full-gate.sh` and gated by Comparator). Nothing in
`books` imports, reads, or writes `approvals.yaml`; `/certify` (books) and `/approve` (this task)
would otherwise collide in a user's mental model if co-located under the same extension and
command prefix. Verified: `grep -rn "approvals.yaml\|check-approvals" agent-system/extensions/books/`
returns nothing.

**Why `core` is also not the right home.** `core`'s task-type table is `general`/`meta`/
`markdown` — the three types "always available," loaded in *every* deployment, including a
plain Neovim-config repository that has no `components/` directory at all. `core` does host
several no-task-type-routed utility commands (`/tag`, `/please`, `/merge`, listed in
`manifest.json`'s `commands` array with no corresponding `routing_agents` entry — the structural
precedent `/approve` should follow for *not* needing a new task type), but all three of those are
genuinely domain-free git/version operations, usable in any repository core is loaded into.
`/approve` is not domain-free: it only does anything useful in a repository shaped like
`Logos/Verification`. Bundling it into `core` would mean every single consumer of this agent
system's `core` extension — the one piece installed everywhere — carries a command that silently
no-ops (or errors) in the overwhelming majority of them. A dedicated, opt-in extension (loaded
only in repositories that actually have `components/*/approve.sh`) is the correct scope match,
mirroring `z3`/`formal`'s precedent of a small, narrowly-triggered extension with no task-type
routing burden placed on `core`.

**Recommendation**: a new extension (suggested name: `approvals`, matching the mechanism's own
vocabulary — `approvals.yaml`, `approve.sh`, `check-approvals.sh` — and avoiding the word
"certify," which `books` already owns for a different certificate). Minimal shape, modeled on
`z3`'s `manifest.json` (no `routing_agents`, mirroring `/tag`'s core precedent instead):
`commands/approve.md`, `skills/skill-approve/SKILL.md` (direct execution, no agent), one context
pointer file for the confidence vocabulary and naming-convention rulings. No new agent file is
needed or wanted — the settled constraint from task 300 is precisely that this flow must *not*
pass through a dispatched agent.

**The rehome pattern from task 300 is the concrete template to copy.**
`agent-system/extensions/core/skills/skill-meta/SKILL.md` frontmatter:
`allowed-tools: Agent, AskUserQuestion, Bash, Edit, Read, Write`, with a documented
"Stage 2: Run the Interview (Pre-Delegation — `AskUserQuestion` Runs Here)" whose own comment
states: "**Why this stage exists here and not in the dispatched agent**: `AskUserQuestion` is
measured [unreachable in a subagent]." `skill-approve`'s `allowed-tools` should list
`AskUserQuestion` directly and the whole classify → summarize → ask → record flow must run inside
the skill body itself, never behind an `Agent` dispatch (matching the dispatch's own
"SETTLED CONSTRAINT" section verbatim).

**Reconciling scope items (3) and (8) under the option cap.**
`agent-system/extensions/core/context/standards/interactive-selection.md` documents the schema
(`question`, `header`, `multiSelect`, `options[]`) and a threshold table (1-10 items: direct
selection; 11-20: consider grouping; 21-50: add "Select all"). `email`'s
`bulk-bucket-review.md` is the more directly applicable precedent because it already solves "many
items, one cheap decision, escape to finer granularity, never weaken the review gate" for a
structurally identical problem (per-sender-domain bulk email decisions): a `min()`-not-`avg()`
confidence rollup, option-availability gating (an unsafe bulk option simply does not exist as a
choice, rather than being offered and then filtered), and "split across successive
`AskUserQuestion` calls when the bucket count exceeds one question's option capacity."

Composing both precedents for the 19-item framed_channel scenario:

1. **Bulk triage gate** (one `AskUserQuestion`, offered only when the classifier found at least
   one item with zero declaration-level diff — option-availability gating, mirroring the 0.90
   delete-confidence gate): `Approve all N mechanical-only items` / `Step through every item`
   / `Decline all`. The bulk-approve option's correctness rests on a MEASURED fact (the
   classifier found no declaration-level diff for every item it covers), not a judgment call —
   if the classifier cannot mechanically clear an item, it is excluded from the bulk count and
   falls through to the step-through.
2. **Step-through loop**, one `AskUserQuestion` per remaining item, four options exactly:
   `Approve` / `Decline` / `Discuss this item` / `Decide later`. `Discuss this item` is Escape 1:
   the skill drops out of the structured prompt into ordinary assistant text about that item
   (its diff, its classification, the recommendation and confidence), and re-issues the same
   per-item question once the owner signals they are ready to continue. This works *because*
   the skill runs in the root session (the owner is talking to the same Claude the whole time,
   not relayed through a subagent) — the precedent for "a dedicated option that leads to a
   free-text/conversational detour, then resumes" is `task-review-mode.md`/`task-expand-mode.md`'s
   "New topic..." → free-text-follow-up → resume pattern.
3. **Escape 2 (open the files directly) needs no `AskUserQuestion` option at all.** It is a
   property of item (6) being satisfied (a real, predictable, persisted path), not of the
   interaction design: the owner can open `specs/certificates/<component>/...` in their own
   editor at any point, whether or not a question is currently pending, with zero coordination
   with the skill. The ruling to record is explicitly this: Escape 2 is reachable *because* the
   artifact is tracked and path-predictable, not because any menu offers it.

This single design covers both items without contradiction: (3)'s four-option cap is respected
everywhere (the bulk gate uses 3 of 4 slots, the per-item loop uses all 4), and (8)'s two escapes
are both reachable at every step of the walk — one via a menu option, one via the filesystem.

### External Resources

- `books/convention/09-trust-unit-is-the-export.md` (Logos/Verification), "Decision 9: Trust unit
  is the export": "`book_requires` states each composition hypothesis... the certifier checks
  both directions against the cones (**completeness marked INFERENCE** for cost on the real
  composite; **the cone walk is measured**)." This sentence is the entire precedent: a two-tier
  vocabulary, MEASURED for a mechanically-verified claim, INFERENCE for a completeness/judgment
  claim the tooling does not (cannot, for cost) independently check. `BookCert/Depends.lean`
  (comment above `book_requires` handling) restates the identical two tiers and the reason both
  directions are reported as warnings, never refusals.
- The task description's own citation, `docs/book-convention.md`, does not exist at that path any
  longer (`docs/book-convention-overview.md` does, as a thin pointer); the convention is now
  split into `books/convention/01..19-*.md`. The plan should cite
  `books/convention/09-trust-unit-is-the-export.md` directly.
- `/review`'s no-task artifact precedent (`specs/reviews/review-{DATE}.md`, with a disambiguating
  suffix already in live use: `review-2026-09-22-roadmap.md`) is the existing no-task identity
  scheme in this codebase; `artifact-formats.md`'s `MM_{slug}` zero-padded sequence-number
  convention is the existing instance-numbering scheme. Composing them (rather than inventing a
  third scheme) for scope item (6):
  - Task-having case: `specs/certificates/<component>/task-{N}-{II}.md` (`{N}` unpadded per
    `artifact-formats.md`'s own placeholder table; `{II}` a 2-digit zero-padded instance counter,
    computed as one more than the count of existing `task-{N}-*.md` files for that component).
  - No-task case: `specs/certificates/<component>/adhoc-{DATE}-{II}.md`, directly mirroring
    `review-{DATE}[-{suffix}].md`'s shape, with the same `{II}` instance-counting rule. This
    explicitly and durably names the no-task key rather than leaving it to an empty segment or a
    literal `000` — satisfying the dispatch's explicit demand that the no-task case not be
    settled by accident.
- `specs/.gitignore`'s managed block (`runtime-file-patterns.sh` in *this* repository's `core`
  extension, 24 narrow `**/`-prefixed dotfile/dot-directory patterns) does **not** currently match
  `specs/certificates/` in any consumer repository, and neither does `Logos/Verification`'s root
  `.gitignore` (read directly; no matching pattern). The requirement is therefore not a functional
  fix today but a **deliberate, durable record** against future drift: `runtime-file-patterns.sh`
  already carries this exact kind of comment for other durable paths ("Deliberately does NOT
  include `.orchestrator-handoff.json` or `.return-meta.json` — those are durable, freshness-gated
  provenance and MUST stay tracked"). The plan should add one parallel sentence there (and/or in
  the new extension's own README) naming `specs/certificates/` as a durable, consumer-repo-owned,
  always-tracked directory that must never be absorbed into a future pattern in that generated
  block.

## Recommendations

1. **Create a new extension** (`approvals`, pending final name confirmation in planning), not a
   `books` sub-feature and not a `core` addition. Minimal shape: one command (`approve.md`), one
   direct-execution skill (`skill-approve`), no agent, one context doc holding the confidence
   vocabulary citation and the naming-convention ruling. Record the reason (books' disclaimed
   component-certificate scope; core's universal-load mismatch) in the extension's own
   `EXTENSION.md`/`README.md` before any other file is written, per acceptance criterion 1.
2. **`skill-approve`'s frontmatter declares `AskUserQuestion` directly** in `allowed-tools`
   (copying `skill-meta`'s corrected pattern exactly) and the entire review → classify →
   summarize → ask → record flow runs in the skill body. No `Agent` dispatch anywhere in this
   flow.
3. **Command surface**: `/approve <component> [--instance ARGS...]` where `<component>` resolves
   to `components/<component>/approve.sh` relative to the repository root (refuse clearly if
   absent), and any trailing arguments are forwarded verbatim to that script's `--review` call
   (covers `--core-only`/`--aeneas` today without hardcoding them).
4. **Classification**: read each item's `diff_since` block out of the generated review file.
   An item with `(no diff is available...)`/empty diff after stripping blank-line and known
   boilerplate-line hunks (license header, import-only lines with no identifier change) is
   mechanical; everything else is presented as a declaration-level candidate. Every
   recommendation/confidence pairing must name which rule classified it (MEASURED: the diff
   literally contains no non-boilerplate hunk; INFERENCE: the agent read the hunk and judged it
   non-semantic without an independent mechanical check).
5. **Interaction design**: adopt the bulk-triage-gate-then-step-through-loop design from Findings
   verbatim, with the exact four per-item options (`Approve`/`Decline`/`Discuss this
   item`/`Decide later`) and the explicit ruling that Escape 2 needs no menu option.
6. **Refusals**, each with its own test fixture: (a) `--record` exits non-zero because the tree
   moved since `--review` — propagate approve.sh's own message, do not retry with `--agent`;
   (b) the classifier finds a declaration-level diff on an item the summary's discrepancy list
   did not name — refuse before calling `--record` at all; (c) `AskUserQuestion` is unreachable —
   detect via the same `orchestrator_mode` flag this very dispatch carries (an autonomous
   `/orchestrate` cycle must never attempt the prompt) and via a non-interactive-environment
   check, and refuse rather than falling back to `--agent`.
7. **Confidence vocabulary**: exactly `MEASURED` / `INFERENCE`, citing
   `books/convention/09-trust-unit-is-the-export.md` (Decision 9) and `BookCert/Depends.lean`
   verbatim in the new extension's own context doc — no graded/numeric scale.
8. **Naming convention**: `specs/certificates/<component>/task-{N}-{II}.md` and
   `specs/certificates/<component>/adhoc-{DATE}-{II}.md`, per Findings; record both forms and the
   instance-counting rule in the same context doc.
9. **`specs/.gitignore` tracking**: add one explicit, durable comment to
   `runtime-file-patterns.sh`'s header (this repository's `core` extension, the single generator
   for every consumer's managed block) naming `specs/certificates/` as deliberately excluded from
   the ephemeral-runtime-file class, mirroring the existing `.orchestrator-handoff.json`/
   `.return-meta.json` precedent sentence already there. No functional pattern change is needed
   today (verified: nothing currently matches), only the durable record the dispatch requires.

## Decisions

- **Placement is a new extension, not `books` and not `core`** — decided on the evidence above
  (disclaimed scope in `books`; universal-load mismatch in `core`), not merely deferred to the
  plan to re-litigate.
- **The companion cross-repo prerequisite is satisfied**: task 233 in `Logos/Verification` is
  `completed`, and its `--via-prompt --assisted-by` contract is the one this command drives,
  verbatim, with no changes requested to it (per the dispatch's own CLOSED QUESTION).
- **The confidence vocabulary is two-tier (MEASURED/INFERENCE), not graded** — derived from and
  citing Decision 9, per the dispatch's explicit instruction to follow that precedent rather than
  invent a parallel scale.
- **Escape 2 (open the files) is structural, not a menu option** — it is satisfied by the
  persisted-path requirement alone, which keeps the per-item question inside the 4-option cap
  with room for Escape 1 and a fourth option (`Decide later`) besides.

## Risks & Mitigations

- **Risk**: a future component's `approve.sh` diverges from `framed_channel`'s exact flag/Notes
  contract (e.g., a different Decisions-block shape), silently breaking `/approve`'s parsing.
  **Mitigation**: `/approve` should treat the review file's shape defensively (fail loud on an
  unrecognized `## Decisions`/`## Notes` shape) rather than assuming every component's
  `approve.sh` is byte-for-byte `framed_channel`'s; this is a plan-time design note, not a
  blocking unknown, since no second component exists yet to diverge.
- **Risk**: the bulk-triage gate's "mechanical-only" classification is itself an INFERENCE for any
  hunk the agent cannot cleanly attribute to boilerplate (e.g., a renamed identifier that is
  genuinely cosmetic but textually touches a declaration line). **Mitigation**: the design in
  Recommendation 4 keeps the MEASURED bar narrow (no non-boilerplate hunk at all) specifically so
  that borderline cases default to the step-through path rather than the bulk gate — never widen
  the MEASURED criterion to admit judgment calls.
- **Risk**: `orchestrator_mode` detection for refusal case (c) could be bypassed by a future
  caller that does not set the flag. **Mitigation**: also refuse on the structural absence of an
  interactive channel (no controlling session attached) as a second, independent check — the
  dispatch names both triggers ("no human is attached, or... the settled subagent-reachability
  limit") and both should gate independently, matching `check-approvals.sh`'s own precedent of
  independent predicates for independent facts.

## Context Extension Recommendations

- **Topic**: cross-repository companion-task tracking for agent-system commands whose mechanism
  lives in a consumer repository.
- **Gap**: no existing context file documents the pattern this task embodies (a command in the
  agent-system source store driving a script that lives, and is maintained, in a different git
  repository entirely). `context/patterns/` has no "cross-repo mechanism dependency" pattern doc.
- **Recommendation**: once `/approve` lands, consider a short pattern note under
  `agent-system/extensions/core/context/patterns/` naming this as a recognized shape (a thin
  driver extension in this repo, paired with a mechanism-owning task in the consumer repo,
  discovered by slug rather than task number since task numbers do not carry across
  repositories) — useful if a second such pairing arises.

## Appendix

- Search queries / probes used: `jq` lookups against both repositories' `specs/state.json`;
  `grep -rn` for `AskUserQuestion`, `multiSelect`, `INFERENCE`, `component certificate`,
  `specs/reviews`, and the `approve.sh`/`check-approvals.sh` source directly; `find` for the
  archived task-300 directory and the Verification task-233 directory.
- References:
  - `~/Projects/Logos/Verification/components/framed_channel/approve.sh`
  - `~/Projects/Logos/Verification/components/framed_channel/certificate/README.md`
  - `~/Projects/Logos/Verification/components/framed_channel/tests/approvals/owner-prompt.yaml`
  - `~/Projects/Logos/Verification/books/convention/09-trust-unit-is-the-export.md`
  - `~/Projects/Logos/Verification/books/lean/BookCert/Depends.lean`
  - `~/Projects/Logos/Verification/specs/233_owner_labeled_agent_assisted_approvals/summaries/`
  - `specs/archive/300_askuserquestion_unreachable_in_subagents/summaries/01_rehome-askuserquestion-gates-summary.md`
  - `agent-system/extensions/core/skills/skill-meta/SKILL.md`
  - `agent-system/extensions/core/context/standards/interactive-selection.md`
  - `agent-system/extensions/email/context/project/email/patterns/bulk-bucket-review.md`
  - `agent-system/extensions/books/EXTENSION.md`, `agent-system/extensions/books/README.md`
  - `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh`
