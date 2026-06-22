# Per-artifact build: computes everything needed to configure/build one [[bin]]
# or [[test]] (artifactInfo), and wraps it in a sealed CMake/Ninja derivation
# (mkArtifact). artifactInfo is shared with the dev shell so the manual and
# sealed builds issue the IDENTICAL cmake invocation.

{ pkgs, lib, cmakeDir, resolveDeps, lookupToolchain, renderManifest }:

let
  # Prefix a source/glob pattern with its resolving root, preserving a leading
  # "!" (gitignore-style exclude). CMake's file(GLOB) expands it.
  atRoot = root: pat:
    if lib.hasPrefix "!" pat
    then "!${root}/${lib.removePrefix "!" pat}"
    else "${root}/${pat}";

  artifactInfo = { app, art, kind }:
    let
      m = app.manifest;
      pkgName = m.package.name;
      version = m.package.version or "0.0.0";
      lang = m.package.language or { };
      cStd = if lang ? c then lib.removePrefix "c" lang.c else "";
      cxxStd = if lang ? cxx then lib.removePrefix "c++" lang.cxx else "";

      platform = m.platform.${art.platform};
      platformKind = platform.kind or "host";
      isFirmware = platformKind == "firmware";

      defines = (platform.defines or [ ]) ++ (art.defines or [ ]);
      cflags = (platform.cflags or [ ]) ++ (art.cflags or [ ]);
      ldflags = (platform.ldflags or [ ]) ++ (art.ldflags or [ ]);
      features = art.features or [ ];

      # Build profile: artifact overrides platform, default release. Mapped to
      # CMAKE_BUILD_TYPE below; also surfaced in via_build.h via VIA_PROFILE.
      profile = art.profile or platform.profile or "release";
      buildType = {
        release = "Release";
        debug = "Debug";
      }.${profile} or (throw "via: unknown profile '${profile}' (expected release|debug)");

      deps = resolveDeps { appDir = app.dir; inherit m platform kind; };
      depRootByName = lib.listToAttrs (map (d: { name = d.name; value = d.root; }) deps);

      # A Via lib is rebuilt from source inside each consumer's toolchain, so a
      # firmware (cross) artifact may only pull libs that opted into portability.
      viaDeps = lib.filter (d: d.isVia) deps;
      nonPortable = lib.filter (d: !(d.portable or false)) viaDeps;
      _portableOk = lib.throwIf (isFirmware && nonPortable != [ ])
        "via: firmware artifact '${pkgName}:${art.name}' depends on non-portable lib(s): ${lib.concatMapStringsSep ", " (d: d.name) nonPortable}. Mark the lib [lib] portable = true to allow cross-toolchain reuse."
        null;

      depLibs = lib.seq _portableOk (map (d: "${d.root}") viaDeps);
      extraIncludes = lib.concatMap (d: map (i: "${d.root}/${i}") d.includes)
        (lib.filter (d: !d.isVia) deps);

      # A [[bin]] must spell out its own sources — no directory is assumed.
      selfSrc = lib.throwIf (kind == "bin" && (art.src or [ ]) == [ ])
        "via: [[bin]] '${art.name}' (in ${pkgName}) must declare a non-empty src = [ ... ]"
        (map (atRoot app.dir) (art.src or [ ]));

      # Compiled sources, all as absolute file/glob patterns ("!"-aware):
      #   - the artifact's own `src` (app-relative)
      #   - each non-Via dep's `sources` (dep-relative)
      #   - the platform's `sources` (app-relative; e.g. a committed startup)
      sources =
        selfSrc
        ++ lib.concatMap (d: map (atRoot "${d.root}") d.sources)
          (lib.filter (d: !d.isVia) deps)
        ++ map (atRoot app.dir) (platform.sources or [ ]);

      # startup / linker-script: a string is app-relative; a { dep, path } table
      # resolves inside that dependency's fetched tree (the dep-relative ref).
      resolveRef = ref:
        if ref == null then ""
        else if builtins.isString ref then "${app.dir}/${ref}"
        else "${depRootByName.${ref.dep}}/${ref.path}";

      manifestFile = pkgs.writeText "via_manifest.cmake" (renderManifest {
        app = pkgName;
        inherit version cStd cxxStd defines cflags ldflags features profile kind;
        inherit depLibs extraIncludes sources platformKind baremetalLdflags;
        artifact = art.name;
        linkerScript = resolveRef (platform."linker-script" or null);
      });

      tc = lookupToolchain (platform.toolchain or "gcc");
      baremetalLdflags = tc.baremetalLdflags or [ ];

      crossArgs = lib.optionalString tc.cross ''
        -DCMAKE_TOOLCHAIN_FILE=${cmakeDir}/ViaToolchain.cmake \
        -DVIA_SYSTEM_NAME=${tc.systemName} \
        -DVIA_SYSTEM_PROCESSOR=${tc.systemProcessor} \
        -DVIA_CC=${tc.cc} -DVIA_CXX=${tc.cxx} -DVIA_ASM=${tc.asm} \
        -DVIA_OBJCOPY=${tc.objcopy} -DVIA_SIZE=${tc.size} \
      '';

      configureCmd = buildDir: ''
        cmake -G Ninja -S ${cmakeDir} -B ${buildDir} \
          -DCMAKE_BUILD_TYPE=${buildType} \
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
          ${crossArgs}-DVIA_MANIFEST=${manifestFile} \
          -DVIA_APP_DIR="$PWD"
      '';
    in
    {
      inherit pkgName version isFirmware kind configureCmd;
      toolInputs = [ tc.pkg ];
      ccPath = tc.cc;
      artName = art.name;
      description = m.package.description or "Via ${kind} ${pkgName}:${art.name}";
    };

  mkArtifact = args:
    let info = artifactInfo args; in
    pkgs.stdenv.mkDerivation {
      pname = "${info.pkgName}-${info.artName}";
      version = info.version;
      src = args.app.dir;

      nativeBuildInputs = [ pkgs.cmake pkgs.ninja ] ++ info.toolInputs;
      dontUseCmakeConfigure = true;

      # A bare-metal cross ELF must not be touched by host strip/patchelf.
      dontStrip = info.isFirmware;
      dontPatchELF = info.isFirmware;

      configurePhase = ''
        runHook preConfigure
        ${info.configureCmd "target"}
        runHook postConfigure
      '';

      buildPhase = ''
        runHook preBuild
        cmake --build target
        runHook postBuild
      '';

      doCheck = info.kind == "test" && !info.isFirmware;
      checkPhase = ''
        runHook preCheck
        echo "via: running test ${info.artName}"
        "./target/${info.artName}"
        runHook postCheck
      '';

      installPhase = ''
        runHook preInstall
        cmake --install target --prefix "$out"
        runHook postInstall
      '';

      meta.description = info.description;
    };
in
{
  inherit artifactInfo mkArtifact;
}
