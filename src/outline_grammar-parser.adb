
with Interfaces;

package body Outline_Grammar.Parser is

   use Ada.Strings.Unbounded;
   use Interfaces;

   type Parser is record
      Toks  : Token_Vectors.Vector;
      Lines : Line_Vectors.Vector;
      Pos   : Natural := 1;
   end record;

   Spaces : constant String :=
     "                                                                ";

   function Found (P : Parser) return String is
   begin
      if P.Pos <= Natural (P.Toks.Length) then
         return To_String (P.Toks (P.Pos).Text);
      end if;
      return "end of input";
   end Found;

   procedure Fail (P : Parser; Expected : String) is
      L : Natural := 0;
      C : Natural := 0;
      Msg : Unbounded_String;
   begin
      if P.Pos <= Natural (P.Toks.Length) then
         L := P.Toks (P.Pos).Line;
         C := P.Toks (P.Pos).Col;
      end if;
      if L >= 1 then
         Append (Msg, "line" & Natural'Image (L) & ": ");
      end if;
      Append (Msg, "expected " & Expected & ", found " & Found (P));
      if L >= 1 and then L <= Natural (P.Lines.Length) then
         declare
            W   : constant Natural := (if C > 1 then C - 1 else 0);
            Pad : constant String :=
              (if W <= Spaces'Length then Spaces (1 .. W) else Spaces);
         begin
            Append (Msg, ASCII.LF & "  " & To_String (P.Lines (L))
              & ASCII.LF & "  " & Pad & "^");
         end;
      end if;
      raise Parse_Error with To_String (Msg);
   end Fail;

   procedure Expect_Lit (P : in out Parser; Lit : String) is
   begin
      if P.Pos <= Natural (P.Toks.Length)
        and then (P.Toks (P.Pos).Kind = Atom or else P.Toks (P.Pos).Kind = Punct)
        and then To_String (P.Toks (P.Pos).Text) = Lit
      then
         P.Pos := P.Pos + 1;
      else
         Fail (P, "`" & Lit & "`");
      end if;
   end Expect_Lit;

   procedure Expect_Kind (P : in out Parser; K : Token_Kind; Desc : String) is
   begin
      if P.Pos <= Natural (P.Toks.Length) and then P.Toks (P.Pos).Kind = K then
         null;
      else
         Fail (P, Desc);
      end if;
   end Expect_Kind;

   function Parse_Outline (P : in out Parser) return Outline_Type;
   function Parse_Entry (P : in out Parser) return Entry_Type;
   function Parse_Content (P : in out Parser) return Content_Type;
   function Parse_Directive (P : in out Parser) return Directive_Type;
   function Parse_Tail (P : in out Parser) return Tail_Type;
   function Parse_Name (P : in out Parser) return Name_Type;
   function Parse_Prefix (P : in out Parser) return Prefix_Type;
   function Parse_Uuid (P : in out Parser) return Uuid_Type;
   function Parse_Title (P : in out Parser) return Title_Type;
   function Parse_Value (P : in out Parser) return Value_Type;
   function Parse_COLON (P : in out Parser) return COLON_Type;
   function Parse_PIPE (P : in out Parser) return PIPE_Type;
   function Parse_Content_1 (P : in out Parser) return Content_1_Type;

   function Parse_Outline (P : in out Parser) return Outline_Type is
   R : Outline_Type;
   Save : Natural;
   begin
      loop
         exit when P.Pos > Natural (P.Toks.Length) or else P.Toks (P.Pos).Kind = Eof;
         declare
            Start : constant Natural := P.Pos;
         begin
            R.Append (new Entry_Type'(Parse_Entry (P)));
         exception
            when Parse_Error => P.Pos := Start; exit;
         end;
      end loop;
      return R;
   end Parse_Outline;

   function Parse_Entry (P : in out Parser) return Entry_Type is
   R : Entry_Type;
   begin
      declare
         Save : constant Natural := P.Pos;
      begin
         declare
            R : Entry_Type;
         begin
            R.Content := new Content_Type'(Parse_Content (P));
            return R;
         exception
            when Parse_Error => null;
         end;
         P.Pos := Save;
         declare
            R : Entry_Type;
         begin
            R.Directive := new Directive_Type'(Parse_Directive (P));
            return R;
         exception
            when Parse_Error => null;
         end;
         P.Pos := Save;
         Fail (P, "a entry");
         return R;
      end;
   end Parse_Entry;

   function Parse_Content (P : in out Parser) return Content_Type is
   R : Content_Type;
   begin
      Expect_Kind (P, Prefix, "prefix");
      R.Prefix := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
      Expect_Kind (P, COLON, "COLON");
      R.COLON := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
      Expect_Kind (P, Uuid, "uuid");
      R.Uuid := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
      R.Content_1 := Parse_Content_1 (P);
      return R;
   end Parse_Content;

   function Parse_Directive (P : in out Parser) return Directive_Type is
   R : Directive_Type;
   begin
      Expect_Kind (P, Prefix, "prefix");
      R.Prefix := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
      Expect_Kind (P, COLON, "COLON");
      R.COLON := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
      R.Tail := new Tail_Type'(Parse_Tail (P));
      return R;
   end Parse_Directive;

   function Parse_Tail (P : in out Parser) return Tail_Type is
   R : Tail_Type;
   begin
      R.Name := Parse_Name (P);
      Expect_Kind (P, COLON, "COLON");
      R.COLON := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
      R.Value := Parse_Value (P);
      return R;
   end Parse_Tail;

   function Parse_Name (P : in out Parser) return Name_Type is
   R : Name_Type;
   begin
      Expect_Kind (P, Atom, "a Name_Type");
      if To_String (P.Toks (P.Pos).Text) = "label" then R := Name_Label;
      elsif To_String (P.Toks (P.Pos).Text) = "number" then R := Name_Number;
      elsif To_String (P.Toks (P.Pos).Text) = "count" then R := Name_Count;
      elsif To_String (P.Toks (P.Pos).Text) = "default" then R := Name_Default;
      elsif To_String (P.Toks (P.Pos).Text) = "none" then R := Name_None;
      else Fail (P, "`label` or `number` or `count` or `default` or `none`"); end if;
      P.Pos := P.Pos + 1;
      return R;
   end Parse_Name;

   function Parse_Prefix (P : in out Parser) return Prefix_Type is
   R : Prefix_Type;
   begin
      Expect_Kind (P, Prefix, "prefix");
      R := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
      return R;
   end Parse_Prefix;

   function Parse_Uuid (P : in out Parser) return Uuid_Type is
   R : Uuid_Type;
   begin
      Expect_Kind (P, Uuid, "uuid");
      R := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
      return R;
   end Parse_Uuid;

   function Parse_Title (P : in out Parser) return Title_Type is
   R : Title_Type;
   begin
      Expect_Kind (P, Title, "title");
      R := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
      return R;
   end Parse_Title;

   function Parse_Value (P : in out Parser) return Value_Type is
   R : Value_Type;
   Save : Natural;
   begin
      loop
         Save := P.Pos;
         declare
            E : Value_Entry;
            Matched : Boolean := False;
         begin
            if not Matched then
               declare
                  El : Value_Entry;
               begin
                  Expect_Kind (P, Atom, "a string");
                  El.Word := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
                  E := El; Matched := True;
               exception
                  when Parse_Error => P.Pos := Save;
               end;
            end if;
            if not Matched then
               declare
                  El : Value_Entry;
               begin
                  Expect_Kind (P, Uuid, "uuid");
                  El.Uuid := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
                  E := El; Matched := True;
               exception
                  when Parse_Error => P.Pos := Save;
               end;
            end if;
            if not Matched then
               declare
                  El : Value_Entry;
               begin
                  Expect_Kind (P, Int, "a number");
                  El.Int := Long_Long_Integer'Value (To_String (P.Toks (P.Pos).Text)); P.Pos := P.Pos + 1;
                  E := El; Matched := True;
               exception
                  when Parse_Error => P.Pos := Save;
               end;
            end if;
            if not Matched then
               declare
                  El : Value_Entry;
               begin
                  Expect_Kind (P, PIPE, "PIPE");
                  El.PIPE := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
                  E := El; Matched := True;
               exception
                  when Parse_Error => P.Pos := Save;
               end;
            end if;
            if not Matched then
               declare
                  El : Value_Entry;
               begin
                  Expect_Kind (P, Title, "title");
                  El.Title := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
                  E := El; Matched := True;
               exception
                  when Parse_Error => P.Pos := Save;
               end;
            end if;
            exit when not Matched;
            R.Append (E);
         end;
      end loop;
      return R;
   end Parse_Value;

   function Parse_COLON (P : in out Parser) return COLON_Type is
   R : COLON_Type;
   begin
      Expect_Kind (P, COLON, "COLON");
      R := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
      return R;
   end Parse_COLON;

   function Parse_PIPE (P : in out Parser) return PIPE_Type is
   R : PIPE_Type;
   begin
      Expect_Kind (P, PIPE, "PIPE");
      R := P.Toks (P.Pos).Text; P.Pos := P.Pos + 1;
      return R;
   end Parse_PIPE;

   function Parse_Content_1 (P : in out Parser) return Content_1_Type is
   R : Content_1_Type;
   Save : Natural;
   begin
      loop
         exit when P.Pos > Natural (P.Toks.Length) or else P.Toks (P.Pos).Kind = Eof;
         exit when Natural (R.Length) >= 1;
         declare
            Start : constant Natural := P.Pos;
         begin
            R.Append (Parse_Title (P));
         exception
            when Parse_Error => P.Pos := Start; exit;
         end;
      end loop;
      return R;
   end Parse_Content_1;

   function Parse_Tokens
     (Toks  : Token_Vectors.Vector;
      Lines : Line_Vectors.Vector) return Outline_Type is
      P : Parser := (Toks => Toks, Lines => Lines, Pos => 1);
      R : Outline_Type;
   begin
      R := Parse_Outline (P);
      if P.Pos <= Natural (P.Toks.Length) and then P.Toks (P.Pos).Kind /= Eof then
         Fail (P, "end of config");
      end if;
      return R;
   end Parse_Tokens;

   function Jet_Dispatch (S : String; Pos, Len : Natural; Kind : out Token_Kind) return Natural is
      N : Natural;
   begin
      return 0;
   end Jet_Dispatch;

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

   function Scan_Prefix (S : String; Pos, Len : Natural) return Natural is
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
   end Scan_Prefix;

   function Scan_Uuid (S : String; Pos, Len : Natural) return Natural is
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
   end Scan_Uuid;

   function Scan_Title (S : String; Pos, Len : Natural) return Natural is
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
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 9 and then Cp <= 9);
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
   end Scan_Title;

   function Scan_Word (S : String; Pos, Len : Natural) return Natural is
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
         Ok := N > 0 and then (Cp >= 65 and then Cp <= 90);
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
         end;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 97 and then Cp <= 122);
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
         end;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 95 and then Cp <= 95);
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
         end;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      Off := 0;
      Ok := True;
      if Ok then
         N := Decode_Utf8 (S, Pos + Off, Len, Cp);
         Ok := N > 0 and then (Cp >= 45 and then Cp <= 45);
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
         end;
      end if;
      if Ok and then Off > Best then Best := Off; end if;
      return Best;
   end Scan_Word;

   function Scan_Int (S : String; Pos, Len : Natural) return Natural is
      Cp   : Natural;
      N    : Natural;
      Best : Natural := 0;
      Off  : Natural;
      Ok   : Boolean;
   begin
      Off := 0;
      Ok := True;
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
         Ok := N > 0 and then (Cp >= 45 and then Cp <= 45);
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
   end Scan_Int;

   function Scan_COLON (S : String; Pos, Len : Natural) return Natural is
      Cp  : Natural;
      N   : Natural;
      Off : Natural := 0;
   begin
      N := Decode_Utf8 (S, Pos + Off, Len, Cp);
      if N = 0 or else not (Cp >= 58 and then Cp <= 58) then return 0; end if;
      Off := Off + N;
      return Off;
   end Scan_COLON;

   function Scan_PIPE (S : String; Pos, Len : Natural) return Natural is
      Cp  : Natural;
      N   : Natural;
      Off : Natural := 0;
   begin
      N := Decode_Utf8 (S, Pos + Off, Len, Cp);
      if N = 0 or else not (Cp >= 124 and then Cp <= 124) then return 0; end if;
      Off := Off + N;
      return Off;
   end Scan_PIPE;

   function Char_Dispatch (S : String; Pos, Len : Natural; Kind : out Token_Kind) return Natural is
      Best : Natural := 0;
      N    : Natural;
   begin
      Kind := Eof;
      N := Scan_Prefix (S, Pos, Len); if N > Best then Best := N; Kind := Prefix; end if;
      N := Scan_Uuid (S, Pos, Len); if N > Best then Best := N; Kind := Uuid; end if;
      N := Scan_Title (S, Pos, Len); if N > Best then Best := N; Kind := Title; end if;
      N := Scan_Word (S, Pos, Len); if N > Best then Best := N; Kind := Atom; end if;
      N := Scan_Int (S, Pos, Len); if N > Best then Best := N; Kind := Int; end if;
      N := Scan_COLON (S, Pos, Len); if N > Best then Best := N; Kind := COLON; end if;
      N := Scan_PIPE (S, Pos, Len); if N > Best then Best := N; Kind := PIPE; end if;
      return Best;
   end Char_Dispatch;

   function Lex (Text : String) return Token_Vectors.Vector is
      Toks : Token_Vectors.Vector;
      I    : Natural := Text'First;
      Line : Natural := 1;
      Col  : Natural := 1;
      C    : Character;
   begin
      while I <= Text'Last loop
         C := Text (I);
         declare
            JK : Token_Kind;
            JL : constant Natural := Jet_Dispatch (Text, I, Text'Last, JK);
            CK : Token_Kind;
            CL : constant Natural := Char_Dispatch (Text, I, Text'Last, CK);
         begin
            if JL > 0 then
               Toks.Append (Token'(JK, To_Unbounded_String (Text (I .. I + JL - 1)), Line, Col));
               I := I + JL; Col := Col + JL;
            elsif CL > 0 then
               Toks.Append (Token'(CK, To_Unbounded_String (Text (I .. I + CL - 1)), Line, Col));
               I := I + CL; Col := Col + CL;
            elsif C = ' ' or else C = ASCII.HT or else C = ASCII.CR then
               I := I + 1; Col := Col + 1;
         elsif C = ASCII.LF then
            I := I + 1; Line := Line + 1; Col := 1;
         --  backslash-newline continues the line, as parse.y's lgetc()
         elsif C = '\' and then I < Text'Last and then Text (I + 1) = ASCII.LF then
            I := I + 2; Line := Line + 1; Col := 1;
         elsif C = '#' then
            while I <= Text'Last and then Text (I) /= ASCII.LF loop
               I := I + 1; Col := Col + 1;
            end loop;
         elsif C = '"' then
            declare
               SC  : constant Natural := Col;
               SL  : constant Natural := Line;
               Buf : Unbounded_String;
            begin
               I := I + 1; Col := Col + 1;
               while I <= Text'Last and then Text (I) /= '"' loop
                  --  inside quotes parse.y drops backslash-newline and a
                  --  bare newline, counting the line
                  if Text (I) = '\' and then I < Text'Last
                    and then Text (I + 1) = ASCII.LF
                  then
                     I := I + 2; Line := Line + 1; Col := 1;
                  elsif Text (I) = ASCII.LF then
                     I := I + 1; Line := Line + 1; Col := 1;
                  else
                     if Text (I) = '\' and then I < Text'Last then
                        I := I + 1; Col := Col + 1;
                     end if;
                     Append (Buf, Text (I));
                     I := I + 1; Col := Col + 1;
                  end if;
               end loop;
               if I <= Text'Last then
                  I := I + 1; Col := Col + 1;
               end if;
               Toks.Append (Token'(Str, Buf, SL, SC));
            end;
         elsif C in '0' .. '9'
           or else (C = '-' and then I < Text'Last
                    and then Text (I + 1) in '0' .. '9')
         then
            --  -N is a number too, as in parse.y's lexers
            declare
               SC      : constant Natural := Col;
               Start_I : constant Natural := I;
               Buf     : Unbounded_String;
            begin
               if C = '-' then
                  Append (Buf, C); I := I + 1; Col := Col + 1;
               end if;
               while I <= Text'Last and then Text (I) in '0' .. '9' loop
                  Append (Buf, Text (I)); I := I + 1; Col := Col + 1;
               end loop;
               if I <= Text'Last
                 and then (Text (I) in 'a' .. 'z' or else Text (I) in 'A' .. 'Z'
                   or else Text (I) = '.' or else Text (I) = '_'
                   or else Text (I) = '-')
               then
                  --  dotted/alphanumeric run (1.2.3.4, 123abc) is one word
                  I := Start_I; Col := SC;
                  Buf := Null_Unbounded_String;
                  while I <= Text'Last loop
                     C := Text (I);
                     exit when not (C in 'a' .. 'z' or else C in 'A' .. 'Z'
                       or else C in '0' .. '9' or else C = '_' or else C = '-'
                       or else C = '.');
                     Append (Buf, C); I := I + 1; Col := Col + 1;
                  end loop;
                  Toks.Append (Token'(Atom, Buf, Line, SC));
               else
                  Toks.Append (Token'(Int, Buf, Line, SC));
               end if;
            end;
         elsif C in 'a' .. 'z' or else C in 'A' .. 'Z' or else C = '_' or else C = '-' then
            declare
               SC  : constant Natural := Col;
               Buf : Unbounded_String;
            begin
               while I <= Text'Last loop
                  C := Text (I);
                  exit when not (C in 'a' .. 'z' or else C in 'A' .. 'Z'
                    or else C in '0' .. '9' or else C = '_' or else C = '-'
                    or else C = '.');
                  Append (Buf, C); I := I + 1; Col := Col + 1;
               end loop;
               Toks.Append (Token'(Atom, Buf, Line, SC));
            end;
         else
            declare
               Buf : Unbounded_String;
            begin
               Append (Buf, C);
               Toks.Append (Token'(Punct, Buf, Line, Col));
               I := I + 1; Col := Col + 1;
            end;
         end if;
         end;
      end loop;
      Toks.Append (Token'(Eof, Null_Unbounded_String, Line, Col));
      return Toks;
   end Lex;

   function Parse_Text (Text : String) return Outline_Type is
      Toks  : Token_Vectors.Vector := Lex (Text);
      Lines : Line_Vectors.Vector;
      S     : Natural := Text'First;
   begin
      for K in Text'Range loop
         if Text (K) = ASCII.LF then
            Lines.Append (To_Unbounded_String (Text (S .. K - 1)));
            S := K + 1;
         end if;
      end loop;
      Lines.Append (To_Unbounded_String (Text (S .. Text'Last)));
      declare
         P : Parser := (Toks => Toks, Lines => Lines, Pos => 1);
         R : Outline_Type;
      begin
         R := Parse_Outline (P);
         if P.Pos <= Natural (P.Toks.Length) and then P.Toks (P.Pos).Kind /= Eof then
            Fail (P, "end of config");
         end if;
         return R;
      end;
   end Parse_Text;

end Outline_Grammar.Parser;
