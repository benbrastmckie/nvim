# Mode-Gated Section Loading Convention

## The Problem

A skill's `SKILL.md` body and a command's `.md` body are loaded in full on every invocation.
`install-extension.sh` has no include/partial/fragment mechanism, and deploy is a byte-for-byte
copy of the source store into `.claude/`. There is no way for a runtime-loaded surface to load
only *part* of itself. Consequently, a prose or decision-logic section that is entered on exactly
one branch of a mutually-exclusive dispatch (a mode flag, a scope flag, an `--auto` variant) is
paid for — in tokens, on every single invocation — even on the invocations that take a different
branch and never read it.

This convention formalizes the extraction mechanism that already exists informally in this repo:
move the branch-only prose out to a `context/**/*.md` file and leave behind an imperative "READ
... now" pointer at the call site. It adds the one piece that was previously missing — a
machine-detectable paired marker — so a regression lint can catch a branch section that grows
past the point where extraction pays for itself, instead of relying on a human noticing.

## Marker Syntax

```
<!-- branch-gated:begin condition="mode=all" -->
## `--all` Mode (`mode=all`): Whole-Mailbox Sweep, One Bucket Approval, Sub-50 Drain
...
<!-- branch-gated:end -->
```

- `<!-- branch-gated:begin condition="..." -->` is placed immediately *outside* (on the line
  directly above) the section's own `##` heading.
- `<!-- branch-gated:end -->` is placed immediately after the section's last line, before the
  next heading (or end of file).
- The `condition` attribute names the dispatch condition that enters this section, by example:
  `condition="mode=all"`, `condition="multi_task_mode=true"`, `condition="--auto"`. It is
  **documentation for humans and future tooling only** — nothing in this convention or its lint
  cross-checks the attribute value against real dispatch logic. Get the wording right for a
  reader, but do not treat it as executable.

## Why Paired, Not Single

An earlier informal approach used a single "start" marker and located the section's end by
scanning forward for the next same-or-higher-level `^## ` heading. That scan is exactly the
operation the **fence-interior heading trap** corrupts: a fenced code example inside the section
(a worked bash snippet, a sample markdown fragment) can contain a line that starts with `#` or
`##` for reasons that have nothing to do with document structure — a bash comment, example
markdown — and a naive heading scan matches it as if it were the real boundary, truncating the
extracted range at the wrong point or leaving a dangling fragment behind. Both prior informal
extractions in this repo needed a manually-drawn boundary map to avoid this. A **paired** marker
removes the `^## ` boundary scan entirely: the end of the section is wherever the literal string
`<!-- branch-gated:end -->` is, full stop, regardless of what heading-shaped text appears inside
fenced blocks in between.

## Naming Precedent

This is a formalization of an existing house style, not new syntax invented from nothing.
The pre-rewrite, now-deleted single-task `skill-orchestrate/SKILL.md` engine's own Stage 2 used
an informal paired bash-comment convention — `# --- name:begin ---` / `# --- name:end ---` — to
bracket named blocks for exactly the same reason: so a boundary can be located by literal text
instead of by structural inference. (A fresh grep for `begin ---` over the current, rewritten
`SKILL.md` finds no surviving instance of that convention — it did not carry over into the
four-move loop, so this precedent is historical, not a pointer to a live example.) The
`branch-gated:begin`/`branch-gated:end` HTML-comment marker is the same idea, in a form that
works inside markdown prose rather than inside a bash block.

## The Extraction Procedure

