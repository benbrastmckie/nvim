# Semantic Evaluation Patterns

Tree-walking evaluation patterns for Python interpreters and evaluators.

## Core Concept: Tree-Walking Evaluation

Tree-walking evaluators traverse an abstract syntax tree (AST) and compute results at each node. This pattern is common in interpreters, compilers, and semantic analyzers.

```
Traditional: evaluate(node) -> value
Recursive:   evaluate(node) -> evaluate(children) -> combine
```

## Basic Evaluator Structure

```python
from abc import ABC, abstractmethod
from typing import Any, Dict, Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from .ast import ASTNode


class Evaluator(ABC):
    """Base class for tree-walking evaluators."""

    def __init__(self, context: Optional[Dict[str, Any]] = None):
        self.context = context or {}

    def evaluate(self, node: "ASTNode") -> Any:
        """Evaluate an AST node."""
        method_name = f'eval_{node.type}'
        method = getattr(self, method_name, self.eval_default)
        return method(node)

    def eval_default(self, node: "ASTNode") -> Any:
        """Default handler for unknown node types."""
        raise NotImplementedError(f"Unknown node type: {node.type}")
```

## Node-Specific Handlers

```python
class ExpressionEvaluator(Evaluator):
    """Evaluator for expression AST."""

    def eval_number(self, node):
        """Evaluate number literal."""
        return node.value

    def eval_string(self, node):
        """Evaluate string literal."""
        return node.value

    def eval_identifier(self, node):
        """Evaluate identifier (variable lookup)."""
        name = node.name
        if name not in self.context:
            raise NameError(f"Undefined variable: {name}")
        return self.context[name]

    def eval_binary_op(self, node):
        """Evaluate binary operation."""
        left = self.evaluate(node.left)
        right = self.evaluate(node.right)

        ops = {
            '+': lambda a, b: a + b,
            '-': lambda a, b: a - b,
            '*': lambda a, b: a * b,
            '/': lambda a, b: a / b,
        }

        if node.operator not in ops:
            raise ValueError(f"Unknown operator: {node.operator}")

        return ops[node.operator](left, right)

    def eval_unary_op(self, node):
        """Evaluate unary operation."""
        operand = self.evaluate(node.operand)

        if node.operator == '-':
            return -operand
        elif node.operator == 'not':
            return not operand
        else:
            raise ValueError(f"Unknown unary operator: {node.operator}")
```

## Bilateral Evaluation

Bilateral evaluation computes both positive and negative aspects:

```python
class BilateralEvaluator(Evaluator):
    """Evaluator with both verify and falsify methods."""

    def verify(self, node: "ASTNode") -> Any:
        """Check if node evaluates to true."""
        method_name = f'verify_{node.type}'
        method = getattr(self, method_name, self.verify_default)
        return method(node)

    def falsify(self, node: "ASTNode") -> Any:
        """Check if node evaluates to false."""
        method_name = f'falsify_{node.type}'
        method = getattr(self, method_name, self.falsify_default)
        return method(node)

    def verify_default(self, node):
        raise NotImplementedError(f"No verify handler for: {node.type}")

    def falsify_default(self, node):
        raise NotImplementedError(f"No falsify handler for: {node.type}")
```

### Bilateral Negation

```python
def verify_negation(self, node):
    """Node verifies NOT(arg) iff it falsifies arg."""
    return self.falsify(node.argument)

def falsify_negation(self, node):
    """Node falsifies NOT(arg) iff it verifies arg."""
    return self.verify(node.argument)
```

### Bilateral Conjunction

```python
def verify_conjunction(self, node):
    """Verify A AND B: both must verify."""
    left_result = self.verify(node.left)
    right_result = self.verify(node.right)
    return self.combine_verify(left_result, right_result)

def falsify_conjunction(self, node):
    """Falsify A AND B: either must falsify."""
    return self.any_falsifies([node.left, node.right])
```

### Bilateral Disjunction

```python
def verify_disjunction(self, node):
    """Verify A OR B: either must verify."""
    return self.any_verifies([node.left, node.right])

def falsify_disjunction(self, node):
    """Falsify A OR B: both must falsify."""
    left_result = self.falsify(node.left)
    right_result = self.falsify(node.right)
    return self.combine_falsify(left_result, right_result)
```

## Evaluation Context

### Environment Pattern

