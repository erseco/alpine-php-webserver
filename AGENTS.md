# AGENTS.md

Guide for agents maintaining this repo. Keep it short; update it when the process changes.

## Branch / version layout

| Branch   | Alpine pin in `Dockerfile` | PHP |
|----------|----------------------------|-----|
| `main`   | `alpine:3.24` (floating minor — mainline) | 8.5 (`php85`) |
| `3.23.x` | exact patch, e.g. `alpine:3.23.6` | 8.4 (`php84`) |
| `3.22.x` | exact patch | 8.4 |
| `3.21.x` | exact patch | 8.4 |
| `3.20.x` | exact patch | 8.3 (`php83`), EOL: no longer built or listed in the README |

`main` also builds `-php83` and `-php84` variants (same Dockerfile, `PHP_SUFFIX` build arg,
matrix in `build.yml`), published as `3.24-php83`, `3.24.2-1-php83`, `3.24-php84`, … Alpine 3.20
(the 3.20.x branch, PHP 8.3) is EOL and gets no PHP fixes, so images that need 8.3 (alpine-moodle
for Moodle 4.5–5.2) use `-php83`. Images that need 8.4 (Moodle 5.3, Omeka S, FacturaScripts) use
`-php84`, which gets PHP fixes sooner than the 3.23.x line.

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

## PHP security release

1. Wait until Alpine 3.24 ships the fixed packages (`docker run --rm alpine:3.24 sh -c
   'apk update -q && apk policy php85 php83'`).
2. Bump `min` for each line in the `build.yml` matrix to the fixed versions. The build fails
   while Alpine still serves an older PHP, and the new value busts the cached apk layers (a plain
   rebuild would reuse them and ship the old PHP).
3. Merge, then tag `main` as a rebuild (`3.24.2-1`) and publish its GitHub Release with `--latest`.
4. Check: `docker run --rm --entrypoint php erseco/alpine-php-webserver:3.24-php83 -v`.

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

- Only the newest PHP owns `/usr/bin/php`; the Dockerfile points it at `php${PHP_SUFFIX}`. On
  the `-php83`/`-php84` variants, `apk add composer` pulls in php85 and repoints it, so downstream images
  should copy Composer from the official image instead.
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
