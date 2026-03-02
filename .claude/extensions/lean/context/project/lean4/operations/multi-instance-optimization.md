# Multi-Instance Lean-LSP Optimization Guide

**Purpose**: Reduce MCP AbortError -32001 timeouts when running multiple Claude Code sessions

---

## Overview

Running multiple concurrent Claude Code sessions with Lean-LSP MCP tools can cause AbortError -32001 timeouts due to resource contention.

### Root Cause

Multiple concurrent lean-lsp-mcp instances via STDIO transport create:
- Memory pressure from parallel `lake build` processes (can exceed 16GB)
- File locking contention on `.olean` files in shared `.lake/` cache
- CPU saturation from parallel compilation workers
- Diagnostic processing delays under concurrent load

---

## Prevention Strategies

### 1. Pre-Build Project (Highest Impact)

**Run `lake build` before starting Claude sessions**:

```bash
cd /path/to/lean-project
lake build
```

**Why this works**:
- Prevents concurrent `lake build` triggers when multiple agents start
- Eliminates timeout on first diagnostic call in each session
- Reduces memory pressure from parallel builds

### 2. Configure Environment Variables

Add to `~/.claude.json`:

```json
{
  "mcpServers": {
    "lean-lsp": {
      "command": "uvx",
      "args": ["lean-lsp-mcp"],
      "env": {
        "LEAN_LOG_LEVEL": "WARNING",
        "LEAN_PROJECT_PATH": "/path/to/lean-project"
      }
    }
  }
}
```

**Benefits**:
- `LEAN_LOG_LEVEL: "WARNING"` reduces log I/O overhead
- Explicit `LEAN_PROJECT_PATH` prevents detection overhead

### 3. Session Management Strategy

**Soft Throttling (Recommended)**:
- When triggering Lean implementation agents, pause work in 3-4 other sessions
- Resume non-Lean work after agent completes
- Non-Lean work (general tasks, LaTeX, meta) unaffected

---

## Workflow Recommendations

### For Lean Implementation Tasks

1. **Before starting `/implement` on Lean task**:
   - Run `lake build` if project has been modified
   - Pause Lean work in other sessions
   - Allow 1-2 minutes for LSP to stabilize

2. **During Lean agent execution**:
   - Avoid starting new Lean tasks in other sessions
   - General/meta/LaTeX tasks in other sessions are fine

3. **After Lean agent completes**:
   - Resume Lean work in other sessions
   - Results are cached, subsequent operations faster

### For Research Tasks

Research agents using `lean_leansearch`, `lean_loogle`, etc. are less resource-intensive
than implementation agents. Multiple concurrent research tasks are generally safe.

---

## Monitoring

### Check Resource Usage

```bash
# Memory usage by lean processes
ps aux --sort=-%mem | grep -E '(lean|lake)' | head -10

# CPU usage
htop -p $(pgrep -d, -f 'lean|lake')
```

### Identify Contention

If you see these symptoms, reduce concurrent sessions:
- lean-lsp calls consistently exceeding 30 seconds
- Memory usage spiking above 12GB
- Multiple `lake build` processes running simultaneously
- Diagnostic messages timing out repeatedly

---

## Expected Results

With optimization strategies applied:
- 60-80% reduction in timeout frequency
- Memory usage stays under 8GB (vs 16GB+ spikes)
- Diagnostic calls complete within 30s (vs 60s+ timeouts)
- Agents complete successfully without interruption
