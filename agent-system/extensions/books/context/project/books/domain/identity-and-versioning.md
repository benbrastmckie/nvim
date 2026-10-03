# Identity, Chaining, and the Versioning Rule

A book's identity is computed from the bottom up: a digest per **export**, rolled into three
book-level identities, chained per export through dependencies' certificates. The version rule is
keyed on the **canonical statement serialisation**, which is why a Lean toolchain bump alone
requires no bump at all.

**Normative source**: `books/schema/book-cert-v2.md`. **Design record**:
`docs/book-convention.md` Decision 9 (`:1093-1213`) and Decision 11 (`:1367-1497`).
**Implementation**: `books/lean/BookCert/{Cone,Serial,Ledger,Identity,VersionCheck}.lean`. Gap
claims defer to `domain/known-gap-register.md`.

## The framing: `H` and `S`

Two primitives do all the work.

`H(tag, f_1 ... f_n)` is **sha256 over a length-framed pre-image with a domain tag as its first
field** (`books/schema/book-cert-v2.md:62-77`):

```
frame(f)           = <decimal UTF-8 byte length of f> ":" f ","
preimage(tag, f..) = frame(tag) ++ frame(f_1) ++ ... ++ frame(f_n)
H(tag, f..)        = sha256(preimage(tag, f..))
```

The byte-length prefix makes each field self-delimiting, so no two distinct field sequences share
a pre-image and `H(a, b)` cannot collide with `H(a', b')` under a different split. The domain tag
means two different formulas over coincidentally equal fields cannot collide either. **A consumer
recomputing a digest needs this framing**, which is why the schema states it rather than leaving
it in the code.

sha256 is implemented in Lean (`books/lean/BookCert/Sha256.lean`) because the pinned toolchain
ships none. **`Lake.Hash`/`mixHash` is never a substitute**: a 64-bit non-cryptographic fold is a
change *detector*, and Decision 9's point is that an unrelated edit is *provably* irrelevant
rather than assumed so.

`S` is the canonical kernel-term serialisation. Measured on this tree,
`serialisation_format: "dag-v2"`.

## The digest formulas, verbatim

With `^` meaning "sorted by the underlying constant names", and `coneStmt`/`coneProof` the
statement and proof cones:

```
statementKey(e)     = H("export-key",   name, kind, isInstance, arity, S(type),
                                        S(value) | "-" when e is not a theorem)
coneKey(e)          = H("export-cone",  [contentDigest(m) | m in coneStmt(e)]^)
contentDigest(n)    = H("const",        name, kind, arity, S(type), S(value) | "-")
constDigest(n)      = H("const-cone",   name, contentDigest(n),
                                        [contentDigest(m) | m in coneStmt(n)]^)
digest(e)           = H("export-stmt",  name, kind, isInstance, arity, S(type),
                                        S(value) | "-" when e is not a theorem,
                                        [contentDigest(m) | m in coneStmt(e)]^,
                                        axioms(e)^)
proof_digest(e)     = H("export-proof", name, kind, isInstance, arity, S(type), S(value) | "-",
                                        [contentDigest(m) | m in coneProof(e)]^,
                                        axioms(e)^)
interface_identity  = H("interface",       [digest(e)       | e in exports]^)
proof_identity      = H("proof-interface", [proof_digest(e) | e in exports]^)
identity            = H("identity",     [path ++ " " ++ sha256(file) | own sources]^,
                                        toolchain fields in order,
                                        normalised book.toml fields in order,
                                        interface_identity,
                                        [book ++ " " ++ its interface_identity | deps]^)
```

Two properties of that block are load-bearing and were each **added by measurement**.

**An export is a member of its own statement cone.** The `S(value)`-for-a-non-theorem clause in
`digest` is what makes that true. Without it, an exported definition's own body is an input to
every *dependent's* digest and to **none of its own**: measured, editing an `@[expose] def`'s body
left that export's own digest bit-identical while moving both a theorem-about-it's and a
dependent composite's. Since `interface_identity` is the hash of the sorted export digests, the
part book's interface identity would not have moved while every dependent's did. Theorems
contribute no value either way, which is **what preserves the proof-only-edit property**.

**The Merkle recursion is flattened, deliberately.** Decision 9 words a constant's digest
recursively over "digests of its own cone". Read literally that **does not terminate** -- Lean
constants form mutually recursive families. Each cone member's *own content* (`contentDigest`, not
recursive) is hashed instead, over the already-transitive cone. That is equivalent in the property
the record cares about: a change anywhere in the cone moves the root. What it does **not**
reproduce is path sensitivity, and no source edit produces two cone *shapes* over identical
constant contents.

