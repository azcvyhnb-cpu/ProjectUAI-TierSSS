-- Read-only semantic graph built from normalized discovery records.
-- Uses indexes rather than an all-pairs node scan so large places remain bounded.
return function(env)
    local M = {}
    local function key(v) return tostring(v or ""):lower() end
    local function add(map, k, v) map[k] = map[k] or {}; map[k][#map[k]+1] = v end

    function M.new()
        return {schemaVersion=1,nodes={},edges={},byType={},byPath={},revision=0}
    end

    function M.update(graph, snapshot, entities)
        graph.revision=graph.revision+1
        graph.nodes,graph.edges,graph.byType,graph.byPath={},{},{},{}
        local childrenByParent={}
        for _,n in ipairs(snapshot.nodes or {}) do
            local id=tostring(n.id or n.path or n.name)
            local e=entities[id]
            graph.nodes[id]={id=id,name=n.name,className=n.className,path=n.path,type=(e and e.type) or "Instance",confidence=(e and e.confidence) or 0}
            graph.byPath[key(n.path)]=id
            add(graph.byType,graph.nodes[id].type,id)
            if n.parentPath and n.parentPath~="" then add(childrenByParent,key(n.parentPath),id) end
        end
        local function edge(a,b,t,c,reason)
            if a and b and a~=b then graph.edges[#graph.edges+1]={from=a,to=b,type=t,confidence=c or .5,evidence=reason} end
        end
        for parentPath,ids in pairs(childrenByParent) do
            local p=graph.byPath[parentPath]
            if p then for _,id in ipairs(ids) do edge(p,id,"contains",.98,"parent/child") end end
        end
        for _,stageId in ipairs(graph.byType.Stage or {}) do
            local stage=graph.nodes[stageId]
            local childIds=childrenByParent[key(stage.path)] or {}
            local waves,enemies,bosses={}, {}, {}
            for _,id in ipairs(childIds) do
                local t=graph.nodes[id].type
                if t=="Wave" then waves[#waves+1]=id elseif t=="Enemy" then enemies[#enemies+1]=id elseif t=="Boss" then bosses[#bosses+1]=id end
            end
            for _,wid in ipairs(waves) do edge(stageId,wid,"contains",.9,"stage child") end
            for _,eid in ipairs(enemies) do edge(stageId,eid,"contains",.7,"stage child") end
            for _,bid in ipairs(bosses) do edge(stageId,bid,"boss_of",.78,"boss under stage") end
            for _,wid in ipairs(waves) do
                for _,eid in ipairs(enemies) do edge(wid,eid,"spawns",.72,"wave/stage structure") end
                for _,bid in ipairs(bosses) do edge(wid,bid,"spawns",.74,"wave/stage structure") end
            end
        end
        return graph
    end
    return M
end
