--  files.ads — raw byte file I/O, so the emitted Typst and CSV are byte-for-
--  byte what render.py writes (no newline translation, no encoding surprises).

package Files is

   --  Read a whole file as raw bytes.
   function Read (Path : String) return String;

   --  Write Content to Path as raw bytes, truncating any existing file.
   procedure Write (Path : String; Content : String);

end Files;
