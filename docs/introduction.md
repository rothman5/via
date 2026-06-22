# Introduction

**Via** is a reusable C/C++ build framework for **host and embedded** development,
delivered as a Nix flake. Each application is configured by a single, Cargo-style
[`Via.toml`](./manifest.md) and built with CMake/Ninja underneath — usually with **no
hand-written `CMakeLists.txt`**.

```sh
nix build .#hello          # host application
nix build .#blink          # STM32 firmware (.elf/.bin/.hex)
nix build .#blink-mspm0    # TI MSPM0 firmware
nix flake check            # build + run host unit tests
nix develop .#hello        # per-app dev shell (cmake/ninja/clangd/gdb)
```

## The core idea

Via splits the build into two halves with a single, explicit hand-off between them:

1. **Nix resolves.** It reads every `Via.toml`, fetches and pins dependencies, selects
   the toolchain, and computes the exact set of sources, includes, defines, and flags for
   one artifact. It writes them out as a flat list of CMake `set()` calls
   (`via_manifest.cmake`).
2. **CMake builds.** A single generic driver consumes those `VIA_*` variables and produces
   a target *by convention* — no per-app source lists, no chip knowledge, no TOML parsing.

Nix is the **only** place TOML is parsed. CMake never sees `Via.toml`. This keeps
resolution reproducible and the build logic small and arch-agnostic.

## Design principles

- **Manifest-first.** An app declares its package, artifacts (`[[bin]]` / `[[test]]`),
  platforms, dependencies, and language standard in `Via.toml`. A hand-written
  `<app>/CMakeLists.txt` is an optional escape hatch, not the norm.
- **The app declares everything the build needs.** Arch flags (`-mcpu`, `-mfpu`, …), chip
  defines, which SDK directories are on the include path, which SDK files compile, the
  startup file, and the linker script all live on the app's platform. There is **no MCU
  "family" layer** doing this behind the scenes — every path is visible in the manifest.
- **The toolchain file is compiler-only.** Selecting GCC vs Clang for a device never
  touches arch flags, so the two swap untouched. Libc/spec choices live on the
  [toolchain record](./toolchains.md), not the build driver.
- **Per-app sealed builds.** Each artifact is its own Nix derivation with its own pinned
  toolchain, SDK, and dependencies, so apps can use different versions side by side.
- **No vendor code generators.** Vendor SDKs are consumed as git dependencies; any
  committed assets (linker scripts, startup) live under `<app>/config/`.

## Repository layout

Via the framework lives at the repo root; the runnable demos are a self-contained Via
workspace under `examples/`:

```
flake.nix           framework outputs: lib.mkVia, packages.docs, the example builds
nix/                the engine (via.nix), lib/*, and bundled toolchain records
cmake/              the generic driver: CMakeLists.txt, ViaDriver, ViaToolchain
docs/               this handbook (mdBook source under docs/src)
examples/           a Via workspace used as the demos:
  Via.toml            workspace manifest (members, shared dep pins)
  Via.lock            resolved git dependency pins (commit-exact)
  apps/<name>/        applications: Via.toml + src/ (+ inc/, config/, tests/)
  libs/<name>/        internal libraries (consumed from source)
```

See [Consuming Via externally](./consuming.md) to use the framework from your own repo, and
[Examples](./examples.md) for a tour of the demos.

Continue to [Architecture](./architecture.md) for how a `nix build` flows end to end.
