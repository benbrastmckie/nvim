# Python Testing Patterns

## Pytest Basics

### Simple Test
```python
def test_addition():
    assert 1 + 1 == 2
```

### Test Class
```python
class TestCalculator:
    def test_add(self):
        calc = Calculator()
        assert calc.add(1, 2) == 3

    def test_subtract(self):
        calc = Calculator()
        assert calc.subtract(5, 3) == 2
```

## Fixtures

### Basic Fixture
```python
import pytest

@pytest.fixture
def sample_data():
    return {"key": "value"}

def test_with_fixture(sample_data):
    assert sample_data["key"] == "value"
```

### Fixture with Cleanup
```python
@pytest.fixture
def temp_file(tmp_path):
    file_path = tmp_path / "test.txt"
    file_path.write_text("content")
    yield file_path
    # Cleanup happens automatically
```

### Scoped Fixtures
```python
@pytest.fixture(scope="module")
def database_connection():
    conn = create_connection()
    yield conn
    conn.close()
```

## Parametrization

```python
@pytest.mark.parametrize("input,expected", [
    (1, 2),
    (2, 4),
    (3, 6),
])
def test_double(input, expected):
    assert double(input) == expected
```

## Exception Testing

```python
def test_raises_error():
    with pytest.raises(ValueError) as excinfo:
        function_that_raises()
    assert "expected message" in str(excinfo.value)
```

## Mocking

```python
from unittest.mock import Mock, patch

def test_with_mock():
    mock_api = Mock()
    mock_api.get_data.return_value = {"result": 42}

    result = process_data(mock_api)
    assert result == 42
    mock_api.get_data.assert_called_once()

@patch("module.external_function")
def test_with_patch(mock_func):
    mock_func.return_value = "mocked"
    result = function_using_external()
    assert result == "mocked"
```

## Markers

```python
@pytest.mark.slow
def test_slow_operation():
    pass

@pytest.mark.skip(reason="Not implemented")
def test_future_feature():
    pass

@pytest.mark.xfail
def test_known_failure():
    pass
```

## Configuration (pytest.ini)

```ini
[pytest]
testpaths = tests
python_files = test_*.py
python_functions = test_*
markers =
    slow: marks tests as slow
    integration: marks integration tests
```
