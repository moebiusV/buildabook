--  token_tests.adb — the {{token}} resolver: single refs, flags, chapter
--  lists, stack refs, join_and, and the unresolvable-token error.

with AUnit; use AUnit;
with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Cases; use AUnit.Test_Cases;
with Ada.Strings.Unbounded;

with Files;
with Outline;
with Tokens;

package body Token_Tests is

   use Ada.Strings.Unbounded;

   type Test is new Test_Case with null record;

   overriding function Name (T : Test) return Message_String;
   overriding procedure Register_Tests (T : in out Test);

   Outline_Path : constant String := "/tmp/bba-test-tokens.txt";

   function Resolver return Tokens.Resolver is
      R : Tokens.Resolver;
   begin
      Files.Write (Outline_Path,
        "c:id00001  First Chapter" & ASCII.LF &
        "c:id00002  Second Chapter" & ASCII.LF &
        "k:id00001.1  First Sub" & ASCII.LF);
      R.O := Outline.Load (Outline_Path);
      return R;
   end Resolver;

   procedure Test_Resolution (T : in out Test_Case'Class) is
      pragma Unreferenced (T);
      R : constant Tokens.Resolver := Resolver;
   begin
      Assert (Tokens.Resolve (R, "c:id00001") = "Chapter 1",
              "chapter token renders its full designation");
      Assert (Tokens.Resolve (R, "c:id00002") = "Chapter 2",
              "second chapter renders 'Chapter 2'");
      Assert (Tokens.Resolve (R, "c:id00001|n") = "1",
              "the |n flag yields the bare number");
      Assert (Tokens.Resolve (R, "c:id00001|s") = "Ch 1",
              "the |s flag yields the short form");
      Assert (Tokens.Resolve (R, "cc:id00001,id00002") = "Chapters 1 and 2",
              "a chapter list pluralises and joins");
      Assert (Tokens.Resolve (R, "k:id00001.1") = "§1.1",
              "a stack token renders parent.minor");
   end Test_Resolution;

   procedure Test_Join_And (T : in out Test_Case'Class) is
      pragma Unreferenced (T);
      package SV renames Tokens.Str_Vectors;
   begin
      Assert (Tokens.Join_And (SV.Empty_Vector) = "",
              "empty list joins to the empty string");

      declare
         One : SV.Vector;
      begin
         One.Append (To_Unbounded_String ("a"));
         Assert (Tokens.Join_And (One) = "a", "single item joins to itself");
      end;

      declare
         Two : SV.Vector;
      begin
         Two.Append (To_Unbounded_String ("a"));
         Two.Append (To_Unbounded_String ("b"));
         Assert (Tokens.Join_And (Two) = "a and b",
                 "two items join with 'and'");
      end;

      declare
         Three : SV.Vector;
      begin
         Three.Append (To_Unbounded_String ("a"));
         Three.Append (To_Unbounded_String ("b"));
         Three.Append (To_Unbounded_String ("c"));
         Assert (Tokens.Join_And (Three) = "a, b, and c",
                 "three items join with the Oxford comma");
      end;
   end Test_Join_And;

   procedure Test_Bad_Token (T : in out Test_Case'Class) is
      pragma Unreferenced (T);
      R      : constant Tokens.Resolver := Resolver;
      Raised : Boolean := False;
   begin
      begin
         declare
            X : constant String := Tokens.Resolve (R, "c:id09999");
         begin
            pragma Unreferenced (X);
            null;
         end;
      exception
         when Tokens.Tokens_Error =>
            Raised := True;
      end;
      Assert (Raised, "an unknown UUID should raise Tokens_Error");
   end Test_Bad_Token;

   function Name (T : Test) return Message_String is
      pragma Unreferenced (T);
   begin
      return Format ("Token resolver");
   end Name;

   procedure Register_Tests (T : in out Test) is
   begin
      Registration.Register_Routine (T, Test_Resolution'Access, "resolution");
      Registration.Register_Routine (T, Test_Join_And'Access, "join_and");
      Registration.Register_Routine (T, Test_Bad_Token'Access, "unresolvable token");
   end Register_Tests;

   function Suite return Access_Test_Suite is
      Ret : constant Access_Test_Suite := new Test_Suite;
   begin
      Ret.Add_Test (Test_Case_Access'(new Test));
      return Ret;
   end Suite;

end Token_Tests;
