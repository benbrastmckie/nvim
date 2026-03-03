# Self-Healing Implementation Details

**Version**: 1.0.0
**Purpose**: Detailed implementation reference for self-healing infrastructure
**Audience**: Developers debugging or extending self-healing functionality
**Last Updated**: 2025-12-27

---

## Overview

This document contains detailed implementation pseudocode, data extraction functions, and testing scenarios for the self-healing infrastructure. For user-facing documentation, see:

- **Quick Reference**: `.opencode/context/core/system/self-healing-guide.md`
- **Schema Reference**: `.opencode/context/core/system/state-schema.md`

---

## Data Extraction Functions

### Extract Active Projects from specs/TODO.md

```python
def extract_active_projects(todo_data):
    """Extract active projects from parsed specs/TODO.md"""
    
    active_statuses = ["IN PROGRESS", "PLANNED", "RESEARCHED", "BLOCKED", "IMPLEMENTING", "RESEARCHING", "PLANNING"]
    active_projects = []
    
    for task in todo_data["tasks"]:
        if task["status"] in active_statuses:
            project = {
                "project_number": task["number"],
                "project_name": slugify(task["title"]),
                "type": infer_project_type(task),
                "phase": infer_project_phase(task),
                "status": task["status"].lower().replace(" ", "_"),
                "priority": task.get("priority", "medium").lower(),
                "language": task.get("language", "general").lower(),
                "created": task.get("created", current_date()),
                "last_updated": task.get("last_updated", current_date())
            }
            
            # Add optional fields
            if task.get("started"):
                project["started"] = task["started"]
            if task.get("plan"):
                project["plan_path"] = task["plan"]
            if task.get("research_completed"):
                project["research_completed"] = task["research_completed"]
            if task["status"] in ["BLOCKED"] and task.get("blocking_reason"):
                project["blocked"] = current_date()
                project["blocking_reason"] = task["blocking_reason"]
            
            active_projects.append(project)
    
    return active_projects
```

### Extract Completed Projects

```python
def extract_completed_projects(todo_data):
    """Extract completed projects from parsed specs/TODO.md"""
    
    completed = []
    
    for task in todo_data["tasks"]:
        if task["status"] == "COMPLETED":
            project = {
                "project_number": task["number"],
                "project_name": slugify(task["title"]),
                "type": infer_project_type(task),
                "completed": task.get("completed", current_date()),
                "summary": task.get("description", task["title"])[:200]  # First 200 chars
            }
            completed.append(project)
    
    return completed
```

### Calculate Health Metrics

```python
def calculate_health_metrics(todo_data):
    """Calculate repository health metrics from specs/TODO.md"""
    
    status_counts = count_by_status(todo_data)
    priority_counts = count_by_priority(todo_data)
    
    # Calculate overall health score (0-100)
    # Higher is better: many completed, few blocked, progress being made
    total_tasks = len(todo_data["tasks"])
    completed = status_counts.get("COMPLETED", 0)
    blocked = status_counts.get("BLOCKED", 0)
    in_progress = status_counts.get("IN PROGRESS", 0) + status_counts.get("IMPLEMENTING", 0)
    
    if total_tasks == 0:
        overall_score = 0
    else:
        # Formula: (completed + in_progress) / total - (blocked penalty)
        progress_score = ((completed + in_progress) / total_tasks) * 100
        blocked_penalty = (blocked / total_tasks) * 20 if blocked > 0 else 0
        overall_score = max(0, min(100, progress_score - blocked_penalty))
    
    # Infer production readiness
    if overall_score >= 90:
        readiness = "excellent"
    elif overall_score >= 75:
        readiness = "good"
    elif overall_score >= 50:
        readiness = "fair"
    else:
        readiness = "needs-work"
    
    return {
        "last_assessed": current_timestamp(),
        "overall_score": round(overall_score),
        "active_tasks": total_tasks,
        "completed_tasks": status_counts.get("COMPLETED", 0),
        "blocked_tasks": status_counts.get("BLOCKED", 0),
        "in_progress_tasks": status_counts.get("IN PROGRESS", 0) + status_counts.get("IMPLEMENTING", 0),
        "not_started_tasks": status_counts.get("NOT STARTED", 0),
        "high_priority_tasks": priority_counts.get("high", 0),
        "medium_priority_tasks": priority_counts.get("medium", 0),
        "low_priority_tasks": priority_counts.get("low", 0),
        "production_readiness": readiness,
        "technical_debt": {
            "sorry_count": 0,  # Would need to scan files
            "build_errors": 0,  # Would need build check
            "status": "unknown"
        }
    }
```

### Helper Functions

