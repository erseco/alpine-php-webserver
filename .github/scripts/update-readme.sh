#!/bin/sh
set -eu

MAINTAINED_MINORS="${MAINTAINED_MINORS:-5}"
REPO="${GITHUB_REPOSITORY:-erseco/alpine-php-webserver}"
README="${README:-README.md}"

[ -n "$REPO" ] || { echo "GITHUB_REPOSITORY is not defined (owner/repo)" >&2; exit 1; }

BLOCK_START="<!-- supported-tags:start -->"
BLOCK_END="<!-- supported-tags:end -->"

# 1) Get all 3.x.y tags sorted
TAGS=$(git tag -l '3.*.*' | sort -V)
[ -n "$TAGS" ] || { echo "No 3.x.y tags found" >&2; exit 0; }

# 2) For each minor, keep the highest patch version
BEST=$(echo "$TAGS" | awk -F. '
  {
    if ($1 != 3) next
    m = $1 "." $2
    last[m] = $0
  }
  END {
    for (m in last) print m, last[m]
  }
' | sort -V -k1,1)

# 3) Select the last N minors and reverse the order
SEL=$(echo "$BEST" | tail -n "$MAINTAINED_MINORS" | awk '{ lines[NR]=$0 } END { for (i=NR;i>0;i--) print lines[i] }')

[ -n "$SEL" ] || { echo "No minors selected" >&2; exit 0; }

# 4) Build the block
BLOCK=""
first=1

echo "$SEL" | while read -r minor full; do
  url="https://github.com/${REPO}/blob/${full}/Dockerfile"
  # Derive the PHP version shipped by this tag from its own Dockerfile (php85 -> 8.5)
  php_ver=$(git show "${full}:Dockerfile" 2>/dev/null | grep -oE 'php8[0-9]' | head -1 | sed -E 's/^php([0-9])([0-9])$/\1.\2/')
  if [ -n "$php_ver" ]; then php_note=" — PHP ${php_ver}"; else php_note=""; fi
  if [ "$first" -eq 1 ]; then
    # newest minor → include all aliases: latest, 3, minor, full
    echo "- \`latest\`, \`3\`, \`$minor\`, \`$full\` ([Dockerfile](${url}))${php_note}"
    first=0
  else
    # older minors → only minor and full
    echo "- \`${minor}\`, \`${full}\` ([Dockerfile](${url}))${php_note}"
  fi
done > supported-tags.tmp


# 5) Replace the block in README
awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
  BEGIN { inblk=0 }
  {
    if ($0 ~ start) {
      print $0
      while ((getline line < "supported-tags.tmp") > 0) print line
      inblk=1
      next
    }
    if ($0 ~ end) {
      inblk=0
    }
    if (!inblk) print $0
  }
' "$README" > "${README}.new"

mv "${README}.new" "$README"
rm -f supported-tags.tmp

echo "README updated."
