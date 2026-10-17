---
description: Collaborative design consultation with domain expert perspective
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Bash(mkdir:*), Bash(sed:*), Bash(od:*), Bash(tr:*), Read, Edit, AskUserQuestion
argument-hint: --legal [file_path|"text"|design question]
---

# /consult Command

Collaborative design consultation command that routes to domain-specific design partner agents.

## Overview

This command initiates a collaborative consultation where a design partner agent helps the user describe their product in language that domain professionals recognize. Unlike review or critique commands, `/consult` uses Socratic dialogue to understand user intent and suggest reframings -- it is collaborative, not adversarial.

Every `/consult` invocation automatically creates a task entry in state.json and TODO.md for artifact tracking. The consultation report is always stored in the task directory. To attach to an existing task instead, pass the task number after the domain flag.

## Syntax

- `/consult --legal /path/to/document.typ` - Review document from attorney perspective (auto-creates task)
- `/consult --legal "product description text"` - Analyze inline text from attorney perspective (auto-creates task)
- `/consult --legal How should I describe formal verification to attorneys?` - Design question dialogue (auto-creates task)
- `/consult --legal 458` - Attach consultation to existing task 458 (artifacts stored in task directory) <!-- task-ref-ok inline, command-usage example -->

## Domain Flags

| Flag | Agent | Domain | Status |
|------|-------|--------|--------|
| `--legal` | legal-analysis-agent | Attorney perspective on legal AI product descriptions | Available |
| `--investor` | (future) | Investor perspective on pitch materials | Planned |
| `--technical` | (future) | Technical architecture review | Planned |
| `--competitor` | (future) | Competitive positioning review | Planned |

**Note**: Only `--legal` is implemented. Other flags are documented for future extensibility.

## Input Types

| Input | Behavior |
|-------|----------|
| File path (after flag) | Read file as document for translation analysis; auto-creates task |
| Quoted string (after flag) | Treat as inline product description snippet; auto-creates task |
| Task number (after flag) | Attach consultation to existing task, store artifacts in task directory |
| Bare text (after flag) | Treat as design question for Socratic dialogue; auto-creates task |

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Consult] Collaborative Design Consultation
```

### Step 1: Generate Session ID

```bash
source .claude/scripts/lib/common.sh
session_id="$(common_session_id)"
```

### Step 2: Parse Flag and Input

```bash
# Extract domain flag
if echo "$ARGUMENTS" | grep -qE '^--legal'; then
  domain="legal"
  args=$(echo "$ARGUMENTS" | sed 's/^--legal *//')
elif echo "$ARGUMENTS" | grep -qE '^--investor'; then
  echo "Error: --investor flag is not yet implemented"
  exit 1
elif echo "$ARGUMENTS" | grep -qE '^--technical'; then
  echo "Error: --technical flag is not yet implemented"
  exit 1
elif echo "$ARGUMENTS" | grep -qE '^--competitor'; then
  echo "Error: --competitor flag is not yet implemented"
  exit 1
else
  echo "Error: Domain flag required. Use --legal, e.g.: /consult --legal /path/to/document.md"
  exit 1
fi
```

### Step 3: Detect Input Type

```bash
# Check for task number
if echo "$args" | grep -qE '^[0-9]+$'; then
  input_type="task_number"
  task_number="$args"

# Check for file path
elif echo "$args" | grep -qE '^\.|^/|^~|\.md$|\.txt$|\.typ$|\.pdf$'; then
  input_type="file_path"
  file_path=$(eval echo "$args")
  if [ ! -f "$file_path" ]; then
    echo "Error: File not found: $file_path"
    exit 1
  fi

# Check for quoted string
elif echo "$args" | grep -qE '^".*"$'; then
  input_type="inline_text"
  inline_text=$(echo "$args" | sed 's/^"//;s/"$//')

# Default: bare text is a design question
else
  input_type="design_question"
  design_question="$args"
fi
```

### Step 4: Create or Resolve Task

```bash
if [ "$input_type" = "task_number" ]; then
  # Existing task path: resolve from state.json (unchanged)
  task_data=$(jq -r --argjson num "$task_number" \
    '.active_projects[] | select(.project_number == $num)' \
    specs/state.json)

  if [ -z "$task_data" ]; then
    echo "Error: Task $task_number not found"
    exit 1
  fi

  project_name=$(echo "$task_data" | jq -r '.project_name')
  description=$(echo "$task_data" | jq -r '.description // ""')

