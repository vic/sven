# Diagrams of the fleet: every view is data ({ nodes; edges; }), flowchart renders it.
{ yen, ... }:
let
  inherit (yen.lib.batteries) mermaid;
  draw = direction: view: mermaid.flowchart { inherit direction; } view;
in
{
  yen.aspects.diagrams = {
    at = yen.fleet.main;
    out.diagrams = {
      # each environment as a subgraph around its hosts
      scopes = draw "TD" (
        mermaid.scopes {
          keep = s: !(yen.lib.holds yen.kinds.fleet s);
          label = s: s.name;
          group = s: if yen.lib.holds yen.kinds.host s then dirOf s.id else null; # hosts inside their environment (the parent id)
        } yen.lib.graph
      );
      kinds = draw "LR" (mermaid.kinds yen.kinds);
      gates = draw "LR" (mermaid.gates yen.aspects);
      routes = draw "BT" (mermaid.routes yen.lib.graph);
      # kind level: kind -> sink -> kind, counted; sinks as rounded nodes, outputs as cylinders
      routing = mermaid.flowchart {
        shapes = with mermaid.shapes; {
          sink = round;
        };
      } (mermaid.routing yen.lib.graph);
      sinks = mermaid.flowchart {
        shapes = with mermaid.shapes; {
          sink = round;
          output = cylinder;
        };
      } (mermaid.sinks yen.lib);
    };
  };
}