Applied in order, once a candidate section is identified (see "When to Extract" and "When NOT to
Extract" below):

1. **Mark**: insert `<!-- branch-gated:begin condition="..." -->` and
   `<!-- branch-gated:end -->` around the section, without moving anything yet.
2. **Re-locate boundaries by literal marker text**, not by remembered line numbers — line numbers
   drift the moment any earlier edit lands. Confirm the span with a direct read.
3. **Create the destination file** (see "Path Selection Rule" below) containing the section's
   content verbatim, preceded by the framing line required in "Whole-Section vs.
   Reference-Appendix Risk" below. **Promote** the extracted heading hierarchy by one level so
   the section's own heading becomes the file's single `#` top-level heading (e.g. a `##`
   section heading becomes `#`, and any `###` subsections beneath it become `##`) — matching the
   single-H1-per-file convention every other `context/**/*.md` file in this repo already follows.
   Only promote; nothing about the source file's own heading levels changes (they stay exactly as
   extracted, since the marked span is being deleted from the source, not edited in place).
4. **Replace the marked span** in the source file (markers included) with the imperative pointer
   (see "The Imperative/Passive Pointer Test" below).
5. **Register** the destination file in the owning extension's `index-entries.json` (see
   "Registration Mechanics" below).
6. **Re-check inbound cross-references**: grep the extension (and any command that dispatches
   into the surface) for references into the region that was just moved, and repoint any that
   would now dangle. Do this check every time — record that it was done even when nothing needed
   repointing, never assume clean.
7. **Measure**: record source-file bytes before and after, the destination file's bytes, and the
   delta. A convention justified by token savings needs the savings written down, not asserted.

**Bottom-up ordering for multi-section files**: when more than one section in the same file is
being extracted in one pass, process them **last section first**. Removing a span shifts every
line number below it; working from the bottom up means sections not yet processed keep their
original line numbers throughout.

## The Imperative/Passive Pointer Test

Before accepting a pointer's wording, apply this test: *would an agent reading only the body know
it is REQUIRED to open the referenced file at this moment, or would it read the pointer as
optional supplementary material it can skip?*

Working precedent, verbatim:

- `READ .claude/context/patterns/checkpoint-before-overflow.md now and follow it exactly.`
- `READ .claude/context/patterns/lit-stage4a-flow.md now and execute it verbatim.`

Banned forms — these read as optional, and an agent that treats them as optional silently skips
the section's entire content:

- "see also ..."
- "for more detail, see ..."
- "additional context: ..."

## Whole-Section vs. Reference-Appendix Risk

Extracting an entire mode's section is a different risk profile from extracting a reference
appendix. When the destination file *is* the section — not a supplement to prose that remains
in place — the destination becomes the section's **only** specification. A skipped READ no longer
produces a *degraded* execution (missing detail, still roughly on track); it produces an
**unspecified** one (the agent has no idea what it is supposed to do).

**Requirement**: the destination file's opening line MUST state that it is the complete and only
specification for the section it replaces, and MUST be followed exactly. Do not soften this with
"see also" framing at either end — the pointer in the source file and the opening line in the
destination file are both required, and both use unsoftened imperative language.

## Path Selection Rule

- A **core-owned** surface (a `core/commands/*.md` or `core/skills/*/SKILL.md`) extracts into
  `agent-system/extensions/core/context/patterns/<name>.md`.
- An **extension-owned** surface extracts into that extension's own provided context subtree,
  e.g. `agent-system/extensions/email/context/project/email/patterns/<name>.md`.

Pointers always use the **deployed path form** (`.claude/context/...`), never the source-store
form (`agent-system/extensions/.../context/...`) — the deployed form is the path an executing
agent can actually open at runtime; the source-store form is only ever meaningful to whoever is
editing the convention itself.

## Registration Mechanics

Add an entry to the owning extension's `index-entries.json` with `path`, `domain`, `subdomain`,
`summary`, `line_count` (the destination file's actual final line count — verify with `wc -l`,
never estimate), `keywords`, and `load_when` (populated with whichever `load_when` keys that
extension's existing entries actually use — do not invent a key that has no precedent in the
file).

