# The Outline Language

The outline file (`outline.txt`) is a plain-text file where each line is a
**content entry**, a **directive**, a **comment**, or blank. Content entries
define the document structure; their order in the file is the order of the
book. Directives set rendering state that applies to subsequent content
entries of the same prefix.

**Design intent.** UUIDs are pure identity: they are never renumbered, and
nothing may be inferred from their digits. All numbering (Chapter 3,
Warrant 42, Title I, Appendix B, §2) is computed from row position at build
time. To insert, delete, or reorder anything, edit `outline.txt`; every
number and every cross-reference in the prose updates on the next build.
Titles can change freely; content stays attached to the UUID.

**Authority.** If it is not in the outline, it is not in the book. Order is
determined by outline row position and nothing else. Filenames carry no
structural meaning.

---

## Line format

```
prefix:uuid<whitespace>title        content entry
prefix:name:value                   directive
```

On every line the final field is greedy to end of line: a content entry's
title and a directive's value both run to EOL, so labels may contain spaces.
There is no trailing-comment syntax. Lines whose first non-blank character
is `#` are comments; blank lines are ignored.

---

## Content entries

```
prefix:uuid<whitespace>title
```

The prefix is a single letter determining the structural kind:

| Prefix | Kind | Renders as | Default label | Default numbering |
|---|---|---|---|---|
| `c` | chapter | "Chapter N" | `Chapter` | `arabic` |
| `p` | part | "Part III" | `Part` | `roman` |
| `a` | appendix | "Appendix A" | `Appendix` | `letter` |
| `d` | division | unnumbered | — | — |
| `n` | unlisted | unnumbered | — | — |
| `s` | section | "§N" | — | `arabic` |
| `k` | sub-entry | "§N.M" | — | — |

**UUID.** Five digits (or `NNNNN.MINOR` for a sub-entry). Unique across the
outline. A UUID is opaque identity: its digits are immaterial to rendering.

**Title.** Display text. Do not bake the computed designation into the title
(write `Angelic Governance and Guidance`, not `Warrant 1 — Angelic
Governance and Guidance`); the label and number are the machinery's job.

**Sections** (`s`) are children of the nearest preceding chapter or division.
The section counter resets at each chapter/division boundary. Sections are
typically inline headings within the parent's source file, not files of their
own.

**Sub-entries** (`k`) are the nearest chapter's sub-structure, rendered `§N.M`
where `N` is the chapter number and `M` the minor. The `NNNNN.MINOR` UUID
binds them to their parent chapter by the `NNNNN` part.

**Divisions** (`d`) are unnumbered structural markers (prologue, coda, end
papers). They appear in the TOC but render without label or number. A
cross-reference to a division renders its title.

**Unlisted** (`n`) entries are identical to divisions except never listed in
the TOC, for front matter, colophons, and other apparatus that should not
announce itself.

---

## Directives

```
prefix:directive[:value]
```

Directives have no title. **Directives are positional**: each one changes the
state for entries of that prefix that appear after it in the file, until
changed by another directive. The state in force at an entry's position is
snapshotted onto that entry, so a cross-reference always renders with the
regime in force at the target's position.

Five keywords: `label`, `number`, `count`, `default`, `none`.

**`label`** sets the display label, and optionally a short form after `|`.

```
c:label:Warrant       → "Warrant 1", "Warrant 2", ...
c:label:Warrant|Wt    → "Warrant 1"; the short form renders "Wt 1"
c:label:Old Law       → "Old Law 1", "Old Law 2", ...
c:label:              → empty value: no label, renders as just "1"
```

Setting a label does not reset the counter. Start a new regime explicitly
with `count`:

```
c:label:Warrant
c:count:1
```

**`number`** sets the numbering style (`arab` is an alias for `arabic`).
Unknown styles are an error.

```
c:number:arabic       → 1, 2, 3, ...
c:number:roman        → I, II, III, ...
c:number:roman-lower  → i, ii, iii, ...
c:number:letter       → A, B, C, ...
c:number:none         → no number displayed
```

**`count`** sets the number of the next entry (one-shot; counting continues
from there). The value must be an integer.

**`default`** resets a property to the kind default:

```
c:default:label       → label back to "Chapter" (or "Part", "Appendix")
c:default:number      → style back to the kind default
c:default:count       → next entry numbered 1
c:default:title       → titles displayed again (undoes none:title)
d:default:toc         → entries listed in the TOC again (undoes none:toc)
```

