# The Via engine — thin wiring over nix/*.
#
# Reads Via.toml manifests and turns each artifact into a sealed, per-app
# derivation built with CMake/Ninja. Implements the HOST path (bins + tests) and
# the FIRMWARE path (cross toolchain + app-declared bare-metal build) end-to-end.
#
#   import ./nix/via.nix { inherit pkgs; cmakeDir = ./cmake; root = <repo>; }
#     .apps                    -> [ { name; dir; manifest; } ... ]  (from [workspace] members)
#     .discoverApps <appsDir>  -> [ { name; dir; manifest; } ... ]  (explicit-dir scan)
#     .packagesFor apps      -> { <attr> = <derivation>; ... }   (bins + tests)
#     .checksFor   apps      -> { <attr> = <derivation>; ... }   (host tests)
#     .devShellsFor apps     -> { <app> = <devShell>; ... }

{ pkgs, cmakeDir, root ? null, toolchainDirs ? [ ], toolchains ? { } }:

let
  lib = pkgs.lib;

  # A `<root>/toolchains/` dir is auto-discovered (zero-config for consumers),
  # alongside any explicit toolchainDirs and inline `toolchains` records.
  autoToolchainDirs =
    lib.optional (root != null && builtins.pathExists (root + "/toolchains")) (root + "/toolchains");
  toolchainsLib = import ./toolchains.nix {
    inherit pkgs lib;
    extraDirs = autoToolchainDirs ++ toolchainDirs;
    extra = toolchains;
  };

  deps = import ./deps.nix { inherit pkgs lib root; };
  manifest = import ./manifest.nix { inherit pkgs lib; };
  artifact = import ./artifact.nix {
    inherit pkgs lib cmakeDir;
    inherit (deps) resolveDeps;
    inherit (manifest) renderManifest;
    lookupToolchain = toolchainsLib.lookup;
  };
  devshell = import ./devshell.nix {
    inherit pkgs lib;
    inherit (artifact) artifactInfo;
  };

  readManifest = dir: builtins.fromTOML (builtins.readFile (dir + "/Via.toml"));

  # Expand a `[workspace] members` list into concrete member dirs (repo-relative).
  # Supports a trailing `/*` glob (one level) and exact paths.
  expandMembers = patterns:
    lib.concatMap
      (pat:
        if lib.hasSuffix "/*" pat then
          let base = lib.removeSuffix "/*" pat; dir = root + "/${base}"; in
          if builtins.pathExists dir then
            let e = builtins.readDir dir; in
            map (n: "${base}/${n}")
              (lib.filter (n: e.${n} == "directory") (builtins.attrNames e))
          else [ ]
        else [ pat ])
      patterns;

  # Workspace packages, discovered from the root manifest's `[workspace] members`
  # (the primary entry point; `discoverApps` below remains for explicit dirs).
  # Only member dirs whose Via.toml carries a [package] are kept, so the
  # workspace root and any non-package dirs are skipped.
  rootManifest =
    if root != null && builtins.pathExists (root + "/Via.toml")
    then readManifest root else { };
  apps = map
    (d: { name = baseNameOf d; dir = root + "/${d}"; manifest = readManifest (root + "/${d}"); })
    (lib.filter
      (d: builtins.pathExists (root + "/${d}/Via.toml") && readManifest (root + "/${d}") ? package)
      (expandMembers (rootManifest.workspace.members or [ ])));

  # Tests are host-only in this design (firmware logic is tested via portable libs).
  isHostArt = m: art: (m.platform.${art.platform}.kind or "host") != "firmware";

  # An app contributes a dev shell only if it has something buildable; a pure
  # library member (no [[bin]]/[[test]]) is skipped rather than throwing.
  hasBuildable = app:
    (app.manifest.bin or [ ]) != [ ]
    || lib.filter (isHostArt app.manifest) (app.manifest.test or [ ]) != [ ];

  artifactAttr = pkgName: artName:
    if artName == pkgName then pkgName else "${pkgName}-${artName}";

  artifactsOf = app:
    let
      m = app.manifest;
      pkgName = m.package.name;
      mk = kind: art: {
        attr = artifactAttr pkgName art.name;
        inherit kind;
        drv = artifact.mkArtifact { inherit app art kind; };
      };
      bins = map (mk "bin") (m.bin or [ ]);
      tests = map (mk "test") (lib.filter (isHostArt m) (m.test or [ ]));
    in
    bins ++ tests;

  allArtifacts = apps: lib.concatMap artifactsOf apps;

  # listToAttrs silently keeps the last on a name clash, which would make an
  # artifact vanish from packages/checks. Fail loudly instead.
  assertUnique = arts:
    let
      names = map (a: a.attr) arts;
      dups = lib.unique (lib.filter (n: lib.count (x: x == n) names > 1) names);
    in
    if dups == [ ]
    then arts
    else throw "via: duplicate artifact name(s) across the workspace: ${lib.concatStringsSep ", " dups}";

  toAttrs = arts:
    lib.listToAttrs (map (a: { name = a.attr; value = a.drv; }) (assertUnique arts));
in
{
  # Members-driven workspace packages (the primary discovery path).
  inherit apps;

  discoverApps = appsDir:
    let
      entries = builtins.readDir appsDir;
      isApp = n: entries.${n} == "directory"
        && builtins.pathExists (appsDir + "/${n}/Via.toml");
      names = lib.filter isApp (builtins.attrNames entries);
    in
    map
      (n: {
        name = n;
        dir = appsDir + "/${n}";
        manifest = readManifest (appsDir + "/${n}");
      })
      names;

  packagesFor = apps: toAttrs (allArtifacts apps);
  checksFor = apps: toAttrs (lib.filter (a: a.kind == "test") (allArtifacts apps));
  devShellsFor = apps:
    lib.listToAttrs (map (app: { name = app.name; value = devshell.mkDevShell app; })
      (lib.filter hasBuildable apps));
}
