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

   --  Resolve a filemap filename to a source path: Src_Dir-relative when it
   --  carries no directory component, otherwise as-is (already a path).
   function Resolve_Path (Src_Dir : String; Fname : String) return String is
   begin
      return (if Ada.Strings.Fixed.Index (Fname, "/") = 0
              then Ada.Directories.Compose (Src_Dir, Fname)
              else Fname);
   end Resolve_Path;

   --  The ordered, deduplicated list of non-.typ filenames, in outline row
   --  order — the work list both the render and the check pass walk.
   function Ordered_Files
     (O : Outline.Outline_Type; FM : Emit.File_Maps.Map) return Str_Vectors.Vector is
      Seen   : Emit.File_Maps.Map;   -- (ab)used as a set: filename → ""
      Result : Str_Vectors.Vector;
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
                     Result.Append (To_Unbounded_String (Fname));
                  end if;
               end;
            end if;
         end;
      end loop;
      return Result;
   end Ordered_Files;

   --  .md files in Src_Dir that no outline token maps to.
   function Compute_Unmatched
     (Src_Dir : String; FM : Emit.File_Maps.Map) return Str_Vectors.Vector is
      Mapped : Emit.File_Maps.Map;   -- (ab)used as a set: filename → ""
      Result : Str_Vectors.Vector;
   begin
      for Cur in FM.Iterate loop
         Mapped.Include (Emit.File_Maps.Element (Cur), "");
      end loop;
      for Fname of List_Md (Src_Dir) loop
         if not Mapped.Contains (To_String (Fname)) then
            Result.Append (Fname);
         end if;
      end loop;
      return Result;
   end Compute_Unmatched;

   --  True when S is a bare UUID: "id" followed by exactly five digits.
   function Is_Id_Uuid (S : String) return Boolean is
   begin
      return S'Length = 7
        and then S (S'First) = 'i'
        and then S (S'First + 1) = 'd'
        and then (for all K in S'First + 2 .. S'Last => S (K) in '0' .. '9');
   end Is_Id_Uuid;

   --  Register {{anchor:ID}} tokens so {{page:ID}} can validate against them,
   --  matching render.py's register_anchors checks: a well-formed idNNNNN that
   --  neither collides with an outline entry nor repeats another anchor.
   procedure Register_Anchors
     (R : in out Tokens.Resolver; Src_Path : String; Text : String) is
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
                        declare
                           Aid : constant String :=
                             Ada.Strings.Fixed.Trim
                               (B (B'First + 7 .. B'Last), Ada.Strings.Both);
                        begin
                           if not Is_Id_Uuid (Aid) then
                              raise Build_Error with
                                Src_Path & ": bad anchor id '" & Aid &
                                "' — expected idNNNNN";
                           end if;
                           if R.O.By_Uuid.Contains (Aid) then
                              raise Build_Error with
                                Src_Path & ": anchor id " & Aid &
                                " collides with an outline entry";
                           end if;
                           if R.Anchor_Ids.Contains (Aid) then
                              raise Build_Error with
                                Src_Path & ": duplicate anchor id " & Aid;
                           end if;
                           R.Anchor_Ids.Insert (Aid);
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
      if not Ada.Directories.Exists (Src_Dir) then
         raise Build_Error with "missing " & Src_Dir & " (the chapter sources are required)";
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

      declare
         Files_List : constant Str_Vectors.Vector := Ordered_Files (O, FM);
      begin
         --  Pass A: register anchors across all source files.
         for Fname of Files_List loop
            declare
               Path : constant String := Resolve_Path (Src_Dir, To_String (Fname));
            begin
               if Ada.Directories.Exists (Path) then
                  Register_Anchors (R, Path, Files.Read (Path));
               end if;
            end;
         end loop;

         --  Pass B: materialize each file.
         for Fname of Files_List loop
            declare
               Path : constant String := Resolve_Path (Src_Dir, To_String (Fname));
            begin
               if Ada.Directories.Exists (Path) then
                  Materialize.Materialize_File
                    (R, Path,
                     Ada.Directories.Compose (Out_Dir, Ada.Directories.Simple_Name (To_String (Fname))),
                     Errors);
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

   -- ── number-map ───────────────────────────────────────────────────────────

   procedure Write_Number_Map_Only (Outline_Path : String; Number_Map : String) is
   begin
      if not Ada.Directories.Exists (Outline_Path) then
         raise Build_Error with
           "missing " & Outline_Path & " (needed to write " & Number_Map & ")";
      end if;
      Emit.Write_Number_Map (Outline.Load (Outline_Path), Number_Map);
   end Write_Number_Map_Only;

   -- ── check ────────────────────────────────────────────────────────────────

   function Check
     (Outline_Path : String;
      Src_Dir      : String;
      Filemap_Path : String;
      Errors       : in out Materialize.Error_List;
      Warnings     : in out Materialize.Error_List) return Check_Result is

      O     : Outline.Outline_Type;
      R     : Tokens.Resolver;
      FM    : Emit.File_Maps.Map;
      Fmap  : constant Emit.File_Maps.Map := Read_Filemap (Filemap_Path);
      Res   : Check_Result := (others => 0);
   begin
      if not Ada.Directories.Exists (Outline_Path) then
         raise Build_Error with "missing " & Outline_Path & " (needed to check the book)";
      end if;
      if not Ada.Directories.Exists (Src_Dir) then
         raise Build_Error with "missing " & Src_Dir & " (needed to check the book)";
      end if;

      O := Outline.Load (Outline_Path);
      R.O := O;
      Res.Rows := Natural (O.Rows.Length);

      FM := Build_File_Map (O, Src_Dir, Fmap);

      --  unmatched files: fatal only when no filemap was in play (heading
      --  fallback), matching render.py; otherwise a warning.
      declare
         Unmatched : constant Str_Vectors.Vector := Compute_Unmatched (Src_Dir, FM);
      begin
         Res.Unmatched := Natural (Unmatched.Length);
         for F of Unmatched loop
            declare
               Msg : constant String :=
                 "file '" & To_String (F) & "' has no matching outline token in its "
                 & "heading — fix the heading, add it to the outline, or remove the file";
            begin
               if Fmap.Is_Empty then
                  Errors.Append (To_Unbounded_String (Msg));
               else
                  Warnings.Append (To_Unbounded_String (Msg & " (excluded from book)"));
               end if;
            end;
         end loop;
      end;

      --  matched vs missing entries (parts, sections and stacks may be fileless).
      for I in 1 .. Natural (O.Rows.Length) loop
         declare
            E : Outline.Row renames O.Rows (I);
         begin
            if E.K in Outline.Section | Outline.Sub_Entry | Outline.Part then
               null;
            elsif FM.Contains (To_String (E.Token)) then
               Res.Matched := Res.Matched + 1;
            else
               Res.Missing := Res.Missing + 1;
               Warnings.Append
                 (To_Unbounded_String
                    ("outline entry " & To_String (E.Token) & " '"
                     & To_String (E.Title) & "' has no source file"));
            end if;
         end;
      end loop;

      --  resolve every token, two passes (anchors first, then resolution).
      declare
         Files_List : constant Str_Vectors.Vector := Ordered_Files (O, FM);
      begin
         for Fname of Files_List loop
            declare
               Path : constant String := Resolve_Path (Src_Dir, To_String (Fname));
            begin
               if Ada.Directories.Exists (Path) then
                  Register_Anchors (R, Path, Files.Read (Path));
               end if;
            end;
         end loop;
         for Fname of Files_List loop
            declare
               Path : constant String := Resolve_Path (Src_Dir, To_String (Fname));
            begin
               if Ada.Directories.Exists (Path) then
                  Materialize.Check_File (R, Path, Errors);
               end if;
            end;
         end loop;
      end;

      return Res;
   end Check;

   -- ── uuid ─────────────────────────────────────────────────────────────────

   --  Track the highest idNNNNN seen in Text (the "id" is two literal letters
   --  followed by exactly five digits; a trailing ".MINOR" is ignored).
   procedure Scan_Uuids (Text : String; Max : in out Natural) is
      P : Natural := Text'First;
   begin
      while P + 6 <= Text'Last loop
         if Text (P .. P + 1) = "id"
           and then (for all K in P + 2 .. P + 6 => Text (K) in '0' .. '9')
         then
            declare
               N : Natural := 0;
            begin
               for K in P + 2 .. P + 6 loop
                  N := N * 10 + (Character'Pos (Text (K)) - Character'Pos ('0'));
               end loop;
               if N > Max then
                  Max := N;
               end if;
            end;
            P := P + 7;
         else
            P := P + 1;
         end if;
      end loop;
   end Scan_Uuids;

   function Next_Uuid (Outline_Path : String; Src_Dir : String) return String is
      Max : Natural := 0;
   begin
      if Ada.Directories.Exists (Outline_Path) then
         Scan_Uuids (Files.Read (Outline_Path), Max);
      end if;
      if Ada.Directories.Exists (Src_Dir) then
         for Fname of List_Md (Src_Dir) loop
            Scan_Uuids
              (Files.Read (Ada.Directories.Compose (Src_Dir, To_String (Fname))),
               Max);
         end loop;
      end if;

      declare
         Next : constant Natural := Max + 1;
         D    : constant String :=
           Ada.Strings.Fixed.Trim (Natural'Image (Next), Ada.Strings.Left);
      begin
         case D'Length is
            when 1      => return "id0000" & D;
            when 2      => return "id000" & D;
            when 3      => return "id00" & D;
            when 4      => return "id0" & D;
            when others => return "id" & D;
         end case;
      end;
   end Next_Uuid;

end Build;
