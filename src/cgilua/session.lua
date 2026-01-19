----------------------------------------------------------------------------
-- Session library.
--
-- @release $Id: session.lua,v 1.29 2007/11/21 16:33:20 carregal Exp $
----------------------------------------------------------------------------

local cgilua = require"cgilua"
local lfs = require"lfs"
local serialize = require"cgilua.serialize".serialize
local strbyte, strformat, strrep = string.byte, string.format, string.rep
local ioopen = io.open
local osremove, ostime = os.remove, os.time

local assert, error, ipairs, loadfile, next, tostring, type = assert, error, ipairs, loadfile, next, tostring, type
local format, gsub, strfind = string.format, string.gsub, string.find
local fsattributes, fsdir = lfs.attributes, lfs.dir
local tinsert = table.insert
local _open = io.open
local remove, time = os.remove, os.time
local mod, rand, randseed = (math.mod or math.fmod), math.random, math.randomseed
local attributes, dir, mkdir = lfs.attributes, lfs.dir, lfs.mkdir

local cookies = require"cgilua.cookies"

local M = {
	_VERSION = "1.0.1",

	data = nil, -- will be created when a session is created
	already_enabled = false,
	base_dir = "/tmp",
	id_pattern = "^"..strrep ("[0-9A-F]", 32)..strrep ("%d", 12).."$",
	timeout = 10 * 60, -- 10 min
	token_name = "cgilua_session_identification",
	token_options = { path = '/', },
}


local INVALID_SESSION_ID = "Invalid session identification"

----------------------------------------------------------------------------
-- Internal state variables.
local root_dir = nil

------------------------------------------------------------------------------
-- Checks identifier's format.
------------------------------------------------------------------------------
function M.check_id (id)
	return id and (id:match (M.id_pattern) ~= nil)
end

------------------------------------------------------------------------------
-- Produces a file name based on a session identifier.
-- @param id Session identification.
-- @return String with the session file name.
------------------------------------------------------------------------------
function M.filename (id)
	return strformat ("%s/%s.lua", M.base_dir, id)
end

------------------------------------------------------------------------------
-- Deletes a session file.
------------------------------------------------------------------------------
function M.delete (id)
	if not M.check_id (id) then
		return nil, INVALID_SESSION_ID
	end
	osremove (M.filename (id))
end

------------------------------------------------------------------------------
-- Searches for a file in the base_dir.
-- @return Boolean indicating the wether file was found.
------------------------------------------------------------------------------
function M.find_file (id)
	local fh = ioopen (M.filename (id))
	if fh then
		fh:close()
		return true
	else
		return false
	end
end

------------------------------------------------------------------------------
-- Creates a new identifier.
-- @return String with a new identifier.
------------------------------------------------------------------------------
function M.new_id ()
	-- Normalize the IP address to 12 chars: 4 x 3-algarism-number
	local remote_ip =
		(cgilua.servervariable"REMOTE_ADDR"..'.')
		:gsub ("(%d+)%.", function (num)
			local n = #num
			return strrep ('0', 3-n)..num
	end)
	-- Random number
	local fh = assert (ioopen("/dev/urandom", "rb"))
	local binstr = fh:read(16)
	fh:close()
	-- Convert each byte to hex
	local hexnum = binstr:gsub ("(.)", function (c)
		return strformat ("%02X", strbyte (c))
	end)
	-- 32 char (algarism or letter from 'A' to 'F') + 12 char (algarism) = 46 char
	return hexnum..remote_ip
end


------------------------------------------------------------------------------
-- Creates a new session and returns its identifier.
-- @return Session identification.
------------------------------------------------------------------------------
function M.new ()
	if M.id then
		M.destroy () -- erases M.id and cookie
	end
	local id
	-- Make sure there is no other session with the same identifier
	repeat
		id = M.new_id ()
	until not M.find_file (id)
	M.id = id
	M.data = {}
	M.save (id, M.data)
	cookies.set (M.token_name, id, M.token_options)
	return id
end

------------------------------------------------------------------------------
-- Loads data from a session.
-- @param id Session identification.
-- @return Table with session data or nil in case of error.
-- @return In case of error, also returns the error message.
------------------------------------------------------------------------------
function M.load (id)
	if not M.check_id (id) then
		return nil, INVALID_SESSION_ID
	end
	local f, err = loadfile (M.filename (id))
	if not f then
		return nil, err
	else
		return f()
	end
