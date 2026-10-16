/**
 * The factory for smithersai/jj. One rule: every day, rebase the Smithers
 * patch stack (branch `smithers`) onto jj-vcs/jj main and propose the result
 * for a maintainer to accept (SMITHERS.md). `.smithers/PACKAGE.ts`
 * `factoryProjection` writes `.smithers/factory.json`, the file the Smithers
 * server reads; regenerate it after editing this file.
 */
import { Smithers as S } from "@smthrs/targets"

export const rebaseUpstream = S.Flow({
  flow: "rebase-upstream",
  summary: "Rebase the Smithers patch stack onto jj-vcs/jj main and propose it."
})

export const factory = S.Factory({
  summary: "Keeps the Smithers patch stack rebased on jj-vcs/jj.",
  flows: [rebaseUpstream],
  on: {
    "schedule:0 6 * * *": { flow: "rebase-upstream", description: "Rebase onto jj-vcs/jj daily" }
  },
  github: S.Github.Policy({
    mirror: "pull",
    issues: "two-way",
    changes: "send-upstream",
    maintainers: ["roninjin10"]
  })
})
