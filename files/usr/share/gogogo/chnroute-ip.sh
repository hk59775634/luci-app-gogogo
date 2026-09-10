# shellcheck shell=sh
# 用 /etc/gogogo_chnroutes 判断 IPv4 是否国内网段

CHNROUTE_FILE="${CHNROUTE_FILE:-/etc/gogogo_chnroutes}"

# 命中 chnroutes 返回 0，否则 1
chnroute_ip_in_cn() {
	local ip="$1" file="${2:-$CHNROUTE_FILE}"
	[ -n "$ip" ] || return 1
	[ -f "$file" ] || return 1
	awk -v ip="$ip" '
		function ip2int(s, a) {
			n = split(s, a, ".")
			if (n != 4) return -1
			return a[1] * 16777216 + a[2] * 65536 + a[3] * 256 + a[4]
		}
		function in_cidr(ip, cidr, c, prefix, ipn, netn, div) {
			split(cidr, c, "/")
			prefix = c[2] + 0
			ipn = ip2int(ip)
			netn = ip2int(c[1])
			if (ipn < 0 || netn < 0) return 0
			if (prefix <= 0) return 1
			if (prefix >= 32) return ipn == netn
			div = 2 ^ (32 - prefix)
			return int(ipn / div) == int(netn / div)
		}
		BEGIN {
			if (ip2int(ip) < 0) exit 1
			found = 0
		}
		/^[0-9]/ {
			if (in_cidr(ip, $1)) found = 1
		}
		END { exit(found ? 0 : 1) }
	' "$file"
}
