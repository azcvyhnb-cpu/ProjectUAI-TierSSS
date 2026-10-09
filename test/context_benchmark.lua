-- Reproducible local benchmark for context compaction.
-- Run after the bundle build with: luajit test/context_benchmark.lua
package.path = "test/?.lua;test/mock/?.lua;" .. package.path
local envMock, luau = require("env"), require("luau")

local function fixture()
	local h = envMock.new()
	local env = { services = h.services, hs = h.services.HttpService,
		info = { folder = "UAI", version = "benchmark" }, context = {} }
	local loaded = {}
	function env.require(id)
		if loaded[id] then return loaded[id] end
		local file = assert(io.open("src/" .. id .. ".lua", "rb"))
		local source = file:read("*a")
		file:close()
		local fn = assert(luau.load(source, id))
		setfenv(fn, h.sandbox)
		loaded[id] = fn()(env)
		return loaded[id]
	end
	env.require("runtime/config")
	return env, env.require("agent/context")
end

local sizes = {
	{ label = "small", turns = 20 },
	{ label = "medium", turns = 100 },
	{ label = "large", turns = 500 },
}

print("context benchmark (deterministic synthetic transcript)")
print("size\tturns\tbefore_tokens\tafter_tokens\tremoved_messages\testimator_calls\tcompact_ms")
for _, size in ipairs(sizes) do
	local env, context = fixture()
	local ctx = context.new()
	local usage = env.require("agent/usage")
	local original, calls = usage.estimateMessages, 0
	usage.estimateMessages = function(messages)
		calls = calls + 1
		return original(messages)
	end
	local repeated = string.rep("inspect the relevant source and preserve compatibility ", 8)
	for index = 1, size.turns do
		ctx.pushUser(repeated .. " question " .. index)
		ctx.pushAssistant({ content = repeated .. " answer " .. index, reasoning = "", toolCalls = {} })
	end
	local before = ctx.tokens()
	local started = os.clock()
	local removed = ctx.compact(function() return "Earlier turns were summarized." end,
		{ tokenLimit = 2500, keepBlocks = 14 })
	local elapsed = (os.clock() - started) * 1000
	local after = ctx.tokens()
	print(string.format("%s\t%d\t%d\t%d\t%d\t%d\t%.3f",
		size.label, size.turns, before, after, #ctx.messages > 0 and (size.turns * 2 - #ctx.messages) or 0,
		calls, elapsed))
	usage.estimateMessages = original
	if not removed or after >= before then
		io.stderr:write(size.label .. " benchmark did not reduce context as expected\n")
		os.exit(1)
	end
end