Whether `manifest.json` also needs an edit depends on whether that extension's
`provides.context` array lists the containing directory **wholesale** or enumerates files
**individually** — check the live `manifest.json`, do not assume. As a point of reference at the
time this convention was written: `core/manifest.json`'s `provides.context` lists `patterns`
wholesale (no edit needed for a new file under `core/context/patterns/`), while
`core/manifest.json`'s `provides.scripts` enumerates every script individually (a new lint or
test script under `core/scripts/` DOES need its own `provides.scripts` entry, or it is silently
never deployed).

## When to Extract

A section is a good extraction candidate when it is:

- Entered via an explicit conditional-dispatch statement (a mode flag, a scope flag, an `--auto`
  variant) — i.e. it is genuinely one branch among mutually exclusive alternatives, not content
  every invocation passes through.
- Large enough that its extraction overhead (a new file, a pointer, an index entry) is clearly
  paid back by the tokens saved on every invocation that skips it. See
  `scripts/lint/lint-branch-gated-sections.sh`'s threshold constant and header for the specific,
  calibrated number this repo currently uses.

## When NOT to Extract

- **Below the lint threshold**: small sections where extraction overhead would exceed the win.
- **The default / most-frequently-taken branch**: extracting the branch nearly every invocation
  actually needs defeats the purpose — it is not the content most invocations are paying to skip.
- **Composable modifiers**: a modifier flag that layers onto other modes rather than excluding
  them is not a mutually-exclusive branch at all, and marking it would misrepresent the dispatch
  structure. Worked counter-example: `skill-email-cleanup`'s `Archive Scope`
  (`scope=archive`) section composes freely with either mode (`/email --all --archive` is valid),
  so it is not a branch-gated candidate even though it is conditionally relevant.

## Adjacent, Separate Lever: Bash-to-`scripts/*.sh` Extraction

Moving procedural bash out of a skill/command body into a `scripts/*.sh` file is a
**pre-existing, complementary, and separate** lever from this convention — already established
via the `orchestrate-*.sh` script family. It removes tokens on **every** invocation of the
surface, branch-gated or not, because bash procedure is rarely useful for an agent to re-read in
full each time regardless of which branch is active. It is explicitly **outside** this
convention's mechanism (which targets prose/decision-logic branch sections, not procedural bash)
and **outside** `lint-branch-gated-sections.sh`'s detection model (which only understands the
`branch-gated:begin`/`branch-gated:end` marker pair). A per-file application task may reach for
bash extraction independently of anything in this document.

## Enforcement

`scripts/lint/lint-branch-gated-sections.sh`, wired as `verify-deploy.sh` Gate 19, is a
regression guard on the **marked** class only: it fails when a marked-but-unextracted section's
byte span exceeds the configured threshold. It is **not** a completeness proof over the whole
tree — an author who never applies the marker to a genuinely mutually-exclusive branch section
produces a large, unextracted section the lint has no way to see. Mark any section entered via an
explicit conditional-dispatch statement so it falls under the lint's coverage; an unmarked
section is invisible to it by construction.

## Measured Example

`skill-email-cleanup/SKILL.md`'s `` `--all` Mode `` section was extracted to
`agent-system/extensions/email/context/project/email/patterns/email-cleanup-all-mode.md` as this
convention's pilot. Measured: `SKILL.md` 47,832 B before -> 30,656 B after (17,176 B / 35.9%
removed from a surface loaded on every `/email` invocation); the extracted file is 17,729 B
(marginally larger than the removed span, because of the added opening framing line and the
`## -> #` / `### -> ##` heading promotion). Approximate token saving per non-`--all` `/email`
invocation (default mode, or `--archive` without `--all`): ~4,300 tokens (17,176 B / ~4 B per
token, a rough English/markdown heuristic, not a tokenizer-exact count). See that task's
implementation summary for the full measurement writeup.

## See Also

- `context/patterns/adoption-lint-conventions.md` — the two adoption-lint shapes
  (zero-tolerance vs. structural-plus-reasoned-allowlist) and the decision rule between them,
  which `lint-branch-gated-sections.sh` follows.
