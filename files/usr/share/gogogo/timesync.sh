# shellcheck shell=sh
# 启动时校时：HTTP Date（不依赖 sysntpd/ntpd 守护进程），避免 TLS 证书日期错误
# HTTPS 探测正常后写入 stamp，后续不再重复校时

[ -f /usr/share/gogogo/defaults.sh ] && . /usr/share/gogogo/defaults.sh

CPE_TIME_MIN_YEAR="${CPE_TIME_MIN_YEAR:-2025}"
CPE_TIMESYNC_STAMP="${CPE_TIMESYNC_STAMP:-/tmp/gogogo.timesync.ok}"
CPE_HTTPS_PROBE_URL="${CPE_HTTPS_PROBE_URL:-https://www.baidu.com/}"

_log() {
	logger -t gogogo-timesync "$*"
}

_need_sync() {
	local y
	y=$(date +%Y 2>/dev/null)
	[ -z "$y" ] && return 0
	[ "$y" -lt "$CPE_TIME_MIN_YEAR" ] 2>/dev/null
}

_gogogo_https_ok() {
	local url="${1:-$CPE_HTTPS_PROBE_URL}"
	command -v curl >/dev/null 2>&1 || return 1
	curl -fsI --connect-timeout 5 --max-time 10 "$url" >/dev/null 2>&1
}

_parse_http_date() {
	local hdr="$1" epoch
	[ -n "$hdr" ] || return 1
	hdr=$(echo "$hdr" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
	epoch=$(date -u -D "%a, %d %b %Y %H:%M:%S %Z" -d "$hdr" +%s 2>/dev/null)
	[ -n "$epoch" ] && [ "$epoch" -gt 946684800 ] && echo "$epoch" && return 0
	epoch=$(date -u -D "%a, %d %b %Y %H:%M:%S GMT" -d "$hdr" +%s 2>/dev/null)
	[ -n "$epoch" ] && [ "$epoch" -gt 946684800 ] && echo "$epoch" && return 0
	return 1
}

_http_date_sync() {
	local url hdr epoch now skew
	command -v curl >/dev/null 2>&1 || return 1
	for url in \
		"http://www.aliyun.com/" \
		"http://www.baidu.com/" \
		"http://connectivitycheck.gstatic.com/generate_204" \
		"http://www.ntsc.ac.cn/"
	do
		hdr=$(curl -fsI --connect-timeout 5 --max-time 10 "$url" 2>/dev/null \
			| sed -n 's/^[Dd]ate:[[:space:]]*//p' | head -1)
		epoch=$(_parse_http_date "$hdr") || continue
		now=$(date +%s 2>/dev/null)
		[ -z "$now" ] && now=0
		skew=$((epoch > now ? epoch - now : now - epoch))
		[ "$skew" -lt 60 ] && return 0
		if date -s "@$epoch" >/dev/null 2>&1; then
			hwclock -w -u 2>/dev/null || hwclock -w 2>/dev/null || true
			_log "set time from HTTP Date ($url) epoch=$epoch"
			return 0
		fi
	done
	return 1
}

_ntp_oneshot_sync() {
	local ntpd_bin=""
	for ntpd_bin in /usr/sbin/ntpd /sbin/ntpd; do
		[ -x "$ntpd_bin" ] || continue
		if "$ntpd_bin" -n -N -q -p ntp.aliyun.com -p ntp1.aliyun.com 2>/dev/null; then
			hwclock -w -u 2>/dev/null || hwclock -w 2>/dev/null || true
			_log "set time via ntp one-shot ($ntpd_bin)"
			return 0
		fi
	done
	return 1
}

cpe_timesync() {
	local force="${1:-}"

	case "$force" in
		force) ;;
		*)
			if [ -f "$CPE_TIMESYNC_STAMP" ] && _gogogo_https_ok; then
				return 0
			fi
			if ! _need_sync && _gogogo_https_ok; then
				touch "$CPE_TIMESYNC_STAMP"
				return 0
			fi
			;;
	esac

	if ! _need_sync && _gogogo_https_ok; then
		touch "$CPE_TIMESYNC_STAMP"
		return 0
	fi

	_log "system year $(date +%Y 2>/dev/null), syncing time..."

	if _http_date_sync && _gogogo_https_ok; then
		touch "$CPE_TIMESYNC_STAMP"
		return 0
	fi

	if _ntp_oneshot_sync && _gogogo_https_ok; then
		touch "$CPE_TIMESYNC_STAMP"
		return 0
	fi

	rm -f "$CPE_TIMESYNC_STAMP" 2>/dev/null
	_log "time sync failed or HTTPS still broken, will retry later"
	return 1
}
