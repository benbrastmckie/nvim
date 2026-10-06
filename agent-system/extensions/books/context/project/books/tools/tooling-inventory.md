# Tooling Inventory: What Each Piece Reads and Writes

Every figure below was measured on 2026-10-03 against the Logos/Verification tree at git
`7281c81`. Gap claims defer to `domain/known-gap-register.md`.

**`books/` is a tooling directory, not a component.** Nothing in it is digested, carries a
certificate, or is depended on by a component gate. That is why the certifier's own sources are
**excluded** from every book's `identity` -- including them would stale every book on every tool
edit (`domain/identity-and-versioning.md`).

**The pending rename.** `specs/170_rename_root_books_tooling_dir_to_bookkit/` is NOT STARTED.
Every path here is written in full so the rename is a mechanical replacement
(`domain/known-gap-register.md` B11).

## The six subdirectories

`books/` holds **six** subdirectories, not three.

| Path | Package | Reads | Writes | Extension's relation |
|---|---|---|---|---|
| `books/lean/` | `books` | Lean core only | the `.olean`s for `Books` and `BookCert` | **consumes** (every book-bearing package requires it) |
| `books/tool/` | `booksTool` | `book.toml`; built `.olean` headers | stdout reports; `book.read.json` | **consumes** (`books-tool`, via `/book`) |
| `books/certifier/` | (none -- a script) | the loaded environment, `book.toml`, a previous certificate, a docs report | `book.cert.json`, `DEPENDS.md` | **consumes** (via the certify driver) |
| `books/schema/` | -- | -- | -- | **cites as normative** |
| `books/scripts/` | -- | the tree, `book.toml` discovery, `books/book-convention.md` | the certificates (through the reader) | **consumes** (`books-certify.sh` forwards to `certify.sh`) |
| `books/tests/` | fixtures | the real tooling | nothing committed | **names, does not run** |

### `books/lean/` -- the metadata provider and the certifier library

Package `books`, licence `UNLICENSED`, `defaultTargets = ["Books", "BookCert"]`,
`[leanOptions] autoImplicit = false`. **Declares NO `require`**: the module builds against core
Lean alone (`public meta import Lean`), so a clean clone needs only the pinned toolchain -- no
Mathlib cache fetch, no network. The Mathlib-free boundary is therefore satisfied
**structurally, not by discipline**.

That `[leanOptions]` line is exactly what a certificate's
`lean_options_seed: ["autoImplicit=false"]` records -- see
`domain/certificate-ledger-and-records.md` for why the seed is read from the certified package's
own lakefile and from no other.

Two libraries, each with its own root:

| Library | Root | Modules | Measured |
|---|---|---|---|
| `Books` | `Books` | **one**: `Books.Meta` | **771 lines** |
| `BookCert` | `BookCert` | **eleven**: `Env`, `Sha256`, `Canon`, `Cone`, `Serial`, `Ledger`, `Reverify`, `Depends`, `Identity`, `VersionCheck`, `Writer` | -- |

**`Books.Meta` is 771 lines**, measured 2026-10-03. A figure of 413 is describing a much earlier
state; its own docstring (`:1-99`) is close to a complete context document in itself -- the
code-module/book-module split, why the provider is a private import, the five defence mechanisms
with what each **refuses versus only reports**, and the two universal rules standing outside the
matrix with the reason `book_layer` cannot enforce confinement.

Plus one executable: `[[lean_exe]] certify`, whose `root`/`srcDir` point at
`books/certifier/Certify.lean` -- **one certifier source, two execution paths**, with
`supportInterpreter = true` because the imported modules' `initialize` blocks (the provider's
environment extensions) run through the interpreter under `enableInitializersExecution`. **Not a
default target**: `certify.sh` builds it explicitly beside `BookCert`.

#### Why `BookCert` lives in the provider package (Decision 10)

**One structural reason**: every package that declares books already `require`s `books` from a
local path, so the certifier's imports resolve **structurally** under `lake env lean` inside any
consumer's workspace -- **no `LEAN_PATH` surgery, no per-consumer lakefile edit, and no generated
`lean_lib`** (which Decision 10 rejects outright). A separate tool package would need `LEAN_PATH`
prepended at every call site, "which silently resolves to a stale build when it is wrong".

Two conditions make it safe, both load-bearing: its **own library root `BookCert`, never `Books`**
(a second `Books` claimant in one workspace fails with `bad import 'Books.Meta'`), and **explicit
per-module `globs`**, so a new `BookCert` module must be added to the glob list by hand.

