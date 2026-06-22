# Examples

The bundled demos live under `examples/` as one self-contained Via workspace
(`examples/Via.toml` + `examples/Via.lock` + `apps/` + `libs/`). The root flake
builds them with the framework's own engine — exactly as a downstream
[consumer](./consuming.md) would. Build any with `nix build .#<name>`.

| Command | What it demonstrates |
|---|---|
| `nix build .#hello` | Host bin with a **path dependency** on `greeting` and the generated `via_build.h`. |
| `nix build .#hello-sim` | A **second bin** in the same package (`sim`), sharing the lib. |
| `nix build .#hello-unit` | A host **`[[test]]`** auto-globbing `tests/`, with **Unity** as a git `dev-dependency`. Also run by `nix flake check`. |
| `nix build .#blink` | **STM32L412** firmware: the STM32Cube **HAL consumed as a git SDK** (raw dep with `includes`/`sources` globs), a dep-resolved linker script, `.elf`/`.bin`/`.hex` + size. |
| `nix build .#blink-mspm0` | **Bare-metal TI MSPM0** (Cortex-M0+): same `arm-gnu` toolchain, **no SDK** — a committed startup + linker only. |

## What each example maps to

- **`examples/libs/greeting`** — a [portable library](./workspace.md#libraries) (`[lib]
  portable = true`) built from source inside each consumer, so the same code works on host
  and firmware.
- **`examples/apps/hello`** — the [host path](./building.md): two bins, a path dep, a git
  dev-dep, and a host test. The most complete tour of the [manifest](./manifest.md).
- **`examples/apps/blink`** — the [firmware path](./firmware.md) with a vendor SDK: shows
  `includes`/`sources` globs (`stm32l4xx_hal*.c`, `!*_template.c`) and a `{ dep, path }`
  linker script.
- **`examples/apps/blink-mspm0`** — firmware with **no** SDK: proves switching chips is just
  different arch flags + a committed startup/linker, with no MCU "family" layer.

## Working in an example

```sh
nix develop .#hello      # dev shell with the right toolchain + clangd
via-configure            # configure ./target + compile_commands.json + .clangd
ninja -C target          # build by hand (identical to the sealed build)
```

See [Dev shells](./devshell.md) for `via-configure [artifact]` on multi-artifact apps.
