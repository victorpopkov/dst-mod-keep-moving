----
-- Point.
--
-- Includes a ground point entity.
--
-- **Source Code:** [https://github.com/victorpopkov/dst-mod-keep-moving](https://github.com/victorpopkov/dst-mod-keep-moving)
--
-- @classmod Point
--
-- @author Victor Popkov
-- @copyright 2020
-- @license MIT
-- @release 0.1.0-alpha
----
require "class"
require "keepmoving/constants"

local Point = Class(function(self, pos, point_type, is_light)
    self:DoInit(pos, point_type, is_light)
end)

--- Helpers
-- @section helpers

local function OnPlayerNear(self, anim, inst)
    if inst.Light then
        inst.Light:SetColour(unpack(self.color_near))
    end

    inst.AnimState:SetMultColour(self.color_near[1], self.color_near[2], self.color_near[3], 1)
    inst.AnimState:PlayAnimation(anim .. "_exit")
    inst:ListenForEvent("animover", function()
        self:Remove()
    end)
end

--- General
-- @section general

--- Enables lighting.
function Point:EnableLight()
    self.inst.Light:Enable(true)
    self.inst.Light:SetColour(unpack(self.color_default))
    self.inst.Light:SetFalloff(1)
    self.inst.Light:SetIntensity(.25)
    self.inst.Light:SetRadius(1 * self.scale)
end

--- Disables lighting.
function Point:DisableLight()
    self.inst.Light:Enable(false)
end

--- Removes point instance.
function Point:Remove()
    if self.inst and self.inst:IsValid() then
        self.inst:Remove()
    end
end

--- Initialization
-- @section initialization

--- Initializes.
--
-- Sets default fields and creates corresponding entity.
--
-- @tparam Vector3 pos Point position
-- @tparam[opt] number point_type Point type
-- @tparam[opt] boolean is_light Should the lighting be enabled?
function Point:DoInit(pos, point_type, is_light)
    local scale = .5
    local anim = "point"
    if point_type == MOD_KEEP_MOVING.POINTS.CHECKPOINT then
        scale = 1
        anim = "checkpoint"
    end

    -- general
    self.anim = anim
    self.is_light = is_light
    self.name = string.format("Point %s", tostring(pos))
    self.pt = pos
    self.scale = scale

    -- colors
    self.color_default = point_type == MOD_KEEP_MOVING.POINTS.CHECKPOINT
        and MOD_KEEP_MOVING.COLORS.WHITE
        or MOD_KEEP_MOVING.COLORS.RED

    self.color_near = MOD_KEEP_MOVING.COLORS.GREEN

    -- inst
    local inst = CreateEntity()

    -- inst (entity)
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:SetPristine()

    -- inst (transform)
    inst.Transform:SetPosition(pos:Get())

    -- inst (animation)
    inst.AnimState:SetBank("keep_moving_points")
    inst.AnimState:SetBuild("keep_moving_points")
    inst.AnimState:PlayAnimation(anim .. "_enter")

    if anim == "checkpoint" then
        inst:ListenForEvent("animover", function()
            inst.AnimState:PlayAnimation(anim .. "_anim", true)
        end)
    end

    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetMultColour(
        self.color_default[1],
        self.color_default[2],
        self.color_default[3],
        1
    )

    -- inst (playerprox)
    inst:AddComponent("playerprox")
    inst.components.playerprox:SetDist(2, 1)
    inst.components.playerprox:SetOnPlayerNear(function(...)
        return OnPlayerNear(self, anim, ...)
    end)

    -- inst (other)
    inst:AddTag("NOCLICK")

    self.inst = inst

    -- light
    if is_light then
        inst.entity:AddLight()
        self:EnableLight()
    end

    return inst
end

return Point
