--  end_to_end_tests.adb — a tiny fixture book driven through Build.Render
--  and Build.Check, the same orchestration the CLI uses.

with AUnit; use AUnit;
with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Cases; use AUnit.Test_Cases;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Build;
with Files;
with Materialize;

package body End_To_End_Tests is

   use Ada.Strings.Unbounded;

   type Test is new Test_Case with null record;

   overriding function Name (T : Test) return Message_String;
   overriding procedure Register_Tests (T : in out Test);

   Dir : constant String := "/tmp/bba-e2e";

   procedure Write_Fixture is
   begin
      Ada.Directories.Create_Path (Dir & "/chapters");

      Files.Write (Dir & "/outline.txt",
        "p:id00100  Part One" & ASCII.LF &
        "c:id00001  First Chapter" & ASCII.LF &
        "c:id00002  Second Chapter" & ASCII.LF &
        "a:id09001  Appendix A" & ASCII.LF);

      Files.Write (Dir & "/filemap.txt",
        "id00001:ch01.md" & ASCII.LF &
        "id00002:ch02.md" & ASCII.LF &
        "id09001:apx.md" & ASCII.LF);

      Files.Write (Dir & "/chapters/ch01.md",
        "# {{c:id00001}} — First Chapter" & ASCII.LF &
        ASCII.LF &
        "See {{c:id00002}} and {{p:id00100}}." & ASCII.LF);

      Files.Write (Dir & "/chapters/ch02.md",
        "# {{c:id00002}} — Second Chapter" & ASCII.LF);

      Files.Write (Dir & "/chapters/apx.md",
        "# {{a:id09001}} — Appendix A" & ASCII.LF);

      Files.Write (Dir & "/book.header.typ",
        "// test template" & ASCII.LF &
        "#let book-title = ""Fixture""" & ASCII.LF);
   end Write_Fixture;

   procedure Test_Render (T : in out Test_Case'Class) is
      pragma Unreferenced (T);
      Errors : Materialize.Error_List;
      Bt     : Unbounded_String;
   begin
      Write_Fixture;

      Errors := Build.Render
        (Dir & "/outline.txt", Dir & "/chapters", Dir & "/filemap.txt",
         Dir & "/book.header.typ", Dir & "/rendered", Dir & "/number_map.csv");

      Assert (Natural (Errors.Length) = 0, "no resolution errors");

      Assert (Ada.Directories.Exists (Dir & "/rendered/book.typ"),
              "book.typ is written");
      Assert (Ada.Directories.Exists (Dir & "/number_map.csv"),
              "number_map.csv is written");
      Assert (Ada.Directories.Exists (Dir & "/rendered/ch01.md"),
              "the chapter is materialized");

      Bt := To_Unbounded_String (Files.Read (Dir & "/rendered/book.typ"));
      Assert (Ada.Strings.Fixed.Index (To_String (Bt),
              "#chapter(""ch01.md"", token: ""c:id00001"")") /= 0,
              "book.typ lists the chapter call");

      declare
         Ch : constant String := Files.Read (Dir & "/rendered/ch01.md");
      begin
         Assert (Ada.Strings.Fixed.Index (Ch, "Chapter 2") /= 0,
                 "a cross-reference resolves to 'Chapter 2'");
         Assert (Ada.Strings.Fixed.Index (Ch, "Part I") /= 0,
                 "a part reference resolves to 'Part I'");
      end;
   end Test_Render;

   procedure Test_Check (T : in out Test_Case'Class) is
      pragma Unreferenced (T);
      Errors   : Materialize.Error_List;
      Warnings : Materialize.Error_List;
      Res      : Build.Check_Result;
   begin
      Write_Fixture;

      Res := Build.Check
        (Dir & "/outline.txt", Dir & "/chapters", Dir & "/filemap.txt",
         Errors, Warnings);

      Assert (Natural (Errors.Length) = 0, "a clean book has no errors");
      Assert (Res.Matched = 3, "three entries matched to files (part is fileless)");
      Assert (Res.Missing = 0, "no entries without files");
      Assert (Res.Unmatched = 0, "no unmatched files");

      --  Introduce an unresolvable token and re-check.
      Files.Write (Dir & "/chapters/ch02.md",
        "# {{c:id00002}} — Second Chapter" & ASCII.LF &
        "See {{c:id09999}}." & ASCII.LF);

      Res := Build.Check
        (Dir & "/outline.txt", Dir & "/chapters", Dir & "/filemap.txt",
         Errors, Warnings);

      Assert (Natural (Errors.Length) = 1, "the bad token is reported");
   end Test_Check;

   function Name (T : Test) return Message_String is
      pragma Unreferenced (T);
   begin
      return Format ("End to end");
   end Name;

   procedure Register_Tests (T : in out Test) is
   begin
      Registration.Register_Routine (T, Test_Render'Access, "render a fixture book");
      Registration.Register_Routine (T, Test_Check'Access, "check a fixture book");
   end Register_Tests;

   function Suite return Access_Test_Suite is
      Ret : constant Access_Test_Suite := new Test_Suite;
   begin
      Ret.Add_Test (Test_Case_Access'(new Test));
      return Ret;
   end Suite;

end End_To_End_Tests;