#### Why `Certify.lean` is a non-`module` script

`books/certifier/Certify.lean` (**1,141 lines**) is **not part of any library**. It is run as
`lake env lean --run <abs>/books/certifier/Certify.lean <subcommand>` from inside the certified
package's own workspace.

Decision 10 forces that shape: **a `module` library in this package cannot reach another
package's private `.olean` level, since `import all` is same-package only** -- and the *exported*
level hides the theorem kinds and docstrings the certifier needs. The script is **never built and
never imported**; `books/lean`'s `BookCert` target must be built **once** before the first
invocation, because `lake env` does not build a dependency's targets for you.

### `books/tool/` -- the validator and the environment walker

Package `booksTool`, one `lean_exe` `books-tool` over `Main.lean`, library root `Books` with
**three** modules: `Books.Manifest`, `Books.EnvWalk`, `Books.LayerCheck`. **Exactly one
`require`**: `books` from `../lean` by path, because the walker reads the provider's environment
extensions through their typed `getModuleEntries` and must link it. The TOML parser comes from
`Lake.Toml`/`Lake.Toml.Decode`, which are `public` in the bundled Lake and need no `require`.

**Three subcommands, not two** (`books/tool/Main.lean:185-187`):

| Subcommand | Shape | Reads | Writes |
|---|---|---|---|
| `validate` | `books-tool validate <book.toml> --lib <dir>` | a manifest, against `books/schema/book-toml-v2.md` | stdout: every offending key, sorted, with source positions |
| `check` | `books-tool check --lib <dir> [--only <module>]` | built `.olean` **headers** | stdout: module-to-book assignment, the observed layer relation, the import-matrix check as the record of truth |
| `levels` | `books-tool levels <base path>` | the built `.olean` levels under `<base path>` | stdout: one line per level -- `<level>: layers=[...] exports=[...]` (`books/tool/Main.lean:137-141`) |

`--lib` is **repeatable**; pass one per package.

Plus two shell scripts in the same directory:

| Script | Lines | Reads | Writes |
|---|---|---|---|
| `books/tool/docs-stage.sh` | 245 | `[docs] entry`, `typst/lib/phrases.toml`, the book's `book.record.json` | **the docs-stage JSON report on stdout -- NEVER committed** |
| `books/tool/record-read-test.sh` | 163 | -- | `book.read.json` beside `book.toml`; **the sole writer** |

`docs-stage.sh` is the **pack-measurement half only**. The certifier reads it through
`--docs-report` and combines it with the three inputs only the certifier has (the certificate's
own canonical bytes, the module-to-source-path map, and layer membership from `modules[].layer`),
"which is why the stage is split this way and why this script never computes
`context_pack_bytes` itself". See `standards/reconciliation-contract.md`.

**Named as absent, not inferred**: `books/tool/approve-guarantees.sh` (the only writer of
`book.record.json`) and `books/tool/book-health.sh --json` are **both missing**. They are planned
and named in `docs/development.md`. `domain/known-gap-register.md` B8.

### `books/schema/` -- the normative schemas

| File | Lines | Status |
|---|---|---|
| `books/schema/book-toml-v2.md` | 324 | normative for the authored manifest |
| `books/schema/book-cert-v2.md` | 689 | normative for the certificate |

Both exist. A claim that `book-cert-v2.md` is not yet landed is stale
(`domain/known-gap-register.md` B13).

### `books/scripts/`

| Script | Lines | Reads | Writes |
|---|---|---|---|
| `books/scripts/certify.sh` | 711 | `book.toml` discovery under the given roots; lakefiles; `/proc/meminfo`; an existing `book.cert.json` as `--prev` | certificates, through the reader; a run log on stdout |
| `books/scripts/lint-validated-by.sh` | 802 | the eighteen `Validated by` markers across `books/book-convention/NN-slug.md` (one per decision) plus any remaining in the flat `books/book-convention.md` index, and every path/Lean name/filename they cite | findings on stdout; **two of its four checks are blocking** |

`lint-validated-by.sh` is what makes `domain/known-gap-register.md` a projection of a *linted*
record rather than of free prose: CHECK 1 (marker presence and well-formedness) and CHECK 2
(instance liveness) are blocking; CHECK 3 and CHECK 4 are advisory heuristics.

### `books/tests/` -- four suites

