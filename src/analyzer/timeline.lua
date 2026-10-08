-- Lightweight runtime timeline. Events are supplied by observation layers; no hooks are created here.
return function(env)
    local M={}
    function M.new(limit) return {schemaVersion=1,limit=limit or 500,events={},revision=0} end
    function M.push(state, kind, subject, data, observedAt)
        state.revision=state.revision+1
        state.events[#state.events+1]={id=state.revision,time=observedAt or os.clock(),kind=tostring(kind or "observation"),subject=subject,data=data}
        while #state.events>state.limit do table.remove(state.events,1) end
    end
    function M.diff(state, previous, current)
        local seen={}; for _,n in ipairs(previous or {}) do seen[tostring(n.id or n.path or n.name)]=true end
        for _,n in ipairs(current or {}) do local id=tostring(n.id or n.path or n.name); if not seen[id] then M.push(state,"discovered",id,{name=n.name,path=n.path,className=n.className},n.observedAt) end end
    end
    return M
end
