# Chapter Quality Standard

## Scope

This standard measures the quality of a hand-built Typst manual chapter. Manual chapters are
built slowly and carefully from high-quality research and must never be filled with fluff; this
standard is the measurable bar a chapter is checked against, replacing ad hoc, per-reviewer
judgment with a recorded, repeatable measure.

This is an **agent-system standard**: it lives in this extension and is deployed to every
repository that loads the `typst` extension, not authored per-repository. It is the authoritative
chapter-quality bar for this extension — where an existing standard's checklist or self-review
questions overlap it, this file is the standard those overlaps ultimately answer to (see
`## Deferrals and Ownership` below for exactly which rules that applies to).

## Rule Classification

Every rule below carries exactly two independent classification tags, stated in the rule's own
entry. A rule is not complete until both tags are present; a rule missing either tag cannot be
transcribed into the consuming mechanical checker.

### Axis 1: BLOCKING or ADVISORY

- **BLOCKING**: the finding drives the consuming checker's exit code. A BLOCKING finding fails the
  check.
- **ADVISORY**: the finding is reported and counted but never affects exit status. An ADVISORY
  finding never fails the check, however severe it looks in the report.

**Unreviewed-threshold rule**: any rule whose threshold (a word count, a ratio, a phrase list) was
introduced without first observing it against a real corpus of chapters is ADVISORY on first
release, and its own rule entry below says so explicitly, with the word "unreviewed". This mirrors
the severity-split rationale already in force in this extension — see `## Rationale` for the
verbatim reasoning this standard restates rather than re-derives.

### Axis 2: MECHANICAL or JUDGED

- **MECHANICAL**: checkable by a shell script without understanding the prose — a grep, a count, a
  path-existence test, a regex match.
- **JUDGED**: requires a reader. A conforming checker cannot decide this rule by pattern-matching
  alone.

A conforming checker MUST emit every JUDGED rule as a structured prompt for a reviewing agent,
never silently skip it. Misclassifying a JUDGED rule as MECHANICAL produces a false gate (a script
enforcing something it cannot actually verify); misclassifying a MECHANICAL rule as JUDGED
produces an unenforced rule (a check that should run automatically but instead waits on a human
every time).

### Rule Entry Format

Every rule below is written as:

> **Rule N.M** — statement of the rule. **[AXIS1 / AXIS2]** Notes: ownership, rationale pointer,
> or unreviewed-threshold disclosure where applicable.

Both tags are mandatory in the entry itself; a rule stated only under a dimension heading with no
inline tags does not satisfy this standard.

## SOURCE GROUNDING

Every substantive claim in a chapter must trace to a cited source: a repo path, a paper, or a
verified fact. This dimension exists so a chapter's claims are checkable, not merely plausible —
see `## Rationale` for the full reasoning.

**Rule 1.1** — Every substantive claim traces to a cited source (a repo path, a paper, or an
explicitly verified fact). **[BLOCKING / JUDGED]** Whether a given sentence is "substantive" (and
whether its cited source actually supports it) requires a reader; no script can decide this from
text shape alone.

**Rule 1.2** — Every backticked path in the chapter resolves against the live tree. **[BLOCKING /
MECHANICAL]** A checker extracts every backtick-delimited path-shaped token and tests it for
existence in the repository at check time.

**Rule 1.3** — Every citation key resolves in `bibliography.bib`. **[BLOCKING / MECHANICAL]** A
checker extracts every `@key` occurrence (see `patterns/bibliography.md` for the citation syntax
this rule checks against) and greps the project's `.bib` file for a matching entry key.

**Rule 1.4** — No hand-typed count, version, or hash. Any such value appearing in the chapter must
be derived from a cited, checkable source at the time it was written, never typed from memory or
guessed. **[BLOCKING / JUDGED]** Whether a specific number was hand-typed versus derived from a
source cannot be determined from the text alone; a reader must check the value against its cited
source.

**Rule 1.5** — Every `CONFIRM` comment is well-formed. **[BLOCKING / MECHANICAL]** "Well-formed"
is a syntactic check on the marker's shape only (see below); it does not require resolving the
underlying claim.

### The `CONFIRM` Comment Convention

No such convention exists elsewhere in this repository; this standard defines it. When an author
cannot immediately verify a claim and does not want to fabricate a citation to fill the gap, the
author writes an inline marker instead of guessing:

```typst
// CONFIRM: <the specific claim that needs a source>
```

