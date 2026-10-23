--  config.ads — the per-book configuration (book.conf), parsed by the parser
--  hbnf generated from grammars/book_conf.hbnf (obconf style).  It supplies the metadata
--  (title, author, slug) and the build/cover paths that the CLI falls back to
--  when no command-line flag overrides them.
--
--  book.conf is obconf syntax: bareword or "quoted" directives, `{ }` blocks,
--  `#` comments, `;`- or newline-terminated entries.  Example:
--
--      title "Telegraph to Turbo Jet"
--      author "David Walther"
--      slug   speedrun-telegraph-to-turbo-jet
--
--      build {
--          outline    outline.txt
--          src        chapters
--          out        rendered
--          template   book.header.typ
--          number-map number_map.csv
--      }
--
--      cover {
--          source cover.typ
--          output speedrun-cover.pdf
--      }

with Ada.Strings.Unbounded;

package Config is

   use Ada.Strings.Unbounded;

   Config_Error : exception;

   type Book_Config is record
      Title      : Unbounded_String;
      Subtitle   : Unbounded_String;
      Tagline    : Unbounded_String;
      Author     : Unbounded_String;
      Year       : Unbounded_String;
      Publisher  : Unbounded_String;
      City       : Unbounded_String;
      Isbn       : Unbounded_String;
      Slug       : Unbounded_String;

      --  the build block
      Outline    : Unbounded_String;
      Src        : Unbounded_String;
      Out_Dir    : Unbounded_String;
      Template   : Unbounded_String;
      Number_Map : Unbounded_String;

      --  the cover block
      Cover_Src  : Unbounded_String;
      Cover_Out  : Unbounded_String;
   end record;

   --  Load book.conf.  Path = "" or a missing file returns an all-empty
   --  config (every field "" = "unset", so the caller falls back to its
   --  built-in defaults).  A malformed file raises Config_Error.
   function Load (Path : String) return Book_Config;

end Config;
