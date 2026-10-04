--  outline.ads — the numbering engine: parse outline.txt, apply directives
--  positionally, snapshot the per-prefix regime onto each entry, and number.
--
--  This is the port of render.py's Outline class (its _parse/_apply_directive/
--  display) into Ada, over the hbnf-generated tree (Outline_Grammar).  The
--  display() output feeds the TOC and every {{token}} substitution, so it must
--  match render.py byte for byte.

with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package Outline is

   use Ada.Strings.Unbounded;

   type Kind is (Chapter, Part, Appendix, Division, Unlisted, Section, Sub_Entry);

   type Number_Style is (Arabic, Roman, Roman_Lower, Letter, No_Number);

   --  A resolved content entry: the regime snapshotted at its outline position
   --  plus its computed number.
   type Row is record
      Token          : Unbounded_String;   -- "c:00001"
      K              : Kind;
      Uuid           : Unbounded_String;   -- "00001" (for a sub-entry, the parent)
      Minor          : Unbounded_String;   -- sub-entry minor ("1"); else ""
      Title          : Unbounded_String;
      Parent         : Unbounded_String;   -- parent uuid (sections/sub-entries); else ""
      N              : Natural := 0;       -- computed number
      Has_N          : Boolean := False;
      Label          : Unbounded_String;   -- "" means none
      Short          : Unbounded_String;   -- "" means none
      Style          : Number_Style := No_Number;
      Suppress_Title : Boolean := False;
      Toc            : Boolean := True;
   end record;

   package Row_Vectors is new Ada.Containers.Vectors (Positive, Row);
   subtype Row_List is Row_Vectors.Vector;

   --  uuid (or "uuid.minor") → 1-based index into Rows.
   package Uuid_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (String, Positive);

   type Outline_Type is record
      Rows    : Row_List;
      By_Uuid : Uuid_Maps.Map;
   end record;

   Outline_Error : exception;

   --  Read, parse, and number an outline file.  Raises Outline_Error on any
   --  malformed line, duplicate uuid, or section before a chapter/division.
   function Load (Path : String) return Outline_Type;

   --  Render an entry's designation ("Chapter 1", "I", "§3", a title).  The
   --  flags mirror render.py: Number_Only = 'n', Short_Form = 's'.
   function Display
     (E : Row; Number_Only : Boolean := False;
      Short_Form : Boolean := False) return String;

   --  The two number formatters, exported for the token resolver's use in
   --  number-only and list forms.
   function Roman (N : Natural) return String;
   function Letter_Num (N : Natural) return String;
   function Format_Number (Style : Number_Style; N : Natural) return String;

end Outline;