## Three identities, not two

| Identity | Formula input | Role |
|---|---|---|
| `interface_identity` | the sorted statement digests | **the chaining key** -- this is what a dependent's `identity` consumes |
| `proof_identity` | the sorted proof digests | **informational; never the chaining key** |
| `identity` | own sources, toolchain, normalised `book.toml`, `interface_identity`, and each dependency's `interface_identity` | the book's **own freshness key** |

Measured 2026-10-03 on `interface/books/result/book.cert.json`: all three present at the top
level. A description of this system with **two** identities is describing an earlier shape.

Decision 9's own marker records one contradiction: "the `identity` formula omits the direct
dependencies' `interface_identity` input". Read the implementation
(`books/lean/BookCert/Identity.lean`), not the formula block above, when a dependency change does
not move an identity you expected it to. Recorded in `domain/known-gap-register.md`, Part A.

## Chaining: through the interface, never through the files

**A dependency's interface files are reached through its `interface_identity`, never hashed
directly. That is the whole point of chaining.** It is strictly finer than hashing a dependency's
files, because a **proof-only edit in a dependency moves its files and not its interface** -- so
it does not stale this book.

Per export, `depends[].exports_used[]` records the dependency export's `name`, its own
`digest` recomputed here, and `statement_level` -- `true` when our statement cone reaches it,
`false` when only our proof does. That flag is computable **only because the certifier imports at
`OLeanLevel.private`**, where an imported theorem carries its value; at `.exported` or `.server`
both cones coincide and the flag would be a constant `true`.

## Why sharing-awareness matters: the measured instance

`S` is a **sharing-aware DAG** encoding (`dag-v2`), not a tree encoding. The measurement that
forced it, from `specs/177_research_build_and_certification_efficiency/`:

> `S(crc8_step_linear)` was a measured **9,263,152,983-node unshared tree**. Under `dag-v2` it is
> **420,646 characters**. `FramedChannelAeneas.Book.Crc8` had been killed by `earlyoom` three
> times, at 16-18 GiB after 35+ minutes across four dispatches; after the serialiser landed it
> certified in **under two minutes**, first attempt -- 53 exports, 6 modules, 0 refusals, 0
> warnings, needing no new `book_requires` line.

That is the clearest case in the evidence base of restructuring buying exactly what it was
supposed to buy. The operational consequence for a reader: a certification that appears to hang
on a large arithmetic proof is not necessarily a certifier bug -- but it is also no longer the
expected behaviour, and `tools/certify-guide.md` records how a killed run is (mis)reported.

The amended `S` carries four self-checks -- `sharing-invariance`, `sharing-shape`, `dag-size` and
`fixed-vectors` (`books/lean/BookCert/Serial.lean`), exercised by the certify suite -- so a
serialiser regression surfaces as a `self-check` or `serial-check` refusal rather than as a
silently wrong digest.

## The versioning rule

Decision 11's table, transcribed from `books/schema/book-cert-v2.md:577-590`:

| Change | Required `book.version` bump |
|---|---|
| An export is removed, or an export's statement digest changes | **major** |
| An export is added | **minor** |
| Proofs, private or non-exposed bodies, docstrings, prose or `book.toml` judgments change, with every export's statement digest unchanged | **patch, optional** |
| A Lean toolchain bump alone, with every statement digest unchanged | **none** |
| The canonical serialisation `S` itself is amended | **none** -- a re-digest, not a version event |

**The check diffs ledgers, not text.** `digest` folds three independent things together -- the
export's own statement, its statement cone's contents, and its axiom set -- which the table treats
differently. So the diff reads `statement_key` and `cone_key` to **attribute** a change rather
than guess:

- `statement_key` moved -> the export's own statement or exposed body changed -> **major**;
- `cone_key` moved -> something the statement reaches changed -> **major**;
- only `axioms` moved -> the axiom rule.

**The axiom rule.** An export whose axiom set changes *within* the `book_axioms` permitted set
needs **no bump** and is recorded. An axiom **outside** the permitted set is a **certifier
failure, never a version event**.

