#!/usr/bin/env bash
set -u
SP="$1"; LIB="$2"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mk() { rm -rf "$SP/$1"; mkdir -p "$SP/$1"; cd "$SP/$1"; git init -q -b trunk .; mkdir -p src specs; echo base > src/a.txt; echo base > src/b.txt; echo base > src/shared.txt; echo '{}' > specs/state.json; git add -- src/a.txt src/b.txt src/shared.txt specs/state.json; git commit -qm "init"; }
c() { git add -- "${@:2}"; git commit -qm "$1"; }
seed() { echo 1a > src/a.txt; echo s1 > specs/state.json; c "task 1 phase 1: a" src/a.txt specs/state.json
  echo 2b > src/b.txt; echo s2 > specs/state.json; c "task 2 phase 1: b" src/b.txt specs/state.json
  echo 1a2 > src/a.txt; echo s3 > specs/state.json; c "task 1 phase 2: a again" src/a.txt specs/state.json
  echo r > specs/ROADMAP.md; c "roadmap: maintenance pass" specs/ROADMAP.md; }
# verify <N> <base> [extra reported paths]: the proposed landing predicate (V1..V5)
verify() {
  local N="$1" base="$2" integ="trunk" excl='^(specs/state\.json|specs/TODO\.md)$'
  [ "$(git symbolic-ref -q HEAD)" = "refs/heads/$integ" ] || { echo "REFUSE:V1 HEAD is not on $integ"; return 1; }
  local own; mapfile -t own < <(git log --no-merges --reverse --format=%H -E --grep="^task ${N}(:| phase )" "${base}..${integ}")
  [ "${#own[@]}" -gt 0 ] || { echo "REFUSE:V2 no commit attributable to task $N in ${base:0:7}..$integ"; return 1; }
  local end="${own[-1]}" P p; mapfile -t P < <(for x in "${own[@]}"; do git diff-tree --no-commit-id --name-only -r "$x"; done | sort -u | grep -Ev "$excl")
  for p in "${P[@]}"; do
    local a b; a="$(git rev-parse -q --verify "$integ:$p" 2>/dev/null || echo absent)"; b="$(git rev-parse -q --verify "$end:$p" 2>/dev/null || echo absent)"
    if [ "$a" != "$b" ]; then echo "REFUSE:V4 $p differs between $integ and end commit ${end:0:7}; offending: $(git log --format='%h %s' "$end..$integ" -- "$p" | tr '\n' ';')"; return 1; fi
  done
  local dirty; dirty="$(git status --porcelain -- "${P[@]}" "${@:3}" 2>/dev/null)"
  [ -z "$dirty" ] || { echo "REFUSE:V5 unlanded working-tree content: $(echo "$dirty" | tr '\n' ';')"; return 1; }
  echo "PASS task $N commits=${#own[@]} end=${end:0:7} paths=${P[*]}"
}
echo "=== E1 option B: interleaved tasks, one branch"
mk e1; base=$(git rev-parse HEAD); seed
echo "E1.pos task1: $(verify 1 $base)"; echo "E1.pos task2: $(verify 2 $base)"
echo "E1 branch unchanged: $(git symbolic-ref --short HEAD)"
echo "--- NEG-a: work edited but never committed (silent exit-1 commit)"
echo 2b-more > src/b.txt; echo "E1.neg-a task2: $(verify 2 $base)"; echo 2b > src/b.txt
echo "--- NEG-a2: reported-but-never-committed NEW file (widening path from the dispatch report)"
echo new > src/new2.txt; echo "E1.neg-a2 task2: $(verify 2 $base src/new2.txt)"; rm src/new2.txt
echo "--- NEG-d: no state-file exclusion -> false refusal on interleave"
echo "full-set mismatch on specs/state.json for task 2: tip=$(git rev-parse --short trunk:specs/state.json) end=$(git rev-parse --short "$(git log --format=%H -E --grep='^task 2' -1)":specs/state.json)"
echo "--- NEG-b: a foreign commit overwrites task 1's path after its end commit"
echo clobber > src/a.txt; c "core: hand edit" src/a.txt; echo "E1.neg-b task1: $(verify 1 $base)"; echo "E1.neg-b task2 (sibling still lands): $(verify 2 $base)"
echo "--- NEG-c: commits made on a detached HEAD (stranded)"
mk e1c; base=$(git rev-parse HEAD); git checkout -q --detach; echo 3 > src/a.txt; c "task 3 phase 1: a" src/a.txt; echo "E1.neg-c detached: $(verify 3 $base)"; git checkout -q trunk 2>/dev/null; echo "E1.neg-c back on trunk: $(verify 3 $base)"

echo; echo "=== E2 option A: phase commits on a side ref by plumbing, HEAD stays on trunk"
mk e2; base=$(git rev-parse HEAD); git update-ref refs/batch/s1 "$base" ""
pc() { local tip; tip=$(git rev-parse refs/batch/s1); local idx; idx="$(mktemp -u)"
  GIT_INDEX_FILE="$idx" git read-tree "$tip"; GIT_INDEX_FILE="$idx" git add -- "${@:2}"
  local tree; tree=$(GIT_INDEX_FILE="$idx" git write-tree); rm -f "$idx"
  git update-ref refs/batch/s1 "$(git commit-tree "$tree" -p "$tip" -m "$1")" "$tip"; }
