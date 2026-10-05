--  spine.ads — the cover-spine updater, the port of render.py's
--  --update-cover-spine: read the book PDF's page count with pdfinfo, compute
--  the spine width, and rewrite the #let sw line in cover.typ.

package Spine is

   Spine_Error : exception;

   --  Rewrite the "#let sw =" line in Cover_Path from Pdf_Path's page count
   --  (spine = pages / 399.0 inches, two decimals).  Returns True when the
   --  line was found and rewritten, False when the line is absent (the cover
   --  is left untouched).  Raises Spine_Error when Pdf_Path or Cover_Path is
   --  missing, or when the page count cannot be determined (pdfinfo missing
   --  or failed).
   function Update
     (Pdf_Path   : String;
      Cover_Path : String := "cover.typ") return Boolean;

end Spine;
