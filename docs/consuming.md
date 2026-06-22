# Consuming Via externally

Via is a **reusable** framework: another repository can add Via as a flake input and build
its own `apps/` with the same engine, instead of vendoring `nix/` and `cmake/`.

## The reusable output

For each system, Via exposes:

```nix
via.lib.${system}.mkVia { root, cmakeDir ? "<via>/cmake" }
```

`mkVia` returns the engine bound to *your* repo, with the same API the Via repo uses
itself:

```nix
v = via.lib.${system}.mkVia { root = ./.; };
v.discoverApps  ./apps   # -> [ { name; dir; manifest; } … ]
v.packagesFor   apps     # -> { <attr> = <derivation>; … }
v.checksFor     apps     # -> { <attr> = <derivation>; … }
v.devShellsFor  apps     # -> { <app> = <devShell>; … }
```

- `root` — your repo root, where your workspace `Via.toml` and `Via.lock` live (used to
  resolve [dependencies](./dependencies.md) and pins).
- `cmakeDir` — defaults to Via's own generic [driver](./architecture.md#the-cmake-driver);
  override only if you ship a customized driver.

## A downstream flake

```nix
{
  inputs = {
    via.url = "github:you/via";
    # Build with the exact nixpkgs Via pins (recommended for reproducibility):
    nixpkgs.follows = "via/nixpkgs";
    flake-utils.follows = "via/flake-utils";
  };

  outputs = { self, via, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        v = via.lib.${system}.mkVia { root = ./.; };
        apps = v.discoverApps ./apps;
      in {
        packages  = v.packagesFor apps;
        checks    = v.checksFor   apps;
        devShells = v.devShellsFor apps;
      });
}
```

That is the whole integration. `nix build .#<app>`, `nix flake check`, and
`nix develop .#<app>` then behave exactly as in the [Building](./building.md) and
[Dev shells](./devshell.md) chapters.

## What your repo must provide

```
Via.toml            workspace root: [workspace] members + (optional) shared dep pins
Via.lock            committed git pins for your dependencies  (see Dependencies)
apps/<name>/        your applications (Via.toml + src/, …)
libs/<name>/        your internal libraries (optional)
```

You do **not** copy Via's `nix/` or `cmake/` — they come from the input.

## Toolchains

`mkVia` ships Via's bundled [toolchain records](./toolchains.md) (`gcc`, `clang`,
`arm-gnu`, …), referenced by id from a platform:

```toml
[platform.fw]
toolchain = "arm-gnu"
```

You can also **add your own** without forking. The zero-config way is a `toolchains/`
directory at your repo root — auto-discovered just like `apps/`:

```
your-repo/
  Via.toml
  toolchains/
    riscv-gnu.nix     # -> toolchain = "riscv-gnu"
  apps/…
```

For toolchains kept elsewhere, or records that reference your own flake inputs, pass them
to `mkVia`:

```nix
via.lib.${system}.mkVia {
  root          = ./.;
  toolchainDirs = [ ./vendor/toolchains ];                 # extra scan dirs
  toolchains    = { riscv-gnu = { /* record */ }; };       # inline records
}
```

Consumer entries override a built-in of the same id, so you can also customize a bundled
toolchain. See [Toolchains → From a downstream consumer](./toolchains.md#from-a-downstream-consumer)
for the full record shape and rules.

## Pinning & updates

Your build is reproducible from two lockfiles: your `flake.lock` (which pins the Via input,
and through `follows` the nixpkgs Via was tested against) and your `Via.lock` (which pins
your git dependencies). Bump Via with `nix flake update via`; refresh dependency pins with
`via update`.
