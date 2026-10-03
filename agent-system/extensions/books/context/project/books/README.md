# Books Domain Context (Navigation Stub)

This directory is a navigation stub, not the domain corpus. The `books` task type covers
authoring, certifying and documenting **lean books** as defined by the Logos/Verification
repository's `docs/book-convention.md` design record: a certified unit inside a Lake package,
named by a `book <Name>` command in its own book module, whose metadata splits facts (Lean
annotations: `@[book_export]`, `book_layer`) from judgments (`book.toml`) with everything else
computed by the certifier into `book.cert.json`.

The full domain corpus — layer-matrix detail, `book.toml`/`book.cert.json` schema walkthroughs,
certifier invocation patterns, and the manual/chapter-quality conventions for book documentation
— is authored by a separate, dependent task and will extend this directory. Until that lands,
agents and skills in this extension reference paths under `context/project/books/...` as plain
backticked pointers (never eager `@`-imports); a missing file at one of those paths is expected,
not a defect, until the corpus task completes.

For the normative design record itself (owned by the consuming repository, not this extension),
see `docs/book-convention.md` and `books/schema/book-toml-v2.md` in the Logos/Verification
repository.
