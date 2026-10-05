# Semantic Element Usage Standard

## Scope

`patterns/theorem-environments.md` and `patterns/rule-environments.md` document *mechanics*: how
to invoke `#theorem`, `#remark`, `#rule-block`, and the rest. Neither file — nor anything else in
this extension, before this standard — states what any of these elements is *for*, how sparingly
to reach for it, or where it may legally appear relative to headings and the results it discusses.

Every semantic element below is a **rhetorical commitment**, not a decoration. Choosing
`#theorem` over `#remark`, or reaching for `#remark` at all, is an assertion about what kind of
claim the surrounding prose is making. `typst compile` has no opinion on any of this: a
`#remark` standing where opening prose belongs, or a `#remark` smuggling in a 25-item tracking
checklist, compiles to a perfectly valid PDF. This standard exists because compile-success is not
evidence of correct usage, and prose guidance describing correct usage has already been tried and
already failed once in this extension (see `patterns/type-theory-foundations.md`'s narrowly-scoped
sparingness rule, and `templates/chapter-template.md`'s unenforced "Opening paragraph" checklist
item, both predating this file).

## Universal Placement Rule

**A semantic element MUST NOT be the first body content after a heading, with no intervening
prose.**

Every heading — chapter (`=`), section (`==`), or subsection (`===`) — opens with prose that
states what the section is about: what it covers, why it matters, or what problem it addresses.
A semantic element (`#definition`, `#theorem`, `#lemma`, `#corollary`, `#example`, `#proof`,
`#remark`, `#rule-block`, `#rule-list`) comes *after* that prose, never in place of it. This rule
applies uniformly to every element in this file; it is restated, not re-derived, in each element's
own "Legal placement" entry below.

This is the rule that would have caught the motivating defect on its own: a `#remark` standing
immediately after a chapter's `=` heading, with zero intervening prose, violates this rule
regardless of what the remark contained.

## Per-Element Semantics

### Definition

**What it is for**: Introducing a term the chapter will use, with a precise, checkable meaning.
A definition is a *promise*: everything that follows can rely on this term meaning exactly this.

**Expected density**: One per genuinely new concept. Do not wrap routine restatements or
notational shorthand in `#definition` — see `standards/textbook-standards.md`'s Definition
Ordering Principle for the companion rule that every term must be defined before its first use.

**Legal placement**: After motivating prose (see `standards/textbook-standards.md`'s Motivation
Requirements — at least two sentences of motivation, integrated into surrounding narrative, never
under an explicit `_Motivation_` header). Never as the first content after a heading.

### Theorem

**What it is for**: Stating a result the chapter will prove and that later material may cite. A
theorem is the chapter's payload — the thing the surrounding exposition exists to justify.

**Expected density**: Sparse relative to prose. A chapter earns its theorems through the
definitions and motivation that precede them; a chapter that is mostly theorems with no connective
prose has skipped the exposition that makes the results legible.

**Legal placement**: After the definitions it depends on and after prose stating why the result
matters (`standards/textbook-standards.md`: "State why the result matters before proving it").
Never as the first content after a heading.

### Lemma

**What it is for**: A subsidiary result proved in service of a later theorem — a stepping stone,
not a standalone payload.

**Expected density**: As many as the proof of the target theorem genuinely needs, and no more.
Do not extract a lemma merely to shorten a proof if the extracted statement has no standing
independent of that one proof.

**Legal placement**: After the definitions and context it depends on, ordinarily immediately
before the theorem it supports. Never as the first content after a heading.

### Corollary

**What it is for**: An immediate consequence of a theorem just proved, requiring little or no
additional argument. A corollary tells the reader "and therefore, for free, we also get..."

**Expected density**: Only when a genuinely free consequence exists. Do not restate a theorem
with trivially different notation and label the restatement a corollary.

**Legal placement**: Immediately after the theorem (and its proof) it follows from. A corollary
with no preceding theorem in the same section is a contradiction in terms, and — like every
element here — is never the first content after a heading.

### Example

**What it is for**: Grounding an abstract definition or theorem in a concrete instance the reader
can check by hand, or illustrating a boundary case (why a hypothesis is needed, what goes wrong
without it).

**Expected density**: At least one per non-obvious definition; more where the concept is
genuinely subtle. An example is exposition, not decoration — it should do work a reader needs, not
pad the chapter.

