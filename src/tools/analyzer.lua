-- Game Analyzer tools, v0.8.
-- Read-only semantic analysis over client-visible discovery data.
return function(env)
    local H = env.require("tools/helpers")
    local refs = env.require("runtime/instance_refs")
    local scan = env.require("runtime/instance_scan")
    local engine = env.require("analyzer/engine")
    local knowledge = env.require("analyzer/knowledge")
    local M = {}
    local identity = {
        placeId = pcall(function() return game.PlaceId end) and game.PlaceId or nil,
        gameId = pcall(function() return game.GameId end) and game.GameId or nil,
        name = pcall(function() return game.Name end) and game.Name or nil,
    }
    local state = engine.new(identity)

    local function collect(root, ctx, limit)
        local records = {}
        local ok, stats = pcall(function()
            return scan.descendants(root, ctx, function(node)
                if #records >= limit then return false end
                local id = refs.id(node)
                local okPath, path = pcall(function() return node:GetFullName() end)
                local attrs = {}
                pcall(function() attrs = node:GetAttributes() end)
                records[#records + 1] = {
                    id=id, name=node.Name, className=node.ClassName,
                    path=okPath and path or node.Name,
                    attributes=attrs, source="instance_scan", observedAt=os.clock(),
                }
            end, limit)
        end)
        if not ok then return records, {complete=false, reason=tostring(stats), scanned=#records} end
        return records, stats or {complete=true, scanned=#records}
    end

    local function analyze(args, ctx)
        local root, err = H.resolve(args.root or "game")
        if not root then return H.fail(err) end
        local limit = math.max(100, math.min(10000, tonumber(args.limit) or 3000))
        local records, stats = collect(root, ctx, limit)
        local result = engine.analyze(state, records, args.reset == true)
        result.analysis={complete=stats.complete==true,reason=stats.reason,scanned=stats.scanned,revision=result.analysisRevision}
        return {ok=true,data=result,text=string.format("Analyzed %d instances. Type: %s (%.0f%%). Revision %d.",stats.scanned or #records,result.classification.primary,result.classification.confidence*100,result.analysisRevision)}
    end

    M[#M+1]={name="game_analyze",risk="read",description="Build or update a read-only semantic Game Model from client-visible instances.",parameters={type="object",properties={root={type="string"},limit={type="integer",minimum=100,maximum=10000},reset={type="boolean"}},required={}},run=analyze}
    M[#M+1]={name="game_refresh",risk="read",description="Repeat analysis and merge newly observed evidence into the existing Game Model.",parameters={type="object",properties={root={type="string"},limit={type="integer",minimum=100,maximum=10000}},required={}},run=function(args,ctx) args.reset=false; return analyze(args,ctx) end}
    M[#M+1]={name="game_systems",risk="read",description="Return detected systems with confidence and supporting evidence counts.",parameters={type="object",properties={},required={}},run=function() return {ok=true,data=state.model.systems,text="Detected systems returned."} end}
    M[#M+1]={name="game_evidence",risk="read",description="Show evidence supporting a semantic system classification.",parameters={type="object",properties={system={type="string"}},required={"system"}},run=function(args) local facts=engine.getEvidence(state,args.system); return {ok=true,data=facts,text=#facts.." evidence item(s)."} end}
    M[#M+1]={name="game_entities",risk="read",description="Return semantic entities discovered in the latest model, optionally filtered by type.",parameters={type="object",properties={type={type="string"}},required={}},run=function(args) local e=engine.getEntities(state,args.type); return {ok=true,data=e,text=#e.." entity(ies)."} end}
    M[#M+1]={name="game_world",risk="read",description="Return the current read-only semantic world graph and statistics.",parameters={type="object",properties={},required={}},run=function() local g=engine.getGraph(state); return {ok=true,data=g,text=string.format("Graph: %d nodes, %d edges.",#(g.nodes or {}),#(g.edges or {}))} end}
    M[#M+1]={name="game_graph",risk="read",description="Return graph relationships such as contains and spawns.",parameters={type="object",properties={},required={}},run=function() local g=engine.getGraph(state); return {ok=true,data=g.edges,text=#g.edges.." relationship(s)."} end}
    M[#M+1]={name="game_timeline",risk="read",description="Return the runtime observation timeline accumulated by analyzer refreshes.",parameters={type="object",properties={limit={type="integer",minimum=1,maximum=500}},required={}},run=function(args) local t=engine.getTimeline(state); local n=math.min(tonumber(args.limit) or #t.events,#t.events); local out={}; for i=#t.events-n+1,#t.events do if i>0 then out[#out+1]=t.events[i] end end; return {ok=true,data=out,text=#out.." timeline event(s)."} end}
    M[#M+1]={name="game_plan",risk="read",description="Return bounded follow-up discovery targets selected from uncertain or weakly supported systems.",parameters={type="object",properties={},required={}},run=function() return {ok=true,data=state.model.adaptive or {},text=#(state.model.adaptive or {}).." follow-up target(s)."} end}
    M[#M+1]={name="game_focus",risk="read",description="Perform a bounded read-only follow-up scan of one analyzer-selected path and merge the new evidence.",parameters={type="object",properties={path={type="string"},limit={type="integer",minimum=50,maximum=3000}},required={"path"}},run=function(args,ctx)
        local root,err=H.resolve(args.path); if not root then return H.fail(err) end
        local records,stats=collect(root,ctx,math.max(50,math.min(3000,tonumber(args.limit) or 800)))
        local result=engine.analyze(state,records,false)
        result.analysis={complete=stats.complete==true,reason=stats.reason,scanned=stats.scanned,revision=result.analysisRevision,focusedPath=args.path}
        return {ok=true,data=result,text=string.format("Focused %s: %d instances.",args.path,stats.scanned or #records)}
    end}
    M[#M+1]={name="game_classification",risk="read",description="Return comparative game-type classification and confidence signals.",parameters={type="object",properties={},required={}},run=function() return {ok=true,data=state.model.classification,text=state.model.classification.primary} end}
    M[#M+1]={name="game_knowledge",risk="read",description="Return the semantic knowledge patterns currently used by the analyzer.",parameters={type="object",properties={system={type="string"}},required={}},run=function(args) local k=knowledge.all(); if args.system then return {ok=true,data=k[args.system],text=tostring(args.system)} end return {ok=true,data=k,text="Knowledge base returned."} end}
    M[#M+1]={name="game_stats",risk="read",description="Return analyzer revision, node/entity/graph/timeline statistics.",parameters={type="object",properties={},required={}},run=function() local m=state.model; return {ok=true,data={revision=m.analysisRevision,nodes=m.stats.nodes,entities=m.stats.entityCount,graphNodes=m.stats.graphNodes,graphEdges=m.stats.graphEdges,evidence=m.stats.evidence,timeline=state.timeline.revision},text="Analyzer statistics returned."} end}
    return M
end
