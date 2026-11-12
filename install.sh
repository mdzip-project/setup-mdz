#!/usr/bin/env bash
# Installs the mdz CLI from a mdzip-project/mdzip-cli GitHub release and adds
# it to PATH. Run by action.yml; reads MDZ_VERSION ("latest" or "2.1.0") and
# MDZ_TOKEN, plus the runner's RUNNER_OS, RUNNER_ARCH, RUNNER_TEMP and
# RUNNER_TOOL_CACHE. Every download is checked against the SHA-256 digest
# GitHub records for the release asset. Needs curl, tar (PowerShell on
# Windows) and one of jq, python3 or node to read JSON; GitHub-hosted runners
# have all of them.
set -euo pipefail

REPO="mdzip-project/mdzip-cli"
fail() { echo "::error title=setup-mdz::$*"; exit 1; }

# json_field <json> <asset-name|""> <field>: prints a field of the release
# (asset name empty) or of one of its assets, or nothing.
json_field() {
  if command -v jq >/dev/null; then
    if [ -z "$2" ]; then jq -r --arg f "$3" '.[$f] // empty' <<<"$1"
    else jq -r --arg n "$2" --arg f "$3" '.assets[] | select(.name == $n) | .[$f] // empty' <<<"$1"; fi
  elif py=$(command -v python3 || command -v python); then
    "$py" -c 'import json,sys
d=json.load(sys.stdin)
o=d if not sys.argv[1] else next((a for a in d.get("assets",[]) if a.get("name")==sys.argv[1]),{})
print(o.get(sys.argv[2]) or "")' "$2" "$3" <<<"$1"
  elif command -v node >/dev/null; then
    node -e 'const d=JSON.parse(require("fs").readFileSync(0,"utf8"));const n=process.argv[1];const o=n?(d.assets||[]).find(a=>a.name===n)||{}:d;console.log(o[process.argv[2]]||"")' "$2" "$3" <<<"$1"
  else
    fail "jq, python3 or node is needed to read the release information"
  fi
}

case "${RUNNER_OS:-}" in
  Linux)   os=linux; ext=tar.gz; exe=mdz ;;
  macOS)   os=osx;   ext=tar.gz; exe=mdz ;;
  Windows) os=win;   ext=zip;    exe=mdz.exe ;;
  *) fail "unsupported runner OS '${RUNNER_OS:-}' (Linux, macOS and Windows are supported)" ;;
esac
case "${RUNNER_ARCH:-}" in
  X64)   arch=x64 ;;
  ARM64) arch=arm64 ;;
  *) fail "unsupported runner architecture '${RUNNER_ARCH:-}' (x64 and arm64 are supported)" ;;
esac

requested="${MDZ_VERSION:-latest}"
if [ "$requested" = "latest" ]; then
  url="https://api.github.com/repos/$REPO/releases/latest"
else
  url="https://api.github.com/repos/$REPO/releases/tags/v${requested#v}"
fi

headers=(-H "Accept: application/vnd.github+json")
[ -n "${MDZ_TOKEN:-}" ] && headers+=(-H "Authorization: Bearer $MDZ_TOKEN")
release=$(curl -fsSL --retry 3 "${headers[@]}" "$url") \
  || fail "no mdz release '$requested' found (see https://github.com/$REPO/releases)"

tag=$(json_field "$release" "" tag_name | tr -d '\r')
[ -n "$tag" ] || fail "couldn't read the release tag from $url"
version="${tag#v}"
name="mdz-v$version-$os-$arch.$ext"
download=$(json_field "$release" "$name" browser_download_url | tr -d '\r')
digest=$(json_field "$release" "$name" digest | tr -d '\r')
[ -n "$download" ] || fail "release $tag has no $name"

# Folders: native form for GITHUB_PATH and outputs, POSIX form for bash on Windows.
dest="${RUNNER_TOOL_CACHE:-$RUNNER_TEMP}/mdz/$version/$arch"
dest_sh="$dest"
if [ "$os" = win ]; then dest_sh=$(cygpath -u "$dest"); dest=$(cygpath -w "$dest_sh"); fi

if [ -x "$dest_sh/$exe" ]; then
  echo "mdz $version is already installed in $dest"
else
  temp_sh="$RUNNER_TEMP"
  [ "$os" = win ] && temp_sh=$(cygpath -u "$RUNNER_TEMP")
  archive="$temp_sh/$name"
  echo "Downloading $download"
  curl -fsSL --retry 3 -o "$archive" "$download" || fail "couldn't download $download"

  if [ -n "$digest" ]; then
    if command -v sha256sum >/dev/null; then actual=$(sha256sum "$archive" | cut -d' ' -f1)
    else actual=$(shasum -a 256 "$archive" | cut -d' ' -f1); fi
    [ "sha256:$actual" = "$digest" ] || fail "checksum mismatch for $name: expected $digest, got sha256:$actual"
    echo "Checksum OK ($digest)"
  else
    echo "::warning title=setup-mdz::release $tag records no digest for $name, so the download wasn't checked"
  fi

  mkdir -p "$dest_sh"
  if [ "$ext" = zip ]; then
    ps=$(command -v pwsh || command -v powershell) || fail "PowerShell is needed to unzip $name"
    "$ps" -NoProfile -Command "Expand-Archive -LiteralPath '$(cygpath -w "$archive")' -DestinationPath '$(cygpath -w "$dest_sh")' -Force"
  else
    tar -xzf "$archive" -C "$dest_sh"
    chmod +x "$dest_sh/$exe"
  fi
  rm -f "$archive"
fi

echo "$dest" >> "$GITHUB_PATH"
echo "version=$version" >> "$GITHUB_OUTPUT"
echo "path=$dest" >> "$GITHUB_OUTPUT"
"$dest_sh/$exe" --version
echo "Installed mdz $version"
