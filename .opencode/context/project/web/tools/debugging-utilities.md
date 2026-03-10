# Web Debugging & Optimization Utilities

CLI tools for debugging, optimizing, and verifying web implementations. These tools are available system-wide and can be invoked via Bash.

## Image Optimization

### optipng

Lossless PNG optimization. Reduces file size without quality loss.

**When to use**:
- After creating or adding PNG images
- When plan specifies image optimization
- When optimizing static assets in `public/` or `src/assets/`
- When debugging large PNG file sizes

**Usage**:
```bash
# Optimize single PNG
optipng -o7 public/images/hero.png

# Optimize all PNGs in directory
optipng -o7 public/images/*.png

# Check optimization potential (dry run)
optipng -simulate public/images/hero.png
```

**Options**:
- `-o7`: Maximum optimization (slowest, smallest output)
- `-o2`: Balanced optimization (good default)
- `-simulate`: Show what would be saved without modifying
- `-preserve`: Keep file timestamps

### jpegoptim

JPEG optimization with optional quality reduction.

**When to use**:
- After creating or adding JPEG images
- When plan specifies image optimization
- When balancing quality vs file size for photos
- When debugging large JPEG file sizes

**Usage**:
```bash
# Lossless optimization
jpegoptim public/images/photo.jpg

# Optimize with quality limit (85% is good balance)
jpegoptim --max=85 public/images/photo.jpg

# Strip all metadata (EXIF, comments)
jpegoptim --strip-all public/images/photo.jpg

# Optimize all JPEGs in directory
jpegoptim --max=85 --strip-all public/images/*.jpg
```

**Options**:
- `--max=N`: Maximum quality (1-100)
- `--strip-all`: Remove all metadata
- `--preserve`: Keep file timestamps
- `-n`: Dry run (show what would change)

## HTTP Verification

### httpie (http command)

User-friendly HTTP client for verifying endpoints and APIs.

**When to use**:
- After deployment to verify endpoints
- When debugging API routes or SSR pages
- When checking response headers (caching, security)
- When plan includes endpoint verification

**Usage**:
```bash
# Simple GET request
http https://example.com/

# Check response headers only
http --headers https://example.com/

# Verify specific endpoint with JSON response
http https://example.com/api/contact

# POST request with JSON body
http POST https://example.com/api/contact \
  name="Test" email="test@example.com"

# Follow redirects
http --follow https://example.com/old-page

# Verify caching headers
http --headers https://example.com/ | grep -i cache
```

**Options**:
- `--headers` / `-h`: Show only response headers
- `--follow` / `-F`: Follow redirects
- `--timeout=N`: Request timeout in seconds
- `--verify=no`: Skip SSL verification (local dev only)

### curl patterns

Alternative HTTP verification using curl.

**When to use**:
- When httpie is not available
- For scripted verification in CI/CD
- For verbose protocol-level debugging

**Usage**:
```bash
# Simple GET with response code
curl -s -o /dev/null -w "%{http_code}" https://example.com/

# Show response headers
curl -I https://example.com/

# Follow redirects and show headers
curl -IL https://example.com/

# Time breakdown (DNS, connect, transfer)
curl -o /dev/null -s -w "DNS: %{time_namelookup}s\nConnect: %{time_connect}s\nTotal: %{time_total}s\n" https://example.com/
```

## DNS Verification

### dig

DNS lookup utility for verifying domain configuration.

**When to use**:
- After Cloudflare deployment to verify DNS propagation
- When debugging domain resolution issues
- When verifying CNAME/A record configuration
- When plan includes DNS verification

**Usage**:
```bash
# Basic DNS lookup
dig example.com

# Query specific record type
dig example.com A
dig example.com CNAME
dig example.com MX

# Query Cloudflare DNS directly (bypass local cache)
dig @1.1.1.1 example.com

# Short output (just the answer)
dig +short example.com

# Verify CNAME pointing to Cloudflare
dig +short example.com CNAME
# Expected: something.pages.dev or similar

# Check TTL and full response
dig +noall +answer example.com
```

**Cloudflare Pages verification**:
```bash
# Verify custom domain CNAME
dig +short example.com CNAME
# Should return: <project>.pages.dev

# Verify A record (if using apex domain)
dig +short example.com A
# Should return Cloudflare IP addresses

# Check DNS propagation from multiple resolvers
dig @1.1.1.1 +short example.com  # Cloudflare
dig @8.8.8.8 +short example.com  # Google
dig @9.9.9.9 +short example.com  # Quad9
```

## SSL/TLS Verification

### mkcert

Local development certificate generation for HTTPS testing.

**When to use**:
- Setting up local HTTPS development
- When testing service worker registration (requires HTTPS)
- When debugging mixed content issues locally
- When plan includes local HTTPS setup

**Usage**:
```bash
# Install local CA (one-time setup)
mkcert -install

# Generate certificate for localhost
mkcert localhost

# Generate certificate with multiple names
mkcert localhost 127.0.0.1 ::1

# Generate for custom local domain
mkcert localhost.dev localhost
```

**Astro integration**:
```typescript
// astro.config.mjs
import { defineConfig } from 'astro/config';

export default defineConfig({
  vite: {
    server: {
      https: {
        key: './localhost-key.pem',
        cert: './localhost.pem'
      }
    }
  }
});
```

### openssl

SSL/TLS verification for production certificates.

**When to use**:
- After deployment to verify SSL configuration
- When debugging certificate chain issues
- When checking certificate expiration
- When plan includes SSL verification

**Usage**:
```bash
# Verify certificate and chain
openssl s_client -connect example.com:443 -servername example.com

# Check certificate expiration
openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | \
  openssl x509 -noout -dates

# Verify certificate issuer
openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | \
  openssl x509 -noout -issuer

# Check certificate subject alternative names
openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | \
  openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
```

## Content Linting (Optional)

### vale

Prose linting for content-heavy sites.

**When to use**:
- For content-heavy sites with blog posts or documentation
- When maintaining consistent writing style
- When plan specifies prose quality checks
- Optional: only if vale configuration exists

**Usage**:
```bash
# Check single file
vale src/content/blog/first-post.md

# Check all content
vale src/content/

# Check with specific style
vale --config=.vale.ini src/content/

# Show only errors (skip suggestions)
vale --minAlertLevel=error src/content/
```

**Note**: Vale requires a `.vale.ini` configuration file. If not present, skip this tool.

## Tool Availability

These tools are documented in the system packages. If a tool is not installed, the command will fail gracefully. Check availability with:

```bash
command -v optipng && echo "optipng available"
command -v jpegoptim && echo "jpegoptim available"
command -v http && echo "httpie available"
command -v dig && echo "dig available"
command -v mkcert && echo "mkcert available"
command -v openssl && echo "openssl available"
command -v vale && echo "vale available"
```

## Integration with Build Workflow

### Pre-deployment checklist

```bash
# Optimize images
optipng -o2 public/images/*.png
jpegoptim --max=85 --strip-all public/images/*.jpg

# Build and verify
pnpm build
```

### Post-deployment verification

```bash
# Verify DNS (after Cloudflare deployment)
dig +short example.com CNAME

# Verify HTTPS
openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | \
  openssl x509 -noout -dates

# Verify endpoints
http --headers https://example.com/
http --headers https://example.com/api/health
```
