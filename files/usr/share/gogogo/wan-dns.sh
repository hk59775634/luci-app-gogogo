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

# 过滤明显无效的 DNS（保留网关地址作 DNS，家庭路由常见）
wan_dns_usable() {
	local dns
	for dns in $(wan_dns_list); do
		case "$dns" in
			127.* | 0.0.0.0 | 255.* | ::*) continue ;;
		esac
		echo "$dns"
	done | awk '!seen[$0]++ { print }'
}
