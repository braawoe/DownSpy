-- test_harness.lua
-- Minimal test harness for DownSpy initialization performance measurement
-- Mocks minimal Roblox services and measures phase durations

local function deepcopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Mock minimal Roblox environment
local mock_services = {
    HttpService = {
        JSONEncode = function(val) return "{}" end,
        JSONDecode = function(val) return {} end,
        HttpGet = function(self, url)
            return '{"mock": "response"}'
        end,
    },
    Players = {
        LocalPlayer = {
            Name = "TestPlayer",
            Character = { Name = "TestCharacter" },
        },
    },
    RunService = {
        Heartbeat = function() end,
    },
    Workspace = {},
}

local game = {
    GetService = function(self, name)
        return mock_services[name] or {}
    end,
}

_G.game = game
_G.cloneref = function(obj) return obj end
_G.request = function(req) 
    return true, { Body = "{}", StatusCode = 200 } 
end
_G.readfile = function(path) return "mock file content" end
_G.writefile = function(path, content) return true end
_G.makefolder = function(path) end
_G.isfile = function(path) return true end
_G.isfolder = function(path) return true end
_G.loadstring = load
_G.getcustomasset = function(path) return "mock asset" end
_G.crypt = { base64decode = function(str) return str end }

-- Mock Ui library functions
_G.Ui = {
    CreateMainWindow = function()
        return {
            Close = function() end,
            SetFontFile = function() end,
            CreateWindowContent = function() end,
            SetCommChannel = function() end,
            QueueLog = function() end,
            ConsoleLog = function() end,
            AskUser = function() return "Yes" end,
        }
    end,
}

-- Performance measurement harness
local report = {}

local function measure_phase(name, func)
    local start = os.clock()
    local ok, err = pcall(func)
    local duration_ms = (os.clock() - start) * 1000
    
    table.insert(report, {
        phase = name,
        duration_ms = duration_ms,
        error = ok and nil or err,
        stack_trace = ok and nil or debug.traceback(),
    })
    
    if not ok then
        print(string.format("[!] Phase '%s' failed: %s", name, tostring(err)))
    end
    return ok
end

print("Starting DownSpy initialization measurement...")

-- Phase 1: Config load
measure_phase("config_load", function()
    local config_path = "/data/data/com.termux/files/home/DownSpy/build/config.json"
    local cfg = readfile(config_path)
    if not cfg then error("Config file missing") end
    -- In real harness, parse JSON here
end)

-- Phase 2: UI init
measure_phase("ui_init", function()
    local window = Ui:CreateMainWindow()
    window:CreateWindowContent()
    window:SetFontFile("ProggyClean.ttf")
    window:QueueLog("UI initialized")
end)

-- Phase 3: Hook init (loading hooks and scripts)
measure_phase("hook_init", function()
    local StartTime = os.clock()
    local Hook, load_err = nil, nil
    local ok, result = pcall(function()
        local f, e = loadfile("src/lib/Hook.lua")
        if not f then error("Failed to load Hook.lua: "..tostring(e)) end
        return f()
    end)
    if ok then Hook = result else load_err = result end
    local hook_err = nil
    if Hook then
        local s, e = pcall(function()
            Hook:ConnectClientRecive(MockRemote)
        end)
        if not s then hook_err = e end
    end
    report.hook_init = {phase="hook_init", duration_ms=(os.clock()-StartTime)*1000, error=hook_err, stack_trace=nil}
end)

-- Phase 4: Remote check
measure_phase("remote_check", function()
    local Process = {
        FindCallingLClosure = function() return {} end,
        ProcessRemote = function() return true end,
    }
    local ok, result = pcall(Process.ProcessRemote)
    if not ok then error("Remote check failed: " .. tostring(result)) end
end)

-- Generate JSON report
local report_path = "/data/data/com.termux/files/home/DownSpy/harness_report.json"
local json_lines = {}
for i, entry in ipairs(report) do
    local err_str = entry.error and string.format("%q", entry.error) or "null"
    local line = string.format(
        '  {"phase": "%s", "duration_ms": %.2f, "error": %s}',
        entry.phase, entry.duration_ms, err_str
    )
    table.insert(json_lines, line)
end
local json_report = "[\n" .. table.concat(json_lines, ",\n") .. "\n]"

local file = io.open(report_path, "w")
if file then
    file:write(json_report)
    file:close()
    print("Report written to " .. report_path)
else
    error("Failed to write report file")
end

-- Output the JSON to stdout
print(json_report)
os.exit(0)