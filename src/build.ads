--  build.ads — the render orchestration: outline → file map → materialize →
--  number_map + book.typ, in one pass.

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

end Build;