```python
def slugify(title):
    """Convert task title to slug format"""
    # Remove special characters, lowercase, replace spaces with underscores
    slug = title.lower()
    slug = re.sub(r'[^\w\s-]', '', slug)
    slug = re.sub(r'[\s_-]+', '_', slug)
    return slug[:50]  # Limit length

def infer_project_type(task):
    """Infer project type from task title and description"""
    title_lower = task["title"].lower()
    
    if any(word in title_lower for word in ["fix", "bug", "error", "broken"]):
        return "bugfix"
    elif any(word in title_lower for word in ["add", "implement", "create", "new"]):
        return "feature"
    elif any(word in title_lower for word in ["improve", "enhance", "refactor", "optimize"]):
        return "enhancement"
    elif any(word in title_lower for word in ["document", "docs", "guide"]):
        return "documentation"
    elif any(word in title_lower for word in ["test", "coverage"]):
        return "testing"
    else:
        return "general"

def infer_project_phase(task):
    """Infer project phase from status"""
    status = task["status"]
    
    phase_map = {
        "NOT STARTED": "not_started",
        "RESEARCHING": "research",
        "RESEARCHED": "research_completed",
        "PLANNING": "planning",
        "PLANNED": "planning_completed",
        "IMPLEMENTING": "implementation",
        "IN PROGRESS": "implementation",
        "COMPLETED": "completed",
        "BLOCKED": "blocked",
        "ABANDONED": "abandoned"
    }
    
    return phase_map.get(status, "unknown")

def count_by_status(todo_data):
    """Count tasks by status"""
    counts = {}
    for task in todo_data["tasks"]:
        status = task["status"]
        counts[status] = counts.get(status, 0) + 1
    return counts

def count_by_priority(todo_data):
    """Count tasks by priority"""
    counts = {}
    for task in todo_data["tasks"]:
        priority = task.get("priority", "medium").lower()
        counts[priority] = counts.get(priority, 0) + 1
    return counts
```

---

## Detailed Self-Healing Pseudo-Code

### Main Self-Healing Function

```python
def ensure_state_json():
    """
    Ensure specs/state.json exists, auto-create if missing
    
    This function is called by commands in their preflight stage.
    It implements the core self-healing logic for specs/state.json.
    """
    
    state_path = "specs/state.json"
    
    # Check if file exists
    if file_exists(state_path):
        # File exists, validate it
        try:
            state = read_json(state_path)
            validate_state_schema(state)
            return state_path
        except Exception as e:
            log_warning(f"specs/state.json exists but invalid: {e}")
            # Fall through to auto-creation
    
    # Self-healing: Auto-create from template
    log_info("Self-healing: specs/state.json missing or invalid, creating from template")
    
    # 1. Load template
    template_path = ".opencode/context/core/templates/state-template.json"
    if not file_exists(template_path):
        log_error("Self-healing failed: Template missing")
        return create_minimal_state()  # Fallback
    
    try:
        template = read_json(template_path)
    except Exception as e:
        log_error(f"Self-healing failed: Template invalid: {e}")
        return create_minimal_state()  # Fallback
    
    # 2. Gather data from specs/TODO.md
    todo_path = "specs/TODO.md"
    if not file_exists(todo_path):
        log_error("Cannot auto-create specs/state.json: specs/TODO.md missing")
        raise FileNotFoundError(
            "Required file specs/TODO.md not found. "
            "Self-healing can only create specs/state.json when specs/TODO.md exists."
        )
    
    try:
        todo_data = parse_todo_md(todo_path)
    except Exception as e:
        log_error(f"Failed to parse specs/TODO.md: {e}")
        raise ValueError(f"specs/TODO.md exists but cannot be parsed: {e}")
    
    # 3. Populate template
    state = populate_state_from_template(template, todo_data)
    
    # 4. Write atomically
    try:
        write_json_atomic(state_path, state)
    except Exception as e:
        log_error(f"Failed to write specs/state.json: {e}")
        raise IOError(f"Could not write {state_path}: {e}")
    
    log_info(f"Self-healing: Created {state_path} successfully")
    log_info(f"  - Initialized from specs/TODO.md ({len(todo_data['tasks'])} tasks)")
    log_info(f"  - Next project number: {state['next_project_number']}")
    
    return state_path

def populate_state_from_template(template, todo_data):
    """Populate state template with data from specs/TODO.md"""
    
    highest_task = max(task["number"] for task in todo_data["tasks"])
    
    state = {
        "_schema_version": template["_schema_version"],
        "_comment": f"Auto-created with self-healing on {current_date()}",
        "_last_updated": current_timestamp(),
        "next_project_number": highest_task + 1,
        "project_numbering": template["project_numbering"],
        "state_references": template["state_references"],
        "active_projects": extract_active_projects(todo_data),
        "completed_projects": extract_completed_projects(todo_data),
        "repository_health": calculate_health_metrics(todo_data),
        "recent_activities": [
            {
                "timestamp": current_timestamp(),
                "activity": f"Auto-created specs/state.json with self-healing - initialized from specs/TODO.md ({len(todo_data['tasks'])} tasks, {highest_task + 1} next number)"
            }
        ],
        "pending_tasks": extract_pending_tasks(todo_data),
        "reviews_summary": template["reviews_summary"],
        "archive_summary": template["archive_summary"],
        "schema_info": {
            **template["schema_info"],
            "self_healing_enabled": True
        }
    }
    
    return state

def extract_pending_tasks(todo_data):
    """Extract pending (high priority NOT STARTED) tasks"""
    
    pending = []
    
    for task in todo_data["tasks"]:
        if task["status"] == "NOT STARTED" and task.get("priority") == "high":
            pending.append({
                "project_number": task["number"],
                "title": task["title"],
                "status": "not_started",
                "priority": "high",
                "language": task.get("language", "general").lower()
            })
    
    return pending[:10]  # Limit to top 10
```

