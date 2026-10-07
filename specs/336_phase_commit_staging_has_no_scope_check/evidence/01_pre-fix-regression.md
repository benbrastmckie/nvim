# Pre-Fix Regression Evidence: Phase-Commit Staging Has No Scope Check

Date: 2026-10-06

## Purpose

Demonstrate, with a live run of the real `git-commit-scoped.sh` code (not a paraphrase), that the
observed defect is reproducible and that supplying `--task` does **not** catch it. This is the
load-bearing claim the task's Acceptance criterion requires be exercised rather than asserted:
the V5 contended-path lease is an Overlap-family mechanism (it fires only when two or more tasks'
declared scopes name the same path) and is structurally incapable of refusing a path that zero
tasks declare, which is exactly the observed shape.

All commands below ran inside a throwaway git repository under the session scratchpad
(`/tmp/claude-*/scratchpad/task336-regression/repo/`), never inside this project repository. The
project repository's own `git log --oneline -1` was confirmed unchanged before and after this
phase (`eb7922235 task 336: create implementation plan`).

## Setup

1. `git init` a throwaway repository; `specs/state.json` written with one synthetic active
   project (`project_number: 1`) whose `file_scope` declares exactly one path:
   `typst/manual/generated/components/crc8.typ` — mirroring the real observed shape (one
   declared path out of ten staged).
2. The real `.claude/scripts/git-commit-scoped.sh`, its two sourced libraries
   (`lib/common.sh`, `lib/task-lookup-lib.sh`), `deploy-root-guard.sh`, and `task-lock.sh` (needed
   for the `--task` claim-acquire/release path) were copied byte-for-byte from this repository's
   deployed `.claude/scripts/` tree into a `.claude/scripts/` layout inside the throwaway repo, so
   `deploy-root-guard.sh`'s path-shape check passes and the exact code under test runs, not a
   restatement of it.
3. Ten files were created mirroring the observed commit's generated-file shape:
   `typst/manual/generated/components/{channel,crc8,receiver,ring_buffer,seq_num,stuff,
   stuffed_channel,varint,vec_queue,zigzag}.typ` — one inside the declared scope (`crc8.typ`),
   nine outside it.

## Live run — with `--task` supplied

Command (verbatim, run from the throwaway repo root):

```
session_id="sess_1791353053_regress1"
bash .claude/scripts/git-commit-scoped.sh \
  --message "task 1 phase 5: recertify the five books whose identity this work moves" \
  --session "$session_id" \
  --task 1 \
  -- \
  typst/manual/generated/components/channel.typ \
  typst/manual/generated/components/crc8.typ \
  typst/manual/generated/components/receiver.typ \
  typst/manual/generated/components/ring_buffer.typ \
  typst/manual/generated/components/seq_num.typ \
  typst/manual/generated/components/stuff.typ \
  typst/manual/generated/components/stuffed_channel.typ \
  typst/manual/generated/components/varint.typ \
  typst/manual/generated/components/vec_queue.typ \
  typst/manual/generated/components/zigzag.typ
```

Captured transcript (stdout+stderr):

```
[master 2c87862] task 1 phase 5: recertify the five books whose identity this work moves
 10 files changed, 10 insertions(+)
 create mode 100644 typst/manual/generated/components/channel.typ
 create mode 100644 typst/manual/generated/components/crc8.typ
 create mode 100644 typst/manual/generated/components/receiver.typ
 create mode 100644 typst/manual/generated/components/ring_buffer.typ
 create mode 100644 typst/manual/generated/components/seq_num.typ
 create mode 100644 typst/manual/generated/components/stuff.typ
 create mode 100644 typst/manual/generated/components/stuffed_channel.typ
 create mode 100644 typst/manual/generated/components/varint.typ
 create mode 100644 typst/manual/generated/components/vec_queue.typ
 create mode 100644 typst/manual/generated/components/zigzag.typ
```

**Exit status: 0.** No refusal, no warning naming the nine undeclared paths, no exit code 3
(the V5 contended-path refusal). All ten land identically whether or not `--task` is supplied.

