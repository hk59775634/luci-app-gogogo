module("luci.controller.gogogo", package.seeall)

local http = require "luci.http"
local sys = require "luci.sys"
local util = require "luci.util"
local jsonc = require "luci.jsonc"
local dispatcher = require "luci.dispatcher"

function index()
	entry({"admin", "gogogo"}, firstchild(), "VPN", 60).dependent = false
	entry({"admin", "gogogo", "config"}, call("action_index"), "跨境加速", 1)
	entry({"admin", "gogogo", "diagnostics"}, template("gogogo/diagnostics"), "连接诊断", 2)
	entry({"admin", "gogogo", "status"}, call("action_status")).leaf = true
	entry({"admin", "gogogo", "login"}, call("action_login")).leaf = true
	entry({"admin", "gogogo", "connect"}, call("action_connect")).leaf = true
	entry({"admin", "gogogo", "disconnect"}, call("action_disconnect")).leaf = true
	entry({"admin", "gogogo", "save"}, call("action_save")).leaf = true
	entry({"admin", "gogogo", "refresh_account"}, call("action_refresh_account")).leaf = true
	entry({"admin", "gogogo", "direction_status"}, call("action_direction_status")).leaf = true
	entry({"admin", "gogogo", "set_direction"}, call("action_set_direction")).leaf = true
	entry({"admin", "gogogo", "portal_captcha"}, call("action_portal_captcha")).leaf = true
	entry({"admin", "gogogo", "shop_status"}, call("action_shop_status")).leaf = true
	entry({"admin", "gogogo", "shop_catalog"}, call("action_shop_catalog")).leaf = true
	entry({"admin", "gogogo", "shop_buy"}, call("action_shop_buy")).leaf = true
	entry({"admin", "gogogo", "shop_renew"}, call("action_shop_renew")).leaf = true
	entry({"admin", "gogogo", "diag_start"}, call("action_diag_start")).leaf = true
	entry({"admin", "gogogo", "diag_poll"}, call("action_diag_poll")).leaf = true
end

local function sh_quote(s)
	return "'" .. tostring(s or ""):gsub("'", "'\\''") .. "'"
end

local function scrub(s)
	s = tostring(s or "")
	s = s:gsub("%c", ""):gsub("\127", "")
	s = s:gsub("\239\187\191", "")
	s = s:gsub("\226\128\139", "")
	s = s:gsub("\226\128\140", "")
	s = s:gsub("\226\128\141", "")
	s = s:gsub("\194\160", " ")
	s = s:gsub("\227\128\128", " ")
	s = util.trim(s)
	s = s:gsub("^[\"'`<]+", ""):gsub("[\"'`>]+$", "")
	return util.trim(s)
end

local function valid_account(a)
	a = scrub(a)
	if a == "" or a:match("%s") then
		return nil
	end
	if a:match("^[%w%._@%+%-]+$") then
		return a
	end
	return nil
end

local function valid_password(p)
	p = scrub(p)
	if p ~= "" and not p:match("[%c%$`\\]") then
		return p
	end
	return nil
end

local function uci_get(opt)
	return scrub(sys.exec("uci -q get gogogo.@default[0]." .. opt) or "")
end

local function reset_exit_if_changed(old_account, account)
	if not account or account == "" then
		return
	end
	old_account = scrub(old_account)
	if old_account ~= "" and account ~= old_account then
		sys.call("/usr/sbin/gogogo reset_exit >/dev/null 2>&1")
	end
end

local function valid_flag(v)
	v = scrub(v)
	if v == "1" or v == "0" then
		return v
	end
	return nil
end

local function valid_direction(v)
	v = scrub(v)
	if v == "us" or v == "hk" then
		return v
	end
	return nil
end

local function valid_captcha(v)
	v = scrub(v)
	if v:match("^[%w]+$") and #v >= 3 and #v <= 8 then
		return v
	end
	return nil
end

local function valid_product_id(v)
	v = scrub(v)
	if v:match("^[0-9]+$") and #v <= 12 then
		return v
	end
	return nil
end

local function valid_month(v)
	v = scrub(v)
	local n = tonumber(v)
	if n and n >= 1 and n <= 12 then
		return tostring(n)
	end
	return nil
end

local function uci_set(opt, val)
	if val == nil then
		return
	end
	sys.call("uci -q set gogogo.@default[0]." .. opt .. "=" .. sh_quote(val))
