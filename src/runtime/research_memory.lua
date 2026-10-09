-- Persistent, place-scoped research notes.
--
-- Store compact observations on disk so a new UAI session can reuse verified
-- discoveries instead of paying to rediscover them. This is a local notebook,
-- not a claim that the model learns weights or that the remote game state is
-- permanently stable. Every search is bounded and ranked lexically.
return function(env)
	local util = env.require("runtime/util")
	local fsx = env.require("runtime/fsx")
	local place = env.require("runtime/place")
	local clock = env.require("runtime/clock")

	local M = {}
	local MAX_RECORDS, MAX_BYTES = 300, 1536 * 1024
	local MAX_TITLE, MAX_BODY, MAX_TAGS = 160, 5000, 12

	local function validPlace(value)
		local id = tonumber(value)
		if not id or id ~= id or id < 0 or id == math.huge or id ~= math.floor(id) or id > 9007199254740991 then
			return nil, "placeId must be a nonnegative integer"
		end
		return id
	end

	local function pathFor(id)
		return "research/place-" .. string.format("%.0f", id) .. ".json"
	end

	local function load(id)
		local path = pathFor(id)
		if not fsx.exists(path) then return { version = 1, placeId = id, records = {} } end
		local raw, err = fsx.read(path)
		if not raw then return nil, "could not read research notebook: " .. tostring(err) end
		if #raw > MAX_BYTES then return nil, "research notebook exceeds the safety size limit" end
		local ok, data = pcall(util.decode, raw)
		if not ok or type(data) ~= "table" or type(data.records) ~= "table" then
			return nil, "research notebook is invalid JSON; original file was left untouched"
		end
		if data.placeId ~= id then return nil, "research notebook placeId mismatch" end
		return data
	end

	local function persist(id, data)
		local encoded = util.encode(data)
		if #encoded > MAX_BYTES then return false, "not saved: notebook would exceed 1.5 MiB" end
		local ok, result = fsx.write(pathFor(id), encoded)
		if not ok then return false, tostring(result) end
		return true
	end

	local function cleanText(value, max, label)
		if type(value) ~= "string" then return nil, label .. " must be a string" end
		value = util.trim(value)
		if value == "" then return nil, label .. " cannot be empty" end
		if #value > max then return nil, label .. " exceeds " .. max .. " bytes" end
		return value
	end

	local function terms(text)
		local found, out = {}, {}
		for token in tostring(text or ""):lower():gmatch("[%w_%-]+") do
			if #token >= 2 and not found[token] then found[token] = true; out[#out + 1] = token end
		end
		return out
	end

	local function identity(title, body)
		return table.concat(terms(title .. " " .. body), " ")
	end

	function M.save(args)
		args = args or {}
		local id, why = validPlace(args.placeId == nil and place.id or args.placeId)
		if not id then return nil, why end
		local title, titleErr = cleanText(args.title, MAX_TITLE, "title")
		if not title then return nil, titleErr end
		local body, bodyErr = cleanText(args.content, MAX_BODY, "content")
		if not body then return nil, bodyErr end
		local tags = {}
		if args.tags ~= nil then
			if type(args.tags) ~= "table" then return nil, "tags must be an array of strings" end
			for i, tag in ipairs(args.tags) do
				if i > MAX_TAGS then break end
				if type(tag) == "string" and util.trim(tag) ~= "" then tags[#tags + 1] = util.ellipsis(util.trim(tag), 40) end
			end
		end
		local confidence = tostring(args.confidence or "observed"):lower()
		if confidence ~= "verified" and confidence ~= "observed" and confidence ~= "hypothesis" then
			return nil, "confidence must be verified, observed, or hypothesis"
		end
		local data, loadErr = load(id)
		if not data then return nil, loadErr end
		local key = identity(title, body)
		for _, record in ipairs(data.records) do
			if record.key == key then
				record.title, record.content, record.tags = title, body, tags
				record.confidence, record.updatedAt = confidence, clock.ms()
				record.source = type(args.source) == "string" and util.ellipsis(args.source, 240) or record.source
				local ok, saveErr = persist(id, data)
				if not ok then return nil, saveErr end
				return { id = record.id, updated = true, placeId = id, count = #data.records }
			end
		end
		local record = {
			id = util.uid("note"), key = key, title = title, content = body, tags = tags,
			confidence = confidence, source = type(args.source) == "string" and util.ellipsis(args.source, 240) or nil,
			createdAt = clock.ms(), updatedAt = clock.ms(),
		}
		table.insert(data.records, record)
		while #data.records > MAX_RECORDS do table.remove(data.records, 1) end
		local ok, saveErr = persist(id, data)
		if not ok then return nil, saveErr end
		return { id = record.id, updated = false, placeId = id, count = #data.records }
	end

	function M.search(args)
		args = args or {}
		local query = util.trim(tostring(args.query or ""))
		if query == "" then return nil, "query cannot be empty" end
		local id, why = validPlace(args.placeId == nil and place.id or args.placeId)
		if not id then return nil, why end
		local data, loadErr = load(id)
		if not data then return nil, loadErr end
		local queryTerms, ranked = terms(query), {}
		if #queryTerms == 0 then return { placeId = id, items = {}, total = #data.records } end
		for _, record in ipairs(data.records) do
			local haystack = (record.title or "") .. " " .. (record.content or "") .. " " .. table.concat(record.tags or {}, " ")
			local lower, score, matches = haystack:lower(), 0, 0
			for _, term in ipairs(queryTerms) do
				if lower:find(term, 1, true) then score = score + (lower:find(term, 1, true) and 1 or 0); matches = matches + 1 end
				if (record.title or ""):lower():find(term, 1, true) then score = score + 2 end
			end
			if matches > 0 then
				score = score + matches / #queryTerms
				if record.confidence == "verified" then score = score + 0.15 end
				ranked[#ranked + 1] = { record = record, score = score, matches = matches }
			end
		end
		table.sort(ranked, function(a, b)
			if a.score == b.score then return (a.record.updatedAt or 0) > (b.record.updatedAt or 0) end
			return a.score > b.score
		end)
		local limit = math.max(1, math.min(math.floor(tonumber(args.limit) or 5), 10))
		local out = {}
		for i = 1, math.min(limit, #ranked) do
			local r = ranked[i].record
			out[#out + 1] = { id = r.id, title = r.title, content = r.content, tags = r.tags,
				confidence = r.confidence, source = r.source, updatedAt = r.updatedAt, score = ranked[i].score }
		end
		return { placeId = id, query = query, items = out, totalMatches = #ranked, total = #data.records }
	end

	function M.list(args)
		args = args or {}
		local id, why = validPlace(args.placeId == nil and place.id or args.placeId)
		if not id then return nil, why end
		local data, loadErr = load(id)
		if not data then return nil, loadErr end
		local limit = math.max(1, math.min(math.floor(tonumber(args.limit) or 20), 50))
		local items = {}
		for i = math.max(1, #data.records - limit + 1), #data.records do
			local r = data.records[i]
			items[#items + 1] = { id = r.id, title = r.title, confidence = r.confidence, updatedAt = r.updatedAt }
		end
		return { placeId = id, total = #data.records, items = items }
	end

	function M.get(args)
		args = args or {}
		local id, why = validPlace(args.placeId == nil and place.id or args.placeId)
		if not id then return nil, why end
		local wanted = util.trim(tostring(args.id or ""))
		local data, loadErr = load(id)
		if not data then return nil, loadErr end
		for _, r in ipairs(data.records) do
			if r.id == wanted then
				return { id = r.id, title = r.title, content = r.content, tags = r.tags, confidence = r.confidence,
					source = r.source, createdAt = r.createdAt, updatedAt = r.updatedAt, placeId = id }
			end
		end
		return nil, "no research note with that id in this place"
	end

	return M
end
