-- Multi-model collaboration over the configured Thirx OpenAI-compatible endpoint.
-- Both worker requests are launched before either is awaited; a coordinator then
-- reconciles their independent analyses and calls out disagreements.
return function(env)
	local util = env.require("runtime/util")
	local providers = env.require("provider/registry")
	local chat = env.require("provider/chat")
	local H = env.require("tools/helpers")

	local BASE_URL = "https://ai.thirx.com/v1"
	local MODELS = {
		{ id = "GLM-5.3-Flash", model = "GLM-5.3-Flash", role = "independent analyst" },
		{ id = "deepseek-v4-flash", model = "deepseek-v4-flash", role = "critical reviewer" },
	}
	local MAX_TASK_CHARS = 12000
	local MAX_REPLY_TOKENS = 1800
	local MAX_REPORT_CHARS = 12000
	local REQUEST_TIMEOUT = 120

	local function thirxRecord(model)
		for _, record in ipairs(providers.list()) do
			local base = util.trim(tostring(record.baseUrl or "")):gsub("/+$", ""):lower()
			if base == BASE_URL and record.enabled ~= false and util.trim(record.apiKey or "") ~= "" then
				local copy = util.deepCopy(record)
				copy.model = model
				copy.models = { model }
				copy.stream = false
				return copy
			end
		end
		return nil
	end

	local function ask(record, systemText, userText)
		local result, err = chat.complete(record, {
			messages = {
				{ role = "system", content = systemText },
				{ role = "user", content = userText },
			},
			stream = false,
			temperature = 0.2,
			maxTokens = MAX_REPLY_TOKENS,
			timeout = REQUEST_TIMEOUT,
		})
		if not result then return nil, tostring(err or "request failed") end
		if type(result.toolCalls) == "table" and #result.toolCalls > 0 then
			return nil, "model returned tool calls where a text report was required"
		end
		local content = util.trim(tostring(result.content or ""))
		if content == "" then return nil, "model returned an empty report" end
		if #content > MAX_REPORT_CHARS then
			content = content:sub(1, MAX_REPORT_CHARS) .. "\n[Report truncated at " .. tostring(MAX_REPORT_CHARS) .. " characters.]"
		end
		return content
	end

	return {
		{
			name = "ai_collaborate",
			risk = "read",
			description = "Have GLM-5.3-Flash and deepseek-v4-flash independently analyze the same task concurrently through the configured Thirx provider, then synthesize a single answer with agreements, disagreements, and uncertainty. Use for difficult analysis, architecture, debugging, or code review where a second model's independent check adds value. Requires a saved enabled provider with base URL https://ai.thirx.com/v1 and an API key. This tool does not execute code or apply changes.",
			parameters = {
				type = "object",
				properties = {
					task = { type = "string", description = "The exact task, question, code, or findings both models should assess." },
					mode = { type = "string", enum = { "team", "debate" }, description = "team combines independent analyses; debate asks the reviewer to challenge the analyst." },
				},
				required = { "task" },
			},
			run = function(args)
				local taskText = util.trim(tostring(args.task or ""))
				if taskText == "" then return H.fail("task is required") end
				if #taskText > MAX_TASK_CHARS then
					taskText = taskText:sub(1, MAX_TASK_CHARS) .. "\n[Task truncated at " .. MAX_TASK_CHARS .. " characters.]"
				end

				local glm = thirxRecord(MODELS[1].model)
				local deepseek = thirxRecord(MODELS[2].model)
				if not glm or not deepseek then
					return H.fail("Configure and save an enabled Thirx provider at " .. BASE_URL .. " with an API key first. Model availability must be confirmed by the service.")
				end
				if type(task) ~= "table" or type(task.spawn) ~= "function" or type(task.wait) ~= "function" then
					return H.fail("This runtime does not expose task.spawn/task.wait; concurrent model requests are unavailable.")
				end

				local outputs = {}
				local pending = 2
				local function launch(index, record, systemText)
					task.spawn(function()
						local ok, value, err = pcall(ask, record, systemText, taskText)
						if ok and value then
							outputs[index] = { model = record.model, text = value }
						else
							outputs[index] = { model = record.model, error = tostring(ok and err or value) }
						end
						pending = pending - 1
					end)
				end

				launch(1, glm, "You are the independent analyst in a two-model collaboration. Solve the user's task on its own merits. State assumptions, evidence, concrete recommendations, and uncertainty. Do not invent API capabilities or claim tests were run.")
				local reviewerPrompt = args.mode == "debate"
					and "You are the critical reviewer in a two-model debate. Independently analyze the user's task, look for failure modes and flawed assumptions, and propose a better solution where warranted. Do not assume the other model is correct."
					or "You are the independent second analyst. Solve the task separately, check likely edge cases, and state what evidence or tests would validate the result. Do not assume the other model is correct."
			launch(2, deepseek, reviewerPrompt)

				local waited = 0
			while pending > 0 and waited < REQUEST_TIMEOUT + 5 do
				task.wait(0.25)
				waited = waited + 0.25
			end
			-- A slow worker must not erase a useful report from the other model.
			-- Mark unfinished workers explicitly, then let the coordinator synthesize
			-- the available evidence. The worker may finish later, but this call never
			-- waits beyond the bounded collaboration window.
			if pending > 0 then
				for index, model in ipairs(MODELS) do
					if not outputs[index] then
						outputs[index] = {
							model = model.model,
							error = "request exceeded the " .. tostring(REQUEST_TIMEOUT + 5) .. "s collaboration wait limit",
						}
					end
				end
			end
			local hasReport = (outputs[1] and outputs[1].text) or (outputs[2] and outputs[2].text)
			if not hasReport then
				return H.fail("Both model requests failed. GLM: " .. tostring(outputs[1] and outputs[1].error or "no result") .. "; DeepSeek: " .. tostring(outputs[2] and outputs[2].error or "no result"))
			end

			local reports = {}
			for index, label in ipairs({ "GLM-5.3-Flash", "deepseek-v4-flash" }) do
				local out = outputs[index]
				if out and out.text then
					reports[#reports + 1] = "## " .. label .. "\n" .. out.text
				else
					reports[#reports + 1] = "## " .. label .. "\nRequest failed: " .. tostring(out and out.error or "no result")
				end
			end
			local synthesisPrompt = "You are the coordinator for a multi-model AI team. Synthesize the reports into one precise answer to the original task. Separate agreement from disagreement, resolve disagreements only when evidence supports it, preserve important caveats, and state explicitly if one model failed. Never claim external checks or tests were run unless a report contains evidence that they were. Output the answer directly."
			local synthesis, synthesisError = ask(glm, synthesisPrompt,
				"Original task:\n" .. taskText .. "\n\nIndependent reports:\n" .. table.concat(reports, "\n\n"))
			if synthesis then return synthesis end
			return "The coordinator request failed (" .. tostring(synthesisError) .. "). Returning independent reports without synthesis:\n\n" .. table.concat(reports, "\n\n")
			end,
		},
	}
end
