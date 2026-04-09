# Research Report: Task #378

**Task**: 378 - Create meeting format context files
**Started**: 2026-04-08T00:00:00Z
**Completed**: 2026-04-08T00:30:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**: Codebase (2 meeting files, 1 CSV tracker, 2 existing templates)
**Artifacts**: specs/378_meeting_format_context_files/reports/01_meeting-format-research.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The meeting file format uses YAML frontmatter with 25+ fields followed by a structured markdown body with 8 standard sections
- The CSV tracker contains 22 columns that map directly to frontmatter fields, with arrays joined by ", " and two derived columns (Meeting Count, Last Meeting)
- The existing founder extension templates follow a consistent pattern: title, output location, template in a fenced code block, section guidance, and a checklist -- the meeting format context files should follow this same structure

## Context & Scope

This research extracts the exact schema from two exemplar meeting files (`2026-04-07_halcyon.md`, `2026-04-08_celero.md`) and one CSV tracker (`VC-spreadsheet.csv`) to document the format for two new context files in the founder extension: `templates/meeting-format.md` and `patterns/csv-tracker.md`.

## Findings

### 1. YAML Frontmatter Schema

All fields extracted from both meeting files, with type analysis:

| # | Field | Type | Required | Description | Example |
|---|-------|------|----------|-------------|---------|
| 1 | `investor_name` | string | Yes | Official name of the firm | `"Halcyon Ventures"` |
| 2 | `website` | string | Yes | URL of the firm's website | `"https://halcyonfutures.org/"` |
| 3 | `fund_size` | string | Yes | Fund size (free-form, may include qualifiers) | `"$20M target"`, `"$25M"` |
| 4 | `fund_number` | string | Yes | Which fund (e.g., Fund I, Fund II) | `"Fund I"` |
| 5 | `stage` | array of strings | Yes | Investment stages | `["pre-seed", "seed"]` |
| 6 | `geography` | string | Yes | Location/region of the fund | `"Santa Monica, CA"` |
| 7 | `focus` | string | Yes | Investment thesis focus area | `"AI safety and security"` |
| 8 | `portfolio_size` | string | Yes | Number of portfolio companies (free-form) | `"12+"`, `"20-25 target"` |
| 9 | `check_size_min` | number | Yes | Minimum check size in USD (no dollar sign) | `250000` |
| 10 | `check_size_max` | number | Yes | Maximum check size in USD (no dollar sign) | `1500000` |
| 11 | `structure` | string | Yes | Fund structure description | `"Hybrid nonprofit incubator + VC fund"` |
| 12 | `primary_contact` | string | Yes | Name of main contact person | `"Ross Matican"` |
| 13 | `primary_contact_role` | string | Yes | Role/title of primary contact | `"Investor"` |
| 14 | `team` | array of objects | Yes | Key team members | See below |
| 15 | `pipeline_stage` | string | Yes | Current relationship stage | `"post-meeting"` |
| 16 | `last_touchpoint` | string (date) | Yes | Date of last interaction (YYYY-MM-DD) | `"2026-04-07"` |
| 17 | `next_action` | string | Yes | Next step to take | `"Follow up with Ross Matican..."` |
| 18 | `warm_intro` | boolean | Yes | Whether there was a warm introduction | `false` |
| 19 | `referral_source` | string | Yes | Who referred (empty string if none) | `""` |
| 20 | `fit_score` | number | Yes | 1-5 rating of investor fit | `4`, `3` |
| 21 | `likely_role` | string | Yes | Expected role in a round | `"syndicate participant / ecosystem connector"` |
| 22 | `strengths` | array of strings | Yes | Key strengths of this investor fit | See examples |
| 23 | `gaps` | array of strings | Yes | Key gaps/weaknesses of fit | See examples |
| 24 | `meetings` | array of objects | Yes | Meeting log entries | See below |
| 25 | `open_actions` | number | Yes | Count of open action items | `8`, `11` |
| 26 | `priority_action` | string | Yes | Single highest-priority action | `"Strengthen commercial case..."` |
| 27 | `tags` | array of strings | Yes | Categorical tags for filtering | `["ai-safety", "mission-vc", "pre-seed"]` |

