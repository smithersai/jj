/**
 * Smithers workspace for smithersai/jj, the jj fork Smithers builds against.
 * It exists to declare the factory in FACTORY.ts; the fork's own build is
 * Cargo, unchanged from upstream.
 */
import { Smithers as S } from "@smthrs/targets"

export const Workspace = S.Workspace("jj", {
  repository: "git+https://github.com/smithersai/jj.git",
  cache: S.Cache({ directory: ".smithers/cache" }),
  // The channel smithersai/smithers pins (its rust-toolchain.toml), so the
  // fork is checked with the compiler that builds Smithers' jj artifacts.
  toolchains: [
    S.Rust.Toolchain({ workspace: S.file("//Cargo.toml"), lockfile: S.file("//Cargo.lock"), channel: "1.98.0" })
  ]
})