**One predicate, with one measured exception.** "Interface identity changed" and "a bump is
required" are the same predicate -- *except* on a within-permitted-set axiom change, because the
axiom set is a field of `digest`. Decision 11's two clauses contradict each other on exactly that
change, resolved as: the **axiom rule wins the version verdict**, while `interface_identity`
**still moves** so every dependent is staled and re-certified (correctly -- a dependent's own
axiom set is computed from its own cone). The certifier **reports the divergence by name**; any
*other* divergence is reported as a defect in the diff or the formula, **not waved through**.

### No bump on a toolchain bump alone -- and the one UNVERIFIED case

`identity` changing with `book.version` unchanged is the **expected, valid signature** of a
toolchain-only bump.

The schema records one case as explicitly **UNVERIFIED**: whether the statement-cone *closure*
digests -- the values of reached `Init` constants -- survive a toolchain bump "is **not settled**.
It needs two toolchains and only one was available." If it fires, it appears as `cone_key` moved
with `statement_key` and `text` unchanged, which is a **distinguishable signature** rather than an
unexplained major bump. On a toolchain bump the certifier reports **both** reviewer diffs -- the
pretty-text diff (expected empty) and the statement-digest diff (expected empty unless this case
fires) -- and the reviewer reads them. Do not resolve that case by assertion.

### A serialisation-format change

The bytes of `S` are every digest's input, so amending `S` re-keys every `statement_key`,
`cone_key`, `digest` and `proof_digest` **with no statement having changed**. The check reads the
previous certificate's `serialisation_format` (absent -> `tree-v1`) and, when it differs,
attributes **no** key move to a statement, cone or proof edit -- the row verdicts come from the
pretty text, the axiom sets and the export set alone, which `S` does not touch -- and reports,
beside `bump=none`:

```
serialisation format changed: tree-v1 -> dag-v2; every statement_key re-keyed under the amended
Decision 11; bump=none (re-digest)
```

`interface_identity` still moves (it hashes the re-keyed digests) and the one-predicate findings
are not raised for that move. Every *other* divergence in the same diff -- an export added or
removed, a changed text, a changed axiom set -- **is reported exactly as before, so a statement
edit cannot hide behind a re-digest**. The re-digest obligation itself (every committed
certificate regenerated in the same change as the serialiser) is Decision 11's.

## What `identity` covers, and the five exclusions

`identity` covers **inputs only, never generated outputs**: the certificate never digests itself
and never digests `DEPENDS.md`. Both are outputs, and a field covering them could not be computed
before they were written.

The exclusions are a **deliberate change** from `components/*/scripts/certificate-identity.sh`,
which hashes a whole component tree, flake files included
(`books/schema/book-cert-v2.md:641-668`):

| Excluded | Why |
|---|---|
| the certifier's own sources (`books/lean/BookCert/**`, `books/certifier/**`, `books/scripts/**`) | including them would stale **every** book on **every** tool edit -- the pathology this design exists to remove. The certifier's own correctness is the recheck legs' business |
| `flake.nix`, `flake.lock` | the toolchain is pinned by `lean-toolchain` and recorded in the toolchain field; the flake additionally pins host tooling that cannot change a `.olean` |
| local path dependencies (the provider, the certifier library) | a book's dependence on another **book** is covered by that book's `interface_identity`, chained in -- strictly finer than hashing its files |
| this book's own `book.cert.json` and `DEPENDS.md` | outputs |
| `book.record.json` and `book.read.json` | non-digested by construction, and **confirmed by measurement**: writing all five read-test records left every one of the five certificates' `identity` unchanged |

Two mechanics of the source half:

- **Source digests are over the book's own module files, sorted by path relative to the package
  directory.** An absolute path would make the identity depend on where the repository happens to
  live.
- **The source path follows Lake's default convention** (`Foo.Bar` at `<pkgDir>/Foo/Bar.lean`). A
  package with a non-default `srcDir` is **reported as a missing source rather than silently
  skipped**, because `lake env lean` exports `LEAN_PATH` and not `LEAN_SRC_PATH`. That is the
  `missing-source` refusal.
- **`book.toml` is normalised by hashing its decoded fields in a fixed order, not its bytes**: a
  comment, a key reordering or a whitespace change must not move a book's identity.

## Related

- `domain/certificate-ledger-and-records.md` -- the ledger row's `digest`/`statement_key`/
  `cone_key` fields, and why the certificate is byte-stable.
- `domain/status-and-trust-vocabularies.md` -- the `stale` verdict this machinery produces.
- `tools/certify-guide.md` -- running the version check as a ledger diff.