#### Nested Object Schemas

**`team[]` object**:

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `name` | string | Yes | Full name | `"Mike McCormick"` |
| `role` | string | Yes | Title/role at firm | `"Founder/CEO"` |

**`meetings[]` object**:

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `date` | string (date) | Yes | Meeting date (YYYY-MM-DD) | `"2026-04-07"` |
| `type` | string | Yes | Meeting type | `"initial"` |
| `format` | string | Yes | How meeting was conducted | `"Slide-by-slide pitch deck review"`, `"unknown"` |
| `attendees_ours` | array of strings | Yes | Our team members present | `["Ben Brast-McKie"]` |
| `attendees_theirs` | array of strings | Yes | Their team members present | `["Nick Cochran"]`, `[]` |
| `outcome` | string | Yes | Brief outcome summary | `"Substantive engagement; introductions offered"` |
| `core_feedback` | string | Yes | One-line core feedback | `"Stronger commercial case needed"` |

#### Pipeline Stage Values (observed)

- `"post-meeting"` -- both files use this value
- Expected additional values (to document): `"identified"`, `"outreach"`, `"scheduled"`, `"post-meeting"`, `"follow-up"`, `"active"`, `"passed"`, `"committed"`

#### Fit Score Scale

- `3` = Celero (moderate fit, geographic/check size gaps)
- `4` = Halcyon (strong fit, mission alignment)
- Implied range: 1 (poor fit) to 5 (excellent fit)

### 2. Markdown Body Structure

Both files follow this section hierarchy:

#### Section 1: Title and Link
- **Heading**: `# {Investor Name}` (H1)
- **Content**: Blockquote with website URL: `> https://...`

#### Section 2: Investor Profile
- **Heading**: `## Investor Profile` (H2)
- **Content**: Summary table (Field | Detail), followed by prose blocks:
  - **Note** block (optional): Caveats about data sources
  - **Parent organization** (optional): If complex structure
  - **Team**: Bulleted list with bold name + em-dash + bio
  - **Thesis**: Prose paragraph explaining investment philosophy
  - **Investment categories tracked** (optional): Bulleted list
  - **Portfolio highlights**: Table (Company | Focus | Raise | Relevance to Logos Labs)
  - **Portfolio notes** (optional): Extended analysis of specific companies
  - **Comparable company** (optional): Valuation context

#### Section 3: Relationship Status
- **Heading**: `## Relationship Status` (H2)
- **Content**: Table (Field | Detail) with pipeline stage, primary contact, last touchpoint, next action

#### Section 4: Investor Fit Assessment
- **Heading**: `## Investor Fit Assessment` (H2)
- **Content**:
  - **Strengths**: Bulleted list
  - **Gaps**: Bulleted list
  - **Likely role**: Prose paragraph

#### Section 5: Meeting Log
- **Heading**: `## Meeting Log` (H2)
- **Sub-sections**: One `### [DATE] -- {Meeting Type}` per meeting (H3)
  - **Attendees**: Prose line
  - **Format**: Prose line
  - **Outcome**: Prose paragraph
  - **Feedback by Theme**: H3 with multiple H4 sub-sections, each containing:
    - Context paragraph
    - Bulleted feedback points (often quoted)
  - **Feedback Comparison** (optional): Cross-investor comparison table

#### Section 6: Action Items
- **Heading**: `## Action Items` (H2)
- **Content**: Table with columns: # | Action | Owner | Status | Source | Notes
- **Status values**: `DONE`, `NOT DONE`, `PARTIAL`, `UNKNOWN`

#### Section 7: Strategic Notes
- **Heading**: `## Strategic Notes` (H2)
- **Content**: Multiple bold-titled prose paragraphs analyzing implications

#### Section 8: Ecosystem Research (optional)
- **Heading**: `## Ecosystem Research` (H2)
- **Content**: H3 sub-sections for each entity, with prose + tables

