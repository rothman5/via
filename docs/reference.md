# Reference

## Manifest variables (`via_manifest.cmake`)

The engine renders these `set()` calls; the CMake driver consumes them. App authors never
write them by hand — this table is for understanding/extending the driver.

| Variable | Source | Use |
|---|---|---|
| `VIA_APP` | `package.name` | Project name; `VIA_PKG_NAME` in `via_build.h`. |
| `VIA_VERSION` | `package.version` | `VIA_PKG_VERSION`. |
| `VIA_ARTIFACT` | bin/test `name` | Target name; `VIA_ARTIFACT` in `via_build.h`. |
| `VIA_KIND` | `bin` / `test` | Drives test source auto-globbing. |
| `VIA_PROFILE` | `profile` | `VIA_PROFILE` in `via_build.h` (build type set on the cmake line). |
| `VIA_PLATFORM_KIND` | `platform.kind` | `firmware` enables `_via_firmware`. |
| `VIA_LINKER_SCRIPT` | `platform.linker-script` | `-T…` + `LINK_DEPENDS`. |
| `VIA_C_STD` / `VIA_CXX_STD` | `package.language` | `C_STANDARD` / `CXX_STANDARD`. |
| `VIA_DEFINES` | platform ++ artifact | `target_compile_definitions`. |
| `VIA_CFLAGS` | platform ++ artifact | `target_compile_options`. |
| `VIA_LDFLAGS` | platform ++ artifact | `target_link_options`. |
| `VIA_BAREMETAL_LDFLAGS` | toolchain `baremetalLdflags` | Firmware-only link flags. |
| `VIA_FEATURES` | artifact `features` | `VIA_FEATURE_<NAME>` defines. |
| `VIA_DEP_LIBS` | Via-package deps | Roots whose `src/**` compile and `inc/` is added. |
| `VIA_EXTRA_INCLUDES` | raw deps' `includes` | Extra `-I` dirs. |
| `VIA_SOURCES` | artifact `src` + raw dep & platform `sources` | Compiled file/glob patterns (`!` excludes). |

Two cache vars come straight from the engine's `cmake` line: `VIA_MANIFEST` (path to the
rendered file) and `VIA_APP_DIR` (app source dir, used for `inc/` and `tests/`).

Cross builds additionally pass `VIA_SYSTEM_NAME`, `VIA_SYSTEM_PROCESSOR`, `VIA_CC`,
`VIA_CXX`, `VIA_ASM`, `VIA_OBJCOPY`, `VIA_SIZE` to `ViaToolchain.cmake`.

## File map

| Path | Role |
|---|---|
| `flake.nix` | Framework outputs: `lib.mkVia`, `packages.docs`, and the example builds (via `mkVia { root = ./examples; }`). |
| `nix/via.nix` | Engine: discovery, artifact enumeration, attr naming, duplicate check. |
| `nix/lib/manifest.nix` | Render resolved values as `set()` calls (with CMake-safe escaping). |
| `nix/lib/deps.nix` | Resolve path/git deps; read `Via.lock` and workspace pins. |
| `nix/lib/toolchains.nix` | Discover + look up toolchain records; validate `@version`. |
| `nix/lib/artifact.nix` | `artifactInfo` (compute inputs) + `mkArtifact` (seal derivation). |
| `nix/lib/devshell.nix` | Per-app dev shell + `via-configure`. |
| `nix/toolchains/<id>.nix` | One toolchain record each (`gcc`, `clang`, `arm-gnu`). |
| `cmake/CMakeLists.txt` | Generic source root; includes the manifest and calls the driver. |
| `cmake/ViaDriver.cmake` | Build-by-convention: sources, deps, std, options, firmware policy. |
| `cmake/ViaToolchain.cmake` | Compiler selection only (host + cross). |
| `examples/` | A self-contained Via workspace (the demos): `Via.toml`/`Via.lock` + `apps/` + `libs/`. |

## Engine API (`nix/via.nix`)

```nix
# Inside the Via flake this is mkVia { root = ./examples; }; the import form:
import ./nix/via.nix { inherit pkgs; cmakeDir = ./cmake; root = ./examples; }
  .discoverApps  ./examples/apps   # -> [ { name; dir; manifest; } … ]
  .packagesFor   apps     # -> { <attr> = <derivation>; … }   bins + host tests
  .checksFor     apps     # -> { <attr> = <derivation>; … }   host tests only
  .devShellsFor  apps     # -> { <app> = <devShell>; … }
```

Downstream flakes get the same engine via the flake output (see
[Consuming Via externally](./consuming.md)):

```nix
via.lib.${system}.mkVia {
  root;                       # your repo root (workspace Via.toml + Via.lock)
  cmakeDir     ? "<via>/cmake";  # generic driver
  toolchainDirs ? [ ];        # extra <id>.nix scan dirs (root/toolchains is auto-added)
  toolchains    ? { };        # inline id -> record (or { pkgs }: record)
}
```

## Errors you may hit

| Message | Cause |
|---|---|
| `[[bin]] '<n>' … must declare a non-empty src` | A bin with no `src`. |
| `git dependency '<n>' has no Via.lock entry — run via update` | Missing lock pin. |
| `unknown toolchain '<id>'` | No `nix/toolchains/<id>.nix`. |
| `toolchain '<id>' provides version '<v>', not '<r>'` | `@version` mismatch. |
| `duplicate artifact name(s) across the workspace: …` | Two artifacts resolve to the same output attr. |
| `unknown profile '<p>' (expected release\|debug)` | Bad `profile` value. |
| `no sources resolved for artifact '<n>'` | A `[[bin]]`'s `src` matched nothing, or a `[[test]]` has no `tests/`. |
