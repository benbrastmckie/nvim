# Workflow Diagrams Reference

Process diagrams for research, planning, and implementation workflows. For behavioral rules (command lifecycle), see `.claude/rules/workflows.md`.

## Research Workflow

```
/research N [focus]
    |
    v
+-----------------+
| Validate task   |
| exists, status  |
| allows research |
+--------+--------+
         |
         v
+-----------------+
| Update status   |
| [RESEARCHING]   |
+--------+--------+
         |
         v
+-----------------+
| Route by type   |
| ext->ext-agent  |
| core->core-agent|
+--------+--------+
         |
         v
+-----------------+
| Create report   |
| MM_{slug}.md    |
+--------+--------+
         |
         v
+-----------------+
| Update status   |
| [RESEARCHED]    |
+--------+--------+
         |
         v
+-----------------+
| Git commit      |
+-----------------+
```

## Planning Workflow

```
/plan N
    |
    v
+-----------------+
| Load research   |
| and task desc   |
+--------+--------+
         |
         v
+-----------------+
| Update status   |
| [PLANNING]      |
+--------+--------+
         |
         v
+-----------------+
| Create phases   |
| with steps      |
+--------+--------+
         |
         v
+-----------------+
| Write plan file |
| MM_{slug}.md    |
+--------+--------+
         |
         v
+-----------------+
| Update status   |
| [PLANNED]       |
+--------+--------+
         |
         v
+-----------------+
| Git commit      |
+-----------------+
```

## Implementation Workflow

```
/implement N
    |
    v
+-----------------+
| Load plan,      |
| find resume pt  |
+--------+--------+
         |
         v
+-----------------+
| Update status   |
| [IMPLEMENTING]  |
+--------+--------+
         |
         v
+-----------------+
| For each phase: |
| +-------------+ |
| | Mark IN     | |
| | PROGRESS    | |
| +-------------+ |
| | Execute     | |
| | steps       | |
| +-------------+ |
| | Mark        | |
| | COMPLETED   | |
| +-------------+ |
| | Git commit  | |
| | phase       | |
| +-------------+ |
+--------+--------+
         |
         v
+-----------------+
| Create summary  |
+--------+--------+
         |
         v
+-----------------+
| Update status   |
| [COMPLETED]     |
+--------+--------+
         |
         v
+-----------------+
| Final commit    |
+-----------------+
```

## Resume Pattern

For interrupted implementations:

```
/implement N (resumed)
    |
    v
+-----------------+
| Load plan       |
+--------+--------+
         |
         v
+-----------------+
| Scan phases:    |
| [COMPLETED] -> Y|
| [PARTIAL] -> <--| Resume here
| [NOT STARTED]   |
+--------+--------+
         |
         v
+-----------------+
| Continue from   |
| resume point    |
+-----------------+
```

## Error Recovery

```
On error during phase:
    |
    v
+-----------------+
| Keep phase      |
| [IN PROGRESS]   |
+--------+--------+
         |
         v
+-----------------+
| Log error       |
| to errors.json  |
+--------+--------+
         |
         v
+-----------------+
| Commit partial  |
| progress        |
+--------+--------+
         |
         v
+-----------------+
| Return partial  |
| with resume     |
| info            |
+-----------------+
```
