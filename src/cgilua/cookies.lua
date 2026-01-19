----------------------------------------------------------------------------
-- Cookies Library
--
-- @release $Id: cookies.lua,v 1.8 2008/04/24 13:42:04 mascarenhas Exp $
----------------------------------------------------------------------------

local os = require"os"
local string = require"string"
local urlcode = require"cgilua.urlcode"
local cgilua = require"cgilua"

local error = error
local format, gsub, strfind, strmatch = string.format, string.gsub, string.find, string.match
local tconcat = table.concat
local date = os.date
local escape, unescape = urlcode.escape, urlcode.unescape

local header = cgilua.Response.header
local write = cgilua.Response.write
local servervariable = cgilua.servervariable

local M = {}

	local function optional (what, name)
		if name ~= nil and name ~= "" then
			return format("%s=%s", what, name)
		end
	end

	local function build (name, value, options)
		options = options or {}
		if not name or not value then
			error("cookie needs a name and a value")
		end

		local a = {}

		if tonumber (options.expires) then
			local t = date("!%A, %d-%b-%Y %H:%M:%S GMT", options.expires)
			a[#a+1] = optional("Expires", t)
		else
			a[#a+1] = optional("Expires", options.expires)
		end

		-- Indicates the number of seconds until the cookie expires. 
		a[#a+1] = optional("Max-Age", options.max_age)

		-- Domain and Path scope the cookie.
		a[#a+1] = optional("Domain", options.domain)
		a[#a+1] = optional("Path", options.path)

		-- If Partitioned is set, secure should also be
		-- If SameSite=None, Secure should be set
		local secure =
	    options.secure
	    or options.partitioned
	    or (options.samesite and options.samesite:lower() == "None")

	  -- Enforces HTTPS transport when required.
	  if secure then
	  	 a[#a+1] = "Secure"
	  end

	  -- Prevent access from client-side JavaScript.
	  -- Default: HttpOnly
	  if options.httponly ~= false then
			a[#a+1] = "HttpOnly"
		end

		-- Mark cookie as partitioned (requires Secure).
		if options.partitioned then
			a[#a+1] = "Partitioned"
		end

		-- SameSite controls cross-site cookie sending.
		-- Note: SameSite=None requires Secure (enforced above).
		-- Default: Lax
		a[#a+1] = optional("SameSite", options.samesite or "Lax")


		return name .. "=" .. escape(value)..";"..tconcat (a, "; ")
	end



----------------------------------------------------------------------------
-- Sets a value to a cookie, with the given options.
-- Generates a header "Set-Cookie", thus it can only be used in Lua Scripts.
-- @param name String with the name of the cookie.
-- @param value String with the value of the cookie.
-- @param options Table with the options (optional).

function M.set (name, value, options)
	header("Set-Cookie", build(name, value, options))
end


----------------------------------------------------------------------------
-- Gets the value of a cookie.
-- @param name String with the name of the cookie.
-- @return String with the value associated with the cookie.

function M.get (name)
	local cookies = servervariable"HTTP_COOKIE" or ""
	cookies = ";" .. cookies .. ";"
	cookies = gsub(cookies, "%s*;%s*", ";")	 -- remove extra spaces
	local pattern = ";" .. name .. "=(.-);"
	local value = strmatch(cookies, pattern)
	return value and unescape(value)
end


	----------------------------------------------------------------------------
	-- Deletes a cookie, by setting its value to "xxx" and Max-Age = 0.
	-- @param name String with the name of the cookie.
	-- @param options Table with the options (optional; note that path and
	-- domain combine with the name to identify the cookie).

	function M.delete (name, options)
		M.set(name, "xxx", {
			path = options.path,
			domain = options.domain,
			max_age = "0",
		})
	end


return M
