#!/usr/bin/env bash
# corpus.sh <N>...  evaluate the proposed landing predicate against live history
set -u
excl_re='^(specs/state\.json|specs/TODO\.md|specs/ROADMAP\.md|specs/events\.jsonl|specs/central-errors\.jsonl|\.claude-extensions\.json|\.memory/)'
for N in "$@"; do
  # attributed commits, oldest first (subject convention: "task N:" or "task N phase")
  mapfile -t all < <(git log --no-merges --reverse --format=%H -E --grep="^task ${N}(:| phase )" HEAD~700..HEAD)
  [ "${#all[@]}" -eq 0 ] && { echo "task $N: no attributed commits"; continue; }
  comp="$(git log --no-merges --reverse --format='%H' -E --grep="^task ${N}: complete implementation" HEAD~700..HEAD | head -1)"
  [ -z "$comp" ] && { echo "task $N: no completion commit"; continue; }
  T="$(git rev-parse "${comp}^")"            # integration tip when verification would have run
  own=(); for c in "${all[@]}"; do git merge-base --is-ancestor "$c" "$T" && own+=("$c"); done
  [ "${#own[@]}" -eq 0 ] && { echo "task $N: none before completion"; continue; }; end="${own[-1]}"
  mapfile -t P < <(for c in "${own[@]}"; do git diff-tree --no-commit-id --name-only -r "$c"; done | sort -u)
  mis_all=0; mis_own=0; pc=0; offenders=""
  for p in "${P[@]}"; do
    a="$(git rev-parse -q --verify "${T}:${p}" 2>/dev/null || echo absent)"
    b="$(git rev-parse -q --verify "${end}:${p}" 2>/dev/null || echo absent)"
    if [ "$a" != "$b" ]; then
      mis_all=$((mis_all+1))
      if ! [[ "$p" =~ $excl_re ]]; then mis_own=$((mis_own+1)); offenders+=" $p"; fi
    fi
    [[ "$p" =~ $excl_re ]] || pc=$((pc+1))
  done
  between="$(git rev-list --count --no-merges "${own[0]}^..${T}")"
  echo "task $N: attributed=${#own[@]} span_commits=${between} paths=${#P[@]} own_paths=${pc} mismatch_fullset=${mis_all} mismatch_ownset=${mis_own}${offenders:+ OFFENDERS:$offenders}"
done
