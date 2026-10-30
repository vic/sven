# a one-line comment in the syntax of a file's format (by extension), for a generated-file notice. Formats with no
# comments (json) get "". A new line ends it.
#   files.comment "README.md" "Generated. Edit modules/docs, then nix run .#write-files."
path: text:
let
  b = builtins;
  ext =
    let
      m = b.match ".*\\.([^./]+)" path;
    in
    if m == null then "" else b.head m;
  hash = [
    "nix"
    "sh"
    "yml"
    "yaml"
    "toml"
    "py"
    "bash"
    "fish"
    "conf"
    ""
  ];
  slashes = [
    "js"
    "ts"
    "rs"
    "go"
    "c"
    "h"
    "kdl"
  ];
in
if b.elem ext hash then
  "# ${text}\n"
else if
  b.elem ext [
    "md"
    "html"
    "mdx"
    "xml"
  ]
then
  "<!-- ${text} -->\n"
else if b.elem ext slashes then
  "// ${text}\n"
else if ext == "lua" || ext == "sql" then
  "-- ${text}\n"
else
  ""
