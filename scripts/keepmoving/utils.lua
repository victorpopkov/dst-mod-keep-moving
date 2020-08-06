----
-- Different mod utilities.
--
-- Most of them are expected to be used in the gameplay console.
--
-- **Source Code:** [https://github.com/victorpopkov/dst-mod-keep-moving](https://github.com/victorpopkov/dst-mod-keep-moving)
--
-- @module Utils
--
-- @author Victor Popkov
-- @copyright 2020
-- @license MIT
-- @release 0.1.0-alpha
----
local Utils = {}

--
-- Helpers
--

local function DebugError(...)
    return _G.KeepMovingDebug and _G.KeepMovingDebug:DebugError(...)
end

local function DebugString(...)
    return _G.KeepMovingDebug and _G.KeepMovingDebug:DebugString(...)
end

--- Debugging
-- @section debugging

--- Adds debug methods to the destination class.
--
-- Checks the global environment if the `KeepMovingDebug` (`Debug`) is available and adds the
-- corresponding methods from there. Otherwise, adds all the corresponding functions as empty ones.
--
-- @tparam table dest Destination class
function Utils.AddDebugMethods(dest)
    local methods = {
        "DebugError",
        "DebugInit",
        "DebugString",
        "DebugStringStart",
        "DebugStringStop",
        "DebugTerm",
    }

    if _G.KeepMovingDebug then
        for _, v in pairs(methods) do
            dest[v] = function(_, ...)
                if _G.KeepMovingDebug and _G.KeepMovingDebug[v] then
                    return _G.KeepMovingDebug[v](_G.KeepMovingDebug, ...)
                end
            end
        end
    else
        for _, v in pairs(methods) do
            dest[v] = function()
            end
        end
    end
end

--- General
-- @section general

--- Checks if HUD has an input focus.
-- @tparam EntityScript inst Player instance
-- @treturn boolean
function Utils.IsHUDFocused(inst)
    return not Utils.ChainGet(inst, "HUD", "HasInputFocus", true)
end

--- Chain
-- @section chain

--- Gets chained field.
--
-- Simplifies the last chained field retrieval like:
--
--    return TheWorld
--        and TheWorld.net
--        and TheWorld.net.components
--        and TheWorld.net.components.shardstate
--        and TheWorld.net.components.shardstate.GetMasterSessionId
--        and TheWorld.net.components.shardstate:GetMasterSessionId
--
-- Or it's value:
--
--    return TheWorld
--        and TheWorld.net
--        and TheWorld.net.components
--        and TheWorld.net.components.shardstate
--        and TheWorld.net.components.shardstate.GetMasterSessionId
--        and TheWorld.net.components.shardstate:GetMasterSessionId()
--
-- It also supports net variables and tables acting as functions.
--
-- @usage Utils.ChainGet(TheWorld, "net", "components", "shardstate", "GetMasterSessionId") -- (function) 0x564445367790
-- @usage Utils.ChainGet(TheWorld, "net", "components", "shardstate", "GetMasterSessionId", true) -- (string) D000000000000000
-- @tparam table src
-- @tparam string|boolean ...
-- @treturn function|userdata|table
function Utils.ChainGet(src, ...)
    if src and (type(src) == "table" or type(src) == "userdata") then
        local args = { ... }
        local execute = false

        if args[#args] == true then
            table.remove(args, #args)
            execute = true
        end

        local previous = src
        for i = 1, #args do
            if src[args[i]] then
                previous = src
                src = src[args[i]]
            else
                return
            end
        end

        if execute and previous then
            if type(src) == "function" then
                return src(previous)
            elseif type(src) == "userdata" or type(src) == "table" then
                if type(src.value) == "function" then
                    -- netvar
                    return src:value()
                elseif getmetatable(src.value) and getmetatable(src.value).__call then
                    -- netvar (for testing)
                    return src.value(src)
                elseif getmetatable(src) and getmetatable(src).__call then
                    -- table acting as a function
                    return src(previous)
                end
            end
            return
        end

        return src
    end
end

--- Validates chained fields.
--
-- Simplifies the chained fields checking like below:
--
--    return TheWorld
--        and TheWorld.net
--        and TheWorld.net.components
--        and TheWorld.net.components.shardstate
--        and TheWorld.net.components.shardstate.GetMasterSessionId
--        and true
--        or false
--
-- @usage Utils.ChainValidate(TheWorld, "net", "components", "shardstate", "GetMasterSessionId") -- (boolean) true
-- @tparam table src
-- @tparam string|boolean ...
-- @treturn boolean
function Utils.ChainValidate(src, ...)
    return Utils.ChainGet(src, ...) and true or false
end

--- Locomotor
-- @section locomotor

--- Checks if the locomotor is available.
--
-- Can be used to check whether the movement prediction (lag compensation) is enabled or not as the
-- locomotor component is not available when it's disabled.
--
-- @tparam EntityScript inst Player instance
-- @treturn boolean
function Utils.IsLocomotorAvailable(inst)
    return Utils.ChainGet(inst, "components", "locomotor") ~= nil
end

--- Runs in a certain direction.
--
-- Calculates an angle and calls `RunInDirection` from the locomotor component when it's available.
-- Otherwise sends the corresponding `RPC.DirectWalking`.
--
-- @tparam EntityScript inst Player instance
-- @tparam Vector3 pt Destination point
-- @treturn[1] Vector3 Direction vector
-- @treturn[1] number Direction angle
function Utils.RunInPointDirection(inst, pt)
    local locomotor = Utils.ChainGet(inst, "components", "locomotor")
    local angle = inst:GetAngleToPoint(pt)
    local offset = inst:GetPosition() - pt
    local dir = offset:GetNormalized()

    dir.x = -dir.x
    dir.z = -dir.z

    if locomotor then
        inst.Transform:SetRotation(angle)
        locomotor:RunInDirection(angle)
    else
        SendRPCToServer(RPC.DirectWalking, dir.x, dir.z)
    end

    return dir, angle
end

--- Walks to a certain point.
--
-- Prepares a `WALKTO` action for `PlayerController.DoAction` when the locomotor component is
-- available. Otherwise sends the corresponding `RPC.LeftClick`.
--
-- @tparam EntityScript inst Player instance
-- @tparam Vector3 pt Destination point
function Utils.WalkToPoint(inst, pt)
    local player_controller = Utils.ChainGet(inst, "components", "playercontroller")
    if not player_controller then
        DebugError("Player controller is not available")
        return
    end

    if player_controller.locomotor then
        player_controller:DoAction(BufferedAction(inst, nil, ACTIONS.WALKTO, nil, pt))
    else
        SendRPCToServer(RPC.LeftClick, ACTIONS.WALKTO.code, pt.x, pt.z)
    end
end

--- Stops moving.
--
-- Calls `Stop` from the locomotor component when it's available. Otherwise sends an
-- `RPC.StopWalking`.
--
-- @tparam EntityScript inst Player instance
function Utils.StopMoving(inst)
    local locomotor = Utils.ChainGet(inst, "components", "locomotor")
    if locomotor then
        locomotor:Stop()
    else
        SendRPCToServer(RPC.StopWalking)
    end
end

--- Save data
-- @section savedata

--- Gets the save data path.
--
-- Returns one of the following paths based on the server type:
--
--   - `server_temp/server_save` (local game)
--   - `client_temp/server_save` (dedicated server)
--
-- @treturn string
function Utils.SaveDataGetPath()
    return TheWorld and TheWorld.ismastersim
        and "server_temp/server_save"
        or "client_temp/server_save"
end

--- Loads the save data.
--
-- Returns the data which is stored on the client-side.
--
-- @treturn table
function Utils.SaveDataLoad()
    local success, save_data
    local path = Utils.SaveDataGetPath()

    DebugString("[save_data]", "Path:", path)

    TheSim:GetPersistentString(path, function(success_load, str)
        if success_load then
            DebugString("[save_data]", "Loaded successfully")
            success, save_data = RunInSandboxSafe(str)
            if success then
                DebugString("[save_data]", "Data extracted successfully")
                DebugString("[save_data]", "Seed:", save_data.meta.seed)
                DebugString("[save_data]", "Version:", save_data.meta.saveversion)
                return save_data
            else
                DebugError("[save_data]", "Data extraction has failed")
                return false
            end
        else
            DebugError("[save_data]", "Load has failed")
            return false
        end
    end)

    return save_data
end

--- Table
-- @section table

--- Counts the number of elements inside the table.
-- @tparam table t Table
-- @treturn number
function Utils.TableCount(t)
    if type(t) ~= "table" then
        return false
    end

    local result = 0
    for _ in pairs(t) do
        result = result + 1
    end

    return result
end

--- Thread
-- @section thread

--- Starts a new thread.
--
-- Just a convenience wrapper for the `StartThread`.
--
-- @tparam string id Thread ID
-- @tparam function fn Thread function
-- @tparam function whl While function
-- @tparam[opt] function init Initialization function
-- @tparam[opt] function term Termination function
-- @treturn table
function Utils.ThreadStart(id, fn, whl, init, term)
    return StartThread(function()
        DebugString("Thread started")
        if init then
            init()
        end
        while whl() do
            fn()
        end
        if term then
            term()
        end
        Utils.ThreadClear()
    end, id)
end

--- Clears a thread.
-- @tparam table thread Thread
function Utils.ThreadClear(thread)
    local task = scheduler:GetCurrentTask()
    if thread or task then
        if thread and not task then
            DebugString("[" .. thread.id .. "]", "Thread cleared")
        else
            DebugString("Thread cleared")
        end

        thread = thread ~= nil and thread or task
        KillThreadsWithID(thread.id)
        thread:SetList(nil)
    end
end

return Utils