A `CONFIRM` comment makes a gap in source grounding visible and deferrable rather than silently
fabricated. "Well-formed" means the marker carries a non-empty claim-text payload after the
`CONFIRM:` prefix — a syntactic, MECHANICAL check, independent of whether the underlying claim is
later resolved true, false, or replaced with a real citation. A chapter may ship with open
`CONFIRM` markers; Rule 1.5 checks only that the markers present are well-formed, not that none
remain.

## ANTI-FLUFF DENSITY

**This entire dimension is advisory. No rule in this section ever blocks, regardless of how
severe its finding looks in the report.** Every rule below states this individually as well,
because a dimension-level note alone is not sufficient for acceptance.

**Rule 2.1** — The chapter's claim-to-word ratio meets a stated per-section threshold. **[ADVISORY
/ MECHANICAL]** This rule never blocks. The specific ratio threshold has not yet been observed
against a real corpus of chapters and is therefore **unreviewed** on first release; a checker
implementing this rule must report the threshold it used alongside the finding.

**Rule 2.2** — No `==` or `===` section lacks a stated reader need in its opening prose (why the
section exists, what it lets the reader do afterward). **[ADVISORY / JUDGED]** This rule never
blocks. This is the chapter-quality-scoring restatement of `standards/textbook-standards.md`'s Motivation
Requirements (see `## Deferrals and Ownership`); whether a section's opening prose actually states
a reader need requires a reader to judge.

**Rule 2.3** — Hedging and filler connective prose is flagged against a seed phrase list (for
example: "it seems", "arguably", "it is worth noting that", "needless to say"). **[ADVISORY /
MECHANICAL]** This rule never blocks. The seed list is drawn from `standards/textbook-standards.md`'s
Professional Tone "Avoid" column and is **unreviewed and extensible**: a checker may add phrases
to the list as false positives and misses are observed, and must report the list version or
contents it used alongside each finding.

## PRESENTATION CLARITY

**Rule 3.1** — Every notation symbol and every glossary term is defined before its first use.
**[BLOCKING / JUDGED]** Ownership: the ordering principle itself is owned by
`standards/textbook-standards.md`'s Definition Ordering Principle, restated here only for chapter-quality
scoring purposes, not re-derived; the source of truth for where a notation symbol's definition is
recorded is `standards/notation-conventions.md`'s two-tier `shared-notation.typ` /
`{project}-notation.typ` system (see `## Deferrals and Ownership`). Tracking "first use" reliably
across a chapter, and across chapters, needs semantic understanding a script cannot reliably
provide.

**Rule 3.2** — Heading depth is bounded at level 3 (`===`); a level-4 heading or deeper is
prohibited. **[BLOCKING / MECHANICAL]** A checker greps heading marker depth per line. This bound
is not a fresh guess: it formalizes `standards/document-structure.md`'s existing heading-depth convention
("Level-1 heading: One `=` heading per chapter"; "Level-3 headings: `===` for subsections (use
sparingly)"), which is why this rule can be BLOCKING rather than an unreviewed threshold.

**Rule 3.3** — Paragraph length is bounded (a word or line count per paragraph). **[ADVISORY /
MECHANICAL]** This is a fresh, **unreviewed** numeric threshold with no corpus observation behind
it; a checker implementing this rule must report the threshold it used alongside the finding.

