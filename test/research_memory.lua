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

-- Thai UTF-8 text must remain searchable even when Lua's %w tokenizer finds
-- no ASCII terms, and Thai-only notes must not share an empty deduplication key.
local thaiTitle = "ประตูฝั่งตะวันตก"
local thaiBody = "สวิตช์สีน้ำเงินเปิดประตู"
local thaiSaved = memory.save({ title = thaiTitle, content = thaiBody, confidence = "observed" })
check("saves Thai-only research notes", thaiSaved ~= nil and thaiSaved.count == 2)
local thaiFound = memory.search({ query = "สวิตช์สีน้ำเงิน" })
check("retrieves notes by a Thai literal phrase", thaiFound ~= nil and #thaiFound.items == 1 and thaiFound.items[1].title == thaiTitle)
local thaiDuplicate = memory.save({ title = thaiTitle, content = thaiBody, confidence = "verified" })
check("deduplicates identical Thai-only notes", thaiDuplicate ~= nil and thaiDuplicate.updated == true and thaiDuplicate.count == 2)
local thaiTitleFound = memory.search({ query = thaiTitle })
check("matches Thai phrases in titles", thaiTitleFound ~= nil and #thaiTitleFound.items == 1 and thaiTitleFound.items[1].title == thaiTitle)

-- Tags should influence ranking, not merely make a note eligible for retrieval.
local tagged = memory.save({
	title = "Chest observation alpha",
	content = "A chest was found in the cave.",
	tags = { "rare chest" }, confidence = "observed",
})
local untagged = memory.save({
	title = "Chest observation beta",
	content = "A chest was found in the cave.",
	confidence = "observed",
})
local ranked = memory.search({ query = "chest cave", limit = 5 })
check("saves tagged and untagged comparison notes", tagged ~= nil and untagged ~= nil)
check("ranks matching tags above otherwise similar notes", ranked ~= nil and #ranked.items == 2 and ranked.items[1].title == "Chest observation alpha")

-- Confidence is a claim about evidence. Do not allow an uncited new note to
-- become verified merely because the model requested that label.
local uncited = memory.save({
	title = "Uncited claim about a hidden room",
	content = "A hidden room may exist behind the wall.",
	confidence = "verified",
})
local uncitedNote = uncited and memory.get({ id = uncited.id })
check("downgrades verified claims without a source pointer", uncitedNote ~= nil and uncitedNote.confidence == "observed" and not uncitedNote.source)
local cited = memory.save({
	title = "Cited confirmation of hidden room",
	content = "The room was found behind the wall and confirmed by inspection.",
	confidence = "verified", source = "Workspace.Map.HiddenRoom",
})
local citedNote = cited and memory.get({ id = cited.id })
check("preserves verified status when a source pointer is present", citedNote ~= nil and citedNote.confidence == "verified" and citedNote.source == "Workspace.Map.HiddenRoom")

local refreshed = memory.save({
	title = "Cited confirmation of hidden room",
	content = "The room was found behind the wall and confirmed by inspection.",
})
local refreshedNote = refreshed and memory.get({ id = refreshed.id })
check("keeps confidence when refresh omits confidence", refreshedNote ~= nil and refreshedNote.confidence == "verified")
check("keeps provenance when refresh omits a new source", refreshedNote ~= nil and refreshedNote.source == "Workspace.Map.HiddenRoom")

local orderedA = memory.save({
	title = "Order-sensitive observation", content = "Switch opens door.", confidence = "observed",
})
local orderedB = memory.save({
	title = "Order-sensitive observation", content = "Door opens switch.", confidence = "observed",
})
check("does not merge distinct claims with reordered words", orderedA ~= nil and orderedB ~= nil and orderedA.id ~= orderedB.id)

local oldObservation = memory.save({
	title = "Old observation of rotating bridge",
	content = "The bridge rotates after the lever is pulled.",
	confidence = "observed", observedAt = 1,
})
local oldResult = memory.search({ query = "rotating bridge", maxAgeMs = 1000 })
local oldItem
if oldResult then
	for _, item in ipairs(oldResult.items) do
		if item.id == (oldObservation and oldObservation.id) then oldItem = item end
	end
end
check("labels observations beyond an explicit age threshold stale", oldItem ~= nil and oldItem.freshness == "stale" and oldItem.ageMs >= 1000)
local originalObservedAt = oldItem and oldItem.observedAt
local refreshedOld = memory.save({
	title = "Old observation of rotating bridge",
	content = "The bridge rotates after the lever is pulled.",
})
local refreshedOldNote = refreshedOld and memory.get({ id = refreshedOld.id })
check("does not make an old observation fresh just by refreshing its note", refreshedOldNote ~= nil and refreshedOldNote.observedAt == originalObservedAt)
local freshResult = memory.search({ query = "blue switch", maxAgeMs = 86400000 })
check("labels recent matching evidence fresh under a suitable threshold", freshResult ~= nil and #freshResult.items > 0 and freshResult.items[1].freshness == "fresh")
check("rejects invalid freshness thresholds", memory.search({ query = "bridge", maxAgeMs = 0 }) == nil)

-- Version-1 notebooks used a first-seen token-set identity. Simulate an old
-- persisted record and verify saving the same observation migrates it in place.
local util = env.require("runtime/util")
local legacyTitle = "Legacy migration check"
local legacyBody = "The blue switch opens gate."
local legacyKey = table.concat((function()
	local seen, out = {}, {}
	for token in (legacyTitle .. " " .. legacyBody):lower():gmatch("[%w_%-]+") do
		if #token >= 2 and not seen[token] then seen[token] = true; out[#out + 1] = token end
	end
	return out
end)(), " ")
local legacyPath = "UAI/research/place-123456.json"
local legacyRecord = {
	id = "legacy-note-1", key = legacyKey, title = legacyTitle, content = legacyBody,
	tags = { "legacy" }, confidence = "observed", source = "old notebook",
	createdAt = 10, updatedAt = 20,
}
env.sandbox.writefile(legacyPath, util.encode({ version = 1, placeId = 123456, records = { legacyRecord } }))
local migrated = memory.save({ title = legacyTitle, content = legacyBody })
local persistedLegacy = util.decode(env.sandbox.readfile(legacyPath))
check("refreshes a legacy token-set note in place", migrated ~= nil and migrated.updated == true and migrated.count == 1 and migrated.id == "legacy-note-1")
check("migrates the legacy key to ordered identity", persistedLegacy.records[1].key ~= legacyKey and persistedLegacy.records[1].key == string.lower(legacyTitle) .. string.char(0) .. string.lower(legacyBody))
check("preserves legacy note provenance during migration", persistedLegacy.records[1].source == "old notebook")

print(string.format("Research memory: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
