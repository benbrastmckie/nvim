#!/usr/bin/env bash
# Per-task squash on a review ref by BLOB OVERLAY from a landing proof (path set + end commit). No worktree, no HEAD.
set -u; cd "$1/e3"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
base=$(git rev-list --max-parents=0 HEAD); excl='^(specs/state\.json|specs/TODO\.md)$'
git update-ref -d refs/review/o 2>/dev/null; git update-ref refs/review/o "$base" ""
overlay() { # overlay <subject> <src-commit> <paths...>
  local subj="$1" src="$2"; shift 2; local tip idx p; tip=$(git rev-parse refs/review/o); idx="$(mktemp -u)"
  GIT_INDEX_FILE="$idx" git read-tree "$tip"
  for p in "$@"; do
    if git cat-file -e "$src:$p" 2>/dev/null; then GIT_INDEX_FILE="$idx" git update-index --add --cacheinfo "$(git ls-tree "$src" -- "$p" | awk '{print $1","$3}'),$p"
    else GIT_INDEX_FILE="$idx" git update-index --force-remove -- "$p"; fi
  done
  local tree; tree=$(GIT_INDEX_FILE="$idx" git write-tree); rm -f "$idx"
  [ "$tree" = "$(git rev-parse "$tip^{tree}")" ] && { echo "no change"; return 0; }
  git update-ref refs/review/o "$(git commit-tree "$tree" -p "$tip" -m "$subj")" "$tip"; echo ok; }
for N in 1 2; do
  mapfile -t own < <(git log --no-merges --reverse --format=%H -E --grep="^task $N( |:)" $base..trunk)
  mapfile -t P < <(for x in "${own[@]}"; do git diff-tree --no-commit-id --name-only -r "$x"; done | sort -u | grep -Ev "$excl")
  echo "task $N overlay (${P[*]} from ${own[-1]:0:7}): $(overlay "task $N: title $N" "${own[-1]}" "${P[@]}")"
done
# remainder: everything the per-task commits did not carry, taken from the integration tip
tip=$(git rev-parse refs/review/o); rest=$(git commit-tree "$(git rev-parse trunk^{tree})" -p "$tip" -m "bookkeeping: state and unattributed changes")
git update-ref refs/review/o "$rest" "$tip"
echo "review log:"; git log --format='  %s  [%h]' --stat=60 refs/review/o | grep -v '^$' | head -20
echo "review tip tree == integration tip tree: $([ "$(git rev-parse refs/review/o^{tree})" = "$(git rev-parse trunk^{tree})" ] && echo yes || echo no)"
echo "branch: $(git symbolic-ref --short HEAD); status: '$(git status --porcelain)'"
