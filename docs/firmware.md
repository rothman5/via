# The firmware path

A firmware artifact is just a `[[bin]]` on a platform with `kind = "firmware"`. The app
declares **everything** the device needs; Via's core names no arch flags, no chip define,
and no "family" abstraction.

## A firmware platform

```toml
[platform.fw]
kind      = "firmware"
toolchain = "arm-gnu"
defines   = ["STM32L412xx", "USE_HAL_DRIVER"]
cflags    = ["-mcpu=cortex-m4", "-mthumb", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard"]
ldflags   = ["-mcpu=cortex-m4", "-mthumb", "-mfpu=fpv4-sp-d16", "-mfloat-abi=hard"]
linker-script = { dep = "stm32cube-l4", path = "Projects/NUCLEO-L412KB/Templates/STM32CubeIDE/STM32L412KBTX_FLASH.ld" }

[[bin]]
name     = "blink"
src      = ["src/main.c"]
platform = "fw"
```

Switching chips is just different arch flags and a different startup/linker — no new layer.
`examples/apps/blink-mspm0` targets a Cortex-M0+ with the *same* `arm-gnu` toolchain, `soft` float,
and a committed startup/linker, no SDK at all:

```toml
[platform.fw]
kind      = "firmware"
toolchain = "arm-gnu"
cflags    = ["-mcpu=cortex-m0plus", "-mthumb", "-mfloat-abi=soft"]
ldflags   = ["-mcpu=cortex-m0plus", "-mthumb", "-mfloat-abi=soft"]
linker-script = "config/MSPM0L1306.ld"
sources       = ["config/startup_mspm0.c"]
```

## Startup & linker script

Both resolve two ways:

- **Committed** (app-relative string): `linker-script = "config/MSPM0L1306.ld"`,
  `sources = ["config/startup_mspm0.c"]`.
- **From a dependency** (`{ dep, path }` for the linker script; a dep `sources` entry for a
  startup shipped inside an SDK): e.g. the STM32 startup `.s` is just another entry in the
  SDK dependency's `sources`.

## Consuming a vendor SDK

A vendor SDK is a [raw git dependency](./dependencies.md#via-packages-vs-raw-deps) scoped to
the platform: it declares which `includes` go on the `-I` path and which `sources` compile.
Globs and `!`-excludes keep it precise — e.g. compile the HAL but skip the `*_template.c`
alternates and never touch the LL drivers:

```toml
[platform.fw.dependencies.stm32cube-l4]
git        = "https://github.com/STMicroelectronics/STM32CubeL4"
tag        = "v1.18.2"
submodules = true
includes = [
  "Drivers/CMSIS/Core/Include",
  "Drivers/CMSIS/Device/ST/STM32L4xx/Include",
  "Drivers/STM32L4xx_HAL_Driver/Inc",
  "Projects/NUCLEO-L412KB/Templates/Inc",
]
sources = [
  "Drivers/CMSIS/Device/ST/STM32L4xx/Source/Templates/gcc/startup_stm32l412xx.s",
  "Drivers/CMSIS/Device/ST/STM32L4xx/Source/Templates/system_stm32l4xx.c",
  "Drivers/STM32L4xx_HAL_Driver/Src/stm32l4xx_hal*.c",
  "!Drivers/STM32L4xx_HAL_Driver/Src/*_template.c",
  "Projects/NUCLEO-L412KB/Templates/Src/stm32l4xx_it.c",
  "Projects/NUCLEO-L412KB/Templates/Src/stm32l4xx_hal_msp.c",
]
```

## The bare-metal link policy

For a firmware artifact the driver applies a small, **compiler-neutral** policy
(`_via_firmware`):

- `-ffunction-sections -fdata-sections` + `-Wl,--gc-sections` (dead-code/-data stripping).
- `-Wl,-Map=<target>.map` (link map).
- The toolchain's `baremetalLdflags` (e.g. `--specs=nano.specs --specs=nosys.specs` for
  arm-gcc/newlib) — these libc/spec flags come from the [toolchain record](./toolchains.md),
  **not** hardcoded in the driver, so a different toolchain supplies its own.
- The linker script (`-T…`) when one is declared.
- `.elf` suffix, plus a post-build `objcopy` to `.bin` and `.hex` and a `size` report.

The cross ELF is not stripped or `patchelf`-ed.

## Outputs

```
result/bin/<name>.elf      # the linked image
result/bin/<name>.bin      # raw binary  (objcopy -O binary)
result/bin/<name>.hex      # Intel HEX   (objcopy -O ihex)
<build>/<name>.map         # link map
```

`nix build .#blink` and `.#blink-mspm0` produce these. Firmware artifacts are excluded from
`nix flake check` — firmware logic is tested on the host through portable libraries.
