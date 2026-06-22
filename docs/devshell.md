# Dev shells

`nix develop .#<app>` drops you into a per-app shell with the **same** toolchains and tools
as the sealed build, plus a `via-configure` helper. The goal: reproduce the sealed build by
hand and get working `clangd`.

```sh
nix develop .#hello
via-configure            # configure ./target + compile_commands.json + .clangd
ninja -C target          # build
```

## What the shell provides

- `cmake`, `ninja`, `clang-tools` (clangd), `gdb`.
- The **union** of every artifact's toolchain in the app, so a multi-platform app has all
  its compilers present (e.g. host `gcc` *and* cross `arm-gnu` in one shell).
- A generated `via-configure` command.

## `via-configure [artifact]`

Run with no argument, it configures the app's **default artifact** — the bin named like the
package, else the first bin, else the first host test. Pass an artifact name to configure a
different one:

```sh
via-configure            # default artifact
via-configure sim        # a specific bin
via-configure unit       # a host test
```

It runs the *identical* `cmake` invocation the sealed build uses (into `./target`,
producing `compile_commands.json`), then writes a `.clangd` pointing at that build's compile
database and compiler — so system includes resolve correctly, including for cross builds:

```yaml
# .clangd  (generated — do not commit)
CompileFlags:
  CompilationDatabase: target
  Compiler: /nix/store/…/bin/arm-none-eabi-gcc
```

An unknown artifact name lists the valid ones:

```
via: unknown artifact 'foo' (have: hello sim unit)
```

## Why it matches the sealed build

`via-configure` is generated from the same `artifactInfo` the engine uses to seal each
artifact, so the manual `cmake` configure and the `nix build` configure are byte-for-byte
the same. Anything that builds under `nix build` builds in the shell, and vice versa.