else
  # Auto-create path: generate task for this consultation

  # 1. Read next project number
  next_num=$(jq -r '.next_project_number' specs/state.json)

  # 2. Generate slug from input (consult_{domain}_{slugified input})
  if [ "$input_type" = "file_path" ]; then
    slug_input=$(basename "$file_path" | sed 's/\.[^.]*$//')
  elif [ "$input_type" = "inline_text" ]; then
    slug_input="$inline_text"
  else
    slug_input="$design_question"
  fi
  input_slug=$(echo "$slug_input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//' | sed 's/ /_/g' | cut -c1-35)
  task_slug="consult_${domain}_${input_slug}"
  task_slug=$(echo "$task_slug" | cut -c1-50)

  # 3. Generate description
  if [ "$input_type" = "file_path" ]; then
    description="Legal design consultation: $(basename "$file_path")"
  elif [ "$input_type" = "inline_text" ]; then
    desc_short=$(echo "$inline_text" | cut -c1-60)
    description="Legal design consultation: ${desc_short}"
  else
    desc_short=$(echo "$design_question" | cut -c1-60)
    description="Legal design consultation: ${desc_short}"
  fi

  # 4. Update state.json: increment next_project_number, prepend entry
  mkdir -p specs/tmp
  new_num=$((next_num + 1))
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  bash .claude/scripts/state-write.sh \
    '.next_project_number = $new_num |
     .active_projects = [{
       "project_number": $num,
       "project_name": $name,
       "status": "not_started",
       "task_type": "founder",
       "description": $desc,
       "created": $ts,
       "last_updated": $ts
     }] + .active_projects' \
     --session-id "$session_id" \
     --arg ts "$ts" \
     --arg name "$task_slug" \
     --arg desc "$description" \
     --argjson num "$next_num" \
     --argjson new_num "$new_num"

  # 5. Update TODO.md frontmatter: increment next_project_number
  sed -i "s/^next_project_number: ${next_num}$/next_project_number: ${new_num}/" specs/TODO.md

  # 6. Prepend task entry to TODO.md after "## Tasks" line
  padded_num=$(printf "%03d" "$next_num")
  task_entry="- **[${next_num}]** \`${task_slug}\` [NOT STARTED] — ${description}"
  sed -i "/^## Tasks/a ${task_entry}" specs/TODO.md

  # 7. Set task_number for downstream use
  task_number="$next_num"
fi
```

---

## STAGE 2: DELEGATE

Route to the appropriate design partner agent based on domain flag.

### Legal Domain (--legal)

Invoke skill-consult with legal routing:

```
skill: "skill-consult"
args: "domain=legal input_type={input_type} file_path={file_path} inline_text={inline_text} design_question={design_question} task_number={task_number} session_id={session_id}"
```

The skill-consult wrapper will:
1. Spawn legal-analysis-agent via Agent tool
2. Pass delegation context including input type and content
3. Agent conducts Socratic dialogue and produces consultation report
4. Skill handles postflight (artifact linking)

---

## CHECKPOINT 2: GATE OUT

### Step 1: Display Result

```
Legal design consultation complete.

Task: #{task_number} — {task_slug}
Input: {file path or description}
Translation gaps found: {N}
Consultation report: {report_path}

Next: /orchestrate {task_number}

Advisory: This consultation models attorney thinking but does not replace attorney review.
Recommend professional review for materials targeting legal professionals in high-stakes contexts.
```

### Step 2: Git Commit

Apply targeted staging per `.claude/context/standards/git-staging-scope.md` — never a repo-wide
add:

```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: legal design consultation" \
  --session "${session_id}" \
  --honest-index-rows "${task_number}" \
  -- "specs/${padded_num}_${task_slug}/" "specs/TODO.md" "specs/state.json"
```

---

## Error Handling

### Missing Domain Flag

```
Error: Domain flag required.
Usage: /consult --legal [file_path|"text"|design question]

Available domains: --legal
Coming soon: --investor, --technical, --competitor
```

### File Not Found

```
Error: File not found: {path}
Verify the file path and try again.
```

### Unimplemented Domain

```
Error: --{domain} flag is not yet implemented.
Currently available: --legal
```

### Task Creation Failure

```
Error: Failed to create task entry. Check that specs/state.json is valid JSON.
```

---

## Examples

```bash
# Review a product document from attorney perspective (auto-creates task)
/consult --legal ~/Projects/Logos/Vision/shared/strategy/legal-ai-example.typ

# Analyze a product description snippet (auto-creates task)
/consult --legal "Logos formally verifies all legal reasoning and discovers concealment patterns"

# Ask a design question (auto-creates task)
/consult --legal How should I describe formal verification to litigation partners?

# Attach consultation to an existing task
/consult --legal 458
```
