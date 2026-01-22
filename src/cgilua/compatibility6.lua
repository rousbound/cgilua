----------------------------------------------------------------------------
-- CGILua 6.x Compatibility Module
--
-- Provides backward compatibility with CGILua 6.x API.
-- Users migrating from CGILua 6.x should add:
--   require"cgilua.compatibility6"
--
-- Compatibility features enabled:
--   - cgilua.splitpath (alias for splitonlast)
--   - session.close (alias for session.persist)
--   - Lua Pages old syntax: $|expr|$ and <!--$$code$$-->
----------------------------------------------------------------------------

local cgilua = require"cgilua"
local lp = require"cgilua.lp"

-- API aliases
cgilua.splitpath = cgilua.splitonlast

-- Enable old Lua Pages template syntax:
--   $|expression|$  ->  <?lua = expression ?>
--   <!--$$code$$--> ->  <?lua code ?>
lp.setcompatmode(true)

-- Session compatibility (loaded lazily to avoid circular deps)
local session_loaded, session = pcall(require, "cgilua.session")
if session_loaded then
    session.close = session.persist
end

return {
    _VERSION = "CGILua 6.x Compatibility",
    _DESCRIPTION = "Backward compatibility layer for CGILua 6.x applications",
}
