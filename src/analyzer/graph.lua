-- Read-only semantic graph built from normalized discovery records.
-- Uses indexes rather than an all-pairs node scan so large places remain bounded.
return function(env)
    local M = {}
    local MAX_GRAPH_EDGES = 12000

    local function key(v) return tostring(v or ""):lower() end
    local function add(map, k, v) map[k] = map[k] or {}; map[k][#map[k]+1] = v end
    local function sortedKeys(map)
        local out = {}
        for k in pairs(map) do out[#out + 1] = k end
        table.sort(out)
        return out
    end

    function M.new()
        return {
            schemaVersion = 1, nodes = {}, edges = {}, byType = {}, byPath = {},
            revision = 0, nodeCount = 0, edgeCount = 0, edgeLimit = MAX_GRAPH_EDGES,
            truncated = false, omittedEdgesLowerBound = 0,
        }
    end

    function M.update(graph, snapshot, entities, options)
        options = options or {}
        local requestedLimit = tonumber(options.maxEdges) or MAX_GRAPH_EDGES
        if requestedLimit ~= requestedLimit then requestedLimit = MAX_GRAPH_EDGES end
        local edgeLimit = math.max(1, math.min(MAX_GRAPH_EDGES, math.floor(requestedLimit)))

        graph.revision = (tonumber(graph.revision) or 0) + 1
        graph.nodes, graph.edges, graph.byType, graph.byPath = {}, {}, {}, {}
        graph.nodeCount, graph.edgeCount = 0, 0
        graph.edgeLimit, graph.truncated, graph.omittedEdgesLowerBound = edgeLimit, false, 0

        local childrenByParent = {}
        for _, n in ipairs(snapshot.nodes or {}) do
            local id = tostring(n.id or n.path or n.name)
            local e = entities[id]
            graph.nodes[id] = {
                id = id, name = n.name, className = n.className, path = n.path,
                type = (e and e.type) or "Instance", confidence = (e and e.confidence) or 0,
            }
            graph.nodeCount = graph.nodeCount + 1
            graph.byPath[key(n.path)] = id
            add(graph.byType, graph.nodes[id].type, id)
            if n.parentPath and n.parentPath ~= "" then add(childrenByParent, key(n.parentPath), id) end
        end

        local function edge(a, b, t, c, reason)
            if not a or not b or a == b then return true end
            if #graph.edges >= edgeLimit then
                graph.truncated = true
                graph.omittedEdgesLowerBound = 1
                return false
            end
            graph.edges[#graph.edges + 1] = {
                from = a, to = b, type = t, confidence = c or .5, evidence = reason,
            }
            graph.edgeCount = #graph.edges
            return true
        end

        -- Sort parent paths so reaching the budget produces repeatable partial output.
        for _, parentPath in ipairs(sortedKeys(childrenByParent)) do
            local ids = childrenByParent[parentPath]
            local p = graph.byPath[parentPath]
            if p then
                for _, id in ipairs(ids) do
                    if not edge(p, id, "contains", .98, "parent/child") then return graph end
                end
            end
        end

        for _, stageId in ipairs(graph.byType.Stage or {}) do
            local stage = graph.nodes[stageId]
            local childIds = childrenByParent[key(stage.path)] or {}
            local waves, enemies, bosses = {}, {}, {}
            for _, id in ipairs(childIds) do
                local t = graph.nodes[id].type
                if t == "Wave" then waves[#waves + 1] = id
                elseif t == "Enemy" then enemies[#enemies + 1] = id
                elseif t == "Boss" then bosses[#bosses + 1] = id end
            end
            for _, wid in ipairs(waves) do
                if not edge(stageId, wid, "contains", .9, "stage child") then return graph end
            end
            for _, eid in ipairs(enemies) do
                if not edge(stageId, eid, "contains", .7, "stage child") then return graph end
            end
            for _, bid in ipairs(bosses) do
                if not edge(stageId, bid, "boss_of", .78, "boss under stage") then return graph end
            end
            for _, wid in ipairs(waves) do
                for _, eid in ipairs(enemies) do
                    if not edge(wid, eid, "spawns", .72, "wave/stage structure") then return graph end
                end
                for _, bid in ipairs(bosses) do
                    if not edge(wid, bid, "spawns", .74, "wave/stage structure") then return graph end
                end
            end
        end
        return graph
    end

    M.MAX_GRAPH_EDGES = MAX_GRAPH_EDGES
    return M
end
