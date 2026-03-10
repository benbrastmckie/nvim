# CI/CD Pipeline Guide

GitLab CI/CD configuration for tag-triggered Cloudflare Pages deployments.

## Deployment Workflow

```
Local Development          GitLab CI/CD               Cloudflare
       │                        │                         │
       ├─ git push ─────────► Build Job ◄── All pushes   │
       │                    (verify only)                 │
       │                        │                         │
       │                        │                         │
       ├─ git tag v*.*.* ──► Deploy Job ───────────────► Live
       │                  (wrangler deploy)               │
       │                        │                         │
       └────────────────────────┴─────────────────────────┘
```

**Key Points**:
- Every push triggers the build stage (TypeScript check, Astro build)
- Only semantic version tags (`v*.*.*`) trigger deployment
- Agents cannot push tags (deployment remains user-controlled)
- Build failures block deployment (fast feedback loop)

## GitLab CI/CD Job Structure

### Build Stage

Runs on every push to verify code quality:

```yaml
build:
  stage: build
  image: node:22-alpine
  script:
    - corepack enable
    - pnpm install --frozen-lockfile
    - pnpm check
    - pnpm build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour
```

### Deploy Stage

Runs only on protected tags matching semantic version pattern:

```yaml
deploy:
  stage: deploy
  image: node:22-alpine
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
  script:
    - corepack enable
    - pnpm install --frozen-lockfile
    - pnpm exec wrangler pages deploy dist/ --project-name=my-project
  environment:
    name: production
    url: https://my-project.pages.dev
```

## Tag-Triggered Deployment

### Preferred Method: /tag Command

Use the `/tag` command for creating and pushing version tags:

```bash
# Create and push patch release (default)
/tag

# Create and push minor release
/tag --minor

# Create and push major release
/tag --major

# Preview without executing
/tag --dry-run

# Skip confirmation prompt
/tag --force
```

The `/tag` command:
- Validates git state (clean working tree, up-to-date with remote)
- Computes the next version automatically
- Shows commits since last tag
- Prompts for confirmation (unless `--force`)
- Creates and pushes the tag
- Updates state.json with deployment history

**Note**: This command is user-only. Agents cannot invoke it.

### Semantic Versioning Convention

Follow semantic versioning (MAJOR.MINOR.PATCH) with these guidelines:

| Version Type | When to Use | Examples |
|--------------|-------------|----------|
| **Patch (v0.2.1)** | Bug fixes, config changes, minor content updates, redirects | _redirects file, typo fixes, metadata updates |
| **Minor (v0.3.0)** | New features, significant content additions | New page sections, new routes, feature additions |
| **Major (v1.0.0)** | Breaking changes, major redesigns | Complete redesign, URL structure changes |

**Default increment**: Use **patch** unless explicitly changing scope to minor or major.

### Creating a Release Tag

**Recommended**: Use the `/tag` command (see above).

**Manual method** (when /tag is unavailable):

```bash
# Most deployments (bug fixes, config, minor changes)
git tag v0.2.1
git push origin v0.2.1

# New features (only when explicitly adding new functionality)
git tag v0.3.0
git push origin v0.3.0

# Major releases (breaking changes, redesigns)
git tag v1.0.0
git push origin v1.0.0
```

### Tag Format Requirements

| Format | Valid | Notes |
|--------|-------|-------|
| `v1.0.0` | Yes | Standard semantic version |
| `v1.2.3` | Yes | Patch release |
| `v2.0.0-beta.1` | No | Pre-release tags not configured for deploy |
| `1.0.0` | No | Missing `v` prefix |
| `release-1.0` | No | Wrong format |

## Post-Deployment Verification

After pushing a release tag, verify deployment succeeded:

### 1. Check Deployment History

```bash
pnpm exec wrangler pages deployment list --project-name=my-project
```

Verify:
- Latest deployment timestamp matches tag creation time
- Commit hash matches your release commit
- Environment shows "production"

### 2. Test Redirect (if _redirects file exists)

```bash
# Should show: HTTP/2 301, location: https://my-project.ai/
curl -I https://my-project.pages.dev/
```

### 3. Test Main Domain

```bash
# Should show: HTTP/2 200
curl -I https://my-project.ai/
```

### 4. Visual Browser Check

Open incognito window and:
- Visit https://my-project.pages.dev (should redirect to .ai domain)
- Visit https://my-project.ai (should load correctly)
- Verify new content appears

### Common Post-Deployment Issues

| Issue | Cause | Resolution |
|-------|-------|------------|
| Redirect not working immediately | Cache propagation delay | Wait 5-15 minutes |
| Old content showing | Browser cache | Hard refresh (Ctrl+Shift+R / Cmd+Shift+R) |
| Deployment missing from list | CI/CD failure or wrong credentials | Check GitLab pipeline logs |
| _redirects not processed | Syntax error or file not in dist/ | Verify file content and build output |

## Wrangler CLI for Deployment Debugging

### List Recent Deployments

```bash
pnpm exec wrangler pages deployment list --project-name=my-project
```

