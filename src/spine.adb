--  spine.adb — read the page count, compute the spine, rewrite cover.typ.

with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files;
with Shell;

package body Spine is

   use Ada.Strings.Unbounded;

   --  Extract the "Pages:" value from pdfinfo output; 0 if not found.
   function Parse_Pages (Info : String) return Natural is
      P : Natural := Ada.Strings.Fixed.Index (Info, "Pages:");
      N : Natural := 0;
   begin
      if P = 0 then
         return 0;
      end if;
      P := P + 6;   -- past "Pages:"
      while P <= Info'Last
        and then (Info (P) = ' ' or else Info (P) = ASCII.HT)
      loop
         P := P + 1;
      end loop;
      while P <= Info'Last and then Info (P) in '0' .. '9' loop
         N := N * 10 + (Character'Pos (Info (P)) - Character'Pos ('0'));
         P := P + 1;
      end loop;
      return N;
   end Parse_Pages;

   --  Format a count of hundredths as "N.NN" (e.g. 131 -> "1.31").
   function Format_Hundredths (Hundredths : Natural) return String is
      Whole : constant String :=
        Ada.Strings.Fixed.Trim (Natural'Image (Hundredths / 100),
                                Ada.Strings.Left);
      Frac  : constant Natural := Hundredths mod 100;
   begin
      return Whole & "." &
        (if Frac < 10 then "0" & Ada.Strings.Fixed.Trim (Natural'Image (Frac), Ada.Strings.Left)
         else Ada.Strings.Fixed.Trim (Natural'Image (Frac), Ada.Strings.Left));
   end Format_Hundredths;

   --  Replace the "#let sw =" line in Text with New_Line; Found = whether it
   --  was present.  Preserves every other byte (LF-separated lines).
   function Rewrite_Sw
     (Text : String; New_Line : String; Found : out Boolean) return String is
      Acc   : Unbounded_String;
      Start : Natural := Text'First;
      I     : Natural;
   begin
      Found := False;
      loop
         I := Ada.Strings.Fixed.Index
           (Text (Start .. Text'Last), String'(1 => ASCII.LF));
         declare
            Line : constant String :=
              (if I = 0 then Text (Start .. Text'Last)
               else Text (Start .. I - 1));
         begin
            if Line'Length >= 9
              and then Line (Line'First .. Line'First + 8) = "#let sw ="
            then
               Append (Acc, New_Line);
               Found := True;
            else
               Append (Acc, Line);
            end if;
            exit when I = 0;
            Append (Acc, ASCII.LF);
            Start := I + 1;
         end;
      end loop;
      return To_String (Acc);
   end Rewrite_Sw;

   function Update
     (Pdf_Path   : String;
      Cover_Path : String := "cover.typ") return Boolean is

      Pages      : Natural;
      Hundredths : Natural;
      New_Line   : Unbounded_String;
      Found      : Boolean;
   begin
      if not Ada.Directories.Exists (Pdf_Path) then
         raise Spine_Error with
           "missing " & Pdf_Path & " (needed to compute the cover spine)";
      end if;
      if not Ada.Directories.Exists (Cover_Path) then
         raise Spine_Error with
           "missing " & Cover_Path & " (needed to build the cover)";
      end if;

      Pages := Parse_Pages (Shell.Capture ("pdfinfo " & Pdf_Path));
      if Pages = 0 then
         raise Spine_Error with
           "could not determine the page count of " & Pdf_Path &
           " (pdfinfo missing or failed — needs poppler-utils)";
      end if;

      Hundredths :=
        Integer (Long_Float'Rounding (Long_Float (Pages) * 100.0 / 399.0));

      Append (New_Line, "#let sw = ");
      Append (New_Line, Format_Hundredths (Hundredths));
      Append (New_Line, "in   // spine width (");
      Append (New_Line, Ada.Strings.Fixed.Trim (Natural'Image (Pages), Ada.Strings.Left));
      Append (New_Line, " pp, 50# cream)");

      declare
         Replaced : constant String :=
           Rewrite_Sw (Files.Read (Cover_Path), To_String (New_Line), Found);
      begin
         if Found then
            Files.Write (Cover_Path, Replaced);
         end if;
      end;
      return Found;
   end Update;

end Spine;
