--  tokens.ads — the {{token}} resolver and TOC generator, the second half of
--  the numbering engine.  Ports render.py's resolve_token / _resolve_stack /
--  _resolve_chapter_list / generate_toc so the substituted prose and the
--  table of contents match render.py byte for byte.

with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Outline;

package Tokens is

   use Ada.Strings.Unbounded;

   Tokens_Error : exception;

   package Str_Vectors is new Ada.Containers.Vectors (Positive, Unbounded_String);
   package Str_Sets is new Ada.Containers.Indefinite_Ordered_Sets (String);

   type Resolver is record
      O          : Outline.Outline_Type;
      Anchor_Ids : Str_Sets.Set;   -- {{anchor:ID}} ids registered by the pre-pass
   end record;

   --  Resolve the body of a {{…}} token (the text between the braces, raw).
   --  Raises Tokens_Error on any unresolvable or mistyped token.
   function Resolve (R : Resolver; Token_Body : String) return String;

   --  Build the Table of Contents from outline row order, in the markdown form
   --  render.py emits (parts bold, chapters/appendix/division as list items).
   function Generate_Toc (R : Resolver) return String;

   --  render.py's join_and: "a", "a and b", "a, b, and c".
   function Join_And (Items : Str_Vectors.Vector) return String;

end Tokens;
