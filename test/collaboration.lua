-- Offline regression tests for bounded multi-model collaboration.
package.path = "test/?.lua;test/mock/?.lua;" .. package.path
local F = require("workspace_fixture")

local function configured(mode)
	local f = F.new()
	local util = f.env.require("runtime/util")
	local calls = {}
	local records = {
		{ id = "thirx", label = "Thirx", baseUrl = "https://ai.thirx.com/v1", apiKey = "test-key", enabled = true, model = "unused" },
	}
	f.loaded["provider/registry"] = { list = function() return records end }
	f.loaded["tools/helpers"] = {
		fail = function(message) return { ok = false, text = tostring(message) } end,
	}
	f.loaded["provider/chat"] = {
		complete = function(record, request)
			local user = request.messages[#request.messages].content
			calls[#calls + 1] = { model = record.model, user = user }
			if mode == "timeout" and record.model == "deepseek-v4-flash" and not user:find("Independent reports", 1, true) then
				-- Virtual scheduler wait: no real network or wall-clock delay.
				f.h.sandbox.task.wait(130)
			end
			local isSynthesis = user:find("Independent reports", 1, true) ~= nil
			if (mode == "failure" or mode == "both_failure") and not isSynthesis
				and (mode == "both_failure" or record.model == "deepseek-v4-flash") then
				return nil, "synthetic " .. tostring(record.model) .. " failure"
			end
			if isSynthesis then
				if mode == "synthesis_failure" then return nil, "synthetic synthesis failure" end
				return { content = "Coordinated answer with caveats", toolCalls = {} }
			end
			return { content = "Report from " .. tostring(record.model), toolCalls = {} }
		end,
	}
	local tools = f.env.require("tools/collaboration")
	assert(type(tools) == "table" and #tools == 1, "collaboration tool loads")
	assert(tools[1].name == "ai_collaborate", "public tool name is stable")
	assert(tools[1].risk == "read", "collaboration remains analysis-only")
	return f, tools[1], calls
end

-- Missing configuration and malformed input fail safely.
do
	local f = F.new()
	local tools = f.env.require("tools/collaboration")
	assert(type(tools) == "table" and #tools == 1, "tool loads without configured provider")
	local missing = tools[1].run({ task = "Review this design." }, {})
	assert(type(missing) == "table" and missing.ok == false, "missing provider fails safely")
	assert(missing.text:find("Configure and save an enabled Thirx provider", 1, true), "setup requirement is actionable")
	local empty = tools[1].run({ task = "  " }, {})
	assert(type(empty) == "table" and empty.ok == false and empty.text:find("task is required", 1, true), "empty tasks are rejected")
	f.healthy()
	f.close()
end

-- Both independent model requests run and the coordinator synthesizes their reports.
do
	local f, tool, calls = configured("success")
	local result = f.run(function() return tool.run({ task = "Review this design.", mode = "team" }) end, 1)
	assert(type(result) == "string" and result:find("Coordinated answer", 1, true), "coordinator result is returned")
	assert(#calls == 3, "two independent reports plus one synthesis request")
	assert(calls[1].model ~= calls[2].model, "the two workers use distinct model IDs")
	assert(calls[3].user:find("Report from GLM-5.3-Flash", 1, true), "synthesis includes GLM report")
	assert(calls[3].user:find("Report from deepseek-v4-flash", 1, true), "synthesis includes reviewer report")
	f.healthy()
	f.close()
end

-- One model failure must not discard the other model's successful report.
do
	local f, tool, calls = configured("failure")
	local result = f.run(function() return tool.run({ task = "Review this design." }) end, 1)
	assert(type(result) == "string" and result:find("Coordinated answer", 1, true), "partial report is still synthesized")
	assert(#calls == 3, "coordinator still runs after one worker failure")
	assert(calls[3].user:find("synthetic reviewer failure", 1, true), "reviewer failure is disclosed to coordinator")
	f.healthy()
	f.close()
end

-- If synthesis fails, return both independent reports rather than losing completed work.
do
	local f, tool, calls = configured("synthesis_failure")
	local result = f.run(function() return tool.run({ task = "Review this design." }) end, 1)
	assert(type(result) == "string" and result:find("coordinator request failed", 1, true), "synthesis failure is explicit")
	assert(result:find("Report from GLM-5.3-Flash", 1, true), "fallback retains GLM report")
	assert(result:find("Report from deepseek-v4-flash", 1, true), "fallback retains DeepSeek report")
	f.healthy()
	f.close()
end

-- If both independent workers fail, report both errors and do not make a third request.
do
	local f, tool, calls = configured("both_failure")
	local result = f.run(function() return tool.run({ task = "Review this design." }) end, 1)
	assert(type(result) == "table" and result.ok == false, "both worker failures return a tool error")
	assert(result.text:find("synthetic GLM-5.3-Flash failure", 1, true), "GLM failure is disclosed")
	assert(result.text:find("synthetic deepseek-v4-flash failure", 1, true), "DeepSeek failure is disclosed")
	assert(#calls == 2, "no synthesis request runs without any independent report")
	f.healthy()
	f.close()
end

-- A worker that exceeds the bounded wait window is marked unavailable; its peer's
-- completed report is still useful and must not be thrown away.
do
	local f, tool, calls = configured("timeout")
	local result = f.run(function() return tool.run({ task = "Review this design." }) end, 131)
	assert(type(result) == "string" and result:find("Coordinated answer", 1, true), "timed-out worker does not discard completed report")
	assert(#calls >= 3, "coordinator runs with the completed report")
	assert(calls[#calls].user:find("request exceeded the 125s collaboration wait limit", 1, true), "timeout is explicit in the evidence packet")
	f.healthy()
	f.close()
end

print("multi-model collaboration: offline regression cases passed")
