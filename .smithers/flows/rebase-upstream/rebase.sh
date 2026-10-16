#!/usr/bin/env bash
# Rebases the Smithers patch stack (branch `smithers`) onto jj-vcs/jj main,
# checks the result, and proposes it on one tracking issue. It never moves
# `smithers`: a maintainer accepts a candidate (SMITHERS.md).
#
#   up to date        exit 0, closes the tracking issue if one is open
#   candidate ready   exit 0, pushes tag smithers/rebase/<date>-<upstream>
#                     and updates the issue with the accept commands
#   conflict/failure  exit 1, updates the issue with what failed
#
# Needs git, cargo (with the wasm32-wasip1 target) and an authenticated gh.
set -euo pipefail

upstream_url="${UPSTREAM_URL:-https://github.com/jj-vcs/jj.git}"
fork="${FORK:-smithersai/jj}"
patch_branch="${PATCH_BRANCH:-smithers}"
label="rebase-upstream"
title="Rebase the Smithers patch stack onto jj-vcs/jj"
dry_run="${DRY_RUN:-0}"
if command -v rustup >/dev/null 2>&1; then
  export RUSTUP_TOOLCHAIN="${RUSTUP_TOOLCHAIN:-1.98.0}"
fi

repo=$(git rev-parse --show-toplevel)
if ! git -C "$repo" config user.email >/dev/null; then
  export GIT_COMMITTER_NAME=Smithers GIT_COMMITTER_EMAIL=noreply@smithers.sh
fi
work=$(mktemp -d)
logs="$work/logs"
tree="$work/tree"
mkdir -p "$logs"
cleanup() {
  cd "$repo"
  git -C "$repo" worktree remove --force "$tree" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

git -C "$repo" fetch --quiet --no-tags "$upstream_url" main
upstream=$(git -C "$repo" rev-parse FETCH_HEAD)
git -C "$repo" fetch --quiet --no-tags origin "$patch_branch"
current=$(git -C "$repo" rev-parse FETCH_HEAD)
short=${upstream:0:9}

issue_number() {
  gh issue list -R "$fork" --label "$label" --state open --json number --jq '.[0].number // empty'
}

# Writes $1 as the tracking issue's body and as a new comment.
report() {
  local body="$1"
  if [ "$dry_run" = 1 ]; then
    cat "$body"
    return
  fi
  gh label create "$label" -R "$fork" --color 5319e7 \
    --description "Patch stack rebase onto jj-vcs/jj" --force >/dev/null
  local number
  number=$(issue_number)
  if [ -z "$number" ]; then
    gh issue create -R "$fork" --title "$title" --label "$label" --body-file "$body"
  else
    gh issue edit "$number" -R "$fork" --body-file "$body" >/dev/null
    gh issue comment "$number" -R "$fork" --body-file "$body"
  fi
}

if git -C "$repo" merge-base --is-ancestor "$upstream" "$current"; then
  echo "up to date: $patch_branch $current contains jj-vcs/jj $upstream"
  number=$([ "$dry_run" = 1 ] || issue_number)
  if [ -n "$number" ]; then
    gh issue close "$number" -R "$fork" \
      --comment "Up to date: \`$patch_branch\` ($current) contains jj-vcs/jj \`$upstream\`."
  fi
  exit 0
fi

base=$(git -C "$repo" merge-base "$upstream" "$current")
git -C "$repo" worktree add --quiet --detach "$tree" "$current"
cd "$tree"

body="$work/body.md"
fail() {
  local summary="$1" log="$2"
  {
    echo "**Blocked.** $summary"
    echo
    echo "- \`$patch_branch\`: \`$current\`"
    echo "- jj-vcs/jj main: \`$upstream\`"
    if [ -n "$log" ]; then
      echo
      echo '```'
      tail -n 80 "$log"
      echo '```'
    fi
    echo
    echo "Resolve it on a branch from \`$patch_branch\`, then a maintainer moves \`$patch_branch\`; see SMITHERS.md."
  } >"$body"
  report "$body"
  exit 1
}

if ! git rebase --quiet "$upstream" >"$logs/rebase.log" 2>&1; then
  commit=$(git log -1 --format='%h %s' REBASE_HEAD 2>/dev/null || echo unknown)
  git diff --name-only --diff-filter=U >>"$logs/rebase.log" || true
  git rebase --abort || true
  fail "Rebasing onto jj-vcs/jj \`$short\` conflicts at \`$commit\`." "$logs/rebase.log"
fi
candidate=$(git rev-parse HEAD)

check() {
  local name="$1"
  shift
  echo "check: $name"
  if ! "$@" >"$logs/$name.log" 2>&1; then
    fail "\`$name\` fails on the rebased stack \`$candidate\`." "$logs/$name.log"
  fi
}
check test cargo test --locked -p jj-core -p jj-lib --all-features
check clippy cargo clippy --locked --all-features -p jj-core -p jj-lib --all-targets -- -D warnings
check wasi cargo build --locked -p jj-lib --target wasm32-wasip1 --no-default-features

tag="smithers/rebase/$(date -u +%Y-%m-%d)-$short"
if [ "$dry_run" != 1 ]; then
  git push --quiet origin "$candidate:refs/tags/$tag"
fi
{
  echo "**Ready.** Tag \`$tag\` (\`$candidate\`) is the patch stack rebased onto jj-vcs/jj \`$upstream\`."
  echo "\`cargo test\`, \`cargo clippy -D warnings\` and the wasm32-wasip1 build pass ($(cargo --version))."
  echo
  echo "To accept, a maintainer runs:"
  echo
  echo '```sh'
  echo "git fetch origin tag $tag"
  echo "git push --force-with-lease=$patch_branch:$current origin $candidate:refs/heads/$patch_branch"
  echo '```'
  echo
  echo "then bumps \`jj-lib\` in smithersai/smithers \`Cargo.toml\` to \`rev = \"$candidate\"\`."
  echo
  echo '```'
  git range-diff --no-color "$base..$current" "$upstream..$candidate"
  echo '```'
} >"$body"
report "$body"
