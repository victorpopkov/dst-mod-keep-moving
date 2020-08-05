exclude_files = {
  "workshop/",
}

std = {
  max_code_line_length = 100,
  max_comment_line_length = 150,
  max_line_length = 100,
  max_string_line_length = 100,

  -- std.read_globals should include only the "native" Lua-related stuff
  read_globals = {
    "arg",
    "assert",
    "Class",
    "debug",
    "env",
    "getmetatable",
    "ipairs",
    "json",
    "math",
    "next",
    "os",
    "pairs",
    "print",
    "rawset",
    "require",
    "string",
    "table",
    "tonumber",
    "tostring",
    "type",
    "unpack",
  },
}

files["modinfo.lua"] = {
  max_code_line_length = 250,
  max_comment_line_length = 100,
  max_line_length = 100,
  max_string_line_length = 250,

  -- globals
  globals = {
    "all_clients_require_mod",
    "api_version",
    "author",
    "client_only_mod",
    "configuration_options",
    "description",
    "dont_starve_compatible",
    "dst_compatible",
    "folder_name",
    "forumthread",
    "icon_atlas",
    "icon",
    "name",
    "priority",
    "reign_of_giants_compatible",
    "shipwrecked_compatible",
    "version",
  },
}

files["modmain.lua"] = {
  max_code_line_length = 100,
  max_comment_line_length = 250,
  max_line_length = 100,
  max_string_line_length = 100,

  -- globals
  globals = {
    "Assets",
    "GLOBAL",
  },
  read_globals = {
    "AddAction",
    "AddComponentPostInit",
    "Asset",
    "GetModConfigData",
    "modname",
  },
}

files["scripts/**/*.lua"] = {
  max_code_line_length = 100,
  max_comment_line_length = 250,
  max_line_length = 100,
  max_string_line_length = 100,

  -- globals
  globals = {
    -- general
    "_G",
    "MOD_KEEP_MOVING",

    -- project
    "Debug",
  },
  read_globals = {
    -- general
    "anglediff",
    "BufferedAction",
    "CreateEntity",
    "KnownModIndex",
    "RoadManager",
    "RunInSandboxSafe",
    "SendRPCToServer",
    "TheSim",
    "TheWorld",
    "Vector3",

    -- constants
    "ACTIONS",
    "ANIM_ORIENTATION",
    "FRAMES",
    "LAYER_BACKGROUND",
    "RPC",

    -- threads
    "KillThreadsWithID",
    "scheduler",
    "Sleep",
    "StartThread",
  },
}

files["spec/**/*.lua"] = {
  max_code_line_length = 100,
  max_comment_line_length = 250,
  max_line_length = 100,
  max_string_line_length = 100,

  -- globals
  globals = {
    -- general
    "_G",
    "Class",
    "ClassRegistry",
    "package",
    "ToVector3",
    "Vector3",

    -- project
    "AssertChainNil",
    "AssertGetter",
    "AssertMethodExists",
    "AssertMethodIsMissing",
    "AssertSetter",
    "DebugSpy",
    "DebugSpyAssert",
    "DebugSpyAssertWasCalled",
    "DebugSpyClear",
    "DebugSpyInit",
    "DebugSpyTerm",
    "Empty",
    "ReturnValueFn",
    "ReturnValues",
    "ReturnValuesFn",
  },
  read_globals = {
    "rawget",
    "setmetatable",
  },
}
