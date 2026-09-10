# 国内 DoH（阿里 / 腾讯纯 IP + curl --resolve），不依赖本地 DNS

DOH_ALI_HOST="${DOH_ALI_HOST:-dns.alidns.com}"
DOH_ALI_IP="${DOH_ALI_IP:-223.5.5.5}"
DOH_ALI_IP2="${DOH_ALI_IP2:-223.6.6.6}"
DOH_TENCENT_HOST="${DOH_TENCENT_HOST:-doh.pub}"
DOH_TENCENT_IP="${DOH_TENCENT_IP:-119.29.29.29}"
DOH_TENCENT_IP2="${DOH_TENCENT_IP2:-119.28.28.28}"
DOH_CURL_TIMEOUT="${DOH_CURL_TIMEOUT:-5}"

_doh_extract_a() {
	local json="$1" ip
	[ -n "$json" ] || return 1
	if command -v jq >/dev/null 2>&1; then
		ip=$(echo "$json" | jq -r '
			.Answer[]? | select(.type == 1 or .type == "1") | .data
		' 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
	else
		ip=$(echo "$json" | grep -oE '"data"[[:space:]]*:[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"' | \
			head -1 | sed 's/.*"\([0-9][0-9.]*\)".*/\1/')
	fi
	[ -n "$ip" ] && echo "$ip"
}

# 阿里 HTTPS DoH
_doh_query_ali() {
	local host="$1" doh_ip="$2" json
	[ -n "$host" ] || return 1
	command -v curl >/dev/null 2>&1 || return 1
	[ -n "$doh_ip" ] || doh_ip="$DOH_ALI_IP"
	json=$(curl -fsSL --connect-timeout "$DOH_CURL_TIMEOUT" --max-time "$DOH_CURL_TIMEOUT" \
		--resolve "${DOH_ALI_HOST}:443:${doh_ip}" \
		"https://${DOH_ALI_HOST}/resolve?name=${host}&type=1" \
		-H "Accept: application/dns-json" \
		-H "Host: ${DOH_ALI_HOST}" 2>/dev/null) || return 1
	_doh_extract_a "$json"
}

# 阿里 HTTP DNS（纯 IP，无 TLS，作 HTTPS 失败时的后备）
_doh_query_ali_http() {
	local host="$1" doh_ip="$2" json
	[ -n "$host" ] || return 1
	command -v curl >/dev/null 2>&1 || return 1
	[ -n "$doh_ip" ] || doh_ip="$DOH_ALI_IP"
	json=$(curl -fsSL --connect-timeout "$DOH_CURL_TIMEOUT" --max-time "$DOH_CURL_TIMEOUT" \
		"http://${doh_ip}/resolve?name=${host}&type=1" 2>/dev/null) || return 1
	_doh_extract_a "$json"
}

# 腾讯 DNSPod：https://doh.pub/dns-query?name=HOST&type=A
_doh_query_tencent() {
	local host="$1" doh_ip="$2" json
	[ -n "$host" ] || return 1
	command -v curl >/dev/null 2>&1 || return 1
	[ -n "$doh_ip" ] || doh_ip="$DOH_TENCENT_IP"
	json=$(curl -fsSL --connect-timeout "$DOH_CURL_TIMEOUT" --max-time "$DOH_CURL_TIMEOUT" \
		--resolve "${DOH_TENCENT_HOST}:443:${doh_ip}" \
		"https://${DOH_TENCENT_HOST}/dns-query?name=${host}&type=A" \
		-H "Accept: application/dns-json" \
		-H "Host: ${DOH_TENCENT_HOST}" 2>/dev/null) || return 1
	_doh_extract_a "$json"
}

# 依次尝试阿里(两 IP)、腾讯(两 IP)
doh_resolve_host() {
	local host="$1" ip

	[ -n "$host" ] || return 1
	case "$host" in
		localhost | localhost.*) return 1 ;;
	esac
	case "$host" in
		[0-9]*.[0-9]*.[0-9]*.[0-9]*) echo "$host"; return 0 ;;
	esac

	ip=$(_doh_query_ali "$host" "$DOH_ALI_IP") && [ -n "$ip" ] && echo "$ip" && return 0
	ip=$(_doh_query_ali "$host" "$DOH_ALI_IP2") && [ -n "$ip" ] && echo "$ip" && return 0
	ip=$(_doh_query_ali_http "$host" "$DOH_ALI_IP") && [ -n "$ip" ] && echo "$ip" && return 0
	ip=$(_doh_query_ali_http "$host" "$DOH_ALI_IP2") && [ -n "$ip" ] && echo "$ip" && return 0
	ip=$(_doh_query_tencent "$host" "$DOH_TENCENT_IP") && [ -n "$ip" ] && echo "$ip" && return 0
	ip=$(_doh_query_tencent "$host" "$DOH_TENCENT_IP2") && [ -n "$ip" ] && echo "$ip" && return 0
	return 1
}
