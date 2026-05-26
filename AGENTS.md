# AGENTS.md

## Build

```sh
FSST_BUILD=1 mix compile   # build NIF from source (requires Rust toolchain)
mix compile                # use precompiled NIFs when available
mix test                   # test suite
mix ci                     # full quality suite
```

Set `FSST_BUILD=1` for any compilation that touches Rust code.

## Architecture

FSST provides Fast Static Symbol Tables compression for Elixir.

Rust NIF crate:

- `native/fsst_nif/` — wraps `fsst-rs`

Elixir modules:

- `lib/fsst.ex` — public API: `train/2`, `train!/2`, `compress/3`, `compress!/3`, `decompress/3`, `decompress!/3`
- `lib/fsst/table.ex` — table struct and `FSST.Table.from_symbols/1` for serialized FSST dictionaries
- `lib/fsst/pure.ex` — pure Elixir backend
- `lib/fsst/rust.ex` — optional Rustler backend wrapper
- `lib/fsst/native.ex` — `RustlerPrecompiled` NIF loader

## Backend Rules

- Keep pure Elixir working without Rust toolchain requirements.
- Rust is optional acceleration; public APIs must continue to return Elixir-style `{:ok, value}` / `{:error, reason}` tuples and bang variants.
- Prefer explicit table passing over global state.
- Do not make Rust backend behavior required for tests that should validate pure Elixir.

## Naming Conventions

- Top-level `FSST` functions use operation names: `train`, `compress`, `decompress`.
- Bang variants raise `ArgumentError` with inspected reasons.
- Serialized dictionary construction lives under `FSST.Table`, not duplicated at the top level.

## Release

1. Bump `@version` in `mix.exs`
2. Update README/CHANGELOG if present
3. Run `mix ci`
4. Commit: `git commit -m "Release vX.Y.Z"`
5. Tag and push: `git tag vX.Y.Z && git push && git push --tags`
6. Wait for the precompile workflow to finish (all 5 targets must pass)
7. Download checksums:
   ```sh
   FSST_BUILD=1 mix rustler_precompiled.download FSST.Native --all
   ```
8. Commit and push checksums: `git commit -am "Update precompiled NIF checksums for vX.Y.Z" && git push`
9. Publish: `mix hex.publish`

**Never force-push a release tag.** The precompile workflow triggers on tag
push. Force-pushing re-triggers it, producing new artifacts that overwrite
the previous ones with different checksums. If you need to fix a release,
publish a patch version instead.

**Checksums commit must come AFTER the CI build completes**, not before. The tag
points to the release commit (without checksums). The checksums commit is a
follow-up on master — it doesn't need a tag.

Do not publish, tag, or create GitHub releases unless explicitly requested.
