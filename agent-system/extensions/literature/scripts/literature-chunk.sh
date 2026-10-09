#!/usr/bin/env bash
# literature-chunk.sh - Two-pass hierarchical chunking with cross-reference extraction
#
# Usage:
#   literature-chunk.sh <input.md> <output_dir> --doc-id <id>
#
# Outputs:
#   {output_dir}/chunk_NNNN.md  — one file per chunk (breadcrumb-prepended content)
#   {output_dir}/chunks.json    — manifest with all chunk metadata
#
# Chunking algorithm:
#   Pass 1: Split at heading boundaries (# ## ###), detect atomic blocks
#   Pass 2: Subdivide chunks >512 tokens at paragraph then sentence breaks
#           Atomic blocks (Theorem/Proof/Definition/etc) up to 1024 token hard cap
#
# Cross-reference extraction:
#   Patterns: \b(Definition|Lemma|Theorem|Proposition|Corollary|Remark|Example)\s+\d+(\.\d+)*\b
#             \bTheorem\s+[A-Z]\b
#
# Chunk ID: sha256(doc_id + section_path + first_64_chars_of_content)[:16]
#
# Exit codes:
#   0 — success
#   1 — missing arguments or input file not found

set -euo pipefail

# --- Arguments ---
INPUT_MD="${1:-}"
OUTPUT_DIR="${2:-}"
DOC_ID=""

shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --doc-id) DOC_ID="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$INPUT_MD" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "[chunk] Usage: $0 <input.md> <output_dir> --doc-id <id>" >&2
  exit 1
fi

if [ ! -f "$INPUT_MD" ]; then
  echo "[chunk] Input file not found: $INPUT_MD" >&2
  exit 1
fi

