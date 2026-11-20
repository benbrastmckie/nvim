#!/usr/bin/env bash
# specs-ignore-lib.sh - Single home of the question "is this repository's specs tree, or this
# one path inside it, gitignored?" Modelled structurally on
# scripts/lib/engine-written-state-paths-lib.sh's header style: a contract statement, the
# fail-open posture, and an explicit enumeration of its consumers.
# Sourced, never executed; sets no shell options a caller inherits; never calls `exit`.
#
# Contract: a repository's `specs/` tree is ordinarily tracked, but a consumer repository may
# add `specs/` (wholly or partly) to its own `.gitignore`. Today's commit path has no
# ignore-awareness on its positive-pathspec side: an untracked, gitignored path reaches `git
# add`, is silently skipped by git, and is then reported as a staging failure indistinguishable
# from a real one. This library exists so that question is answered in exactly one place and
# consulted from one place, never reimplemented at a call site (`git-commit-scoped.sh`'s own
# `V13` classification gate).
#
# Fail-open posture: both functions below are rc-based booleans with no stdout. `rc 0` means
# *definitively ignored*; any other rc (not ignored, or indeterminate -- a malformed pathspec, a
# missing repository, `git` itself failing) means *treat as not ignored*. This makes the
# fail-open direction structural rather than a convention a caller must remember, and mirrors
# the fall-through direction `git-commit-scoped.sh` already documents for its own
# `check-ignore` call ("ONLY exit code 0 ... skips injection"). It departs from
# `engine_written_state_paths`'s print-and-return-0 shape because that function returns a
# *set*; these two answer a *question*, and the caller needs the rc, not a string to parse.
#
# Index-awareness: `git check-ignore -q` is index-aware. For a path that is already TRACKED,
# `check-ignore -q` reports *not ignored* (rc 1) even when the path also matches a `.gitignore`
# rule, under both a parent-directory rule and a direct file-level rule. This is the property
# that makes a separate tracked/untracked test unnecessary at any call site that consults
# `path_is_gitignored`: a tracked-but-ignore-matching path (a different, pre-existing advisory
# shape documented in context/standards/git-staging-scope.md's "Positive-Pathspec Ignore-Advisory
# Hazard" section) structurally cannot be misclassified as "ignored" by this library.
#
# Why this library does NOT duplicate engine-written-state-paths-lib.sh's path list, and must
# never acquire one: that library answers "which paths does the engine write on behalf of every
# task" -- a fixed, enumerable constant. This library answers a question about a REPOSITORY'S
# OWN ignore configuration, which varies per repository and per path and cannot be captured as a
# static list; it is a predicate over live `git check-ignore` state, not a set membership test.
#
# Two exported functions:
#
#   specs_tree_is_gitignored <repo_root>
#     `git -C "<repo_root>" check-ignore -q -- specs`; rc 0 = the specs tree itself is ignored,
#     any other rc = not ignored / indeterminate. Answers the repository-level question.
#
#   path_is_gitignored <repo_root> <path>
#     `git -C "<repo_root>" check-ignore -q -- "<path>"`; same rc contract, evaluated for one
#     path. This is the function `git-commit-scoped.sh`'s `V13` gate consults per pathspec,
#     immediately before the path can reach case 1's existence test.
#
# Rejected candidates and why each fails to belong here:
#   - A function returning the LIST of ignored paths under a tree - no consumer needs a list;
#     every consumer asks a yes/no question about one path or about the tree as a whole, and a
#     list-returning function would require its own parsing convention for no benefit.
#   - A function that also classifies the TRACKED-but-ignore-matching advisory shape - that is a
#     different, already-handled case (V7's tolerated-advisory carve-out); this library only
#     ever has to answer "is this specific thing ignored", and the index-awareness documented
#     above already makes that one question sufficient for both calling shapes.
#   - Caching/memoizing results across calls within one invocation - `git check-ignore` is cheap
#     and the predicate must stay a pure function of live repository state; caching would risk a
#     stale answer within a single long-running script that maintains its own state.
#
# Consumers (each sources this file and calls one of the two functions above, never
# re-implementing `git check-ignore` inline):
#   - scripts/git-commit-scoped.sh (the V13 classification gate, guarded source with fall-through
#     to today's unmodified behaviour on a sourcing failure)

# specs_tree_is_gitignored <repo_root>
# Returns 0 if the repository's specs tree itself is gitignored, 1 otherwise (not ignored, or
# indeterminate -- a missing/invalid repo_root, or git itself failing). Never prints anything.
specs_tree_is_gitignored() {
  local repo_root="$1"
  [ -n "$repo_root" ] || return 1
  git -C "$repo_root" check-ignore -q -- specs 2>/dev/null
  local rc=$?
  [ "$rc" -eq 0 ] && return 0
  return 1
}

# path_is_gitignored <repo_root> <path>
# Returns 0 if the given path is gitignored (and, by check-ignore's own index-awareness, not
# already tracked), 1 otherwise. Never prints anything.
path_is_gitignored() {
  local repo_root="$1"
  local path="$2"
  [ -n "$repo_root" ] && [ -n "$path" ] || return 1
  git -C "$repo_root" check-ignore -q -- "$path" 2>/dev/null
  local rc=$?
  [ "$rc" -eq 0 ] && return 0
  return 1
}
