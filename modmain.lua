----
-- Modmain.
--
-- **Source Code:** [https://github.com/victorpopkov/dst-mod-keep-moving](https://github.com/victorpopkov/dst-mod-keep-moving)
--
-- @author Victor Popkov
-- @copyright 2020
-- @license MIT
-- @release 0.1.0-alpha
----
local _G = GLOBAL
local require = _G.require

local Utils = require "keepmoving/utils"

--
-- Globals
--

local ACTIONS = _G.ACTIONS
local BufferedAction = _G.BufferedAction
local CONTROL_ACTION = _G.CONTROL_ACTION
local CONTROL_MOVE_DOWN = _G.CONTROL_MOVE_DOWN
local CONTROL_MOVE_LEFT = _G.CONTROL_MOVE_LEFT
local CONTROL_MOVE_RIGHT = _G.CONTROL_MOVE_RIGHT
local CONTROL_MOVE_UP = _G.CONTROL_MOVE_UP
local CONTROL_PRIMARY = _G.CONTROL_PRIMARY
local TheInput = _G.TheInput
local TheSim = _G.TheSim

--
-- Assets
--

Assets = {
    Asset("ANIM", "anim/keep_moving_points.zip"),
}

--
-- Debugging
--

local Debug

if GetModConfigData("debug") then
    Debug = require "keepmoving/debug"
    Debug:DoInit(modname)
    Debug:SetIsEnabled(true)
    Debug:DebugModConfigs()
end

_G.KeepMovingDebug = Debug

local function DebugString(...)
    return Debug and Debug:DebugString(...)
end

local function DebugInit(...)
    return Debug and Debug:DebugInit(...)
end

--
-- Helpers
--

local function GetKeyFromConfig(config)
    local key = GetModConfigData(config)
    return key and (type(key) == "number" and key or _G[key]) or -1
end

local function IsDST()
    return TheSim:GetGameID() == "DST"
end

local function IsClient()
    return IsDST() and _G.TheNet:GetIsClient()
end

local function IsMoveButton(control)
    return control == CONTROL_MOVE_UP
        or control == CONTROL_MOVE_DOWN
        or control == CONTROL_MOVE_LEFT
        or control == CONTROL_MOVE_RIGHT
end

local function IsOurAction(action)
    return action == ACTIONS.MOD_KEEP_MOVING_DIRECT
        or action == ACTIONS.MOD_KEEP_MOVING_ROAD
end

--
-- Configurations
--

local _DIRECT_MOVING = GetModConfigData("direct_moving")
local _KEY_ACTION = GetKeyFromConfig("key_action")
local _MOUSE_DRAGGING_CHECK = GetModConfigData("mouse_dragging_check")
local _ON_ROAD_MOVING = GetModConfigData("on_road_moving")
local _REVERSE_ACTIONS = GetModConfigData("reverse_actions")

--
-- Actions
--

local function ActionDirect(act)
    local keepmoving = Utils.ChainGet(act, "doer", "components", "keepmoving")
    if keepmoving and not act.target then
        keepmoving:Stop()
        keepmoving:StartDirectMoving(TheInput:GetWorldPosition())
        return true
    end
    return false
end

local function ActionRoad(act)
    local keepmoving = Utils.ChainGet(act, "doer", "components", "keepmoving")
    if keepmoving and not act.target then
        keepmoving:Stop()
        keepmoving:StartOnRoadMoving(TheInput:GetWorldPosition())
        return true
    end
    return false
end

if _DIRECT_MOVING then
    AddAction("MOD_KEEP_MOVING_DIRECT", "Keep moving", ActionDirect)
end

if _ON_ROAD_MOVING then
    AddAction("MOD_KEEP_MOVING_ROAD", "Keep moving on the road", ActionRoad)
end

--
-- Player
--

local _IS_DRAGGING

local function OnPlayerActivated(player, world)
    player:AddComponent("keepmoving")

    local keepmoving = player.components.keepmoving
    if keepmoving then
        keepmoving.is_client = IsClient()
        keepmoving.is_dst = IsDST()
        keepmoving.is_master_sim = world.ismastersim
        keepmoving.modname = modname
        keepmoving.world = world

        -- GetModConfigData
        local configs = {
            "on_road_points",
            "on_road_points_lighting",
        }

        for _, config in ipairs(configs) do
            keepmoving.config[config] = GetModConfigData(config)
        end

        -- roads
        keepmoving:GatherSaveDataRoads()
    end

    DebugString("Player", player:GetDisplayName(), "activated")
end

local function OnPlayerDeactivated(player)
    player:RemoveComponent("keepmoving")
    DebugString("Player", player:GetDisplayName(), "deactivated")
end

local function AddPlayerPostInit(onActivatedFn, onDeactivatedFn)
    DebugString("Game ID -", TheSim:GetGameID())

    if IsDST() then
        env.AddPrefabPostInit("world", function(_world)
            _world:ListenForEvent("playeractivated", function(world, player)
                if player == _G.ThePlayer then
                    onActivatedFn(player, world)
                end
            end)

            _world:ListenForEvent("playerdeactivated", function(_, player)
                if player == _G.ThePlayer then
                    onDeactivatedFn(player)
                end
            end)
        end)
    else
        env.AddPlayerPostInit(function(player)
            onActivatedFn(player)
        end)
    end

    DebugInit("AddPlayerPostInit")
end

local function PlayerActionPickerPostInit(_self, player)
    if player ~= _G.ThePlayer then
        return
    end

    --
    -- Helpers
    --

    local function GetOurMouseActions(keepmoving, lmb, rmb)
        local item = player.replica.inventory:GetActiveItem()

        if _DIRECT_MOVING and (not lmb or item) then
            lmb = BufferedAction(player, nil, ACTIONS.MOD_KEEP_MOVING_DIRECT)
        end

        if _ON_ROAD_MOVING and (not rmb or item) then
            if keepmoving:IsOnRoad(TheInput:GetWorldPosition():Get()) then
                rmb = BufferedAction(player, nil, ACTIONS.MOD_KEEP_MOVING_ROAD)
            end
        end

        return lmb, rmb
    end

    --
    -- Overrides
    --

    local OldDoGetMouseActions = _self.DoGetMouseActions

    local function NewDoGetMouseActions(self, position, _target)
        local lmb, rmb = OldDoGetMouseActions(self, position, _target)
        local keepmoving = player.components.keepmoving
        if not keepmoving
            or TheInput:GetHUDEntityUnderMouse()
            or (_MOUSE_DRAGGING_CHECK and _IS_DRAGGING)
        then
            return lmb, rmb
        end

        if TheInput:IsKeyDown(_KEY_ACTION) then
            -- We could have used lmb.target. However, the PlayerActionPicker has leftclickoverride
            -- and rightclickoverride so we can't trust that. A good example is Woodie's Weregoose
            -- form which overrides mouse actions.
            local target = TheInput:GetWorldEntityUnderMouse()
            if target then
                return lmb, rmb
            end

            if _REVERSE_ACTIONS then
                rmb, lmb = GetOurMouseActions(keepmoving, lmb, rmb)
            else
                lmb, rmb = GetOurMouseActions(keepmoving, lmb, rmb)
            end
        end

        return lmb, rmb
    end

    _self.DoGetMouseActions = NewDoGetMouseActions

    DebugInit("PlayerActionPickerPostInit")
end

local function PlayerControllerPostInit(_self, _player)
    if _player ~= _G.ThePlayer then
        return
    end

    --
    -- Helpers
    --

    local drag_start, drag_end

    -- We ignore ActionQueue(DST) mod here intentionally. Our mod won't work with theirs if the same
    -- action key is used. So there is no point to mess with their functions anyway.
    --
    -- From an engineering perspective, the method which ActionQueue(DST) mod uses for overriding
    -- PlayerController:OnControl() should never be used. Technically, we can fix this issue by
    -- either using the same approach or using the global input handler when ActionQueue(DST) mod is
    -- enabled. However, I don't see any valid reason to do that.
    local function ClearActionQueueRebornEntities()
        local actionqueuer = _player.components.actionqueuer
        if not actionqueuer
            or not actionqueuer.ClearActionThread
            or not actionqueuer.ClearSelectionThread
            or not actionqueuer.ClearSelectedEntities
        then
            return
        end

        actionqueuer:ClearActionThread()
        actionqueuer:ClearSelectionThread()
        actionqueuer:ClearSelectedEntities()
    end

    local function OurMouseAction(self, player, act)
        local keepmoving = player.components.keepmoving
        if not act or not keepmoving then
            return false
        end

        if IsOurAction(act.action)
            and not TheInput:GetHUDEntityUnderMouse()
            and not self:IsAOETargeting()
        then
            if act.action.fn(act) then
                ClearActionQueueRebornEntities()
                return true
            end
        end

        return false
    end

    --
    -- Overrides
    --

    local OldOnControl = _self.OnControl
    local OldOnLeftClick = _self.OnLeftClick
    local OldOnRightClick = _self.OnRightClick
    local OldOnUpdate = _self.OnUpdate

    local function NewOnControl(self, control, down)
        local keepmoving = _player.components.keepmoving
        if keepmoving and IsMoveButton(control) or control == CONTROL_ACTION then
            keepmoving:Stop()
        end

        return OldOnControl(self, control, down)
    end

    local function NewOnLeftClick(self, down)
        if not down
            and ((_MOUSE_DRAGGING_CHECK and not _IS_DRAGGING) or not _MOUSE_DRAGGING_CHECK)
            and OurMouseAction(self, _player, self:GetLeftMouseAction())
        then
            return
        end
        return OldOnLeftClick(self, down)
    end

    local function NewOnRightClick(self, down)
        if not down
            and ((_MOUSE_DRAGGING_CHECK and not _IS_DRAGGING) or not _MOUSE_DRAGGING_CHECK)
            and OurMouseAction(self, _player, self:GetRightMouseAction())
        then
            return
        end
        return OldOnRightClick(self, down)
    end

    local function NewOnUpdate(self, dt)
        if TheInput:IsKeyDown(_KEY_ACTION) then
            if not drag_start and TheInput:IsControlPressed(CONTROL_PRIMARY) then
                drag_start = TheInput:GetScreenPosition()
            elseif not TheInput:IsControlPressed(CONTROL_PRIMARY) then
                drag_start = nil
            end

            if TheInput:IsControlPressed(CONTROL_PRIMARY) and drag_start then
                drag_end = TheInput:GetScreenPosition()
                _IS_DRAGGING = math.abs(drag_start.x - drag_end.x)
                    + math.abs(drag_start.y - drag_end.y)
                    > 32
            else
                drag_end = nil
                _IS_DRAGGING = false
            end
        end
        return OldOnUpdate(self, dt)
    end

    _self.OnControl = NewOnControl
    _self.OnLeftClick = NewOnLeftClick
    _self.OnRightClick = NewOnRightClick
    --_self.OnUpdate = _MOUSE_DRAGGING_CHECK and NewOnUpdate or _self.OldOnUpdate

    DebugInit("PlayerControllerPostInit")
end

AddPlayerPostInit(OnPlayerActivated, OnPlayerDeactivated)
AddComponentPostInit("playeractionpicker", PlayerActionPickerPostInit)
AddComponentPostInit("playercontroller", PlayerControllerPostInit)
