#!/bin/sh
# Regenerate the two checked-in parsers from their grammars with hbnf:
#   grammars/outline.hbnf   -> src/outline_grammar.ads, -parser.ads, -parser.adb
#   grammars/book_conf.hbnf -> src/book_conf_grammar.ads, -parser.ads, -parser.adb
# Needs hbnf (moebiusV/hbnf main of 2026-10-22 or later; the output of an older
# hbnf has a different tree API and outline.adb and config.adb are written for
# this one) and gnatchop (part of gcc-gnat).  hbnf prints one stream (the
# parent spec, then the child spec and body); gnatchop splits it into the three
# files by unit name.  HBNF_TEMPLATES may name hbnf's template directory.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
SRC="$HERE/../src"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
gen() {			# gen GRAMMAR PACKAGE
	hbnf "$HERE/$1" --backend=ada --package="$2" ${HBNF_TEMPLATES:+--templates="$HBNF_TEMPLATES"} > "$TMP/$2.out"
	gnatchop -w -q "$TMP/$2.out" "$SRC"
}
gen outline.hbnf Outline_Grammar
gen book_conf.hbnf Book_Conf_Grammar
echo "regenerated src/outline_grammar* and src/book_conf_grammar*"
