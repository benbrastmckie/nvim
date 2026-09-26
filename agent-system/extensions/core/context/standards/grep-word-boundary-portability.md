# Word-Boundary (`\b`) Portability Across Deployed grep Contexts

## The Deployed `grep` Is Invocation-Context-Dependent

The deployed `grep` is not a single fact — it depends on how the command is invoked. A `.sh`
script or hook that is *executed* as a subprocess (`bash file.sh`, `./file.sh`, or the hook
runner) resolves `grep` on `$PATH` to GNU grep. A command typed or pasted directly into an
agent's own Bash-tool shell — a raw one-liner, or a fenced ```bash block copied verbatim out of
an agent-instruction Markdown file and executed at the top level — instead hits a non-exported
shell function that `exec`'s the Claude Code binary itself under the name `ugrep`, giving that
command ugrep's matching semantics. A child process does not inherit that function (confirmed
empirically: `env -i bash -lc`, a nested `bash -c`, and literal execution of a `.sh` file
containing only `grep --version` all report GNU grep, while the same command typed at the
top-level Bash-tool shell reports ugrep). **Determine which context applies — with
`type grep` at the top level, or `bash -c 'grep --version'` for the subprocess case — before
assuming either engine.**

## The ugrep Defect Is Compositional, Not a Missing Feature

ugrep's `-E` (POSIX/DFA) engine does not simply ignore `\b`. It mis-evaluates a `\b` that appears
downstream of an earlier `\b`-anchored subexpression, separated by a wildcard run (for example
`[^|]*`), and can silently fail to match even though every fragment matches fine in isolation and
`-P` (PCRE2) on the identical, unmodified pattern matches correctly. This is
`HOOK_REGEX_BOUNDARY_DEFECT` in `system-defect-discrimination.md`.

Worked example (verified directly against the deployed ugrep 7.8.4, `-i`, against the literal
input line `| Claim | Source / counterexample | Verification method | Confidence |`):

```
PATTERN                                                                RESULT
\bclaim\b                                                              MATCH
\bsource\b[^|]*\bcounterexample\b                                      MATCH
\|[^|]*\bclaim\b[^|]*\|[^|]*\bsource\b[^|]*\bcounterexample\b[^|]*\|    NOMATCH  (composed — bug)
(same pattern, with -P instead of -E)                                  MATCH
(same pattern, inside a .sh file run via `bash file.sh`, GNU grep)     MATCH
```

Every fragment matches; the fully composed production pattern does not, under `-E` only. The
defect only manifests once two or more `\b`-anchored subexpressions are chained across a wildcard
run in one linear pattern.

## Shape Rule

A single `\b`, or a single `\b...\b` bracket around one token or alternation (the shape `\bWORD\b`
or `\b(A|B|C)\s+N\b`), is **not known to be affected** — this shape was independently re-verified
as WORKING across every such site found in this source store. Only a *chain* of two or more
independent `\b`-anchored subexpressions in one linear pattern is at risk. Do not generalize a
result from one shape to the other, and do not generalize a result from one site to a
same-shaped site elsewhere without re-running it — the compositional nature of the defect means a
pattern's *neighbors* within the same expression determine whether a given `\b` works, not the
construct in isolation.

## Prefer Delimiter-Anchored Alternatives

Where the surrounding pattern already bounds the token — a pipe-delimited table cell
(`\|[^|]*TOKEN[^|]*\|`), a whitespace- or quote-bounded field — the delimiter itself already
prevents a partial-word match, and `\b` is often unnecessary. Prefer dropping `\b` in favor of the
existing delimiter over adding further `\b`s to a pattern that already has one.

## Where `\b` Is Genuinely Needed Under ugrep

When a pattern will run in an ugrep-exposed context (an ad hoc Bash-tool command, or a fenced
code block in an agent-instruction Markdown file meant to be pasted into the agent's own shell)
and needs `\b` semantics that delimiters cannot provide, switch that one invocation to `-P`
(PCRE2) rather than `-E`/default BRE. PCRE2 evaluates the same pattern correctly.

## Execute-Before-Commit Obligation

Any new `\b` pattern must be executed against a real positive input **and** a real negative input,
under the actual mechanism that will run it in production, before it is committed — never reasoned
about, never tested as a simplified stand-in, and never assumed safe by analogy to a working
pattern elsewhere. A pattern that matches in isolation is not evidence that it matches once
composed with the rest of a real production pattern.

## Determining Which Engine Applies

```bash
# At the top level of an agent's own Bash-tool shell:
type grep            # a shell function -> ugrep is in effect for this invocation
grep --version        # confirms the version string directly

# For a .sh file, hook, or any subprocess execution:
bash -c 'grep --version'          # or: env -i bash -lc 'grep --version'
```

If `type grep` reports a shell function, the command is running under ugrep. If it reports a
path under `$PATH` (e.g. `/run/current-system/sw/bin/grep`), it is GNU grep.

## Related

- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`'s
  `HOOK_REGEX_BOUNDARY_DEFECT` vocabulary entry names this exact defect class and records the
  orchestration-gate instance that first surfaced it.
