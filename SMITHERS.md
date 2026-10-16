# Smithers patch stack

This fork of [jj-vcs/jj](https://github.com/jj-vcs/jj) holds the changes
[Smithers](https://github.com/smithersai/smithers) needs in `jj-lib`. Branch
`smithers` is jj-vcs/jj `main` plus the commits below, kept rebased, never
merged. Smithers pins one commit of it in its root `Cargo.toml`
(`jj-lib = { git = "https://github.com/smithersai/jj", rev = "..." }`) and
builds the bundled `jj` CLI from the same commit.

`main` in this fork is not maintained; read upstream's.

## The stack

Oldest first. Each commit stands alone, carries its tests, and builds natively
and for `wasm32-wasip1`.

| Commit | Why |
| --- | --- |
| `wasi: support compiling jj-lib for WASI targets (without git support)` | Smithers runs `jj-lib` in the browser as `wasm32-wasip1` (`flows_jj.wasm`). Adds a lockfile-based `FileLock`, a WASI `file_util::platform`, and skips `canonicalize`, which WASI lacks. Based on jj-vcs/jj#9849. |
| `workspace: skip path canonicalization on WASI` | Same reason, for workspace init and load. |
| `repo_path: represent non-UTF-8 path bytes losslessly` | Upstream skips names that are not UTF-8 (#9774); Smithers captures arbitrary working copies and must not lose files. Each invalid byte is stored as NUL plus two hex digits; Git trees keep the original bytes. From smithersai/smithers#3561. |
| `file_util: share new workspace files with the team group` | Smithers machines share one repository below Linux `/workspace` between several UIDs in group `team` (gid 20000). Grants group read/write on files jj creates there, only in setgid team directories. From smithersai/smithers#3567 and #3385. |
| `git_backend: share new loose objects with the team group` | gix writes loose objects 0444; the same grant for Git objects. From smithersai/smithers#3567. |
| `smithers: document the patch stack` | This file. |
| `smithers: rebase onto jj-vcs/jj daily` | The scheduled flow below. |

Check the stack with the toolchain Smithers pins (`1.98.0`):

```sh
cargo test -p jj-core -p jj-lib --all-features
cargo clippy --all-features -p jj-core -p jj-lib --all-targets -- -D warnings
cargo build -p jj-lib --target wasm32-wasip1 --no-default-features
cargo +nightly fmt --all -- --check
```

Add a change as a new commit on `smithers` with its tests, and add a row here.
When upstream accepts an equivalent change, the next rebase drops ours.

## Rebasing

`.smithers/FACTORY.ts` schedules the repository flow
`.smithers/flows/rebase-upstream` daily at 06:00 UTC. It runs `rebase.sh`,
which rebases `smithers` onto jj-vcs/jj `main` and runs the checks above
(except rustfmt, which needs nightly), then writes the result to the one open
issue labeled `rebase-upstream`:

- **Ready:** it pushes the tag `smithers/rebase/<date>-<upstream>` and posts
  the commands that accept it.
- **Blocked:** it posts the conflicting commit or failing check.
- **Up to date:** it closes the issue.

A rebased stack cannot merge through a pull request, and agents never move
`smithers`, so a maintainer accepts a candidate:

```sh
git fetch origin tag smithers/rebase/<date>-<upstream>
git push --force-with-lease=smithers:<old> origin <candidate>:refs/heads/smithers
```

and then bumps the `jj-lib` rev in smithersai/smithers. Tags are never deleted,
so every rev Smithers ever pinned stays fetchable. Earlier heads are tagged
too, for example `smithers/pre-rebase-47589ada`.

The Smithers server reads `.smithers/factory.json`, not `FACTORY.ts`.
Regenerate it after editing either file:

```sh
smthrs target '//.smithers:factoryProjection' --write
```

To run the rebase by hand without pushing or writing the issue:

```sh
DRY_RUN=1 bash .smithers/flows/rebase-upstream/rebase.sh
```
