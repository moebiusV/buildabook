--  tests.adb — the aunit runner: assembles every suite and runs them with
--  the text reporter.

with AUnit.Reporter.Text;
with AUnit.Run;
with AUnit.Test_Suites; use AUnit.Test_Suites;

with Numbering_Tests;
with Token_Tests;
with Materialize_Tests;
with End_To_End_Tests;

procedure Tests is

   function Suite return Access_Test_Suite is
      Ret : constant Access_Test_Suite := new Test_Suite;
   begin
      Ret.Add_Test (Numbering_Tests.Suite);
      Ret.Add_Test (Token_Tests.Suite);
      Ret.Add_Test (Materialize_Tests.Suite);
      Ret.Add_Test (End_To_End_Tests.Suite);
      return Ret;
   end Suite;

   procedure Runner is new AUnit.Run.Test_Runner (Suite);
   Reporter : AUnit.Reporter.Text.Text_Reporter;

begin
   Runner (Reporter);
end Tests;
