# Cross-Repo Task Migration

How a task record moves from a repository that cannot perform its work into the repository that
owns the files it edits. Written for, and followed by, the migration of mis-sited agent-system
records out of a consuming repository into this source-store repository.

This is a documented procedure, not a script. Cross-repo migration is rare; a general-purpose
migration tool would be speculative generality against an unproven need.

## When a record must move

A record belongs in the repository that owns its **edit targets**, not the one whose session
happened to create it. Apply the readability test, not a path-shape test:

> Could a dispatch picking this record up, in the repository it currently sits in, read the files
> it is meant to edit and commit what it writes?

If no, it must move. `git-commit-scoped.sh` drops an unmatched pathspec with a warning rather
than failing, so a mis-sited record's completion commit silently contains none of its own
deliverable — the failure is quiet, which is why these records accumulate.

Three classes are *not* movable and must be recognised before any list is built:

- **Split-scope**: edit targets in both repositories. Migration relocates the defect rather than
  repairing it. Leave in place and record why.
- **Observed-case citations are not edit targets.** A record whose edit target is a single
  manifest or context file, but whose evidence cites source files in the consuming repository,
  is movable — the cited files are a fixture, not scope. Read the description before judging.
- **Already complete.** A record completed in the wrong repository needs no migration. The work
  is done; only its siting was ever wrong.

## Identifying the set — two filters that both under-count

A filter keyed on "every `file_scope` entry is under the source-store prefix" misses two classes:

1. **Deploy-mirror declarations.** A consuming repository's records often declare the deployed
   mirror path alongside the real source path, deliberately, so that repository's own overlap
   gate can see a collision surface. Strip mirror paths *before* testing, or these records read
   as mixed-scope and stay behind.
2. **Absent or mirror-only `file_scope`.** A record declaring none, or declaring only mirror
   paths, cannot be classified by scope at all. Classify these by reading the description for
   named edit targets.

Re-measure every figure at migration time. A migration list is stale by construction whenever the
authoring hole that produced the mis-sited records is still open, and record statuses change
underneath it — records complete in place, get archived, or gain dependencies.

## The procedure

### 1. Renumber, never copy

The two repositories keep independent numbering spaces. Allocate from the receiving repository's
`next_project_number`, and advance it in the same write.

Re-read the counter **immediately before** writing and re-check for duplicate `project_number`
values **immediately after**. A value read earlier in the same session is not safe: a concurrent
writer in the window between read and write produces colliding numbers and can clobber the other
writer's counter bump.

### 2. Preserve descriptions verbatim

Copy the description field programmatically rather than retyping or summarising it. Measured
evidence — line numbers, reproduction commands, enumerated sub-faults, `iss_*` citation ids — is
the entire value of a record, and paraphrase destroys it. A programmatic copy satisfies this
exactly; an edit pass does not.

The one permitted addition is a provenance note recording the migration and how citation
resolvability was discharged.

### 3. Keep citations resolvable across the boundary

An `iss_*` id, or any artifact path, that resolves only under the source repository becomes a
dangling reference once read from the receiving one. Pick one approach, apply it uniformly, and
state which was used in the migrated record: repository-qualified absolute path, or a copied
evidence excerpt carried into the description. Never leave a bare relative path standing.

### 4. Give each vacated record a terminal status and a durable pointer

Choose `abandoned` or `expanded` deliberately and record the reasoning. The vacated record is the
only trace a future reader of the source repository has.

Pair any number in the pointer with a durable anchor — the `project_name` slug, the named
source-store file, an `iss_*` id. Bare cross-repo numbers are especially unstable: they are
renumbered by vault operations, and a number from one repository's space means something
different in the other's.

### 5. Measure directory trackability before committing

An all-empty task directory is not git-trackable and a commit naming it is refused. Check each
directory's actual population at migration time and omit empty ones from the commit path list.
Most mis-sited records are `not_started` and carry empty directories, so this is the common case
rather than the exception.

### 6. Derive a `file_scope` where none exists

An absent `file_scope` is itself a defect — the pre-dispatch review reports it — so migrating a
record unchanged carries that defect across. Derive the scope from the edit targets named in the
description.

### 7. Rewrite `file_scope` to source-store paths only

Strip deploy-mirror declarations. This is a **consequence of migration, not a defect repair**:
the mirror declarations were coherent where they were written, because the consuming repository's
overlap gate runs over a tree in which only the deployed paths exist. That rationale does not
survive the move — the receiving repository's gate runs over a tree where the source path is real
and its own deploy tree is unrelated to the source repository's.

Match the receiving repository's house style, observed rather than assumed, by reading its
comparable existing records.

### 8. Resolve every dependency edge explicitly

For each edge, decide and record one of:

- **Both ends move** — remap to the new number. An edge between two migrating records survives
  only if they move together; moving either alone breaks it silently.
- **Referent is complete or archived** — the edge is satisfied; drop it and record that it was.
- **Referent stays behind** — the edge cannot be expressed in the receiving repository's space.
  Record it as prose provenance rather than leaving a number that resolves to the wrong record.

### 9. Supply titles where null

Derive a title from the description rather than carrying a null across.

## Duplicates: transplant before abandoning

Where a record duplicates one the receiving repository already holds, the duplicate is abandoned
rather than migrated — but only after anything it holds that the absorbing record does not is
transplanted into the absorbing record. Look for two things in particular:

- **Independent corroboration from a different run.** A second reproduction materially
  strengthens a case, and a reproduction at higher severity changes which remedy is warranted.
- **A live disagreement.** Where the two records reach opposite conclusions on a sub-question,
  the absorbing record may be treating as settled something the duplicate treats as open. Surface
  it there as open rather than discarding it.

If amending the absorbing record is not possible, do not abandon the duplicate. Report it and
leave it open.

Check the absorbing record's status before amending, and do not amend it mid-dispatch.

## Scope blindness is real, not an exemption

A migration mutates task state in **both** repositories. The receiving repository's `file_scope`
cannot name the source repository's `state.json` or `TODO.md`, so no local overlap check can see
that half of the work. A concurrent dispatch touching the source repository's task state will not
be detected as colliding. Serialize manually when that risk is live: check for live sessions
registered against the source repository before writing.

## Order of operations

Write the receiving repository first, verify, then vacate the source. The reverse order risks
records that exist in neither repository if the second write fails.

1. Receiving repository: append the renumbered entries, advance the counter.
2. Verify: no duplicate numbers, counter correct, every expected record present.
3. Move task directories, skipping empty ones.
4. Source repository: set each vacated record terminal with its pointer.
5. Verify both trees, then commit each repository separately with its own scoped path list.
