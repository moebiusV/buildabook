// ═══════════════════════════════════════════════════════════════════
//  buildabook — shared Typst template
//  Compile with:  typst compile rendered/book.typ <slug>.pdf
//
//  This is the default template buildabook emits.  It owns the metadata,
//  the page geometry, the typography, the markdown→Typst engine, the
//  front matter, and the `chapter(path, token, part, toc)` function that
//  buildabook's generated book.typ calls once per outline entry.
//
//  A book overrides it by pointing book.conf at its own template; the only
//  contract buildabook requires is that the template define:
//    book-title   running-title   fm-pages   body-pages
//    chapter(path, token, part, toc)   pgan(id)   pageof(id)
//  and import cmarker's `render`.
// ═══════════════════════════════════════════════════════════════════

#import "@preview/cmarker:0.1.1": render

// ─────────────────────────────────────────────────────────────────
//  METADATA  (per-book values; edit or override in book.conf)
// ─────────────────────────────────────────────────────────────────

#let book-title     = "Untitled"
#let book-subtitle  = ""
#let book-tagline   = ""
#let book-author    = ""
#let book-year      = "2026"
#let book-publisher = ""
#let book-city      = ""
#let book-isbn      = ""

#set document(title: book-title, author: book-author)

// ─────────────────────────────────────────────────────────────────
//  PAGE ANCHORS
// ─────────────────────────────────────────────────────────────────

// pgan plants an invisible native label at a spot in the document;
// pageof reads the displayed page number where that label landed, via
// locate().  buildabook emits these for every chapter heading, every
// tokenized § heading, and every {{anchor:…}} — so {{page:…}} refs
// resolve natively in the single compile pass.
#let pgan(id) = [#metadata(none)#label("pg-" + id)]
#let pageof(id) = context {
  str(counter(page).at(locate(label("pg-" + id))).first())
}

// ─────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────

// Full title from a Markdown file's first H1 line.
#let md-title(src) = {
  let line = src.split("\n").find(l => l.starts-with("# "))
  if line != none { line.slice(2).trim() } else { "" }
}

// Everything before the first H1 — raw Typst, executed before markdown.
// Lets a chapter's preamble carry title pages, plate layouts, or other
// raw-Typst front matter.
#let md-preamble(src) = {
  let lines = src.split("\n")
  let idx   = lines.position(l => l.starts-with("# "))
  if idx != none and idx > 0 { lines.slice(0, idx).join("\n") } else { "" }
}

// Everything after the first H1 (the body text).
#let md-body(src) = {
  let lines = src.split("\n")
  let idx   = lines.position(l => l.starts-with("# "))
  if idx != none { lines.slice(idx + 1).join("\n") } else { src }
}

// Running-header title: strip the "Chapter N — "/"Part I — "/"Warrant N — "
// prefix (this project uses em-dash separators rather than colons).
#let md-short-title(src) = {
  let full  = md-title(src)
  let parts = full.split(" — ")
  if parts.len() > 1 { parts.slice(1).join(" — ") } else { full }
}

// Convert Markdown footnotes ([^id] / [^id]: text) to inline Typst footnotes.
// cmarker does not support Markdown footnote syntax, so we preprocess.
#let process-footnotes(src) = {
  let footnotes = (:)
  for m in src.matches(regex("\[\^([^\]]+)\]: ([^\n]+)")) {
    footnotes.insert(m.captures.at(0), m.captures.at(1).trim())
  }
  let result = src.replace(regex("\n\[\^[^\]]+\]: [^\n]+"), "")
  for (id, text) in footnotes {
    let escaped = text.replace("\\", "\\\\").replace("\"", "\\\"")
    result = result.replace(
      "[^" + id + "]",
      "<!--raw-typst #footnote(render(\"" + escaped + "\", h1-level: 0))-->"
    )
  }
  result
}

// Chapter argument: centered italic index of the chapter's topics,
// typeset between the chapter title and the body text.
// Called from <!--raw-typst #chapter-argument[...]--> in Markdown.
#let chapter-argument(content) = {
  v(-0.9in)   // pull back against the 1in heading gap
  align(center,
    text(size: 10.5pt, style: "italic",
      par(first-line-indent: 0em, leading: 1.5em, content)
    )
  )
  v(0.6in)    // restore space before body text
}

