--  materialize.adb — the per-file pass, byte-identical to render.py.

with Ada.Exceptions;
with Ada.Strings.Fixed;

with Files;

package body Materialize is

   package Line_Vectors is new Ada.Containers.Vectors
     (Positive, Unbounded_String);

   type Section_Mark is record
      Line : Natural;           -- 0-based line index in the source
      Uuid : Unbounded_String;
   end record;
   package Mark_Vectors is new Ada.Containers.Vectors (Positive, Section_Mark);

   function Is_Space (C : Character) return Boolean is
   begin
      return C = ' ' or else C = Character'Val (9) or else C = Character'Val (13);
   end Is_Space;

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

   function Split_Lines (Text : String) return Line_Vectors.Vector is
      Lines : Line_Vectors.Vector;
      Start : Natural := Text'First;
   begin
      for I in Text'Range loop
         if Text (I) = ASCII.LF then
            Lines.Append (To_Unbounded_String (Text (Start .. I - 1)));
            Start := I + 1;
         end if;
      end loop;
      Lines.Append (To_Unbounded_String (Text (Start .. Text'Last)));
      return Lines;
   end Split_Lines;

   function Join_Lines (Lines : Line_Vectors.Vector) return String is
      Acc : Unbounded_String;
   begin
      for I in 1 .. Natural (Lines.Length) loop
         if I > 1 then
            Append (Acc, ASCII.LF);
         end if;
         Append (Acc, Lines (I));
      end loop;
      return To_String (Acc);
   end Join_Lines;

   -- ── no-giant-tables rule ─────────────────────────────────────────────────

   --  TABLE_SEP_RE: ^\s*\|[\s:|\-]+\|?\s*$
   function Is_Table_Sep (Line : String) return Boolean is
      First : Natural := Line'First;
      Last  : Natural := Line'Last;
      Count : Natural;
   begin
      while First <= Last and then Is_Space (Line (First)) loop
         First := First + 1;
      end loop;
      while Last >= First and then Is_Space (Line (Last)) loop
         Last := Last - 1;
      end loop;
      if First > Last or else Line (First) /= '|' then
         return False;
      end if;
      if Last > First and then Line (Last) = '|' then
         Last := Last - 1;   -- optional trailing |
      end if;
      Count := 0;
      for I in First + 1 .. Last loop
         if Line (I) = ' ' or else Line (I) = ASCII.HT
           or else Line (I) = ':' or else Line (I) = '|' or else Line (I) = '-'
         then
            Count := Count + 1;
         else
            return False;
         end if;
      end loop;
      return Count > 0;
   end Is_Table_Sep;

   --  line.lstrip().startswith('|')
   function Starts_With_Pipe (Line : String) return Boolean is
      I : Natural := Line'First;
   begin
      while I <= Line'Last and then Is_Space (Line (I)) loop
         I := I + 1;
      end loop;
      return I <= Line'Last and then Line (I) = '|';
   end Starts_With_Pipe;

   function Split_Long_Tables (Text : String; Max_Rows : Natural) return String is
   begin
      if Max_Rows <= 0 then
         return Text;
      end if;

      declare
         Lines : Line_Vectors.Vector := Split_Lines (Text);
         Acc   : Line_Vectors.Vector;
         I     : Natural := 1;
         N     : constant Natural := Natural (Lines.Length);
      begin
         while I <= N loop
            declare
               Line : constant String := To_String (Lines (I));
            begin
               if I < N and then Starts_With_Pipe (Line)
                 and then Is_Table_Sep (To_String (Lines (I + 1)))
               then
                  declare
                     Header : constant String := Line;
                     Sep    : constant String := To_String (Lines (I + 1));
                     J      : Natural := I + 2;
                     Data   : Line_Vectors.Vector;
                  begin
                     while J <= N loop
                        declare
                           D : constant String := To_String (Lines (J));
                        begin
                           exit when not Starts_With_Pipe (D);
                        end;
                        Data.Append (Lines (J));
                        J := J + 1;
                     end loop;

                     if Natural (Data.Length) > Max_Rows then
                        declare
                           K  : Natural := 1;
                           DN : constant Natural := Natural (Data.Length);
                        begin
                           while K <= DN loop
                              if K > 1 then
                                 Acc.Append (Null_Unbounded_String);
                              end if;
                              Acc.Append (To_Unbounded_String (Header));
                              Acc.Append (To_Unbounded_String (Sep));
                              declare
                                 Limit : constant Natural :=
                                   Natural'Min (K + Max_Rows - 1, DN);
                              begin
                                 for M in K .. Limit loop
                                    Acc.Append (Data (M));
                                 end loop;
                                 K := Limit + 1;
                              end;
                           end loop;
                        end;
                     else
                        Acc.Append (To_Unbounded_String (Header));
                        Acc.Append (To_Unbounded_String (Sep));
                        for M in 1 .. Natural (Data.Length) loop
                           Acc.Append (Data (M));
                        end loop;
                     end if;

                     I := J;
                  end;
               else
                  Acc.Append (Lines (I));
                  I := I + 1;
               end if;
            end;
         end loop;

         return Join_Lines (Acc);
      end;
   end Split_Long_Tables;

   -- ── materialize one file ─────────────────────────────────────────────────

   function Is_Heading (Line : String) return Boolean is
      N : Natural := 0;
      I : Natural := Line'First;
   begin
      while I <= Line'Last and then Line (I) = '#' loop
         N := N + 1;
         I := I + 1;
      end loop;
      if N < 2 or else N > 6 then
         return False;
      end if;
      if I > Line'Last then
         return False;
      end if;
      return Line (I) = ' ' or else Line (I) = ASCII.HT;
   end Is_Heading;

   procedure Materialize_File
     (R : Tokens.Resolver; Src_Path : String; Dst_Path : String;
      Errors : in out Error_List) is

      Text : constant String := Files.Read (Src_Path);

      Marks    : Mark_Vectors.Vector;
      Line_No  : Natural := 0;
      Start    : Natural := Text'First;
      I        : Natural;
   begin
      --  First: find section tokens in sub-heading lines of the ORIGINAL text.
      loop
         I := Ada.Strings.Fixed.Index
           (Text (Start .. Text'Last), String'(1 => ASCII.LF));
         declare
            Line : constant String :=
              (if I = 0 then Text (Start .. Text'Last)
               else Text (Start .. I - 1));
         begin
            if Is_Heading (Line) then
               declare
                  P : Natural := Line'First;
               begin
                  while P <= Line'Last - 1 loop
                     if Line (P) = '{' and then Line (P + 1) = '{' then
                        declare
                           Q : constant Natural :=
                             Ada.Strings.Fixed.Index
                               (Line (P + 2 .. Line'Last), "}}");
                        begin
                           if Q = 0 then
                              P := Line'Last + 1;
                           else
                              declare
                                 Tok_Body : constant String :=
                                   Strip_WS (Line (P + 2 .. Q - 1));
                              begin
                                 if Tok_Body'Length >= 2
                                   and then Tok_Body (Tok_Body'First .. Tok_Body'First + 1) = "s:"
                                 then
                                    declare
                                       Rest : constant String :=
                                         Tok_Body (Tok_Body'First + 2 .. Tok_Body'Last);
                                       Pipe : constant Natural :=
                                         Ada.Strings.Fixed.Index (Rest, "|");
                                       Uuid : constant String :=
                                         Strip_WS (if Pipe = 0 then Rest
                                                   else Rest (Rest'First .. Pipe - 1));
                                    begin
                                       if Uuid /= ""
                                         and then R.O.By_Uuid.Contains (Uuid)
                                       then
                                          Marks.Append
                                            (Section_Mark'
                                               (Line => Line_No,
                                                Uuid => To_Unbounded_String (Uuid)));
                                       end if;
                                    end;
                                 end if;
                              end;
                              P := Q + 2;
                           end if;
                        end;
                     else
                        P := P + 1;
                     end if;
                  end loop;
               end;
            end if;
         end;
         exit when I = 0;
         Start := I + 1;
         Line_No := Line_No + 1;
      end loop;

      --  Second: substitute every {{…}} token.
      declare
         Acc      : Unbounded_String;
         P        : Natural := Text'First;
         Tok_Line : Natural := 1;
      begin
         while P <= Text'Last loop
            if P < Text'Last and then Text (P) = '{' and then Text (P + 1) = '{' then
               declare
                  Q : constant Natural :=
                    Ada.Strings.Fixed.Index (Text (P + 2 .. Text'Last), "}}");
               begin
                  if Q = 0 then
                     Append (Acc, "{{");
                     P := P + 2;
                  else
                     declare
                        Tok_Body : constant String := Text (P + 2 .. Q - 1);
                     begin
                        declare
                           Rendered : constant String := Tokens.Resolve (R, Tok_Body);
                        begin
                           Append (Acc, Rendered);
                        exception
                           when E : Tokens.Tokens_Error =>
                              declare
                                 Msg : constant String :=
                                   Ada.Exceptions.Exception_Message (E);
                              begin
                                 Errors.Append
                                   (To_Unbounded_String
                                      (Src_Path & ":" &
                                       Ada.Strings.Fixed.Trim
                                         (Natural'Image (Tok_Line),
                                          Ada.Strings.Left) & ": " & Msg));
                                 Append (Acc, "{{ERROR:" & Msg & "}}");
                              end;
                        end;
                     end;
                     P := Q + 2;
                  end if;
               end;
            else
               if Text (P) = ASCII.LF then
                  Tok_Line := Tok_Line + 1;
               end if;
               Append (Acc, Text (P));
               P := P + 1;
            end if;
         end loop;

         --  Third: plant the page markers after the section headings.
         declare
            Lines : Line_Vectors.Vector := Split_Lines (To_String (Acc));
         begin
            for K in reverse 1 .. Natural (Marks.Length) loop
               declare
                  M : Section_Mark renames Marks (K);
               begin
                  Lines.Insert
                    (M.Line + 2,
                     To_Unbounded_String ("<!--raw-typst #pgan(""" &
                                          To_String (M.Uuid) & """)-->"));
               end;
            end loop;

            Files.Write
              (Dst_Path, Split_Long_Tables (Join_Lines (Lines), 40));
         end;
      end;
   end Materialize_File;

end Materialize;
