name = "Keep Moving"
version = "0.1.0-alpha"
description = [[Version: ]] .. version .. "\n\n" ..
    [[By default, Shift +  (LMB) on empty space to keep direct moving or Shift +  (RMB) on a road to keep on-road moving.]]
author = "Demonblink"
api_version = 10
forumthread = ""

priority = 0

icon = "modicon.tex"
icon_atlas = "modicon.xml"

all_clients_require_mod = false
client_only_mod = true
dont_starve_compatible = false
dst_compatible = true
reign_of_giants_compatible = false
shipwrecked_compatible = false

folder_name = folder_name or "dst-mod-keep-moving"
if not folder_name:find("workshop-") then
    name = name .. " (dev)"
end

--
-- Helpers
--

local function AddConfig(label, name, options, default, hover)
    return { label = label, name = name, options = options, default = default, hover = hover or "" }
end

local function AddSection(title)
    return AddConfig(title, "", { { description = "", data = 0 } }, 0)
end

local function CreateKeyList()
    local keylist = {}
    local string = ""
    local keys = {
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
        "LAlt", "RAlt", "LCtrl", "RCtrl", "LShift", "RShift",
        "Tab", "Capslock", "Space", "Minus", "Equals", "Backspace",
        "Insert", "Home", "Delete", "End", "Pageup", "Pagedown", "Print", "Scrollock", "Pause",
        "Period", "Slash", "Semicolon", "Leftbracket", "Rightbracket", "Backslash",
        "Up", "Down", "Left", "Right",
    }

    keylist[1] = { description = "Disabled", data = false }
    for i = 1, #keys do
        keylist[i + 1] = { description = keys[i], data = "KEY_" .. string.upper(keys[i]) }
    end

    return keylist
end

--
-- Configuration
--

local key_list = CreateKeyList()

local boolean = {
    { description = "Yes", data = true },
    { description = "No", data = false },
}

local reverse_actions = {
    { description = "Yes", data = true, hover = "Yes: RMB for direct moving and LMB for on-road moving" },
    { description = "No", data = false, hover = "No: LMB for direct moving and RMB for on-road moving" },
}

local mouse_dragging_check = {
    { description = "Yes", data = true, hover = "Yes: moving actions are disabled when the mouse dragging is detected" },
    { description = "No", data = false, hover = "No: moving actions are always enabled ignoring the mouse dragging" },
}

local on_road_points = {
    { description = "Yes", data = true, hover = "Yes: on-road moving positions are visible" },
    { description = "No", data = false, hover = "No: on-road moving positions are NOT visible" },
}

local on_road_points_lighting = {
    { description = "Yes", data = true, hover = "Yes: on-road moving positions are highlighted when enabled" },
    { description = "No", data = false, hover = "No: on-road moving positions are NOT highlighted when enabled" },
}

configuration_options = {
    AddSection("Keybinds"),
    AddConfig("Action key", "key_action", key_list, "KEY_LSHIFT", "Key used for triggering moving actions"),

    AddSection("General"),
    AddConfig("Reverse actions", "reverse_actions", reverse_actions, false, "Should the  (LMB) and  (RMB) moving actions be reversed?"),
    AddConfig("Mouse dragging check", "mouse_dragging_check", mouse_dragging_check, true, "Should the mouse dragging check be enabled?"),

    AddSection("Direct"),
    AddConfig("Direct moving", "direct_moving", boolean, true, "Should the direct moving be enabled?"),

    AddSection("On-road"),
    AddConfig("On-road moving", "on_road_moving", boolean, true, "Should the on-road moving be enabled?"),
    AddConfig("On-road points", "on_road_points", on_road_points, false, "Should the on-road points be enabled?"),
    AddConfig("On-road points lighting", "on_road_points_lighting", on_road_points_lighting, true, "Should the on-road points lighting be enabled?"),

    AddSection("Other"),
    AddConfig("Debug", "debug", boolean, false, "Should the debug mode be enabled?"),
}