end

local function uci_commit()
	sys.call("uci commit gogogo >/dev/null")
end

local function run_json(cmd)
	local raw = util.trim(sys.exec(cmd .. " 2>/dev/null") or "")
	local e = jsonc.parse(raw)
	if type(e) ~= "table" then
		local blob = raw:match("(%{.*%})%s*$")
		e = blob and jsonc.parse(blob)
	end
	if type(e) ~= "table" then
		e = { ok = false, msg = (raw ~= "" and raw or "无有效响应") }
	end
	return e
end

local function read_status_cache_json()
	local f = io.open("/var/run/gogogo/status.json", "r")
	if not f then
		return "{}"
	end
	local raw = util.trim(f:read("*a") or "")
	f:close()
	if raw ~= "" and type(jsonc.parse(raw)) == "table" then
		return raw
	end
	return "{}"
end

function action_index()
	local query_url = http.formvalue("url")
	if query_url and query_url ~= "" then
		query_url = util.trim(tostring(query_url)):gsub("/+$", "")
		if query_url:match("^https?://[%w%-%.:/%%?&=#]+$") then
			sys.call("/usr/sbin/gogogo-url set " .. sh_quote(query_url) .. " >/dev/null")
			http.redirect(dispatcher.build_url("admin", "gogogo", "config"))
			return
		end
	end
	sys.call("/usr/sbin/gogogo-cred sync >/dev/null 2>&1 &")
	luci.template.render("gogogo/main", {
		status_cache_json = read_status_cache_json()
	})
end

function action_status()
	http.prepare_content("application/json")
	http.write_json(run_json("/usr/sbin/gogogo status"))
end

function action_save()
	local account = valid_account(http.formvalue("account"))
	local password = valid_password(http.formvalue("password"))
	local enable = valid_flag(http.formvalue("enable") or "")
	local split = valid_flag(http.formvalue("split") or "")
	local killswitch = valid_flag(http.formvalue("killswitch") or "")
	local old_account = uci_get("username")

	if account then
		uci_set("username", account)
		reset_exit_if_changed(old_account, account)
	end
	if password then
		uci_set("password", password)
	end
	if enable then
		uci_set("enable", enable)
	end
	if split then
		uci_set("tunnelall", split == "1" and "0" or "1")
	end
	if killswitch then
		uci_set("dnsleak", killswitch)
	end
	uci_commit()
	os.execute("/usr/sbin/gogogo-cred sync >/dev/null 2>&1 &")
	os.execute("/usr/sbin/gogogo-luci-after-save >/dev/null 2>&1 &")

	http.prepare_content("application/json")
	http.write_json(run_json("/usr/sbin/gogogo status"))
end

function action_login()
	local account = valid_account(http.formvalue("account"))
	local password = valid_password(http.formvalue("password"))
	local enable = valid_flag(http.formvalue("enable") or "")
	local old_account = uci_get("username")

	if account then
		uci_set("username", account)
		reset_exit_if_changed(old_account, account)
	end
	if password then
		uci_set("password", password)
	end
	if enable then
		uci_set("enable", enable)
	end
	uci_commit()

	os.execute("/usr/sbin/gogogo-cred sync >/dev/null 2>&1 &")
	os.execute("mkdir -p /var/run/gogogo; date +%s > /var/run/gogogo/login.job; rm -f /var/run/gogogo/login.result; /usr/sbin/gogogo login >/dev/null 2>&1 &")
	http.prepare_content("application/json")
	http.write_json({
		ok = true,
		pending = true,
		msg = "正在登录",
		account = account or ""
	})
end

function action_connect()
	local account = valid_account(http.formvalue("account"))
	local password = valid_password(http.formvalue("password"))
	local split = valid_flag(http.formvalue("split") or "")
	local killswitch = valid_flag(http.formvalue("killswitch") or "")
	local old_account = uci_get("username")

	if account then
		uci_set("username", account)
		reset_exit_if_changed(old_account, account)
	end
	if password then
		uci_set("password", password)
	end
	if split then
		uci_set("tunnelall", split == "1" and "0" or "1")
	end
	if killswitch then
		uci_set("dnsleak", killswitch)
	end
	uci_commit()

	os.execute("/usr/sbin/gogogo connect >/dev/null 2>&1 &")
	http.prepare_content("application/json")
	http.write_json({
		ok = true,
		pending = true,
		msg = "正在连接"
	})
