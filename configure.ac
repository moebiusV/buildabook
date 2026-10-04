# configure.ac — buildabook, the outline-language book builder.
#
# GNU-style configure for an Ada 2022 project built with gprbuild.  There is
# no AC_PROG_Ada, so the Ada toolchain is detected by hand (gprbuild + the
# GNAT gcc) and the hbnf runtime project (libhbnf.a) is checked for gprbuild
# visibility, since buildabook.gpr `with "hbnf_config"`.
#
#   ./configure && make && make check && make install
#
# Standard variables are honoured throughout: PREFIX, DESTDIR, and the
# autoconf --bindir/--mandir/--libdir family.

AC_INIT([buildabook], [0.1.0],
        [david@clearbrookdistillery.com], [buildabook],
        [https://github.com/moebiusV/buildabook])
AC_PREREQ([2.69])
AC_CONFIG_SRCDIR([src/buildabook_cli.adb])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIR([m4])
AC_PROG_INSTALL

# -- Ada toolchain ----------------------------------------------------------
# gprbuild drives the GNAT gcc; both are required.  The canonical source is
# the ada-on-alpine overlay (gcc-gnat 15.x + gprbuild), whose container image
# is `ada-toolchain:edge`.

AC_ARG_VAR([GPRBUILD], [the gprbuild project builder])
AC_PATH_PROG([GPRBUILD], [gprbuild])
AS_IF([test -z "$GPRBUILD"],
      [AC_MSG_ERROR([gprbuild not found in PATH; install gcc-gnat + gprbuild (the ada-on-alpine packages)])])

# gnatmake drives the Ada-capable gcc (gcc proper may be built without the
# Ada frontend, so testing gcc directly is unreliable).  It is used here only
# to probe for Ada 2022; gprbuild does the real compilation.
AC_ARG_VAR([GNATMAKE], [the GNAT build driver])
AC_PATH_PROG([GNATMAKE], [gnatmake])
AS_IF([test -z "$GNATMAKE"],
      [AC_MSG_ERROR([gnatmake not found in PATH; install gcc-gnat (the ada-on-alpine package)])])

AC_MSG_CHECKING([that the GNAT compiler accepts Ada 2022])
cat > conftest.adb <<'EOF'
procedure Conftest is
begin
   null;
end Conftest;
EOF
AS_IF([$GNATMAKE -gnat2022 -c conftest.adb >/dev/null 2>&1],
      [AC_MSG_RESULT([yes])],
      [AC_MSG_RESULT([no])
       AC_MSG_ERROR([the GNAT compiler does not accept -gnat2022; upgrade to gcc-gnat 15.x])])
rm -f conftest.adb conftest.ali conftest.o

# -- optional: Typst, for `buildabook build` ---------------------------------
AC_ARG_VAR([TYPST], [the Typst compiler (optional; needed only for `buildabook build`)])
AC_PATH_PROG([TYPST], [typst])
AS_IF([test -z "$TYPST"],
      [AC_MSG_WARN([typst not found; `buildabook build` will not be able to compile the PDF])])

# -- hbnf runtime -----------------------------------------------------------
# buildabook links libhbnf.a (hbnf_config.gpr), which itself depends on
# mustache.gpr.  Both must be gprbuild-visible (installed by the ada-on-alpine
# hbnf + mustache-ada aports).  A `-c` dry pass is the reliable probe: a
# missing project file aborts gprbuild before any compilation.
AC_MSG_CHECKING([that hbnf_config.gpr and mustache.gpr are gprbuild-visible])
AS_IF([$GPRBUILD -P "$srcdir/buildabook.gpr" -q -c >/dev/null 2>&1],
      [AC_MSG_RESULT([yes])],
      [AC_MSG_RESULT([no])
       AC_MSG_ERROR([hbnf_config.gpr (and its mustache.gpr dependency) must be visible to gprbuild; install the ada-on-alpine hbnf + mustache-ada packages])])

# -- install layout ---------------------------------------------------------
# AC_PREFIX_DEFAULT then normalise the ac_default_prefix dance so Makefile.in
# can use plain $(prefix)/$(bindir)/$(mandir).
AC_PREFIX_DEFAULT([/usr/local])
AS_IF([test "x$prefix" = xNONE], [prefix=$ac_default_prefix])
AS_IF([test "x$exec_prefix" = xNONE], [exec_prefix=$prefix])

AC_SUBST([VERSION], [AC_PACKAGE_VERSION])

AC_CONFIG_FILES([Makefile])
AC_OUTPUT
