--  numbering_tests.adb — the numbering engine: row kinds, numbers, display
--  strings, directive regimes, and the duplicate-UUID error.

with AUnit; use AUnit;
with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Cases; use AUnit.Test_Cases;
with Ada.Strings.Unbounded;

with Files;
with Outline;

package body Numbering_Tests is

   use Ada.Strings.Unbounded;
   use type Outline.Kind;
   use type Outline.Number_Style;

   type Test is new Test_Case with null record;

   overriding function Name (T : Test) return Message_String;
   overriding procedure Register_Tests (T : in out Test);

   Outline_Path : constant String := "/tmp/bba-test-outline.txt";

   function Load_Outline (Text : String) return Outline.Outline_Type is
   begin
      Files.Write (Outline_Path, Text);
      return Outline.Load (Outline_Path);
   end Load_Outline;

   procedure Test_Basic (T : in out Test_Case'Class) is
      pragma Unreferenced (T);
      O : Outline.Outline_Type := Load_Outline
        ("p:id00100  Part One" & ASCII.LF &
         "c:id00001  First Chapter" & ASCII.LF &
         "c:id00002  Second Chapter" & ASCII.LF &
         "a:id09001  Appendix A" & ASCII.LF);
   begin
      Assert (Natural (O.Rows.Length) = 4, "expected 4 outline rows");

      Assert (O.Rows (1).K = Outline.Part, "row 1 is a part");
      Assert (O.Rows (1).N = 1, "part numbered 1");
      Assert (Outline.Display (O.Rows (1)) = "Part I",
              "part renders as 'Part I' (roman)");

      Assert (O.Rows (2).K = Outline.Chapter, "row 2 is a chapter");
      Assert (O.Rows (2).N = 1, "first chapter numbered 1");
      Assert (Outline.Display (O.Rows (2)) = "Chapter 1",
              "chapter renders as 'Chapter 1'");

      Assert (O.Rows (3).N = 2, "second chapter numbered 2");
      Assert (Outline.Display (O.Rows (3)) = "Chapter 2",
              "second chapter renders as 'Chapter 2'");

      Assert (O.Rows (4).K = Outline.Appendix, "row 4 is an appendix");
      Assert (Outline.Display (O.Rows (4)) = "Appendix A",
              "appendix renders as 'Appendix A' (letter)");
   end Test_Basic;

   procedure Test_Sections (T : in out Test_Case'Class) is
      pragma Unreferenced (T);
      O : Outline.Outline_Type := Load_Outline
        ("c:id00001  First Chapter" & ASCII.LF &
         "s:id00300  ""First Section""" & ASCII.LF &
         "s:id00301  ""Second Section""" & ASCII.LF);
   begin
      Assert (Natural (O.Rows.Length) = 3, "expected 3 outline rows");
      Assert (O.Rows (2).K = Outline.Section, "row 2 is a section");
      Assert (O.Rows (2).N = 1, "first section numbered 1");
      Assert (O.Rows (3).N = 2, "second section numbered 2");
      Assert (Outline.Display (O.Rows (2)) = "§1",
              "section renders as the section sign + number");
   end Test_Sections;

   procedure Test_Label_Directive (T : in out Test_Case'Class) is
      pragma Unreferenced (T);
      O : Outline.Outline_Type := Load_Outline
        ("c:label:Warrant|Wt" & ASCII.LF &
         "c:id00001  First" & ASCII.LF &
         "c:number:roman" & ASCII.LF &
         "c:id00002  Second" & ASCII.LF);
   begin
      Assert (O.Rows (1).Label = "Warrant", "label directive sets the label");
      Assert (O.Rows (1).Short = "Wt", "label directive sets the short form");
      Assert (Outline.Display (O.Rows (1)) = "Warrant 1",
              "custom label renders as 'Warrant 1'");
      Assert (Outline.Display (O.Rows (1), Short_Form => True) = "Wt 1",
              "short form renders as 'Wt 1'");

      Assert (O.Rows (2).Style = Outline.Roman,
              "number directive sets the style");
      Assert (Outline.Display (O.Rows (2)) = "Warrant II",
              "roman style renders as 'Warrant II'");
   end Test_Label_Directive;

   procedure Test_Duplicate_Uuid (T : in out Test_Case'Class) is
      pragma Unreferenced (T);
      Raised : Boolean := False;
   begin
      Files.Write (Outline_Path,
        "c:id00001  First" & ASCII.LF &
        "c:id00001  Dup" & ASCII.LF);
      begin
         declare
            O : Outline.Outline_Type := Outline.Load (Outline_Path);
         begin
            pragma Unreferenced (O);
            null;
         end;
      exception
         when Outline.Outline_Error =>
            Raised := True;
      end;
      Assert (Raised, "duplicate UUID should raise Outline_Error");
   end Test_Duplicate_Uuid;

   function Name (T : Test) return Message_String is
      pragma Unreferenced (T);
   begin
      return Format ("Numbering engine");
   end Name;

   procedure Register_Tests (T : in out Test) is
   begin
      Registration.Register_Routine (T, Test_Basic'Access, "basic numbering");
      Registration.Register_Routine (T, Test_Sections'Access, "sections");
      Registration.Register_Routine (T, Test_Label_Directive'Access, "label + number directives");
      Registration.Register_Routine (T, Test_Duplicate_Uuid'Access, "duplicate UUID");
   end Register_Tests;

   function Suite return Access_Test_Suite is
      Ret : constant Access_Test_Suite := new Test_Suite;
   begin
      Ret.Add_Test (Test_Case_Access'(new Test));
      return Ret;
   end Suite;

end Numbering_Tests;
