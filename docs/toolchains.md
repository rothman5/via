# Toolchains

A toolchain is a single file `nix/toolchains/<id>.nix` returning a uniform record. Every
toolchain — host or cross — is discovered the same way and referenced from a platform by
id:

```toml
[platform.fw]
toolchain = "arm-gnu"        # or "arm-gnu@15.2.rel1" to assert a version
```

The default toolchain when a platform omits the key is `gcc`.

## The toolchain record

A host record needs only a package and the two compiler binaries:

```nix
# nix/toolchains/gcc.nix
{ pkgs }:
{
  pkg   = pkgs.gcc;
  cross = false;
  cc    = "${pkgs.gcc}/bin/gcc";
  cxx   = "${pkgs.gcc}/bin/g++";
}
```

A cross record sets `cross = true` and adds the fields the engine threads into the CMake
toolchain file, plus any **bare-metal libc/spec flags**:

```nix
# nix/toolchains/arm-gnu.nix
{ pkgs }:
let bin = "${pkgs.gcc-arm-embedded}/bin"; prefix = "arm-none-eabi-"; in
{
  pkg     = pkgs.gcc-arm-embedded;
  version = pkgs.gcc-arm-embedded.version;   # validated against an "@version" request
  cross   = true;
  systemName      = "Generic";
  systemProcessor = "arm";
  cc = "${bin}/${prefix}gcc";   cxx = "${bin}/${prefix}g++";  asm = "${bin}/${prefix}gcc";
  objcopy = "${bin}/${prefix}objcopy";  size = "${bin}/${prefix}size";

  # newlib/arm-gcc specific — lives here, not in the driver, so a clang toolchain
  # could supply its own equivalent and the firmware link policy stays neutral.
  baremetalLdflags = [ "--specs=nano.specs" "--specs=nosys.specs" ];
}
```

### Record fields

| Field | Required | Meaning |
|---|---|---|
| `pkg` | yes | The package added to the build inputs / dev shell. |
| `cross` | yes | `true` selects the cross path: emit `CMAKE_TOOLCHAIN_FILE` + system/binutils vars. |
| `cc` / `cxx` | yes | Compiler binaries. |
| `asm` | cross | Assembler (usually the C compiler). |
| `objcopy` / `size` | cross | Binutils used by the firmware image/size post-build. |
| `systemName` / `systemProcessor` | cross | `CMAKE_SYSTEM_NAME` / `CMAKE_SYSTEM_PROCESSOR`. `Generic` triggers freestanding compiler-check settings. |
| `version` | optional | Asserted when a platform requests `<id>@<version>`. |
| `baremetalLdflags` | optional | Libc/spec link flags applied only on firmware platforms. |

## Versions

`toolchain = "arm-gnu@15.2.rel1"` validates the request against the record's `version`
field. A mismatch — or a version request against a record with no `version` — fails fast:

```
via: toolchain 'arm-gnu' provides version '15.2.rel1', not '99'
```

Deriving `version` from the package (as above) keeps the assertion honest as nixpkgs moves.

## Compiler selection is all the toolchain file does

`cmake/ViaToolchain.cmake` sets only the compiler binaries and — for a cross build — the
system name/processor and the settings that let the compiler check pass without a linker
script (`CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY`, `FIND_ROOT_PATH` modes). It names
no `-mcpu`, no chip define, no linker script. Those come from the manifest. That separation
is what lets GCC and Clang swap on one device untouched.

## Adding a toolchain

### Inside the Via repo

1. Drop a `nix/toolchains/<id>.nix` returning the record above.
2. Reference it from a platform: `toolchain = "<id>"`.

No registry edit is needed — discovery is automatic, and an unknown id fails fast:
`via: unknown toolchain '<id>' (no nix/toolchains/<id>.nix)`.

### From a downstream consumer

A flake that consumes Via via [`mkVia`](./consuming.md) adds toolchains without forking,
three ways (later overrides earlier on an id clash, so you can also **shadow a built-in**):

1. **Convention — zero config.** Drop `toolchains/<id>.nix` at your repo root (the same
   `{ pkgs }: record` shape). It is auto-discovered, exactly like `apps/` is:

   ```
   your-repo/
     Via.toml          # workspace root
     toolchains/
       riscv-gnu.nix   # -> toolchain = "riscv-gnu"
     apps/…
   ```

2. **Explicit directories** — for toolchains kept elsewhere:

   ```nix
   via.lib.${system}.mkVia { root = ./.; toolchainDirs = [ ./vendor/toolchains ]; }
   ```

3. **Inline records** — when the record must reference *your own* flake inputs (a file
   imported by Via only receives Via's `pkgs`). Pass a record, or a `{ pkgs }: record`:

   ```nix
   via.lib.${system}.mkVia {
     root = ./.;
     toolchains.riscv-gnu = {
       pkg     = myInputs.riscv-toolchain;        # from your own input
       version = myInputs.riscv-toolchain.version;
       cross   = true;
       systemName = "Generic";  systemProcessor = "riscv";
       cc = "${myInputs.riscv-toolchain}/bin/riscv64-none-elf-gcc";
       # cxx/asm/objcopy/size/baremetalLdflags as needed …
     };
   }
   ```

All three use the **same record fields** documented above, and `@version` validation,
unknown-id errors, and the compiler-only toolchain file all apply unchanged.
