{
  description = "Via — reusable C/C++ build framework (Nix + CMake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # The reusable Via engine, defined once: a consumer points it at their
        # own repo root and gets the discoverApps/packagesFor/checksFor/
        # devShellsFor API. We dogfood it below to build this repo's examples.
        mkVia = { root, cmakeDir ? "${self}/cmake", toolchainDirs ? [ ], toolchains ? { } }:
          import "${self}/nix/via.nix" { inherit pkgs cmakeDir root toolchainDirs toolchains; };

        # The bundled examples are an ordinary Via workspace under ./examples,
        # built with the framework's own engine — exactly as a consumer would.
        example = mkVia { root = ./examples; };
        exampleApps = example.apps;

        # The Via handbook (mdBook). `nix build .#docs` -> result/ (static HTML site).
        docs = pkgs.stdenv.mkDerivation {
          pname = "via-docs";
          version = "0.1.0";
          src = ./docs;
          nativeBuildInputs = [ pkgs.mdbook ];
          buildPhase = ''
            runHook preBuild
            mdbook build --dest-dir "$out"
            runHook postBuild
          '';
          dontInstall = true;
          meta.description = "Via documentation handbook (mdBook)";
        };

        # `nix run .#docs` — generate the handbook into ./docs/book (a normal,
        # in-tree path your browser can open directly). Unlike `nix build`, this
        # writes into the working tree instead of a /nix/store symlink, so
        # sandboxed (Snap/Flatpak) browsers can read docs/book/index.html.
        docsGen = pkgs.writeShellScriptBin "via-docs" ''
          set -euo pipefail
          dir="''${1:-$PWD/docs}"
          ${pkgs.mdbook}/bin/mdbook build "$dir"
          echo "via: docs generated at $dir/book — open $dir/book/index.html"
        '';
      in
      {
        # Reusable engine for downstream flakes. A consumer points it at their
        # own repo root (workspace manifest + Via.lock) and gets the same
        # discoverApps/packagesFor/checksFor/devShellsFor API this flake uses.
        # cmakeDir defaults to Via's own generic driver.
        #
        # Consumer toolchains: drop a `toolchains/<id>.nix` at the repo root (auto-
        # discovered), pass extra scan dirs via toolchainDirs, or inline records via
        # toolchains = { <id> = <record-or-{pkgs}:record>; }. Consumer entries
        # override built-ins of the same id.
        lib.mkVia = mkVia;

        # Example artifacts (blink, hello, hello-sim, hello-unit, blink-mspm0) +
        # the docs site. Build any with `nix build .#<name>`.
        packages = example.packagesFor exampleApps // { inherit docs; };
        checks = example.checksFor exampleApps;

        apps.docs = flake-utils.lib.mkApp { drv = docsGen; };

        devShells = {
          default = pkgs.mkShell {
            name = "via";
            packages = [ pkgs.cmake pkgs.ninja pkgs.gcc pkgs.clang-tools pkgs.git ];
          };
        } // example.devShellsFor exampleApps;
      });
}