end

------------------------------------------------------------------------------
-- Saves data to a session.
-- @param id Session identification.
-- @param data Table with session data to be saved.
------------------------------------------------------------------------------
function M.save (id, data)
	if not M.check_id (id) then
		return nil, INVALID_SESSION_ID
	end
	local fh = assert (ioopen (M.filename (id), "w+"))
	fh:write "return "
	serialize (data, function (s) fh:write(s) end)
	fh:close()
end

----------------------------------------------------------------------------
-- Removes expired sessions.
----------------------------------------------------------------------------
function M.cleanup ()
	local rem = {}
	local now = ostime ()
	for file in fsdir (M.base_dir) do
		local attr = fsattributes (M.base_dir..'/'..file)
		if attr and attr.mode == "file" then
			if attr.modification + M.timeout < now then
				tinsert (rem, file)
			end
		end
	end
	for _, file in ipairs (rem) do
		osremove (M.base_dir..'/'..file)
	end
end

----------------------------------------------------------------------------
-- Changes the session timeout.
-- @param t Number of seconds to maintain a session.
----------------------------------------------------------------------------
function M.setsessiontimeout (t)
	if type (t) == "number" then
		M.timeout = t
	end
end

----------------------------------------------------------------------------
-- Changes the session directory.
-- @param path String with the new session directory.
----------------------------------------------------------------------------
function M.setsessiondir (path)
	path = gsub (path, "[/\\]$", "")
	-- Make sure the given path is a directory
	if not attributes (path, "mode") then
		assert (mkdir (path))
	end
	-- Make sure it can create a new file in the given directory
	local test_file = path.."/"..cgilua.tmpname()
	local fh, err = _open (test_file, "w")
	if not fh then
		error ("Could not open a file in session directory: "..
			tostring(err), 2)
	end
	fh:close ()
	remove (test_file)
	M.base_dir = path
end

------------------------------------------------------------------------------
-- destroy
------------------------------------------------------------------------------
function M.destroy ()
	M.data = nil
	M.delete (M.id)
	M.id = nil
end

function M.logout()
	M.destroy()
	cookies.delete (M.token_name, M.token_options)
end

------------------------------------------------------------------------------
-- Open a user session based on the id stored in the cookie (if there is one!).
-- This function should be called before the script is executed.
------------------------------------------------------------------------------
function M.try_open ()
	M.cleanup()
	local id = cookies.get (M.token_name) -- or M.new()
	if id then
		-- session persisted from last request!
		if M.check_id (id) then
			M.data = M.load (id) -- or {}
			if M.data then
				M.id = id -- temos uma sessão aberta
			else
				M.id = nil
			end
		end
	end
end


------------------------------------------------------------------------------
-- Open a specific user session passed as parameter.
------------------------------------------------------------------------------
function M.force_open (id)
	if not id or not M.check_id (id) then
		return false
	end

	-- session persisted from last request!
	M.id = id
	M.data = M.load (M.id)
	cookies.set (M.token_name, id, M.token_options)
	return true
end

------------------------------------------------------------------------------
-- Persist the user session.
-- This function should be called after the script is executed.
------------------------------------------------------------------------------
function M.persist ()
	if M.id and M.data and next (M.data) then
		M.save (M.id, M.data)
	end
end

-- Compatibility
M.close = M.persist

----------------------------------------------------------------------------
-- Close user session.
-- This function should be called after the script is executed.
----------------------------------------------------------------------------
function M.close ()
	if next (M.data) then
		M.save (id, M.data)
		id = nil
	end
end

------------------------------------------------------------------------------
-- Prepare session environment:
-- 1. if there is a session-id, try to open the session;
-- 2. set the close-function that will persist the session-data.
--
-- Note that this function DOES NOT automatically opens a session if there
-- is no session-id.
------------------------------------------------------------------------------
function M.enablesession ()
	if M.already_enabled then
		return
	else
		M.already_enabled = true
	end
	M.try_open ()
	cgilua.addclosefunction (M.persist)
end

return M
