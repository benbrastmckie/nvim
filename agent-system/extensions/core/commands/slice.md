---
description: Propose, build, and track a stack of reviewable slices cut from the current work ref against a chosen target (user-only)
allowed-tools: Bash(git:*), Bash(gh:*), Bash(glab:*), Bash(.claude/scripts/slice-series.sh:*), AskUserQuestion, Read, Write, Glob
argument-hint: "[free-text description of what to slice]"
model: sonnet
---

# Command: /slice

**Purpose**: Cuts the difference between the current work ref and a chosen target branch into a
stack of reviewable slices, builds each one by plumbing (no checkout, no merge), and tracks a
series through push and pull-request open across repeated invocations.
**User Only**: YES — Agents, skills, and lifecycle scripts MUST NOT invoke this command. It
appears in no skill-to-agent mapping and no lifecycle script calls it; see
`rules/pr-prohibition.md`, which this command's own design observes directly: it never pushes
and it opens a pull request only in its own "open" step, on the operator's explicit "yes" inside
this same user-typed invocation.
**Layer**: 1 (Direct execution)
**Delegates To**: none — this command performs its own resolution, proposal, and build steps
directly, driving `scripts/slice-series.sh` for every validated/built/reported fact and the
forge CLI for the one call that opens a pull request.

---

## Vocabulary

- **Work ref**: where content is read from — the currently checked-out branch (or `HEAD`).
- **Target**: the remote branch slices are based on and pull requests are opened against.
- **Series**: one work ref cut into slices for one target, recorded at
  `specs/.orchestration/slices/<series id>.json`.
- **Slice**: one path set, cut from the work ref's tip, built as one commit on the target.

---

## Usage

```
/slice [free-text description of what to slice]
```

A description is optional and never required. When given, it steers both prompts: if it names
exactly one candidate target unambiguously, that answers prompt 1 (printed, not asked); it never
answers prompt 2 — the proposal is always shown and always needs an explicit "approve".

---

## Execution

**EXECUTE NOW**: Follow these steps in sequence. Do not just describe what should happen —
actually perform each step.

### STEP 1: Resolution (printed, no question)

**EXECUTE NOW**:

```bash
work_ref="$(git branch --show-current)"
[ -n "$work_ref" ] || work_ref="HEAD"
work_sha="$(git rev-parse --short HEAD)"
configured_remote="$(git config --get "branch.${work_ref}.remote" 2>/dev/null || true)"
remote_count="$(git remote | wc -l | tr -d ' ')"
dirty_paths="$(git status --porcelain | wc -l | tr -d ' ')"
```

Determine the remote:
- If `configured_remote` is non-empty, use it.
- Else, if exactly one remote exists (`git remote`), use that one.
- Else, if more than one remote exists and none is configured for this branch, ask the user
  which remote to use via `AskUserQuestion` before continuing (this is the only question in
  resolution; everything else here is printed, not asked).
- Else (no remote at all): print one line — `No remote is configured; there is nothing to open
  a pull request against.` — and **STOP**. Nothing below this point can run without a remote.

Attempt a fetch of the chosen remote (`git fetch "$remote" --quiet 2>&1`); on success, print
`fetched <remote> just now`; on failure, print `fetch failed, figures are against the last
fetch` and proceed — a stale fetch degrades the precision of the measured differences shown
below but never blocks the command.

Print:
```
work ref   <work_ref> at <work_sha>
remote     <remote>
fetched    <remote> just now   (or: fetch failed, figures are against the last fetch)
tree       <dirty_paths> uncommitted paths are not sliced   (only when dirty_paths > 0)
```

**IMMEDIATELY CONTINUE** to STEP 2.

---

### STEP 2: Prompt 1 — the target

**EXECUTE NOW**: Build the candidate set from exactly three live sources and free entry — never
a declaration file for this step:

1. **An in-flight series for this work ref.** List
   `specs/.orchestration/slices/*.json`; for each, check whether `.work_ref.name` matches
   `work_ref` (live `git rev-parse` comparison, not a string match alone, since a renamed branch
   can still be the same ref) and the series is not fully `merged`/closed. If found, it is shown
   **first**, labelled `continue <series_id>: <n> of <m> merged` (counts from `.slices[].state`).
   Choosing it skips straight to STEP 6 (the continue step) using that series' own recorded
   target — it is not a new target choice.
