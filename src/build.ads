--  build.ads — the render orchestration: outline → file map → materialize →
--  number_map + book.typ, in one pass, plus the check and number-map helpers.

with Materialize;

package Build is

   Build_Error : exception;

   --  Run the full render.  Fatal problems (missing outline or template)
   --  raise Build_Error; per-file problems (unresolvable tokens, unmatched
   --  headings) are returned in the error list so the caller can report and
   --  keep going.
   function Render
     (Outline_Path  : String;
      Src_Dir       : String;
      Filemap_Path  : String;   -- "" = none
      Template_Path : String;
      Out_Dir       : String;
      Number_Map    : String) return Materialize.Error_List;

   --  Write number_map.csv only: parse and number the outline, emit the audit,
   --  and do nothing else.  Raises Build_Error when the outline is missing.
   procedure Write_Number_Map_Only (Outline_Path : String; Number_Map : String);

   --  The summary of a `check` run.
   type Check_Result is record
      Matched   : Natural;   -- outline entries matched to a file
      Missing   : Natural;   -- non-section/stack/part entries without a file
      Unmatched : Natural;   -- .md files in Src_Dir not referenced by the map
      Rows      : Natural;   -- total outline rows
   end record;

   --  Validate outline + filemap + tokens without emitting anything.  Fatal
   --  problems (missing outline/source, parse errors, file-map errors) raise
   --  Build_Error.  Unresolvable tokens and (without a filemap) unmatched files
   --  are appended to Errors; non-fatal warnings (missing entries, unmatched
   --  files under a filemap) are appended to Warnings.
   function Check
     (Outline_Path : String;
      Src_Dir      : String;
      Filemap_Path : String;
      Errors       : in out Materialize.Error_List;
      Warnings     : in out Materialize.Error_List) return Check_Result;

   --  The next free idNNNNN: the highest UUID already in use (scanned from the
   --  outline and every .md source file) plus one, zero-padded to five digits.
   --  Used by `buildabook uuid` so a writer (human or LLM) can mint a fresh
   --  UUID for a new chapter, section, or anchor without colliding.
   function Next_Uuid (Outline_Path : String; Src_Dir : String) return String;

end Build;
