----
-- Component `keepmoving`.
--
-- Includes moving features/functionality.
--
-- **Source Code:** [https://github.com/victorpopkov/dst-mod-keep-moving](https://github.com/victorpopkov/dst-mod-keep-moving)
--
-- @classmod KeepMoving
--
-- @author Victor Popkov
-- @copyright 2020
-- @license MIT
-- @release 0.1.0-alpha
----
local Point = require "keepmoving/point"
local Utils = require "keepmoving/utils"

local _NEAR_DIST_SQ = 1
local _ON_ROAD_MOVING_CORRECTION_THREAD_ID = "on_road_moving_correction_thread"
local _ON_ROAD_MOVING_THREAD_ID = "on_road_moving_thread"

local KeepMoving = Class(function(self, inst)
    self:DoInit(inst)
end)

--- Helpers
-- @section helpers

local function WalkToPoint(self, pt)
    Utils.WalkToPoint(self.inst, pt)
    if _G.KeepMovingDebug then
        self.debug_rpc_counter = self.debug_rpc_counter + 1
    end
end

--- General
-- @section general

--- Checks if the player is idle.
-- @treturn boolean
function KeepMoving:IsIdle()
    if self.is_master_sim and self.inst.sg then
        return self.inst.sg:HasStateTag("idle")
            or (self.inst:HasTag("idle") and self.inst:HasTag("nopredict"))
    end
    return self.inst.AnimState:IsCurrentAnimation("idle_pre")
        or self.inst.AnimState:IsCurrentAnimation("idle_loop")
        or self.inst.AnimState:IsCurrentAnimation("idle_pst")
end

--- Stops direct and on-road moving.
--
-- General wrapper to call `StopDirectMoving` and/or `StopOnRoadMoving` based on the current state.
--
-- @treturn boolean
function KeepMoving:Stop()
    if Utils.IsHUDFocused(self.inst) then
        if self:IsDirectMoving() then
            self:StopDirectMoving()
            return true
        end

        if self:IsOnRoadMoving() then
            self:StopOnRoadMoving()
            return true
        end
    end
    return false
end

--- Direct moving
-- @section direct

local function GetCompassDirectionFromAngle(angle)
    -- there should be a better way to do it, but I don't care much as this function is used only
    -- for debugging anyway
    local direction, diff_closest
    local angle_correction = 135
    local directions = {
        N = 0,
        S = 180,
        NE = 45,
        E = 90,
        SE = 135,
        NW = -45,
        W = -90,
        SW = -135
    }

    for k, v in pairs(directions) do
        local diff = math.abs(anglediff(angle - angle_correction, v))
        if not direction or diff < diff_closest then
            direction, diff_closest = k, diff
        end
    end

    return direction
end

--- Gets the direct moving state.
-- @treturn boolean
function KeepMoving:IsDirectMoving()
    return self.is_direct_moving
end

--- Starts the direct moving.
--
-- Starts locomotor direct movement and prepares corresponding class fields.
--
-- @tparam number pt Point where tp move
function KeepMoving:StartDirectMoving(pt)
    local direction, angle = Utils.RunInPointDirection(self.inst, pt)

    self.direction = direction
    self.is_direct_moving = true
    self.start_time = os.clock()

    self:DebugString(string.format(
        "Started direct moving: %s. Direction: %s. Angle: %d",
        GetCompassDirectionFromAngle(angle),
        tostring(direction),
        angle
    ))
end

--- Stops the direct moving.
--
-- Stops locomotor movements and resets corresponding class fields.
function KeepMoving:StopDirectMoving()
    Utils.StopMoving()

    if self.start_time then
        self:DebugString(
            string.format(
                "Stopped direct moving. Time: %2.4f",
                os.clock() - self.start_time
            )
        )
    else
        self:DebugString("Stopped direct moving")
    end

    self.direction = nil
    self.is_direct_moving = false
    self.start_time = nil
end

--- On-road moving
-- @section on-road

local function AddRoadCheckpoint(self, pos)
    local key = string.format("%d_%d_%d", math.abs(pos.x), math.abs(pos.z), math.abs(pos.y))
    if not self.road_points[key] then
        self.road_points[key] = Point(
            pos,
            MOD_KEEP_MOVING.POINTS.CHECKPOINT,
            self.config.on_road_points_lighting
        )
    end
end

local function AddRoadPoint(self, pos)
    local key = string.format("%d_%d_%d", math.abs(pos.x), math.abs(pos.z), math.abs(pos.y))
    if not self.road_points[key] then
        self.road_points[key] = Point(
            pos,
            MOD_KEEP_MOVING.POINTS.POINT,
            self.config.on_road_points_lighting
        )
    end
end

local function RemoveRoadPoints(self)
    if self.road_points and Utils.TableCount(self.road_points) > 0 then
        self:DebugString("Removing road points...")
        for _, v in pairs(self.road_points) do
            v:Remove()
        end
        self.road_points = {}
    end
end

local function GetVectorOnSegment(p, p1, p2)
    local px, py, pz = p:Get()
    local x1, y1, z1 = p1:Get()
    local x2, y2, z2 = p2:Get()

    local dx, dy, dz = x2 - x1, y2 - y1, z2 - z1
    local d = (dx * dx + dy * dy + dz * dz)
    if d == 0 then
        return x1, y1, z1
    end

    local cx, cy, cz = px - x1, py - y1, pz - z1
    local u = (cx * dx + cy * dy + cz * dz) / d
    if u < 0 then
        u = 0
    elseif u > 1 then
        u = 1
    end

    return Vector3(x1 + u * dx, y1 + u * dy, z1 + u * dz)
end

local function GetClosestRoad(roads, inst, pt)
    local v1, v2, seg, seg_dist_sq
    local inst_pos, sp
    local closest_dist, road_idx, start
    local cp, cp_idx, next_cp, next_cp_idx, dir

    for i, road in ipairs(roads) do
        for j = 1, #road do
            if j >= 2 then
                v1 = road[j - 1]
                v2 = road[j]
                seg = GetVectorOnSegment(pt, v1, v2)
                seg_dist_sq = pt:DistSq(seg)

                inst_pos = inst:GetPosition()
                sp = GetVectorOnSegment(inst_pos, v1, v2)

                if closest_dist == nil or seg_dist_sq < closest_dist then
                    closest_dist = seg_dist_sq
                    road_idx = i
                    start = seg

                    -- I would normally use Trigonometry to get the direction but the simple
                    -- distance comparison does the work like a charm. Consider using math.atan2()
                    -- or something similar.
                    if v1:DistSq(seg) >= v1:DistSq(sp) then
                        cp = v2
                        cp_idx = j
                        next_cp = road[j + 1]
                        next_cp_idx = j + 1
                        dir = 1
                    else
                        cp = v1
                        cp_idx = j - 1
                        next_cp = road[j]
                        next_cp_idx = j
                        dir = -1
                    end
                end
            end
        end
    end

    return road_idx, start, cp, cp_idx, next_cp, next_cp_idx, dir
end

local function GetNextRoadValuesOnCorrection(inst_pos, pos, road_correction)
    if road_correction then
        pos = road_correction
        if inst_pos:DistSq(pos) < _NEAR_DIST_SQ then
            return true, pos
        end
    end
    return false, pos, road_correction
end

local function GetNextRoadValuesOnCheckpoint(road, inst_pos, pos, dir, cp_idx)
    local next_cp_idx = cp_idx + dir
    local next_cp = road[next_cp_idx]

    if road[cp_idx] and inst_pos:DistSq(road[cp_idx]) < _NEAR_DIST_SQ then
        pos = next_cp
        cp_idx = next_cp and next_cp_idx or cp_idx
        next_cp_idx = cp_idx + dir
        next_cp = road[next_cp_idx]
        return true, pos, cp_idx, next_cp and next_cp_idx
    end

    return false, pos, cp_idx, next_cp_idx
end

local function GetNextRoadValues(
    self,
    start,
    pos,
    dir,
    cp_idx,
    cp,
    next_cp_idx,
    next_cp
)
    local state
    local inst_pos = self.inst:GetPosition()

    -- move to the first checkpoint after reaching the start
    if inst_pos:DistSq(start) < _NEAR_DIST_SQ then
        pos = cp
    end

    -- on road correction
    state, pos, self.road_correction = GetNextRoadValuesOnCorrection(
        inst_pos,
        pos,
        self.road_correction
    )

    pos = state and not self.road_correction and cp or pos

    -- on checkpoint
    local new_pos, new_cp_idx, new_next_cp_idx
    state, new_pos, new_cp_idx, new_next_cp_idx = GetNextRoadValuesOnCheckpoint(
        self.road,
        inst_pos,
        pos,
        dir,
        cp_idx
    )

    cp_idx = cp_idx ~= nil and cp_idx or new_cp_idx
    next_cp_idx = next_cp_idx ~= nil and next_cp_idx or new_next_cp_idx

    if state then
        if next_cp then
            self:DebugString(string.format(
                "Near checkpoint: %d %s. Next: %d %s",
                cp_idx,
                tostring(cp),
                next_cp_idx,
                tostring(next_cp)
            ))
        else
            self.is_on_road_moving = false
            self:DebugString(string.format("Near the last checkpoint: %d %s", cp_idx, tostring(cp)))
        end

        pos, cp_idx, next_cp_idx = new_pos, new_cp_idx, new_next_cp_idx
        cp = self.road[cp_idx]
        next_cp = self.road[next_cp_idx]
    end

    return pos, cp_idx, cp, next_cp_idx, next_cp
end

local function ResetOnRoadFields(self)
    -- general
    self.start_time = nil

    -- on-road moving
    self.is_on_road_moving = false
    self.on_road_moving_correction_thread = nil
    self.on_road_moving_thread = nil
    self.road = nil
    self.road_accuracy = 0
    self.road_checkpoint = nil
    self.road_checkpoint_idx = nil
    self.road_correction = nil
    self.road_direction = nil
    self.road_next_checkpoint = nil
    self.road_start = nil

    -- debugging
    self.debug_rpc_counter = 0

    -- remove road points
    RemoveRoadPoints(self)
end

--- Gets the on-road moving state.
-- @treturn boolean
function KeepMoving:IsOnRoadMoving()
    return self.is_on_road_moving
end

--- Checks if coordinates are on a road.
--
-- This is a convenience method returning:
--
--    RoadManager:IsOnRoad()
--
-- @tparam number x
-- @tparam number y
-- @tparam number z
-- @treturn table Roads
function KeepMoving:IsOnRoad(x, y, z) -- luacheck: only
    return RoadManager:IsOnRoad(x, y, z)
end

--- Gathers roads from the save data file.
-- @treturn table Roads
function KeepMoving:GatherSaveDataRoads()
    self:DebugString("Gathering roads from the save data file...")
    local save_data = Utils.SaveDataLoad()
    local save_data_roads = Utils.ChainGet(save_data, "map", "roads")

    if save_data_roads then
        local roads = {}

        -- we don't care about keys and sorting
        local points
        for _, road in pairs(save_data_roads) do
            points = {}
            -- we don't need weights and only store points
            for _, v in pairs(road) do
                if type(v) ~= "number" then
                    table.insert(points, Vector3(v[1], 0, v[2]))
                end
            end
            table.insert(roads, points)
        end

        if roads and #roads > 0 then
            self:DebugString("Roads:", #roads)
        else
            self:DebugError("No roads found")
        end

        self.roads = roads

        return roads
    else
        self:DebugError("No roads found")
    end
end

--- Gets the closest road to the point.
--
-- Starts the thread to keep moving on a road and starts the on-road moving correction thread as
-- well by calling `StartOnRoadMovingCorrectionThread`.
--
-- @tparam Vector3 pt Point from where to look (usually a player position)
-- @treturn Vector3 Road index
-- @treturn Vector3 On-road movement starting point
-- @treturn number Road checkpoint index
-- @treturn number Next road checkpoint
-- @treturn number Direction
function KeepMoving:GetClosestRoad(pt)
    return GetClosestRoad(self.roads, self.inst, pt)
end

--- Starts the on-road moving thread.
--
-- Starts the thread to keep moving on a road and starts the on-road moving correction thread as
-- well by calling `StartOnRoadMovingCorrectionThread`.
--
-- @tparam Vector3 start On-road movement starting point
-- @tparam Vector3 cp Road checkpoint
-- @tparam number cp_idx Road checkpoint index
-- @tparam number next_cp Next road checkpoint
-- @tparam number dir Direction
function KeepMoving:StartOnRoadMovingThread(start, cp, cp_idx, next_cp, dir)
    local next_cp_idx, pos, pos_previous

    self.on_road_moving_thread = Utils.ThreadStart(_ON_ROAD_MOVING_THREAD_ID, function()
        -- start on-road moving correction thread
        if not self.on_road_moving_correction_thread
            and self.inst:GetPosition():DistSq(start) < _NEAR_DIST_SQ
        then
            self:StartOnRoadMovingCorrectionThread()
        end

        -- getting the next position
        pos, cp_idx, cp, next_cp_idx, next_cp = GetNextRoadValues(
            self,
            start,
            pos,
            dir,
            cp_idx,
            cp,
            next_cp_idx,
            next_cp
        )

        -- when the player is idling or the new position is acquired
        if self.is_on_road_moving
            and pos
            and (self:IsIdle() or (not pos_previous or pos_previous ~= pos))
        then
            pos_previous = pos
            WalkToPoint(self, pos)
            if self.config.on_road_points then
                AddRoadPoint(self, pos)
            end
        end

        -- sync working values with fields
        self.road_checkpoint = cp
        self.road_checkpoint_idx = cp_idx
        self.road_next_checkpoint = next_cp

        Sleep(FRAMES)
    end, function()
        return self.inst:IsValid() and self:IsOnRoadMoving()
    end, function()
        pos = start
        self.inst:ClearBufferedAction()
    end, function()
        ResetOnRoadFields(self)
    end)
end

--- Gets the next road correction point.
--
-- Gets the next road point where the player should go in order to correct his/her current path to
-- not move away from the road. Should be used with the smallest passed distance as possible and
-- with the most optimal passed step size as well in order to not "eat" up more CPU power.
--
-- In a perfect world this method should be replaced with points already predefined after the world
-- load before starting moving.
--
-- See `StartOnRoadMovingCorrectionThread` description for more explanation.
--
-- @tparam Vector3 pos Position from where to look
-- @tparam number dist Distance limit
-- @tparam number step Step size
-- @todo Optimize KeepMoving:GetNextRoadCorrectionPoint() and return the furthest average instead
function KeepMoving:GetNextRoadCorrectionPoint(pos, dist, step)
    local next_pos
    local checkpoint, checkpoint_dist_sq
    local next_checkpoint, next_checkpoint_dist_sq

    for xi = -dist, dist, step do
        for zi = -dist, dist, step do
            next_pos = Vector3(pos.x + xi, 0, pos.z + zi)
            checkpoint = self.road_checkpoint
            if checkpoint and self:IsOnRoad(next_pos:Get()) then
                checkpoint_dist_sq = checkpoint:DistSq(next_pos)
                if not next_checkpoint or (checkpoint_dist_sq < next_checkpoint_dist_sq) then
                    next_checkpoint = next_pos
                    next_checkpoint_dist_sq = checkpoint_dist_sq
                end
            end
        end
    end

    return next_checkpoint
end

--- Starts the on-road moving correction thread.
--
-- Starts the thread to correct on-road moving positions by calling `GetNextRoadCorrectionPoint`
-- to get the next correction point.
--
-- It's not the best solution, but it works with a good enough accuracy. Testing has shown that this
-- method gives ~100% accuracy in an ideal environment and ~80% in the worst-case scenario.
-- On average: ~87%.
--
-- Optimally, the path between checkpoints should already be predefined before starting moving. The
-- prototype did include the most optimal pathfinding between checkpoints during the world load
-- using their `RoadManager:IsOnRoad()` but it took extra 4-5 seconds in loading time. The accuracy
-- for the worst-case scenario did improve significantly (from ~80% to ~92%) even for the first
-- iteration of the algorithm. But the algorithm itself wasn't mature enough to be released in my
-- opinion.
--
-- However, ideally, their `RoadManager` road drawing method should be used instead by either
-- reverse-engineering or simply guessing their curve vertex values of the Cubic Bezier spline-like
-- algorithm. But the cobblestone road (usually road #1) is a different case and even if we guess
-- the vertex values this will only improve overall accuracy and not for the #1 road unless you
-- waste more CPU power. If you are planning to improve the algorithm, it would be easier just to
-- ask the developers about that.
--
-- But I'm lazy and don't even see the point in that... So here we are, using the "correction"
-- method instead.
function KeepMoving:StartOnRoadMovingCorrectionThread()
    local pos, correction

    local total_frames = 0
    local total_frames_on_road = 0

    self.on_road_moving_correction_thread = Utils.ThreadStart(
        _ON_ROAD_MOVING_CORRECTION_THREAD_ID,
        function()
            pos = self.inst:GetPosition()

            if _G.KeepMovingDebug then
                total_frames = total_frames + 1
            end

            if _G.KeepMovingDebug and self:IsOnRoad(pos:Get()) then
                total_frames_on_road = total_frames_on_road + 1
                self.road_accuracy = total_frames_on_road * 100 / total_frames
            elseif not self.road_correction then
                self:DebugString("Not on road. Correcting...")

                -- Find the farthest road point by checking each "step" if we are on the road. The
                -- KeepMoving:GetNextRoadCorrectionPoint() should be optimized as there is no point
                -- in checking all the "steps" especially behind the player. Moreover, the farthest
                -- point is not ideal and it would be better to use some interpolation methods to
                -- find the furthest average and return it instead.
                correction = self:GetNextRoadCorrectionPoint(pos, 6, 2)
                if correction then
                    self.road_correction = correction
                end
            end

            Sleep(FRAMES)
        end,
        function()
            return self.inst:IsValid() and self:IsOnRoadMoving()
        end,
        nil,
        function()
            self:DebugString("Accuracy:", string.format("%2.2f%%", self.road_accuracy))
        end
    )
end

--- Starts on-road moving.
--
-- Searches for the closest road to the player using `GetClosestRoad`, prepares corresponding class
-- fields and then calls `StartOnRoadMovingThread` to start on-road moving thread.
--
-- @tparam Vector3 pos Screen position
-- @treturn boolean
function KeepMoving:StartOnRoadMoving(pos)
    if not self.roads or #self.roads == 0 then
        self:DebugError("No roads available")
        return false
    end

    if self.is_on_road_moving then
        self:DebugError("Already on-road moving")
        return false
    end

    self:DebugString("Searching for the closest road...")

    local idx, start, cp, cp_idx, next_cp, _, dir = self:GetClosestRoad(pos)
    local road = self.roads[idx]

    if road and start then
        -- fields (general)
        self.start_time = os.clock()

        -- fields (on-road moving)
        self.is_on_road_moving = true
        self.road = road
        self.road_accuracy = 0
        self.road_checkpoint = cp
        self.road_checkpoint_idx = cp_idx
        self.road_correction = nil
        self.road_direction = dir
        self.road_next_checkpoint = next_cp
        self.road_start = start

        -- fields (debugging)
        self.debug_rpc_counter = 0

        -- debugging
        self:DebugString(string.format("Found road: %d. Checkpoints: %d", idx, #self.road, dir))
        self:DebugString(string.format(
            "Start: %s. Checkpoint: %d %s",
            tostring(start),
            cp_idx,
            tostring(cp)
        ))

        -- add road points
        if self.config.on_road_points then
            self:DebugString("Adding road points...")
            for _, v in pairs(road) do
                AddRoadCheckpoint(self, v)
            end
        end

        -- start
        self:DebugString(string.format("Started on-road moving. Direction: %d...", dir))
        self:StartOnRoadMovingThread(start, cp, cp_idx, next_cp, dir)

        return true
    else
        self:DebugError("No road found")
    end

    return false
end

--- Stops on-road moving.
-- @treturn boolean
function KeepMoving:StopOnRoadMoving()
    if not self.is_on_road_moving then
        self:DebugError("No on-road moving")
        return false
    end

    if not self.on_road_moving_thread then
        self:DebugError("No active thread")
        return false
    end

    self:DebugString(string.format(
        "Stopped on-road moving. RPCs: %d. Time: %2.4f",
        self.debug_rpc_counter,
        os.clock() - self.start_time
    ))

    self.is_on_road_moving = false

    return true
end

--- Initialization
-- @section initialization

--- Initializes.
--
-- Sets default fields, adds debug methods and starts the component.
--
-- @tparam EntityScript inst Player instance
function KeepMoving:DoInit(inst)
    Utils.AddDebugMethods(self)

    -- general
    self.inst = inst
    self.is_client = false
    self.is_dst = false
    self.is_master_sim = TheWorld.ismastersim
    self.name = "KeepMoving"
    self.start_time = nil
    self.world = TheWorld

    -- direct moving
    self.direction = nil
    self.direction_angle = nil
    self.is_direct_moving = false

    -- on-road moving
    self.is_on_road_moving = false
    self.on_road_moving_correction_thread = nil
    self.on_road_moving_thread = nil
    self.road = nil
    self.road_accuracy = nil
    self.road_checkpoint = nil
    self.road_checkpoint_idx = nil
    self.road_correction = nil
    self.road_direction = nil
    self.road_next_checkpoint = nil
    self.road_points = {}
    self.road_start = nil
    self.roads = {}

    -- debugging
    self.debug_rpc_counter = 0

    -- config
    self.config = {
        on_road_points = false,
        on_road_points_lighting = true,
    }

    -- update
    inst:StartUpdatingComponent(self)

    -- tests
    if _G.TEST then
        self._GetNextRoadPositionOnCheckpoint = GetNextRoadValuesOnCheckpoint
        self._GetNextRoadPositionOnRoadCorrection = GetNextRoadValuesOnCorrection
    end

    self:DebugInit(self.name)
end

return KeepMoving
