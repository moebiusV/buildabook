--  emit.adb — the writers, byte-identical to render.py.

with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files;

package body Emit is

   use Ada.Strings.Unbounded;

   use type Outline.Kind;

   --  UTF-8 for U+2014 EM DASH (the marker's "— DO NOT EDIT").
   Em_Dash : constant String :=
     Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#94#);

   -- ── CSV (Python csv.writer, excel dialect, QUOTE_MINIMAL) ────────────────

   function Needs_Quote (S : String) return Boolean is
   begin
      for I in S'Range loop
         if S (I) = ',' or else S (I) = '"'
           or else S (I) = ASCII.LF or else S (I) = ASCII.CR
         then
            return True;
         end if;
      end loop;
      return False;
   end Needs_Quote;

   function Csv_Field (S : String) return String is
      B : Unbounded_String;
   begin
      if Needs_Quote (S) then
         Append (B, '"');
         for I in S'Range loop
            if S (I) = '"' then
               Append (B, '"');
            end if;
            Append (B, S (I));
         end loop;
         Append (B, '"');
         return To_String (B);
      else
         return S;
      end if;
   end Csv_Field;

   function Dec (N : Natural) return String is
   begin
      return Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left);
   end Dec;

   function Kind_Name (K : Outline.Kind) return String is
   begin
      case K is
         when Outline.Chapter   => return "chapter";
         when Outline.Part      => return "part";
         when Outline.Appendix  => return "appendix";
         when Outline.Division  => return "division";
         when Outline.Unlisted  => return "unlisted";
         when Outline.Section   => return "section";
         when Outline.Sub_Entry => return "stack";
      end case;
   end Kind_Name;

   function Style_Name (E : Outline.Row) return String is
   begin
      if E.K in Outline.Division | Outline.Unlisted | Outline.Sub_Entry then
         return "";
      end if;
      case E.Style is
         when Outline.Arabic      => return "arabic";
         when Outline.Roman       => return "roman";
         when Outline.Roman_Lower => return "roman-lower";
         when Outline.Letter      => return "letter";
         when Outline.No_Number   => return "none";
      end case;
   end Style_Name;

   -- ── number_map.csv ───────────────────────────────────────────────────────

   procedure Write_Number_Map (O : Outline.Outline_Type; Path : String) is
      Buf : Unbounded_String;

      procedure Emit (S : String) is
      begin
         Append (Buf, S);
      end Emit;
   begin
      Emit ("uuid,kind,title,label,short,style,n,rendered,parent" & ASCII.CR & ASCII.LF);

      for I in 1 .. Natural (O.Rows.Length) loop
         declare
            E : Outline.Row renames O.Rows (I);
            Uuid_Key : constant String :=
              (if E.K = Outline.Sub_Entry
               then To_String (E.Uuid) & "." & To_String (E.Minor)
               else To_String (E.Uuid));
         begin
            Emit (Csv_Field (Uuid_Key) & ",");
            Emit (Csv_Field (Kind_Name (E.K)) & ",");
            Emit (Csv_Field (To_String (E.Title)) & ",");
            Emit (Csv_Field (To_String (E.Label)) & ",");
            Emit (Csv_Field (To_String (E.Short)) & ",");
            Emit (Csv_Field (Style_Name (E)) & ",");
            Emit (Csv_Field ((if E.Has_N then Dec (E.N) else "")) & ",");
            Emit (Csv_Field (Outline.Display (E)) & ",");
            Emit (Csv_Field (To_String (E.Parent)));
            Emit (ASCII.CR & ASCII.LF);
         end;
      end loop;

      Files.Write (Path, To_String (Buf));
   end Write_Number_Map;

   -- ── book.typ ─────────────────────────────────────────────────────────────

   function Basename (Fname : String) return String is
      Idx : Natural := 0;
   begin
      for I in Fname'Range loop
         if Fname (I) = '/' then
            Idx := I;
         end if;
      end loop;
      if Idx = 0 then
         return Fname;
      end if;
      return Fname (Idx + 1 .. Fname'Last);
   end Basename;

   function Make_Chapter_Call (Fname : String; E : Outline.Row) return String is
      Base : constant String := Basename (Fname);
      Args : Unbounded_String;
   begin
      Append (Args, '"' & Base & '"');
      Append (Args, ", token: """ & To_String (E.Token) & """");
      if E.K = Outline.Part then
         Append (Args, ", part: true");
      end if;
      if not E.Toc then
         Append (Args, ", toc: false");
      end if;
      return "#chapter(" & To_String (Args) & ")";
   end Make_Chapter_Call;

   procedure Write_Book_Typ
     (O : Outline.Outline_Type; File_Map : File_Maps.Map;
      Template_Path : String; Out_Path : String) is

      package Str_Sets is new Ada.Containers.Indefinite_Ordered_Sets (String);

      Header : constant String := Files.Read (Template_Path);
      Lines  : Unbounded_String;
      Seen   : Str_Sets.Set;
      First  : Boolean := True;

      procedure Add_Line (S : String) is
      begin
         if not First then
            Append (Lines, ASCII.LF);
         end if;
         First := False;
         Append (Lines, S);
      end Add_Line;
   begin
      for I in 1 .. Natural (O.Rows.Length) loop
         declare
            E : Outline.Row renames O.Rows (I);
         begin
            if E.K in Outline.Section | Outline.Sub_Entry then
               null;
            elsif not File_Map.Contains (To_String (E.Token)) then
               null;
            elsif Seen.Contains (File_Map.Element (To_String (E.Token))) then
               null;
            else
               Seen.Insert (File_Map.Element (To_String (E.Token)));
               Add_Line (Make_Chapter_Call
                 (File_Map.Element (To_String (E.Token)), E));
            end if;
         end;
      end loop;

      declare
         Marker : constant String :=
           "// Auto-generated by render.py from outline.txt " &
           Em_Dash & " DO NOT EDIT";
         Result : Unbounded_String;
      begin
         Append (Result, Header);
         Append (Result, ASCII.LF & Marker & ASCII.LF & ASCII.LF);
         Append (Result, Lines);
         Append (Result, ASCII.LF);
         Files.Write (Out_Path, To_String (Result));
      end;
   end Write_Book_Typ;

end Emit;
