--  config.adb — parse book.conf into a Book_Config.  The parser is generated
--  by hbnf from grammars/book_conf.hbnf (Book_Conf_Grammar); the tree is
--  generic (a key, then a value or a { } block of keys), so the directives are
--  looked up by name here.

with Ada.Directories;
with Ada.Exceptions;

with Files;
with Book_Conf_Grammar;
with Book_Conf_Grammar.Parser;

package body Config is

   use Ada.Strings.Unbounded;
   use type Book_Conf_Grammar.Bnf_body_Access;
   use type Book_Conf_Grammar.Bnf_block_Access;

   --  A value's text.  A word is itself; a "quoted string" arrives with its
   --  quotes and backslash escapes, which are removed here (\x is x).
   function Text_Of (V : Book_Conf_Grammar.Bnf_value_Type) return String is
      S : constant String := To_String (V);
      B : Unbounded_String;
      I : Natural;
   begin
      if S'Length >= 2 and then S (S'First) = '"' and then S (S'Last) = '"' then
         I := S'First + 1;
         while I < S'Last loop
            if S (I) = '\' and then I + 1 < S'Last then
               I := I + 1;
            end if;
            Append (B, S (I));
            I := I + 1;
         end loop;
         return To_String (B);
      end if;
      return S;
   end Text_Of;

   --  The text of an item's value, or "" if the item has a block (or nothing).
   function Item_Text (It : Book_Conf_Grammar.Bnf_item_Access) return String is
   begin
      if It.Bnf_body /= null then
         return Text_Of (It.Bnf_body.Bnf_value);
      end if;
      return "";
   end Item_Text;

   --  The first value of the directive named Name in a block, or "".
   function Block_Text
     (B : Book_Conf_Grammar.Bnf_block_Type; Name : String) return String is
   begin
      for It of B.Bnf_block_1 loop
         if To_String (It.Bnf_key) = Name then
            return Item_Text (It);
         end if;
      end loop;
      return "";
   end Block_Text;

   function Load (Path : String) return Book_Config is
      C : Book_Config;
   begin
      if Path = "" or else not Ada.Directories.Exists (Path) then
         return C;
      end if;

      declare
         Root : Book_Conf_Grammar.Bnf_book_Type;
      begin
         begin
            Root := Book_Conf_Grammar.Parser.Parse_Text (Files.Read (Path));
         exception
            when E : Book_Conf_Grammar.Parser.Parse_Error =>
               raise Config_Error with
                 Path & ": " & Ada.Exceptions.Exception_Message (E);
         end;

         --  a directive that is given twice: the first one wins, as before
         for It of Root loop
            declare
               K : constant String := To_String (It.Bnf_key);
               V : constant Unbounded_String :=
                 To_Unbounded_String (Item_Text (It));
            begin
               if It.Bnf_body /= null and then It.Bnf_body.Bnf_block /= null then
                  declare
                     B : Book_Conf_Grammar.Bnf_block_Type renames
                       It.Bnf_body.Bnf_block.all;
                  begin
                     if K = "build" and then Length (C.Outline) = 0 then
                        C.Outline    := To_Unbounded_String (Block_Text (B, "outline"));
                        C.Src        := To_Unbounded_String (Block_Text (B, "src"));
                        C.Out_Dir    := To_Unbounded_String (Block_Text (B, "out"));
                        C.Template   := To_Unbounded_String (Block_Text (B, "template"));
                        C.Number_Map := To_Unbounded_String (Block_Text (B, "number-map"));
                     elsif K = "cover" and then Length (C.Cover_Src) = 0 then
                        C.Cover_Src := To_Unbounded_String (Block_Text (B, "source"));
                        C.Cover_Out := To_Unbounded_String (Block_Text (B, "output"));
                     end if;
                  end;
               elsif K = "title" and then Length (C.Title) = 0 then
                  C.Title := V;
               elsif K = "subtitle" and then Length (C.Subtitle) = 0 then
                  C.Subtitle := V;
               elsif K = "tagline" and then Length (C.Tagline) = 0 then
                  C.Tagline := V;
               elsif K = "author" and then Length (C.Author) = 0 then
                  C.Author := V;
               elsif K = "year" and then Length (C.Year) = 0 then
                  C.Year := V;
               elsif K = "publisher" and then Length (C.Publisher) = 0 then
                  C.Publisher := V;
               elsif K = "city" and then Length (C.City) = 0 then
                  C.City := V;
               elsif K = "isbn" and then Length (C.Isbn) = 0 then
                  C.Isbn := V;
               elsif K = "slug" and then Length (C.Slug) = 0 then
                  C.Slug := V;
               end if;
            end;
         end loop;
      end;

      return C;
   end Load;

end Config;
