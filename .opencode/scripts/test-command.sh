Testing .opencode command execution system.

Test command: /task --abandon 671

Expected behavior:
- Command should be routed through execute-command.sh
- Should read command definition from .opencode/commands/task.md
- Should execute abandon logic for task 671
- Should NOT try to execute "poetry run python src/main.py"

Actual result test pending.