require "busted.runner"()

describe("Utils", function()
    -- setup
    local match

    -- before_each initialization
    local Utils

    setup(function()
        -- match
        match = require "luassert.match"

        -- debug
        DebugSpyTerm()
        DebugSpyInit(spy)

        -- globals
        _G.ACTIONS = {
            WALKTO = { code = 163 },
        }
        _G.RPC = {
            DirectWalking = 16,
            LeftClick = 26,
            StopWalking = 46,
        }
    end)

    teardown(function()
        -- debug
        DebugSpyTerm()

        -- globals
        _G.ACTIONS = nil
        _G.BufferedAction = nil
        _G.RPC = nil
        _G.SendRPCToServer = nil
    end)

    before_each(function()
        -- initialization
        Utils = require "keepmoving/utils"

        -- debug
        DebugSpyClear()

        -- globals
        _G.BufferedAction = spy.new(ReturnValueFn({}))
        _G.SendRPCToServer = spy.new(Empty)
    end)

    describe("general", function()
        describe("IsHUDFocused", function()
            local player

            before_each(function()
                player = {
                    HUD = {
                        HasInputFocus = spy.new(ReturnValueFn(true)),
                    },
                }
            end)

            describe("when some chain fields are missing", function()
                it("should return true", function()
                    AssertChainNil(function()
                        assert.is_true(Utils.IsHUDFocused(player))
                    end, player, "HUD", "HasInputFocus")
                end)
            end)

            describe("when player.HUD:HasInputFocus()", function()
                local function AssertCall()
                    it("should call player.HUD:HasInputFocus()", function()
                        assert.spy(player.HUD.HasInputFocus).was_called(0)
                        Utils.IsHUDFocused(player)
                        assert.spy(player.HUD.HasInputFocus).was_called(1)
                        assert.spy(player.HUD.HasInputFocus).was_called_with(
                            match.is_ref(player.HUD)
                        )
                    end)
                end

                describe("returns true", function()
                    before_each(function()
                        player.HUD.HasInputFocus = spy.new(ReturnValueFn(true))
                    end)

                    AssertCall()

                    it("should return false", function()
                        assert.is_false(Utils.IsHUDFocused(player))
                    end)
                end)

                describe("returns false", function()
                    before_each(function()
                        player.HUD.HasInputFocus = spy.new(ReturnValueFn(false))
                    end)

                    AssertCall()

                    it("should return true", function()
                        assert.is_true(Utils.IsHUDFocused(player))
                    end)
                end)
            end)
        end)
    end)

    describe("chain", function()
        local value, netvar, GetTimeUntilPhase, clock, TheWorld

        before_each(function()
            value = 42
            netvar = { value = spy.new(ReturnValueFn(value)) }
            GetTimeUntilPhase = spy.new(ReturnValueFn(value))

            clock = {
                boolean = true,
                fn = ReturnValueFn(value),
                netvar = netvar,
                number = 1,
                string = "test",
                table = {},
                GetTimeUntilPhase = GetTimeUntilPhase,
            }

            TheWorld = {
                net = {
                    components = {
                        clock = clock,
                    },
                },
            }
        end)

        describe("ChainGet", function()
            describe("when an invalid src is passed", function()
                it("should return nil", function()
                    assert.is_nil(Utils.ChainGet(nil, "net"))
                    assert.is_nil(Utils.ChainGet("nil", "net"))
                    assert.is_nil(Utils.ChainGet(42, "net"))
                    assert.is_nil(Utils.ChainGet(true, "net"))
                end)
            end)

            describe("when some chain fields are missing", function()
                it("should return nil", function()
                    AssertChainNil(function()
                        assert.is_nil(Utils.ChainGet(
                            TheWorld,
                            "net",
                            "components",
                            "clock",
                            "GetTimeUntilPhase"
                        ))
                    end, TheWorld, "net", "components", "clock", "GetTimeUntilPhase")
                end)
            end)

            describe("when the last parameter is true", function()
                it("should return the last field call (function)", function()
                    assert.is_equal(value, Utils.ChainGet(
                        TheWorld,
                        "net",
                        "components",
                        "clock",
                        "fn",
                        true
                    ))
                end)

                it("should return the last field call (table as a function)", function()
                    assert.is_equal(value, Utils.ChainGet(
                        TheWorld,
                        "net",
                        "components",
                        "clock",
                        "GetTimeUntilPhase",
                        true
                    ))

                    assert.spy(GetTimeUntilPhase).was_called(1)
                    assert.spy(GetTimeUntilPhase).was_called_with(match.is_ref(clock))
                end)

                it("should return the last netvar value", function()
                    assert.is_equal(value, Utils.ChainGet(
                        TheWorld,
                        "net",
                        "components",
                        "clock",
                        "netvar",
                        true
                    ))

                    assert.spy(netvar.value).was_called(1)
                    assert.spy(netvar.value).was_called_with(match.is_ref(netvar))
                end)

                local fields = {
                    "boolean",
                    "number",
                    "string",
                    "table",
                }

                for _, field in pairs(fields) do
                    describe("and the previous parameter is a " .. field, function()
                        it("should return nil", function()
                            assert.is_nil(Utils.ChainGet(
                                TheWorld,
                                "net",
                                "components",
                                "clock",
                                field,
                                true
                            ), field)
                        end)
                    end)
                end

                describe("and the previous parameter is a nil", function()
                    it("should return nil", function()
                        assert.is_nil(Utils.ChainGet(
                            TheWorld,
                            "net",
                            "components",
                            "test",
                            true
                        ))
                    end)
                end)
            end)

            it("should return the last field", function()
                assert.is_equal(GetTimeUntilPhase, Utils.ChainGet(
                    TheWorld,
                    "net",
                    "components",
                    "clock",
                    "GetTimeUntilPhase"
                ))

                assert.spy(GetTimeUntilPhase).was_not_called()
            end)
        end)

        describe("ChainValidate", function()
            describe("when an invalid src is passed", function()
                it("should return false", function()
                    assert.is_false(Utils.ChainValidate(nil, "net"))
                    assert.is_false(Utils.ChainValidate("nil", "net"))
                    assert.is_false(Utils.ChainValidate(42, "net"))
                    assert.is_false(Utils.ChainValidate(true, "net"))
                end)
            end)

            describe("when some chain fields are missing", function()
                it("should return false", function()
                    AssertChainNil(function()
                        assert.is_false(Utils.ChainValidate(
                            TheWorld,
                            "net",
                            "components",
                            "clock",
                            "GetTimeUntilPhase"
                        ))
                    end, TheWorld, "net", "components", "clock", "GetTimeUntilPhase")
                end)
            end)

            describe("when all chain fields are available", function()
                it("should return true", function()
                    assert.is_true(Utils.ChainValidate(
                        TheWorld,
                        "net",
                        "components",
                        "clock",
                        "GetTimeUntilPhase"
                    ))
                end)
            end)
        end)
    end)

    describe("locomotor", function()
        local pt

        before_each(function()
            pt = Vector3(1, 0, 1)
        end)

        describe("IsLocomotorAvailable", function()
            local player

            before_each(function()
                player = {
                    components = {
                        locomotor = {},
                    },
                }
            end)

            describe("when some chain fields are missing", function()
                it("should return false", function()
                    AssertChainNil(function()
                        assert.is_false(Utils.IsLocomotorAvailable(player))
                    end, player, "components", "locomotor")
                end)
            end)

            describe("when the locomotor component is available", function()
                it("should return true", function()
                    assert.is_true(Utils.IsLocomotorAvailable(player))
                end)
            end)

            describe("when the locomotor component is not available", function()
                before_each(function()
                    player.components.locomotor = nil
                end)

                it("should return true", function()
                    assert.is_false(Utils.IsLocomotorAvailable(player))
                end)
            end)
        end)

        describe("RunInPointDirection", function()
            local player

            before_each(function()
                player = {
                    components = {
                        locomotor = {
                            RunInDirection = spy.new(Empty),
                        },
                    },
                    GetAngleToPoint = spy.new(ReturnValueFn(45)),
                    GetPosition = ReturnValueFn(Vector3(1, 0, -1)),
                    Transform = {
                        SetRotation = spy.new(Empty),
                    },
                }
            end)

            describe("when some chain fields are missing", function()
                it("should return false", function()
                    AssertChainNil(function()
                        assert.is_false(Utils.IsLocomotorAvailable(player))
                    end, player, "components", "locomotor")
                end)
            end)

            describe("when the locomotor component is available", function()
                it("should call player.Transform:SetRotation()", function()
                    assert.spy(player.Transform.SetRotation).was_called(0)
                    Utils.RunInPointDirection(player, pt)
                    assert.spy(player.Transform.SetRotation).was_called(1)
                    assert.spy(player.Transform.SetRotation).was_called_with(
                        match.is_ref(player.Transform),
                        45
                    )
                end)

                it("should call player.components.locomotor:RunInDirection()", function()
                    assert.spy(player.components.locomotor.RunInDirection).was_called(0)
                    Utils.RunInPointDirection(player, pt)
                    assert.spy(player.components.locomotor.RunInDirection).was_called(1)
                    assert.spy(player.components.locomotor.RunInDirection).was_called_with(
                        match.is_ref(player.components.locomotor),
                        45
                    )
                end)

                it("shouldn't call SendRPCToServer()", function()
                    assert.spy(_G.SendRPCToServer).was_called(0)
                    Utils.RunInPointDirection(player, pt)
                    assert.spy(_G.SendRPCToServer).was_called(0)
                end)

                it("should return direction and angle", function()
                    local dir, angle = Utils.RunInPointDirection(player, pt)
                    assert.is_same({ x = -0, y = 0, z = 1 }, dir)
                    assert.is_equal(45, angle)
                end)
            end)

            describe("when the locomotor component is not available", function()
                before_each(function()
                    player.components.locomotor = nil
                end)

                it("should call SendRPCToServer()", function()
                    assert.spy(_G.SendRPCToServer).was_called(0)
                    Utils.RunInPointDirection(player, pt)
                    assert.spy(_G.SendRPCToServer).was_called(1)
                    assert.spy(_G.SendRPCToServer).was_called_with(_G.RPC.DirectWalking, -0, 1)
                end)

                it("should return direction and angle", function()
                    local dir, angle = Utils.RunInPointDirection(player, pt)
                    assert.is_same({ x = -0, y = 0, z = 1 }, dir)
                    assert.is_equal(45, angle)
                end)
            end)
        end)

        describe("WalkToPoint", function()
            local player

            before_each(function()
                player = {
                    components = {
                        playercontroller = {
                            locomotor = {},
                            DoAction = spy.new(Empty),
                        },
                    },
                }
            end)

            describe("when the player controller is available", function()
                describe("and the locomotor component is available", function()
                    it("should call player.components.playercontroller:DoAction()", function()
                        assert.spy(player.components.playercontroller.DoAction).was_called(0)
                        Utils.WalkToPoint(player, pt)
                        assert.spy(player.components.playercontroller.DoAction).was_called(1)
                        assert.spy(player.components.playercontroller.DoAction).was_called_with(
                            match.is_ref(player.components.playercontroller),
                            {}
                        )
                    end)

                    it("shouldn't call SendRPCToServer()", function()
                        assert.spy(_G.SendRPCToServer).was_called(0)
                        Utils.WalkToPoint(player, pt)
                        assert.spy(_G.SendRPCToServer).was_called(0)
                    end)
                end)

                describe("and the locomotor component is not available", function()
                    before_each(function()
                        player.components.playercontroller.locomotor = nil
                    end)

                    it("should call SendRPCToServer()", function()
                        assert.spy(_G.SendRPCToServer).was_called(0)
                        Utils.WalkToPoint(player, pt)
                        assert.spy(_G.SendRPCToServer).was_called(1)
                        assert.spy(_G.SendRPCToServer).was_called_with(
                            _G.RPC.LeftClick,
                            _G.ACTIONS.WALKTO.code,
                            1,
                            1
                        )
                    end)
                end)
            end)

            describe("when the player controller is not available", function()
                before_each(function()
                    player.components.playercontroller = nil
                end)

                it("should debug string", function()
                    DebugSpyClear("DebugString")
                    Utils.WalkToPoint(player, pt)
                    DebugSpyAssertWasCalled("DebugError", 1, {
                        "Player controller is not available",
                    })
                end)
            end)
        end)

        describe("StopMoving", function()
            local player

            before_each(function()
                player = {
                    components = {
                        locomotor = {
                            Stop = spy.new(Empty),
                        },
                    },
                }
            end)

            describe("when the locomotor component is available", function()
                it("should call player.components.locomotor:DoAction()", function()
                    assert.spy(player.components.locomotor.Stop).was_called(0)
                    Utils.StopMoving(player)
                    assert.spy(player.components.locomotor.Stop).was_called(1)
                    assert.spy(player.components.locomotor.Stop).was_called_with(
                        match.is_ref(player.components.locomotor)
                    )
                end)

                it("shouldn't call SendRPCToServer()", function()
                    assert.spy(_G.SendRPCToServer).was_called(0)
                    Utils.StopMoving(player)
                    assert.spy(_G.SendRPCToServer).was_called(0)
                end)
            end)

            describe("when the locomotor component is not available", function()
                before_each(function()
                    player.components.locomotor = nil
                end)

                it("should call SendRPCToServer()", function()
                    assert.spy(_G.SendRPCToServer).was_called(0)
                    Utils.StopMoving(player)
                    assert.spy(_G.SendRPCToServer).was_called(1)
                    assert.spy(_G.SendRPCToServer).was_called_with(_G.RPC.StopWalking)
                end)
            end)
        end)
    end)
end)
