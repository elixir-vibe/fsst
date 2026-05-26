# AGENTS.md

## Build

```sh
FSST_BUILD=1 mix compile   # build NIF from source (requires Rust toolchain)
mix compile                # compile Elixir project; NIF builds when rustler is available
mix test                   # test suite
mix ci                     # full quality suite
```

Set `FSST_BUILD=1` for any compilation that touches Rust code.

## Architecture

FSST provides Fast Static Symbol Tables compression for Elixir.

Elixir modules:

- `lib/fsst.ex` — public API: `train/2`, `train!/2`, `compress/3`, `compress!/3`, `decompress/3`, `decompress!/3`
- `lib/fsst/table.ex` — table struct used by both backends
- `lib/fsst/pure.ex` — pure Elixir backend
- `lib/fsst/rust.ex` — optional Rustler backend wrapper
- `lib/fsst/native.ex` — Rustler NIF loader/fallback

Rust NIF crate:

- `native/fsst_nif/` — wraps `fsst-rs`

## Backend Rules

- Keep pure Elixir working without Rust toolchain requirements.
- Rust is optional acceleration; public APIs must continue to return Elixir-style `{:ok, value}` / `{:error, reason}` tuples and bang variants.
- Prefer explicit table passing over global state.
- Do not make Rust backend behavior required for tests that should validate pure Elixir.

## Release

1. Bump `@version` in `mix.exs`
2. Update README/CHANGELOG if present
3. Run `mix ci`
4. Commit: `git commit -m "Release vX.Y.Z"`
5. Tag and push: `git tag vX.Y.Z && git push && git push --tags`
6. Publish: `mix hex.publish`

Do not publish, tag, or create GitHub releases unless explicitly requested.