| Suite | Lines | What it drives |
|---|---|---|
| `books/tests/manifest/run.sh` | 521 | the provider, the validator and the walker, over **twenty-seven** cases and **twenty** probe fixtures |
| `books/tests/certify/run.sh` | 1,338 | the certifier end to end, including the VERSION and POLICY-VACUOUS cases |
| `books/tests/validated-by-lint/run.sh` | 272 | all four `lint-validated-by.sh` checks against eleven record fixtures |
| `books/tests/layer/` (via `interface/tests/layer/run.sh`) | -- | the regex rule set, **extracted verbatim** |

The manifest suite's own discipline is worth copying: **no copy of the provider's rules lives in
the harness.** Every case drives the real `lake build`, the real `lean` elaborator and the real
`books-tool` executable, so a rule that drifts in the provider drifts in the suite too. See
`standards/forgery-probe-discipline.md`.

## Three authoring rules for anything under `books/`

1. **The proprietary header within the first three lines of every `.lean` and `.sh`** -- and in a
   `module` file, the **comment on line 1 and `module` on line 2**, because a comment parses ahead
   of the `module` keyword. Enforced by `components/framed_channel/scripts/check-spdx.sh`
   (123 lines), whose extension list is `rs|lean|sh|py|typ|css|js|mjs|ts`. Markdown is **not**
   scanned, so the `.md` files under `books/` need no header.

2. **Explicit per-module lakefile `globs`, NEVER `Books.+`.** Both `books/lean` and `books/tool`
   use the library root `Books`, and `books/tool` necessarily `require`s `books/lean` by path. A
   `Books.+` glob in either package makes it claim the other's modules and the build fails with
   the exact text:

   ```
   error: Books: some modules have bad imports
     bad import 'Books.Meta'
   ```

   So: `globs = ["Books.Meta"]` in `books/lean`;
   `globs = ["Books.Manifest", "Books.EnvWalk", "Books.LayerCheck"]` in `books/tool`; and the
   eleven-entry explicit list for `BookCert`. **A new module must be added by hand** -- that is
   the cost of the shared root, and it is cheaper than the failure above.

3. **Fixture packages use library roots DISTINCT from `Books`**, for the same reason.

## Repo-side documentation machinery: know it, do NOT duplicate it

All measured 2026-10-03. **`typst/manual/generated/` is every-file-generated and never
hand-edited** -- it holds `certificate-export.json`, `certificate-export.typ`, `components/`,
`script-reference.typ`, `status.typ` and its own `README.md`.

| Script | Lines | Produces / checks |
|---|---|---|
| `typst/scripts/build.sh` | -- | **the sole caller of `typst compile`** in the tree; resolves the repository root and passes it as an explicit `--root` |
| `typst/scripts/typst-component-doc.sh` | 338 | per-component generated documentation |
| `typst/scripts/typst-component-index.sh` | 156 | the component index |
| `typst/scripts/status-counts.sh` | 435 | `status.typ` |
| `typst/scripts/script-reference.sh` | 257 | `script-reference.typ` |
| `typst/scripts/certificate-export.sh` | 407 | `certificate-export.{json,typ}` |
| `typst/scripts/typst-manual-sync-check.sh` | 160 | **regenerate-and-diff**: exits non-zero **naming the file and its exact regeneration command** |
| `typst/scripts/chapter-drift.sh` | 382 | drift findings -- **non-blocking by design**, with `--mark` left to the person |
| `typst/scripts/name-resolution-check.sh` | 173 | name resolution across the manual |

The typst extension additionally ships `typst-element-lint.sh` and `chapter-quality-check.sh`.
**Do not reimplement any of the above**: a books document stage that recomputes what
`typst-manual-sync-check.sh` already checks becomes a second source of truth, which is the failure
mode `patterns/gate-collision-ledger.md` records for pre-gate tiers generally.

One recorded caveat, from the family dispatch: `typst/scripts/script-reference.sh` **could not
run** at the time (failing on a non-conforming header in an archived fixture), leaving
`typst/manual/generated/script-reference.typ` stale. The retrospective's judgment is worth
carrying: **"a generated doc that cannot be regenerated is worse than no generated doc."**

## Related

- `patterns/authoring-workflow.md` -- which stage calls which tool.
- `tools/certify-guide.md` -- operating `books/scripts/certify.sh`.
- `tools/typst-template-contract.md` -- `typst/lib/book.typ` and `typst/scripts/build.sh`.
- `standards/forgery-probe-discipline.md` -- the test suites' discipline.
- `domain/known-gap-register.md` -- B8, B11, B13.
