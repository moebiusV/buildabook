--  files.adb — raw byte file I/O.

with Ada.Sequential_IO;
with Ada.Strings.Unbounded;

package body Files is

   use Ada.Strings.Unbounded;

   package Char_IO is new Ada.Sequential_IO (Character);

   function Read (Path : String) return String is
      F   : Char_IO.File_Type;
      C   : Character;
      Buf : Unbounded_String;
   begin
      Char_IO.Open (F, Char_IO.In_File, Path);
      while not Char_IO.End_Of_File (F) loop
         Char_IO.Read (F, C);
         Append (Buf, C);
      end loop;
      Char_IO.Close (F);
      return To_String (Buf);
   end Read;

   procedure Write (Path : String; Content : String) is
      F : Char_IO.File_Type;
   begin
      Char_IO.Create (F, Char_IO.Out_File, Path);
      for I in Content'Range loop
         Char_IO.Write (F, Content (I));
      end loop;
      Char_IO.Close (F);
   end Write;

end Files;
