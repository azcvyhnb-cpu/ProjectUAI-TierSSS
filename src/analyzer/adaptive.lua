-- Produces bounded, read-only follow-up discovery targets from uncertainty in the model.
return function(env)
    local M={}
    function M.plan(model, snapshot, limit)
        limit=limit or 20
        local targets={}
        local wanted={"Stage","Wave","Enemy","Boss","Character","Quest","Inventory","Shop","Gacha","Upgrade"}
        for _,system in ipairs(wanted) do
            local s=model.systems[system]
            if not s or s.confidence<0.72 then
                for _,n in ipairs(snapshot.nodes or {}) do
                    local p=tostring(n.path or "")
                    if p:lower():find(system:lower(),1,true) then
                        targets[#targets+1]={system=system,path=p,priority=1-(s and s.confidence or 0)}
                        if #targets>=limit then return targets end
                    end
                end
            end
        end
        table.sort(targets,function(a,b)return a.priority>b.priority end)
        return targets
    end
    return M
end
