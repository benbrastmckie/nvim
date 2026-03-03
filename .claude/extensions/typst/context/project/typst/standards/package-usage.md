# Typst Package Usage Standards

**Created**: 2026-02-27
**Purpose**: Guidelines for using packages in Typst documents

---

## Package Import Syntax

### Basic Import

```typst
#import "@preview/package-name:version": *
```

### Selective Import

```typst
#import "@preview/thmbox:0.1.0": thmbox, theorem
```

## Version Pinning

### Always Pin Versions

```typst
// Good - explicit version
#import "@preview/thmbox:0.1.0": *

// Avoid - may break with updates
#import "@preview/thmbox": *
```

### Upgrading Packages

1. Check changelog for breaking changes
2. Test with new version locally
3. Update import statements
4. Verify document compiles correctly
5. Commit changes

## Approved Packages

### Core Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `thmbox` | 0.1.0 | Theorem environments |
| `fletcher` | 0.5.5 | Diagrams and flowcharts |
| `cetz` | 0.3.2 | General drawing |
| `tablex` | 0.0.8 | Advanced tables |

### Optional Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `polylux` | 0.3.1 | Presentations |
| `physica` | 0.9.2 | Physics notation |
| `algorithmic` | 0.1.0 | Algorithm pseudocode |

## Adding New Packages

### Evaluation Criteria

1. **Necessity**: Does the package solve a real problem?
2. **Maintenance**: Is it actively maintained?
3. **Compatibility**: Works with current Typst version?
4. **License**: Compatible with project needs?

### Process

1. Test package in isolated document
2. Document usage in project context
3. Add to approved packages list
4. Update this document

## Local Packages

### Project Packages

For project-specific functionality:

```
project/
├── packages/
│   └── my-package/
│       └── lib.typ
└── main.typ
```

```typst
// Import local package
#import "packages/my-package/lib.typ": *
```

### Notation Modules

Keep notation separate from packages:

```typst
// notation/shared-notation.typ
#let R = math.bb("R")

// Use in documents
#import "notation/shared-notation.typ": *
```

## Troubleshooting

### Package Not Found

```
error: cannot find package @preview/package-name:version
```

**Solutions**:
- Verify package name spelling
- Check version exists on Typst Universe
- Ensure internet connectivity

### Version Conflicts

If two packages require different versions:
1. Check if versions are compatible
2. Try updating both to latest
3. Consider replacing one package

### Outdated Cache

```bash
# Clear Typst cache (if needed)
rm -rf ~/.cache/typst
```

## Best Practices

1. **Minimize dependencies**: Only use packages when necessary
2. **Pin versions**: Always specify exact versions
3. **Document usage**: Comment why each package is imported
4. **Update regularly**: Stay current but test changes
5. **Check alternatives**: Sometimes built-in features suffice
