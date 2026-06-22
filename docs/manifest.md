# The manifest: `Via.toml`

A package manifest describes **what** to build. Resolution and the build are derived
entirely from it. This page covers the artifact and platform tables; dependencies have
[their own page](./dependencies.md).

## Platforms

A `[platform.<id>]` table describes a build environment an artifact targets. It carries the
toolchain choice and all the arch/device specifics — Via's core names none of these itself.

```toml
[platform.host]
toolchain = "gcc"        # references nix/toolchains/gcc.nix

[platform.fw]
kind      = "firmware"   # default is "host"
toolchain = "arm-gnu"
defines   = ["STM32L412xx", "USE_HAL_DRIVER"]
cflags    = ["-mcpu=cortex-m4", "-mthumb", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard"]
ldflags   = ["-mcpu=cortex-m4", "-mthumb", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard"]
linker-script = "config/MSPM0L1306.ld"      # app-relative string, or a { dep, path } table
sources       = ["config/startup_mspm0.c"]  # platform-supplied sources (e.g. startup)
```

| Key | Meaning |
|---|---|
| `kind` | `"host"` (default) or `"firmware"`. Firmware enables the bare-metal link policy and image/size post-build, and is skipped by `checks`. |
| `toolchain` | A toolchain id, optionally `@version` (see [Toolchains](./toolchains.md)). |
| `defines` / `cflags` / `ldflags` | Merged with the artifact's own (platform first, then artifact). |
| `linker-script` | A string (app-relative) **or** `{ dep = "...", path = "..." }` to resolve inside a fetched dependency. |
| `sources` | App-relative files/globs the platform always compiles (startup, etc.). `!`-prefix excludes. |
| `profile` | `"release"` (default) or `"debug"` → `CMAKE_BUILD_TYPE`. Overridable per artifact. |
| `[platform.<id>.dependencies]` | Deps scoped to this platform (see [Dependencies](./dependencies.md)). |

## `[[bin]]` — an executable

```toml
[[bin]]
name     = "hello"
src      = ["src/main.c"]   # required, non-empty: a bin spells out its own sources
platform = "host"
```

A package may declare several bins:

```toml
[[bin]]
name     = "sim"
src      = ["src/sim.c"]
platform = "host"
```

| Key | Meaning |
|---|---|
| `name` | Artifact name. Output attr is `<pkg>` if it equals the package name, else `<pkg>-<name>`. |
| `src` | **Required, non-empty.** App-relative files/globs (`!` excludes). No directory is assumed. |
| `platform` | Which `[platform.<id>]` to build for. |
| `defines` / `cflags` / `ldflags` | Appended after the platform's. |
| `features` | Names emitted as `VIA_FEATURE_<NAME>` in `via_build.h`. |
| `profile` | Overrides the platform profile for this artifact. |

A missing or empty `src` on a `[[bin]]` is a hard error — Via never guesses a bin's
sources.

## `[[test]]` — a host test

```toml
[[test]]
name     = "unit"
platform = "host"
```

Tests are **host-only**; a firmware-platform test is dropped from `packages`/`checks`. A
test needs no `src`: the driver auto-globs `tests/*.c` / `*.cpp` / `*.cc` under the app.
Pull in a framework with a [`[dev-dependencies]`](./dependencies.md#dev-dependencies) entry
(e.g. Unity). The test binary is built, then run in the derivation's `checkPhase`; `nix
flake check` runs all of them.

## Generated build header

Every build gets a generated `via_build.h` on its include path — no `build.rs` equivalent
needed:

```c
#define VIA_PKG_NAME    "hello"
#define VIA_PKG_VERSION "0.1.0"
#define VIA_ARTIFACT    "sim"
#define VIA_PROFILE     "release"
#define VIA_FEATURE_<NAME> 1   /* one per declared feature */
```

## Worked example

`examples/apps/hello/Via.toml` exercises most of the surface — two bins, a path dependency, a git
dev-dependency, and a host test:

```toml
[package]
name = "hello"
version = "0.1.0"

[package.language]
c = "c11"

[dependencies]
greeting = { path = "../../libs/greeting" }

[dev-dependencies]
unity = { git = "https://github.com/ThrowTheSwitch/Unity", tag = "v2.6.0", includes = ["src"], sources = ["src/unity.c"] }

[platform.host]
toolchain = "gcc"

[[bin]]
name = "hello"
src  = ["src/main.c"]
platform = "host"

[[bin]]
name = "sim"
src  = ["src/sim.c"]
platform = "host"

[[test]]
name = "unit"
platform = "host"
```
