# curl --resolve 辅助：经 cpe-dns-probe（含国内 DoH）解析，避免本地 DNS 错误

[ -f /usr/share/gogogo/defaults.sh ] && . /usr/share/gogogo/defaults.sh

gogogo_get_base_url() {
	if [ -x /usr/sbin/gogogo-url ]; then
		local u
		u=$(/usr/sbin/gogogo-url get 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		[ -n "$u" ] && echo "$u" && return 0
	fi
	echo "${CPE_DEFAULT_URL_FALLBACK:-https://cpe.gogogofuture.com}"
}

gogogo_url_host() {
	echo "$1" | sed -e 's|^[a-zA-Z]*://||' -e 's|/.*||' -e 's|:.*||'
}

gogogo_url_port() {
	local u="$1" p
	u=$(echo "$1" | sed -e 's|^[a-zA-Z]*://||' -e 's|/.*||')
	p=$(echo "$u" | sed -n 's/.*:\([0-9]*\)$/\1/p')
	if [ -n "$p" ]; then
		echo "$p"
	elif echo "$1" | grep -q '^https:'; then
		echo 443
	else
		echo 80
	fi
}

# 须仅用 DoH 解析的域名（防 DNS 污染），逗号分隔，可在 env 覆盖
_gogogo_host_requires_doh() {
	local host="$1" entry
	host=$(echo "$host" | tr '[:upper:]' '[:lower:]')
	for entry in $(echo "${CPE_DOH_FORCE_HOSTS:-gh-proxy.com}" | tr ',' ' '); do
		entry=$(echo "$entry" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
		[ -z "$entry" ] && continue
		[ "$host" = "$entry" ] && return 0
		case "$host" in
			*."${entry}") return 0 ;;
		esac
	done
	return 1
}

# 仅国内 DoH（阿里/腾讯），不走 WAN/系统 DNS
gogogo_resolve_host_via_doh() {
	local host="$1" ip
	[ -n "$host" ] || return 1
	case "$host" in
		[0-9]*.[0-9]*.[0-9]*.[0-9]*) echo "$host"; return 0 ;;
	esac
	if [ -x /usr/sbin/gogogo-dns-probe ]; then
		ip=$(/usr/sbin/gogogo-dns-probe doh "$host" 2>/dev/null)
		[ -n "$ip" ] && echo "$ip" && return 0
	fi
	if command -v doh_resolve_host >/dev/null 2>&1; then
		ip=$(doh_resolve_host "$host")
		[ -n "$ip" ] && echo "$ip" && return 0
	fi
	return 1
}

# 解析主机 A 记录：加速域名强制 DoH；其余 DoH 优先再 WAN（见 cpe-dns-probe resolve）
gogogo_resolve_host() {
	local host="$1"
	[ -n "$host" ] || return 1
	case "$host" in
		[0-9]*.[0-9]*.[0-9]*.[0-9]*) echo "$host"; return 0 ;;
	esac
	if _gogogo_host_requires_doh "$host"; then
		gogogo_resolve_host_via_doh "$host" && return 0
		return 1
	fi
	if [ -x /usr/sbin/gogogo-dns-probe ]; then
		/usr/sbin/gogogo-dns-probe resolve "$host" 2>/dev/null && return 0
	fi
	return 1
}

# 输出 curl --resolve 参数（无则空）
gogogo_curl_resolve_args() {
	local url="$1" host port ip
	[ -n "$url" ] || return 0
	host=$(gogogo_url_host "$url")
	port=$(gogogo_url_port "$url")
	ip=$(gogogo_resolve_host "$host") || return 0
	echo "--resolve ${host}:${port}:${ip}"
}

# 用法: gogogo_curl "$url" [curl 选项...]（优先 DoH + --resolve；加速域名禁止污染 DNS 直连）
gogogo_curl() {
	local url="$1" resolve host
	[ -n "$url" ] || return 1
	shift
	host=$(gogogo_url_host "$url")
	resolve=$(gogogo_curl_resolve_args "$url")
	if _gogogo_host_requires_doh "$host"; then
		if [ -z "$resolve" ]; then
			logger -t gogogo-curl "DoH required for ${host}, resolve failed (no direct fallback)"
			return 1
		fi
		# shellcheck disable=SC2086
		curl $resolve "$@" "$url"
		return $?
	fi
	if [ -n "$resolve" ]; then
		# shellcheck disable=SC2086
		curl $resolve "$@" "$url" && return 0
		logger -t gogogo-curl "DoH resolve failed for ${host}, fallback direct"
	fi
	curl "$@" "$url"
}
