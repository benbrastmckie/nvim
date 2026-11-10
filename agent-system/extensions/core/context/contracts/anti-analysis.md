# Anti-Analysis Contract (H2)

This contract implements H2: Anti-Analysis-Paralysis. It is a hard behavioral constraint
for all hard-mode agents. The single highest-value technique distilled from a cross-repo
high-complexity orchestration case study (the BimodalLogic per-phase-dispatch baseline):
per-phase dispatch moved implementation from 0 lines across 3 dispatches to 2,400+ lines
across 13 dispatches only after this contract was in force.

## Read Budget

- Maximum 15-20% of total effort on reading, searching, and analysis before first file edit
- First file creation or modification MUST happen within the first 20% of tool calls
- Reading an existing file for context is permitted; re-reading a file you already read is
  a context-pressure signal (see context-exhaustion-detection.md), not a license to plan

**Enforcement**: If you have made 15+ tool calls with no Write or Edit, you are in violation.
Write something immediately. A partial first file is better than continued analysis.

## Forbidden Conclusions

The following outputs are NOT acceptable as final deliverables from an implementation dispatch:

1. "The current approach is wrong" — without a concrete counterexample and an alternative
2. "A different representation is needed" — without implementing at least the skeleton of
   the new representation in the same dispatch
3. "Estimated N lines of work remain" — as the primary output of a dispatch
4. "I need to understand X better before proceeding" — without having attempted X
5. "This requires further research" — in an implementation dispatch (research dispatches exist)
6. "The design has a fundamental issue" — without either fixing it or stating the exact
   counterexample that makes it unfixable

These are analysis-paralysis signatures. Agents that produce them without accompanying
implementation have failed the dispatch.

## Defect Bar

An agent may claim a design decision is defective ONLY when ALL of the following hold:

1. **Concrete counterexample**: A specific case is stated verbatim (not described in general)
2. **Current behavior**: What the current implementation does on that case
3. **Required behavior**: What the correct implementation must do
4. **Isolation**: The defect is in a specific identified component (not "the whole approach")

Without all four elements, a defect claim is analysis, not implementation work.

## Sub-Sorry Policy

**`--hard`-only**: This entire contract, including this policy, is loaded exclusively via
`skill-orchestrate`'s hard-mode contract injection (Stage 3.5, gated on `hard_mode == "true"`),
which appends it to every hard-mode research/plan/implement dispatch's prompt; STANDARD mode
never loads this file and its zero-debt bar is unaffected by anything below. cslib's and lean's
own hard-mode implementation agents also reference it directly.

- Tightly scoped, documented leaf sub-sorrys are acceptable progress markers
- Main target theorems (or main-target-level constructs in non-formal domains) as sorry-stubs
  are not acceptable as final dispatch output, EXCEPT when they qualify as a strategic sorry
  under the "Strategic sorries" test below
- Each sorry must include a comment stating: (a) what it assumes, (b) why it was deferred,
  (c) which next dispatch should address it

### Strategic sorries (skeleton division points)

A main-target-level placeholder is acceptable as a **strategic sorry** — a deliberate division
point in a skeleton, not an abandoned or stuck proof — ONLY when ALL five conditions hold:

1. **Deliberate division boundary**: The sorry marks a division point that was planned as part
   of a skeleton (e.g., from a hard-mode plan's phase/part breakdown), not a proof the agent got
   stuck on and gave up. An abandoned or stuck attempt is never strategic.
2. **Tightly scoped**: The placeholder is scoped to exactly one theorem, function, or definition
   — not an entire module, file, or multi-part goal.
3. **Documented**: The sorry's accompanying comment states (a) the assumption it stands in for,
   (b) why it was deferred rather than completed in this dispatch, and (c) the owning follow-up
   task or sub-phase that will discharge it.
4. **Tracked**: The sorry is recorded in the handoff `sorry_inventory` (see `wrap-up.md`) with
   `strategic: true` and a non-null `follow_up_task`. An undocumented or untracked sorry is never
   strategic — it forces `status: "partial"` or `status: "blocked"`, not `"implemented"`.
5. **Build-green**: The placeholder is a syntactically/type-valid token in the target language
   (`sorry` in Lean4; domain equivalents such as `admit`, `raise NotImplementedError`, or an
   explicit `-- STUB:` marker) — the build/typecheck must still pass.

A dispatch meeting all five conditions for every main-target-level placeholder it introduces
reports `status: "implemented"` with `skeleton: true` (see `wrap-up.md` for the field and the
full `sorry_inventory` schema), rather than being forced toward `partial`/`blocked` or into
analysis-paralysis. Non-strategic main-target sorries — i.e. any that fail one or more of the
five conditions — remain forbidden under the "Forbidden Conclusions" section above.

**Family relationship**: a strategic sorry is one of two members of one documented family —
"documented incompleteness that still counts as success." The other member is a **reasoned
exclusion** (`[COMPLETED WITH EXCLUSIONS]`, a phase-heading marker), for phases whose remaining
items are decided rather than merely deferred: see `context/standards/status-markers.md`'s
`[COMPLETED WITH EXCLUSIONS]` subsection for its own five-condition admission test and
`context/formats/plan-format.md`'s `#### Reasoned Exclusions` record format. The distinguishing
axis: a strategic sorry is *deferred with a tracked follow-up* (`follow_up_task` non-null); a
reasoned exclusion is *decided and will not be revisited* (no follow-up field exists at all).

## Settled-Design Preamble Protocol

At the start of each dispatch, the agent MUST restate:

1. The decided design (1-3 sentences)
2. Ruled-out alternatives (brief list with rejection reasons)
3. What has been completed and must not regress

This prevents "re-opening" settled decisions during implementation.

## Domain Specialization

This is the domain-agnostic baseline. Extensions may override with stricter versions:

- **lean4**: H2 applies with a formal proof line bar (first sorry-free lemma within 20 tool calls)
- **z3**: H2 applies with a satisfying-assignment bar (first passing assert within 20 tool calls)
- An extension override deploys to a flat, domain-prefixed basename directly under the shared
  `context/contracts/` directory (e.g. `context/contracts/lean4-anti-analysis.md`), declared by
  that extension's own `provides.context` entry and reached via its manifest's `hard_contracts`
  `replace:` directive — never at a nested or extension-namespaced path such as
  `.claude/extensions/{domain}/context/contracts/anti-analysis.md`, which no deployed tree
  produces. See `context/guides/manifest-routing-schema.md`'s "Override Contract Placement
  Convention" subsection for the full convention and the clobber hazard it prevents.
