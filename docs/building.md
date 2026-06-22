# Building

The flake exposes every artifact as a package, host tests as checks, and a dev shell per
app.

## Commands

```sh
nix build .#hello            # a host bin           -> result/bin/hello
nix build .#hello-sim        # a second bin         -> result/bin/sim
nix build .#hello-unit       # a host test          (built and run)
nix build .#blink            # STM32 firmware       -> result/bin/blink.{elf,bin,hex}
nix build .#blink-mspm0      # TI MSPM0 firmware
nix flake check              # build + run every host [[test]]
```

### Output attribute names

For a package `<pkg>`, an artifact named `<art>` is exposed as:

- `<pkg>` when `<art> == <pkg>` (the package's headline artifact), else
- `<pkg>-<art>` (e.g. `hello-sim`, `hello-unit`).

`packages` includes every `[[bin]]` plus host `[[test]]`s; `checks` is the host `[[test]]`
subset that `nix flake check` runs. A duplicate attribute name across the workspace is a
hard error (so an artifact never silently disappears).

## What a sealed build does

Each artifact is its own derivation (`mkArtifact`). The phases:

1. **configure** — `cmake -G Ninja -S cmake -B target` with `-DVIA_MANIFEST=…`,
   `-DVIA_APP_DIR="$PWD"`, the chosen `CMAKE_BUILD_TYPE`, `compile_commands.json` on, and
   (cross only) the toolchain-file vars.
2. **build** — `cmake --build target`.
3. **check** — for a host `[[test]]`, runs `./target/<name>`.
4. **install** — `cmake --install target --prefix $out`.

Firmware ELFs are not stripped or `patchelf`-ed (`dontStrip` / `dontPatchELF`), so the
cross output is left exactly as linked.

## Profiles

`profile` selects the CMake build type. Default is `release`; set `debug` on a platform or
an individual artifact:

```toml
[platform.host]
toolchain = "gcc"
profile   = "debug"     # whole platform

[[bin]]
name     = "hello"
src      = ["src/main.c"]
platform = "host"
profile  = "debug"      # just this artifact (overrides the platform)
```

| `profile` | `CMAKE_BUILD_TYPE` |
|---|---|
| `release` (default) | `Release` |
| `debug` | `Debug` |

Any other value fails fast. The active profile is also surfaced as `VIA_PROFILE` in the
generated `via_build.h`.

## Reproducibility

Builds are reproducible because resolution is fully pinned: nixpkgs by `flake.lock`, git
dependencies by [`Via.lock`](./dependencies.md#the-lockfile), and toolchains by their
package. The same inputs render the same `via_manifest.cmake` and therefore the same
artifact.
