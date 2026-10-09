-- Persistent research memory tools.
--
-- Search the place notebook before repeating exploration. Save concise findings
-- only after they have evidence; mark uncertain conclusions as hypotheses.
return function(env)
	local util = env.require("runtime/util")
	local H = env.require("tools/helpers")
	local memory = env.require("runtime/research_memory")
	local place = env.require("runtime/place")
	local placeId = { type = "integer", minimum = 0, description = "Optional Roblox PlaceId. Defaults to the current place; use an explicit id only when intentionally accessing that place's notebook." }
	local function compact(value, err)
		if not value then return H.fail(err) end
		return util.encode(value)
	end
	return {
		{
			name = "research_search",
			risk = "read",
			needs = { "fs" },
			description = "Search persistent research notes for this Roblox place. Use this BEFORE scanning or rediscovering map systems, UI paths, object hierarchies, observed behavior, or prior test results. Returns a small relevance-ranked set, with confidence and sources; hypotheses are not facts. Notes survive client restarts when filesystem persistence is supported.",
			parameters = { type = "object", properties = {
				query = { type = "string", description = "Short keyword query: feature/system/object names and the specific question." },
				placeId = placeId,
				limit = { type = "integer", minimum = 1, maximum = 10, description = "Maximum matching notes. Default 5." },
			}, required = { "query" } },
			run = function(args) return compact(memory.search(args)) end,
		},
		{
			name = "research_save",
			risk = "write",
			needs = { "fs" },
			description = "Persist a compact research finding in the current place's notebook. Use after inspecting evidence, not for guesses. Record one durable fact per note, include a source/evidence pointer, and choose confidence=verified only when directly confirmed; use observed or hypothesis otherwise. Duplicate findings are updated instead of duplicated. Saved notes are available to future sessions and do not automatically sync to GitHub.",
			parameters = { type = "object", properties = {
				title = { type = "string", description = "Short descriptive title, max 160 bytes." },
				content = { type = "string", description = "Compact finding with what was observed, how it was verified, and important limitations; max 5000 bytes." },
				tags = { type = "array", items = { type = "string" }, maxItems = 12, description = "Optional topic tags." },
				confidence = { type = "string", enum = { "verified", "observed", "hypothesis" }, description = "Evidence status; default observed." },
				source = { type = "string", description = "Optional evidence pointer such as a source path, object path, test name, or capture id. Do not store credentials or secrets." },
				placeId = placeId,
			}, required = { "title", "content" } },
			run = function(args)
				local result, err = memory.save(args)
				if not result then return H.fail(err) end
				return util.encode(result)
			end,
		},
		{
			name = "research_list",
			risk = "read",
			needs = { "fs" },
			description = "List the newest saved research note titles for a place and show how many notes are stored. Use this to inspect notebook coverage without loading every note.",
			parameters = { type = "object", properties = {
				placeId = placeId,
				limit = { type = "integer", minimum = 1, maximum = 50, description = "Maximum titles. Default 20." },
			}, required = {} },
			run = function(args) return compact(memory.list(args)) end,
		},
		{
			name = "research_get",
			risk = "read",
			needs = { "fs" },
			description = "Read one complete saved research note by id. Use after research_search identifies a relevant note when the evidence details matter.",
			parameters = { type = "object", properties = {
				id = { type = "string", description = "Exact note id returned by research_search or research_list." },
				placeId = placeId,
			}, required = { "id" } },
			run = function(args) return compact(memory.get(args)) end,
		},
	}
end