**Rule 3.4** — Every non-obvious concept introduced has an accompanying example or figure.
**[ADVISORY / JUDGED]** Ownership: `standards/semantic-element-usage.md`'s Example entry already sets the
expected density and placement mechanics for `#example` ("At least one per non-obvious
definition..."); this rule restates only the reader-facing consequence for chapter-quality
scoring, not the placement/density mechanics themselves. "Non-obvious" is inherently a judgment
call — tagging this rule BLOCKING would risk the fire-on-correct-documents failure mode this
standard's severity split exists to prevent (see `## Rationale`).

**Element placement is out of scope for this dimension.** The Universal Placement Rule (a
semantic element must not be the first body content after a heading, with no intervening prose)
is owned by `standards/semantic-element-usage.md` and is already mechanically enforced, BLOCKING, by
`scripts/typst-element-lint.sh` check 1. This dimension does not re-specify placement; it names
the existing rule and its existing enforcer instead.

## OPEN-QUESTION HONESTY

A forward-looking chapter — one describing work still in progress, or research not yet settled —
must not present genuinely open questions as resolved facts. See `## Rationale` for the full
reasoning behind this dimension.

**Rule 4.1** — Every speculative claim is explicitly marked. **[BLOCKING / JUDGED]** The marker is
a `Speculative:` tag (inline or as a labeled aside), distinct from the `CONFIRM` marker defined
under SOURCE GROUNDING: `CONFIRM` flags a claim whose *source* is missing; `Speculative:` flags a
claim whose *truth* is not yet established even with a source behind it. Distinguishing a
speculative claim from an established one requires a reader; this is the rule this dimension's
rationale most directly exists to support.

**Rule 4.2** — Open questions are listed in a dedicated, discoverable location (for example an
`== Open Questions` section) rather than buried inline in ordinary prose. **[BLOCKING / JUDGED]**
The presence of a heading with that name is a cheap mechanical proxy, but is not sufficient on its
own: whether the chapter's open questions are actually collected there, versus scattered and
half-hidden in prose elsewhere, requires a reader.

**Rule 4.3** — No future-tense claim is stated as settled fact. **[BLOCKING / JUDGED]**
Future-tense and modal phrase patterns ("will show", "should hold", "is expected to") are too
unreliable as a standalone mechanical signal — both false positives (a future-tense sentence that
is honestly hedged) and false negatives (a present-tense sentence asserting something unsettled)
are common enough that this rule requires reading for intent, not pattern matching.

Each rule above is BLOCKING because a chapter that misrepresents an open question as settled is
not merely lower quality — it is actively misleading a reader who has no way to know the ground
has not yet settled. All three are JUDGED because reliably drawing the speculative/settled line is
not a task a mechanical pattern match can be trusted with; see `## Rationale` for why this
dimension exists at all.

## Deferrals and Ownership

Three existing standards in this extension already cover ground adjacent to this one. Where this
standard and one of the three could both be read as owning a rule, the sentence below states which
one does. This standard restates the adjacent rule only to the extent needed for chapter-quality
scoring; it never re-derives or contradicts the deferred-to standard's own content.

### `standards/textbook-standards.md`

Deferred and owned there: the **Definition Ordering Principle** (the underlying "define before
use" rule and its audit procedure), the **Motivation Requirements** (the minimum-two-sentences
rule and its three motivation patterns), the **Professional Tone Standards** (the "Avoid" /
"Prefer" terminology table, seeded into Rule 2.3 above), and **Chapter Structure** (required
sections, section numbering). This standard's Rules 3.1 and 2.2 restate only the chapter-quality
scoring consequence of the first two, not their underlying content requirements.

Ownership resolution against `standards/textbook-standards.md`'s existing "Quality Checklist" (an 8-item
list including "All terms defined before use" and "Notation is consistent with
shared-notation.typ"): that checklist predates this standard and covers the same territory
informally. **This standard is the authoritative chapter-quality bar going forward**;
`standards/textbook-standards.md` keeps ownership of the underlying content conventions the checklist items
were shorthand for, but the measurable pass/fail judgment belongs here.

### `standards/semantic-element-usage.md`

Deferred and owned there: the **Universal Placement Rule** (a semantic element must not be the
first body content after a heading), already mechanically enforced, BLOCKING, by
`scripts/typst-element-lint.sh` check 1; and the **per-element expected-density mechanics**,
notably the Example element's "at least one per non-obvious definition" density rule. This
standard's Rule 3.4 restates only the reader-facing consequence of the Example density rule for
scoring purposes, never the density/placement mechanics themselves.

Ownership resolution against `standards/semantic-element-usage.md`'s existing "Self-Review Questions": those
questions overlap this standard's JUDGED rules (in particular, its placement questions overlap
nothing new here since placement is already fully deferred above). `standards/semantic-element-usage.md`
owns the self-review questions as its own verification gate; this standard's JUDGED rule prompts
(see `## Interface Contract for Repo-Local Checks` for how a checker must present JUDGED rules)
are a distinct, chapter-quality-scoped set and do not replace or duplicate that file's self-review
gate.

### `standards/notation-conventions.md`

Deferred and owned there: the **notation architecture** itself — the two-tier
`shared-notation.typ` / `{project}-notation.typ` system and its `#import` re-export pattern — which
answers "where is a given symbol's definition recorded." This standard's Rule 3.1 owns only the
before-first-use **ordering** consequence for chapter-quality scoring; it does not re-derive a
second notation model or restate the import pattern.

