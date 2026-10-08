-- Universal Game Model. Keeps classification separate from raw discovery.
return function(env)
    local evidence = env.require("analyzer/evidence")
    local M = {}

    local GAME_TYPES = {
        {name = "Tower Defense", systems = {"Stage", "Wave", "Character", "Enemy"}},
        {name = "RPG", systems = {"Character", "Combat", "Quest", "Inventory"}},
        {name = "Simulator", systems = {"Currency", "Upgrade", "Inventory"}},
        {name = "Gacha", systems = {"Gacha", "Character", "Inventory"}},
        {name = "Tycoon", systems = {"Currency", "Upgrade", "Shop"}},
        {name = "Adventure", systems = {"Stage", "Quest", "Character"}},
    }

    function M.new(place)
        return {
            schemaVersion = 1,
            updatedAt = os.time(),
            identity = place or {},
            classification = {primary = "Unknown", confidence = 0, candidates = {}},
            systems = {},
            entities = {},
            evidence = {},
            stats = {nodes = 0, evidence = 0},
        }
    end

    function M.update(model, snapshot, ledger)
        model.updatedAt = os.time()
        model.stats.nodes = snapshot.count or 0
        model.stats.evidence = #(ledger.facts or {})
        model.systems = {}
        for system, facts in pairs(ledger.bySystem or {}) do
            local score = evidence.score(ledger, system)
            model.systems[system] = {
                detected = score >= 0.45,
                confidence = score,
                evidenceCount = #facts,
                topEvidence = evidence.top(ledger, system, 5),
            }
        end

        local candidates = {}
        for _, def in ipairs(GAME_TYPES) do
            local sum, weight = 0, 0
            for _, system in ipairs(def.systems) do
                local s = evidence.score(ledger, system)
                sum = sum + s
                weight = weight + 1
            end
            local confidence = weight > 0 and sum / weight or 0
            candidates[#candidates + 1] = {name = def.name, confidence = confidence}
        end
        table.sort(candidates, function(a, b) return a.confidence > b.confidence end)
        model.classification.candidates = candidates
        if candidates[1] and candidates[1].confidence >= 0.55 then
            model.classification.primary = candidates[1].name
            model.classification.confidence = candidates[1].confidence
        else
            model.classification.primary = "Unknown"
            model.classification.confidence = candidates[1] and candidates[1].confidence or 0
        end
        return model
    end

    return M
end