**`none`** suppresses a property:

```
c:none:label          → no label (same effect as c:label:)
c:none:number         → no number (same as c:number:none)
c:none:title          → designation only, no title text
d:none:toc            → subsequent entries omitted from the TOC
```

`c:label:none` sets the label to the literal word "none" (a warning, because
it is almost always a mistake). The suppression forms are `c:none:label` or
`c:label:`.

---

## Cross-reference tokens

Source files use `{{token}}` for cross-references, resolved at build time. A
reference renders using the regime in force at the target's position in the
outline, so `{{c:00042}}` renders "Chapter 42" if UUID 00042 sits in a
`Chapter` regime and "Warrant 42" if it sits after `c:label:Warrant`.

```
{{c:00042}}           → "Chapter 42" / "Warrant 42" (regime at target)
{{c:00042|n}}         → "42" (number only)
{{c:00042|s}}         → "Ch 42" / "Wt 42" (short label at target)
{{p:00100}}           → "Part I" / "Title I"
{{a:00200}}           → "Appendix A"
{{s:00300}}           → "§3"
{{cc:00001,00002}}    → "Chapters 1 and 2" / "Warrants 1 and 2"
{{cc:...|sort}}       → same, sorted by number
{{d:02000}}           → the division's title
{{toc}}               → the generated Table of Contents
```

The prefix in a token is redundant with the UUID's kind, deliberately: a
mismatch is a build error, so the prefix is a checksum against typo'd UUIDs.
A reference never renders as empty text; unlabeled, unnumbered targets fall
back to their title.

### Page references

Page numbers are never written by hand:

```
{{c:10042|page}}      → the page where that entry begins
{{page:10042}}        → same, addressed by bare UUID
{{anchor:90001}}      → an invisible anchor at this spot in the prose
{{page:90001}}        → the page that anchor landed on
```

Page refs compile to native Typst `locate()` lookups: one document, one pass,
always exact.

---

## Errors and the file map

buildabook maps outline entries to source files by reading each `.md` file's
first `# ` heading and matching the full token (`c:00001`) against it. The
build fails before writing anything if a source file's heading matches no
outline token, if a heading matches two tokens, if two files claim one token,
or if the outline is malformed (duplicate UUID, unknown prefix, unknown
directive value, non-integer count, a line that parses as neither entry nor
directive).

An outline entry with no matching source file is a warning, not an error: the
entry produces no pages yet. Unresolvable `{{tokens}}` in prose are reported
with file and line, rendered as `{{ERROR:...}}`, and fail the build.

---

## The template

buildabook ships a default Typst template (`template/book.typ`). A book may
override it, but the engine requires this coupling contract of any template:

* define `book-title`, `running-title`, `fm-pages`, and `body-pages`
* define `chapter(path, token, part, toc)`
* define `pgan(id)` and `pageof(id)`
* import cmarker

The template owns front matter and TOC styling; the engine injects the
metadata bindings and the `#chapter(...)` calls.

---

## Example

```
# ── Frame: unlabeled parts; plain "Chapter N" chapters ──
p:none:label
p:none:number
p:00100    The Frame of Things
c:01001    The Hierarchy of Being
c:01002    Israel Among the Nations
d:03000    Prologue of Primal Warrants

# ── The ten books: Title I..X, Warrant 1..120 ──
p:label:Title
p:number:roman
p:count:1
p:04000    God & The Celestial Hierarchy
c:label:Warrant|Wt
c:count:1
c:10001    Angelic Governance and Guidance
c:10002    Divine Judgment Executed by Celestial Beings
k:10001.1  Stack 2.1: Mathematics
```

Inserting a new warrant between the first two is one line with a fresh UUID;
on the next build it renders as Warrant 2, the next becomes Warrant 3, and
every `{{c:10002}}` in the prose follows automatically.

---

## Build pipeline

```
chapters/*.md + outline.txt + filemap.txt
      │
buildabook render   resolves every {{token}} → rendered/*.md + rendered/book.typ
      │
typst compile rendered/book.typ   →   the PDF
```

One source, one document, one pass. `buildabook number-map` writes a CSV of
every entry's UUID, kind, title, snapshotted regime, computed number, and
rendered designation.
