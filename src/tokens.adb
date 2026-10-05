--  tokens.adb — the {{token}} resolver and TOC generator, a faithful port of
--  render.py's resolve_token / _resolve_stack / _resolve_chapter_list /
--  generate_toc / join_and, so substituted prose and the TOC match byte for
--  byte.

with Ada.Strings.Fixed;

package body Tokens is

   use type Outline.Kind;

   --  UTF-8 for U+2014 EM DASH and U+00A7 SECTION SIGN, as explicit bytes so
   --  the source encoding can never change them.
   Em_Dash      : constant String :=
     Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#94#);
   Section_Sign : constant String :=
     Character'Val (16#C2#) & Character'Val (16#A7#);

   function Is_Space (C : Character) return Boolean is
   begin
      return C = ' ' or else C = Character'Val (9)   -- HTAB
        or else C = Character'Val (10)               -- LF
        or else C = Character'Val (11)               -- VT
        or else C = Character'Val (12)               -- FF
        or else C = Character'Val (13);              -- CR
   end Is_Space;

   --  Python str.strip(): strip leading/trailing whitespace.
   function Strip_WS (S : String) return String is
      First : Natural := S'First;
      Last  : Natural := S'Last;
   begin
      while First <= Last and then Is_Space (S (First)) loop
         First := First + 1;
      end loop;
      while Last >= First and then Is_Space (S (Last)) loop
         Last := Last - 1;
      end loop;
      if First > Last then
         return "";
      end if;
      return S (First .. Last);
   end Strip_WS;

   function Dec (N : Natural) return String is
   begin
      return Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left);
   end Dec;

   function Has_Flag (Flags : Str_Vectors.Vector; F : String) return Boolean is
   begin
      for I in 1 .. Natural (Flags.Length) loop
         if To_String (Flags (I)) = F then
            return True;
         end if;
      end loop;
      return False;
   end Has_Flag;

   -- ── join_and ─────────────────────────────────────────────────────────────

   function Join_And (Items : Str_Vectors.Vector) return String is
      B : Unbounded_String;
   begin
      case Natural (Items.Length) is
         when 0 =>
            return "";
         when 1 =>
            return To_String (Items (1));
         when 2 =>
            return To_String (Items (1)) & " and " & To_String (Items (2));
         when others =>
            for I in 1 .. Natural (Items.Length) loop
               if I > 1 then
                  if I = Natural (Items.Length) then
                     Append (B, ", and ");
                  else
                     Append (B, ", ");
                  end if;
               end if;
               Append (B, Items (I));
            end loop;
            return To_String (B);
      end case;
   end Join_And;

   -- ── TOC ──────────────────────────────────────────────────────────────────

   function Toc_Text (E : Outline.Row) return String is
      Disp  : constant String :=
        (if E.K in Outline.Division | Outline.Front_Matter | Outline.Unlisted then ""
         else Outline.Display (E));
      Title : constant String :=
        (if E.Suppress_Title then "" else To_String (E.Title));
   begin
      if Disp /= "" and then Title /= "" and then Disp /= Title then
         return Disp & " " & Em_Dash & " " & Title;
      end if;
      if Disp /= "" then
         return Disp;
      else
         return Title;
      end if;
   end Toc_Text;

   function Generate_Toc (R : Resolver) return String is
      Lines : Str_Vectors.Vector;
   begin
      for I in 1 .. Natural (R.O.Rows.Length) loop
         declare
            E : Outline.Row renames R.O.Rows (I);
         begin
            if E.Toc then
               case E.K is
                  when Outline.Part =>
                     if Natural (Lines.Length) > 0 then
                        Lines.Append (Null_Unbounded_String);
                     end if;
                     Lines.Append
                       (To_Unbounded_String ("**" & Toc_Text (E) & "**"));
                  when Outline.Chapter | Outline.Appendix | Outline.Division =>
                     Lines.Append (To_Unbounded_String ("- " & Toc_Text (E)));
                  when others =>
                     null;   -- sections and sub-entries are omitted
               end case;
            end if;
         end;
      end loop;

      declare
         Joined : Unbounded_String;
      begin
         for I in 1 .. Natural (Lines.Length) loop
            if I > 1 then
               Append (Joined, ASCII.LF);
            end if;
            Append (Joined, Lines (I));
         end loop;
         return Strip_WS (To_String (Joined));
      end;
   end Generate_Toc;

   -- ── k: sub-entry ────────────────────────────────────────────────────────

   function Resolve_Stack (R : Resolver; Uuid_Part : String) return String is
      Dot    : constant Natural := Ada.Strings.Fixed.Index (Uuid_Part, ".");
      Uuid   : Unbounded_String;
      Minor  : Unbounded_String;
      Dbkey  : Unbounded_String;
      Parent_N : Unbounded_String;
   begin
      if Dot = 0 then
         raise Tokens_Error with "Stack token missing minor index: " & Uuid_Part;
      end if;
      Uuid := To_Unbounded_String (Strip_WS (Uuid_Part (Uuid_Part'First .. Dot - 1)));
      Minor := To_Unbounded_String (Strip_WS (Uuid_Part (Dot + 1 .. Uuid_Part'Last)));
      Dbkey := To_Unbounded_String (To_String (Uuid) & "." & To_String (Minor));

      if not R.O.By_Uuid.Contains (To_String (Dbkey)) then
         raise Tokens_Error with "Stack not in outline: " & To_String (Dbkey);
      end if;

      if R.O.By_Uuid.Contains (To_String (Uuid)) then
         declare
            Parent : Outline.Row renames
              R.O.Rows (R.O.By_Uuid.Element (To_String (Uuid)));
         begin
            if Parent.K = Outline.Chapter and then Parent.Has_N then
               Parent_N := To_Unbounded_String (Dec (Parent.N));
            else
               Parent_N := To_Unbounded_String ("?");
            end if;
         end;
      else
         Parent_N := To_Unbounded_String ("?");
      end if;

      return Section_Sign & To_String (Parent_N) & "." & To_String (Minor);
   end Resolve_Stack;

   -- ── cc: chapter list ─────────────────────────────────────────────────────

   function Resolve_Chapter_List
     (R : Resolver; Uuid_List : String; Sort_Flag : Boolean) return String is
      Recs  : Outline.Row_Vectors.Vector;
      Start : Natural := Uuid_List'First;
      I     : Natural;
   begin
      loop
         I := Ada.Strings.Fixed.Index (Uuid_List (Start .. Uuid_List'Last), ",");
         declare
            Part : constant String :=
              (if I = 0 then Uuid_List (Start .. Uuid_List'Last)
               else Uuid_List (Start .. I - 1));
            U : constant String := Strip_WS (Part);
         begin
            if U /= "" then
               if not R.O.By_Uuid.Contains (U) then
                  raise Tokens_Error with "UUID not in outline: cc:" & U;
               end if;
               declare
                  E : Outline.Row renames R.O.Rows (R.O.By_Uuid.Element (U));
               begin
                  if E.K /= Outline.Chapter then
                     raise Tokens_Error with
                       "cc: token expects chapters, but UUID " & U &
                       " is a " & E.K'Image;
                  end if;
                  Recs.Append (E);
               end;
            end if;
         end;
         exit when I = 0;
         Start := I + 1;
      end loop;

      if Natural (Recs.Length) = 0 then
         raise Tokens_Error with "Empty chapter list in token";
      end if;

      if Sort_Flag then
         for J in 2 .. Natural (Recs.Length) loop
            declare
               Key : constant Outline.Row := Recs (J);
               K   : Natural := J;
            begin
               while K > 1 and then Recs (K - 1).N > Key.N loop
                  Recs (K) := Recs (K - 1);
                  K := K - 1;
               end loop;
               Recs (K) := Key;
            end;
         end loop;
      end if;

      declare
         Same        : Boolean := True;
         First_Label : constant String := To_String (Recs (1).Label);
      begin
         for J in 2 .. Natural (Recs.Length) loop
            if To_String (Recs (J).Label) /= First_Label then
               Same := False;
               exit;
            end if;
         end loop;

         if Same then
            declare
               Nums : Str_Vectors.Vector;
            begin
               for J in 1 .. Natural (Recs.Length) loop
                  Nums.Append
                    (To_Unbounded_String
                       (Outline.Format_Number (Recs (J).Style, Recs (J).N)));
               end loop;
               declare
                  Joined : constant String := Join_And (Nums);
               begin
                  if First_Label = "" then
                     return Joined;
                  end if;
                  if Natural (Recs.Length) > 1 then
                     return First_Label & "s " & Joined;
                  else
                     return First_Label & " " & Joined;
                  end if;
               end;
            end;
         else
            declare
               Disps : Str_Vectors.Vector;
            begin
               for J in 1 .. Natural (Recs.Length) loop
                  Disps.Append (To_Unbounded_String (Outline.Display (Recs (J))));
               end loop;
               return Join_And (Disps);
            end;
         end if;
      end;
   end Resolve_Chapter_List;

   -- ── Resolve ──────────────────────────────────────────────────────────────

   function Kind_Of (Prefix : String) return Outline.Kind is
   begin
      if Prefix = "c" then return Outline.Chapter;
      elsif Prefix = "p" then return Outline.Part;
      elsif Prefix = "a" then return Outline.Appendix;
      elsif Prefix = "d" then return Outline.Division;
      elsif Prefix = "n" then return Outline.Front_Matter;
      elsif Prefix = "u" then return Outline.Unlisted;
      elsif Prefix = "s" then return Outline.Section;
      else raise Tokens_Error with "Unknown token prefix: " & Prefix;
      end if;
   end Kind_Of;

   function Resolve (R : Resolver; Token_Body : String) return String is
      B : constant String := Strip_WS (Token_Body);

      function Split_First (S : String; Sep : Character)
        return Str_Vectors.Vector is
         V     : Str_Vectors.Vector;
         Start : Natural := S'First;
         I     : Natural;
      begin
         loop
            I := Ada.Strings.Fixed.Index (S (Start .. S'Last), String'(1 => Sep));
            if I = 0 then
               V.Append (To_Unbounded_String (S (Start .. S'Last)));
               exit;
            end if;
            V.Append (To_Unbounded_String (S (Start .. I - 1)));
            Start := I + 1;
         end loop;
         return V;
      end Split_First;

      Parts  : Str_Vectors.Vector;
      Flags  : Str_Vectors.Vector;
      Prefix : Unbounded_String;
      Uuid   : Unbounded_String;
      Colon  : Natural;
   begin
      if B = "toc" then
         return Generate_Toc (R);
      end if;

      if B'Length >= 7 and then B (B'First .. B'First + 6) = "anchor:" then
         declare
            Aid : constant String := Strip_WS (B (B'First + 7 .. B'Last));
         begin
            if not R.Anchor_Ids.Contains (Aid) then
               raise Tokens_Error with
                 "anchor id " & Aid & " was not registered (pre-scan missed it?)";
            end if;
            return "<!--raw-typst #pgan(""" & Aid & """)-->";
         end;
      end if;

      if B'Length >= 5 and then B (B'First .. B'First + 4) = "page:" then
         declare
            Ident : constant String := Strip_WS (B (B'First + 5 .. B'Last));
         begin
            if not R.Anchor_Ids.Contains (Ident)
              and then not R.O.By_Uuid.Contains (Ident)
            then
               raise Tokens_Error with
                 "page ref " & Ident & ": no such anchor or outline entry";
            end if;
            return "<!--raw-typst #pageof(""" & Ident & """)-->";
         end;
      end if;

      Parts := Split_First (B, '|');
      declare
         Head_Str : constant String := Strip_WS (To_String (Parts (1)));
      begin
         for J in 2 .. Natural (Parts.Length) loop
            Flags.Append (To_Unbounded_String (Strip_WS (To_String (Parts (J)))));
         end loop;

         Colon := Ada.Strings.Fixed.Index (Head_Str, ":");
         if Colon = 0 then
            raise Tokens_Error with "Invalid token (no colon): " & B;
         end if;
         Prefix := To_Unbounded_String (Strip_WS (Head_Str (Head_Str'First .. Colon - 1)));
         Uuid   := To_Unbounded_String (Strip_WS (Head_Str (Colon + 1 .. Head_Str'Last)));
      end;

      if To_String (Prefix) = "cc" then
         return Resolve_Chapter_List (R, To_String (Uuid), Has_Flag (Flags, "sort"));
      end if;

      if To_String (Prefix) = "k" then
         return Resolve_Stack (R, To_String (Uuid));
      end if;

      declare
         Kid : constant Outline.Kind := Kind_Of (To_String (Prefix));
      begin
         if not R.O.By_Uuid.Contains (To_String (Uuid)) then
            raise Tokens_Error with
              "UUID not in outline: " & To_String (Prefix) & ":" & To_String (Uuid);
         end if;
         declare
            E : Outline.Row renames R.O.Rows (R.O.By_Uuid.Element (To_String (Uuid)));
         begin
            if E.K /= Kid then
               raise Tokens_Error with
                 "Token prefix '" & To_String (Prefix) & "' expects a " &
                 Kid'Image & ", but UUID " & To_String (Uuid) & " is a " & E.K'Image;
            end if;
            if Has_Flag (Flags, "page") then
               return "<!--raw-typst #pageof(""" & To_String (Uuid) & """)-->";
            end if;
            return Outline.Display
              (E, Has_Flag (Flags, "n"), Has_Flag (Flags, "s"));
         end;
      end;
   end Resolve;

end Tokens;
