# Dependency resolution: reads the workspace shared-dep pins + the lockfile, and
# resolves each [dependencies] / [platform.*.dependencies] / [dev-dependencies]
# entry to a fetched source tree (git pinned by Via.lock, or a local path).
#
#   includes : dep-relative dirs added to the include path (-I)
#   sources  : dep-relative files or globs to compile; a "!" prefix excludes
#              (gitignore-style). Patterns reach CMake's file(GLOB) unexpanded.

{ pkgs, lib, root }:

let
  workspaceManifest =
    if root != null && builtins.pathExists (root + "/Via.toml")
    then builtins.fromTOML (builtins.readFile (root + "/Via.toml")) else { };
  workspaceDeps = workspaceManifest.workspace.dependencies or { };

  lockEntries =
    if root != null && builtins.pathExists (root + "/Via.lock")
    then (builtins.fromTOML (builtins.readFile (root + "/Via.lock"))).dependency or [ ]
    else [ ];
  lockMap = lib.listToAttrs (map (d: { name = d.name; value = d; }) lockEntries);

  resolveGit = name: spec:
    let
      central =
        if (spec.workspace or false)
        then (workspaceDeps.${name} or
          (throw "via: dependency '${name}' is marked workspace=true but has no [workspace.dependencies.${name}] in the root Via.toml"))
        else { };
      gitSpec = central // spec;
      locked = lockMap.${name} or
        (throw "via: git dependency '${name}' has no Via.lock entry — regenerate Via.lock");

      # The lock is the source of reproducibility, but the URL/tag it pins must
      # still agree with what the manifest asks for; otherwise a stale lock would
      # fetch `locked.rev` from the wrong place (or a different tag) silently.
      _urlOk = lib.throwIf
        ((locked.url or null) != null && locked.url != gitSpec.git)
        "via: Via.lock url for '${name}' (${locked.url}) does not match manifest (${gitSpec.git}) — regenerate Via.lock"
        null;
      _tagOk = lib.throwIf
        (gitSpec ? tag && locked ? tag && locked.tag != gitSpec.tag)
        "via: Via.lock tag for '${name}' (${locked.tag}) does not match manifest (${gitSpec.tag}) — regenerate Via.lock"
        null;

      tag = lib.seq _urlOk (lib.seq _tagOk (locked.tag or (gitSpec.tag or null)));
    in
    builtins.fetchGit ({
      url = gitSpec.git;
      rev = locked.rev;
    } // (if tag != null then { ref = "refs/tags/${tag}"; } else { allRefs = true; })
    // (if (spec.submodules or false) then { submodules = true; } else { }));

  resolveDep = appDir: name: spec:
    let
      root' =
        if spec ? path then appDir + ("/" + spec.path)
        else resolveGit name spec;
    in
    let isVia = builtins.pathExists (root' + "/Via.toml"); in
    {
      inherit name isVia;
      root = root';
      includes = spec.includes or [ ];
      sources = spec.sources or [ ];
      # For Via lib deps, surface the lib's [lib] portable flag so the artifact
      # layer can refuse a non-portable lib in a firmware (cross) build. null for
      # raw (non-Via) deps, where the notion does not apply.
      portable =
        if isVia
        then (builtins.fromTOML (builtins.readFile (root' + "/Via.toml"))).lib.portable or false
        else null;
    };
in
{
  # All deps in scope for an artifact: [dependencies] + platform deps + (tests) dev-deps.
  resolveDeps = { appDir, m, platform, kind }:
    let
      base = m.dependencies or { };
      plat = platform.dependencies or { };
      dev = if kind == "test" then (m."dev-dependencies" or { }) else { };
      depSet = base // plat // dev;
    in
    lib.mapAttrsToList (resolveDep appDir) depSet;
}
