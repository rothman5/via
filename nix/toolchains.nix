# Toolchain discovery + lookup. Every toolchain — host or cross — is the uniform
# record, looked up by the platform's `toolchain = "<id>"` (an optional "@version"
# suffix is validated against the record). Unknown id fails fast.
#
# Records come from three sources, later overriding earlier on an id clash:
#   1. Via's built-in nix/toolchains/<id>.nix
#   2. extraDirs — additional <id>.nix directories (e.g. a consumer's repo)
#   3. extra — inline id -> record (or `{ pkgs }: record`) passed by a consumer
# Sources 2 and 3 are how a downstream `mkVia` consumer adds toolchains.

{ pkgs, lib, extraDirs ? [ ], extra ? { } }:

let
  # A toolchain may arrive as a `{ pkgs }: record` function (a file or an inline
  # function) or as an already-built record; normalize both to a record.
  norm = v: if lib.isFunction v then v { inherit pkgs; } else v;

  fromDir = dir:
    let
      ids = map (lib.removeSuffix ".nix")
        (lib.filter (n: lib.hasSuffix ".nix" n) (builtins.attrNames (builtins.readDir dir)));
    in
    lib.listToAttrs
      (map (id: { name = id; value = import (dir + "/${id}.nix") { inherit pkgs; }; }) ids);

  dirs = [ ./toolchains ] ++ lib.filter builtins.pathExists extraDirs;
  byId = (lib.foldl' (acc: d: acc // fromDir d) { } dirs)
    // lib.mapAttrs (_: norm) extra;
in
{
  # "arm-gnu" or "arm-gnu@13.2" -> the record from nix/toolchains/arm-gnu.nix.
  # A requested "@version" is validated against the record's `version` field
  # (rather than silently ignored): a mismatch or missing version fails fast.
  lookup = id:
    let
      parts = lib.splitString "@" id;
      base = lib.head parts;
      ver = if lib.length parts > 1 then lib.last parts else null;
      record = byId.${base} or
        (throw "via: unknown toolchain '${base}' — no built-in, ./toolchains/${base}.nix, or mkVia toolchainDirs/toolchains entry");
    in
    if ver != null && (record.version or null) != ver
    then throw "via: toolchain '${base}' provides version '${record.version or "(none)"}', not '${ver}'"
    else record;
}
