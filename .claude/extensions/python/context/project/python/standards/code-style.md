# Python Code Style Guide

## Code Formatting

### Tools
- `ruff` - Fast linter and formatter
- `black` - Code formatting (alternative)
- `isort` - Import sorting

### Line Length
- Target: 88 characters (ruff/black default)
- Maximum: 100 characters (documentation)

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Module | snake_case | `my_module.py` |
| Class | PascalCase | `MyClass` |
| Function | snake_case | `my_function` |
| Constant | SCREAMING_SNAKE | `MAX_VALUE` |
| Variable | snake_case | `my_variable` |
| Private | `_prefix` | `_internal` |

## Type Hints

```python
from __future__ import annotations
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from collections.abc import Callable

def function(arg: str, count: int = 0) -> list[str]:
    """Function with type hints."""
    return [arg] * count
```

## Docstrings

### Google Style (Recommended)
```python
def function(arg1: str, arg2: int) -> bool:
    """Short description.

    Longer description if needed.

    Args:
        arg1: Description of arg1.
        arg2: Description of arg2.

    Returns:
        Description of return value.

    Raises:
        ValueError: When invalid input.
    """
    pass
```

## Import Organization

```python
# Standard library
import os
import sys
from pathlib import Path

# Third-party
import pytest
import numpy as np

# Local
from mypackage import module
from mypackage.subpackage import function
```

## Class Structure

```python
class MyClass:
    """Class docstring."""

    # Class attributes
    class_attr: str = "value"

    def __init__(self, arg: str) -> None:
        """Initialize instance."""
        self.arg = arg

    # Properties first
    @property
    def computed(self) -> str:
        """Property docstring."""
        return self.arg.upper()

    # Public methods
    def public_method(self) -> None:
        """Public method."""
        pass

    # Private methods
    def _private_method(self) -> None:
        """Private method."""
        pass
```

## Error Handling

```python
# Specific exceptions
try:
    result = risky_operation()
except ValueError as e:
    logger.error("Invalid value: %s", e)
    raise
except KeyError:
    return default_value

# Context managers
with open(path) as f:
    content = f.read()
```
