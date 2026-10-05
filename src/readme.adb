--  readme.adb — rebuild README.md from DESCRIPTION.md and the chapter .desc
--  sidecars.

with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Files;

package body Readme is

   use Ada.Strings.Unbounded;
   use Ada.Text_IO;

   NL : constant String := "" & ASCII.LF;

   --  A front-matter block: "Key: value" lines, then (optionally) a blank line
   --  followed by prose.
   type Meta is record
      Title    : Unbounded_String;
      Tagline  : Unbounded_String;
      Creation : Unbounded_String;   -- Creation-Date
      Modified : Unbounded_String;   -- Last-Modified
      Prose    : Unbounded_String;
   end record;

   type Chapter is record
      File     : Unbounded_String;   -- "00_introduction_....md"
      Title    : Unbounded_String;
      Creation : Unbounded_String;
      Modified : Unbounded_String;
      Tagline  : Unbounded_String;
   end record;

   package Str_Sets        is new Ada.Containers.Indefinite_Ordered_Sets (String);
   package Chapter_Vectors is new Ada.Containers.Vectors (Positive, Chapter);

   function Trim (S : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (S, Ada.Strings.Both);
   end Trim;

   function Dec (N : Natural) return String is
   begin
      return Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left);
   end Dec;

   --  Return the next line of Text (without its LF), advancing Pos past it.
   --  Returns an empty line for a blank line.  Pos ends at Text'Last + 1 once
   --  the final line has been consumed.
   function Next_Line (Text : String; Pos : in out Natural) return Unbounded_String is
      Result : Unbounded_String;
      Nl_Idx : Natural;
   begin
      if Pos > Text'Last then
         return Null_Unbounded_String;
      end if;
      Nl_Idx := Ada.Strings.Fixed.Index (Text (Pos .. Text'Last), NL);
      if Nl_Idx = 0 then
         Append (Result, Text (Pos .. Text'Last));
         Pos := Text'Last + 1;
      elsif Nl_Idx > Pos then
         Append (Result, Text (Pos .. Nl_Idx - 1));
         Pos := Nl_Idx + 1;
      else
         Pos := Nl_Idx + 1;   -- blank line (Nl_Idx = Pos)
      end if;
      return Result;
   end Next_Line;

   --  Parse "Key: value" lines, and after the first blank line collect the
   --  remainder as Prose (used only by DESCRIPTION.md).
   procedure Parse_Meta (Text : String; M : out Meta) is
      Pos      : Natural := Text'First;
      In_Prose : Boolean := False;
   begin
      M := (Title => Null_Unbounded_String, Tagline => Null_Unbounded_String,
            Creation => Null_Unbounded_String, Modified => Null_Unbounded_String,
            Prose => Null_Unbounded_String);
      while Pos <= Text'Last loop
         declare
            Line : constant String := To_String (Next_Line (Text, Pos));
         begin
            if In_Prose then
               Append (M.Prose, Line);
               Append (M.Prose, NL);
            elsif Trim (Line) = "" then
               In_Prose := True;
            else
               declare
                  Colon : constant Natural :=
                    Ada.Strings.Fixed.Index (Line, ":");
               begin
                  if Colon > Line'First then
                     declare
                        K : constant String := Trim (Line (Line'First .. Colon - 1));
                        V : constant String := Trim (Line (Colon + 1 .. Line'Last));
                     begin
                        if K = "Title" then
                           M.Title := To_Unbounded_String (V);
                        elsif K = "Tagline" then
                           M.Tagline := To_Unbounded_String (V);
                        elsif K = "Creation-Date" then
                           M.Creation := To_Unbounded_String (V);
                        elsif K = "Last-Modified" then
                           M.Modified := To_Unbounded_String (V);
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Parse_Meta;

   function Month_Name (MM : String) return String is
   begin
      if MM = "01" then return "January";
      elsif MM = "02" then return "February";
      elsif MM = "03" then return "March";
      elsif MM = "04" then return "April";
      elsif MM = "05" then return "May";
      elsif MM = "06" then return "June";
      elsif MM = "07" then return "July";
      elsif MM = "08" then return "August";
      elsif MM = "09" then return "September";
      elsif MM = "10" then return "October";
      elsif MM = "11" then return "November";
      elsif MM = "12" then return "December";
      else return MM;
      end if;
   end Month_Name;

   --  "2026-03-18" -> "March 2026" (falls back to the raw date if malformed).
   function Humanize (Date : String) return String is
   begin
      if Date'Length >= 7 then
         return Month_Name (Date (Date'First + 5 .. Date'First + 6))
           & " " & Date (Date'First .. Date'First + 3);
      end if;
      return Date;
   end Humanize;

   --  Collect the chapter .md filenames (sorted), one per source file.
   procedure Collect_Md (Src : String; Set : in out Str_Sets.Set) is
      procedure Add (E : Ada.Directories.Directory_Entry_Type) is
         Name : constant String := Ada.Directories.Simple_Name (E);
      begin
         if Name'Length > 3
           and then Name (Name'Last - 2 .. Name'Last) = ".md"
         then
            Set.Include (Name);
         end if;
      end Add;
   begin
      if Ada.Directories.Exists (Src) then
         Ada.Directories.Search
           (Src, "*.md",
            (Ada.Directories.Ordinary_File => True, others => False),
            Add'Access);
      end if;
   end Collect_Md;

   procedure Write_Readme
     (Description_Path : String;
      Src_Dir          : String;
      Slug             : String;
      Out_Path         : String)
   is
      Book    : Meta;
      Md      : Str_Sets.Set;
      Entries : Chapter_Vectors.Vector;
      Out_Buf : Unbounded_String;
      Max_Mod : Unbounded_String := Null_Unbounded_String;

      procedure Line (S : String) is
      begin
         Append (Out_Buf, S);
         Append (Out_Buf, NL);
      end Line;

      procedure Blank is
      begin
         Append (Out_Buf, NL);
      end Blank;
   begin
      if not Ada.Directories.Exists (Description_Path) then
         raise Readme_Error with "missing " & Description_Path;
      end if;

      Parse_Meta (Files.Read (Description_Path), Book);
      Collect_Md (Src_Dir, Md);

      for Name of Md loop
         declare
            Desc_Path : constant String :=
              Src_Dir & "/" & Name & ".desc";
         begin
            if not Ada.Directories.Exists (Desc_Path) then
               Put_Line (Standard_Error,
                 "buildabook: readme: no .desc for " & Name & " — skipped");
            else
               declare
                  M : Meta;
                  E : Chapter;
               begin
                  Parse_Meta (Files.Read (Desc_Path), M);
                  E.File     := To_Unbounded_String (Name);
                  E.Title    := M.Title;
                  E.Creation := M.Creation;
                  E.Modified := M.Modified;
                  E.Tagline  := M.Tagline;
                  Entries.Append (E);
                  if E.Modified > Max_Mod then
                     Max_Mod := E.Modified;
                  end if;
               end;
            end if;
         end;
      end loop;

      --  Header
      Line ("# " & To_String (Book.Title));
      Blank;
      Line (To_String (Book.Tagline) & " ("
        & Dec (Natural (Entries.Length)) & " documents)");
      Blank;
      Line ("<small>Created: " & Humanize (To_String (Book.Creation))
        & " · Updated: " & To_String (Max_Mod) & "</small>");
      Blank;

      --  Intro prose (DESCRIPTION.md body), then the download table.
      if To_String (Book.Prose) /= "" then
         Append (Out_Buf, To_String (Book.Prose));
         Blank;
      end if;
      Line ("---");
      Blank;
      Line ("## Download");
      Blank;
      Line ("| Format | Link | Created | Updated |");
      Line ("|---|---|---|---|");
      Line ("| PDF | [" & Slug & ".pdf](" & Slug & ".pdf) | "
        & To_String (Book.Creation) & " | " & To_String (Max_Mod) & " |");
      Blank;

      --  Contents
      Line ("## Contents");
      Blank;
      for I in 1 .. Natural (Entries.Length) loop
         declare
            E : Chapter renames Entries (I);
         begin
            Line ("**[" & To_String (E.Title) & "](" & Src_Dir & "/"
              & To_String (E.File) & ")** — " & To_String (E.Tagline));
            Blank;
            Line ("<small>Created: " & To_String (E.Creation)
              & " · Updated: " & To_String (E.Modified) & "</small>");
            Blank;
         end;
      end loop;

      Files.Write (Out_Path, To_String (Out_Buf));
   end Write_Readme;

end Readme;