**Legal placement**: After the definition or theorem it illustrates. Never as the first content
after a heading, and never used as a substitute for the definition or theorem itself.

### Proof

**What it is for**: Establishing that a theorem, lemma, or corollary is actually true, in standard
mathematical style (`standards/textbook-standards.md`'s Professional Tone Standards apply
throughout).

**Expected density**: One per theorem/lemma/corollary that is not immediate. A stated result with
no proof and no explicit "proof omitted" / "see [reference]" note is incomplete, not sparing.

**Legal placement**: Immediately after the statement it proves, closed with `#qed`. A proof never
opens a section — it has no independent standing without the statement it proves.

### Remark

**What it is for**: A **sparing**, **high-value**, genuinely **off-topic** point, or a **big-picture
reflection on the current development** — commentary that sits outside the main line of
exposition but is worth the reader's attention. A remark is never load-bearing: the chapter's
argument must make complete sense if every remark in it were deleted.

**Expected density**: Low. Reach for `#remark` rarely. If a chapter has more remarks than
theorems, that is a signal the remarks are doing work that belongs in ordinary prose, a
definition, or a dedicated section — not evidence the chapter is unusually reflective. This
generalizes the existing narrow rule in `standards/type-theory-foundations.md` ("Do NOT add DTT
remarks to every definition. The goal is strategic placement, not exhaustive annotation") from
DTT annotations specifically to every use of `#remark` in this extension.

**Legal placement**: A remark **typically follows some substantial result** — a theorem, a proof,
a definition that just landed — because a reflection needs something to reflect *on*. A remark is
**never a chapter opener**: it cannot be the first body content after a `=` heading (or any
heading), because at that point nothing has been established yet for the remark to be "off-topic"
from or to "reflect back" on. A remark is **never a long enumerated status or tracking list**:
if a remark's body is a numbered or bulleted checklist tracking completion, formalization
progress, or open items, it is not a remark — see "Where Tracking Content Belongs" below for
where that content actually goes.

### `rule-block` (from `patterns/rule-environments.md`)

**What it is for**: A single named typing or inference rule (Formation, Introduction,
Elimination, ...) presented with its explanation, for a type former the chapter is defining.

**Expected density**: One per rule the type former actually has. Do not use `rule-block` for
prose explanations that are not stating a formal rule — see `patterns/rule-environments.md`'s
"When to Use" section for the boundary against single equations and definition lists.

**Legal placement**: Within the definitional exposition of the type former it belongs to, after
the prose introducing that type former. Never as the first content after a heading.

### `rule-list` (from `patterns/rule-environments.md`)

**What it is for**: The grouped presentation of the *complete* set of typing rules for one type
former (Formation, Introduction, Elimination, ...) with consistent spacing — the preferred form
whenever more than one related rule is being presented together (see `patterns/rule-environments.md`'s
"First-Item Indentation Issue" for why `rule-list` is preferred over a manual bullet list here).

**Expected density**: One `rule-list` per type former being formalized, containing exactly that
former's rules — not a grab-bag of unrelated rules.

**Legal placement**: Within the definitional exposition of the type former it belongs to, after
the prose introducing that type former. Never as the first content after a heading.

### Tabular / Key-Value Data

**What it is for**: Presenting structured data — a label-to-value mapping, or a genuinely narrow
matrix — as a `#figure(kind: table, ...)`. Unlike the elements above, this entry governs a
*structural choice within one figure kind*, not which element to reach for: a grid-based layout
for a genuinely narrow, scannable matrix, or a description-list / stacked layout for key-value
content or for cells carrying long prose or long unhyphenatable identifiers. See
`patterns/tables-and-figures.md`'s "Pagination and Element Choice" for the full operational test
and the pagination mechanics that follow once a shape is chosen.

**Expected density**: One structural choice per table, made once at authoring time rather than
revisited ad hoc. Stay with the grid shape only when every cell renders in roughly two lines or
fewer at its own column width and the whole table fits comfortably within the page measure;
otherwise use the description-list shape.

**Legal placement**: Same as every other element in this file — never as the first content after
a heading. The tabular/key-value choice is orthogonal to the Universal Placement Rule, not an
exception to it: a table needs the same preceding prose as any other element to establish what it
is presenting and why.

## Where Tracking Content Belongs

The motivating defect for this standard was not only a placement violation — it was also content
that never belonged inside a semantic element at all. A numbered "Formalization Status" checklist,
a completion tracker, or an open-items list is **task-management material**. It has a stated legal
home, not merely a prohibition:

1. **Preferred**: `specs/**` task artifacts (a plan's Testing & Validation checklist, a summary's
   Follow-ups section, or a dedicated tracking task). This is where the rest of this repository's
   own task-management content already lives, and it is read by the tooling built to track it.
2. **If it must live in the document itself**: an **appendix**, or a **dedicated status section**
   clearly separated from the chapter's expository body (e.g. a `== Formalization Status` section
   placed at the *end* of the chapter, not embedded inside a remark or standing where opening
   prose belongs).
