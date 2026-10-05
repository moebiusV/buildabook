--  end_to_end_tests.ads — a tiny fixture book rendered end-to-end.

with AUnit.Test_Suites; use AUnit.Test_Suites;

package End_To_End_Tests is

   function Suite return Access_Test_Suite;

end End_To_End_Tests;