// Gotcha sidebar: a boxed aside, capped at half the 6in page width.
// The Markdown source calls it as
//   <!--raw-typst #sidebar(render("**⚠ Gotcha — …** …markdown…", h1-level: 0))-->
// so the aside's prose is authored in Markdown and rendered into the box.
#let sidebar(body) = block(
  width: 2.9in,
  fill: luma(244),
  stroke: (left: 1.5pt + luma(140), rest: 0.5pt + luma(200)),
  radius: 2pt,
  inset: (x: 10pt, y: 9pt),
  above: 1.1em, below: 1.1em,
)[
  #set text(size: 9.5pt)
  #set par(first-line-indent: 0em, leading: 0.55em, justify: true)
  #body
]

// ─────────────────────────────────────────────────────────────────
//  STATE
// ─────────────────────────────────────────────────────────────────

// Current chapter's short title, used in recto running headers.
#let running-title = state("running-title", "")

// ─────────────────────────────────────────────────────────────────
//  PAGE GEOMETRY  (6 × 9 in trade paperback)
// ─────────────────────────────────────────────────────────────────

#set page(
  width:  6in,
  height: 9in,
  margin: (top: 0.875in, bottom: 0.875in, inside: 1in, outside: 0.75in),
)

// ─────────────────────────────────────────────────────────────────
//  TYPOGRAPHY
// ─────────────────────────────────────────────────────────────────

#set text(font: "EB Garamond", size: 12pt, lang: "en")
#set par(justify: true, leading: 0.65em, first-line-indent: 1.5em)
#set strong(delta: 300)

// ─────────────────────────────────────────────────────────────────
//  ELEMENT STYLES
// ─────────────────────────────────────────────────────────────────

// Footnotes ── small, separated, flush-left
#set footnote.entry(
  separator: pad(bottom: 4pt, line(length: 33%, stroke: 0.4pt)),
  gap: 0.65em,
  indent: 0em,
)
#show footnote.entry: set text(size: 10pt)
#show footnote.entry: set par(first-line-indent: 0em, leading: 0.55em)

// Section breaks ── cmarker renders --- as line(length: 100%)
// Replace with a centred floral ornament.
#show line: _ => [
  #v(0.9em)
  #align(center)[#text(size: 14pt)[❧]]
  #v(0.9em)
]

// Block quotes (intro epigraph, pull quotes)
#show quote.where(block: true): it => pad(
  top: 0.8em, bottom: 0.8em,
  left: 2em, right: 2em,
  par(
    first-line-indent: 0em,
    text(style: "italic", it.body)
  )
)

// H1 ── chapter title
// "Chapter N — Title" is already in the string; just centre it large.
#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  v(1.5in)
  align(center,
    text(size: 22pt, weight: "regular", tracking: 0.02em, it.body)
  )
  v(1in)
}

// H2 ── section headings
#show heading.where(level: 2): it => block(
  above: 1.4em, below: 0.6em,
  text(size: 13pt, style: "italic", weight: "regular", it.body)
)

// H3 ── subsection headings
#show heading.where(level: 3): it => block(
  above: 1.2em, below: 0.4em,
  text(size: 12pt, style: "italic", weight: "regular", it.body)
)

// ─────────────────────────────────────────────────────────────────
//  BODY-PAGE TEMPLATE  (running headers + Arabic page numbers)
// ─────────────────────────────────────────────────────────────────

#let body-pages(doc) = {
  set page(
    header: context {
      let n = counter(page).at(here()).first()
      set text(size: 9pt, tracking: 0.06em)
      if calc.odd(n) {
        align(right, smallcaps(running-title.at(here())))
      } else {
        align(left, smallcaps(book-title))
      }
    },
    footer: context {
      let n = counter(page).at(here()).first()
      align(center, text(size: 10pt, str(n)))
    },
    numbering: "1",
  )
  doc
}

// ─────────────────────────────────────────────────────────────────
//  FRONT-MATTER PAGE TEMPLATE  (roman folios, no running heads)
// ─────────────────────────────────────────────────────────────────

#let fm-pages(doc) = {
  set page(
    header: none,
    footer: context {
      align(center, text(size: 10pt, counter(page).display("i")))
    },
    numbering: "i",
  )
  doc
}

// ─────────────────────────────────────────────────────────────────
//  CHAPTER INCLUDE
// ─────────────────────────────────────────────────────────────────

