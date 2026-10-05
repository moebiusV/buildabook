--  materialize_tests.adb — the materialize pass: the no-giant-tables rule
--  and per-file token resolution errors.

with AUnit; use AUnit;
with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Cases; use AUnit.Test_Cases;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files;
with Materialize;
with Outline;
with Tokens;

package body Materialize_Tests is

   use Ada.Strings.Unbounded;

   type Test is new Test_Case with null record;

   overriding function Name (T : Test) return Message_String;
   overriding procedure Register_Tests (T : in out Test);

   --  Build a markdown table with Rows data rows.
   function Table (Rows : Natural) return String is
      B : Unbounded_String;
   begin
      Append (B, "| Col1 | Col2 |");
      Append (B, ASCII.LF);
      Append (B, "|---|---|");
      Append (B, ASCII.LF);
      for I in 1 .. Rows loop
         Append (B, "| r" & Ada.Strings.Fixed.Trim (Natural'Image (I), Ada.Strings.Left)
                   & " | c" & Ada.Strings.Fixed.Trim (Natural'Image (I), Ada.Strings.Left) & " |");
         Append (B, ASCII.LF);
      end loop;
      return To_String (B);
   end Table;

   procedure Test_Table_Split (T : in out Test_Case'Class) is
      pragma Unreferenced (T);
      Whole  : constant String := Table (45);
      Split  : constant String := Materialize.Split_Long_Tables (Whole, 40);
      Small  : constant String := Materialize.Split_Long_Tables (Table (3), 40);
   begin
      --  A short table passes through untouched (one header).
      Assert (Ada.Strings.Fixed.Count (Small, "| Col1 | Col2 |") = 1,
              "a short table keeps a single header");

      --  45 rows at a 40-row cap split into two tables (two headers).
      Assert (Ada.Strings.Fixed.Count (Split, "| Col1 | Col2 |") = 2,
              "an oversized table repeats its header once per part");
      Assert (Ada.Strings.Fixed.Count (Split, "|---|---|") = 2,
              "each split part repeats the separator");
   end Test_Table_Split;

   procedure Test_Check_File (T : in out Test_Case'Class) is
      pragma Unreferenced (T);
      Outline_Path : constant String := "/tmp/bba-test-mcheck-outline.txt";
      Src_Path     : constant String := "/tmp/bba-test-mcheck.md";
      R            : Tokens.Resolver;
      Errors       : Materialize.Error_List;
   begin
      Files.Write (Outline_Path, "c:id00001  First Chapter" & ASCII.LF);
      R.O := Outline.Load (Outline_Path);

      Files.Write (Src_Path,
        "# {{c:id00001}} — Title" & ASCII.LF &
        ASCII.LF &
        "See {{c:id09999}}." & ASCII.LF);

      Materialize.Check_File (R, Src_Path, Errors);

      Assert (Natural (Errors.Length) = 1, "one unresolvable token is reported");
      if Natural (Errors.Length) = 1 then
         Assert (Ada.Strings.Fixed.Index (To_String (Errors (1)), "UUID not in outline") /= 0,
                 "the error names the missing UUID");
      end if;
   end Test_Check_File;

   function Name (T : Test) return Message_String is
      pragma Unreferenced (T);
   begin
      return Format ("Materialize pass");
   end Name;

   procedure Register_Tests (T : in out Test) is
   begin
      Registration.Register_Routine (T, Test_Table_Split'Access, "table splitting");
      Registration.Register_Routine (T, Test_Check_File'Access, "resolution error reporting");
   end Register_Tests;

   function Suite return Access_Test_Suite is
      Ret : constant Access_Test_Suite := new Test_Suite;
   begin
      Ret.Add_Test (Test_Case_Access'(new Test));
      return Ret;
   end Suite;

end Materialize_Tests;
