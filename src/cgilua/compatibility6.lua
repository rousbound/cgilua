----------------------------------------------------------------------------
-- CGILua 6.x Compatibility Module
--
-- Provides backward compatibility with CGILua 6.x API.
-- Users migrating from CGILua 6.x should add:
--   require"cgilua.compatibility6"
--
-- Compatibility features enabled:
--   cgilua:
--     - splitpath (alias for splitonlast)
--     - preprocess (alias for handlelp)
--     - includehtml (alias for lp.include)
--   session:
--     - close (alias for persist)
--     - open (alias for try_open)
--     - enablesession (alias for enable)
--     - setsessiondir(dir) (sets base_dir)
--   lp:
--     - Old syntax: $|expr|$ and <!--$$code$$-->
--
-- Note: cgilua.GET was removed. Use cgilua.QUERY instead.
----------------------------------------------------------------------------

local cgilua = require"cgilua"
local lp = require"cgilua.lp"

----------------------------------------------------------------------------
-- cgilua aliases
----------------------------------------------------------------------------
cgilua.splitpath = cgilua.splitonlast
cgilua.preprocess = cgilua.handlelp
cgilua.includehtml = lp.include

----------------------------------------------------------------------------
-- Lua Pages: enable old template syntax
--   $|expression|$  ->  <?lua = expression ?>
--   <!--$$code$$--> ->  <?lua code ?>
----------------------------------------------------------------------------
lp.setcompatmode(true)

----------------------------------------------------------------------------
-- Session aliases (loaded lazily to avoid circular deps)
----------------------------------------------------------------------------
local session_loaded, session = pcall(require, "cgilua.session")
if session_loaded then
    -- Method aliases
    session.close = session.persist
    session.open = session.try_open
    session.enablesession = session.enable

    -- setsessiondir was a function, now it's just setting base_dir
    function session.setsessiondir(dir)
        -- Remove trailing slash if present
        if dir:sub(-1) == "/" then
            dir = dir:sub(1, -2)
        end
        session.base_dir = dir
    end
end

----------------------------------------------------------------------------
-- cgilua.enablesession convenience wrapper (common pattern in 6.x)
----------------------------------------------------------------------------
function cgilua.enablesession()
    if session_loaded then
        session.enable()
    end
end

return {
    _VERSION = "CGILua 6.x Compatibility",
    _DESCRIPTION = "Backward compatibility layer for CGILua 6.x applications",
}
