#: lib.batteries.mermaid.shapes.box, lib.batteries.mermaid.shapes.circle, lib.batteries.mermaid.shapes.cylinder, lib.batteries.mermaid.shapes.hexagon, lib.batteries.mermaid.shapes.parallelogram, lib.batteries.mermaid.shapes.round, lib.batteries.mermaid.shapes.subroutine :: label -> string -- a node shape for flowchart
# node shapes for flowchart: a function from the quoted label to the mermaid node text
{
  box = l: "[${l}]";
  round = l: "(${l})";
  subroutine = l: "[[${l}]]";
  parallelogram = l: "[/${l}/]";
  circle = l: "((${l}))";
  hexagon = l: "{{${l}}}";
  cylinder = l: "[(${l})]";
}
