{
  title = "Data is queried, not merged";
  description = "Each read is a query on the files that answer it. Two answers for one leaf are an error, not an override.";
  section = "concepts";
  order = 4;

  body =
    {
      docs,
      r,
      variant,
      ...
    }:
    [
      ''
        The NixOS module system merges every definition into one value, then reads it.
        yen does not merge. A read of a path is one query on the files that answer that path.

        Here two feature files declare settings at two paths of one field. Neither file knows the other:
      ''
      (docs.tabs [
        {
          label = "features/zfs.nix";
          body = docs.file "modules/features/zfs.nix";
        }
        {
          label = "features/k3s.nix";
          body = docs.file "modules/features/k3s.nix";
        }
      ])
      ''
        A read of `host.settings.k3s.role` looks at the instance, then at the type default. It never reads `zfs.nix`.
        `r.declaredIn` answers which files declare a path:
      ''
      (docs.value (
        map baseNameOf (
          r.declaredIn [
            "kinds"
            "host"
            "fields"
            "settings"
          ]
        )
      ))
      ''
        ## Cascades

        A cascade is a list in your order. `yen.lib.cascade path xs` gives the first non-null value along `xs`.
        `nas` sets its own `arcMax`; `node` falls back to its environment:
      ''
      (docs.file "modules/hosts.nix")
      (docs.fileWith "{10}" "modules/report.nix")
      (docs.value r.flake.report)
      ''
        ## Helpers

        `yen.helpers` holds shared values and functions. It is an open namespace: any file declares a key, and any
        module reads it from its `yen` arg. Above, `report.nix` reads `yen.helpers.k3sRole`:
      ''
      (docs.file "modules/helpers.nix")
      ''
        A fleet chooses its own helpers, so yen does not document them and `schema` does not list them.
        A helper is a declaration like any other: one answer per key. A second file that gives the same key is
        two answers, because two functions are never equal:
      ''
      (docs.file "variants/helper-twice.nix")
      (docs.value (map (e: { inherit (e) code path; }) (variant "variants/helper-twice.nix").errors))
      ''
        ## Two answers are an error

        One leaf with two different values is not an override. It is an error record, and you keep one answer:
      ''
      (docs.file "variants/override.nix")
      (docs.value (variant "variants/override.nix").errors)
      (docs.note "Same value, no error" ''
        Two files that give the same value for one leaf are fine. Only a conflict is an error.
        Lists and attrsets for aspect keys are elements, not leaves: see [Aspects](/concepts/aspects/).
      '')
    ];

  checks =
    { r, variant, ... }:
    {
      cascade =
        r.flake.report == {
          nas = {
            arcMax = 32;
            k3s = "agent";
          };
          node = {
            arcMax = 8;
            k3s = "server";
          };
        };
      declared =
        map baseNameOf (
          r.declaredIn [
            "kinds"
            "host"
            "fields"
            "settings"
          ]
        ) == [
          "k3s.nix"
          "zfs.nix"
        ];
      two-answers = map (e: e.code) (variant "variants/override.nix").errors == [ "two-answers" ];
      helper-twice =
        map (e: { inherit (e) code path; }) (variant "variants/helper-twice.nix").errors == [
          {
            code = "two-answers";
            path = [
              "helpers"
              "k3sRole"
            ];
          }
        ];
    };
}
