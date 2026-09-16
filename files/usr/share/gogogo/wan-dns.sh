# shellcheck shell=sh
# 获取 WAN 口 DNS（DHCP / UCI 静态），供 dns-probe、resolv-guard 共用

[ -f /lib/functions/network.sh ] && . /lib/functions/network.sh

wan_dns_list() {
	local NET_IF dns uci_dns
	network_find_wan NET_IF || NET_IF="wan"
	dns=""
	network_get_dnsserver dns "$NET_IF" 1 2>/dev/null
	uci_dns=$(uci -q get "network.${NET_IF}.dns" 2>/dev/null)
	for uci_dns in $uci_dns $dns; do
		echo "$uci_dns"
	done | awk '!seen[$0]++ && $0 != "" { print }'
}

wan_gateway() {
	local NET_IF gw
	network_find_wan NET_IF || NET_IF="wan"
	network_get_gateway gw "${NET_IF}" 2>/dev/null
	[ -n "$gw" ] && echo "$gw"
}

# 过滤明显无效的 DNS。保留网关/私网地址：子路由场景下这就是内网权威 DNS。
wan_dns_usable() {
	local dns
	for dns in $(wan_dns_list); do
		case "$dns" in
			127.* | 0.0.0.0 | 255.* | ::*) continue ;;
		esac
		echo "$dns"
	done | awk '!seen[$0]++ { print }'
}

wan_dns_is_overseas_public() {
	case "$1" in
		8.8.8.8 | 8.8.4.4 | 1.1.1.1 | 1.0.0.1 | 9.9.9.9 | 149.112.112.112 | 208.67.222.222 | 208.67.220.220)
			return 0
			;;
	esac
	return 1
}

# 分流国内上游：WAN 上全部可用 DNS（排除海外公共解析器）。内网可能有多台、用途不同，不能只留一台。
wan_dns_direct() {
	local dns
	for dns in $(wan_dns_usable); do
		wan_dns_is_overseas_public "$dns" && continue
		echo "$dns"
	done | awk '!seen[$0]++ { print }'
}