#### Section 9: Corrections (optional)
- **Heading**: `## Corrections` (H2)
- **Content**: Prose + table of candidate replacement stats

#### Section 10: Raw Notes
- **Heading**: `## Raw Notes` (H2)
- **Content**: Preserved original content from before refactoring, labeled by source type
- **Sub-sections**: `### Source: {Source Type}` with original bullet points/text

### 3. CSV Column Mapping

The CSV has 22 columns. Here is the exact column order and mapping:

| # | CSV Column | YAML Field | Format Notes |
|---|-----------|------------|--------------|
| 1 | `Investor` | `investor_name` | Direct string |
| 2 | `Website` | `website` | Direct string (URL) |
| 3 | `Fund Size` | `fund_size` | Direct string |
| 4 | `Stage` | `stage` | Array joined with `", "` (e.g., `"pre-seed, seed"`) |
| 5 | `Geography` | `geography` | Direct string (may contain commas, quoted in CSV) |
| 6 | `Focus` | `focus` | Direct string |
| 7 | `Check Min` | `check_size_min` | Number (no dollar sign, no commas) |
| 8 | `Check Max` | `check_size_max` | Number (no dollar sign, no commas) |
| 9 | `Primary Contact` | `primary_contact` | Direct string |
| 10 | `Contact Role` | `primary_contact_role` | Direct string |
| 11 | `Pipeline Stage` | `pipeline_stage` | Direct string |
| 12 | `Last Touchpoint` | `last_touchpoint` | Date string (YYYY-MM-DD) |
| 13 | `Next Action` | `next_action` | Direct string (quoted if contains commas) |
| 14 | `Warm Intro` | `warm_intro` | Boolean as lowercase string (`true`/`false`) |
| 15 | `Referral Source` | `referral_source` | Direct string (empty if none) |
| 16 | `Fit Score` | `fit_score` | Number (1-5) |
| 17 | `Likely Role` | `likely_role` | Direct string |
| 18 | `Priority Action` | `priority_action` | Direct string (quoted if contains commas) |
| 19 | `Open Actions` | `open_actions` | Number (count of action items) |
| 20 | `Tags` | `tags` | Array joined with `", "` (e.g., `"ai-safety, mission-vc, pre-seed"`) |
| 21 | `Meeting Count` | *derived* | Number -- count of `meetings[]` array entries |
| 22 | `Last Meeting` | *derived* | Date -- `date` field of last entry in `meetings[]` |

**Derived columns** (21, 22): Not stored in frontmatter. Computed from `meetings[]` array when updating the CSV.

**Fields NOT in CSV** (in frontmatter only):
- `fund_number` -- fund identifier
- `structure` -- fund structure description
- `team[]` -- full team member list
- `strengths[]` -- detailed strength descriptions
- `gaps[]` -- detailed gap descriptions
- `meetings[]` -- full meeting log with attendees, feedback, outcome

**Array encoding**: YAML arrays (`stage`, `tags`) are joined with `", "` (comma-space) in the CSV. When parsing CSV back to YAML, split on `", "`.

### 4. File Naming Convention

**Pattern**: `YYYY-MM-DD_slug.md`

**Slug derivation**:
- Take the investor name (e.g., "Halcyon Ventures", "Celero Ventures")
- Extract the distinctive word (drop generic terms like "Ventures", "Capital", "Partners")
- Lowercase the result
- Examples:
  - "Halcyon Ventures" -> `halcyon`
  - "Celero Ventures" -> `celero`
- For multi-word distinctive names, use hyphens (e.g., "Blue Ocean Capital" -> `blue-ocean`)

**Date component**: Uses the date of the first/initial meeting with the investor.

**Multiple meetings**: If the same investor has a second meeting on a different date, the filename retains the original date (the file is updated, not duplicated). The `meetings[]` array in frontmatter tracks all meetings.

### 5. Design Recommendations

#### For `templates/meeting-format.md`

**Structure** (following existing template conventions from `contract-analysis.md` and `market-sizing.md`):

