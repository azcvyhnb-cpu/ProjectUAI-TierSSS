-- Live-collector regression for semantic Humanoid property evidence.
-- Runs against the local mock only; no network or real Roblox client is used.
package.path = "test/?.lua;test/mock/?.lua;" .. package.path

local envMock = require("env")
local luau = require("luau")
local h = envMock.new()
local env = {
    services = h.services,
    hs = h.services.HttpService,
    plr = h.localPlayer,
    info = { folder = "UAI", version = "test" },
    context = {},
}
local loaded = {}
function env.require(id)
    if loaded[id] then return loaded[id] end
    local file = assert(io.open("src/" .. id .. ".lua", "rb"))
    local source = file:read("*a")
    file:close()
    local fn, err = luau.load(source, id)
    assert(fn, err)
    setfenv(fn, h.sandbox)
    loaded[id] = fn()(env)
    return loaded[id]
end

local workspace = h.services.Workspace
local model = h.sandbox.Instance.new("Model")
model.Name = "Enemy"
model.Parent = workspace
local humanoid = h.sandbox.Instance.new("Humanoid")
humanoid.Name = "Humanoid"
humanoid.Health = 45
humanoid.MaxHealth = 100
humanoid.HealthDisplayDistance = 100
humanoid.Parent = model

local tools = env.require("tools/analyzer")
local analyze
for _, tool in ipairs(tools) do
    if tool.name == "game_analyze" then analyze = tool; break end
end
assert(analyze, "game_analyze tool is registered")
local result = analyze.run({ root = "Workspace", limit = 100 }, {
    aborted = function() return false end,
})
assert(result and result.ok, "analysis completes: " .. tostring(result and result.text))
local combat = result.data.systems.Combat
assert(combat and combat.detected, "Humanoid health properties contribute enough evidence to detect Combat")
local healthEvidence = false
for _, item in ipairs(combat.topEvidence or {}) do
    if item.reason and item.reason:find("health-like field", 1, true) then healthEvidence = true end
end
assert(healthEvidence, "model exposes health-property evidence")
print("game analyzer collector: 3 checks passed")
