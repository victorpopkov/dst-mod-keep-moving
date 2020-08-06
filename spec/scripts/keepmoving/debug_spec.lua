require "busted.runner"()

describe("Debug", function()
    -- setup
    local match
    local _os

    -- before_each initialization
    local modname
    local Debug, debug

    setup(function()
        -- match
        match = require "luassert.match"

        -- debug
        DebugSpyTerm()
        DebugSpyInit(spy)

        -- globals
        _os = _G.os

        -- initialization
        modname = "dst-mod-keep-moving"
    end)

    teardown(function()
        -- debug
        DebugSpyTerm()

        -- globals
        _G.os = _os
        _G.scheduler = nil
    end)

    before_each(function()
        -- globals
        _G.os = mock({
            clock = ReturnValueFn(2),
        })
        _G.scheduler = mock({
            GetCurrentTask = ReturnValueFn({ id = "thread" }),
        })

        -- initialization
        Debug = require "keepmoving/debug"
        Debug = Debug(modname)

        -- debug
        DebugSpyClear()
    end)

    insulate("initialization", function()
        before_each(function()
            -- initialization
            Debug = require "keepmoving/debug"
            debug = Debug(modname)
        end)

        local function AssertDefaults(self)
            -- general
            assert.is_same({}, self.is_debug)
            assert.is_false(self.is_enabled)
            assert.is_equal(modname, self.modname)
            assert.is_equal("Debug", self.name)
            assert.is_nil(self.start_time)
        end

        describe("using the constructor", function()
            before_each(function()
                debug = Debug(modname)
            end)

            it("should have the default fields", function()
                AssertDefaults(debug)
            end)
        end)

        describe("using DoInit()", function()
            before_each(function()
                debug:DoInit(modname)
            end)

            it("should have the default fields", function()
                AssertDefaults(debug)
            end)
        end)
    end)

    describe("general", function()
        describe("should have the getter", function()
            it("IsEnabled()", function()
                AssertGetter(debug, "is_enabled", "IsEnabled")
            end)
        end)

        describe("should have the setter", function()
            it("SetIsEnabled()", function()
                AssertSetter(debug, "is_enabled", "SetIsEnabled")
            end)
        end)

        describe("Enable()", function()
            before_each(function()
                debug.is_enabled = false
            end)

            it("should enable debug", function()
                debug:Enable()
                assert.is_true(debug.is_enabled)
            end)
        end)

        describe("Disable()", function()
            before_each(function()
                debug.is_enabled = true
            end)

            it("should disable debug", function()
                debug:Disable()
                assert.is_false(debug.is_enabled)
            end)
        end)

        describe("IsDebug()", function()
            before_each(function()
                debug.is_debug = {
                    test = true,
                }
            end)

            describe("when debugging", function()
                it("should return true", function()
                    assert.is_true(debug:IsDebug("test"))
                end)
            end)

            describe("when not debugging", function()
                before_each(function()
                    debug.is_debug = {}
                end)

                it("should return false", function()
                    assert.is_false(debug:IsDebug("test"))
                end)
            end)
        end)

        describe("IsDebug()", function()
            local enable

            before_each(function()
                debug.is_debug = {}
            end)

            describe("when the passed value is true", function()
                before_each(function()
                    enable = true
                end)

                it("should add debug value as true", function()
                    assert.is_nil(debug.is_debug.test)
                    debug:SetIsDebug("test", enable)
                    assert.is_true(debug.is_debug.test)
                end)
            end)

            describe("when the passed value is false", function()
                before_each(function()
                    enable = false
                end)

                it("should add debug value as false", function()
                    assert.is_nil(debug.is_debug.test)
                    debug:SetIsDebug("test", enable)
                    assert.is_false(debug.is_debug.test)
                end)
            end)

            describe("when the passed value is any other non-nil and non-false value", function()
                before_each(function()
                    enable = "test"
                end)

                it("should add debug value as true", function()
                    assert.is_nil(debug.is_debug.test)
                    debug:SetIsDebug("test", enable)
                    assert.is_true(debug.is_debug.test)
                end)
            end)
        end)

        describe("DebugString()", function()
            local _print

            setup(function()
                _print = _G.print
            end)

            teardown(function()
                _G.print = _print
            end)

            before_each(function()
                _G.print = spy.new(Empty)
            end)

            describe("when debugging is enabled", function()
                before_each(function()
                    debug.is_enabled = true
                end)

                describe("and not inside thread", function()
                    before_each(function()
                        _G.scheduler.GetCurrentTask = spy.new(ReturnValueFn(nil))
                    end)

                    describe("and only single argument is passed", function()
                        it("should call global print", function()
                            assert.spy(_G.print).was_called(0)
                            debug:DebugString("test")
                            assert.spy(_G.print).was_called(1)
                            assert.spy(_G.print).was_called_with("[" .. modname .. "] test")
                        end)
                    end)

                    describe("and multiple arguments are passed", function()
                        it("should call global print", function()
                            assert.spy(_G.print).was_called(0)
                            debug:DebugString("hello", "world", 1)
                            assert.spy(_G.print).was_called(1)
                            assert.spy(_G.print).was_called_with(
                                "[" .. modname .. "] hello world 1"
                            )
                        end)
                    end)
                end)

                describe("and inside thread", function()
                    describe("and only single argument is passed", function()
                        it("should call global print", function()
                            assert.spy(_G.print).was_called(0)
                            debug:DebugString("test")
                            assert.spy(_G.print).was_called(1)
                            assert.spy(_G.print).was_called_with(
                                "[" .. modname .. "] [thread] test"
                            )
                        end)
                    end)

                    describe("and multiple arguments are passed", function()
                        it("should call global print", function()
                            assert.spy(_G.print).was_called(0)
                            debug:DebugString("hello", "world", 1)
                            assert.spy(_G.print).was_called(1)
                            assert.spy(_G.print).was_called_with(
                                "[" .. modname .. "] [thread] hello world 1"
                            )
                        end)
                    end)
                end)
            end)

            describe("when debugging is not enabled", function()
                before_each(function()
                    debug.is_enabled = false
                end)

                it("shouldn't call global print", function()
                    assert.spy(_G.print).was_called(0)
                    debug:DebugString("test")
                    assert.spy(_G.print).was_called(0)
                end)
            end)
        end)

        describe("DebugStringStart()", function()
            before_each(function()
                debug.DebugString = spy.new(Empty)
            end)

            it("should set self.start_time", function()
                assert.is_nil(debug.start_time)
                debug:DebugStringStart("test")
                assert.is_equal(2, debug.start_time)
            end)

            it("should call DebugString() with passed arguments", function()
                assert.spy(debug.DebugString).was_called(0)
                debug:DebugStringStart("hello", "world", 1)
                assert.spy(debug.DebugString).was_called(1)
                assert.spy(debug.DebugString).was_called_with(
                    match.is_ref(debug),
                    "hello",
                    "world",
                    1
                )
            end)
        end)

        describe("DebugStringStop()", function()
            before_each(function()
                debug.DebugString = spy.new(Empty)
            end)

            describe("when self.start_time is set", function()
                before_each(function()
                    debug.start_time = 1
                end)

                it("should call DebugString() with passed arguments and appended time", function()
                    assert.spy(debug.DebugString).was_called(0)
                    debug:DebugStringStop("hello", "world", 1)
                    assert.spy(debug.DebugString).was_called(1)
                    assert.spy(debug.DebugString).was_called_with(
                        match.is_ref(debug),
                        "hello",
                        "world",
                        "1.",
                        "Time: 1.0000"
                    )
                end)

                it("should unset self.start_time", function()
                    assert.is_equal(1, debug.start_time)
                    debug:DebugStringStop("test")
                    assert.is_nil(debug.start_time)
                end)
            end)

            describe("when self.start_time is not set", function()
                before_each(function()
                    debug.start_time = nil
                end)

                it("should call DebugString() with only passed arguments", function()
                    assert.spy(debug.DebugString).was_called(0)
                    debug:DebugStringStop("hello", "world", 1)
                    assert.spy(debug.DebugString).was_called(1)
                    assert.spy(debug.DebugString).was_called_with(
                        match.is_ref(debug),
                        "hello",
                        "world",
                        1
                    )
                end)
            end)
        end)

        describe("DebugInit()", function()
            before_each(function()
                debug.DebugString = spy.new(Empty)
            end)

            it("should call DebugString() with corresponding arguments", function()
                assert.spy(debug.DebugString).was_called(0)
                debug:DebugInit("hello")
                assert.spy(debug.DebugString).was_called(1)
                assert.spy(debug.DebugString).was_called_with(
                    match.is_ref(debug),
                    "[life_cycle]",
                    "Initialized",
                    "hello"
                )
            end)
        end)

        describe("DebugTerm()", function()
            before_each(function()
                debug.DebugString = spy.new(Empty)
            end)

            it("should call DebugString() with corresponding arguments", function()
                assert.spy(debug.DebugString).was_called(0)
                debug:DebugTerm("hello")
                assert.spy(debug.DebugString).was_called(1)
                assert.spy(debug.DebugString).was_called_with(
                    match.is_ref(debug),
                    "[life_cycle]",
                    "Terminated",
                    "hello"
                )
            end)
        end)

        describe("DebugError()", function()
            before_each(function()
                debug.DebugString = spy.new(Empty)
            end)

            it("should call DebugString() with corresponding arguments", function()
                assert.spy(debug.DebugString).was_called(0)
                debug:DebugError("hello")
                assert.spy(debug.DebugString).was_called(1)
                assert.spy(debug.DebugString).was_called_with(
                    match.is_ref(debug),
                    "[error]",
                    "hello"
                )
            end)
        end)

        describe("DebugModConfigs()", function()
            setup(function()
                _G.KnownModIndex = {
                    GetModConfigurationOptions_Internal = ReturnValueFn({
                        { name = "", label = "General" },
                        { name = "test", label = "Test", default = "hello" },
                        { name = "", label = "Other" },
                        {
                            name = "hide_changelog",
                            label = "Hide changelog",
                            default = true,
                            saved = true,
                        },
                        { name = "debug", label = "Debug", default = false, saved = true },
                    })
                }
            end)

            teardown(function()
                _G.KnownModIndex = nil
            end)

            before_each(function()
                debug.DebugString = spy.new(Empty)
            end)

            describe("when configuration options are returned as a table", function()
                it("should call DebugString() with corresponding arguments", function()
                    assert.spy(debug.DebugString).was_called(0)
                    debug:DebugModConfigs()
                    assert.spy(debug.DebugString).was_called(5)

                    assert.spy(debug.DebugString).was_called_with(
                        match.is_ref(debug),
                        "[config]",
                        "[section]",
                        "General"
                    )

                    assert.spy(debug.DebugString).was_called_with(
                        match.is_ref(debug),
                        "[config]",
                        "Test:",
                        "hello"
                    )

                    assert.spy(debug.DebugString).was_called_with(
                        match.is_ref(debug),
                        "[config]",
                        "[section]",
                        "Other"
                    )

                    assert.spy(debug.DebugString).was_called_with(
                        match.is_ref(debug),
                        "[config]",
                        "Hide changelog:",
                        true
                    )
                    assert.spy(debug.DebugString).was_called_with(
                        match.is_ref(debug),
                        "[config]",
                        "Debug:",
                        true
                    )
                end)
            end)
        end)
    end)
end)