3. **Never**: as the opening content of a chapter or section, and never wrapped in `#remark` (or
   any other semantic element defined above) regardless of where it appears. A `#remark` is a
   sparing reflective aside, not a container for enumerated status data — see the Remark entry
   above.

## Worked Contrast

**INCORRECT** (the observed defect shape — a semantic element as chapter opener, and an
enumerated status list inside a remark):

```typst
= Agency <sec-agency>

#remark("Formalization Status")[
  1. Agent primitives formalized
  2. Ability operator defined
  3. Group agency axioms stated
  ... (22 more numbered items)
]

#remark("Decision: Representation")[
  We chose to represent agency as a primitive rather than derive it.
]

== Agent Primitives
...
```

This violates the Universal Placement Rule twice (a `#remark` standing as the chapter's first
body content, immediately followed by a second `#remark` with still no intervening prose) and the
Remark entry's density and content rules (a 25-item numbered tracking list has no place inside a
remark at all).

**CORRECT** (opening prose; the chapter's substantial results; then a sparing reflective remark):

```typst
= Agency <sec-agency>

This chapter formalizes agency as a primitive modality over group and individual actors,
building on the ability operators introduced in Chapter 3. We define the agent primitives,
state the group-agency axioms, and prove that individual agency is derivable as a special case.

== Agent Primitives

...

#definition("Agent")[
  ...
]

#theorem("Agency Composition")[
  ...
] <thm:agency-composition>

#proof[
  ...
  #qed
]

#remark[
  The composition result above depends essentially on agents forming a monoid under group
  action; Chapter 9 revisits this when group structure is relaxed.
]

== Formalization Status

_Tracking section, not chapter-opening body prose:_

/ Complete: Agent primitives, ability operators, group-agency axioms.
/ Remaining: Individual-agency derivation (see task tracker).
```

The correct version opens with exposition, presents its actual result (definition, theorem,
proof) before any remark appears, keeps the remark short and reflective rather than tracking
progress, and — if status tracking must live in the document at all — isolates it in a
dedicated, clearly labeled section at a point where the chapter's exposition has already been
delivered, never inside a `#remark`.

## Self-Review Questions

An agent or skill executing the structural gate this standard supports should answer these
questions verbatim for every `.typ` section it authors or modifies:

1. Does any heading (`=`, `==`, `===`) have a semantic element as its first body content, with no
   intervening prose? (Universal Placement Rule)
2. Does any `#remark` stand as the first content after a heading? (Remark: Legal placement)
3. Does any `#remark` contain a numbered or bulleted status/tracking list, rather than a sparing
   reflective point? (Remark: What it is for / Expected density)
4. Does any theorem, lemma, or corollary lack a preceding `#proof` (or an explicit
   "proof omitted"/reference note)? (Proof: Expected density)
5. Is there enumerated formalization-status or completion-tracking content anywhere in the
   document body, and if so, does it live in a `specs/**` artifact, an appendix, or a dedicated
   status section — rather than inline where prose or a remark should be? (Where Tracking Content
   Belongs)

Answering "no" to 1-4 and confirming the stated home for any tracking content in 5 is the gate;
a "yes" to 1-4, or unhoused tracking content in 5, is a defect to fix before the phase is marked
verified.

## Cross-Reference

`standards/type-theory-foundations.md` already states the narrow, pre-existing instance of this
standard's sparingness principle, scoped specifically to DTT annotation remarks ("Do NOT add DTT
remarks to every definition. The goal is strategic placement, not exhaustive annotation"). That
rule and the Remark entry above are the same principle at two scopes, not competing rules: this
file's Remark entry is the general case; `type-theory-foundations.md`'s rule is its DTT-specific
instantiation.
