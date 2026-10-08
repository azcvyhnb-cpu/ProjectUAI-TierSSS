-- Multi-signal game classifier. Scores are comparative evidence, not guarantees.
return function(env)
    local M={}
    local DEFINITIONS={
        {name="Tower Defense", required={"Stage","Wave","Enemy","Character"}, bonus={"Upgrade"}},
        {name="RPG", required={"Character","Combat","Quest","Inventory"}, bonus={"Upgrade","Currency"}},
        {name="Simulator", required={"Currency","Upgrade","Inventory"}, bonus={"Rebirth"}},
        {name="Gacha", required={"Gacha","Character","Inventory"}, bonus={"Currency","Quest"}},
        {name="Tycoon", required={"Currency","Upgrade","Shop"}, bonus={"Income","Rebirth"}},
        {name="Adventure", required={"Stage","Quest","Character"}, bonus={"Enemy","Boss"}},
    }
    function M.run(model, evidence, graph)
        local cand={}
        for _,d in ipairs(DEFINITIONS) do
            local sum,count=0,0
            for _,s in ipairs(d.required) do sum=sum+(evidence.score(evidence,s)); count=count+1 end
            local bonus=0
            for _,s in ipairs(d.bonus) do bonus=bonus+evidence.score(evidence,s) end
            local c=(count>0 and sum/count or 0)*0.8 + bonus*0.2/math.max(1,#d.bonus)
            cand[#cand+1]={name=d.name,confidence=math.max(0,math.min(1,c)),signals=d.required}
        end
        table.sort(cand,function(a,b)return a.confidence>b.confidence end)
        model.classification.candidates=cand
        local top=cand[1]
        model.classification.primary=(top and top.confidence>=0.5) and top.name or "Unknown"
        model.classification.confidence=top and top.confidence or 0
        model.classification.version=2
        return model.classification
    end
    return M
end
