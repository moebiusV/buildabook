--  outline.adb — the numbering engine.  A faithful port of render.py's
--  Outline class (its _parse, _apply_directive, display, and the number
--  formatters) so buildabook's designations and TOC match render.py's byte
--  for byte.

with Ada.Sequential_IO;
with Ada.Strings.Fixed;

with Outline_Grammar;
with Outline_Grammar.Parser;

package body Outline is

   use type Outline_Grammar.Bnf_content_Access;
   use type Outline_Grammar.Bnf_directive_Access;

   --  UTF-8 encoding of U+00A7 SECTION SIGN (§), written as explicit bytes so
   --  the source encoding can never turn it into a single Latin-1 byte.
   Section_Sign : constant String :=
     Character'Val (16#C2#) & Character'Val (16#A7#);

   -- ── raw file read ────────────────────────────────────────────────────────

   package Char_IO is new Ada.Sequential_IO (Character);

   function Read_File (Path : String) return String is
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
   end Read_File;

   -- ── small text helpers ───────────────────────────────────────────────────

   function Is_Space (C : Character) return Boolean is
   begin
      return C = ' ' or else C = Character'Val (9)   -- HTAB
        or else C = Character'Val (11)               -- VT
        or else C = Character'Val (12);              -- FF
   end Is_Space;

   --  Python str.strip() on the outline's character set: strip leading and
   --  trailing SP/HTAB/VT/FF.
   function Strip (S : Unbounded_String) return Unbounded_String is
      Str   : constant String := To_String (S);
      First : Natural := Str'First;
      Last  : Natural := Str'Last;
   begin
      while First <= Last and then Is_Space (Str (First)) loop
         First := First + 1;
      end loop;
      while Last >= First and then Is_Space (Str (Last)) loop
         Last := Last - 1;
      end loop;
      if First > Last then
         return Null_Unbounded_String;
      end if;
      return To_Unbounded_String (Str (First .. Last));
   end Strip;

   function Dec (N : Natural) return String is
   begin
      return Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left);
   end Dec;

   function To_Lower (S : String) return String is
      Result : String (S'Range);
   begin
      for I in S'Range loop
         if S (I) in 'A' .. 'Z' then
            Result (I) := Character'Val (Character'Pos (S (I)) + 32);
         else
            Result (I) := S (I);
         end if;
      end loop;
      return Result;
   end To_Lower;

   -- ── number formatters (render.py roman / letter_num / fmt_num) ──────────

   function Roman (N : Natural) return String is
      X      : Natural := N;
      Result : Unbounded_String;
      type RV is record
         Val : Natural;
         Num : String (1 .. 2);
         Len : Natural;
      end record;
      Vals : constant array (Positive range <>) of RV :=
        [(1000, "M ", 1), (900, "CM", 2), (500, "D ", 1), (400, "CD", 2),
         (100,  "C ", 1), (90,  "XC", 2), (50,  "L ", 1), (40,  "XL", 2),
         (10,   "X ", 1), (9,   "IX", 2), (5,   "V ", 1), (4,   "IV", 2),
         (1,    "I ", 1)];
   begin
      if N = 0 then
         return "0";
      end if;
      for I in Vals'Range loop
         while X >= Vals (I).Val loop
            Append (Result, Vals (I).Num (1 .. Vals (I).Len));
            X := X - Vals (I).Val;
         end loop;
      end loop;
      return To_String (Result);
   end Roman;

   function Letter_Num (N : Natural) return String is
      X   : Natural := N;
      Buf : Unbounded_String;
      Rev : Unbounded_String;
   begin
      if N = 0 then
         return "0";
      end if;
      while X > 0 loop
         X := X - 1;
         Append (Buf, Character'Val (Character'Pos ('A') + (X mod 26)));
         X := X / 26;
      end loop;
      for I in reverse 1 .. Length (Buf) loop
         Append (Rev, Element (Buf, I));
      end loop;
      return To_String (Rev);
   end Letter_Num;

   function Format_Number (Style : Number_Style; N : Natural) return String is
   begin
      case Style is
         when Arabic      => return Dec (N);
         when Roman       => return Roman (N);
         when Roman_Lower => return To_Lower (Roman (N));
         when Letter      => return Letter_Num (N);
         when No_Number   => return "";
      end case;
   end Format_Number;

   -- ── prefix / kind ────────────────────────────────────────────────────────

   function Prefix_Char (P : Outline_Grammar.Bnf_prefix_Type) return Character is
      S : constant String := To_String (P);
   begin
      if S'Length /= 1 then
         raise Outline_Error with "bad prefix";
      end if;
      return S (S'First);
   end Prefix_Char;

   function Kind_Of (Ch : Character) return Kind is
   begin
      case Ch is
         when 'c' => return Chapter;
         when 'p' => return Part;
         when 'a' => return Appendix;
         when 'd' => return Division;
         when 'n' => return Front_Matter;
         when 'u' => return Unlisted;
         when 's' => return Section;
         when 'k' => return Sub_Entry;
         when others => raise Outline_Error with "unknown prefix '" & Ch & "'";
      end case;
   end Kind_Of;

   type Prefix_Id is (C_Id, P_Id, A_Id, D_Id, N_Id, U_Id, S_Id, K_Id);

   function Prefix_Id_Of (Ch : Character) return Prefix_Id is
   begin
      case Ch is
         when 'c' => return C_Id;
         when 'p' => return P_Id;
         when 'a' => return A_Id;
         when 'd' => return D_Id;
         when 'n' => return N_Id;
         when 'u' => return U_Id;
         when 's' => return S_Id;
         when 'k' => return K_Id;
         when others => raise Outline_Error with "unknown prefix '" & Ch & "'";
      end case;
   end Prefix_Id_Of;

   function Default_Label (Ch : Character) return Unbounded_String is
   begin
      case Ch is
         when 'c' => return To_Unbounded_String ("Chapter");
         when 'p' => return To_Unbounded_String ("Part");
         when 'a' => return To_Unbounded_String ("Appendix");
         when others => return Null_Unbounded_String;
      end case;
   end Default_Label;

   function Default_Short (Ch : Character; Label : Unbounded_String)
     return Unbounded_String is
   begin
      case Ch is
         when 'c' => return To_Unbounded_String ("Ch");
         when 'p' => return To_Unbounded_String ("Pt");
         when 'a' => return To_Unbounded_String ("App");
         when others => return Label;
      end case;
   end Default_Short;

   function Default_Number (Kid : Kind) return Number_Style is
   begin
      case Kid is
         when Chapter   => return Arabic;
         when Part      => return Roman;
         when Appendix  => return Letter;
         when Section   => return Arabic;
         when Division | Front_Matter | Unlisted | Sub_Entry => return No_Number;
      end case;
   end Default_Number;

   -- ── directive state ──────────────────────────────────────────────────────

   type State is record
      Has_Label      : Boolean := False;
      Label          : Unbounded_String;
      Has_Short      : Boolean := False;
      Short          : Unbounded_String;
      Has_Number     : Boolean := False;
      Number         : Number_Style := Arabic;
      Has_Next       : Boolean := False;
      Next           : Natural := 0;
      Suppress_Title : Boolean := False;
      No_Toc         : Boolean := False;
   end record;

   type State_Array is array (Prefix_Id) of State;

   function Style_Of (Value : String) return Number_Style is
   begin
      if Value = "arabic" or else Value = "arab" then
         return Arabic;
      elsif Value = "roman" then
         return Roman;
      elsif Value = "roman-lower" then
         return Roman_Lower;
      elsif Value = "letter" then
         return Letter;
      elsif Value = "none" then
         return No_Number;
      else
         raise Outline_Error with "unknown number style '" & Value & "'";
      end if;
   end Style_Of;

   procedure Apply_Directive
     (St : in out State; Name : Outline_Grammar.Bnf_name_Type;
      Value : Unbounded_String) is
      V    : constant String := To_String (Value);
      Pipe : Natural;
   begin
      case Name is
         when Outline_Grammar.Bnf_name_Label =>
            Pipe := Ada.Strings.Fixed.Index (V, "|");
            if Pipe /= 0 then
               St.Has_Label := True;
               St.Label := Strip (To_Unbounded_String (V (V'First .. Pipe - 1)));
               St.Has_Short := True;
               St.Short := Strip (To_Unbounded_String (V (Pipe + 1 .. V'Last)));
            else
               St.Has_Label := True;
               St.Label := Value;
               St.Has_Short := True;
               St.Short := Value;
            end if;
         when Outline_Grammar.Bnf_name_Number =>
            St.Has_Number := True;
            St.Number := Style_Of (V);
         when Outline_Grammar.Bnf_name_Count =>
            begin
               St.Next := Natural'Value (V);
               St.Has_Next := True;
            exception
               when Constraint_Error =>
                  raise Outline_Error with
                    "count requires an integer, got '" & V & "'";
            end;
         when Outline_Grammar.Bnf_name_Default =>
            if V = "label" then
               St.Has_Label := False;
               St.Has_Short := False;
            elsif V = "number" then
               St.Has_Number := False;
            elsif V = "count" then
               St.Next := 1;
               St.Has_Next := True;
            elsif V = "title" then
               St.Suppress_Title := False;
            elsif V = "toc" then
               St.No_Toc := False;
            else
               raise Outline_Error with
                 "default takes label/number/count/title/toc, got '" & V & "'";
            end if;
         when Outline_Grammar.Bnf_name_None =>
            if V = "label" then
               St.Has_Label := True;
               St.Label := Null_Unbounded_String;
               St.Has_Short := True;
               St.Short := Null_Unbounded_String;
            elsif V = "number" then
               St.Has_Number := True;
               St.Number := No_Number;
            elsif V = "title" then
               St.Suppress_Title := True;
            elsif V = "toc" then
               St.No_Toc := True;
            else
               raise Outline_Error with
                 "none takes label/number/title/toc, got '" & V & "'";
            end if;
      end case;
   end Apply_Directive;

   -- ── the directive value: free text to end of line ───────────────────────

   function Value_Text (V : Outline_Grammar.Bnf_value_Type) return Unbounded_String is
   begin
      return V;
   end Value_Text;

   function Title_Of (C : Outline_Grammar.Bnf_content_Type) return Unbounded_String is
      T : constant Unbounded_String := C.Bnf_content_1;
   begin
      return Strip (T);
   end Title_Of;

   -- ── Load ─────────────────────────────────────────────────────────────────

   function Load (Path : String) return Outline_Type is
      Tree : Outline_Grammar.Bnf_outline_Type;
      R    : Outline_Type;

      Sts        : State_Array;
      Counters   : array (Prefix_Id) of Natural := [others => 0];
      --  render.py keeps section_counters as a map keyed by the current parent,
      --  but only the current parent is ever read or written, so a single
      --  counter reset at each chapter/division/unlisted boundary is equivalent.
      Current_Section : Natural := 0;
      Current_Parent  : Unbounded_String;   -- "" = none

      procedure Add_Row (E : Row; Key : String) is
      begin
         if R.By_Uuid.Contains (Key) then
            raise Outline_Error with "duplicate UUID: " & Key;
         end if;
         R.Rows.Append (E);
         R.By_Uuid.Insert (Key, Positive (R.Rows.Length));
      end Add_Row;

   begin
      Tree := Outline_Grammar.Parser.Parse_Text (Read_File (Path) & ASCII.LF);

      --  a line is an entry or nothing (a blank or comment line); the file text
      --  gets a final LF so that a last line without one parses
      for I in 1 .. Natural (Tree.Length) loop
       for J in 1 .. Natural (Tree (I).Bnf_line_1.Length) loop
         declare
            EG : Outline_Grammar.Bnf_entry_Type renames Tree (I).Bnf_line_1 (J).all;
         begin
            if EG.Bnf_directive /= null then
               declare
                  D : Outline_Grammar.Bnf_directive_Type renames EG.Bnf_directive.all;
               begin
                  Apply_Directive
                    (Sts (Prefix_Id_Of (Prefix_Char (D.Bnf_prefix))),
                     D.Bnf_tail.all.Bnf_name, Strip (Value_Text (D.Bnf_tail.all.Bnf_value)));
               end;
            elsif EG.Bnf_content /= null then
               declare
                  C    : Outline_Grammar.Bnf_content_Type renames EG.Bnf_content.all;
                  Ch   : constant Character := Prefix_Char (C.Bnf_prefix);
                  Kid  : constant Kind := Kind_Of (Ch);
                  Uuid : constant String := To_String (C.Bnf_uuid);
                  St   : State renames Sts (Prefix_Id_Of (Ch));

                  E     : Row;
                  Label : Unbounded_String;
                  Base  : Unbounded_String;
                  Minor : Unbounded_String;
                  Key   : Unbounded_String;
               begin
                  if Kid = Sub_Entry then
                     declare
                        Dot : constant Natural := Ada.Strings.Fixed.Index (Uuid, ".");
                     begin
                        if Dot = 0 then
                           raise Outline_Error with
                             "k: requires a MINOR index (k:NNNNN.MINOR): " & Uuid;
                        end if;
                        Base := To_Unbounded_String (Uuid (Uuid'First .. Dot - 1));
                        Minor := To_Unbounded_String (Uuid (Dot + 1 .. Uuid'Last));
                        Key := To_Unbounded_String (Uuid);
                     end;

                     E := (Token          => To_Unbounded_String ("k:" & Uuid),
                           K              => Sub_Entry,
                           Uuid           => Base,
                           Minor          => Minor,
                           Title          => Title_Of (C),
                           Parent         => Current_Parent,
                           N              => 0,
                           Has_N          => False,
                           Label          => Null_Unbounded_String,
                           Short          => Null_Unbounded_String,
                           Style          => No_Number,
                           Suppress_Title => False,
                           Toc            => False);

                  else
                     Label := (if St.Has_Label then St.Label
                               else Default_Label (Ch));

                     E := (Token          => To_Unbounded_String (Ch & ':' & Uuid),
                           K              => Kid,
                           Uuid           => To_Unbounded_String (Uuid),
                           Minor          => Null_Unbounded_String,
                           Title          => Title_Of (C),
                           Parent         => Null_Unbounded_String,
                           N              => 0,
                           Has_N          => False,
                           Label          => Label,
                           Short          => (if St.Has_Short then St.Short
                                             else Default_Short (Ch, Label)),
                           Style          => (if St.Has_Number then St.Number
                                             else Default_Number (Kid)),
                           Suppress_Title => St.Suppress_Title,
                           Toc            => not St.No_Toc);

                     case Kid is
                        when Chapter | Part | Appendix =>
                           declare
                              N : Natural;
                           begin
                              if St.Has_Next then
                                 N := St.Next;
                                 St.Has_Next := False;   -- one-shot
                              else
                                 N := Counters (Prefix_Id_Of (Ch)) + 1;
                              end if;
                              Counters (Prefix_Id_Of (Ch)) := N;
                              E.N := N;
                              E.Has_N := True;
                              if Kid = Chapter then
                                 Current_Parent := E.Uuid;
                                 Current_Section := 0;
                              end if;
                           end;
                        when Division | Front_Matter | Unlisted =>
                           E.Label := Null_Unbounded_String;
                           E.Short := Null_Unbounded_String;
                           E.Style := No_Number;
                           if Kid = Unlisted then
                              E.Toc := False;
                           end if;
                           Current_Parent := E.Uuid;
                           Current_Section := 0;
                        when Section =>
                           if Length (Current_Parent) = 0 then
                              raise Outline_Error with
                                "section " & To_String (E.Token) &
                                " appears before any chapter, division, front-matter, or unlisted entry";
                           end if;
                           E.Parent := Current_Parent;
                           Current_Section := Current_Section + 1;
                           E.N := Current_Section;
                           E.Has_N := True;
                        when Sub_Entry =>
                           null;   -- handled above
                     end case;

                     Key := E.Uuid;
                  end if;

                  Add_Row (E, To_String (Key));
               end;
            end if;
         end;
       end loop;
      end loop;

      return R;
   end Load;

   -- ── Display ──────────────────────────────────────────────────────────────

   function Display
     (E : Row; Number_Only : Boolean := False;
      Short_Form : Boolean := False) return String is
   begin
      case E.K is
         when Division | Front_Matter | Unlisted =>
            return To_String (E.Title);
         when Sub_Entry =>
            if Length (E.Title) > 0 then
               return To_String (E.Title);
            else
               return To_String (E.Uuid) & "." & To_String (E.Minor);
            end if;
         when Section =>
            if Number_Only then
               return Dec (E.N);
            else
               return Section_Sign & Dec (E.N);
            end if;
         when Chapter | Part | Appendix =>
            if E.Style = No_Number then
               if Length (E.Label) > 0 then
                  return To_String (E.Label);
               else
                  return To_String (E.Title);
               end if;
            end if;
            declare
               Num : constant String := Format_Number (E.Style, E.N);
            begin
               if Number_Only or else Length (E.Label) = 0 then
                  return Num;
               end if;
               if Short_Form then
                  if Length (E.Short) > 0 then
                     return To_String (E.Short) & " " & Num;
                  else
                     return Num;
                  end if;
               end if;
               return To_String (E.Label) & " " & Num;
            end;
      end case;
   end Display;

end Outline;