```python
class Environment:
    """Evaluation environment with scoping."""

    def __init__(self, parent: Optional["Environment"] = None):
        self.bindings: Dict[str, Any] = {}
        self.parent = parent

    def lookup(self, name: str) -> Any:
        """Look up a binding in this environment or parents."""
        if name in self.bindings:
            return self.bindings[name]
        if self.parent is not None:
            return self.parent.lookup(name)
        raise NameError(f"Undefined: {name}")

    def define(self, name: str, value: Any) -> None:
        """Define a new binding."""
        self.bindings[name] = value

    def extend(self) -> "Environment":
        """Create a new environment with this as parent."""
        return Environment(parent=self)
```

### Using Environment in Evaluator

```python
class ScopedEvaluator(Evaluator):
    """Evaluator with scoped environments."""

    def __init__(self):
        self.env = Environment()

    def eval_let(self, node):
        """Evaluate let binding."""
        # Create new scope
        self.env = self.env.extend()

        # Bind variables
        for binding in node.bindings:
            value = self.evaluate(binding.value)
            self.env.define(binding.name, value)

        # Evaluate body in new scope
        result = self.evaluate(node.body)

        # Restore previous scope
        self.env = self.env.parent

        return result
```

## Constraint Generation

For symbolic evaluation (e.g., with Z3):

```python
import z3


class ConstraintEvaluator(Evaluator):
    """Generate constraints from AST."""

    def __init__(self):
        self.constraints = []
        self.variables: Dict[str, z3.ExprRef] = {}

    def get_var(self, name: str, sort=z3.IntSort()) -> z3.ExprRef:
        """Get or create a Z3 variable."""
        if name not in self.variables:
            self.variables[name] = z3.Const(name, sort)
        return self.variables[name]

    def eval_comparison(self, node):
        """Generate comparison constraint."""
        left = self.evaluate(node.left)
        right = self.evaluate(node.right)

        ops = {
            '==': lambda a, b: a == b,
            '!=': lambda a, b: a != b,
            '<':  lambda a, b: a < b,
            '<=': lambda a, b: a <= b,
            '>':  lambda a, b: a > b,
            '>=': lambda a, b: a >= b,
        }

        return ops[node.operator](left, right)

    def add_constraint(self, constraint: z3.BoolRef) -> None:
        """Add a constraint to the system."""
        self.constraints.append(constraint)

    def solve(self) -> Optional[z3.ModelRef]:
        """Solve the constraint system."""
        solver = z3.Solver()
        solver.add(self.constraints)
        if solver.check() == z3.sat:
            return solver.model()
        return None
```

## Evaluation Pipeline

```python
def evaluate_program(source: str, context: Dict[str, Any] = None) -> Any:
    """Full evaluation pipeline."""
    # 1. Parse source into AST
    ast = parse(source)

    # 2. Create evaluator with context
    evaluator = ExpressionEvaluator(context or {})

    # 3. Evaluate AST
    result = evaluator.evaluate(ast)

    return result
```

## Performance Patterns

### Memoization

```python
from functools import lru_cache


class MemoizedEvaluator(Evaluator):
    """Evaluator with memoization for repeated subexpressions."""

    @lru_cache(maxsize=1000)
    def evaluate_cached(self, node_id: int) -> Any:
        """Cached evaluation by node ID."""
        node = self.node_registry[node_id]
        return self._evaluate_impl(node)

    def evaluate(self, node):
        """Evaluate with caching."""
        if hasattr(node, 'id'):
            return self.evaluate_cached(node.id)
        return self._evaluate_impl(node)
```

### Timeout Handling

```python
import signal


class TimeoutError(Exception):
    pass


def with_timeout(timeout_seconds: int):
    """Decorator for timeout-protected evaluation."""
    def decorator(func):
        def handler(signum, frame):
            raise TimeoutError("Evaluation timed out")

        def wrapper(*args, **kwargs):
            signal.signal(signal.SIGALRM, handler)
            signal.alarm(timeout_seconds)
            try:
                result = func(*args, **kwargs)
            finally:
                signal.alarm(0)
            return result

        return wrapper
    return decorator
```

### Incremental Evaluation

```python
class IncrementalEvaluator(Evaluator):
    """Evaluator that can be paused and resumed."""

    def __init__(self):
        self.state_stack = []

    def checkpoint(self) -> Dict[str, Any]:
        """Save current evaluation state."""
        return {
            'stack': self.state_stack.copy(),
            'context': self.context.copy(),
        }

    def restore(self, checkpoint: Dict[str, Any]) -> None:
        """Restore from checkpoint."""
        self.state_stack = checkpoint['stack']
        self.context = checkpoint['context']
```
