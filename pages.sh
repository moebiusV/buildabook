#!/bin/sh
# pages.sh - regenerate index.html, the GitHub Pages front page, from README.md.
#
# Pages serves this repository with Jekyll off (see .nojekyll), because Jekyll
# reads {{ }} in README.md as Liquid and drops the token examples.  The page is
# made by the Markdown grammar in hbnf's corpus/markdown instead.
#
#   HBNF_DIR=/path/to/hbnf sh pages.sh        (default ../hbnf; needs a built hbnf)
set -eu
cd "$(dirname "$0")"
HBNF_DIR=${HBNF_DIR:-../hbnf}
export HBNF_TEMPLATES="$HBNF_DIR/templates"
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
"$HBNF_DIR/hbnf" "$HBNF_DIR/corpus/markdown/markdown.hbnf" --backend=c --layout=tape > "$W/md.c"
cat "$W/md.c" "$HBNF_DIR/corpus/markdown/html.c" > "$W/h.c"
${CC:-cc} -O1 -std=gnu11 -w -D_GNU_SOURCE -I"$HBNF_DIR/runtime" -DOUT_T=document_t -o "$W/md2html" "$W/h.c"
"$W/md2html" README.md buildabook > "$W/index.html"
mv "$W/index.html" index.html
echo "index.html: $(wc -l < index.html) lines"
