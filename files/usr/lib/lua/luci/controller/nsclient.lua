module("luci.controller.nsclient", package.seeall)

local http = require "luci.http"
local sys = require "luci.sys"
local util = require "luci.util"
local jsonc = require "luci.jsonc"
local dispatcher = require "luci.dispatcher"

function index()
	entry({"admin", "network", "nsclient"}, call("action_index"), _("NS Client"), 70).dependent = false
	entry({"admin", "network", "nsclient", "status"}, call("action_status")).leaf = true
	entry({"admin", "network", "nsclient", "login"}, call("action_login")).leaf = true
	entry({"admin", "network", "nsclient", "connect"}, call("action_connect")).leaf = true
	entry({"admin", "network", "nsclient", "disconnect"}, call("action_disconnect")).leaf = true
	entry({"admin", "network", "nsclient", "save"}, call("action_save")).leaf = true
end

local function sh_quote(s)
	return "'" .. tostring(s or ""):gsub("'", "'\\''") .. "'"
end

local function trim(s)
	return util.trim(tostring(s or ""))
end

local function run_json(cmd)
	local raw = util.trim(sys.exec(cmd .. " 2>/dev/null") or "")
	local e = jsonc.parse(raw)
	if type(e) ~= "table" then
		e = { ok = false, msg = (raw ~= "" and raw or "无有效响应") }
	end
	return e
end

local function valid_url(u)
	u = trim(u):gsub("/+$", "")
	if u:match("^https?://[%w%._%-:]+") then
		return u
	end
	return nil
end

local function valid_domain(d)
	d = trim(d)
	d = d:gsub("^https?://", ""):gsub("/.*$", "")
	if d:match("^[%w][%w%.%-]*[%w]$") or d:match("^[%w]+$") then
		return d
	end
	return nil
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

function action_index()
	if apply_url_overrides() then
		http.redirect(dispatcher.build_url("admin", "network", "nsclient"))
		return
	end
	luci.template.render("nsclient/main")
end

function action_status()
	http.prepare_content("application/json")
	http.write_json(run_json("/usr/sbin/nsclient status"))
end

function action_save()
	local account = trim(http.formvalue("account"))
	local password = trim(http.formvalue("password"))
	local enable = trim(http.formvalue("enable"))
	local region = trim(http.formvalue("region"))

	if account ~= "" then
		sys.call("/usr/sbin/nsclient set account " .. sh_quote(account) .. " >/dev/null")
	end
	if password ~= "" then
		local cur = trim(sys.exec("/usr/sbin/nsclient get account 2>/dev/null") or "")
		sys.call("/usr/sbin/nsclient set account " .. sh_quote(cur) .. " " .. sh_quote(password) .. " >/dev/null")
	end
	if enable ~= "" then
		sys.call("/usr/sbin/nsclient set enable " .. sh_quote(enable) .. " >/dev/null")
	end
	if region ~= "" then
		sys.call("/usr/sbin/nsclient set region " .. sh_quote(region) .. " >/dev/null")
	end

	http.prepare_content("application/json")
	http.write_json({ ok = true, msg = "已保存" })
end

function action_login()
	local account = trim(http.formvalue("account"))
	local password = trim(http.formvalue("password"))
	local enable = trim(http.formvalue("enable"))

	if account ~= "" then
		if password ~= "" then
			sys.call("/usr/sbin/nsclient set account " .. sh_quote(account) .. " " .. sh_quote(password) .. " >/dev/null")
		else
			sys.call("/usr/sbin/nsclient set account " .. sh_quote(account) .. " >/dev/null")
		end
	end
	if enable ~= "" then
		sys.call("/usr/sbin/nsclient set enable " .. sh_quote(enable) .. " >/dev/null")
	end

	http.prepare_content("application/json")
	http.write_json(run_json("/usr/sbin/nsclient login"))
end

function action_connect()
	local region = trim(http.formvalue("region"))
	if region ~= "" then
		sys.call("/usr/sbin/nsclient set region " .. sh_quote(region) .. " >/dev/null")
	end
	http.prepare_content("application/json")
	http.write_json(run_json("/usr/sbin/nsclient connect " .. sh_quote(region)))
end

function action_disconnect()
	http.prepare_content("application/json")
	http.write_json(run_json("/usr/sbin/nsclient disconnect"))
end
