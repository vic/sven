# Mermaid flowcharts: `flowchart` renders a view; the others make views of yen data (graph, kinds, schema, aspects).
{
  flowchart = import ./flowchart.nix;
  shapes = import ./shapes.nix;
  scopes = import ./scopes.nix;
  routes = import ./routes.nix;
  routing = import ./routing.nix;
  kinds = import ./kinds.nix;
  sinks = import ./sinks.nix;
  gates = import ./gates.nix;
}