Output shows deployment IDs, timestamps, and status for troubleshooting.

### Tail Deployment Logs

```bash
pnpm exec wrangler pages deployment tail --project-name=my-project
```

Real-time log streaming for debugging production issues.

### Rollback to Previous Deployment

```bash
# Find deployment ID from list command
pnpm exec wrangler pages deployment list --project-name=my-project

# Rollback to known-good deployment
pnpm exec wrangler pages deployment rollback <deployment-id> --project-name=my-project
```

### Check Wrangler Version

```bash
pnpm exec wrangler --version
```

Version mismatches can cause unexpected behavior. Ensure CI/CD and local versions match.

## Common Failure Modes

### Build Fails in CI

**Symptoms**: Pipeline fails at build stage, TypeScript or Astro errors.

**Resolution**:
1. Run locally first:
   ```bash
   pnpm check && pnpm build
   ```
2. Fix TypeScript errors, missing imports, or Astro template issues
3. Push fix and verify CI passes

### Deploy Auth Error

**Symptoms**: "unauthorized" or "authentication failed" in deploy job logs.

**Possible Causes**:
- `CLOUDFLARE_API_TOKEN` expired or revoked
- Token scope insufficient (needs Cloudflare Pages Edit)
- Variable not marked as protected (for protected tag deploys)

**Resolution**:
1. Generate new API token in Cloudflare dashboard
2. Update GitLab CI/CD variable
3. Verify "Mask variable" and "Protect variable" are enabled

### Project Not Found

**Symptoms**: "project not found" or "account not found" errors.

**Possible Causes**:
- `CLOUDFLARE_ACCOUNT_ID` incorrect
- Project name mismatch between wrangler.jsonc and deploy command
- Account permissions issue

**Resolution**:
1. Verify account ID in Cloudflare dashboard
2. Check project name matches in:
   - `wrangler.jsonc` (name field)
   - Deploy command (`--project-name=`)
   - Cloudflare Pages dashboard

### Tag Not Triggering Deploy

**Symptoms**: Tag pushed but deploy job never runs.

**Possible Causes**:
- Tag format doesn't match regex (`^v\d+\.\d+\.\d+$`)
- Tag not pushed to remote
- CI/CD rules misconfigured

**Resolution**:
1. Verify tag format: `git tag -l`
2. Verify tag pushed: `git ls-remote --tags origin`
3. Check `.gitlab-ci.yml` rules section

### Token Exposed in Logs

**Symptoms**: API token visible in CI/CD job output.

**Resolution** (CRITICAL):
1. Immediately revoke token in Cloudflare dashboard
2. Generate new token
3. Update GitLab variable with "Mask variable" enabled
4. Review CI/CD configuration for `echo` statements or verbose flags

## Environment Variable Security

### Required Variables

| Variable | Description | Protection |
|----------|-------------|------------|
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare account identifier | Masked |
| `CLOUDFLARE_API_TOKEN` | API token with Pages Edit scope | Masked, Protected |

### Variable Configuration (GitLab)

1. Navigate to **Settings** > **CI/CD** > **Variables**
2. Add variable with:
   - **Protect variable**: Yes (only available on protected branches/tags)
   - **Mask variable**: Yes (hidden in job logs)

### Security Best Practices

- **Never hardcode credentials** in `.gitlab-ci.yml` or code
- **Use masked variables** for all secrets
- **Scope tokens minimally**: Cloudflare Pages Edit only, not Account Admin
- **Rotate tokens periodically** (every 90 days recommended)
- **Agents should never suggest** storing credentials in files or environment variables in code

## Local Development vs CI/CD

| Action | Local | CI/CD |
|--------|-------|-------|
| Build verification | `pnpm build` | Build stage (every push) |
| TypeScript check | `pnpm check` | Build stage |
| Deploy to production | Not recommended | Tag-triggered deploy stage |
| Preview deployment | `wrangler pages deploy dist/` | Branch preview (automatic) |

### Local Pre-Push Verification

Before pushing, run the same checks CI/CD will run:

```bash
pnpm check && pnpm build
```

This catches errors before CI/CD, reducing pipeline failures.

## Rollback Procedures

### Quick Rollback via Dashboard

1. Go to Cloudflare Dashboard > Pages > Project
2. Find previous successful deployment
3. Click menu > "Rollback to this deployment"

### Rollback via CLI

```bash
# List deployments to find target
pnpm exec wrangler pages deployment list --project-name=my-project

# Rollback to specific deployment ID
pnpm exec wrangler pages deployment rollback abc123xyz --project-name=my-project
```

### Rollback via Git

For code-level rollback:

```bash
# Revert to previous release
git revert HEAD
git tag v1.0.1
git push origin main v1.0.1
```

## Related Documentation

- `.gitlab-ci.yml` - Pipeline configuration file
- `wrangler.jsonc` - Wrangler project configuration
- `@.opencode/context/project/web/tools/cloudflare-deploy-guide.md` - Manual wrangler deployment
- `@.opencode/context/project/web/domain/cloudflare-pages.md` - Cloudflare Pages platform overview