end

function action_disconnect()
	http.prepare_content("application/json")
	http.write_json(run_json("/usr/sbin/gogogo disconnect"))
end

local function diag_json(cmd)
	local raw = util.trim(sys.exec("/usr/sbin/gogogo-luci-diag " .. cmd .. " 2>/dev/null") or "")
	local e = jsonc.parse(raw)
	if type(e) ~= "table" then
		e = { state = "idle", vpn_healthy = false, faults = {}, steps = {} }
	end
	return e
end

function action_diag_start()
	http.prepare_content("application/json")
	local e = diag_json("start")
	if e.state ~= "running" and e.state ~= "done" then
		e = {
			state = "running",
			vpn_healthy = false,
			progress = 0,
			progress_total = 27,
			progress_pct = 0,
			faults = {},
			steps = {},
			current = { title = "准备诊断", detail = "正在启动" },
		}
	end
	http.write_json(e)
end

function action_diag_poll()
	http.prepare_content("application/json")
	http.write_json(diag_json("poll"))
end

function action_refresh_account()
	http.prepare_content("application/json")
	http.write_json(run_json("/usr/sbin/gogogo refresh_account"))
end

function action_direction_status()
	local code = valid_captcha(http.formvalue("code") or "")
	local cmd = "/usr/sbin/gogogo direction_status"
	if code then
		cmd = cmd .. " " .. sh_quote(code)
	end
	http.prepare_content("application/json")
	http.write_json(run_json(cmd))
end

function action_set_direction()
	local dir = valid_direction(http.formvalue("direction"))
	local code = valid_captcha(http.formvalue("code") or "")
	http.prepare_content("application/json")
	if not dir then
		http.write_json({ ok = false, msg = "线路参数无效" })
		return
	end
	local cmd = "/usr/sbin/gogogo set_direction " .. sh_quote(dir)
	if code then
		cmd = cmd .. " " .. sh_quote(code)
	end
	http.write_json(run_json(cmd))
end

function action_portal_captcha()
	os.execute("/usr/sbin/gogogo portal_captcha >/dev/null 2>&1")
	local f = io.open("/var/run/gogogo/portal_captcha.png", "r")
	if not f then
		http.status(404, "Not Found")
		http.prepare_content("application/json")
		http.write_json({ ok = false, msg = "验证码获取失败" })
		return
	end
	local data = f:read("*a") or ""
	f:close()
	if data == "" then
		http.status(404, "Not Found")
		http.prepare_content("application/json")
		http.write_json({ ok = false, msg = "验证码获取失败" })
		return
	end
	http.header("Cache-Control", "no-store, no-cache")
	http.header("Pragma", "no-cache")
	http.prepare_content("image/png")
	http.write(data)
end

function action_shop_status()
	http.prepare_content("application/json")
	http.write_json(run_json("/usr/sbin/gogogo shop_status"))
end

function action_shop_catalog()
	local code = valid_captcha(http.formvalue("code") or "")
	local cmd = "/usr/sbin/gogogo shop_catalog"
	if code then
		cmd = cmd .. " " .. sh_quote(code)
	end
	http.prepare_content("application/json")
	http.write_json(run_json(cmd))
end

function action_shop_buy()
	local pid = valid_product_id(http.formvalue("product_id"))
	local month = valid_month(http.formvalue("month") or "1") or "1"
	local code = valid_captcha(http.formvalue("code") or "")
	http.prepare_content("application/json")
	if not pid then
		http.write_json({ ok = false, msg = "套餐参数无效" })
		return
	end
	local cmd = "/usr/sbin/gogogo shop_buy " .. sh_quote(pid) .. " " .. sh_quote(month)
	if code then
		cmd = cmd .. " " .. sh_quote(code)
	end
	http.write_json(run_json(cmd))
end

function action_shop_renew()
	local month = valid_month(http.formvalue("month") or "1") or "1"
	local code = valid_captcha(http.formvalue("code") or "")
	local cmd = "/usr/sbin/gogogo shop_renew " .. sh_quote(month)
	if code then
		cmd = cmd .. " " .. sh_quote(code)
	end
	http.prepare_content("application/json")
	http.write_json(run_json(cmd))
end