## `git show --stat` of the resulting commit

```
commit 2c87862103fa8493c274059e1e30060031c51209
Author: Test <test@test.local>
Date:   Tue Oct 6 23:06:13 2026 -0700

    task 1 phase 5: recertify the five books whose identity this work moves

    Session: sess_1791353053_regress1

 typst/manual/generated/components/channel.typ         | 1 +
 typst/manual/generated/components/crc8.typ            | 1 +
 typst/manual/generated/components/receiver.typ        | 1 +
 typst/manual/generated/components/ring_buffer.typ     | 1 +
 typst/manual/generated/components/seq_num.typ         | 1 +
 typst/manual/generated/components/stuff.typ           | 1 +
 typst/manual/generated/components/stuffed_channel.typ | 1 +
 typst/manual/generated/components/varint.typ          | 1 +
 typst/manual/generated/components/vec_queue.typ       | 1 +
 typst/manual/generated/components/zigzag.typ          | 1 +
 10 files changed, 10 insertions(+)
```

All ten paths are present in the commit, byte-identical to the real observed commit's shape
(ten generated `.typ` files, one declared, nine not).

## Mechanism confirmation — why the lease never fires

```
$ ls specs/.contention-manifest
ls: cannot access 'specs/.contention-manifest': No such file or directory
```

The contended-path manifest directory does not exist at all in this throwaway repo (it is built
once per `/orchestrate` cycle by `build_contended_manifest` in
`scripts/lib/territory-contention-lib.sh`, which only runs from `orchestrate-cycle-plan.sh`, never
from a standalone script invocation). Even when a manifest directory *is* present, a path is only
ever written to it when `uniq_tasks >= 2` — i.e. two or more tasks' declared `file_scope` name the
same path. A path declared by **zero** tasks (all nine undeclared paths here) is never written to
`path_declarers` under any circumstance, so the V5 lease has no manifest entry to refuse against
regardless of whether the manifest directory exists. `git-commit-scoped.sh`'s own `--task` block
(lines ~282-324) confirms this structurally: when `$contention_manifest_dir` does not exist, the
entire V5 block is skipped (`if [ -d "$contention_manifest_dir" ]`), falling through to ordinary
staging with no check performed at all.

**Conclusion: `--task` does not address the observed undeclared-path case.** It closes a
different, real hazard (two tasks concurrently declaring the same path), which is orthogonal to
this defect.

## Hand-run Containment predicate

Predicate: a staged path is CONTAINED if it exactly matches a declared `file_scope` entry, or
either side is a directory/glob ancestor of the other. Run over the ten observed/reproduced paths
against the single declared path (`typst/manual/generated/components/crc8.typ`):

```
UNCONTAINED: typst/manual/generated/components/channel.typ
CONTAINED : typst/manual/generated/components/crc8.typ
UNCONTAINED: typst/manual/generated/components/receiver.typ
UNCONTAINED: typst/manual/generated/components/ring_buffer.typ
UNCONTAINED: typst/manual/generated/components/seq_num.typ
UNCONTAINED: typst/manual/generated/components/stuff.typ
UNCONTAINED: typst/manual/generated/components/stuffed_channel.typ
UNCONTAINED: typst/manual/generated/components/varint.typ
UNCONTAINED: typst/manual/generated/components/vec_queue.typ
UNCONTAINED: typst/manual/generated/components/zigzag.typ

Declared scope: typst/manual/generated/components/crc8.typ
Kept (contained): 1
Dropped (uncontained): 9
```

**Result: 1 contained, 9 uncontained** — confirming the Scope Hypothesis exactly (one path inside
the declared scope, nine outside it) and matching the real observed commit's actual split. This is
precisely the decision a pre-commit Containment self-check (Phase 2) would make: drop the nine
uncontained entries from staging (with a loud warning) and commit only the one contained entry,
rather than landing all ten silently as happened in the live run above.

## Harness note

This run was not blocked; it executed live against the real script. No structural-trace fallback
was needed.
