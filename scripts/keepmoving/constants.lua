----
-- Mod constants.
--
-- **Source Code:** [https://github.com/victorpopkov/dst-mod-keep-moving](https://github.com/victorpopkov/dst-mod-keep-moving)
--
-- @module Constants
--
-- @author Victor Popkov
-- @copyright 2020
-- @license MIT
-- @release 0.1.0-alpha
----

local function RGB(r, g, b)
    return { r / 255, g / 255, b / 255, 1 }
end

--- Mod constants.
-- @table MOD_KEEP_MOVING
-- @field POINTS Default point type
MOD_KEEP_MOVING = {
    --- Different colors.
    -- @table MOD_KEEP_MOVING.COLORS
    -- @tfield table GREEN
    -- @tfield table RED
    COLORS = {
        BLACK = RGB(0, 0, 0),
        GREEN = RGB(0, 255, 0),
        RED = RGB(200, 0, 0),
        WHITE = RGB(255, 255, 255),
    },

    --- Different point types.
    -- @table MOD_KEEP_MOVING.POINTS
    -- @tfield number POINT Default point type
    -- @tfield number CHECKPOINT Checkpoint point type
    POINTS = {
        POINT = 1,
        CHECKPOINT = 2,
    },
}
