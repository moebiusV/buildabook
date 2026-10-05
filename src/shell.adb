--  shell.adb — run an external command, optionally capturing its output.

with Ada.Directories;

with GNAT.OS_Lib;

with Files;

package body Shell is

   use GNAT.OS_Lib;

   Capture_Path : constant String := "/tmp/buildabook.capture";

   function Spawn (Command_Line : String) return Integer is
      Pid     : Process_Id;
      Wpid    : Process_Id;
      Success : Boolean;
   begin
      Pid := Non_Blocking_Spawn
        ("/bin/sh",
         Argument_List'(1 => new String'("-c"), 2 => new String'(Command_Line)));
      if Pid = Invalid_Pid then
         return -1;
      end if;
      Wait_Process (Wpid, Success);
      return (if Success then 0 else 1);
   end Spawn;

   function Run (Command_Line : String) return Integer is
   begin
      return Spawn (Command_Line);
   end Run;

   function Capture (Command_Line : String) return String is
      Status : Integer;
   begin
      if Ada.Directories.Exists (Capture_Path) then
         Ada.Directories.Delete_File (Capture_Path);
      end if;
      Status := Spawn
        (Command_Line & " > " & Capture_Path & " 2>&1");
      if Status = -1 then
         return "";
      end if;
      if not Ada.Directories.Exists (Capture_Path) then
         return "";
      end if;
      declare
         Text : constant String := Files.Read (Capture_Path);
      begin
         Ada.Directories.Delete_File (Capture_Path);
         return Text;
      end;
   end Capture;

end Shell;