## Interface Contract for Repo-Local Checks

A consuming repository plans two additional checks of its own, in its local `typst/scripts/`
directory: a name-resolution check and a chapter-source coverage check. **This standard does not
implement or duplicate either check.** It defines only the contract a conforming repo-local
implementation must satisfy, so that implementation can be written independently, without
importing any agent-system code.

### Shared Finding-Record Shape

Both repo-local checks, and the consuming mechanical checker built against this standard, emit
findings in the same shape:

```
{ dimension, rule (namespaced "local:<check-name>" for a repo-local finding),
  severity (BLOCKING | ADVISORY, the repo's choice for its own local rules),
  location (file:line), message }
```

`dimension` names the standard's own dimension a finding is closest to, even for a repo-local
check whose rule is not one of the rules enumerated above; `rule` is namespaced `local:` to keep
repo-local rule identifiers from colliding with this standard's own numbered rules.

### Name-Resolution Check Contract

**What it verifies**: every identifier referenced in chapter prose that purports to name a Typst
function, variable, or module defined in the consuming repository's own source (its `template.typ`,
its notation modules, or other project-local Typst source) actually resolves in the live tree at
check time.

**Why it is repo-local**: the modules a chapter's prose refers to are per-repository content, not
agent-system content; this standard has no visibility into a consuming repository's own module
layout and must not assume one.

**What it reports**: findings in the shared finding-record shape above, with `rule` namespaced
`local:name-resolution`.

**How it composes**: it runs as an independent script. Its findings are aggregated at the
consuming repository's own CI or test layer alongside the mechanical checker's own output — never
by the mechanical checker shelling out to repository-local code, and never by this standard
defining or requiring a specific script location or invocation.

### Chapter-Source Coverage Check Contract

**What it verifies**: every chapter source file the consuming repository's build includes (for
example, via a `#include "chapters/NN-*.typ"` pattern per `standards/document-structure.md`) has a recorded
chapter-quality-check run against it, so no chapter ships without ever having been measured against
this standard.

**What it reports**: findings in the shared finding-record shape above, with `rule` namespaced
`local:chapter-source-coverage`.

**How it composes**: identically to the name-resolution check above — an independent script,
aggregated at the repository's own CI or test layer.

### Composition with This Standard's Own Findings

A consuming repository's local findings (both checks above) and this standard's own findings
(produced by the mechanical checker built against the dimensions and rules earlier in this
document) are aggregated together at the repository layer, using the same Axis 1 exit-code
semantics uniformly: a BLOCKING finding from either source fails the aggregate check; an ADVISORY
finding from either source is reported and counted but never fails it.

## Rationale

This section records why each dimension exists, so a future editor cannot quietly delete a rule
whose purpose is no longer obvious.

**SOURCE GROUNDING** exists because a chapter built from research is only as good as its
traceability. An untraceable claim is indistinguishable from a fabricated one to a reader who
cannot check it; the `CONFIRM` marker exists precisely so a genuine gap in sourcing is recorded
honestly rather than silently papered over with a guessed number or an invented citation.

**ANTI-FLUFF DENSITY** is advisory-only for the same reason `scripts/typst-element-lint.sh`
already documents for its own advisory checks: an unreviewed hard threshold that fires on correct
documents is exactly the failure mode this split exists to prevent, because a gate that fires on
correct documents gets switched off. Promoting any of this dimension's thresholds to BLOCKING
requires first observing its behavior against a real corpus of chapters — the same discipline
already in force for `typst-element-lint.sh`'s own advisory checks. This dimension restates that
existing reasoning rather than inventing a new one.

**PRESENTATION CLARITY** exists because a chapter is read linearly by a reader who cannot look
ahead. A term used before it is defined, or a concept introduced with no anchoring example, costs
the reader the rest of the section: once a reader loses the thread, everything downstream of the
gap is unearned.

**OPEN-QUESTION HONESTY** exists because a forward-looking chapter — in particular, a chapter on
training agents to synthesize programs from verified components, where the underlying research
questions are genuinely open — must not present those open questions as resolved fact. A reader
who cannot tell settled results from open questions cannot correctly calibrate how much to trust
the chapter, and a chapter that quietly launders an open question into a settled-sounding
declarative sentence is a more insidious defect than an outright missing citation, because it
reads as authoritative right up until someone tries to build on it. This reasoning belongs in the
standard itself, not in a commit message where it would be lost the moment anyone stopped looking
at the git history.
