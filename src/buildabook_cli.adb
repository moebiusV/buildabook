--  buildabook_cli.adb — subcommand dispatch for buildabook.
--
--  The outline-language book builder: turns a book's outline.txt + book.conf
--  into a Typst book.typ, resolving {{token}} cross-references and emitting a
--  number_map.csv audit.  This file is the entry point; the real work lives in
--  the Buildabook.Outline / Tokens / Materialize / Emit / Spine / Config units.

with Ada.Command_Line;
with Ada.Text_IO;

with HBNF_Config;   --  validates the hbnf toolchain is linkable

procedure Buildabook_Cli is

   procedure Usage is
   begin
      Ada.Text_IO.Put_Line ("buildabook — the outline-language book builder");
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("Usage: buildabook SUBCOMMAND [options]");
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("Subcommands:");
      Ada.Text_IO.Put_Line ("  render      outline -> rendered/book.typ + number_map.csv");
      Ada.Text_IO.Put_Line ("  check       validate outline + filemap + tokens, emit nothing");
      Ada.Text_IO.Put_Line ("  number-map  write number_map.csv only");
      Ada.Text_IO.Put_Line ("  spine <pdf> rewrite the cover spine width from a page count");
      Ada.Text_IO.Put_Line ("  build       render + typst compile + spine");
   end Usage;

   Sub : constant String :=
     (if Ada.Command_Line.Argument_Count >= 1
      then Ada.Command_Line.Argument (1)
      else "");

begin
   case Sub is
      when "" | "-h" | "--help" =>
         Usage;
      when "render" | "check" | "number-map" | "spine" | "build" =>
         Ada.Text_IO.Put_Line ("buildabook: '" & Sub & "' not yet implemented");
      when others =>
         Ada.Text_IO.Put_Line ("buildabook: unknown subcommand '" & Sub & "'");
         Usage;
   end case;
end Buildabook_Cli;