### Minimal Fallback (When Template Missing)

```python
def create_minimal_state():
    """
    Create minimal specs/state.json when template unavailable
    
    This is a fallback for when the template file is missing or invalid.
    It creates a minimal but functional specs/state.json.
    """
    
    minimal_state = {
        "_schema_version": "1.0.0",
        "_comment": "Minimal fallback state - template unavailable",
        "_last_updated": current_timestamp(),
        "next_project_number": 1,
        "project_numbering": {
            "min": 0,
            "max": 999,
            "policy": "increment_modulo_1000",
            "_comment": "Project numbers wrap around to 000 after 999. Ensure old projects are archived before reuse."
        },
        "state_references": {
            "archive_state_path": "specs/specs/archive/state.json",
            "_comment": "References to specialized state files. These files are auto-created if missing."
        },
        "active_projects": [],
        "completed_projects": [],
        "repository_health": {
            "last_assessed": current_timestamp(),
            "overall_score": 0,
            "active_tasks": 0,
            "production_readiness": "unknown",
            "technical_debt": {
                "sorry_count": 0,
                "build_errors": 0,
                "status": "unknown"
            }
        },
        "recent_activities": [
            {
                "timestamp": current_timestamp(),
                "activity": "Created minimal specs/state.json - template unavailable (degraded mode)"
            }
        ],
        "pending_tasks": [],
        "reviews_summary": {
            "_comment": "Quick reference to review status - full history in reviews/state.json",
            "last_review": None,
            "total_reviews": 0,
            "total_issues_found": 0
        },
        "archive_summary": {
            "_comment": "Quick reference to archived projects - full details in specs/archive/state.json",
            "archive_location": "specs/archive/",
            "archive_state_file": "specs/specs/archive/state.json"
        },
        "schema_info": {
            "version": "1.0.0",
            "backward_compatible": True,
            "extensible": True,
            "self_healing_enabled": True,
            "degraded_mode": True,
            "_comment": "Operating in degraded mode due to missing template"
        }
    }
    
    try:
        write_json_atomic("specs/state.json", minimal_state)
        log_warning("Self-healing: Created minimal specs/state.json (degraded mode)")
        log_warning("  - Template file missing, using fallback minimal structure")
        log_warning("  - To restore full functionality, restore template from git:")
        log_warning("    git checkout HEAD -- .opencode/context/core/templates/state-template.json")
    except Exception as e:
        log_error(f"Critical: Cannot create even minimal specs/state.json: {e}")
        raise IOError(f"Self-healing completely failed: {e}")
    
    return "specs/state.json"
```

---

## Testing Scenarios

### Test Case 1: Missing specs/state.json (Normal Case)

```bash
# Setup: Remove specs/state.json
rm specs/state.json

# Execute: Run any command
/research 197

# Expected behavior:
# 1. Command detects missing specs/state.json in preflight
# 2. Calls ensure_state_json()
# 3. Loads template from .opencode/context/core/templates/state-template.json
# 4. Parses specs/TODO.md (must exist)
# 5. Extracts task data (37 tasks found)
# 6. Populates template fields
# 7. Writes specs/state.json atomically
# 8. Logs: "Self-healing: Created specs/state.json from template"
# 9. Command continues normally

# Verification:
cat specs/state.json | jq '._comment'
# Should show: "Auto-created with self-healing on 2025-12-27"

cat specs/state.json | jq '.next_project_number'
# Should show: 200 (one more than highest task in specs/TODO.md)

cat specs/state.json | jq '.recent_activities[0].activity'
# Should show: "Auto-created specs/state.json..."
```

### Test Case 2: Missing Template (Degraded Mode)