// buildabook passes the structural kind explicitly from outline.txt:
//   #chapter("file.md")               — chapter/division/appendix (TOC level 2)
//   #chapter("file.md", part: true)   — part page (TOC level 1)
//   #chapter("file.md", toc: false)   — omit from the outline
// Filenames carry no structural meaning.
#let chapter(path, token: none, part: false, toc: true) = {
  let src        = read(path)
  let preamble   = md-preamble(src)
  let full-title = md-title(src)
  let short      = md-short-title(src)
  let body       = md-body(src)

  // Raw Typst before the first H1: execute it directly (title pages, etc.)
  if preamble != "" {
    eval(preamble, mode: "markup")
  }

  // Update the running header before the heading so it is live on the
  // opening page and every page that follows.
  running-title.update(short)

  // Proper Typst heading → feeds #outline() automatically.
  // Parts render at level 1 (above chapters); unlisted entries hide from TOC.
  let level = if part { 1 } else { 2 }
  heading(level: level, outlined: toc, numbering: none)[#full-title]

  // Plant a page anchor so {{page:…}} tokens resolve to this page.
  if token != none {
    pgan(token.split(":").last())
  }

  // Render Markdown body; pass render, pgan, pageof, chapter-argument and
  // sidebar into scope so <!--raw-typst --> blocks can call them.
  render(process-footnotes(body),
         scope: (render: render, pgan: pgan, pageof: pageof,
                 chapter-argument: chapter-argument, sidebar: sidebar))
}

// ═════════════════════════════════════════════════════════════════
//  FRONT MATTER
//
//  Generic front matter driven by the metadata above.  A book with a
//  dedication, epigraph, or other bespoke front-matter pages either adds
//  them here in its own template, or emits them from a chapter preamble
//  (raw Typst before the first H1), or points book.conf at a book-specific
//  template that overrides this section.
// ═════════════════════════════════════════════════════════════════

// ── Half-title ────────────────────────────────────────────────────

#page(header: none, footer: none, numbering: none)[
  #v(2.5in)
  #align(center,
    text(size: 18pt, weight: "regular", tracking: 0.03em, book-title)
  )
]

// ── Blank verso ───────────────────────────────────────────────────

#page(header: none, footer: none, numbering: none)[]

// ── Full title page ───────────────────────────────────────────────

#page(header: none, footer: none, numbering: none)[
  #v(1.0in)
  #align(center)[
    #text(size: 24pt, weight: "regular", tracking: 0.02em, book-title)
    #v(0.6em)
    #if book-subtitle != "" [
      #text(size: 13pt, style: "italic", weight: "regular", book-subtitle)
      #v(0.4em)
    ]
    #v(1.0em)
    #line(length: 2.2in, stroke: 0.4pt)
    #v(1.1em)
    #if book-tagline != "" [
      #text(size: 10.5pt, weight: "regular", tracking: 0.04em, book-tagline)
      #v(2.8em)
    ]
    #text(size: 13pt, book-author)
    #v(1fr)
    #if book-publisher != "" [
      #text(size: 11pt)[#book-publisher #sym.dot.c #book-city]
    ]
    #v(0.6in)
  ]
]

// ── Copyright ─────────────────────────────────────────────────────

#page(header: none, footer: none, numbering: none)[
  #v(1fr)
  #set text(size: 10pt)
  #set par(first-line-indent: 0em, leading: 0.8em)

  Copyright #sym.copyright #book-year #book-author

  #v(0.8em)

  All rights reserved. No part of this publication may be reproduced,
  distributed, or transmitted in any form or by any means, including
  photocopying, recording, or other electronic or mechanical methods,
  without the prior written permission of the author, except in the
  case of brief quotations in critical reviews and certain other
  noncommercial uses permitted by copyright law.

  #v(0.8em)

  First edition, #book-year

  #v(0.8em)

  ISBN #book-isbn

  #v(0.8em)

  Typeset in EB Garamond using Typst. \
  Printed in Canada.
]

// ── Table of contents ─────────────────────────────────────────────

#set page(
  header: none,
  footer: context {
    align(center,
      text(size: 10pt, counter(page).display("i"))
    )
  },
  numbering: "i",
)

#counter(page).update(1)

#v(0.5in)
#align(center,
  text(size: 14pt, tracking: 0.18em, upper[Contents])
)
#v(0.7in)

#show outline.entry: set text(size: 11pt)
#show outline.entry: set par(first-line-indent: 0em, leading: 1.6em)

#outline(
  title: none,
  depth: 1,
  indent: 0em,
)

// ═════════════════════════════════════════════════════════════════
//  BODY
// ═════════════════════════════════════════════════════════════════

#show: body-pages
#counter(page).update(1)

// Chapter list appended below by buildabook — DO NOT EDIT BELOW THIS LINE
