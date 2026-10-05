--  buildabook_cli.adb — the buildabook command line.
--
--  buildabook [typst|pdf|cover] [options]
--
--  With no subcommand, build all three stages in order, building whatever it
--  can: render the Typst book, compile the PDF, then (if a cover exists)
--  update its spine and compile it.  A missing or failing stage is reported
--  and the next stage is still attempted when its own inputs are present —
--  no cover.typ only means the cover is skipped, never that the book or the
--  PDF is blocked.

with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Build;
with Materialize;
with Shell;
with Spine;

procedure Buildabook_Cli is

   use Ada.Strings.Unbounded;
   use Ada.Text_IO;

   -- ── configuration ────────────────────────────────────────────────────────

   type Config is record
      Outline    : Unbounded_String;
      Src        : Unbounded_String;
      Out_Dir    : Unbounded_String;
      Filemap    : Unbounded_String;   -- "" = none
      Template   : Unbounded_String;
      Number_Map : Unbounded_String;
      Slug       : Unbounded_String;
      Pdf        : Unbounded_String;
      Cover_Src  : Unbounded_String;
      Cover_Out  : Unbounded_String;
   end record;

   function Argument_Value (Name : String; Default : String) return String is
      Long : constant String := "--" & Name;
   begin
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         declare
            A : constant String := Ada.Command_Line.Argument (I);
         begin
            if A = Long then
               if I < Ada.Command_Line.Argument_Count then
                  return Ada.Command_Line.Argument (I + 1);
               end if;
               return "";
            elsif A'Length > Long'Length
              and then A (A'First .. A'First + Long'Length - 1) = Long
              and then A (A'First + Long'Length) = '='
            then
               return A (A'First + Long'Length + 1 .. A'Last);
            end if;
         end;
      end loop;
      return Default;
   end Argument_Value;

   type Stage is (S_Typst, S_Pdf, S_Cover, S_Check, S_Number_Map, S_All);

   function Subcommand return Stage is
   begin
      if Ada.Command_Line.Argument_Count >= 1 then
         declare
            A : constant String := Ada.Command_Line.Argument (1);
         begin
            if A = "typst" then
               return S_Typst;
            elsif A = "pdf" then
               return S_Pdf;
            elsif A = "cover" then
               return S_Cover;
            elsif A = "check" then
               return S_Check;
            elsif A = "number-map" then
               return S_Number_Map;
            end if;
         end;
      end if;
      return S_All;
   end Subcommand;

   function Detect_Template return String is
   begin
      if Ada.Directories.Exists ("book.header.typ") then
         return "book.header.typ";
      elsif Ada.Directories.Exists ("book.prefix.typ") then
         return "book.prefix.typ";
      end if;
      return "";
   end Detect_Template;

   function Load_Config return Config is
      Slug : constant String :=
        Ada.Directories.Simple_Name (Ada.Directories.Current_Directory);
   begin
      return Config'
        (Outline    => To_Unbounded_String (Argument_Value ("outline", "outline.txt")),
         Src        => To_Unbounded_String (Argument_Value ("src", "chapters")),
         Out_Dir    => To_Unbounded_String (Argument_Value ("out", "rendered")),
         Filemap    => To_Unbounded_String
                         (Argument_Value ("filemap",
                            (if Ada.Directories.Exists ("filemap.txt")
                             then "filemap.txt" else ""))),
         Template   => To_Unbounded_String
                         (Argument_Value ("template", Detect_Template)),
         Number_Map => To_Unbounded_String
                         (Argument_Value ("number-map", "number_map.csv")),
         Slug       => To_Unbounded_String (Argument_Value ("slug", Slug)),
         Pdf        => To_Unbounded_String
                         (Argument_Value ("pdf",
                            Argument_Value ("slug", Slug) & ".pdf")),
         Cover_Src  => To_Unbounded_String (Argument_Value ("cover-src", "cover.typ")),
         Cover_Out  => To_Unbounded_String
                         (Argument_Value ("cover",
                            Argument_Value ("slug", Slug) & "-cover.pdf")));
   end Load_Config;

   -- ── output helpers ───────────────────────────────────────────────────────

   procedure Msg (S : String) is
   begin
      Put_Line (S);
   end Msg;

   procedure Err (S : String) is
   begin
      Put_Line (Standard_Error, "buildabook: " & S);
   end Err;

   function Sh_Quote (S : String) return String is
   begin
      return "'" & S & "'";
   end Sh_Quote;

   procedure Usage is
   begin
      Put_Line ("buildabook — the outline-language book builder");
      New_Line;
      Put_Line ("Usage: buildabook [typst|pdf|cover] [options]");
      New_Line;
      Put_Line ("With no subcommand, build all three stages in order:");
      Put_Line ("  typst       render rendered/book.typ + number_map.csv from outline.txt");
      Put_Line ("  pdf         compile rendered/book.typ to a PDF");
      Put_Line ("  cover       update the cover spine and compile cover.typ");
      Put_Line ("  check       validate outline + filemap + tokens, emit nothing");
      Put_Line ("  number-map  write number_map.csv only");
      New_Line;
      Put_Line ("Each stage reports what is missing and what it needs, and a");
      Put_Line ("missing or failing stage never blocks the others — no cover.typ");
      Put_Line ("just means the cover is skipped.");
      New_Line;
      Put_Line ("Options (all optional):");
      Put_Line ("  --outline PATH      outline file (default outline.txt)");
      Put_Line ("  --src DIR           chapter source directory (default chapters)");
      Put_Line ("  --out DIR           render output directory (default rendered)");
      Put_Line ("  --filemap PATH      UUID:filename map (default filemap.txt if present)");
      Put_Line ("  --template PATH     Typst template (default book.header.typ or book.prefix.typ)");
      Put_Line ("  --number-map PATH   CSV audit output (default number_map.csv)");
      Put_Line ("  --slug NAME         book slug for output names (default: directory name)");
      Put_Line ("  --pdf PATH          book PDF output (default <slug>.pdf)");
      Put_Line ("  --cover-src PATH    cover source (default cover.typ)");
      Put_Line ("  --cover PATH        cover PDF output (default <slug>-cover.pdf)");
   end Usage;

   -- ── stages ───────────────────────────────────────────────────────────────

   procedure Run_Typst (C : Config; Ok : out Boolean) is
      Errors : Materialize.Error_List;
   begin
      if not Ada.Directories.Exists (To_String (C.Outline)) then
         Err ("missing " & To_String (C.Outline) & " (needed to render the book)");
         Ok := False;
         return;
      end if;
      if not Ada.Directories.Exists (To_String (C.Src)) then
         Err ("missing " & To_String (C.Src) & " (needed for the chapter sources)");
         Ok := False;
         return;
      end if;
      if To_String (C.Template) = "" then
         Err ("missing a Typst template (needs book.header.typ or book.prefix.typ)");
         Ok := False;
         return;
      end if;
      if not Ada.Directories.Exists (To_String (C.Template)) then
         Err ("missing " & To_String (C.Template) & " (needed to render book.typ)");
         Ok := False;
         return;
      end if;

      begin
         Errors := Build.Render
           (To_String (C.Outline), To_String (C.Src), To_String (C.Filemap),
            To_String (C.Template), To_String (C.Out_Dir),
            To_String (C.Number_Map));
      exception
         when E : Build.Build_Error =>
            Err (Ada.Exceptions.Exception_Message (E));
            Ok := False;
            return;
         when E : others =>
            Err (Ada.Exceptions.Exception_Message (E));
            Ok := False;
            return;
      end;

      for I in 1 .. Natural (Errors.Length) loop
         Err (To_String (Errors (I)));
      end loop;

      Msg ("built " & To_String (C.Out_Dir) & "/book.typ");
      Ok := True;
   end Run_Typst;

   procedure Run_Pdf (C : Config; Ok : out Boolean) is
      Book_Typ : constant String := To_String (C.Out_Dir) & "/book.typ";
   begin
      if not Ada.Directories.Exists (Book_Typ) then
         Err ("missing " & Book_Typ & " (needed to compile the PDF — run the typst stage first)");
         Ok := False;
         return;
      end if;
      if Shell.Run ("command -v typst >/dev/null 2>&1") /= 0 then
         Err ("missing typst (needed to compile the PDF — install typst-cli)");
         Ok := False;
         return;
      end if;
      if Shell.Run ("typst compile " & Sh_Quote (Book_Typ) & " "
                    & Sh_Quote (To_String (C.Pdf))) /= 0
      then
         Err ("typst failed to compile " & Book_Typ);
         Ok := False;
         return;
      end if;
      Msg ("built " & To_String (C.Pdf));
      Ok := True;
   end Run_Pdf;

   procedure Run_Cover (C : Config; Ok : out Boolean) is
      Updated : Boolean;
   begin
      if not Ada.Directories.Exists (To_String (C.Cover_Src)) then
         Err ("missing " & To_String (C.Cover_Src) & " (needed to build the cover) — skipping cover");
         Ok := False;
         return;
      end if;
      if not Ada.Directories.Exists (To_String (C.Pdf)) then
         Err ("missing " & To_String (C.Pdf) & " (needed for the cover spine) — skipping cover");
         Ok := False;
         return;
      end if;

      begin
         Updated := Spine.Update (To_String (C.Pdf), To_String (C.Cover_Src));
      exception
         when E : Spine.Spine_Error =>
            Err (Ada.Exceptions.Exception_Message (E) & " — skipping cover");
            Ok := False;
            return;
      end;
      if not Updated then
         Err ("no #let sw line in " & To_String (C.Cover_Src)
              & " — spine width left unchanged");
      end if;

      if Shell.Run ("command -v typst >/dev/null 2>&1") /= 0 then
         Err ("missing typst (needed to compile the cover — install typst-cli)");
         Ok := False;
         return;
      end if;
      if Shell.Run ("typst compile " & Sh_Quote (To_String (C.Cover_Src)) & " "
                    & Sh_Quote (To_String (C.Cover_Out))) /= 0
      then
         Err ("typst failed to compile " & To_String (C.Cover_Src));
         Ok := False;
         return;
      end if;
      Msg ("built " & To_String (C.Cover_Out));
      Ok := True;
   end Run_Cover;

   procedure Run_Number_Map (C : Config; Ok : out Boolean) is
   begin
      begin
         Build.Write_Number_Map_Only (To_String (C.Outline), To_String (C.Number_Map));
      exception
         when E : Build.Build_Error =>
            Err (Ada.Exceptions.Exception_Message (E));
            Ok := False;
            return;
         when E : others =>
            Err (Ada.Exceptions.Exception_Message (E));
            Ok := False;
            return;
      end;
      Msg ("wrote " & To_String (C.Number_Map));
      Ok := True;
   end Run_Number_Map;

   procedure Run_Check (C : Config; Ok : out Boolean) is
      Errors   : Materialize.Error_List;
      Warnings : Materialize.Error_List;
      Res      : Build.Check_Result;
   begin
      begin
         Res := Build.Check
           (To_String (C.Outline), To_String (C.Src), To_String (C.Filemap),
            Errors, Warnings);
      exception
         when E : Build.Build_Error =>
            Err (Ada.Exceptions.Exception_Message (E));
            Ok := False;
            return;
         when E : others =>
            Err (Ada.Exceptions.Exception_Message (E));
            Ok := False;
            return;
      end;

      for I in 1 .. Natural (Warnings.Length) loop
         Err ("warning: " & To_String (Warnings (I)));
      end loop;

      for I in 1 .. Natural (Errors.Length) loop
         Err (To_String (Errors (I)));
      end loop;

      Msg ("Preflight: "
        & Ada.Strings.Fixed.Trim (Natural'Image (Res.Matched), Ada.Strings.Left)
        & " outline entries matched, "
        & Ada.Strings.Fixed.Trim (Natural'Image (Res.Missing), Ada.Strings.Left)
        & " entries without files, "
        & Ada.Strings.Fixed.Trim (Natural'Image (Res.Unmatched), Ada.Strings.Left)
        & " unmatched files, "
        & Ada.Strings.Fixed.Trim (Natural'Image (Res.Rows), Ada.Strings.Left)
        & " outline rows.");

      if Natural (Errors.Length) /= 0 then
         Err (Ada.Strings.Fixed.Trim (Natural'Image (Natural (Errors.Length)), Ada.Strings.Left)
              & " error(s) — check failed.");
         Ok := False;
      else
         Msg ("All tokens resolved successfully.");
         Ok := True;
      end if;
   end Run_Check;

   -- ── main ────────────────────────────────────────────────────────────────

   Sub    : constant Stage := Subcommand;
   C      : constant Config := Load_Config;
   Typst_Ok, Pdf_Ok, Cover_Ok, Check_Ok, Number_Map_Ok : Boolean;

begin
   if Ada.Command_Line.Argument_Count >= 1
     and then (Ada.Command_Line.Argument (1) = "-h"
               or else Ada.Command_Line.Argument (1) = "--help")
   then
      Usage;
      return;
   end if;

   case Sub is
      when S_Typst =>
         Run_Typst (C, Typst_Ok);
         Ada.Command_Line.Set_Exit_Status (if Typst_Ok then 0 else 1);
      when S_Pdf =>
         Run_Pdf (C, Pdf_Ok);
         Ada.Command_Line.Set_Exit_Status (if Pdf_Ok then 0 else 1);
      when S_Cover =>
         Run_Cover (C, Cover_Ok);
         Ada.Command_Line.Set_Exit_Status (if Cover_Ok then 0 else 1);
      when S_Check =>
         Run_Check (C, Check_Ok);
         Ada.Command_Line.Set_Exit_Status (if Check_Ok then 0 else 1);
      when S_Number_Map =>
         Run_Number_Map (C, Number_Map_Ok);
         Ada.Command_Line.Set_Exit_Status (if Number_Map_Ok then 0 else 1);
      when S_All =>
         --  default: build what it can, in order, each stage guarded by the
         --  previous stage's output so a failure never cascades.
         Run_Typst (C, Typst_Ok);
         if Typst_Ok then
            Run_Pdf (C, Pdf_Ok);
            if Pdf_Ok then
               Run_Cover (C, Cover_Ok);
            end if;
         end if;
         Ada.Command_Line.Set_Exit_Status (if Typst_Ok then 0 else 1);
   end case;
end Buildabook_Cli;
