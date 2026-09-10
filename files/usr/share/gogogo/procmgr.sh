# CPE 进程管理：flock 文件锁 + PID 文件 + /proc cmdline 校验（单实例 cpe / cped）

CPE_MAIN_LOCK="${CPE_MAIN_LOCK:-/tmp/gogogo.main.flock}"
CPE_MAIN_PIDFILE="${CPE_MAIN_PIDFILE:-/tmp/gogogo.pid}"
CPED_LOCK="${CPED_LOCK:-/tmp/gogogod.flock}"
CPED_PIDFILE="${CPED_PIDFILE:-/tmp/gogogod.pid}"

# 兼容旧路径清理
CPE_START_LOCK="${CPE_START_LOCK:-/tmp/gogogo.start.lock}"

_gogogo_cmdline_n() {
	local pid="$1" n="${2:-1}"
	tr '\0' '\n' < "/proc/${pid}/cmdline" 2>/dev/null | sed -n "${n}p"
}

# 仅匹配：/bin/sh /usr/sbin/gogogo start 或 /usr/sbin/gogogo start
_gogogo_is_main_pid() {
	local pid="$1" a0 a1 a2
	[ -n "$pid" ] || return 1
	[ -d "/proc/${pid}" ] || return 1
	a0=$(_gogogo_cmdline_n "$pid" 1)
	a1=$(_gogogo_cmdline_n "$pid" 2)
	a2=$(_gogogo_cmdline_n "$pid" 3)
	case "$a0" in
		/bin/sh|/bin/ash)
			case "$a1" in
				/usr/sbin/gogogo|/sbin/gogogo) [ "$a2" = "start" ] && return 0 ;;
			esac
			return 1
			;;
	esac
	case "$a0" in
		/usr/sbin/gogogo|/sbin/gogogo) [ "$a1" = "start" ] && return 0 ;;
	esac
	return 1
}

_gogogo_is_cped_pid() {
	local pid="$1" a0 a1 a2
	[ -n "$pid" ] || return 1
	[ -d "/proc/${pid}" ] || return 1
	a0=$(_gogogo_cmdline_n "$pid" 1)
	a1=$(_gogogo_cmdline_n "$pid" 2)
	a2=$(_gogogo_cmdline_n "$pid" 3)
	case "$a0" in
		/bin/sh|/bin/ash)
			case "$a1" in
				/usr/sbin/gogogod|/sbin/gogogod) [ "$a2" = "start" ] && return 0 ;;
			esac
			return 1
			;;
	esac
	case "$a0" in
		/usr/sbin/gogogod|/sbin/gogogod) [ "$a1" = "start" ] && return 0 ;;
	esac
	return 1
}

