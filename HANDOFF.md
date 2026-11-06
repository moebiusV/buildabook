# Handoff: HTML build and book.conf metadata

Working note for resuming on the machine that has the other books (speedrun,
recheboc). Not part of the site: `_config.yml` excludes it from Jekyll.

Written 2026-11-06. State of buildabook: `main` at the commit that adds this file;
the html work itself is in `8be90f3` and `0f3b201`.

## What is done and pushed

buildabook (this repo):

- `buildabook html` renders the same chapters and numbering as the PDF with an
  HTML template, into `rendered/book-html.typ` (so `rendered/book.typ` is left
  alone), then runs `typst compile --features html --format html` to `<slug>.html`.
- The template is `book.html.typ` beside `book.conf`, or `html-template` in the
  `build` block of `book.conf`. The default to copy is `template/book.html.typ`.
- `Build.Render` has an optional last parameter, `Book_Name` (default `book.typ`).
- `buildabook readme`: when `<slug>.html` exists it adds an HTML row to the
  download table and links the contents of the book to the chapters in that page.
  "Of the book" means the files named in `filemap.txt`; other entries (for example
  jacket copy) keep their link to the Markdown source. `Write_Readme` has a new
  optional `Filemap` parameter, which the CLI passes.
- Anchor rule, shared by the templates and the README generator: a chapter's
  heading id is `ch-` plus the file name without `.md`, with anything but letters,
  digits, `_` and `-` turned into `-`. Typst writes a label as an element id only
  when it is a plain identifier (no leading digit, no `.` or `:`), and only for a
  label that something links to (the contents list does).
- Tests: 14 pass (two new: html render name, readme links). Man page, README,
  LANGUAGE.md and NEWS describe the stage.

papers (viking-poets), `406b63c`: `book.html.typ`, a Makefile `html` target, the
committed `viking-poets.html`, and a regenerated `README.md` whose contents link to
`viking-poets.html#ch-...`. The chapter sources are excluded from Jekyll.

## What Typst's HTML export does (found by experiment, typst 0.15.1)

- Needs `--features html`; Typst calls the export "under active development and
  incomplete".
- `align`, `pad`, `grid`, `line`, `v`, `pagebreak`, `flush` and `set page` are
  "ignored", and for the first four that means the contents are dropped too. This
  is why a paged template shows no chapter titles, title page or block quotes in
  HTML. `block`, `box`, `par`, `text`, tables, footnotes, links, outline and
  `html.elem(...)` work.
- `set document(title:, author:)` gives the `<title>`; math becomes MathML; a
  heading of level N becomes `<h(N+1)>`; `quote(block: true)` becomes `<blockquote>`.
- cmarker treats Markdown blockquotes as plain text unless given `blockquote:`; the
  HTML templates pass `blockquote: it => html.elem("blockquote", it)`.
- `--format bundle` (several files) rejects top-level `pagebreak`, `flush`, `v` and
  `align`, so it would need a bundle-aware template. Not attempted.
- The output is one HTML file, not one page per chapter.

## Not done, on purpose

1. Metadata from `book.conf` for the templates. `book.conf` has title, subtitle,
   tagline, author, year, publisher, city, isbn, and `Config` parses them, but
   nothing reads them; each template hard-codes its own copy. Design: the CLI adds
   `--input title=... --input author=...` to the `typst compile` call of the `pdf`
   and `html` stages (only for keys the book sets), and a template reads
   `sys.inputs.at("title", default: "<its old literal>")`. A template that still
   defines `#let book-title = ...` ignores the inputs, so nothing changes until a
   book migrates. Also fix `Sh_Quote` in `buildabook_cli.adb`: it does not escape a
   `'`, so a title like "Doesn't" would break the shell command. A first patch for
   this failed on a typo and was not applied.
2. Migrating any template. Decided: do not touch speedrun's or recheboc's templates
   or front matter; give a note of the lines to change and let the owner apply it.
3. A shared HTML library (CSS, footnotes, anchors, chapter engine in one imported
   file) so each book's `book.html.typ` is a few lines. The default and
   viking-poets' HTML templates differ by about 88 non-comment lines. Whether
   `#import` works from the generated `rendered/book-html.typ` to a file in another
   directory is untested.

## First steps on the other box

1. Build this version of buildabook and keep the old binary.
2. For recheboc and speedrun, run `buildabook typst` with the old and the new binary
   and diff the two `rendered/book.typ` files byte for byte. That shows the front
   matter and the paged path are unchanged before anything is rebuilt.
3. Run `buildabook html` on a copy of each book with the default HTML template.
   Watch for layout calls (`align`, `pad`, `v`), anything page-dependent, and any
   `{{page:...}}` reference (the default `pageof` links to an anchor instead of
   printing a number).
4. Then decide on item 1 above.

## Building and testing

Built in the `ada-toolchain:edge` image (the README names it):

    docker run --rm -v "$PWD":/src -w /src ada-toolchain:edge sh -c \
      'gprbuild -P buildabook.gpr -q && gprbuild -P tests/tests.gpr -p -q && ./tests/tests'

An end-to-end run needs `typst` on the path (a static release binary is enough) and
the cmarker package, which Typst downloads on first use.

## Loose ends

- `chapters/blurb_jacket_copy.md` in viking-poets is listed in its README but is not
  in the book; its link goes to the Markdown source, which is excluded from the Pages
  site, so it works on github.com and returns 404 on the site.
- The README generator still writes an em dash and
  middle dots in its contents lines, as it did before; only the link targets changed.
- hbnf's Markdown-to-HTML renderer (`corpus/markdown/html.c`) has known gaps (marks
  that run over a line break, raw HTML and comments, entities, escaped pipes in table
  cells, double-backtick code spans). Nothing publishes with it now.