if [ -z "$DOC_ID" ]; then
  DOC_ID=$(basename "$INPUT_MD" .md | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
fi

mkdir -p "$OUTPUT_DIR"

log() { echo "[chunk] $*" >&2; }

# --- Constants ---
TARGET_TOKENS=512     # Target chunk size
ATOM_CAP_TOKENS=1024  # Hard cap for atomic blocks

# Atomic block keywords
ATOMIC_PATTERNS="Theorem|Proof|Definition|Lemma|Proposition|Corollary|Axiom|Claim|Conjecture|Observation"

# Cross-reference patterns (used with grep -oE)
# shellcheck disable=SC2034  # Documented pattern constant, not currently consumed anywhere in
# this file or the Python chunking helper -- a planned cross-reference extraction feature not
# yet wired up.
XREF_PATTERN='\b(Definition|Lemma|Theorem|Proposition|Corollary|Remark|Example|Axiom|Figure|Section)\s+[0-9]+(\.[0-9]+)*\b|\bTheorem\s+[A-Z]\b'

# --- Python helper for the chunking logic ---
# bash+awk is adequate for simple splitting but Python handles
# the sha256, JSON output, and regex more cleanly

python3 << PYEOF
import sys
import re
import json
import hashlib
import os

input_md = "$INPUT_MD"
output_dir = "$OUTPUT_DIR"
doc_id = "$DOC_ID"
target_tokens = $TARGET_TOKENS
atom_cap_tokens = $ATOM_CAP_TOKENS
atomic_keywords = set("$ATOMIC_PATTERNS".split('|'))

# Read input
with open(input_md, encoding='utf-8', errors='replace') as f:
    content = f.read()

def estimate_tokens(text):
    """Approximate token count as chars/4"""
    return max(1, len(text) // 4)

def compute_chunk_id(doc_id, section_path, content_prefix):
    """Stable 16-char ID from doc_id + section_path + content fingerprint"""
    data = f"{doc_id}\x00{section_path}\x00{content_prefix[:64]}"
    return hashlib.sha256(data.encode()).hexdigest()[:16]

def extract_cross_refs(text):
    """Extract reference labels from chunk text"""
    pattern = r'\b(Definition|Lemma|Theorem|Proposition|Corollary|Remark|Example|Axiom|Figure|Section)\s+\d+(?:\.\d+)*\b|\bTheorem\s+[A-Z]\b'
    matches = re.findall(pattern, text, re.IGNORECASE)
    # re.findall returns tuples when there are groups; extract full match differently
    full_pattern = re.compile(
        r'\b(?:Definition|Lemma|Theorem|Proposition|Corollary|Remark|Example|Axiom|Figure|Section)\s+\d+(?:\.\d+)*\b'
        r'|\bTheorem\s+[A-Z]\b',
        re.IGNORECASE
    )
    refs = list(dict.fromkeys(full_pattern.findall(text)))  # deduplicated, order preserved
    return refs

def is_atomic_start(line):
    """True if line marks the start of an atomic block"""
    stripped = line.strip()
    atomic_pattern = re.compile(
        r'^(?:\*{1,2})?(?:Theorem|Proof|Definition|Lemma|Proposition|Corollary|Axiom|Claim|Conjecture|Observation)\b',
        re.IGNORECASE
    )
    return bool(atomic_pattern.match(stripped))

def extract_keywords(title, content):
    """Extract keywords from heading words plus bolded terms"""
    keywords = set()

    # Words from title
    for word in re.split(r'\W+', title):
        if len(word) > 3:
            keywords.add(word.lower())

    # Bolded terms in content
    bold_terms = re.findall(r'\*{1,2}([^*]+)\*{1,2}', content)
    for term in bold_terms:
        words = re.split(r'\W+', term)
        for word in words:
            if len(word) > 3:
                keywords.add(word.lower())

    return ' '.join(sorted(keywords)[:20])  # Limit to 20 keywords

def extract_summary(title, content):
    """Extract heuristic summary: first sentence up to 150 chars"""
    # Skip any breadcrumb line at start
    lines = content.strip().split('\n')
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#') or ' > ' in line:
            continue
        # First non-empty, non-heading, non-breadcrumb line
        # Extract up to first sentence ending
        sentences = re.split(r'(?<=[.!?])\s+', line)
        summary = sentences[0][:150] if sentences else line[:150]
        return summary.strip()
    return title[:150] if title else ''

# ============================================================
# Pass 1: Split at heading boundaries
# ============================================================

class HeadingChunk:
    def __init__(self, level, title, section_path, content_lines):
        self.level = level
        self.title = title
        self.section_path = section_path
        self.content = '\n'.join(content_lines)
        self.is_atomic = False

def split_at_headings(content):
    """Parse markdown and split at # ## ### boundaries"""
    lines = content.split('\n')

    chunks = []
    current_level = 0
    current_title = doc_id.replace('_', ' ').title()  # document-level title
    section_stack = []  # list of (level, title) for breadcrumb building
    current_lines = []

    def build_section_path(stack, title):
        """Build breadcrumb from stack of ancestor headings"""
        parts = [t for _, t in stack] + [title]
        # Abbreviate: use first 20 chars of each part
        abbrev = [p[:20] + ('...' if len(p) > 20 else '') for p in parts]
        return ' > '.join(abbrev)

    def flush_chunk(level, title, section_path, lines):
        if lines or level == 0:
            chunk = HeadingChunk(level, title, section_path, lines)
            chunks.append(chunk)

    for line in lines:
        heading_match = re.match(r'^(#{1,4})\s+(.+)$', line)

        if heading_match:
            # Flush current chunk
            if current_lines or current_level == 0:
                # BUG 3 fix: section_stack's top entry is (current_level, current_title)
                # itself (pushed below when this section began), so it must be excluded
                # from the ancestor list here — otherwise current_title is appended
                # twice, producing doubled breadcrumbs like "Doc > X > X".
                section_path = build_section_path(section_stack[:-1], current_title)
                flush_chunk(current_level, current_title, section_path, current_lines)

            heading_level = len(heading_match.group(1))
            heading_title = heading_match.group(2).strip()

            # Update section stack
            while section_stack and section_stack[-1][0] >= heading_level:
                section_stack.pop()

            current_title = heading_title
            current_level = heading_level
            current_lines = []
            section_stack.append((heading_level, heading_title))
        else:
            current_lines.append(line)

    # Flush final chunk
    if current_lines or len(chunks) == 0:
        # BUG 3 fix: same section_stack[:-1] rationale as the in-loop flush above;
        # the empty-stack (document-level, level-0) case is unaffected: [][:-1] == [].
        section_path = build_section_path(section_stack[:-1], current_title)
        flush_chunk(current_level, current_title, section_path, current_lines)

    return chunks

heading_chunks = split_at_headings(content)

# ============================================================
# Pass 2: Size enforcement - subdivide large chunks
# ============================================================

def split_at_paragraphs(text):
    """Split text at blank-line boundaries"""
    paragraphs = re.split(r'\n\s*\n', text)
    return [p.strip() for p in paragraphs if p.strip()]

def split_at_sentences(text):
    """Split text at sentence boundaries (. [A-Z] pattern)"""
    # Split on '. ' followed by uppercase, or end of line with period
    sentences = re.split(r'(?<=[.!?])\s+(?=[A-Z\-\(])', text)
    return [s.strip() for s in sentences if s.strip()]

def merge_small_pieces(pieces, target_tokens):
    """Greedily merge pieces under target_token limit"""
    merged = []
    current = []
    current_tokens = 0

    for piece in pieces:
        piece_tokens = estimate_tokens(piece)
        if current_tokens + piece_tokens > target_tokens and current:
            merged.append('\n\n'.join(current))
            current = [piece]
            current_tokens = piece_tokens
        else:
            current.append(piece)
            current_tokens += piece_tokens

    if current:
        merged.append('\n\n'.join(current))

    return merged if merged else ['']

def subdivide_chunk(chunk_content, title, section_path, target_tokens, atom_cap):
    """Subdivide chunk content into appropriately-sized pieces"""
    total_tokens = estimate_tokens(chunk_content)

    # Detect if this is an atomic block
    first_line = chunk_content.strip().split('\n')[0] if chunk_content.strip() else ''
    is_atomic = is_atomic_start(first_line) or is_atomic_start(title)

    if is_atomic:
        if total_tokens <= atom_cap:
            return [(chunk_content, True)]  # Return as single atomic chunk
        else:
            # Oversized atomic block: warn, then fall through to size-based
            # subdivision below instead of returning unsplit.
            print(f"[chunk] WARNING: Atomic block exceeds {atom_cap} token cap ({total_tokens} tokens) - subdividing anyway: {title[:50]}", file=sys.stderr)

    if total_tokens <= target_tokens:
        return [(chunk_content, False)]

    # Try paragraph split first
    paragraphs = split_at_paragraphs(chunk_content)
    if len(paragraphs) > 1:
        merged = merge_small_pieces(paragraphs, target_tokens)
        result = []
        for piece in merged:
            piece_tokens = estimate_tokens(piece)
            if piece_tokens > target_tokens:
                # Try sentence split for oversized paragraphs
                sentences = split_at_sentences(piece)
                if len(sentences) > 1:
                    sent_merged = merge_small_pieces(sentences, target_tokens)
                    result.extend([(s, False) for s in sent_merged])
                else:
                    result.append((piece, False))
            else:
                result.append((piece, False))
        return result

    # Single paragraph: try sentence split
    sentences = split_at_sentences(chunk_content)
    if len(sentences) > 1:
        return [(s, False) for s in merge_small_pieces(sentences, target_tokens)]

    # Cannot subdivide further (single sentence longer than target)
    return [(chunk_content, False)]

# ============================================================
# Generate final chunk list with all metadata
# ============================================================

raw_chunks = []  # list of (content, is_atomic, level, title, section_path, parent_level_idx)

for h_chunk in heading_chunks:
    pieces = subdivide_chunk(h_chunk.content, h_chunk.title, h_chunk.section_path, target_tokens, atom_cap_tokens)

    is_first = True
    for piece_content, is_atomic in pieces:
        if not piece_content.strip():
            continue

        # Prepend section breadcrumb to content
        breadcrumb = h_chunk.section_path
        if breadcrumb:
            full_content = f"{breadcrumb}\n\n{piece_content}"
        else:
            full_content = piece_content

        raw_chunks.append({
            'content': piece_content,
            'full_content': full_content,
            'is_atomic': is_atomic,
            'level': h_chunk.level,
            'title': h_chunk.title if is_first else f"{h_chunk.title} (cont.)",
            'section_path': h_chunk.section_path,
            'is_heading_chunk': is_first,
        })
        is_first = False

# ============================================================
# Assign chunk IDs and compute prev/next links
# ============================================================

chunks = []
for i, rc in enumerate(raw_chunks):
    chunk_id = compute_chunk_id(doc_id, rc['section_path'], rc['content'][:64])
    token_count = estimate_tokens(rc['full_content'])
    cross_refs = extract_cross_refs(rc['content'])
    keywords = extract_keywords(rc['title'], rc['content'])
    summary = extract_summary(rc['title'], rc['content'])

    # Source path (relative to wherever chunks_dir is)
    chunk_num = i + 1
    source_path = f"chunk_{chunk_num:04d}.md"

    chunks.append({
        'chunk_id': chunk_id,
        'doc_id': doc_id,
        'parent_chunk_id': None,   # Will be filled after all IDs computed
        'level': rc['level'],
        'section_path': rc['section_path'],
        'title': rc['title'],
        'keywords': keywords,
        'summary': summary,
        'token_count': token_count,
        'source_path': source_path,
        'prev_chunk_id': None,
        'next_chunk_id': None,
        'cross_refs': cross_refs,
        'full_content': rc['full_content'],
        'is_atomic': rc['is_atomic'],
        'is_heading_chunk': rc['is_heading_chunk'],
    })

# Build chunk_id list for prev/next linking
chunk_ids = [c['chunk_id'] for c in chunks]

# Build section_path -> heading chunk_id map for parent linking
heading_chunk_ids = {}  # section_path -> chunk_id of heading chunk
for i, c in enumerate(chunks):
    if c['is_heading_chunk']:
        heading_chunk_ids[c['section_path']] = c['chunk_id']

for i, c in enumerate(chunks):
    # prev/next links
    c['prev_chunk_id'] = chunk_ids[i - 1] if i > 0 else None
    c['next_chunk_id'] = chunk_ids[i + 1] if i < len(chunks) - 1 else None

    # parent_chunk_id: the heading chunk for this section (if not itself a heading chunk)
    if not c['is_heading_chunk']:
        c['parent_chunk_id'] = heading_chunk_ids.get(c['section_path'])

# ============================================================
# Write chunk files and manifest
# ============================================================

manifest = []
for i, c in enumerate(chunks):
    chunk_file = os.path.join(output_dir, c['source_path'])
    with open(chunk_file, 'w', encoding='utf-8') as f:
        f.write(c['full_content'])

    # Manifest entry (no full_content or internal flags)
    manifest_entry = {k: v for k, v in c.items() if k not in ('full_content', 'is_heading_chunk')}
    manifest.append(manifest_entry)

manifest_path = os.path.join(output_dir, 'chunks.json')
with open(manifest_path, 'w', encoding='utf-8') as f:
    json.dump(manifest, f, indent=2, ensure_ascii=False)

# Report stats
atomic_count = sum(1 for c in chunks if c['is_atomic'])
over_target = sum(1 for c in chunks if c['token_count'] > target_tokens)
print(f"[chunk] Generated {len(chunks)} chunks ({atomic_count} atomic, {over_target} over {target_tokens} token target)", file=sys.stderr)
print(f"[chunk] Manifest: {manifest_path}", file=sys.stderr)

# Output chunk count to stdout
print(len(chunks))
PYEOF

exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "[chunk] Python chunker failed (exit $exit_code)" >&2
  exit 1
fi

log "Done: $(cat "$OUTPUT_DIR/chunks.json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(f"{len(d)} chunks in {sys.argv[1]}") if False else print(f"Manifest has {len(d)} chunks")' 2>/dev/null || echo "chunk files in $OUTPUT_DIR")"
