#!/bin/sh
# 生成 version.json + manifest.json，并可选上传客户端 ipk 与固件。
# 完整更新（推荐）：--ipk --sysupgrade [--factory] --push
# 用法见 PUSH.md

set -e
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

_env_val() {
	grep -m1 "^${1}=" ./env 2>/dev/null | sed 's/^[^=]*=//;s/^[[:space:]]*//;s/[[:space:]]*$//;s/^:=//'
}

_theme_ver() {
	local mk="$ROOT/../luci-theme-gogogo/Makefile"
	[ -f "$mk" ] || return 0
	sed -n 's/^PKG_VERSION:=[[:space:]]*//p' "$mk" | head -1
}

PKG_NAME="$(_env_val CPE_PKG_NAME)"
[ -n "$PKG_NAME" ] || PKG_NAME="luci-app-gogogo"
IPK=""
SYSUPGRADE=""
FACTORY=""
FW_VER=""
NOTES_FILE="$ROOT/RELEASE_NOTES"
PUSH_GIT=0
BOARD="mt7981-spim-nand-rfb"

while [ $# -gt 0 ]; do
	case "$1" in
		--ipk) IPK=$2; shift 2 ;;
		--sysupgrade) SYSUPGRADE=$2; shift 2 ;;
		--factory) FACTORY=$2; shift 2 ;;
		--fw-version) FW_VER=$2; shift 2 ;;
		--board) BOARD=$2; shift 2 ;;
		--notes-file) NOTES_FILE=$2; shift 2 ;;
		--push) PUSH_GIT=1; shift ;;
		-h|--help)
			echo "Usage: $0 --ipk <app.ipk> [--sysupgrade <sysupgrade.bin>] [--factory <factory.bin>] [--fw-version X] [--push]" >&2
			exit 0
			;;
		*) echo "Unknown arg: $1" >&2; exit 1 ;;
	esac
done

[ -n "$IPK" ] && [ -f "$IPK" ] || {
	echo "error: --ipk required and must exist" >&2
	exit 1
}

if [ "$PUSH_GIT" = 1 ] && [ -z "$SYSUPGRADE" ]; then
	echo "error: --push 需要 --sysupgrade，完整更新必须同时发布客户端和固件" >&2
	exit 1
fi

[ -z "$SYSUPGRADE" ] || [ -f "$SYSUPGRADE" ] || {
	echo "error: --sysupgrade not found: $SYSUPGRADE" >&2
	exit 1
}
[ -z "$FACTORY" ] || [ -f "$FACTORY" ] || {
	echo "error: --factory not found: $FACTORY" >&2
	exit 1
}

APP_VER=$(basename "$IPK" | sed -n "s/^${PKG_NAME}_\\([0-9]\\{10\\}\\)\\(-[0-9]\\+\\)\\?_all\\.ipk\$/\\1/p")
[ -n "$APP_VER" ] || APP_VER="$(_env_val CPE_PKG_VERSION)"
[ -n "$APP_VER" ] || {
	echo "error: cannot detect app version from ipk name or env" >&2
	exit 1
}

[ -n "$FW_VER" ] || FW_VER="$(_theme_ver)"
[ -n "$FW_VER" ] || FW_VER="$APP_VER"

IPK_SHA=$(sha256sum "$IPK" | awk '{print $1}')
IPK_NAME=$(basename "$IPK")
IPK_SIZE=$(wc -c <"$IPK" | tr -d ' ')

mkdir -p manifest release
# 设备守护进程 gogogo-update 读 version.json
printf '%s\n' "{\"version\":\"$APP_VER\",\"url\":\"$IPK_NAME\",\"sha256\":\"$IPK_SHA\"}" >"$ROOT/manifest/version.json"
cp -f "$ROOT/manifest/version.json" "$ROOT/release/version.json"
cp -f "$IPK" "$ROOT/release/$IPK_NAME"

SYSU_NAME=""
SYSU_SHA=""
SYSU_SIZE=0
if [ -n "$SYSUPGRADE" ]; then
	SYSU_NAME=$(basename "$SYSUPGRADE")
	SYSU_SHA=$(sha256sum "$SYSUPGRADE" | awk '{print $1}')
	SYSU_SIZE=$(wc -c <"$SYSUPGRADE" | tr -d ' ')
	cp -f "$SYSUPGRADE" "$ROOT/release/$SYSU_NAME"
