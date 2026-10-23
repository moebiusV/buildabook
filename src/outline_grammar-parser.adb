
with Interfaces;
with Ada.Unchecked_Deallocation;

package body Outline_Grammar.Parser is

   use Ada.Strings.Unbounded;
   use Interfaces;   function Scan_Word (S : String; Pos, Len : Natural) return Natural is
      I : Natural := Pos;
   begin
      if I > Len
        or else S (I) not in 'a' .. 'z' | 'A' .. 'Z' | '_' | '-'
      then
         return 0;
      end if;
      I := I + 1;
      while I <= Len
        and then S (I) in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '-' | '.'
      loop
         I := I + 1;
      end loop;
      return I - Pos;
   end Scan_Word;

   function Scan_Int (S : String; Pos, Len : Natural) return Natural is
      I     : Natural := Pos;
      Start : Natural;
   begin
      if I < Len and then S (I) = '-' and then S (I + 1) in '0' .. '9' then
         I := I + 1;
      end if;
      Start := I;
      while I <= Len and then S (I) in '0' .. '9' loop
         I := I + 1;
      end loop;
      return (if I > Start then I - Pos else 0);
   end Scan_Int;

   function Scan_Str (S : String; Pos, Len : Natural) return Natural is
      I : Natural;
   begin
      if Pos > Len or else S (Pos) /= '"' then
         return 0;
      end if;
      I := Pos + 1;
      while I <= Len and then S (I) /= '"' loop
         if S (I) = '\' and then I < Len then
            I := I + 1;
         end if;
         I := I + 1;
      end loop;
      if I > Len then
         return 0;
      end if;
      return I + 1 - Pos;
   end Scan_Str;

   function Decode_Utf8 (S : String; Pos, Len : Natural; Cp : out Natural) return Natural is
      B0 : Unsigned_32;
      N  : Natural := 0;
      C  : Unsigned_32 := 0;
      B  : Unsigned_32;
   begin
      Cp := 0;
      if Pos > Len then return 0; end if;
      B0 := Unsigned_32 (Character'Pos (S (Pos)));
      if B0 < 16#80# then
         Cp := Natural (B0); return 1;
      elsif (B0 and 16#E0#) = 16#C0# then N := 2; C := B0 and 16#1F#;
      elsif (B0 and 16#F0#) = 16#E0# then N := 3; C := B0 and 16#0F#;
      elsif (B0 and 16#F8#) = 16#F0# then N := 4; C := B0 and 16#07#;
      else return 0;
      end if;
      if Pos + N - 1 > Len then return 0; end if;
      for J in 1 .. N - 1 loop
         B := Unsigned_32 (Character'Pos (S (Pos + J)));
         if (B and 16#C0#) /= 16#80# then return 0; end if;
         C := C * 16#40# or (B and 16#3F#);
      end loop;
      Cp := Natural (C); return N;
   end Decode_Utf8;

   function Scan_Bnf_value (S : String; Pos, Len : Natural) return Natural is
      type Table is array (Natural range <>) of Natural;
      Lo    : constant Table := (33, 1, 11, 14, 1, 11, 14, 1, 11, 14, 1, 11, 14, 1, 1);
      Hi    : constant Table := (1114111, 9, 12, 1114111, 9, 12, 1114111, 9, 12, 1114111, 9, 12, 1114111, 0, 0);
      To    : constant Table := (1, 2, 3, 4, 2, 3, 4, 2, 3, 4, 2, 3, 4, 0, 0);
      First : constant Table := (0, 1, 4, 7, 10, 13);
      Acc   : constant Table := (1, 1, 1, 1, 1, 0);
      I     : Natural := Pos;
      Best  : Natural := 0;
      St    : Natural := 0;
      Cp, N, K : Natural;
   begin
      loop
         if Acc (St) /= 0 then Best := I - Pos; end if;
         exit when I > Len;
         N := Decode_Utf8 (S, I, Len, Cp);
         exit when N = 0;
         K := First (St);
         while K < First (St + 1)
           and then not (Cp >= Lo (K) and then Cp <= Hi (K))
         loop
            K := K + 1;
         end loop;
         exit when K = First (St + 1);
         St := To (K);
         I := I + N;
      end loop;
      return Best;
   end Scan_Bnf_value;

   function Scan_Bnf_eol (S : String; Pos, Len : Natural) return Natural is
      Cp  : Natural;
      N   : Natural;
      Off : Natural := 0;
   begin
      N := Decode_Utf8 (S, Pos + Off, Len, Cp);
      if N = 0 or else not (Cp >= 10 and then Cp <= 10) then return 0; end if;
      Off := Off + N;
      return Off;
   end Scan_Bnf_eol;

   function Scan_Bnf_prefix (S : String; Pos, Len : Natural) return Natural is
      Cp   : Natural;
      N    : Natural;
      Best : Natural := 0;
      Off  : Natural;
      Ok   : Boolean;
   begin
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 99 and then Cp <= 99);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 112 and then Cp <= 112);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 97 and then Cp <= 97);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 100 and then Cp <= 100);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 110 and then Cp <= 110);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 117 and then Cp <= 117);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 115 and then Cp <= 115);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 107 and then Cp <= 107);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      return Best;
   end Scan_Bnf_prefix;

   function Scan_Bnf_uuid (S : String; Pos, Len : Natural) return Natural is
      Cp   : Natural;
      N    : Natural;
      Best : Natural := 0;
      Off  : Natural;
      Ok   : Boolean;
   begin
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 105 and then Cp <= 105);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 100 and then Cp <= 100);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok then
         declare
            Cnt : Natural := 0;
         begin
            loop
               declare
                  Br    : Natural := 0;
                  O     : Natural;
                  Match : Boolean;
               begin
                  O := 0;
                  Match := True;
                  if Match then
                     N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                     Match := N > 0 and then (Cp >= 48 and then Cp <= 57);
                     if Match then O := O + N; end if;
                  end if;
                  if Match and then O > Br then Br := O; end if;
                  exit when Br = 0;
                  Off := Off + Br;
                  Cnt := Cnt + 1;
               end;
            end loop;
            if Cnt < 1 then Ok := False; end if;
         end;
      end if;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 46 and then Cp <= 46);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok then
         declare
            Cnt : Natural := 0;
         begin
            loop
               declare
                  Br    : Natural := 0;
                  O     : Natural;
                  Match : Boolean;
               begin
                  O := 0;
                  Match := True;
                  if Match then
                     N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                     Match := N > 0 and then (Cp >= 48 and then Cp <= 57);
                     if Match then O := O + N; end if;
                  end if;
                  if Match and then O > Br then Br := O; end if;
                  exit when Br = 0;
                  Off := Off + Br;
                  Cnt := Cnt + 1;
               end;
            end loop;
            if Cnt < 1 then Ok := False; end if;
         end;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 105 and then Cp <= 105);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 100 and then Cp <= 100);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok then
         declare
            Cnt : Natural := 0;
         begin
            loop
               declare
                  Br    : Natural := 0;
                  O     : Natural;
                  Match : Boolean;
               begin
                  O := 0;
                  Match := True;
                  if Match then
                     N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                     Match := N > 0 and then (Cp >= 48 and then Cp <= 57);
                     if Match then O := O + N; end if;
                  end if;
                  if Match and then O > Br then Br := O; end if;
                  exit when Br = 0;
                  Off := Off + Br;
                  Cnt := Cnt + 1;
               end;
            end loop;
            if Cnt < 1 then Ok := False; end if;
         end;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      return Best;
   end Scan_Bnf_uuid;

   function Scan_Ws (S : String; Pos, Len : Natural) return Natural is
      Cp   : Natural;
      N    : Natural;
      Best : Natural := 0;
      Off  : Natural;
      Ok   : Boolean;
   begin
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 32 and then Cp <= 32);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 9 and then Cp <= 9);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 13 and then Cp <= 13);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 35 and then Cp <= 35);
         if Ok then Off := Off + N; end if;
      end if;
      if Ok then
         declare
            Cnt : Natural := 0;
         begin
            loop
               declare
                  Br    : Natural := 0;
                  O     : Natural;
                  Match : Boolean;
               begin
                  O := 0;
                  Match := True;
                  if Match then
                     N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                     Match := N > 0 and then (Cp >= 1 and then Cp <= 9);
                     if Match then O := O + N; end if;
                  end if;
                  if Match and then O > Br then Br := O; end if;
                  O := 0;
                  Match := True;
                  if Match then
                     N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                     Match := N > 0 and then (Cp >= 11 and then Cp <= 12);
                     if Match then O := O + N; end if;
                  end if;
                  if Match and then O > Br then Br := O; end if;
                  O := 0;
                  Match := True;
                  if Match then
                     N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                     Match := N > 0 and then (Cp >= 14 and then Cp <= 1114111);
                     if Match then O := O + N; end if;
                  end if;
                  if Match and then O > Br then Br := O; end if;
                  exit when Br = 0;
                  Off := Off + Br;
                  Cnt := Cnt + 1;
               end;
            end loop;
         end;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      return Best;
   end Scan_Ws;

   function Scan_Bnf_COLON (S : String; Pos, Len : Natural) return Natural is
      Cp  : Natural;
      N   : Natural;
      Off : Natural := 0;
   begin
      N := Decode_Utf8 (S, Pos + Off, Len, Cp);
      if N = 0 or else not (Cp >= 58 and then Cp <= 58) then return 0; end if;
      Off := Off + N;
      return Off;
   end Scan_Bnf_COLON;

   function Scan_Bnf_content_1 (S : String; Pos, Len : Natural) return Natural is
      type Table is array (Natural range <>) of Natural;
      Lo    : constant Table := (33, 1, 11, 14, 1, 11, 14, 1, 11, 14, 1, 11, 14, 1, 1);
      Hi    : constant Table := (1114111, 9, 12, 1114111, 9, 12, 1114111, 9, 12, 1114111, 9, 12, 1114111, 0, 0);
      To    : constant Table := (1, 2, 3, 4, 2, 3, 4, 2, 3, 4, 2, 3, 4, 0, 0);
      First : constant Table := (0, 1, 4, 7, 10, 13);
      Acc   : constant Table := (1, 1, 1, 1, 1, 0);
      I     : Natural := Pos;
      Best  : Natural := 0;
      St    : Natural := 0;
      Cp, N, K : Natural;
   begin
      loop
         if Acc (St) /= 0 then Best := I - Pos; end if;
         exit when I > Len;
         N := Decode_Utf8 (S, I, Len, Cp);
         exit when N = 0;
         K := First (St);
         while K < First (St + 1)
           and then not (Cp >= Lo (K) and then Cp <= Hi (K))
         loop
            K := K + 1;
         end loop;
         exit when K = First (St + 1);
         St := To (K);
         I := I + N;
      end loop;
      return Best;
   end Scan_Bnf_content_1;

   type Text_Access is access constant String;

   type Alt_List is array (1 .. 16) of Unbounded_String;
   type Rule_Stack is array (1 .. 24) of Natural;

   --  The parser reads the text itself: a position in it, no token array.
   type Parser is record
      Text : Text_Access;
      Pos  : Natural := 1;
      Last : Natural := Natural'Last;   --  the input is cut here for a trial parse (`a - b`)
      --  The farthest failure (Err_Pos, 0 while there is none): what could have stood
      --  there, each told once, and the rules being read then and where each began.
      Err_Pos    : Natural := 0;
      Alt_N      : Natural := 0;
      Alts       : Alt_List;
      More       : Boolean := False;
      Depth      : Natural := 0;
      Stk        : Rule_Stack := (others => 0);
      Stkpos     : Rule_Stack := (others => 0);
      Err_Depth  : Natural := 0;
      Err_Stk    : Rule_Stack := (others => 0);
      Err_Stkpos : Rule_Stack := (others => 0);
   end record;

   --  A rule is being read from here (and not any more, when it returns).
   procedure Enter (P : in out Parser; Rule : Positive) is
   begin
      if P.Depth < 24 then
         P.Stk (P.Depth + 1) := Rule;
         P.Stkpos (P.Depth + 1) := P.Pos;
      end if;
      P.Depth := P.Depth + 1;
   end Enter;

   function Limit (P : Parser) return Natural is
     (Natural'Min (P.Last, P.Text'Last));

   Spaces : constant String :=
     "                                                                ";

   --  What stands at the position, for an error message: the bareword that
   --  starts there, else the one character, else the end of the text.
   function Found (P : Parser; At_Pos : Natural) return String is
      Last : constant Natural := P.Text'Last;
      I    : Natural := At_Pos;

      function Word_Char (C : Character) return Boolean is
        (C in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '-' | '.');
   begin
      if At_Pos > Last then
         return "end of input";
      end if;
      if Word_Char (P.Text (I)) then
         while I <= Last and then Word_Char (P.Text (I)) loop
            I := I + 1;
         end loop;
         return P.Text (At_Pos .. I - 1);
      end if;
      return P.Text (At_Pos .. At_Pos);
   end Found;

   --  Keep the farthest failure, and at the same place what else could have stood
   --  there; the message is made of them when the whole parse has failed (Render).
   procedure Fail (P : in out Parser; Expected : String) is
   begin
      if P.Err_Pos = 0 or else P.Pos > P.Err_Pos then
         P.Err_Pos := P.Pos;
         P.Alt_N := 1;
         P.Alts (1) := To_Unbounded_String (Expected);
         P.More := False;
         P.Err_Depth := Natural'Min (P.Depth, 24);
         P.Err_Stk := P.Stk;
         P.Err_Stkpos := P.Stkpos;
      elsif P.Pos = P.Err_Pos then
         declare
            Seen : Boolean := False;
         begin
            for I in 1 .. P.Alt_N loop
               if To_String (P.Alts (I)) = Expected then
                  Seen := True;
               end if;
            end loop;
            if not Seen then
               if P.Alt_N < 16 then
                  P.Alt_N := P.Alt_N + 1;
                  P.Alts (P.Alt_N) := To_Unbounded_String (Expected);
               else
                  P.More := True;
               end if;
            end if;
         end;
      end if;
      raise Parse_Error with "expected " & Expected;
   end Fail;

   --  A punctuation- or digit-led literal: compare bytes at the position (a
   --  prefix is correct there, e.g. "-" in "-5", "0x" in "0x1F").
   procedure Expect_Lit (P : in out Parser; Lit : String) is
   begin
      if P.Pos + Lit'Length - 1 <= Limit (P)
        and then P.Text (P.Pos .. P.Pos + Lit'Length - 1) = Lit
      then
         P.Pos := P.Pos + Lit'Length;
      else
         Fail (P, "`" & Lit & "`");
      end if;
   end Expect_Lit;

   --  A keyword: the whole bareword at the position must be the literal, so
   --  `in` does not match the front of `input`.
   procedure Expect_Word (P : in out Parser; Lit : String) is
      N : constant Natural := Scan_Word (P.Text.all, P.Pos, Limit (P));
   begin
      if N = Lit'Length and then P.Text (P.Pos .. P.Pos + N - 1) = Lit then
         P.Pos := P.Pos + N;
      else
         Fail (P, "`" & Lit & "`");
      end if;
   end Expect_Word;

   --  Skip what the grammar calls whitespace, one match at a time.
   procedure Skip_Ws (P : in out Parser) is
      N : Natural;
   begin
      loop
         N := Scan_Ws (P.Text.all, P.Pos, Limit (P));
         exit when N = 0;
         P.Pos := P.Pos + N;
      end loop;
   end Skip_Ws;

   --  The content of a quoted string: strip the quotes, and drop a backslash
   --  (keeping the character after it) or a backslash-newline.
   function Str_Value (S : String) return Unbounded_String is
      R : Unbounded_String;
      I : Natural := S'First + 1;
   begin
      while I < S'Last loop
         if S (I) = '\' and then I + 1 < S'Last then
            I := I + 1;
            if S (I) /= ASCII.LF then
               Append (R, S (I));
            end if;
         else
            Append (R, S (I));
         end if;
         I := I + 1;
      end loop;
      return R;
   end Str_Value;

   function Is_Keyword (S : String) return Boolean is
   begin
      pragma Unreferenced (S);
      return False;
   end Is_Keyword;

   procedure Dealloc_Bnf_line is new Ada.Unchecked_Deallocation (Bnf_line_Type, Bnf_line_Access);
   procedure Dealloc_Bnf_entry is new Ada.Unchecked_Deallocation (Bnf_entry_Type, Bnf_entry_Access);
   procedure Dealloc_Bnf_content is new Ada.Unchecked_Deallocation (Bnf_content_Type, Bnf_content_Access);
   procedure Dealloc_Bnf_directive is new Ada.Unchecked_Deallocation (Bnf_directive_Type, Bnf_directive_Access);
   procedure Dealloc_Bnf_tail is new Ada.Unchecked_Deallocation (Bnf_tail_Type, Bnf_tail_Access);

   procedure Free_Bnf_outline (V : in out Bnf_outline_Type) is
   begin
   for K in V.First_Index .. V.Last_Index loop
      declare
         E : Bnf_line_Access := V (K);
      begin
         if E /= null then
            Free_Bnf_line (E.all);
            V.Replace_Element (K, null);
            Dealloc_Bnf_line (E);
         end if;
      end;
   end loop;
   end Free_Bnf_outline;

   procedure Free_Bnf_line (V : in out Bnf_line_Type) is
   begin
   Free_Bnf_line_1 (V.Bnf_line_1);
   end Free_Bnf_line;

   procedure Free_Bnf_entry (V : in out Bnf_entry_Type) is
   begin
   if V.Bnf_content /= null then
      Free_Bnf_content (V.Bnf_content.all);
      Dealloc_Bnf_content (V.Bnf_content);
   end if;
   if V.Bnf_directive /= null then
      Free_Bnf_directive (V.Bnf_directive.all);
      Dealloc_Bnf_directive (V.Bnf_directive);
   end if;
   end Free_Bnf_entry;

   procedure Free_Bnf_content (V : in out Bnf_content_Type) is
      pragma Unreferenced (V);
   begin
      null;
   end Free_Bnf_content;

   procedure Free_Bnf_directive (V : in out Bnf_directive_Type) is
   begin
   if V.Bnf_tail /= null then
      Free_Bnf_tail (V.Bnf_tail.all);
      Dealloc_Bnf_tail (V.Bnf_tail);
   end if;
   end Free_Bnf_directive;

   procedure Free_Bnf_tail (V : in out Bnf_tail_Type) is
      pragma Unreferenced (V);
   begin
      null;
   end Free_Bnf_tail;

   procedure Free_Bnf_line_1 (V : in out Bnf_line_1_Type) is
   begin
   for K in V.First_Index .. V.Last_Index loop
      declare
         E : Bnf_entry_Access := V (K);
      begin
         if E /= null then
            Free_Bnf_entry (E.all);
            V.Replace_Element (K, null);
            Dealloc_Bnf_entry (E);
         end if;
      end;
   end loop;
   end Free_Bnf_line_1;

   function Parse_Bnf_outline (P : in out Parser) return Bnf_outline_Type;
   function Parse_Bnf_line (P : in out Parser) return Bnf_line_Type;
   function Parse_Bnf_entry (P : in out Parser) return Bnf_entry_Type;
   function Parse_Bnf_content (P : in out Parser) return Bnf_content_Type;
   function Parse_Bnf_directive (P : in out Parser) return Bnf_directive_Type;
   function Parse_Bnf_tail (P : in out Parser) return Bnf_tail_Type;
   function Parse_Bnf_value (P : in out Parser) return Bnf_value_Type;
   function Parse_Bnf_eol (P : in out Parser) return Bnf_eol_Type;
   function Parse_Bnf_name (P : in out Parser) return Bnf_name_Type;
   function Parse_Bnf_prefix (P : in out Parser) return Bnf_prefix_Type;
   function Parse_Bnf_uuid (P : in out Parser) return Bnf_uuid_Type;
   function Parse_Bnf_COLON (P : in out Parser) return Bnf_COLON_Type;
   function Parse_Word (P : in out Parser) return Word_Type;
   function Parse_Int (P : in out Parser) return Int_Type;
   function Parse_Str (P : in out Parser) return Str_Type;
   function Parse_Bnf_line_1 (P : in out Parser) return Bnf_line_1_Type;
   function Parse_Bnf_content_1 (P : in out Parser) return Bnf_content_1_Type;

   function Body_Of_Bnf_outline (P : in out Parser) return Bnf_outline_Type is
   R : Bnf_outline_Type;
   Save : Natural;
   begin
      loop
         declare
            Start : constant Natural := P.Pos;
         begin
            Skip_Ws (P);
            if P.Pos > Limit (P) then P.Pos := Start; exit; end if;
            R.Append (new Bnf_line_Type'(Parse_Bnf_line (P)));
         exception
            when Parse_Error => P.Pos := Start; exit;
         end;
      end loop;
      return R;
   end Body_Of_Bnf_outline;

   function Parse_Bnf_outline (P : in out Parser) return Bnf_outline_Type is
   begin
      Enter (P, 1);
      declare
         R : constant Bnf_outline_Type := Body_Of_Bnf_outline (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_outline;

   function Body_Of_Bnf_line (P : in out Parser) return Bnf_line_Type is
   R : Bnf_line_Type;
   begin
      Skip_Ws (P);
      R.Bnf_line_1 := Parse_Bnf_line_1 (P);
      Skip_Ws (P);
      declare
         N : constant Natural := Scan_Bnf_eol (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "eol"); end if;
         R.Bnf_eol := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N;
      end;
      return R;
   end Body_Of_Bnf_line;

   function Parse_Bnf_line (P : in out Parser) return Bnf_line_Type is
   begin
      Enter (P, 2);
      declare
         R : constant Bnf_line_Type := Body_Of_Bnf_line (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_line;

   function Body_Of_Bnf_entry (P : in out Parser) return Bnf_entry_Type is
   R : Bnf_entry_Type;
   begin
      declare
         Save : constant Natural := P.Pos;
      begin
         declare
            R : Bnf_entry_Type;
         begin
            Skip_Ws (P);
            R.Bnf_content := new Bnf_content_Type'(Parse_Bnf_content (P));
            return R;
         exception
            when Parse_Error => null;
         end;
         P.Pos := Save;
         declare
            R : Bnf_entry_Type;
         begin
            Skip_Ws (P);
            R.Bnf_directive := new Bnf_directive_Type'(Parse_Bnf_directive (P));
            return R;
         exception
            when Parse_Error => null;
         end;
         P.Pos := Save;
         Fail (P, "a entry");
         return R;
      end;
   end Body_Of_Bnf_entry;

   function Parse_Bnf_entry (P : in out Parser) return Bnf_entry_Type is
   begin
      Enter (P, 3);
      declare
         R : constant Bnf_entry_Type := Body_Of_Bnf_entry (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_entry;

   function Body_Of_Bnf_content (P : in out Parser) return Bnf_content_Type is
   R : Bnf_content_Type;
   begin
      Skip_Ws (P);
      declare
         N : constant Natural := Scan_Bnf_prefix (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "prefix"); end if;
         R.Bnf_prefix := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N;
      end;
      Skip_Ws (P);
      declare
         N : constant Natural := Scan_Bnf_COLON (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "COLON"); end if;
         R.Bnf_COLON := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N;
      end;
      Skip_Ws (P);
      declare
         N : constant Natural := Scan_Bnf_uuid (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "uuid"); end if;
         R.Bnf_uuid := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N;
      end;
      Skip_Ws (P);
      declare
         N : constant Natural := Scan_Bnf_content_1 (P.Text.all, P.Pos, Limit (P));
      begin
         R.Bnf_content_1 := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N;
      end;
      return R;
   end Body_Of_Bnf_content;

   function Parse_Bnf_content (P : in out Parser) return Bnf_content_Type is
   begin
      Enter (P, 4);
      declare
         R : constant Bnf_content_Type := Body_Of_Bnf_content (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_content;

   function Body_Of_Bnf_directive (P : in out Parser) return Bnf_directive_Type is
   R : Bnf_directive_Type;
   begin
      Skip_Ws (P);
      declare
         N : constant Natural := Scan_Bnf_prefix (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "prefix"); end if;
         R.Bnf_prefix := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N;
      end;
      Skip_Ws (P);
      declare
         N : constant Natural := Scan_Bnf_COLON (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "COLON"); end if;
         R.Bnf_COLON := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N;
      end;
      Skip_Ws (P);
      R.Bnf_tail := new Bnf_tail_Type'(Parse_Bnf_tail (P));
      return R;
   end Body_Of_Bnf_directive;

   function Parse_Bnf_directive (P : in out Parser) return Bnf_directive_Type is
   begin
      Enter (P, 5);
      declare
         R : constant Bnf_directive_Type := Body_Of_Bnf_directive (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_directive;

   function Body_Of_Bnf_tail (P : in out Parser) return Bnf_tail_Type is
   R : Bnf_tail_Type;
   begin
      Skip_Ws (P);
      R.Bnf_name := Parse_Bnf_name (P);
      Skip_Ws (P);
      declare
         N : constant Natural := Scan_Bnf_COLON (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "COLON"); end if;
         R.Bnf_COLON := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N;
      end;
      Skip_Ws (P);
      declare
         N : constant Natural := Scan_Bnf_value (P.Text.all, P.Pos, Limit (P));
      begin
         R.Bnf_value := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N;
      end;
      return R;
   end Body_Of_Bnf_tail;

   function Parse_Bnf_tail (P : in out Parser) return Bnf_tail_Type is
   begin
      Enter (P, 6);
      declare
         R : constant Bnf_tail_Type := Body_Of_Bnf_tail (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_tail;

   function Body_Of_Bnf_value (P : in out Parser) return Bnf_value_Type is
   R : Bnf_value_Type;
   Save : Natural;
   begin
      declare
         N : constant Natural := Scan_Bnf_value (P.Text.all, P.Pos, Limit (P));
      begin
         R := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1));
         P.Pos := P.Pos + N;
         return R;
      end;
   end Body_Of_Bnf_value;

   function Parse_Bnf_value (P : in out Parser) return Bnf_value_Type is
   begin
      Enter (P, 7);
      declare
         R : constant Bnf_value_Type := Body_Of_Bnf_value (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_value;

   function Body_Of_Bnf_eol (P : in out Parser) return Bnf_eol_Type is
   R : Bnf_eol_Type;
   begin
      declare
         N : constant Natural := Scan_Bnf_eol (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "eol"); end if;
         R := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1));
         P.Pos := P.Pos + N;
         return R;
      end;
   end Body_Of_Bnf_eol;

   function Parse_Bnf_eol (P : in out Parser) return Bnf_eol_Type is
   begin
      Enter (P, 8);
      declare
         R : constant Bnf_eol_Type := Body_Of_Bnf_eol (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_eol;

   function Body_Of_Bnf_name (P : in out Parser) return Bnf_name_Type is
   R : Bnf_name_Type;
   begin
      if P.Pos > Limit (P) then Fail (P, "a Bnf_name_Type"); end if;
      if P.Pos + 5 - 1 <= Limit (P) and then P.Text (P.Pos .. P.Pos + 5 - 1) = "label" then
         R := Bnf_name_Label; P.Pos := P.Pos + 5;
      elsif P.Pos + 6 - 1 <= Limit (P) and then P.Text (P.Pos .. P.Pos + 6 - 1) = "number" then
         R := Bnf_name_Number; P.Pos := P.Pos + 6;
      elsif P.Pos + 5 - 1 <= Limit (P) and then P.Text (P.Pos .. P.Pos + 5 - 1) = "count" then
         R := Bnf_name_Count; P.Pos := P.Pos + 5;
      elsif P.Pos + 7 - 1 <= Limit (P) and then P.Text (P.Pos .. P.Pos + 7 - 1) = "default" then
         R := Bnf_name_Default; P.Pos := P.Pos + 7;
      elsif P.Pos + 4 - 1 <= Limit (P) and then P.Text (P.Pos .. P.Pos + 4 - 1) = "none" then
         R := Bnf_name_None; P.Pos := P.Pos + 4;
      else Fail (P, "`label` or `number` or `count` or `default` or `none`"); end if;
      return R;
   end Body_Of_Bnf_name;

   function Parse_Bnf_name (P : in out Parser) return Bnf_name_Type is
   begin
      Enter (P, 9);
      declare
         R : constant Bnf_name_Type := Body_Of_Bnf_name (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_name;

   function Body_Of_Bnf_prefix (P : in out Parser) return Bnf_prefix_Type is
   R : Bnf_prefix_Type;
   begin
      declare
         N : constant Natural := Scan_Bnf_prefix (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "prefix"); end if;
         R := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1));
         P.Pos := P.Pos + N;
         return R;
      end;
   end Body_Of_Bnf_prefix;

   function Parse_Bnf_prefix (P : in out Parser) return Bnf_prefix_Type is
   begin
      Enter (P, 10);
      declare
         R : constant Bnf_prefix_Type := Body_Of_Bnf_prefix (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_prefix;

   function Body_Of_Bnf_uuid (P : in out Parser) return Bnf_uuid_Type is
   R : Bnf_uuid_Type;
   begin
      declare
         N : constant Natural := Scan_Bnf_uuid (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "uuid"); end if;
         R := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1));
         P.Pos := P.Pos + N;
         return R;
      end;
   end Body_Of_Bnf_uuid;

   function Parse_Bnf_uuid (P : in out Parser) return Bnf_uuid_Type is
   begin
      Enter (P, 11);
      declare
         R : constant Bnf_uuid_Type := Body_Of_Bnf_uuid (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_uuid;

   function Body_Of_Bnf_COLON (P : in out Parser) return Bnf_COLON_Type is
   R : Bnf_COLON_Type;
   begin
      declare
         N : constant Natural := Scan_Bnf_COLON (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "COLON"); end if;
         R := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1));
         P.Pos := P.Pos + N;
         return R;
      end;
   end Body_Of_Bnf_COLON;

   function Parse_Bnf_COLON (P : in out Parser) return Bnf_COLON_Type is
   begin
      Enter (P, 24);
      declare
         R : constant Bnf_COLON_Type := Body_Of_Bnf_COLON (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_COLON;

   function Body_Of_Word (P : in out Parser) return Word_Type is
   R : Word_Type;
   begin
      declare
         N : constant Natural := Scan_Word (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "a word"); end if;
         R := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1));
         P.Pos := P.Pos + N;
         return R;
      end;
   end Body_Of_Word;

   function Parse_Word (P : in out Parser) return Word_Type is
   begin
      Enter (P, 25);
      declare
         R : constant Word_Type := Body_Of_Word (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Word;

   function Body_Of_Int (P : in out Parser) return Int_Type is
   R : Int_Type;
   begin
      declare
         N : constant Natural := Scan_Int (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "a int"); end if;
         R := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1));
         P.Pos := P.Pos + N;
         return R;
      end;
   end Body_Of_Int;

   function Parse_Int (P : in out Parser) return Int_Type is
   begin
      Enter (P, 26);
      declare
         R : constant Int_Type := Body_Of_Int (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Int;

   function Body_Of_Str (P : in out Parser) return Str_Type is
   R : Str_Type;
   begin
      declare
         N : constant Natural := Scan_Str (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 then Fail (P, "a str"); end if;
         R := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1));
         P.Pos := P.Pos + N;
         return R;
      end;
   end Body_Of_Str;

   function Parse_Str (P : in out Parser) return Str_Type is
   begin
      Enter (P, 27);
      declare
         R : constant Str_Type := Body_Of_Str (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Str;

   function Body_Of_Bnf_line_1 (P : in out Parser) return Bnf_line_1_Type is
   R : Bnf_line_1_Type;
   Save : Natural;
   begin
      loop
         exit when Natural (R.Length) >= 1;
         declare
            Start : constant Natural := P.Pos;
         begin
            Skip_Ws (P);
            if P.Pos > Limit (P) then P.Pos := Start; exit; end if;
            R.Append (new Bnf_entry_Type'(Parse_Bnf_entry (P)));
         exception
            when Parse_Error => P.Pos := Start; exit;
         end;
      end loop;
      return R;
   end Body_Of_Bnf_line_1;

   function Parse_Bnf_line_1 (P : in out Parser) return Bnf_line_1_Type is
   begin
      Enter (P, 28);
      declare
         R : constant Bnf_line_1_Type := Body_Of_Bnf_line_1 (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_line_1;

   function Body_Of_Bnf_content_1 (P : in out Parser) return Bnf_content_1_Type is
   R : Bnf_content_1_Type;
   Save : Natural;
   begin
      declare
         N : constant Natural := Scan_Bnf_content_1 (P.Text.all, P.Pos, Limit (P));
      begin
         R := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1));
         P.Pos := P.Pos + N;
         return R;
      end;
   end Body_Of_Bnf_content_1;

   function Parse_Bnf_content_1 (P : in out Parser) return Bnf_content_1_Type is
   begin
      Enter (P, 29);
      declare
         R : constant Bnf_content_1_Type := Body_Of_Bnf_content_1 (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_content_1;

   function Rule_Name (I : Natural) return String is
     (case I is
        when 1 => "outline",
        when 2 => "line",
        when 3 => "entry",
        when 4 => "content",
        when 5 => "directive",
        when 6 => "tail",
        when 7 => "value",
        when 8 => "eol",
        when 9 => "name",
        when 10 => "prefix",
        when 11 => "uuid",
        when 12 => "title",
        when 13 => "title_start",
        when 14 => "title_char",
        when 15 => "ws",
        when 16 => "comment",
        when 17 => "comment_char",
        when 18 => "DIGIT",
        when 19 => "LF",
        when 20 => "CR",
        when 21 => "SP",
        when 22 => "HTAB",
        when 23 => "PERIOD",
        when 24 => "COLON",
        when 25 => "word",
        when 26 => "int",
        when 27 => "str",
        when 28 => "",
        when 29 => "",
        when others => "");
   
   function Render (P : Parser) return String is
      At_Pos : constant Natural := P.Err_Pos;
      Last   : constant Natural := P.Text'Last;
      At_End : constant Boolean := At_Pos > Last;
      Line   : Natural := 1;
      Col    : Natural := 1;
      Start  : Natural := 1;
      Msg    : Unbounded_String;
   
      function Img (N : Natural) return String is
         S : constant String := Natural'Image (N);
      begin
         return S (S'First + 1 .. S'Last);
      end Img;
   begin
      for I in 1 .. Natural'Min (At_Pos, Last + 1) - 1 loop
         if P.Text (I) = ASCII.LF then
            Line := Line + 1;
            Col := 1;
            Start := I + 1;
         else
            Col := Col + 1;
         end if;
      end loop;
      Append (Msg, Img (Line) & ":" & Img (Col) & ":" & Img (At_Pos - 1) & ": expected ");
      if P.Alt_N > 1 then
         Append (Msg, "one of ");
      end if;
      for I in 1 .. P.Alt_N loop
         if I > 1 then
            Append (Msg, ", ");
         end if;
         Append (Msg, P.Alts (I));
      end loop;
      if P.More then
         Append (Msg, ", ...");
      end if;
      Append (Msg, ", found " & Found (P, At_Pos));
      declare
         Stop : Natural := Start;
      begin
         while Stop <= Last and then P.Text (Stop) /= ASCII.LF loop
            Stop := Stop + 1;
         end loop;
         declare
            W   : constant Natural := Col - 1;
            Pad : constant String :=
              (if W <= Spaces'Length then Spaces (1 .. W) else Spaces);
         begin
            Append (Msg, ASCII.LF & "  " & P.Text (Start .. Stop - 1)
              & ASCII.LF & "  " & Pad & "^");
         end;
      end;
      for K in reverse 1 .. P.Err_Depth loop
         declare
            Nm : constant String := Rule_Name (P.Err_Stk (K));
            Sp : Natural := P.Err_Stkpos (K);
            L  : Natural := 1;
            Ls : Natural := 1;
            Le : Natural;
         begin
            if Nm'Length > 0 then
               while Sp <= Last and then P.Text (Sp) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR loop
                  Sp := Sp + 1;
               end loop;
               for I in 1 .. Natural'Min (Sp, Last + 1) - 1 loop
                  if P.Text (I) = ASCII.LF then
                     L := L + 1;
                     Ls := I + 1;
                  end if;
               end loop;
               if L + (if At_End then 1 else 3) <= Line then
                  Le := Ls;
                  while Le <= Last and then P.Text (Le) /= ASCII.LF loop
                     Le := Le + 1;
                  end loop;
                  Append (Msg, ASCII.LF & "  " & Img (L) & ":" & Img (Sp - Ls + 1)
                    & ":" & Img (Sp - 1) & ": "
                    & (if At_End then "the " else "inside the ") & Nm
                    & " that begins here" & (if At_End then " is not finished:" else ":")
                    & ASCII.LF & "  " & P.Text (Ls .. Le - 1) & ASCII.LF & "  "
                    & (if Sp - Ls <= Spaces'Length then Spaces (1 .. Sp - Ls) else Spaces)
                    & "^");
                  exit;
               end if;
            end if;
         end;
      end loop;
      return To_String (Msg);
   end Render;
   
   function Parse_Text (Text : String) return Bnf_outline_Type is
      --  A 1-based copy: positions are indexes into it, wherever the
      --  caller's string starts.
      function Rebase (S : String) return String is
         R : String (1 .. S'Length);
      begin
         R := S;
         return R;
      end Rebase;

      T : aliased constant String := Rebase (Text);
      P : Parser := (Text => T'Unchecked_Access, Pos => 1, Last => Natural'Last, others => <>);
      R : Bnf_outline_Type;
   begin
      begin
      Skip_Ws (P);
         R := Parse_Bnf_outline (P);
      Skip_Ws (P);
         if P.Pos <= T'Last then
            Fail (P, "end of config");
         end if;
      exception
         when Parse_Error =>
            raise Parse_Error with Render (P);
      end;
      return R;
   end Parse_Text;

end Outline_Grammar.Parser;

