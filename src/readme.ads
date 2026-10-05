--  readme.ads — rebuild README.md from DESCRIPTION.md and the chapter .desc
--  sidecars.

package Readme is

   Readme_Error : exception;

   --  Write README.md.
   --
   --  Description_Path is the book header (DESCRIPTION.md): Title / Tagline /
   --  Creation-Date front matter followed by the intro prose.  Src_Dir is
   --  scanned for *.md.desc sidecars, one Contents entry each (sorted by
   --  filename).  A chapter whose .desc is missing is skipped and noted on
   --  standard error.  Slug names the PDF in the Download table.
   procedure Write_Readme
     (Description_Path : String;
      Src_Dir          : String;
      Slug             : String;
      Out_Path         : String);

end Readme;
