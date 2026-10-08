# Uniformity Audit: Phase-Commit Containment Self-Check Across All Fifteen Definitions

Date: 2026-10-07

## Purpose

Prove mechanically that the ruled mechanism (`--task {N}` plus the canonical pre-commit
Containment self-check, pointed at by name from fourteen of the fifteen files and authored once
in the fifteenth) landed uniformly across every one of the fifteen `file_scope` entries — no
per-extension divergence, per the task's ruling that a subset landing would itself be a defect.

## Audit Loop (verbatim)

```bash
files=(
  "agent-system/extensions/books/agents/books-implementation-agent.md"
  "agent-system/extensions/books/agents/books-implementation-hard-agent.md"
  "agent-system/extensions/core/agents/general-implementation-agent.md"
  "agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md"
  "agent-system/extensions/founder/agents/founder-implement-agent.md"
  "agent-system/extensions/latex/agents/latex-implementation-agent.md"
  "agent-system/extensions/lean/agents/lean-implementation-agent.md"
  "agent-system/extensions/lean/agents/lean-implementation-hard-agent.md"
  "agent-system/extensions/nix/agents/nix-implementation-agent.md"
  "agent-system/extensions/nvim/agents/neovim-implementation-agent.md"
  "agent-system/extensions/python/agents/python-implementation-agent.md"
  "agent-system/extensions/rust/agents/rust-implementation-agent.md"
  "agent-system/extensions/typst/agents/typst-implementation-agent.md"
  "agent-system/extensions/web/agents/web-implementation-agent.md"
  "agent-system/extensions/z3/agents/z3-implementation-agent.md"
)
for f in "${files[@]}"; do
  gcs_count=$(grep -c "git-commit-scoped.sh" "$f")
  task_count=$(grep -c -- "--task" "$f")
  grep -q "Phase-Commit Containment Self-Check" "$f" && pointer="yes" || pointer="NO"
  echo "$f | $gcs_count | $task_count | $pointer"
done
```

## Results (captured verbatim)

| File | `git-commit-scoped.sh` occurrences | `--task` occurrences | pointer-or-block present |
|------|------|------|------|
| `agent-system/extensions/books/agents/books-implementation-agent.md` | 1 | 1 | yes |
| `agent-system/extensions/books/agents/books-implementation-hard-agent.md` | 1 | 1 | yes |
| `agent-system/extensions/core/agents/general-implementation-agent.md` | 8 | 5 | yes |
| `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` | 1 | 1 | yes |
| `agent-system/extensions/founder/agents/founder-implement-agent.md` | 5 | 5 | yes |
| `agent-system/extensions/latex/agents/latex-implementation-agent.md` | 1 | 1 | yes |
| `agent-system/extensions/lean/agents/lean-implementation-agent.md` | 1 | 1 | yes |
| `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` | 2 | 2 | yes |
| `agent-system/extensions/nix/agents/nix-implementation-agent.md` | 1 | 1 | yes |
| `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` | 1 | 1 | yes |
| `agent-system/extensions/python/agents/python-implementation-agent.md` | 1 | 1 | yes |
| `agent-system/extensions/rust/agents/rust-implementation-agent.md` | 1 | 1 | yes |
| `agent-system/extensions/typst/agents/typst-implementation-agent.md` | 1 | 1 | yes |
| `agent-system/extensions/web/agents/web-implementation-agent.md` | 1 | 1 | yes |
| `agent-system/extensions/z3/agents/z3-implementation-agent.md` | 1 | 1 | yes |

**Fifteen files, no file missing, none added.**

## Invariant Check

The audit loop's raw `git-commit-scoped.sh` occurrence count mixes genuine invocation sites with
prose mentions (e.g. the core definition's 8 occurrences = 2 genuine bash invocations + 6 prose
references; `books-implementation-hard-agent.md`'s 1 occurrence is itself a prose
cross-reference, not a bash block — see its recorded Phase 4 deviation). The per-file genuine
invocation-site count, confirmed by reading every occurrence in context during Phases 2-4 (not
re-derived here from the raw count), is:

| File | Genuine invocation sites | `--task` at every genuine site |
|------|------|------|
| books-implementation-agent.md | 1 | yes |
| books-implementation-hard-agent.md | 1 (prose-line recipe, not a bash block — deviation recorded) | yes |
| general-implementation-agent.md | 2 | yes |
| cslib-implementation-hard-agent.md | 1 | yes |
| founder-implement-agent.md | 5 | yes |
| latex-implementation-agent.md | 1 | yes |
| lean-implementation-agent.md | 1 | yes |
| lean-implementation-hard-agent.md | 2 | yes |
| nix-implementation-agent.md | 1 | yes |
| neovim-implementation-agent.md | 1 | yes |
| python-implementation-agent.md | 1 | yes |
| rust-implementation-agent.md | 1 | yes |
| typst-implementation-agent.md | 1 | yes |
| web-implementation-agent.md | 1 | yes |
| z3-implementation-agent.md | 1 | yes |

**Total genuine invocation sites: 21** (2 + 9 + 10, matching the plan's Phase 5 Scope
Hypothesis exactly: Phase 2 contributed 2, Phase 3 contributed 9, Phase 4 contributed 10 — one of
which, `books-implementation-hard-agent.md`, is the prose-line recipe rather than a bash block).

**Invariant holds for all fifteen files**: `--task` count is at least the genuine invocation-site
count everywhere, and the canonical-block pointer (or, for the core definition, the block itself)
is present in every file. No file failed either check; no fix was required in this phase.

## Conclusion

Uniform coverage confirmed mechanically across all fifteen `file_scope` entries. No
per-extension divergence exists in the landed mechanism.
