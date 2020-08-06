require "busted.runner"()

describe("KeepMoving", function()
    -- setup
    local match
    local _os

    -- before_each initialization
    local inst, leader
    local KeepMoving, keepmoving

    setup(function()
        -- match
        match = require "luassert.match"

        -- debug
        DebugSpyTerm()
        DebugSpyInit(spy)

        -- globals
        _os = _G.os

        _G.TEST = true
        _G.TheWorld = {}
    end)

    teardown(function()
        -- debug
        DebugSpyTerm()

        -- globals
        _G.TEST = false
        _G.TheWorld = nil
    end)

    before_each(function()
        -- globals
        _G.os = mock({
            clock = ReturnValueFn(2),
        })

        -- initialization
        inst = mock({
            StartUpdatingComponent = Empty,
        })

        KeepMoving = require "components/keepmoving"
        keepmoving = KeepMoving(inst)

        -- debug
        DebugSpyClear()
    end)

    insulate("initialization", function()
        before_each(function()
            -- initialization
            inst = {
                StartUpdatingComponent = spy.new(Empty),
            }

            KeepMoving = require "components/keepmoving"
            keepmoving = KeepMoving(inst)
        end)

        local function AssertDefaults(self)
            -- general
            assert.is_equal(inst, self.inst)
            assert.is_false(self.is_client)
            assert.is_false(self.is_dst)
            assert.is_equal(_G.TheWorld.ismastersim, self.is_master_sim)
            assert.is_equal("KeepMoving", self.name)
            assert.is_nil(self.start_time)
            assert.is_equal(_G.TheWorld, self.world)

            -- direct moving
            assert.is_nil(self.direction)
            assert.is_nil(self.direction_angle)
            assert.is_false(self.is_direct_moving)

            -- on-road moving
            assert.is_false(self.is_on_road_moving)
            assert.is_nil(self.on_road_moving_correction_thread)
            assert.is_nil(self.on_road_moving_thread)
            assert.is_nil(self.road)
            assert.is_nil(self.road_accuracy)
            assert.is_nil(self.road_checkpoint)
            assert.is_nil(self.road_checkpoint_idx)
            assert.is_nil(self.road_correction)
            assert.is_nil(self.road_direction)
            assert.is_nil(self.road_next_checkpoint)
            assert.is_same({}, self.road_points)
            assert.is_nil(self.road_start)
            assert.is_same({}, self.roads)

            -- debugging
            assert.is_equal(0, self.debug_rpc_counter)

            -- config
            assert.is_table(self.config)
            assert.is_false(self.config.on_road_points)
            assert.is_true(self.config.on_road_points_lighting)
        end

        describe("using the constructor", function()
            before_each(function()
                keepmoving = KeepMoving(inst)
            end)

            it("should have the default fields", function()
                AssertDefaults(keepmoving)
            end)

            it("should call inst:StartUpdatingComponent()", function()
                assert.spy(inst.StartUpdatingComponent).was_called(2)
                assert.spy(inst.StartUpdatingComponent).was_called_with(
                    match.is_ref(inst),
                    match.is_ref(keepmoving)
                )
            end)
        end)

        describe("using DoInit()", function()
            before_each(function()
                KeepMoving:DoInit(inst)
            end)

            it("should have the default fields", function()
                AssertDefaults(KeepMoving)
            end)

            it("should call inst:StartUpdatingComponent()", function()
                assert.spy(inst.StartUpdatingComponent).was_called(2)
                assert.spy(inst.StartUpdatingComponent).was_called_with(
                    match.is_ref(inst),
                    match.is_ref(KeepMoving)
                )
            end)
        end)
    end)

    describe("on-road moving", function()
        describe("local", function()
            describe("GetNextRoadPositionOnRoadCorrection()", function()
                local inst_pos, pos, road_correction
                local state, _pos, _road_correction

                before_each(function()
                    inst_pos = Vector3(1, 0, -1)
                    pos = Vector3(2, 0, -2)
                    road_correction = Vector3(3, 0, -3)
                end)

                describe("when the road correction is not passed", function()
                    before_each(function()
                        road_correction = nil
                        state, _pos, _road_correction = keepmoving
                            ._GetNextRoadPositionOnRoadCorrection(inst_pos, pos, road_correction)
                    end)

                    it("should return false", function()
                        assert.is_false(state)
                    end)

                    it("should return the same position", function()
                        assert.is_equal(pos, _pos)
                    end)

                    it("should return nil road correction", function()
                        assert.is_nil(_road_correction)
                    end)
                end)

                describe("when the road correction is passed", function()
                    describe("and inst position is near road correction", function()
                        before_each(function()
                            inst_pos = Vector3(2.75, 0, -2.75)
                            state, _pos, _road_correction = keepmoving
                                ._GetNextRoadPositionOnRoadCorrection(
                                    inst_pos,
                                    pos,
                                    road_correction
                                )
                        end)

                        it("should return true state", function()
                            assert.is_true(state)
                        end)

                        it("should return the road correction position", function()
                            assert.is_equal(road_correction, _pos)
                        end)

                        it("should return nil road correction", function()
                            assert.is_nil(_road_correction)
                        end)
                    end)

                    describe("and inst position is not near road correction", function()
                        before_each(function()
                            state, _pos, _road_correction = keepmoving
                                ._GetNextRoadPositionOnRoadCorrection(
                                    inst_pos,
                                    pos,
                                    road_correction
                                )
                        end)

                        it("should return false", function()
                            assert.is_false(state)
                        end)

                        it("should return the same road correction", function()
                            assert.is_equal(road_correction, _road_correction)
                        end)
                    end)
                end)
            end)

            describe("GetNextRoadPositionOnCheckpoint()", function()
                local road, inst_pos, pos, dir, cp_idx
                local state, _pos, _cp_idx, next_cp_idx

                before_each(function()
                    road = {
                        Vector3(3, 0, -3),
                        Vector3(4, 0, -4),
                        Vector3(5, 0, -5),
                        Vector3(6, 0, -6),
                    }

                    inst_pos = Vector3(1, 0, -1)
                    pos = Vector3(2, 0, -2)
                    dir = 1
                    cp_idx = 2
                end)

                describe("when not near checkpoint", function()
                    before_each(function()
                        state, _pos, _cp_idx, next_cp_idx = keepmoving
                            ._GetNextRoadPositionOnCheckpoint(
                                road,
                                inst_pos,
                                pos,
                                dir,
                                cp_idx
                            )
                    end)

                    it("should return false", function()
                        assert.is_false(state)
                    end)

                    it("should return the same position", function()
                        assert.is_equal(pos, _pos)
                    end)

                    it("should return the same checkpoint index", function()
                        assert.is_equal(cp_idx, _cp_idx)
                    end)

                    it("should return the same next checkpoint index", function()
                        assert.is_equal(3, next_cp_idx)
                    end)
                end)

                describe("when near checkpoint", function()
                    before_each(function()
                        inst_pos = Vector3(3.75, 0, -3.75)
                        state, _pos, _cp_idx, next_cp_idx = keepmoving
                            ._GetNextRoadPositionOnCheckpoint(
                                road,
                                inst_pos,
                                pos,
                                dir,
                                cp_idx
                            )
                    end)

                    describe("and direction is positive", function()
                        describe("and it's not a last checkpoint", function()
                            it("should return true", function()
                                assert.is_true(state)
                            end)

                            it("should return new position", function()
                                assert.is_equal(road[3], _pos)
                            end)

                            it("should return new checkpoint index", function()
                                assert.is_equal(3, _cp_idx)
                            end)

                            it("should return new next checkpoint index", function()
                                assert.is_equal(4, next_cp_idx)
                            end)
                        end)

                        describe("and it's a last checkpoint", function()
                            before_each(function()
                                inst_pos = Vector3(5.75, 0, -5.75)
                                cp_idx = 4
                                state, _pos, _cp_idx, next_cp_idx = keepmoving
                                    ._GetNextRoadPositionOnCheckpoint(
                                        road,
                                        inst_pos,
                                        pos,
                                        dir,
                                        cp_idx
                                    )
                            end)

                            it("should return true", function()
                                assert.is_true(state)
                            end)

                            it("should return nil position", function()
                                assert.is_nil(_pos)
                            end)

                            it("should return the same checkpoint index", function()
                                assert.is_equal(cp_idx, _cp_idx)
                            end)

                            it("should return nil checkpoint index", function()
                                assert.is_nil(next_cp_idx)
                            end)
                        end)
                    end)

                    describe("and direction is negative", function()
                        describe("and it's not a last checkpoint", function()
                            before_each(function()
                                dir = -1
                                cp_idx = 2
                                state, _pos, _cp_idx, next_cp_idx = keepmoving
                                    ._GetNextRoadPositionOnCheckpoint(
                                        road,
                                        inst_pos,
                                        pos,
                                        dir,
                                        cp_idx
                                    )
                            end)

                            describe("and it's not a first checkpoint", function()
                                it("should return true", function()
                                    assert.is_true(state)
                                end)

                                it("should return new position", function()
                                    assert.is_equal(road[1], _pos)
                                end)

                                it("should return new checkpoint index", function()
                                    assert.is_equal(1, _cp_idx)
                                end)

                                it("should return nil next checkpoint index", function()
                                    assert.is_nil(next_cp_idx)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end)
