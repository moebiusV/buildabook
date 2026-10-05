--  config.adb — parse book.conf into a Book_Config.

with Ada.Directories;
with Ada.Strings.Fixed;

with Files;
with HBNF_Config;

package body Config is

   use Ada.Strings.Unbounded;
   use type HBNF_Config.Node_Access;

   --  The first value of the directive named Name under N, as text, or "".
   function Dir_Text (N : HBNF_Config.Node; Name : String) return String is
      Child : HBNF_Config.Node_Access := HBNF_Config.Find (N, Name);
   begin
      if Child = null or else HBNF_Config.Value_Count (Child.all) = 0 then
         return "";
      end if;
      return HBNF_Config.As_Text (HBNF_Config.Value_At (Child.all, 1));
   end Dir_Text;

   function Load (Path : String) return Book_Config is
      C : Book_Config;
   begin
      if Path = "" or else not Ada.Directories.Exists (Path) then
         return C;
      end if;

      declare
         R : HBNF_Config.Parse_Result := HBNF_Config.Parse (Files.Read (Path));
      begin
         if not R.Success then
            raise Config_Error with
              Path & ":" &
              Ada.Strings.Fixed.Trim (Positive'Image (R.Line), Ada.Strings.Left) &
              ":" &
              Ada.Strings.Fixed.Trim (Positive'Image (R.Col), Ada.Strings.Left) &
              ": " & To_String (R.Msg);
         end if;

         C.Title      := To_Unbounded_String (Dir_Text (R.Root.all, "title"));
         C.Subtitle   := To_Unbounded_String (Dir_Text (R.Root.all, "subtitle"));
         C.Tagline    := To_Unbounded_String (Dir_Text (R.Root.all, "tagline"));
         C.Author     := To_Unbounded_String (Dir_Text (R.Root.all, "author"));
         C.Year       := To_Unbounded_String (Dir_Text (R.Root.all, "year"));
         C.Publisher  := To_Unbounded_String (Dir_Text (R.Root.all, "publisher"));
         C.City       := To_Unbounded_String (Dir_Text (R.Root.all, "city"));
         C.Isbn       := To_Unbounded_String (Dir_Text (R.Root.all, "isbn"));
         C.Slug       := To_Unbounded_String (Dir_Text (R.Root.all, "slug"));

         declare
            B : HBNF_Config.Node_Access := HBNF_Config.Find (R.Root.all, "build");
         begin
            if B /= null then
               C.Outline    := To_Unbounded_String (Dir_Text (B.all, "outline"));
               C.Src        := To_Unbounded_String (Dir_Text (B.all, "src"));
               C.Out_Dir    := To_Unbounded_String (Dir_Text (B.all, "out"));
               C.Template   := To_Unbounded_String (Dir_Text (B.all, "template"));
               C.Number_Map := To_Unbounded_String (Dir_Text (B.all, "number-map"));
            end if;
         end;

         declare
            V : HBNF_Config.Node_Access := HBNF_Config.Find (R.Root.all, "cover");
         begin
            if V /= null then
               C.Cover_Src := To_Unbounded_String (Dir_Text (V.all, "source"));
               C.Cover_Out := To_Unbounded_String (Dir_Text (V.all, "output"));
            end if;
         end;
      end;

      return C;
   end Load;

end Config;
