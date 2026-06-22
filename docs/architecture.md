# Architecture

Via has two layers with one explicit hand-off:

```
Via.toml ──▶  Nix engine (nix/)  ──▶  via_manifest.cmake  ──▶  CMake driver (cmake/)  ──▶  artifact
            resolve + pin + select         set() calls           build by convention      (.elf/bin/test)
```

Nix owns **resolution** (what to build and with what). CMake owns **construction** (how to
turn a fixed set of sources/flags into a target). TOML is parsed exactly once, in Nix.

## The Nix engine

`flake.nix` builds the engine via `mkVia` and points it at the example workspace (a
downstream consumer does the same against their own `root` — see
[Consuming Via externally](./consuming.md)):

```nix
example = mkVia { root = ./examples; };       # mkVia -> import nix/via.nix
apps = example.discoverApps ./examples/apps;
{
  packages  = example.packagesFor apps;   # every [[bin]] + host [[test]]
  checks    = example.checksFor   apps;   # host [[test]] only
  devShells = … // example.devShellsFor apps;
}
```

`nix/via.nix` is thin wiring over `nix/lib/*`:

| Module | Responsibility |
|---|---|
| `lib/manifest.nix` | Render resolved values as `set()` calls (`via_manifest.cmake`). |
| `lib/deps.nix` | Resolve `[dependencies]` / platform deps / dev-deps to fetched trees. |
| `lib/toolchains.nix` | Discover & look up `nix/toolchains/<id>.nix` records. |
| `lib/artifact.nix` | Compute one artifact's inputs (`artifactInfo`) and seal it (`mkArtifact`). |
| `lib/devshell.nix` | Build the per-app dev shell that reproduces the sealed build by hand. |

### Discovery → artifacts

`discoverApps <dir>` finds every subdirectory containing a `Via.toml`. For each app,
`artifactsOf` produces one entry per `[[bin]]` and per **host** `[[test]]` (firmware tests
are excluded — firmware logic is tested through portable libs on the host). Each entry's
attribute name is `<pkg>` if the artifact matches the package name, else `<pkg>-<artifact>`
(so `hello` yields `hello`, `hello-sim`, `hello-unit`). Duplicate attribute names across
the workspace fail loudly rather than silently shadowing.

### Resolving one artifact (`artifactInfo`)

`lib/artifact.nix` computes, for a single artifact:

- **Language standards** from `[package.language]` (`c11` → `C_STANDARD 11`).
- **defines / cflags / ldflags** = platform values **++** artifact values.
- **Dependencies** via `resolveDeps` (see [Dependencies](./dependencies.md)), split into
  Via-package libs (built from their `src/`) and raw deps (compiled `sources` + `includes`).
- **Sources** — the artifact's own `src`, plus each raw dep's `sources`, plus the
  platform's `sources`, all as absolute file/glob patterns (`!` = exclude).
- **Profile** → `CMAKE_BUILD_TYPE` (`release`→`Release`, `debug`→`Debug`).
- **Toolchain** via `lookupToolchain`, including any cross fields and bare-metal ldflags.

It renders all of this into `via_manifest.cmake` and assembles the exact `cmake` configure
command. That command is shared verbatim with the [dev shell](./devshell.md), so the manual
and sealed builds are byte-for-byte identical.

### Sealing (`mkArtifact`)

`mkArtifact` wraps the configure/build/check/install in a `stdenv.mkDerivation`:

- `dontUseCmakeConfigure = true` — Via drives CMake itself (custom `-S cmakeDir`).
- Firmware ELFs set `dontStrip` / `dontPatchELF` so host tooling never rewrites them.
- `doCheck` runs a host `[[test]]` binary in `checkPhase`.
- `installPhase` runs `cmake --install` into `$out` (`bin/` for executables; `.bin`/`.hex`
  for firmware).

## The CMake driver

`cmake/CMakeLists.txt` is the source root for **every** Via build. It is not edited by app
authors. It requires two cache vars from the engine:

- `-DVIA_MANIFEST=<via_manifest.cmake>` — the rendered `set()` calls.
- `-DVIA_APP_DIR=<app source dir>` — for the conventional `inc/` and `tests/` lookups.

It `include()`s the manifest, declares `project(... C CXX ASM)`, and calls
`via_build_artifact()` from `ViaDriver.cmake`, which:

1. Resolves `VIA_SOURCES` globs (honoring `!` excludes; auto-globs `tests/` for tests).
2. Creates the executable and generates `via_build.h` (package/version/artifact/profile/
   features) onto the include path.
3. Applies dependency libs/includes, language standards, and the merged defines/cflags/
   ldflags.
4. For firmware, applies the bare-metal link policy and the image/size post-build.

`cmake/ViaToolchain.cmake` is **compiler selection only** — it sets the compiler binaries
(and, for cross builds, `CMAKE_SYSTEM_NAME/PROCESSOR` and the freestanding compiler-check
settings). It names no arch flags, no chip define, and no linker script.

## Invariants worth preserving

- TOML is parsed only in Nix; CMake consumes flat `VIA_*` lists.
- The toolchain file stays compiler-only; arch/libc specifics live in the manifest or the
  toolchain record, never in the driver.
- The dev shell and the sealed build issue the *identical* `cmake` invocation.
