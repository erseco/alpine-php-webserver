# AGENTS.md

Guide for agents maintaining this repo. Keep it short; update it when the process changes.

## Branch / version layout

| Branch   | Alpine pin in `Dockerfile` | PHP |
|----------|----------------------------|-----|
| `main`   | `alpine:3.24` (floating minor — mainline) | 8.5 (`php85`) |
| `3.23.x` | exact patch, e.g. `alpine:3.23.6` | 8.4 (`php84`) |
| `3.22.x` | exact patch | 8.4 |
| `3.21.x` | exact patch | 8.4 |
| `3.20.x` | exact patch | 8.3 (`php83`) |

Git tag = the Alpine patch the image was built from (`3.23.6`, `3.24.2`, …). Rebuilds of the
same Alpine patch use a `-N` suffix (`3.23.4-1`).

## Alpine patch release (the routine job)

When Alpine announces new patch releases:

1. For each maintenance branch, bump both `FROM ${ARCH}alpine:X.Y.Z` lines in `Dockerfile`
   (builder stage + runtime stage) and commit as `chore: bump Alpine to X.Y.Z`.
   `main` floats on `alpine:3.24`, so it needs no Dockerfile edit — just tag it.
2. Push branches, then annotated tags on each branch head.
3. Create a **GitHub Release** for every tag (`gh release create <tag> --title <tag> --notes ...`).
   Use `--latest` only for the mainline (`main`) release; maintenance releases need
   `--latest=false` so they never move Docker `:latest`.

## CI: what actually publishes images

`.github/workflows/build.yml` builds version Docker tags on the **`release: published`** event,
not on tag pushes (the `on.push.tags` glob uses `()` groups that GitHub treats as literals and
never matches). Pushing to `main` only publishes `:beta`.

A release build emits `{{version}}` and `{{major}}.{{minor}}`; if the tag commit is an ancestor
of `main` it also moves `latest` and `3`. It then regenerates the README supported-tags block
and commits it to `main`, so never hand-edit that block.

To rebuild an existing tag: move the git tag (`git tag -f`, `git push --force origin refs/tags/<tag>`)
and re-fire CI with `gh release edit <tag> --draft` followed by `gh release edit <tag> --draft=false`.

## Gotchas

- PHP 8.5 has **no `php85-opcache`** package (OPcache is in core); `json` and `zlib` also ship
  in the `php85` core package. FPM binary is `php-fpm85`, config tree `/etc/php85/`.
- `MAINTAINED_MINORS` (in `build.yml` and `.github/scripts/update-readme.sh`) controls how many
  minors the README lists. Currently 5.
- No AI attribution in commits, PRs, or files.

## Releasing several tags at once

Concurrent release builds all try to commit the regenerated README to `main`; the losers used to
fail with `! [rejected] (fetch first)`. The commit step now rebases and retries, but the image
build/push already finished by then — a failure in that last step never means a missing image.
Verify with `docker manifest inspect docker.io/erseco/alpine-php-webserver:<tag>`.
