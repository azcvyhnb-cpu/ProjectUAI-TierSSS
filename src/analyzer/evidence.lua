-- Evidence ledger for semantic classification.
-- Scores are confidence hints, not guarantees.
return function(env)
    local M = {}

    function M.new()
        return { facts = {}, bySystem = {}, seen = {}, revision = 0 }
    end

    function M.add(state, system, weight, reason, source, subject)
        if not state or not system then return end
        weight = math.max(0, math.min(1, tonumber(weight) or 0))
        local key = table.concat({tostring(system), tostring(subject or ""), tostring(source or ""), tostring(reason or "")}, "|")
        if state.seen[key] then return end
        state.seen[key] = true
        state.revision = state.revision + 1
        state.facts[#state.facts + 1] = {
            system = system,
            weight = weight,
            reason = tostring(reason or ""),
            source = tostring(source or "unknown"),
            subject = subject,
            revision = state.revision,
        }
        state.bySystem[system] = state.bySystem[system] or {}
        table.insert(state.bySystem[system], state.facts[#state.facts])
    end

    function M.score(state, system)
        local facts = state and state.bySystem and state.bySystem[system] or {}
        local miss = 1
        for _, fact in ipairs(facts) do miss = miss * (1 - fact.weight) end
        return math.max(0, math.min(1, 1 - miss))
    end

    function M.top(state, system, limit)
        local facts = {}
        for _, fact in ipairs((state.bySystem or {})[system] or {}) do facts[#facts + 1] = fact end
        table.sort(facts, function(a, b) return a.weight > b.weight end)
        local out = {}
        for i = 1, math.min(limit or 5, #facts) do out[#out + 1] = facts[i] end
        return out
    end

    return M
end