_gogogo_main_pids() {
	local pid
	for pid in /proc/[0-9]*; do
		pid=${pid#/proc/}
		_gogogo_is_main_pid "$pid" && echo "$pid"
	done
}

_gogogo_cped_pids() {
	local pid
	for pid in /proc/[0-9]*; do
		pid=${pid#/proc/}
		_gogogo_is_cped_pid "$pid" && echo "$pid"
	done
}

_gogogo_read_pidfile() {
	local f="$1" p
	[ -f "$f" ] || return 1
	p=$(cat "$f" 2>/dev/null | tr -d '[:space:]')
	[ -n "$p" ] || return 1
	echo "$p"
}

_gogogo_main_alive() {
	local pid
	pid=$(_gogogo_read_pidfile "$CPE_MAIN_PIDFILE") || return 1
	_gogogo_is_main_pid "$pid" && kill -0 "$pid" 2>/dev/null
}

_gogogo_cped_alive() {
	local pid
	pid=$(_gogogo_read_pidfile "$CPED_PIDFILE") || return 1
	_gogogo_is_cped_pid "$pid" && kill -0 "$pid" 2>/dev/null
}

_gogogo_lock_try() {
	# $1=fd $2=lockfile；成功占用返回 0（须在同一 shell 保持 fd 打开）
	eval "exec $1>\"\$2\""
	flock -n "$1" 2>/dev/null
}

_gogogo_lock_release() {
	# $1=fd
	flock -u "$1" 2>/dev/null
	eval "exec $1>&-"
}

_gogogo_cleanup_legacy_lock() {
	rmdir "$CPE_START_LOCK" 2>/dev/null
}

# cpe 主循环：获取独占锁（由 cpe.sh _start 调用，锁持有至进程结束）
_gogogo_main_acquire_lock() {
	local pid

	_gogogo_cleanup_legacy_lock

	if _gogogo_main_alive; then
		return 1
	fi

	if ! _gogogo_lock_try 9 "$CPE_MAIN_LOCK"; then
		if _gogogo_main_alive; then
			return 1
		fi
		_gogogo_main_stop_all
		if ! _gogogo_lock_try 9 "$CPE_MAIN_LOCK"; then
			return 1
		fi
	fi

	pid=$$
	echo "$pid" > "$CPE_MAIN_PIDFILE"
	_gogogo_kill_duplicate_mains "$pid"
	return 0
}

_gogogo_main_release_lock() {
	rm -f "$CPE_MAIN_PIDFILE" 2>/dev/null
	_gogogo_lock_release 9
	_gogogo_cleanup_legacy_lock
}

_gogogo_kill_duplicate_mains() {
	local keep="${1:-}" pid
	keep=${keep:-$(_gogogo_read_pidfile "$CPE_MAIN_PIDFILE")}
	[ -z "$keep" ] && keep=$(_gogogo_main_pids | sort -n | head -1)
	[ -z "$keep" ] && return 0
	for pid in $(_gogogo_main_pids); do
		[ "$pid" = "$keep" ] && continue
		kill -9 "$pid" 2>/dev/null
	done
	echo "$keep" > "$CPE_MAIN_PIDFILE"
}

_gogogo_main_stop_all() {
	local pid wait="${CPE_KILL_WAIT_SEC:-1}"
	for pid in $(_gogogo_main_pids); do
		kill "$pid" 2>/dev/null
	done
	[ "$wait" != "0" ] && sleep "$wait"
	for pid in $(_gogogo_main_pids); do
		kill -9 "$pid" 2>/dev/null
	done
	rm -f "$CPE_MAIN_PIDFILE" "$CPE_MAIN_LOCK" 2>/dev/null
	_gogogo_cleanup_legacy_lock
}

# cped 看门狗单实例
_gogogo_cped_acquire_lock() {
	local pid

	if _gogogo_cped_alive; then
		return 1
	fi

	if ! _gogogo_lock_try 8 "$CPED_LOCK"; then
		if _gogogo_cped_alive; then
			return 1
		fi
		_gogogo_cped_stop_all
		if ! _gogogo_lock_try 8 "$CPED_LOCK"; then
			return 1
		fi
	fi

	pid=$$
	echo "$pid" > "$CPED_PIDFILE"
	_gogogo_kill_duplicate_cped "$pid"
	return 0
}

_gogogo_cped_release_lock() {
	rm -f "$CPED_PIDFILE" 2>/dev/null
	_gogogo_lock_release 8
}

_gogogo_kill_duplicate_cped() {
	local keep="${1:-}" pid
	keep=${keep:-$(_gogogo_read_pidfile "$CPED_PIDFILE")}
	[ -z "$keep" ] && keep=$(_gogogo_cped_pids | sort -n | head -1)
	[ -z "$keep" ] && return 0
	for pid in $(_gogogo_cped_pids); do
		[ "$pid" = "$keep" ] && continue
		kill -9 "$pid" 2>/dev/null
	done
	echo "$keep" > "$CPED_PIDFILE"
}

_gogogo_cped_stop_all() {
	local pid wait="${CPE_KILL_WAIT_SEC:-1}"
	for pid in $(_gogogo_cped_pids); do
		kill "$pid" 2>/dev/null
	done
	[ "$wait" != "0" ] && sleep "$wait"
	for pid in $(_gogogo_cped_pids); do
		kill -9 "$pid" 2>/dev/null
	done
	rm -f "$CPED_PIDFILE" "$CPED_LOCK" 2>/dev/null
}

# 看门狗：仅在无主进程时拉起（BusyBox flock 无 -w，用 flock FILE -c + 重试）
_gogogo_main_ensure_running() {
	local spawn_lock="/tmp/gogogo.spawn.lock" i=0

	_gogogo_main_alive && return 0

	while [ "$i" -lt 8 ]; do
		flock -n "$spawn_lock" sh -c '
			. /usr/share/gogogo/procmgr.sh 2>/dev/null
			_gogogo_main_alive && exit 0
			[ -x /usr/sbin/gogogo ] && /usr/sbin/gogogo start >/dev/null 2>&1 &
		' 2>/dev/null || true
		_gogogo_main_alive && return 0
		sleep 1
		i=$((i + 1))
	done
	return 1
}

# 兼容旧名
_is_gogogo_main_cmd() { _gogogo_is_main_pid "$1"; }
_gogogo_pick_main_pid() { _gogogo_main_pids | sort -n | head -1; }
_gogogo_acquire_start_lock() { _gogogo_main_acquire_lock; }
_gogogo_release_start_lock() { _gogogo_main_release_lock; }
_gogogo_start_lock_held() { _gogogo_main_alive; }

# flock -n 单实例执行；锁被占用则静默跳过（exit 0）
_gogogo_flock_run() {
	local lock="$1"
	shift
	(
		flock -n 9 || exit 0
		"$@"
	) 9>"$lock"
}
