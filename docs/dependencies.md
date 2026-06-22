# Dependencies & the lockfile

Dependencies are resolved by the Nix engine (`nix/lib/deps.nix`) — never by CMake. Each
entry resolves to a **fetched source tree**: a local path, or a git checkout pinned by
[`Via.lock`](#the-lockfile).

## Where dependencies are declared

Three scopes feed a single resolution set for an artifact:

```toml
[dependencies]                       # always in scope
greeting = { path = "../../libs/greeting" }

[platform.fw.dependencies]           # in scope only on that platform
stm32cube-l4 = { git = "…", tag = "v1.18.2", submodules = true, includes = […], sources = […] }

[dev-dependencies]                   # in scope only for [[test]] artifacts
unity = { git = "…", tag = "v2.6.0", includes = ["src"], sources = ["src/unity.c"] }
```

They merge as `dependencies` → `platform.dependencies` → (`dev-dependencies` for tests),
later scopes winning a name clash.

## Path vs git

```toml
# Path: relative to the app directory.
greeting = { path = "../../libs/greeting" }

# Git: pinned by Via.lock to an exact commit; tag is advisory.
unity = { git = "https://github.com/ThrowTheSwitch/Unity", tag = "v2.6.0" }

# Git with submodules (vendor SDK umbrellas):
stm32cube-l4 = { git = "…", tag = "v1.18.2", submodules = true }
```

A git dependency **must** have a matching `Via.lock` entry, or resolution fails with
`via: git dependency '<name>' has no Via.lock entry`. The lock's `rev` is what is actually
fetched (via `builtins.fetchGit`); the `tag` only selects the ref to fetch under.

To inherit a shared pin from `[workspace.dependencies]`, set `workspace = true` on the entry
and override fields as needed.

## Via packages vs raw deps

How a dependency is consumed depends on whether its tree contains a `Via.toml`:

- **Via package** (has `Via.toml`) — a first-class library. The driver compiles its
  `src/**` (`.c/.cpp/.cc/.S`) into the consumer and adds its `inc/` to the include path.
  Because it is built *inside* the consumer, it honors that artifact's toolchain and
  standard (this is what makes a [portable lib](./workspace.md#libraries) work on host and
  firmware alike). No `includes`/`sources` keys needed.
- **Raw dep** (no `Via.toml`, e.g. a vendor SDK) — it must declare how to consume it:

  ```toml
  includes = [ "src" ]            # dep-relative dirs added to the include path (-I)
  sources  = [ "src/unity.c" ]    # dep-relative files/globs to compile
  ```

  `sources` patterns support gitignore-style excludes and reach CMake's `file(GLOB)`
  unexpanded:

  ```toml
  sources = [
    "Drivers/STM32L4xx_HAL_Driver/Src/stm32l4xx_hal*.c",   # glob
    "!Drivers/STM32L4xx_HAL_Driver/Src/*_template.c",       # exclude the *_template alternates
  ]
  ```

## `dev-dependencies`

Only in scope when building a `[[test]]`. Typically a host test framework (Unity is the
example here): a raw dep declaring its `includes` and `sources` so the driver compiles the
framework alongside the auto-globbed `tests/`.

## The lockfile

`Via.lock` (committed, at the workspace root) pins each git dependency to an exact commit —
the source of build reproducibility. It is refreshed by `via update`.

```toml
version = 1

[[dependency]]
name   = "unity"
source = "git"
url    = "https://github.com/ThrowTheSwitch/Unity"
tag    = "v2.6.0"
rev    = "860062d51b2e8a75d150337b63ca2a472840d13c"

[[dependency]]
name   = "stm32cube-l4"
source = "git"
url    = "https://github.com/STMicroelectronics/STM32CubeL4"
tag    = "v1.18.2"
rev    = "28bac46b8bae4e74951f6decc48a30984ad5e621"   # submodules pinned by this commit
```

> A vendor SDK consumed `submodules = true` has its submodules (HAL, CMSIS, …) pinned
> transitively by the umbrella commit recorded here.
