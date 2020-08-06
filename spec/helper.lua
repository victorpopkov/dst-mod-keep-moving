--
-- Packages
--

require "spec/vector3"

local preloads = {
    class = "spec/class",
}

package.path = "./scripts/?.lua;" .. package.path
for k, v in pairs(preloads) do
    package.preload[k] = function()
        return require(v)
    end
end

--
-- General
--

function Empty()
end

function ReturnValues(...)
    return ...
end

function ReturnValueFn(value)
    return function()
        return value
    end
end

function ReturnValuesFn(...)
    local args = { ... }
    return function()
        return unpack(args)
    end
end

--
-- Debug
--

local _DEBUG_SPY = {}

function DebugSpyInit(spy)
    local methods = {
        "DebugError",
        "DebugInit",
        "DebugString",
        "DebugStringStart",
        "DebugStringStop",
        "DebugTerm",
    }

    _G.KeepMovingDebug = require "keepmoving/debug"
    for _, method in pairs(methods) do
        if not _DEBUG_SPY[method] then
            _DEBUG_SPY[method] = spy.on(_G.KeepMovingDebug, method)
        end
    end
end

function DebugSpyTerm()
    for name, _ in pairs(_DEBUG_SPY) do
        _DEBUG_SPY[name] = nil
    end
    _G.KeepMovingDebug = nil
end

function DebugSpyClear(name)
    if name ~= nil then
        for _name, method in pairs(_DEBUG_SPY) do
            if _name == name then
                method:clear()
            end
        end
    else
        for _, method in pairs(_DEBUG_SPY) do
            method:clear()
        end
    end
end

function DebugSpy(name)
    for _name, method in pairs(_DEBUG_SPY) do
        if _name == name then
            return method
        end
    end
end

function DebugSpyAssert(name)
    local assert = require "luassert.assert"
    return assert.spy(DebugSpy(name))
end

function DebugSpyAssertWasCalled(name, calls, args)
    local match = require "luassert.match"
    calls = calls ~= nil and calls or 0
    args = args ~= nil and args or {}
    args = type(args) == "string" and { args } or args
    DebugSpyAssert(name).was_called(calls)
    if calls > 0 then
        DebugSpyAssert(name).was_called_with(match.is_ref(_G.KeepMovingDebug), unpack(args))
    end
end

--
-- Asserts
--

function AssertChainNil(fn, src, ...)
    if src and (type(src) == "table" or type(src) == "userdata") then
        local args = { ... }
        local start = src
        local previous, key

        for i = 1, #args do
            if start[args[i]] then
                previous = start
                key = args[i]
                start = start[key]
            end
        end

        if previous and src then
            previous[key] = nil
            args[#args] = nil
            fn()
            AssertChainNil(fn, src, unpack(args))
        end
    end
end

function AssertMethodExists(class, fn_name)
    local assert = require "busted".assert
    local classname = class.name ~= nil and class.name or "Class"
    assert.is_not_nil(
        class[fn_name],
        string.format("Function %s:%s() is missing", classname, fn_name)
    )
end

function AssertMethodIsMissing(class, fn_name)
    local assert = require "busted".assert
    local classname = class.name ~= nil and class.name or "Class"
    assert.is_nil(class[fn_name], string.format("Function %s:%s() exists", classname, fn_name))
end

function AssertGetter(class, field, fn_name, test_data)
    test_data = test_data ~= nil and test_data or "test"

    local assert = require "busted".assert
    AssertMethodExists(class, fn_name)
    local classname = class.name ~= nil and class.name or "Class"
    local fn = class[fn_name]

    local msg = string.format(
        "Getter %s:%s() doesn't return the %s.%s value",
        classname,
        fn_name,
        classname,
        field
    )

    assert.is_equal(class[field], fn(class), msg)
    class[field] = test_data
    assert.is_equal(test_data, fn(class), msg)
end

function AssertSetter(class, field, fn_name, test_data)
    test_data = test_data ~= nil and test_data or "test"

    local assert = require "busted".assert
    AssertMethodExists(class, fn_name)
    local classname = class.name ~= nil and class.name or "Class"
    local fn = class[fn_name]

    local msg = string.format(
        "Setter %s:%s() doesn't set the %s.%s value",
        classname,
        fn_name,
        classname,
        field
    )

    fn(class, test_data)
    assert.is_equal(test_data, class[field], msg)
end