2. **The remote's default branch**: `git symbolic-ref "refs/remotes/${remote}/HEAD" 2>/dev/null`
   (or `git remote show "$remote" | grep 'HEAD branch'` as a fallback), shown as
   `<remote>/<default branch>`.
3. **The bases of the user's own open pull requests on that remote, where they differ** from
   the default branch above. Detect the forge platform the same way `/merge` does (the remote
   URL's host, falling back to `gh auth status` / `glab auth status`), then list open requests
   authored by the current user (`gh pr list --author @me --json baseRefName,number,url` or
   `glab mr list --author=@me`), and show each distinct base not already listed, labelled
   `<remote>/<base> — base of your open pull request #<n>`.
4. **Free entry, always last** — the user may type any other branch name or ref.

For every candidate except free entry, compute and show its measured difference from the work
ref:
```bash
git merge-base --is-ancestor "<candidate>" "$work_ref"   # ancestor test
git rev-list --count "<candidate>..${work_ref}"          # commits ahead
git diff --shortstat "<candidate>" "$work_ref"            # files / lines
```
- A candidate that is **not** an ancestor of the work ref is still shown, but cannot be chosen;
  name the merge-up needed (`needs a merge-up first: <n> commits on it are not in the work ref`)
  and never offer it as a selectable option. `/slice` never merges.
- A candidate whose difference is empty is shown as `nothing to slice`.
- A candidate sharing the work ref's own name is never, by itself, a reason to exclude it — only
  an empty difference or a non-ancestor relationship disqualifies a candidate.

Ask via `AskUserQuestion`:
```json
{
  "question": "Slice <work_ref> for review against which branch?",
  "header": "Choose Target",
  "multiSelect": false,
  "options": [
    {"label": "continue <series_id>", "description": "<n> of <m> merged; resumes tracking the in-flight series"},
    {"label": "<remote>/<default branch>", "description": "<n> commits ahead, <files> files, <lines> added lines"},
    {"label": "<remote>/<base>", "description": "base of your open pull request #<n>; <n> commits ahead, <files> files"},
    {"label": "another branch", "description": "type its name"}
  ]
}
```
(Omit the `continue` option when no in-flight series exists for this work ref. Omit a
non-ancestor candidate from the selectable list entirely, printing its merge-up line above the
question instead.)

If a free-text description was given and it names exactly one candidate unambiguously, print
the resolved target line directly and skip the question.

**If "continue ..." was chosen**: **IMMEDIATELY CONTINUE** to STEP 6.
**Otherwise**: record the chosen target, **IMMEDIATELY CONTINUE** to STEP 3.

---

### STEP 3: The bar line (printed, no question)

**EXECUTE NOW**: This record ships only the shipped default — `1,500` added lines and `30`
files — printed as `default, unmeasured`. (The series schema also accepts `declared` and
`measured` sources for a future successor that populates them; this command never produces
either.)

Print:
```
bar        1,500 added lines / 30 files   default, unmeasured
```

**IMMEDIATELY CONTINUE** to STEP 4.

---

### STEP 4: Prompt 2 — the proposal

**EXECUTE NOW**: Draft a candidate series document (never the durable path yet — a throwaway
file under your own scratch area, or piped on stdin to `check`) from:
- the target→work_ref difference (`git diff --name-status <target> ${work_ref}`),
- the directory structure of the changed paths,
- completed tasks' `modified_files` (from `specs/*/​.return-meta.json` or `specs/state.json`),
  used **only as a hint** toward grouping — never as a source of truth and never required.

Group paths into slices by your own judgment (what reviews well together), name each slice's
`depends_on` edges only where one slice's content is logically built on another's, and leave
every other declared field (`over_bar_reason`, `state: "proposed"`, etc.) at its default.

Validate the candidate document:
```bash
bash .claude/scripts/slice-series.sh check <candidate-path-or- "-" with the document piped>
```
This is the validation-only run the schema's candidate-document input exists for: it writes
nothing durable and produces exactly the counts this prompt needs. If `check` refuses, the
reason tells you what to fix before a table can even be shown:
- `path_unassigned` / `path_in_two_slices` / `glob_empty` — regroup the paths.
- `depends_on_unknown` / `depends_on_cycle` — fix the declared edges.
- `over_bar_no_reason` — for that slice: add a declared `over_bar_reason` (`single_file` or
  `generated_tree`) if it genuinely qualifies, split it, or revise the bar. **A row that is over
  the bar with no reason blocks approval entirely until resolved** — `build` refuses the whole
  document on this condition exactly as `check` does, so there is no partial "build everything
  else anyway" outcome to fall back on. Show such a row as `OVER, NO REASON: will not build` and
  do not offer "approve" until the user has revised it away.

Once `check` succeeds, print the proposal:
```
 id  title                          files   lines / bar     depends on   opens against
 a   <title>                           9     1,204 / 1,500   -            <target>
 b   <title>                          12     1,610 / 1,500   a            <target>, after a merges
 c   <title>                           1     3,300 / 1,500   -            <target>   OVER: single_file

 assigned     <assigned> of <diff_total> changed paths      unassigned <unassigned>   in two slices <in_two_slices>
 not landing  <not_landing> paths                            (listed on request)
 generated    none declared; every path counts toward the bar
 cost         <n> slices: <n> typed pushes, one at a time, then 1 /slice to open them

 approve / revise (say what to change) / cancel
```
Every one of the four fixed lines (`assigned`, `not landing`, `generated`, `cost`) is always
printed, with zeros shown as zeros — never omitted for a zero count. State explicitly, once,
beneath the table: "No per-slice check ran; nothing here proves slice `b` builds or passes
without slice `c`." **Nothing is written before approve.**

Ask via `AskUserQuestion`:
```json
{
  "question": "Approve this proposal?",
  "header": "Confirm Slices",
  "multiSelect": false,
  "options": [
    {"label": "approve", "description": "Write the series file and build every slice that can be built"},
    {"label": "revise", "description": "Say what to change (regrouping, a different bar, dependencies, over_bar_reason)"},
    {"label": "cancel", "description": "Abort. Nothing is written."}
  ]
}
```

**Response handling**:
- **"approve"**: **IMMEDIATELY CONTINUE** to STEP 5.
- **"revise"**: ask what to change (free text — e.g. "split c by directory", "bar 2,000 / 40",
  "c over_bar_reason single_file"), re-draft the candidate document accordingly, and return to
  the top of this step. The bar, if replaced here, is recorded as `chosen at prompt` in the
  series document once written. Revise never writes anything either.
- **"cancel"**: print "Cancelled. Nothing was written." and **STOP**.

---

### STEP 5: On approval

**EXECUTE NOW**:

1. Allocate a `series_id` (short, stable, derived from the work ref and target — never a task
   number) and write the approved candidate document to the durable path
   `specs/.orchestration/slices/<series_id>.json`. This is the first durable write of this
   invocation.
2. Run the build:
   ```bash
   bash .claude/scripts/slice-series.sh build specs/.orchestration/slices/<series_id>.json
   ```
   Because `check` already succeeded against this exact document in STEP 4 and nothing about
   the repository changed since, `build` refuses nothing structural here; its only per-slice
   outcome is a slice **waiting** on two or more unmerged dependencies (never a bar refusal,
   which was already resolved before approval was possible — see STEP 4).
3. The union — the target's tree overlaid with every built slice equals the work ref's tree on
   every assigned path — needs no separate runtime check here: STEP 4's `check` already proved
   every difference path is assigned to exactly one slice, and the overlay primitive `build`
   uses is the same one the script's own suite statically proves preserves that assignment.
4. Print one line per slice, from `build`'s own output:
   ```
   a  built  <short sha>   /please push <remote> slice/<series_id>/a
   b  waits on a
   then: /slice
   ```
   `<short sha>` is the first 7-12 characters of the slice's built commit. The exact
   `/please push <remote> slice/<series_id>/<id>` line is what the operator types next — this
   command never pushes it itself. The closing `then: /slice` line is always printed.
5. **Do not push. Do not invoke the forge CLI here. Do not create a pull request.** This step
   ends with the operator holding typed lines, not with anything sent anywhere.

**STOP** here for this invocation — the operator now runs the printed `/please push ...` lines
(one at a time; only one push grant is live at once) and returns later with `/slice` to
continue.

---

### STEP 6: The continue step (a later `/slice` while a series is in flight)

**EXECUTE NOW** (reached either from STEP 2's `continue` choice or because exactly one in-flight
series exists and resolution found it unambiguous):

1. Run the report:
   ```bash
   bash .claude/scripts/slice-series.sh status specs/.orchestration/slices/<series_id>.json
   ```
2. Print one state line per slice from that output (local/remote ref state, `merged`,
   `rebuild_due`).
3. Ask, via `AskUserQuestion`, **only what is due** — omit any bullet below with nothing to act
   on:
   - **A request to open**: for each slice whose remote ref equals its recorded commit
     (`remote_matches_recorded=yes`) and that has no `request_url` yet, show base, head, and
     title, and offer to open it. "Yes" runs STEP 7 for that slice; the URL is recorded in the
     series file afterward.
   - **A merged marking**: for each slice `status` reports `merged=yes`, mark its `state` as
     `merged` in the series document (a content test result, so a squash merge is recognised —
     no question needed, this is a factual update).
   - **A rebuild due**: for each slice `status` reports `rebuild_due=yes`, re-run `build` for
     that slice's series (re-derive, never rebase — a fresh overlay against the current base,
     never a restack or a three-way merge) and print the push line again: a plain
     `/please push <remote> slice/<series_id>/<id>` if it was never pushed, or
     `/please push <remote> slice/<series_id>/<id> --force-with-lease` if it was.
   - **A stale target**: if the target is no longer an ancestor of the work ref, print one line
     naming the merge-up needed and nothing else — `/slice` never merges and performs no further
     action in this series until the operator (or an ordinary task, in a repository that
     declares `integration_branch`) makes that merge on the work branch.

