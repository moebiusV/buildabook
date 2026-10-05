--  shell.ads — run external commands (typst, pdfinfo) and read their output.

package Shell is

   --  Run Command_Line through /bin/sh -c, inheriting stdout/stderr.  Returns
   --  0 on success, 1 on a non-zero exit, -1 if the process could not spawn.
   function Run (Command_Line : String) return Integer;

   --  Run Command_Line and return its combined stdout+stderr as a String.
   --  Returns "" if the process could not spawn or produced nothing.
   function Capture (Command_Line : String) return String;

end Shell;
