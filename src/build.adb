--  build.adb — the render orchestration.

with Ada.Containers;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Emit;
with Files;
with Materialize;
with Outline;
with Tokens;

package body Build is

   use Ada.Strings.Unbounded;

   package Str_Vectors is new Ada.Containers.Vectors (Positive, Unbounded_String);

   --  forward declarations (bodies below)
   function Trim_Line (S : String) return String;

   function Ends_With (S : String; Suffix : String) return Boolean is
   begin
      return S'Length >= Suffix'Length
        and then S (S'Last - Suffix'Length + 1 .. S'Last) = Suffix;
   end Ends_With;

   --  The first "# " heading line of a markdown file, or "".
   function First_Heading (Text : String) return String is
      Start : Natural := Text'First;
      I     : Natural;
   begin
      loop
         I := Ada.Strings.Fixed.Index
           (Text (Start .. Text'Last), String'(1 => ASCII.LF));
         declare
            Line : constant String :=
              (if I = 0 then Text (Start .. Text'Last)
               else Text (Start .. I - 1));
         begin
            if Line'Length >= 2
              and then Line (Line'First) = '#'
              and then Line (Line'First + 1) = ' '
            then
               return Line;
            end if;
         end;
         exit when I = 0;
         Start := I + 1;
      end loop;
      return "";
   end First_Heading;

   --  Read filemap.txt: UUID:filename lines, # comments, blank lines skipped.
   function Read_Filemap (Path : String) return Emit.File_Maps.Map is
      M : Emit.File_Maps.Map;
   begin
      if Path = "" or else not Ada.Directories.Exists (Path) then
         return M;
      end if;
      declare
         Text  : constant String := Files.Read (Path);
         Start : Natural := Text'First;
         I     : Natural;
      begin
         loop
            I := Ada.Strings.Fixed.Index
              (Text (Start .. Text'Last), String'(1 => ASCII.LF));
            declare
               Line : constant String :=
                 (if I = 0 then Text (Start .. Text'Last)
                  else Text (Start .. I - 1));
               S    : constant String := Trim_Line (Line);
               Colon : Natural;
            begin
               if S /= "" and then S (S'First) /= '#' then
                  Colon := Ada.Strings.Fixed.Index (S, ":");
                  if Colon /= 0 then
                     M.Insert
                       (S (S'First .. Colon - 1), S (Colon + 1 .. S'Last));
                  end if;
               end if;
            end;
            exit when I = 0;
            Start := I + 1;
         end loop;
      end;
      return M;
   end Read_Filemap;

   function Trim_Line (S : String) return String is
      First : Natural := S'First;
      Last  : Natural := S'Last;
   begin
      while First <= Last
        and then (S (First) = ' ' or else S (First) = ASCII.HT
                  or else S (First) = ASCII.CR)
      loop
         First := First + 1;
      end loop;
      while Last >= First
        and then (S (Last) = ' ' or else S (Last) = ASCII.HT
                  or else S (Last) = ASCII.CR)
      loop
         Last := Last - 1;
      end loop;
      if First > Last then
         return "";
      end if;
      return S (First .. Last);
   end Trim_Line;

   --  Sorted list of the .md files directly in Src_Dir.
   function List_Md (Src_Dir : String) return Str_Vectors.Vector is
      V : Str_Vectors.Vector;
      use Ada.Directories;
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
   begin
      Start_Search (Search, Src_Dir, "");
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Ent);
         declare
            Name : constant String := Simple_Name (Ent);
         begin
            if Ends_With (Name, ".md")
              and then Kind (Ent) = Ordinary_File
            then
               V.Append (To_Unbounded_String (Name));
            end if;
         end;
      end loop;
      End_Search (Search);

      --  insertion sort
      for I in 2 .. Natural (V.Length) loop
         declare
            Key : constant Unbounded_String := V (I);
            K   : Natural := I;
         begin
            while K > 1 and then To_String (V (K - 1)) > To_String (Key) loop
               V (K) := V (K - 1);
               K := K - 1;
            end loop;
            V (K) := Key;
         end;
      end loop;
      return V;
   end List_Md;

   --  token → filename: filemap entries first, heading matching as fallback.
   function Build_File_Map
     (O : Outline.Outline_Type; Src_Dir : String;
      Filemap : Emit.File_Maps.Map) return Emit.File_Maps.Map is
      Token_To_File : Emit.File_Maps.Map;
   begin
      --  filemap path: uuid → filename, so map each row's token by its uuid.
      if not Filemap.Is_Empty then
         for I in 1 .. Natural (O.Rows.Length) loop
            declare
               E : Outline.Row renames O.Rows (I);
            begin
               if Filemap.Contains (To_String (E.Uuid)) then
                  Token_To_File.Include
                    (To_String (E.Token), Filemap.Element (To_String (E.Uuid)));
               end if;
            end;
         end loop;
      end if;

      --  fallback: heading matching when no filemap produced anything.
      if Token_To_File.Is_Empty then
         for Fname of List_Md (Src_Dir) loop
            declare
               Heading : constant String :=
                 First_Heading (Files.Read (Ada.Directories.Compose (Src_Dir, To_String (Fname))));
               Matched : Unbounded_String := Null_Unbounded_String;
            begin
               for I in 1 .. Natural (O.Rows.Length) loop
                  declare
                     E : Outline.Row renames O.Rows (I);
                  begin
                     if Ada.Strings.Fixed.Index (Heading, To_String (E.Token)) /= 0 then
                        if Length (Matched) /= 0 then
                           raise Build_Error with
                             "file '" & To_String (Fname) & "': heading matches both "
                             & To_String (Matched) & " and " & To_String (E.Token);
                        end if;
                        Matched := E.Token;
                     end if;
                  end;
               end loop;
               if Length (Matched) /= 0 then
                  if Token_To_File.Contains (To_String (Matched)) then
                     raise Build_Error with
                       "outline token " & To_String (Matched) & " claimed by both '"
                       & Token_To_File.Element (To_String (Matched)) & "' and '"
                       & To_String (Fname) & "'";
                  end if;
                  Token_To_File.Insert (To_String (Matched), To_String (Fname));
               end if;
            end;
         end loop;
      end if;

      return Token_To_File;
   end Build_File_Map;

   --  Register {{anchor:ID}} tokens so {{page:ID}} can validate against them.
   procedure Register_Anchors (R : in out Tokens.Resolver; Text : String) is
      P : Natural := Text'First;
   begin
      while P <= Text'Last loop
         if P < Text'Last and then Text (P) = '{' and then Text (P + 1) = '{' then
            declare
               Q : constant Natural :=
                 Ada.Strings.Fixed.Index (Text (P + 2 .. Text'Last), "}}");
            begin
               if Q = 0 then
                  P := P + 2;
               else
                  declare
                     B : constant String :=
                       Ada.Strings.Fixed.Trim (Text (P + 2 .. Q - 1),
                                               Ada.Strings.Both);
                  begin
                     if B'Length >= 7
                       and then B (B'First .. B'First + 6) = "anchor:"
                     then
                        R.Anchor_Ids.Insert
                          (Ada.Strings.Fixed.Trim
                             (B (B'First + 7 .. B'Last), Ada.Strings.Both));
                     end if;
                  end;
                  P := Q + 2;
               end if;
            end;
         else
            P := P + 1;
         end if;
      end loop;
   end Register_Anchors;

   -- ── Render ───────────────────────────────────────────────────────────────

   function Render
     (Outline_Path  : String;
      Src_Dir       : String;
      Filemap_Path  : String;
      Template_Path : String;
      Out_Dir       : String;
      Number_Map    : String) return Materialize.Error_List is

      O  : Outline.Outline_Type;
      R  : Tokens.Resolver;
      FM : Emit.File_Maps.Map;
      Errors : Materialize.Error_List;
   begin
      if not Ada.Directories.Exists (Outline_Path) then
         raise Build_Error with "missing " & Outline_Path & " (the outline is required)";
      end if;

      O := Outline.Load (Outline_Path);
      R.O := O;

      FM := Build_File_Map (O, Src_Dir, Read_Filemap (Filemap_Path));

      --  Clean and (re)create the output directory.
      if Ada.Directories.Exists (Out_Dir) then
         declare
            Search : Ada.Directories.Search_Type;
            Ent    : Ada.Directories.Directory_Entry_Type;
         begin
            Ada.Directories.Start_Search (Search, Out_Dir, "");
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Ent);
               if Ends_With (Ada.Directories.Simple_Name (Ent), ".md") then
                  Ada.Directories.Delete_File (Ada.Directories.Full_Name (Ent));
               end if;
            end loop;
            Ada.Directories.End_Search (Search);
         end;
      end if;
      Ada.Directories.Create_Path (Out_Dir);

      --  Pass A: register anchors across all source files, in outline order.
      declare
         Seen : Emit.File_Maps.Map;   -- (ab)used as a set: filename → ""
      begin
         for I in 1 .. Natural (O.Rows.Length) loop
            declare
               E : Outline.Row renames O.Rows (I);
            begin
               if E.K in Outline.Section | Outline.Sub_Entry then
                  null;
               elsif not FM.Contains (To_String (E.Token)) then
                  null;
               elsif Seen.Contains (FM.Element (To_String (E.Token))) then
                  null;
               else
                  declare
                     Fname : constant String := FM.Element (To_String (E.Token));
                  begin
                     Seen.Insert (Fname, "");
                     if not Ends_With (Fname, ".typ") then
                        declare
                           Path : constant String :=
                             (if Ada.Strings.Fixed.Index (Fname, "/") = 0
                              then Ada.Directories.Compose (Src_Dir, Fname)
                              else Fname);
                        begin
                           if Ada.Directories.Exists (Path) then
                              Register_Anchors (R, Files.Read (Path));
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end loop;
      end;

      --  Pass B: materialize each file.
      declare
         Seen : Emit.File_Maps.Map;
      begin
         for I in 1 .. Natural (O.Rows.Length) loop
            declare
               E : Outline.Row renames O.Rows (I);
            begin
               if E.K in Outline.Section | Outline.Sub_Entry then
                  null;
               elsif not FM.Contains (To_String (E.Token)) then
                  null;
               elsif Seen.Contains (FM.Element (To_String (E.Token))) then
                  null;
               else
                  declare
                     Fname : constant String := FM.Element (To_String (E.Token));
                     Base  : constant String :=
                       Ada.Directories.Simple_Name (Fname);
                  begin
                     Seen.Insert (Fname, "");
                     if not Ends_With (Fname, ".typ") then
                        declare
                           Path : constant String :=
                             (if Ada.Strings.Fixed.Index (Fname, "/") = 0
                              then Ada.Directories.Compose (Src_Dir, Fname)
                              else Fname);
                        begin
                           if Ada.Directories.Exists (Path) then
                              Materialize.Materialize_File
                                (R, Path,
                                 Ada.Directories.Compose (Out_Dir, Base),
                                 Errors);
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end loop;
      end;

      Emit.Write_Number_Map (O, Number_Map);

      if not Ada.Directories.Exists (Template_Path) then
         raise Build_Error with
           "missing " & Template_Path & " (the Typst template is required)";
      end if;
      Emit.Write_Book_Typ (O, FM, Template_Path, Ada.Directories.Compose (Out_Dir, "book.typ"));

      return Errors;
   end Render;

end Build;
