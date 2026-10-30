#: lib.batteries.addresses :: { prefix; members; } -> { value; errors; } -- one IPv4 address per member from a prefix, in member order; a repeated address or a full prefix is an error
# members are `{ name; address ? null; }`: a given address is kept, the others take the next free address of the prefix
# ("10.8.0.0/24", /16 to /24), skipping the network and broadcast ones. value: name -> address. A given address twice,
# a prefix that is no IPv4 /16 to /24 and a prefix too small for its members are error records `{ error; code; got; }`.
# shortcut: IPv4 only, add IPv6 when a kit needs it
#   addresses { prefix = "10.8.0.0/24"; members = [ { name = "lb"; } { name = "web"; address = "10.8.0.9"; } ]; }
{ prefix, members }:
let
  b = builtins;
  re = "(0|[1-9][0-9]{0,2})\\.(0|[1-9][0-9]{0,2})\\.(0|[1-9][0-9]{0,2})\\.(0|[1-9][0-9]{0,2})/(0|[1-9][0-9]?)";
  m = if b.isString prefix then b.match re prefix else null;
  n = b.map b.fromJSON (if m == null then [ ] else m);
  p = b.elemAt n;
  valid = m != null && b.all (x: x <= 255) (b.genList p 4) && p 4 >= 16 && p 4 <= 24;
  size = b.foldl' (s: _: s * 2) 1 (b.genList (i: i) (32 - p 4));
  mod = x: y: x - y * (x / y);
  net = (((p 0 * 256 + p 1) * 256 + p 2) * 256 + p 3) / size * size;
  usable = size - 2;
  dotted =
    x:
    "${toString (x / 16777216)}.${toString (mod (x / 65536) 256)}.${toString (mod (x / 256) 256)}.${toString (mod x 256)}";
  taken = a: b.any (x: x.address or null == a) members;
  skip = i: if i < usable && taken (dotted (net + 1 + i)) then skip (i + 1) else i;
  step =
    st: x:
    let
      i = skip st.next;
    in
    if x.address or null != null then
      st // { out = st.out ++ [ { inherit (x) name address; } ]; }
    else if i >= usable then
      st // { full = st.full ++ [ x.name ]; }
    else
      st
      // {
        next = i + 1;
        out = st.out ++ [
          {
            inherit (x) name;
            address = dotted (net + 1 + i);
          }
        ];
      };
  r = b.foldl' step {
    next = 0;
    out = [ ];
    full = [ ];
  } members;
  groups = b.groupBy (x: x.address) r.out;
  twice = b.filter (a: b.length groups.${a} > 1) (b.attrNames groups);
  err = code: msg: got: {
    error = "addresses: ${msg}";
    inherit code got;
  };
  when = c: e: if c then [ e ] else [ ];
in
if !valid then
  {
    value = { };
    errors = [ (err "addresses-prefix" "${toString prefix} is not an IPv4 prefix /16 to /24" prefix) ];
  }
else
  {
    value = b.listToAttrs (
      map (x: {
        inherit (x) name;
        value = x.address;
      }) r.out
    );
    errors =
      when (r.full != [ ]) (
        err "addresses-full" "prefix ${prefix} is too small for ${toString (b.length r.full)} members"
          r.full
      )
      ++ when (twice != [ ]) (err "addresses-twice" "addresses given twice" twice);
  }