echo 1a > src/a.txt; pc "task 1 phase 1: a" src/a.txt
echo 2b > src/b.txt; pc "task 2 phase 1: b" src/b.txt
echo 1a2 > src/a.txt; pc "task 1 phase 2: a again" src/a.txt
echo "E2 side ref log: $(git log --format=%s refs/batch/s1 | tr '\n' ';')"
echo "E2 HEAD branch: $(git symbolic-ref --short HEAD); trunk moved: $([ "$(git rev-parse trunk)" = "$base" ] && echo no || echo yes)"
echo "E2 primary tree status vs HEAD after all 'commits': $(git status --porcelain | tr '\n' ';')"
( source "$LIB"; echo "E2 admission dirty paths (batch_admission_dirty_paths): $(batch_admission_dirty_paths "$PWD" | tr '\n' ';')" )
t1=$(git log --reverse --format=%H -E --grep='^task 1' "$base..refs/batch/s1")
echo "E2 cherry-pick -n of task 1's side commits into the primary tree:"; git cherry-pick -n $t1 > "$SP/cp.out" 2>&1; echo "    rc=$?"; sed 's/^/    /' "$SP/cp.out"
echo "    status after the refused pick: $(git status --porcelain | tr '\n' ';')"
echo "E2 landing as an ordinary scoped commit of task 1's paths from the working tree:"; git add -- src/a.txt; git commit -qm "task 1: title"; echo "    trunk tip: $(git log -1 --format=%s); blob equal to side end: $([ "$(git rev-parse trunk:src/a.txt)" = "$(git rev-parse refs/batch/s1:src/a.txt)" ] && echo yes || echo no); status after: $(git status --porcelain | tr '\n' ';')"

echo; echo "=== E3 option C: review ref with one commit per task, built by merge-tree replay from the integration branch"
replay() { local ref="$1" subj="$2"; shift 2; local tip tree cur x; tip=$(git rev-parse "$ref"); cur=$tip
  for x in "$@"; do
    tree=$(git merge-tree --write-tree --merge-base="$x^" "$cur" "$x" 2>/dev/null) || { echo "CONFLICT replaying ${x:0:7} ($(git log -1 --format=%s $x))"; return 1; }
    cur=$(git commit-tree "$tree" -p "$cur" -m tmp)
  done
  git update-ref "$ref" "$(git commit-tree "$(git rev-parse "$cur^{tree}")" -p "$tip" -m "$subj")" "$tip"; echo "ok"; }
mk e3; base=$(git rev-parse HEAD); seed; git update-ref refs/review/r "$base"
for N in 1 2; do echo "E3 task $N: $(replay refs/review/r "task $N: title $N" $(git log --no-merges --reverse --format=%H -E --grep="^task $N( |:)" $base..trunk))"; done
echo "E3 unattributed: $(replay refs/review/r "roadmap: maintenance pass" $(git log --no-merges --reverse --format=%H --invert-grep -E --grep='^task [0-9]+' $base..trunk))"
echo "E3 review log: $(git log --format=%s refs/review/r | tr '\n' ';')"
echo "E3 review tip tree == integration tip tree: $([ "$(git rev-parse refs/review/r^{tree})" = "$(git rev-parse trunk^{tree})" ] && echo yes || echo no)"
echo "E3 HEAD/branch/worktree untouched: $(git symbolic-ref --short HEAD) status='$(git status --porcelain)'"
echo "--- E3 limit: two tasks interleave on ONE file"
mk e3b; printf 'l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9\n' > src/shared.txt; c "init2" src/shared.txt; base=$(git rev-parse HEAD)
sed -i 's/l1/X1/' src/shared.txt; c "task 7 phase 1: x" src/shared.txt
sed -i 's/l9/Y1/' src/shared.txt; c "task 8 phase 1: y" src/shared.txt
sed -i 's/l5/X2/' src/shared.txt; c "task 7 phase 2: x" src/shared.txt
git update-ref refs/review/r "$base"
for N in 7 8; do echo "E3b distant lines task $N: $(replay refs/review/r "task $N: t" $(git log --no-merges --reverse --format=%H -E --grep="^task $N( |:)" $base..trunk))"; done
echo "E3b tree equal: $([ "$(git rev-parse refs/review/r^{tree})" = "$(git rev-parse trunk^{tree})" ] && echo yes || echo no)"
sed -i 's/X1/Y-over-X1/' src/shared.txt; c "task 8 phase 2: y edits x's line" src/shared.txt
sed -i 's/Y-over-X1/X-again/' src/shared.txt; c "task 7 phase 3: x edits it back" src/shared.txt
git update-ref -d refs/review/r; git update-ref refs/review/r "$base"
for N in 7 8; do echo "E3b same line task $N: $(replay refs/review/r "task $N: t" $(git log --no-merges --reverse --format=%H -E --grep="^task $N( |:)" $base..trunk))"; done