**STOP** after printing what is due; nothing here pushes or opens anything the operator did not
just say "yes" to.

---

### STEP 7: The open step — the only place a forge call appears

**EXECUTE NOW**, only for a slice the operator just said "yes" to opening (from STEP 6, or
immediately after a STEP 5 build if the operator says so in the same invocation — never
automatically):

1. Detect the platform the same way `/merge` does.
2. For GitHub: `gh pr create --base <target> --head slice/<series_id>/<id> --title "<title>" --body-file specs/.orchestration/slices/<series_id>/<id>.md`.
   For GitLab: `glab mr create --target-branch <target> --source-branch slice/<series_id>/<id> --title "<title>" --description "$(cat specs/.orchestration/slices/<series_id>/<id>.md)"`.
3. On success, extract the URL and record it as that slice's `request_url` in the series
   document, and set its `state` to `open`.
4. On failure, print the CLI's error verbatim and leave the series document untouched for that
   slice — the operator can retry `/slice` once the underlying problem (auth, an unpushed ref,
   an existing request) is fixed.

This is the **only** step in this command, the script, or anywhere else in this record that
calls a forge CLI. Nothing upstream of here ever does.

---

## The visible stack and re-derive, never rebase

The default order of opening builds and opens a dependent slice only after its one dependency
has merged — under this default every slice is one commit on the target's tip, pushed once, and
never force-pushed. A **visible stack** (opening a dependent slice early, against its one
unmerged dependency's own branch) is allowed only when asked for in "revise" at STEP 4; its cost
is stated in the cost line before approval — after the dependency merges, every already-pushed
dependent is rebuilt on the new base and needs one further typed `--force-with-lease` push
(STEP 6's rebuild-due handling).

**Re-derive, never rebase.** Every rebuild in this command (STEP 6) is a fresh overlay against
the then-current base. There is no restack operation, no three-way merge of slice commits, and
no conflict resolution performed anywhere in this command. A conflict between the target and the
work ref is resolved once, by an ordinary merge of the target into the work branch, which this
command waits for and never performs itself.

## One invocation, one target

A series never spans two targets, because the bar, the ancestry test, and the exhaustiveness
check (STEP 4's `check` run) are all facts about one target. Work bound for a second target is a
second series, started by a second `/slice` invocation choosing a different target at STEP 2.

---

## Agent Restrictions

This command MUST NOT be invoked by any agent, skill, or lifecycle script. It appears in no
skill-to-agent mapping, and no automated dispatch path names it. `scripts/slice-series.sh`
itself contains no push, checkout, merge, or forge invocation (its own suite asserts this
statically) — every irreversible or outward-facing action in this whole mechanism (the push the
operator types via `/please`, and the forge call in STEP 7) happens only on this command's own,
user-typed invocation, never autonomously.

## Related Commands

- `/please` — authorizes the one push each built slice needs, one typed line at a time.
- `/merge` — the unrelated, whole-branch pull-request path this command does not replace for a
  branch that is not being sliced.
