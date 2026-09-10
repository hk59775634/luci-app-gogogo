#!/bin/sh
# 生成 manifest/version.json 与 release/ 产物；仅正式推送时使用（见 PUSH.md）
# 用法: ./scripts/publish-release.sh --ipk /path/to/luci-app-gogogo_2026091003-1_all.ipk [--push]

set -e
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

_env_val() {
	grep -m1 "^${1}=" ./env 2>/dev/null | sed 's/^[^=]*=//;s/^[[:space:]]*//;s/[[:space:]]*$//;s/^:=//'
}

PKG_NAME="$(_env_val CPE_PKG_NAME)"
[ -n "$PKG_NAME" ] || PKG_NAME="luci-app-gogogo"
IPK=""
PUSH_GIT=0

while [ $# -gt 0 ]; do
	case "$1" in
		--ipk) IPK=$2; shift 2 ;;
		--push) PUSH_GIT=1; shift ;;
		-h|--help)
			echo "Usage: $0 --ipk <path.ipk> [--push]" >&2
			exit 0
			;;
		*) echo "Unknown arg: $1" >&2; exit 1 ;;
	esac
done

[ -n "$IPK" ] && [ -f "$IPK" ] || {
	echo "error: --ipk required and must exist" >&2
	exit 1
}

VER=$(basename "$IPK" | sed -n "s/^${PKG_NAME}_\\([0-9]\\{10\\}\\)\\(-[0-9]\\+\\)\\?_all\\.ipk\$/\\1/p")
[ -n "$VER" ] || VER="$(_env_val CPE_PKG_VERSION)"
[ -n "$VER" ] || {
	echo "error: cannot detect version from ipk name or env" >&2
	exit 1
}

SHA=$(sha256sum "$IPK" | awk '{print $1}')
IPK_NAME=$(basename "$IPK")

mkdir -p manifest release
MANIFEST=$ROOT/manifest/version.json

printf '%s\n' "{\"version\":\"$VER\",\"url\":\"$IPK_NAME\",\"sha256\":\"$SHA\"}" >"$MANIFEST"

cp -f "$MANIFEST" "$ROOT/release/version.json"
cp -f "$IPK" "$ROOT/release/$IPK_NAME"

echo "manifest: $MANIFEST"
echo "release/:  release/version.json release/$IPK_NAME"
echo "version=$VER sha256=$SHA"

if [ "$PUSH_GIT" != 1 ]; then
	echo ""
	echo "Local manifest/release ready. No git/github action (see PUSH.md)."
	echo "Formal push: $0 --ipk '$IPK' --push"
	exit 0
fi

TAG="v${VER}"
REPO_SLUG="$(_env_val CPE_GITHUB_REPO)"
[ -n "$REPO_SLUG" ] || REPO_SLUG="hk59775634/luci-app-gogogo"

git add -A
git add -u
git status --short
git commit -m "release: ${PKG_NAME} ${VER}" || true
git tag -f "$TAG"
git push -u origin HEAD
git push -f origin "$TAG"

if command -v gh >/dev/null 2>&1; then
	gh release delete "$TAG" -R "$REPO_SLUG" -y 2>/dev/null || true
	gh release create "$TAG" -R "$REPO_SLUG" \
		--title "$TAG" \
		--notes "${PKG_NAME} ${VER}" \
		"release/version.json" \
		"release/${IPK_NAME}"
	echo "GitHub Release: https://github.com/${REPO_SLUG}/releases/tag/${TAG}"
else
	echo "warn: gh not found; upload release/version.json and release/${IPK_NAME} manually"
fi
