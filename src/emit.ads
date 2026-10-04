--  emit.ads — the writers: number_map.csv and book.typ, byte-identical to
--  render.py's write_number_map / write_book_typ / _make_chapter_call.

with Ada.Containers.Indefinite_Ordered_Maps;

with Outline;

package Emit is

   package File_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (String, String);

   --  Write number_map.csv (the audit of every entry's UUID, kind, title,
   --  regime, number, and rendered designation).
   procedure Write_Number_Map (O : Outline.Outline_Type; Path : String);

   --  Write book.typ: the template file verbatim, then the auto-generated
   --  marker, then one #chapter(...) call per entry in outline order.
   procedure Write_Book_Typ
     (O             : Outline.Outline_Type;
      File_Map      : File_Maps.Map;
      Template_Path : String;
      Out_Path      : String);

end Emit;
