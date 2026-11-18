# Bounded Block Edits: Index and Assert, Never String-Splice

This document covers a failure class in editing a bounded block inside a larger line-structured
text file — a phase inside a plan, a section inside a document, a record inside a log — and the
two-part discipline that prevents it from going unnoticed: anchoring the block correctly, and
asserting both the pre-state and the post-state of the edit.

## Trigger Condition

Check both of the following before trusting an edit mechanism with a bounded block:

1. The target is a **bounded block inside a larger line-structured text file**. Concrete shapes
   that qualify: a single phase's heading and checklist inside a multi-phase plan file; one
   section between two headings inside a longer markdown document; one record inside an
   append-only log.
2. The mechanism under consideration **reconstructs the file from string slices of its own
   content** — computing character offsets into the file's text and concatenating the pieces
   around them — **rather than replacing identified lines in place**.

Both halves must hold. A mechanism that rewrites a whole file from freshly computed content is
outside this class: there is no stale slice to mis-splice. A mechanism that reads the file into a
list of lines and replaces only an identified line range, leaving every other line untouched, is
also outside this class — it is the prescribed alternative below, not an instance of the hazard.

## First Choice: the `Edit` Tool with a Unique `old_string`

For a small bounded edit, reach for an editor whose match step is itself an assertion: a tool
that requires an exact, unique `old_string` and fails loudly — refusing to write anything — when
that string is absent or matches more than once. This is a bounded, assert-on-match edit by
construction: the pre-state check that the discipline below asks for is obtained for free, before
any write happens.

## When a Scripted, Line-Indexed Path Earns Its Place

Reach for a scripted edit instead when the change is repetitive across many sites in one file, or
mechanical enough that enumerating one matched-string edit per site is impractical — for example,
flipping one phase's heading marker together with ticking every checklist item underneath it in
one pass. The worked recipe below is for exactly this case. It is not a case for reconstructing
the file from character-offset slices of its own text; it is a case for indexing the file by line
and replacing only the matched range.

## The Three-Part Recipe

### Part 1 — Index, Do Not Splice

Read the file into a list of lines. Locate the target block's start and end by matching the
*lines* that delimit it (a heading line, a marker line, a record boundary) — never by computing
character offsets into the file's raw text. Rewrite only the lines inside that range, leaving
every line outside it untouched. A worked shape:

```python
lines = open(path).read().splitlines(keepends=True)
start = next(i for i, l in enumerate(lines) if l.startswith(start_marker))
# ... locate `end` per Part 2 ...
new_block = [...]  # the replacement lines for this range only
lines[start:end] = new_block
open(path, "w").writelines(lines)
```

### Part 2 — Bound the Range by an Explicit Terminator, and Assert the Pre-State

Bound the loop by an explicit terminator — the next top-level heading, the next record boundary —
rather than by a computed length. Before writing anything, assert that the located range looks as
expected: the marker to be changed is actually present, the items inside the range actually
match what was expected, and the range actually terminated at a found terminator rather than at
end of file (a terminator search that falls through to end of file is itself a sign the target
was never found, and the edit must abort rather than silently touching the whole remainder of the
file). An edit whose pre-state assertion fails must abort without writing — never proceed on a
best guess.

**Anchoring the range.** When the bounded block spans more than one line — a whole section
between its own start and the next heading — the start and end anchors must themselves resolve
correctly before this recipe's pre-state assertion can mean anything. <!-- anchor-rule-transplant: filled in below -->

### Part 3 — Assert a Post-State Invariant Immediately After the Write

Pick one property of the whole file that this edit must not change, and check it in the same
breath as the write, before moving on to anything else. For a sectioned document, the cheapest
and most sensitive such invariant is a structural count — `grep -c '^### Phase'` for a
phase-structured plan, `grep -c '^## '` for a section-structured document. A total line count is
a weaker fallback, but it still catches gross duplication. This part is the one a careful pre-state
check does not cover on its own: a block can be anchored and matched correctly and the write can
still misbehave in the surrounding reconstruction, and only a check made in the same breath as the
write catches that reliably.

## Recovery When an Edit Goes Wrong

Restoring one clobbered file is `git show HEAD:<path>` piped to a write: a blob read to stdout,
followed by an ordinary file write. This has no interaction with the destructive-git guard at
all — it touches no working-tree state belonging to any other file, discards nothing, and needs
no snapshot first. It works on a dirty tree exactly as well as a clean one, which matters because
other uncommitted work may be sitting in the same working tree at the time. `git checkout --
<path>`, `git restore <path>`, and `git reset --hard` are neither needed nor appropriate for
restoring one file from its last commit — see `.claude/rules/git-workflow.md` for what those
commands are for and why they are guarded; this document does not restate those rules.

## What This Guidance Does Not Say

This is not a prohibition on scripted editing, and it is not "always use the `Edit` tool" —
both would be false, and both would be ignored the first time a reader meets a case that does
not fit. Nor is the post-state assertion in Part 3 optional verification that a sufficiently
careful editor may skip: a careful, line-indexed edit can still misbehave in its own
reconstruction step, and the assertion is what turns that mistake loud instead of silent. Treat
it as a required step of the recipe, not a safety net for the careless.

## Reopen Condition

If this assertion recipe is being retyped across many tasks, that repetition is the signal to
revisit a helper-script question for it — not before. A generic "safe block editor" would need
its own test suite, deploy registration, and maintenance, which is out of proportion unless the
recipe is genuinely being hand-typed often.

## Anchoring a Multi-Line Section (Transplanted)

<!-- ANCHOR-RULE-TRANSPLANT-PLACEHOLDER: replaced with the transplanted section-anchoring rule -->


## References

- `.claude/rules/git-workflow.md` — the destructive-git rules this document does not restate.
- `context/patterns/jq-escaping-workarounds.md` — the sibling discipline for JSON record files: a
  different file format, a different hazard (jq's whole-file re-serialization), the same
  assertion-first shape.
- `context/contracts/pre-edit-gate.md` — per-item evidence before applying a mechanical-list edit.
