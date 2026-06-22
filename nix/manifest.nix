# Renders resolved manifest values as a CMake include of set() calls. CMake never
# parses TOML — Nix is the single resolver; this is the hand-off.

{ pkgs, lib }:

{
  renderManifest =
    { app, version, artifact, kind, cStd, cxxStd, defines, cflags
    , ldflags, features, profile, platformKind, linkerScript
    , depLibs, extraIncludes, sources, baremetalLdflags
    }:
    let
      # Escape CMake-significant characters before quoting, so a value containing
      # ';' (list separator), '\', '"', or '$' (variable ref) survives verbatim.
      esc = lib.escape [ "\\" "\"" "$" ";" ];
      q = s: ''"${esc s}"'';
      lst = xs: lib.concatMapStringsSep " " q xs;
    in ''
      set(VIA_APP ${q app})
      set(VIA_VERSION ${q version})
      set(VIA_ARTIFACT ${q artifact})
      set(VIA_KIND ${q kind})
      set(VIA_PROFILE ${q profile})
      set(VIA_PLATFORM_KIND ${q platformKind})
      set(VIA_LINKER_SCRIPT ${q linkerScript})
      set(VIA_C_STD ${q cStd})
      set(VIA_CXX_STD ${q cxxStd})
      set(VIA_DEFINES ${lst defines})
      set(VIA_CFLAGS ${lst cflags})
      set(VIA_LDFLAGS ${lst ldflags})
      set(VIA_BAREMETAL_LDFLAGS ${lst baremetalLdflags})
      set(VIA_FEATURES ${lst features})
      set(VIA_DEP_LIBS ${lst depLibs})
      set(VIA_EXTRA_INCLUDES ${lst extraIncludes})
      set(VIA_SOURCES ${lst sources})
    '';
}