```bash
# Setup: Remove template file
mv .opencode/context/core/templates/state-template.json \
   .opencode/context/core/templates/state-template.json.backup

# Execute: Run command
/research 197

# Expected behavior:
# 1. Command detects missing specs/state.json
# 2. Calls ensure_state_json()
# 3. Attempts to load template - fails
# 4. Falls back to create_minimal_state()
# 5. Creates minimal but functional specs/state.json
# 6. Logs warning: "Created minimal specs/state.json (degraded mode)"
# 7. Command continues in degraded mode

# Verification:
cat specs/state.json | jq '.schema_info.degraded_mode'
# Should show: true

cat specs/state.json | jq '.active_projects | length'
# Should show: 0 (minimal state has empty arrays)

# Cleanup: Restore template
mv .opencode/context/core/templates/state-template.json.backup \
   .opencode/context/core/templates/state-template.json
```

### Test Case 3: Missing specs/TODO.md (Failure)

```bash
# Setup: Remove specs/TODO.md
mv specs/TODO.md specs/TODO.md.backup

# Execute: Run command
/research 197

# Expected behavior:
# 1. Command detects missing specs/state.json
# 2. Calls ensure_state_json()
# 3. Loads template successfully
# 4. Attempts to load specs/TODO.md - fails
# 5. Raises FileNotFoundError with clear message
# 6. Command fails with actionable error

# Expected error:
# Error: Required file specs/TODO.md not found
# Self-healing can only create specs/state.json when specs/TODO.md exists.
#
# Recovery steps:
# 1. Restore specs/TODO.md from git: git checkout HEAD -- specs/TODO.md
# 2. Or restore from backup
# 3. Retry command

# Cleanup: Restore specs/TODO.md
mv specs/TODO.md.backup specs/TODO.md
```

### Test Case 4: Corrupted specs/state.json (Re-Creation)

```bash
# Setup: Corrupt specs/state.json
echo "{ invalid json }" > specs/state.json

# Execute: Run command
/research 197

# Expected behavior:
# 1. Command attempts to load specs/state.json
# 2. JSON parsing fails
# 3. Falls back to auto-creation
# 4. Creates fresh specs/state.json from template
# 5. Logs warning about corruption
# 6. Command continues normally

# Verification:
cat specs/state.json | jq '._schema_version'
# Should show: "1.0.0" (valid JSON)
```

### Test Case 5: Normal Operation (No Self-Healing)

```bash
# Setup: specs/state.json exists and valid
# (No setup needed, this is the normal case)

# Execute: Run command
/research 197

# Expected behavior:
# 1. Command loads specs/state.json successfully
# 2. No self-healing triggered
# 3. No extra logging
# 4. Command proceeds normally
# 5. Performance is optimal (no template loading)

# Verification:
# Check that recent_activities does NOT have a new self-healing entry
cat specs/state.json | jq '.recent_activities[0].activity'
# Should NOT show "Auto-created" message
```

---

## Logging Examples

### Successful Auto-Creation

```
[INFO] Self-healing: specs/state.json missing, creating from template
[INFO] Self-healing: Loaded template from .opencode/context/core/templates/state-template.json
[INFO] Self-healing: Parsed specs/TODO.md successfully (37 tasks found)
[INFO] Self-healing: Extracted 4 active projects, 2 completed projects
[INFO] Self-healing: Calculated repository health (score: 85)
[INFO] Self-healing: Created specs/state.json successfully
[INFO]   - Initialized from specs/TODO.md (37 tasks)
[INFO]   - Next project number: 200
```

### Degraded Mode Fallback

```
[WARN] Self-healing: specs/state.json missing, creating from template
[ERROR] Self-healing failed: Template missing
[WARN] Self-healing: Falling back to minimal state creation
[WARN] Self-healing: Created minimal specs/state.json (degraded mode)
[WARN]   - Template file missing, using fallback minimal structure
[WARN]   - To restore full functionality, restore template from git:
[WARN]     git checkout HEAD -- .opencode/context/core/templates/state-template.json
```

### Failed Self-Healing

```
[WARN] Self-healing: specs/state.json missing, creating from template
[INFO] Self-healing: Loaded template from .opencode/context/core/templates/state-template.json
[ERROR] Cannot auto-create specs/state.json: specs/TODO.md missing
[ERROR] Required file specs/TODO.md not found. Self-healing can only create specs/state.json when specs/TODO.md exists.

Error: Required file not found

Recovery steps:
1. Restore specs/TODO.md from git:
   git checkout HEAD -- specs/TODO.md

2. Or restore from backup if available

3. Create new specs/TODO.md following the standard format
   Template: .opencode/context/core/templates/todo-template.md
```

---

## Related Documentation

- **Quick Reference**: `.opencode/context/core/system/self-healing-guide.md`
- **Schema Reference**: `.opencode/context/core/system/state-schema.md`
- **Context Organization**: `.opencode/context/core/system/context-guide.md`
- **Template**: `.opencode/context/core/templates/state-template.json`
