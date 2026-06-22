# Workspace & packages

Every `Via.toml` is one of two things:

- a **workspace** manifest (has a `[workspace]` table) — the monorepo root, or
- a **package** manifest (has a `[package]` table) — one app or library.

## The workspace root

A workspace `Via.toml` (the repo root you point Via at — `examples/Via.toml` for the
bundled demos) lists members and holds shared settings:

```toml
[workspace]
members = ["apps/*", "libs/*"]

[workspace.package]
edition = "2026"
```

- `members` — glob patterns for where packages live. Apps under `apps/` are what the flake
  turns into build outputs; `libs/` packages are consumed as dependencies.
- `[workspace.package]` — defaults shared across packages.
- `[workspace.dependencies]` *(optional)* — shared dependency pins a package can inherit
  with `workspace = true` on its own dependency entry (see [Dependencies](./dependencies.md)).

The workspace root is also where [`Via.lock`](./dependencies.md#the-lockfile) lives.

## A package

A package manifest names itself and its language:

```toml
[package]
name        = "hello"
version     = "0.1.0"
description = "Host example — path-dep on libs/greeting, git dev-dep on Unity"

[package.language]
c = "c11"        # → C_STANDARD 11
# cxx = "c++17"  # → CXX_STANDARD 17
```

From here a package either builds artifacts (apps, via `[[bin]]` / `[[test]]` — see
[The manifest](./manifest.md)) or is a library others consume.

## Libraries

A library declares `[lib]`:

```toml
[package]
name    = "greeting"
version = "0.1.0"

[package.language]
c = "c11"

[lib]
portable = true
```

A **portable** library is built *from source inside each consumer's tree*, so it honors
that consumer's toolchain and language standard — the same `greeting` sources can land in a
host binary and a firmware image. Libraries are discovered only as dependencies; they do
not themselves appear as build outputs. By convention a library exposes headers in `inc/`
and sources in `src/` (see [Dependencies → Via packages](./dependencies.md#via-packages-vs-raw-deps)).
