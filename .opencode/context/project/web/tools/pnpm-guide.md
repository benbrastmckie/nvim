# pnpm Guide

Package manager reference for the website project.

## Installation

```bash
# Install pnpm via corepack (Node.js 16.13+)
corepack enable
corepack prepare pnpm@latest --activate

# Or install standalone
curl -fsSL https://get.pnpm.io/install.sh | sh -
```

## Common Commands

| Command | Description | npm Equivalent |
|---------|-------------|----------------|
| `pnpm install` | Install all dependencies | `npm install` |
| `pnpm add <pkg>` | Add dependency | `npm install <pkg>` |
| `pnpm add -D <pkg>` | Add dev dependency | `npm install -D <pkg>` |
| `pnpm remove <pkg>` | Remove dependency | `npm uninstall <pkg>` |
| `pnpm update` | Update dependencies | `npm update` |
| `pnpm update --latest` | Update to latest (ignore ranges) | `npm update --latest` |
| `pnpm outdated` | Check for outdated packages | `npm outdated` |
| `pnpm run <script>` | Run package.json script | `npm run <script>` |
| `pnpm exec <cmd>` | Run local binary | `npx <cmd>` |
| `pnpm dlx <pkg>` | Download and execute | `npx <pkg>` |
| `pnpm store prune` | Remove unreferenced packages | N/A |

## Project Scripts

Typical scripts in `package.json` for an Astro project:

```json
{
  "scripts": {
    "dev": "astro dev",
    "build": "astro check && astro build",
    "preview": "astro preview",
    "check": "astro check",
    "format": "prettier --write .",
    "lint": "eslint src/"
  }
}
```

Run scripts:

```bash
pnpm dev           # Start dev server (shorthand for pnpm run dev)
pnpm build         # Type-check and build for production
pnpm preview       # Preview production build locally
pnpm check         # Run Astro type checking
```

## Adding Dependencies

```bash
# Add runtime dependency
pnpm add @astrojs/tailwind

# Add dev dependency
pnpm add -D prettier prettier-plugin-astro

# Add specific version
pnpm add astro@5.2.0

# Add from GitHub
pnpm add github:user/repo
```

## Lockfile Management

- **File**: `pnpm-lock.yaml`
- **Always commit** to version control
- **Never edit manually**
- Regenerate with `pnpm install` after editing `package.json`

```bash
# Install exactly from lockfile (CI environments)
pnpm install --frozen-lockfile

# Update lockfile without modifying node_modules
pnpm install --lockfile-only
```

## Store Management

pnpm uses a content-addressable store for disk efficiency:

```bash
# View store path
pnpm store path

# Remove unreferenced packages from store
pnpm store prune

# Verify store integrity
pnpm store status
```

## Useful Flags

| Flag | Description |
|------|-------------|
| `--frozen-lockfile` | Fail if lockfile needs update (CI) |
| `--prefer-offline` | Use cached packages when possible |
| `--filter <pattern>` | Run command in specific workspace |
| `--recursive` / `-r` | Run command in all workspaces |
| `--prod` | Install only production dependencies |

## Node Version Management

Specify the Node.js version in `package.json`:

```json
{
  "engines": {
    "node": ">=22.0.0",
    "pnpm": ">=9.0.0"
  }
}
```

## Troubleshooting

### Clean Reinstall

```bash
rm -rf node_modules
rm pnpm-lock.yaml
pnpm install
```

### Peer Dependency Warnings

Add to `.npmrc` if needed:

```ini
# .npmrc
auto-install-peers=true
strict-peer-dependencies=false
```

### Module Resolution

pnpm uses strict isolation by default (no phantom dependencies). If a package fails because it relies on hoisted dependencies:

```ini
# .npmrc - only if absolutely necessary
shamefully-hoist=true
```
