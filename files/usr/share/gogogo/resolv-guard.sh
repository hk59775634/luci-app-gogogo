# shellcheck shell=sh
# 监视 /etc/resolv.conf：nameserver 为 127.0.0.1 时改为 WAN DNS 或国内备用，避免 DNS 黑洞
# 解析正常后写入 stamp，后续不再重复处理

[ -f /usr/share/gogogo/defaults.sh ] && . /usr/share/gogogo/defaults.sh
[ -f /usr/share/gogogo/wan-dns.sh ] && . /usr/share/gogogo/wan-dns.sh

CPE_RESOLV_CONF="${CPE_RESOLV_CONF:-/etc/resolv.conf}"
CPE_RESOLV_GUARD_STAMP="${CPE_RESOLV_GUARD_STAMP:-/tmp/gogogo.resolv.guard.stamp}"
CPE_RESOLV_OK_STAMP="${CPE_RESOLV_OK_STAMP:-/tmp/gogogo.resolv.ok}"
CPE_RESOLV_PROBE_HOST="${CPE_RESOLV_PROBE_HOST:-www.baidu.com}"
DNS_LOCAL_FALLBACK="${DNS_LOCAL_FALLBACK:-180.76.76.76}"

_log() {
	logger -t gogogo-resolv-guard "$*"
}

_resolv_realpath() {
	local f="$1" r
	[ -n "$f" ] || return 1
	if [ -L "$f" ]; then
		r=$(readlink -f "$f" 2>/dev/null) || r=$(readlink "$f" 2>/dev/null)
		[ -n "$r" ] && [ "${r#/}" = "$r" ] && r="/$r"
		[ -n "$r" ] && echo "$r" && return 0
	fi
	echo "$f"
}

_resolv_has_loopback_ns() {
	local f="$1"
	[ -f "$f" ] || return 1
	grep -qE '^[[:space:]]*nameserver[[:space:]]+127\.0\.0\.1([[:space:]]|$)' "$f" 2>/dev/null
}

_resolv_dns_ok() {
	local host="${1:-$CPE_RESOLV_PROBE_HOST}"
	command -v nslookup >/dev/null 2>&1 || return 0
	nslookup "$host" >/dev/null 2>&1
}

_resolv_pick_servers() {
	local dns list="" picked
	for dns in $(wan_dns_usable 2>/dev/null); do
		list="$list $dns"
	done
	list=$(echo "$list" | awk '{ for (i=1;i<=NF;i++) if (!seen[$i]++) print $i }')
	if [ -z "$list" ]; then
		echo "$DNS_LOCAL_FALLBACK"
		return 0
	fi
	picked=0
	for dns in $list; do
		picked=$((picked + 1))
		[ "$picked" -le 3 ] && echo "$dns"
	done
}

_resolv_write() {
	local f="$1" servers="$2" tmp search line
	tmp=$(mktemp /tmp/gogogo.resolv.XXXXXX)
	search=$(grep -E '^[[:space:]]*search[[:space:]]' "$f" 2>/dev/null | head -1)
	{
		[ -n "$search" ] && echo "$search"
		for line in $servers; do
			echo "nameserver $line"
		done
	} > "$tmp"
	if cmp -s "$tmp" "$f" 2>/dev/null; then
		rm -f "$tmp"
		return 1
	fi
	cp "$tmp" "$f"
	rm -f "$tmp"
	return 0
}

cpe_resolv_guard() {
	local real servers newstamp

	[ -f "$CPE_RESOLV_CONF" ] || [ -L "$CPE_RESOLV_CONF" ] || return 1
	real=$(_resolv_realpath "$CPE_RESOLV_CONF")
	[ -f "$real" ] || return 1

	if ! _resolv_has_loopback_ns "$real"; then
		if _resolv_dns_ok; then
			touch "$CPE_RESOLV_OK_STAMP"
			rm -f "$CPE_RESOLV_GUARD_STAMP" 2>/dev/null
			return 1
		fi
		rm -f "$CPE_RESOLV_OK_STAMP" 2>/dev/null
		return 1
	fi

	if [ -f "$CPE_RESOLV_OK_STAMP" ]; then
		rm -f "$CPE_RESOLV_OK_STAMP" 2>/dev/null
	fi

	servers=$(_resolv_pick_servers | tr '\n' ' ')
	newstamp=$(echo "$servers" | md5sum 2>/dev/null | awk '{print $1}')
	echo "$newstamp" > "$CPE_RESOLV_GUARD_STAMP"

	if _resolv_write "$real" "$servers"; then
		_log "replaced 127.0.0.1 in $real with $servers"
		if _resolv_dns_ok; then
			touch "$CPE_RESOLV_OK_STAMP"
		fi
		return 0
	fi

	if _resolv_dns_ok; then
		touch "$CPE_RESOLV_OK_STAMP"
	fi
	return 1
}

cpe_resolv_guard_status() {
	local real servers
	real=$(_resolv_realpath "$CPE_RESOLV_CONF" 2>/dev/null)
	echo "file=${real:-$CPE_RESOLV_CONF}"
	if [ -f "${real:-$CPE_RESOLV_CONF}" ]; then
		echo "loopback_ns=$(_resolv_has_loopback_ns "${real:-$CPE_RESOLV_CONF}" && echo yes || echo no)"
		grep -E '^nameserver|^search' "${real:-$CPE_RESOLV_CONF}" 2>/dev/null
	fi
	echo "wan_dns=$(wan_dns_list 2>/dev/null | tr '\n' ' ')"
	echo "fallback=$DNS_LOCAL_FALLBACK"
	echo "ok_stamp=$([ -f "$CPE_RESOLV_OK_STAMP" ] && echo yes || echo no)"
}
