module("luci.controller.nsclient", package.seeall)

local http = require "luci.http"
local sys = require "luci.sys"
local util = require "luci.util"
local jsonc = require "luci.jsonc"
local dispatcher = require "luci.dispatcher"

function index()
	entry({"admin", "nsclient"}, firstchild(), "VPN", 60).dependent = false
	entry({"admin", "nsclient", "config"}, call("action_index"), "连接", 1)
	entry({"admin", "nsclient", "status"}, call("action_status")).leaf = true
	entry({"admin", "nsclient", "login"}, call("action_login")).leaf = true
	entry({"admin", "nsclient", "connect"}, call("action_connect")).leaf = true
	entry({"admin", "nsclient", "disconnect"}, call("action_disconnect")).leaf = true
	entry({"admin", "nsclient", "save"}, call("action_save")).leaf = true
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

local function valid_url(u)
	u = scrub(u):gsub("%s+", ""):gsub("/+$", "")
	if u:match("^https?://[%w][%w%._%-:]*") and not u:match("[%$`();|\\<>]") then
		return u
	end
	return nil
end

local function valid_domain(d)
	d = scrub(d):gsub("%s+", "")
	d = d:gsub("^https?://", ""):gsub("/.*$", ""):gsub(":.*$", "")
	d = d:lower()
	if d:match("^[%l%d][%l%d%.%-]*[%l%d]$") or d:match("^[%l%d]+$") then
		return d
	end
	return nil
end

local function valid_account(a)
	a = scrub(a)
	if a:match("%s") then
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

local function valid_region(r)
	r = scrub(r):gsub("%s+", ""):lower()
	if r:match("^[%l%d_%-]+$") then
		return r
	end
	return nil
end

local function valid_split(v)
	v = scrub(v)
	if v == "1" or v == "0" then
		return v
	end
	return nil
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

local function apply_url_overrides()
	local orch = valid_url(http.formvalue("orch") or http.formvalue("url"))
	local domain = valid_domain(http.formvalue("domain"))
	local changed = false

	if orch then
		if sys.call("/usr/sbin/nsclient set orch " .. sh_quote(orch) .. " >/dev/null") == 0 then
			changed = true
		end
	end
	if domain then
		if sys.call("/usr/sbin/nsclient set domain " .. sh_quote(domain) .. " >/dev/null") == 0 then
			changed = true
		end
	end
	return changed
end

local function read_status_cache_json()
	local f = io.open("/var/run/nsclient/status.json", "r")
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
	if apply_url_overrides() then
		http.redirect(dispatcher.build_url("admin", "nsclient", "config"))
		return
	end
	luci.template.render("nsclient/main", {
		status_cache_json = read_status_cache_json()
	})
end

function action_status()
	http.prepare_content("application/json")
	http.write_json(run_json("/usr/sbin/nsclient status"))
end

function action_save()
	local account = valid_account(http.formvalue("account"))
	local password = valid_password(http.formvalue("password"))
	local enable = scrub(http.formvalue("enable") or "")
	local region = valid_region(http.formvalue("region"))
	local split = valid_split(http.formvalue("split") or "")

	if account then
		if password then
			sys.call("/usr/sbin/nsclient set account " .. sh_quote(account) .. " " .. sh_quote(password) .. " >/dev/null")
		else
			sys.call("/usr/sbin/nsclient set account " .. sh_quote(account) .. " >/dev/null")
		end
	end
	if enable ~= "" then
		sys.call("/usr/sbin/nsclient set enable " .. sh_quote(enable) .. " >/dev/null")
	end
	if split then
		sys.call("/usr/sbin/nsclient set split " .. sh_quote(split) .. " >/dev/null")
	end
	if region then
		sys.call("/usr/sbin/nsclient set region " .. sh_quote(region) .. " >/dev/null")
	end

	http.prepare_content("application/json")
	http.write_json({ ok = true, msg = "已保存" })
end

function action_login()
	local account = valid_account(http.formvalue("account"))
	local password = valid_password(http.formvalue("password"))
	local enable = scrub(http.formvalue("enable") or "")

	if account then
		if password then
			sys.call("/usr/sbin/nsclient set account " .. sh_quote(account) .. " " .. sh_quote(password) .. " >/dev/null")
		else
			sys.call("/usr/sbin/nsclient set account " .. sh_quote(account) .. " >/dev/null")
		end
	end
	if enable ~= "" then
		sys.call("/usr/sbin/nsclient set enable " .. sh_quote(enable) .. " >/dev/null")
	end

	-- Login may disconnect the old tunnel (account switch) then wait on
	-- HTTPS; that exceeds uhttpd idle timeout. Return immediately and
	-- let the page poll status.login_pending / login_result.
	os.execute("mkdir -p /var/run/nsclient; echo pending > /var/run/nsclient/login.job; rm -f /var/run/nsclient/login.result; /usr/sbin/nsclient login >/dev/null 2>&1 &")
	http.prepare_content("application/json")
	http.write_json({
		ok = true,
		pending = true,
		msg = "正在登录",
		account = account or ""
	})
end

function action_connect()
	local region = valid_region(http.formvalue("region"))
	if region then
		sys.call("/usr/sbin/nsclient set region " .. sh_quote(region) .. " >/dev/null")
	end
	-- Handshake can take longer than uhttpd's idle timeout. Start it in the
	-- background and let the page poll status; otherwise LuCI shows
	-- "无有效响应" while the tunnel is still coming up.
	os.execute("/usr/sbin/nsclient connect " .. sh_quote(region or "") ..
		" >/dev/null 2>&1 &")
	http.prepare_content("application/json")
	http.write_json({
		ok = true,
		pending = true,
		msg = "正在连接",
		region = region or ""
	})
end

function action_disconnect()
	http.prepare_content("application/json")
	http.write_json(run_json("/usr/sbin/nsclient disconnect"))
end
