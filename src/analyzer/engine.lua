-- Read-only semantic analysis pipeline, v0.8.
return function(env)
    local normalizer=env.require("analyzer/normalizer")
    local evidence=env.require("analyzer/evidence")
    local detectors=env.require("analyzer/detectors")
    local entities=env.require("analyzer/entities")
    local graph=env.require("analyzer/graph")
    local model=env.require("analyzer/model")
    local classifier=env.require("analyzer/classifier")
    local timeline=env.require("analyzer/timeline")
    local adaptive=env.require("analyzer/adaptive")
    local knowledge=env.require("analyzer/knowledge")
    local M={}
    function M.new(identity)
        return {identity=identity or {},evidence=evidence.new(),model=model.new(identity),snapshot=nil,previousSnapshot=nil,graph=graph.new(),timeline=timeline.new(500),revision=0,knowledgeVersion=1,knowledge=knowledge.new()}
    end
    function M.analyze(state,records,reset)
        local snapshot=normalizer.snapshot(records or {})
        local ledger=(reset and evidence.new()) or state.evidence or evidence.new()
        if state.snapshot then timeline.diff(state.timeline,state.snapshot.nodes,snapshot.nodes) end
        detectors.run(snapshot,ledger)
        local entityMap=entities.build(snapshot)
        state.previousSnapshot=state.snapshot
        state.snapshot=snapshot
        state.evidence=ledger
        state.revision=state.revision+1
        state.model=model.update(state.model or model.new(state.identity),snapshot,ledger)
        state.model.entities=entityMap
        state.graph=graph.update(state.graph,snapshot,entityMap)
        classifier.run(state.model,ledger,state.graph)
        state.model.graph={nodes=state.graph.nodes,edges=state.graph.edges,revision=state.graph.revision}
        state.model.timeline={events=state.timeline.events,revision=state.timeline.revision}
        state.model.adaptive=adaptive.plan(state.model,snapshot,25)
        knowledge.observe(state.knowledge,state.model)
        state.model.knowledge={version=state.knowledgeVersion,systems=knowledge.all(),learned=knowledge.learned(state.knowledge),analysisPasses=state.knowledge.analysisPasses}
        state.model.analysisRevision=state.revision
        state.model.stats.entityCount=0
        for _ in pairs(entityMap) do state.model.stats.entityCount=state.model.stats.entityCount+1 end
        state.model.stats.graphNodes=0; for _ in pairs(state.graph.nodes) do state.model.stats.graphNodes=state.model.stats.graphNodes+1 end
        state.model.stats.graphEdges=#state.graph.edges
        return state.model
    end
    function M.getEvidence(state,system) return evidence.top(state.evidence,system,10) end
    function M.getEntities(state,kind)
        local out={}; for _,e in pairs(state.model.entities or {}) do if not kind or e.type==kind then out[#out+1]=e end end
        table.sort(out,function(a,b)return (a.confidence or 0)>(b.confidence or 0) end); return out
    end
    function M.getGraph(state) return state.graph end
    function M.getTimeline(state) return state.timeline end
    return M
end
