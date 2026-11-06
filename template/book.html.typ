// -------------------------------------------------------------------
//  buildabook - shared Typst template for the HTML build
//  Used by:  buildabook html      (typst compile --features html --format html)
//
//  The web counterpart of template/book.typ.  A page has no geometry, so this
//  one is written in HTML elements: the paged template's align, pad, v() and
//  pagebreak are dropped, contents and all, by Typst's HTML export.  Typst
//  calls that export experimental; it needs typst-cli 0.13 or later.
//
//  A book overrides it with a book.html.typ beside book.conf, or with
//  html-template in the build block of book.conf.  The contract is the one of
//  the paged template that applies to a page:
//    book-title   chapter(path, token, part, toc)   pgan(id)   pageof(id)
//  and import cmarker's `render`.  Keep the metadata in step with the paged
//  template.  The output is one HTML file; each chapter's heading has the id
//  of its file name without ".md", so a link can go straight to a chapter.
// -------------------------------------------------------------------

#import "@preview/cmarker:0.1.1": render

// -------------------------------------------------------------------
//  METADATA  (per-book values; edit or override in book.conf)
// -------------------------------------------------------------------

#let book-title     = "Untitled"
#let book-subtitle  = ""
#let book-tagline   = ""
#let book-author    = ""
#let book-year      = "2026"
#let book-publisher = ""
#let book-city      = ""
#let book-isbn      = ""

#set document(title: book-title, author: book-author)
#set text(lang: "en")

// -------------------------------------------------------------------
//  STYLE
// -------------------------------------------------------------------

#html.elem("style")[
  :root { color-scheme: light dark; }
  body { max-width: 40rem; margin: 2rem auto; padding: 0 1rem; font: 1.1rem/1.6 Georgia, serif; }
  h1, h2, h3 { font-weight: normal; line-height: 1.25; }
  h2 { font-size: 1.7rem; margin: 4rem 0 1.5rem; }
  h3 { font-size: 1.3rem; margin: 2.5rem 0 1rem; }
  h4 { font-style: italic; margin: 2rem 0 .5rem; }
  p { margin: 0 0 1rem; }
  header.title-page { text-align: center; margin: 3rem 0 4rem; }
  header.title-page h1 { font-size: 2.4rem; margin-bottom: .3rem; }
  header.title-page .subtitle { font-size: 1.3rem; font-style: italic; margin: 0 0 1rem; }
  header.title-page .tagline { letter-spacing: .04em; margin: 0 0 1.5rem; }
  section.copyright { font-size: .85rem; margin: 3rem 0; }
  nav[role="doc-toc"] ol { list-style: none; padding: 0; }
  nav[role="doc-toc"] li { margin: .35rem 0; }
  blockquote { margin: 1.2rem 0 1.2rem 1.5rem; font-style: italic; }
  aside.sidebar { margin: 1.2rem 0; padding: .6rem 1rem; font-size: .95rem; border-left: 3px solid currentColor; background: rgba(128, 128, 128, .12); }
  p.chapter-argument { text-align: center; font-style: italic; font-size: .95rem; margin: -.5rem 0 2.5rem; }
  p.ornament { text-align: center; font-size: 1.4rem; margin: 1.5rem 0; }
  sup { line-height: 0; }
  a { color: inherit; }
  ol[role="doc-endnotes"], section.footnotes { font-size: .9rem; }
]

// -------------------------------------------------------------------
//  PAGE ANCHORS
// -------------------------------------------------------------------

// A page has no number on the web.  pgan plants an anchor at a spot in the
// document; pageof links to it, so a {{page:...}} reference stays a working link.
#let pgan(id) = html.elem("span", attrs: (id: "pg-" + id))[]
#let pageof(id) = html.elem("a", attrs: (href: "#pg-" + id))[here]

// -------------------------------------------------------------------
//  HELPERS
// -------------------------------------------------------------------

// Full title from a Markdown file's first H1 line.
#let md-title(src) = {
  let line = src.split("\n").find(l => l.starts-with("# "))
  if line != none { line.slice(2).trim() } else { "" }
}

// Everything before the first H1: raw Typst, executed before the Markdown.
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

// Markdown footnotes ([^id] / [^id]: text) become Typst footnotes, as in book.typ.
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

// Chapter argument: centred italic index of the chapter's topics, between the
// title and the text.  Called from <!--raw-typst #chapter-argument[...]--> in Markdown.
#let chapter-argument(content) = html.elem("p", attrs: (class: "chapter-argument"), content)

// Sidebar: a boxed aside.  Called from <!--raw-typst #sidebar(render("...", h1-level: 0))-->.
#let sidebar(body) = html.elem("aside", attrs: (class: "sidebar"), body)

// cmarker renders a Markdown rule (---) as a line; the web shows an ornament instead.
#show line: _ => html.elem("p", attrs: (class: "ornament"))[\u{2767}]

// -------------------------------------------------------------------
//  CHAPTER INCLUDE
// -------------------------------------------------------------------

// buildabook generates one call per outline entry:
//   #chapter("file.md", token: "c:id00042", part: false, toc: true)
// Parts are headings one level above chapters.  The heading's id is the file name
// without ".md".
#let chapter(path, token: none, part: false, toc: true) = {
  let src        = read(path)
  let preamble   = md-preamble(src)
  let full-title = md-title(src)
  let body       = md-body(src)

  if preamble != "" {
    eval(preamble, mode: "markup")
  }

  let stem  = if path.ends-with(".md") { path.slice(0, path.len() - 3) } else { path }
  let level = if part { 1 } else { 2 }
  [#heading(level: level, outlined: toc, numbering: none)[#full-title]#label(stem)]

  if token != none {
    pgan(token.split(":").last())
  }

  render(process-footnotes(body),
         blockquote: it => html.elem("blockquote", it),
         scope: (render: render, pgan: pgan, pageof: pageof,
                 chapter-argument: chapter-argument, sidebar: sidebar))
}

// =====================================================================
//  FRONT MATTER
//
//  Generic front matter driven by the metadata above.  A book with its own
//  front matter supplies its own template (see the top of this file).
// =====================================================================

#html.elem("header", attrs: (class: "title-page"))[
  #html.elem("h1")[#book-title]
  #if book-subtitle != "" { html.elem("p", attrs: (class: "subtitle"))[#book-subtitle] }
  #if book-tagline != "" { html.elem("p", attrs: (class: "tagline"))[#book-tagline] }
  #if book-author != "" { html.elem("p")[#book-author] }
]

#html.elem("section", attrs: (class: "copyright"))[
  Copyright #sym.copyright #book-year #book-author

  #if book-isbn != "" [ISBN #book-isbn]
]

#html.elem("h2")[Contents]
#outline(title: none, depth: 2)

// Chapter list appended below by buildabook - DO NOT EDIT BELOW THIS LINE
