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
   --  standard error.  Slug names the PDF in the Download table.  When Slug.html
   --  exists, the table gets an HTML row and the entries of the book link to
   --  their chapters in it (Slug.html#ch-NAME, NAME being the file name without
   --  ".md" and with anything but letters, digits, "_" and "-" turned into "-");
   --  the book is the files named by Filemap ("" = every entry), and any other
   --  entry links to its Markdown source.
   procedure Write_Readme
     (Description_Path : String;
      Src_Dir          : String;
      Slug             : String;
      Out_Path         : String;
      Filemap          : String := "");

end Readme;