1. **Title and description**: What this template is for
2. **Output file format**: `YYYY-MM-DD_slug.md` naming convention
3. **Frontmatter schema**: Complete YAML frontmatter template with placeholders showing every field, type annotations in comments
4. **Body template**: Full markdown body in a fenced code block with all sections
5. **Section guidance**: Instructions for each section -- what goes where, what requires research vs. comes from notes
6. **Field generation rules**: Classification of fields by source:

| Source | Fields |
|--------|--------|
| User-provided (from meeting notes) | `investor_name`, `primary_contact`, `meetings[]` (attendees, raw feedback), `next_action` |
| Web research required | `website`, `fund_size`, `fund_number`, `portfolio_size`, `check_size_min/max`, `structure`, `team[]`, `geography`, `focus` |
| Agent-computed | `fit_score`, `likely_role`, `strengths[]`, `gaps[]`, `open_actions`, `priority_action`, `tags[]` |
| Default values | `warm_intro` (false), `referral_source` (""), `pipeline_stage` ("post-meeting") |

7. **Checklist**: Pre-delivery validation checklist

#### For `patterns/csv-tracker.md`

**Structure**:

1. **Title and description**: What the CSV tracker is and how it relates to meeting files
2. **Column specification**: Full 22-column schema with types and mapping to YAML fields
3. **Update patterns**: When and how to update the CSV:
   - After creating a new meeting file -> add a new row
   - After updating an existing meeting file -> update the existing row
   - Derived field computation rules (meeting_count, last_meeting)
4. **Array encoding**: How YAML arrays map to CSV values (join/split on `", "`)
5. **Quoting rules**: Which fields need CSV quoting (those containing commas)
6. **Sync invariants**: The CSV must always be in sync with the frontmatter of all meeting files in the directory
7. **Sort order**: Rows sorted by `Last Touchpoint` descending (most recent first)

#### Key Design Principles

1. **Template completeness**: Include every field and section, even optional ones, with clear `{placeholder}` markers and comments indicating when to omit
2. **Agent-consumable**: Use explicit type annotations and field descriptions so an agent can populate the template programmatically
3. **Raw notes preservation**: The template must include the `## Raw Notes` section -- this is the input that the agent refactors into structured content
4. **Bidirectional sync**: The CSV tracker pattern must clearly document the mapping between YAML frontmatter and CSV columns so an agent can update either from the other

## Decisions

- All frontmatter fields are marked as "Required" because both exemplar files include every field (even when values are empty strings or empty arrays)
- The `pipeline_stage` field uses kebab-case strings; the full enum should be documented in the template
- `fit_score` uses a 1-5 integer scale (not fractional)
- `check_size_min` and `check_size_max` are raw numbers (no dollar signs, no commas) for machine parseability
- The slug derivation drops generic suffixes ("Ventures", "Capital", "Partners") -- this should be documented as a rule

## Risks & Mitigations

- **Schema drift**: As more meeting files are created, new fields may emerge. Mitigation: document the schema as extensible and note that new fields should be added to both the template and CSV column spec
- **CSV quoting edge cases**: Fields with commas, quotes, or newlines need proper CSV escaping. Mitigation: document quoting rules explicitly in the CSV tracker pattern
- **Derived field staleness**: `Meeting Count` and `Last Meeting` in CSV can get out of sync if meetings are added to YAML but CSV is not updated. Mitigation: document the sync invariant and include it in the update pattern

## Appendix

### Search Queries Used

- File search: `find /home/benjamin/Projects -type f -name "*halcyon*"` (and similar for celero, VC-spreadsheet)
- Glob: `**/*` under founder extension context directory

### Source Files

- `/home/benjamin/Projects/Logos/Vision/shared/investors/VC/2026-04-07_halcyon.md` (303 lines)
- `/home/benjamin/Projects/Logos/Vision/shared/investors/VC/2026-04-08_celero.md` (423 lines)
- `/home/benjamin/Projects/Logos/Vision/shared/investors/VC/VC-spreadsheet.csv` (3 lines -- header + 2 data rows)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/templates/contract-analysis.md` (348 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/templates/market-sizing.md` (251 lines)
