
with Interfaces;
with Ada.Unchecked_Deallocation;

package body Book_Conf_Grammar.Parser is

   use Ada.Strings.Unbounded;
   use Interfaces;   function Scan_Int (S : String; Pos, Len : Natural) return Natural is
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

   function Scan_Word (S : String; Pos, Len : Natural) return Natural is
      Cp  : Natural;
      N   : Natural;
      Off : Natural := 0;
   begin
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
                  Match := N > 0 and then (Cp >= 65 and then Cp <= 90);
                  if Match then O := O + N; end if;
               end if;
               if Match and then O > Br then Br := O; end if;
               O := 0;
               Match := True;
               if Match then
                  N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                  Match := N > 0 and then (Cp >= 97 and then Cp <= 122);
                  if Match then O := O + N; end if;
               end if;
               if Match and then O > Br then Br := O; end if;
               O := 0;
               Match := True;
               if Match then
                  N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                  Match := N > 0 and then (Cp >= 48 and then Cp <= 57);
                  if Match then O := O + N; end if;
               end if;
               if Match and then O > Br then Br := O; end if;
               O := 0;
               Match := True;
               if Match then
                  N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                  Match := N > 0 and then (Cp >= 95 and then Cp <= 95);
                  if Match then O := O + N; end if;
               end if;
               if Match and then O > Br then Br := O; end if;
               O := 0;
               Match := True;
               if Match then
                  N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                  Match := N > 0 and then (Cp >= 45 and then Cp <= 45);
                  if Match then O := O + N; end if;
               end if;
               if Match and then O > Br then Br := O; end if;
               O := 0;
               Match := True;
               if Match then
                  N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                  Match := N > 0 and then (Cp >= 46 and then Cp <= 46);
                  if Match then O := O + N; end if;
               end if;
               if Match and then O > Br then Br := O; end if;
               exit when Br = 0;
               Off := Off + Br;
               Cnt := Cnt + 1;
            end;
         end loop;
         if Cnt < 1 then return 0; end if;
      end;
      return Off;
   end Scan_Word;

   function Scan_Str (S : String; Pos, Len : Natural) return Natural is
      Cp  : Natural;
      N   : Natural;
      Off : Natural := 0;
   begin
      N := Decode_Utf8 (S, Pos + Off, Len, Cp);
      if N = 0 or else not (Cp >= 34 and then Cp <= 34) then return 0; end if;
      Off := Off + N;
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
                  Match := N > 0 and then (Cp >= 92 and then Cp <= 92);
                  if Match then O := O + N; end if;
               end if;
               if Match then
                  N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                  Match := N > 0 and then (Cp <= 1114111);
                  if Match then O := O + N; end if;
               end if;
               if Match and then O > Br then Br := O; end if;
               O := 0;
               Match := True;
               if Match then
                  N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                  Match := N > 0 and then (Cp <= 33);
                  if Match then O := O + N; end if;
               end if;
               if Match and then O > Br then Br := O; end if;
               O := 0;
               Match := True;
               if Match then
                  N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                  Match := N > 0 and then (Cp >= 35 and then Cp <= 91);
                  if Match then O := O + N; end if;
               end if;
               if Match and then O > Br then Br := O; end if;
               O := 0;
               Match := True;
               if Match then
                  N := Decode_Utf8 (S, Pos + Off + O, Len, Cp);
                  Match := N > 0 and then (Cp >= 93 and then Cp <= 1114111);
                  if Match then O := O + N; end if;
               end if;
               if Match and then O > Br then Br := O; end if;
               exit when Br = 0;
               Off := Off + Br;
               Cnt := Cnt + 1;
            end;
         end loop;
      end;
      N := Decode_Utf8 (S, Pos + Off, Len, Cp);
      if N = 0 or else not (Cp >= 34 and then Cp <= 34) then return 0; end if;
      Off := Off + N;
      return Off;
   end Scan_Str;

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
         Ok := N > 0 and then (Cp >= 10 and then Cp <= 10);
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
                     Match := N > 0 and then (Cp >= 11 and then Cp <= 1114111);
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

   function Scan_Bnf_item_1 (S : String; Pos, Len : Natural) return Natural is
      type Table is array (Natural range <>) of Natural;
      Lo    : constant Table := (59, 1, 1);
      Hi    : constant Table := (59, 0, 0);
      To    : constant Table := (1, 0, 0);
      First : constant Table := (0, 1, 1);
      Acc   : constant Table := (1, 1, 0);
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
   end Scan_Bnf_item_1;

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
      return S = "_";
   end Is_Keyword;

   procedure Dealloc_Bnf_item is new Ada.Unchecked_Deallocation (Bnf_item_Type, Bnf_item_Access);
   procedure Dealloc_Bnf_body is new Ada.Unchecked_Deallocation (Bnf_body_Type, Bnf_body_Access);
   procedure Dealloc_Bnf_block is new Ada.Unchecked_Deallocation (Bnf_block_Type, Bnf_block_Access);

   procedure Free_Bnf_book (V : in out Bnf_book_Type) is
   begin
   for K in V.First_Index .. V.Last_Index loop
      declare
         E : Bnf_item_Access := V (K);
      begin
         if E /= null then
            Free_Bnf_item (E.all);
            V.Replace_Element (K, null);
            Dealloc_Bnf_item (E);
         end if;
      end;
   end loop;
   end Free_Bnf_book;

   procedure Free_Bnf_item (V : in out Bnf_item_Type) is
   begin
   if V.Bnf_body /= null then
      Free_Bnf_body (V.Bnf_body.all);
      Dealloc_Bnf_body (V.Bnf_body);
   end if;
   end Free_Bnf_item;

   procedure Free_Bnf_body (V : in out Bnf_body_Type) is
   begin
   if V.Bnf_block /= null then
      Free_Bnf_block (V.Bnf_block.all);
      Dealloc_Bnf_block (V.Bnf_block);
   end if;
   end Free_Bnf_body;

   procedure Free_Bnf_block (V : in out Bnf_block_Type) is
   begin
   Free_Bnf_block_1 (V.Bnf_block_1);
   end Free_Bnf_block;

   procedure Free_Bnf_block_1 (V : in out Bnf_block_1_Type) is
   begin
   for K in V.First_Index .. V.Last_Index loop
      declare
         E : Bnf_item_Access := V (K);
      begin
         if E /= null then
            Free_Bnf_item (E.all);
            V.Replace_Element (K, null);
            Dealloc_Bnf_item (E);
         end if;
      end;
   end loop;
   end Free_Bnf_block_1;

   function Parse_Bnf_book (P : in out Parser) return Bnf_book_Type;
   function Parse_Bnf_item (P : in out Parser) return Bnf_item_Type;
   function Parse_Bnf_key (P : in out Parser) return Bnf_key_Type;
   function Parse_Bnf_body (P : in out Parser) return Bnf_body_Type;
   function Parse_Bnf_block (P : in out Parser) return Bnf_block_Type;
   function Parse_Bnf_value (P : in out Parser) return Bnf_value_Type;
   function Parse_Int (P : in out Parser) return Int_Type;
   function Parse_Bnf_item_1 (P : in out Parser) return Bnf_item_1_Type;
   function Parse_Bnf_block_1 (P : in out Parser) return Bnf_block_1_Type;

   function Body_Of_Bnf_book (P : in out Parser) return Bnf_book_Type is
   R : Bnf_book_Type;
   Save : Natural;
   begin
      loop
         declare
            Start : constant Natural := P.Pos;
         begin
            Skip_Ws (P);
            if P.Pos > Limit (P) then P.Pos := Start; exit; end if;
            R.Append (new Bnf_item_Type'(Parse_Bnf_item (P)));
         exception
            when Parse_Error => P.Pos := Start; exit;
         end;
      end loop;
      return R;
   end Body_Of_Bnf_book;

   function Parse_Bnf_book (P : in out Parser) return Bnf_book_Type is
   begin
      Enter (P, 1);
      declare
         R : constant Bnf_book_Type := Body_Of_Bnf_book (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_book;

   function Body_Of_Bnf_item (P : in out Parser) return Bnf_item_Type is
   R : Bnf_item_Type;
   begin
      Skip_Ws (P);
      R.Bnf_key := Parse_Bnf_key (P);
      Skip_Ws (P);
      R.Bnf_body := new Bnf_body_Type'(Parse_Bnf_body (P));
      Skip_Ws (P);
      declare
         N : constant Natural := Scan_Bnf_item_1 (P.Text.all, P.Pos, Limit (P));
      begin
         R.Bnf_item_1 := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N;
      end;
      return R;
   end Body_Of_Bnf_item;

   function Parse_Bnf_item (P : in out Parser) return Bnf_item_Type is
   begin
      Enter (P, 2);
      declare
         R : constant Bnf_item_Type := Body_Of_Bnf_item (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_item;

   function Body_Of_Bnf_key (P : in out Parser) return Bnf_key_Type is
   R : Bnf_key_Type;
   begin
      declare
         N : constant Natural := Scan_Word (P.Text.all, P.Pos, Limit (P));
      begin
         if N = 0 or else Is_Keyword (P.Text (P.Pos .. P.Pos + N - 1)) then Fail (P, "a string"); end if;
         R := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N;
         return R;
      end;
   end Body_Of_Bnf_key;

   function Parse_Bnf_key (P : in out Parser) return Bnf_key_Type is
   begin
      Enter (P, 3);
      declare
         R : constant Bnf_key_Type := Body_Of_Bnf_key (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_key;

   function Body_Of_Bnf_body (P : in out Parser) return Bnf_body_Type is
   R : Bnf_body_Type;
   begin
      declare
         Save : constant Natural := P.Pos;
      begin
         declare
            R : Bnf_body_Type;
         begin
            Skip_Ws (P);
            R.Bnf_block := new Bnf_block_Type'(Parse_Bnf_block (P));
            return R;
         exception
            when Parse_Error => null;
         end;
         P.Pos := Save;
         declare
            R : Bnf_body_Type;
         begin
            Skip_Ws (P);
            R.Bnf_value := Parse_Bnf_value (P);
            return R;
         exception
            when Parse_Error => null;
         end;
         P.Pos := Save;
         Fail (P, "a body");
         return R;
      end;
   end Body_Of_Bnf_body;

   function Parse_Bnf_body (P : in out Parser) return Bnf_body_Type is
   begin
      Enter (P, 4);
      declare
         R : constant Bnf_body_Type := Body_Of_Bnf_body (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_body;

   function Body_Of_Bnf_block (P : in out Parser) return Bnf_block_Type is
   R : Bnf_block_Type;
   begin
      Skip_Ws (P);
      Expect_Lit (P, "{");
      Skip_Ws (P);
      R.Bnf_block_1 := Parse_Bnf_block_1 (P);
      Skip_Ws (P);
      Expect_Lit (P, "}");
      return R;
   end Body_Of_Bnf_block;

   function Parse_Bnf_block (P : in out Parser) return Bnf_block_Type is
   begin
      Enter (P, 5);
      declare
         R : constant Bnf_block_Type := Body_Of_Bnf_block (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_block;

   function Body_Of_Bnf_value (P : in out Parser) return Bnf_value_Type is
   R : Bnf_value_Type;
   begin
      declare
         N : constant Natural := Scan_Word (P.Text.all, P.Pos, Limit (P));
      begin
         if N > 0 and then not Is_Keyword (P.Text (P.Pos .. P.Pos + N - 1)) then
            R := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N; return R;
         end if;
      end;
      declare
         N : constant Natural := Scan_Str (P.Text.all, P.Pos, Limit (P));
      begin
         if N > 0 then
            R := Str_Value (P.Text (P.Pos .. P.Pos + N - 1)); P.Pos := P.Pos + N; return R;
         end if;
      end;
      Fail (P, "a value");
      return R;
   end Body_Of_Bnf_value;

   function Parse_Bnf_value (P : in out Parser) return Bnf_value_Type is
   begin
      Enter (P, 6);
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
      Enter (P, 21);
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

   function Body_Of_Bnf_item_1 (P : in out Parser) return Bnf_item_1_Type is
   R : Bnf_item_1_Type;
   Save : Natural;
   begin
      declare
         N : constant Natural := Scan_Bnf_item_1 (P.Text.all, P.Pos, Limit (P));
      begin
         R := To_Unbounded_String (P.Text (P.Pos .. P.Pos + N - 1));
         P.Pos := P.Pos + N;
         return R;
      end;
   end Body_Of_Bnf_item_1;

   function Parse_Bnf_item_1 (P : in out Parser) return Bnf_item_1_Type is
   begin
      Enter (P, 22);
      declare
         R : constant Bnf_item_1_Type := Body_Of_Bnf_item_1 (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_item_1;

   function Body_Of_Bnf_block_1 (P : in out Parser) return Bnf_block_1_Type is
   R : Bnf_block_1_Type;
   Save : Natural;
   begin
      loop
         declare
            Start : constant Natural := P.Pos;
         begin
            Skip_Ws (P);
            if P.Pos > Limit (P) then P.Pos := Start; exit; end if;
            R.Append (new Bnf_item_Type'(Parse_Bnf_item (P)));
         exception
            when Parse_Error => P.Pos := Start; exit;
         end;
      end loop;
      return R;
   end Body_Of_Bnf_block_1;

   function Parse_Bnf_block_1 (P : in out Parser) return Bnf_block_1_Type is
   begin
      Enter (P, 23);
      declare
         R : constant Bnf_block_1_Type := Body_Of_Bnf_block_1 (P);
      begin
         P.Depth := P.Depth - 1;
         return R;
      end;
   exception
      when Parse_Error =>
         P.Depth := P.Depth - 1;
         raise;
   end Parse_Bnf_block_1;

   function Rule_Name (I : Natural) return String is
     (case I is
        when 1 => "book",
        when 2 => "item",
        when 3 => "key",
        when 4 => "body",
        when 5 => "block",
        when 6 => "value",
        when 7 => "word",
        when 8 => "wordchars",
        when 9 => "str",
        when 10 => "str_char",
        when 11 => "comment",
        when 12 => "comment_char",
        when 13 => "ws",
        when 14 => "DIGIT",
        when 15 => "ALPHA",
        when 16 => "LF",
        when 17 => "CR",
        when 18 => "SP",
        when 19 => "HTAB",
        when 20 => "DQUOTE",
        when 21 => "int",
        when 22 => "",
        when 23 => "",
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
   
   function Parse_Text (Text : String) return Bnf_book_Type is
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
      R : Bnf_book_Type;
   begin
      begin
      Skip_Ws (P);
         R := Parse_Bnf_book (P);
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

end Book_Conf_Grammar.Parser;

