-- Persistent research memory: storage, retrieval, deduplication, and place isolation.
package.path = "test/?.lua;test/mock/?.lua;" .. package.path
local envMock, luau = require("env"), require("luau")
local passed, failed = 0, 0
local function check(label, value)
	if value then passed = passed + 1; print("  ok   " .. label)
	else failed = failed + 1; print("  FAIL " .. label) end
end
local function fixture()
	local h = envMock.new()
	local env = { services = h.services, hs = h.services.HttpService, info = { folder = "UAI", version = "test" }, context = {} }
	local loaded = {}
	function env.require(id)
		if loaded[id] then return loaded[id] end
		local file = assert(io.open("src/" .. id .. ".lua", "rb")); local source = file:read("*a"); file:close()
		local fn = assert(luau.load(source, id)); setfenv(fn, h.sandbox); loaded[id] = fn()(env); return loaded[id]
	end
	return env, loaded
end

local env, loaded = fixture()
local memory = env.require("runtime/research_memory")
local place = env.require("runtime/place")
place.id = 123456
local saved, saveErr = memory.save({
	title = "Map door interaction",
	content = "The west gate opens after the blue switch is activated. Confirmed by repeating the interaction twice.",
	tags = { "map", "gate", "interaction" }, confidence = "verified", source = "manual observation test",
})
check("saves a verified note", saved ~= nil and saved.count == 1)
check("reports validation failures", memory.save({ title = "", content = "bad" }) == nil)
local found = memory.search({ query = "west gate blue switch", limit = 5 })
check("retrieves relevant notes by keywords", found ~= nil and #found.items == 1 and found.items[1].title == "Map door interaction")
check("retains confidence and source metadata", found ~= nil and found.items[1].confidence == "verified" and found.items[1].source == "manual observation test")

-- Recreate the module while keeping the filesystem, as a client reload would.
loaded["runtime/research_memory"] = nil
memory = env.require("runtime/research_memory")
local afterReload = memory.search({ query = "blue switch" })
check("notes survive module/session reload", afterReload ~= nil and #afterReload.items == 1)
local duplicate = memory.save({
	title = "Map door interaction",
	content = "The west gate opens after the blue switch is activated. Confirmed by repeating the interaction twice.",
	confidence = "observed",
})
check("identical findings update rather than duplicate", duplicate ~= nil and duplicate.updated == true and duplicate.count == 1)
check("place notebooks are isolated", #memory.search({ query = "blue switch", placeId = 987654 }).items == 0)
check("returns a clear error for a missing note", memory.get({ id = "missing" }) == nil)

print(string.format("Research memory: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
