--  materialize.ads — the per-file pass: substitute {{tokens}}, plant page
--  markers after section headings, and split oversized tables, byte-identical
--  to render.py's materialize_file / split_long_tables.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Tokens;

package Materialize is

   use Ada.Strings.Unbounded;

   package Error_Vectors is new Ada.Containers.Vectors
     (Positive, Unbounded_String);
   subtype Error_List is Error_Vectors.Vector;

   --  Enforce the no-giant-tables rule: split any markdown table with more
   --  than Max_Rows data rows, repeating the header row for each part.
   --  Max_Rows <= 0 disables splitting.
   function Split_Long_Tables (Text : String; Max_Rows : Natural) return String;

   --  Read Src_Path, replace every {{…}} token, plant the section page markers,
   --  split oversized tables, and write Dst_Path.  Appends one entry per
   --  unresolvable token to Errors.
   procedure Materialize_File
     (R        : Tokens.Resolver;
      Src_Path : String;
      Dst_Path : String;
      Errors   : in out Error_List);

end Materialize;