fi

FACT_NAME=""
FACT_SHA=""
FACT_SIZE=0
if [ -n "$FACTORY" ]; then
	FACT_NAME=$(basename "$FACTORY")
	FACT_SHA=$(sha256sum "$FACTORY" | awk '{print $1}')
	FACT_SIZE=$(wc -c <"$FACTORY" | tr -d ' ')
	cp -f "$FACTORY" "$ROOT/release/$FACT_NAME"
fi

MANIFEST_JSON="$ROOT/manifest/manifest.json"
python3 - "$MANIFEST_JSON" "$FW_VER" "$APP_VER" "$IPK_NAME" "$IPK_SHA" "$IPK_SIZE" \
	"$SYSU_NAME" "$SYSU_SHA" "$SYSU_SIZE" "$FACT_NAME" "$FACT_SHA" "$FACT_SIZE" "$BOARD" "$NOTES_FILE" <<'PY'
import json, os, sys
out, fw_ver, app_ver, ipk_name, ipk_sha, ipk_size = sys.argv[1:7]
sysu_name, sysu_sha, sysu_size, fact_name, fact_sha, fact_size, board, notes_file = sys.argv[7:]
notes = ""
if notes_file and os.path.isfile(notes_file):
    with open(notes_file, "r", encoding="utf-8") as nf:
        notes = nf.read()
doc = {
    "tag": "v" + fw_ver,
    "version": fw_ver,
    "notes": notes,
    "gogogo": {
        "version": app_ver,
        "filename": ipk_name,
        "size": int(ipk_size or 0),
        "sha256": ipk_sha,
    },
}
if sysu_name:
    doc["firmware"] = {
        "version": fw_ver,
        "board": board,
        "filename": sysu_name,
        "size": int(sysu_size or 0),
        "sha256": sysu_sha,
    }
if fact_name:
    doc["factory"] = {
        "version": fw_ver,
        "board": board,
        "filename": fact_name,
        "size": int(fact_size or 0),
        "sha256": fact_sha,
    }
with open(out, "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
cp -f "$MANIFEST_JSON" "$ROOT/release/manifest.json"

echo "app version.json: $ROOT/manifest/version.json"
echo "ui manifest.json: $MANIFEST_JSON"
echo "app=$APP_VER firmware=$FW_VER tag=v${FW_VER}"
echo "release/: version.json manifest.json $IPK_NAME ${SYSU_NAME} ${FACT_NAME}"

if [ "$PUSH_GIT" != 1 ]; then
	echo ""
	echo "Local manifest/release ready. No git/github action (see PUSH.md)."
	echo "Formal push: $0 --ipk '$IPK' --sysupgrade '$SYSUPGRADE' --factory '$FACTORY' --push"
	exit 0
fi

TAG="v${FW_VER}"
REPO_SLUG="$(_env_val CPE_GITHUB_REPO)"
[ -n "$REPO_SLUG" ] || REPO_SLUG="hk59775634/luci-app-gogogo"

git add -A
git add -u
git status --short
git commit -m "release: ${PKG_NAME} ${APP_VER} / firmware ${FW_VER}" || true
git tag -f "$TAG"
git push -u origin HEAD
git push -f origin "$TAG"

ASSETS="release/version.json release/manifest.json release/${IPK_NAME}"
[ -n "$SYSU_NAME" ] && ASSETS="$ASSETS release/${SYSU_NAME}"
[ -n "$FACT_NAME" ] && ASSETS="$ASSETS release/${FACT_NAME}"

if command -v gh >/dev/null 2>&1; then
	gh release delete "$TAG" -R "$REPO_SLUG" -y 2>/dev/null || true
	# shellcheck disable=SC2086
	if [ -f "$NOTES_FILE" ]; then
		gh release create "$TAG" -R "$REPO_SLUG" \
			--title "$TAG" \
			--notes-file "$NOTES_FILE" \
			$ASSETS
	else
		gh release create "$TAG" -R "$REPO_SLUG" \
			--title "$TAG" \
			--notes "${PKG_NAME} ${APP_VER} / firmware ${FW_VER}" \
			$ASSETS
	fi
	echo "GitHub Release: https://github.com/${REPO_SLUG}/releases/tag/${TAG}"
else
	echo "warn: gh not found; upload release assets manually"
fi
