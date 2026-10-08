-- Extensible semantic knowledge base. Entries describe patterns, not executable game actions.
return function(env)
    local M={}
    local KB={
        Enemy={terms={"enemy","enemies","mob","mobs","monster","monsters"},attrs={"EnemyType","MobType","NPCType"}},
        Boss={terms={"boss","raidboss","worldboss"},attrs={"IsBoss","Boss","BossType"}},
        Character={terms={"character","characters","unit","units","hero","heroes"}},
        Quest={terms={"quest","quests","mission","missions"}},
        Stage={terms={"stage","stages","chapter","chapters","story"}},
        Wave={terms={"wave","waves"}},
        Inventory={terms={"inventory","backpack","items"}},
        Shop={terms={"shop","store","vendor","merchant"}},
        Gacha={terms={"gacha","summon","summons","roll","rolling","banner","banners"}},
        Upgrade={terms={"upgrade","upgrades","enhance","enhancement"}},
        Currency={terms={"currency","currencies","money","coins","cash","gems"}},
        Crafting={terms={"craft","crafting","recipe","recipes","forge","fusing"}},
        Trading={terms={"trade","trading","exchange"}},
        Rebirth={terms={"rebirth","prestige","reset"}},
    }
    function M.new() return {version=1,observations={},analysisPasses=0} end
    function M.get(name) return KB[name] end
    function M.all() return KB end
    function M.add(name,entry) if type(name)=="string" and type(entry)=="table" then KB[name]=entry; return true end return false end
    function M.observe(state,model)
        state.analysisPasses=state.analysisPasses+1
        for system,data in pairs(model.systems or {}) do
            if data.detected then
                local o=state.observations[system] or {seen=0,totalConfidence=0,maxConfidence=0}
                o.seen=o.seen+1; o.totalConfidence=o.totalConfidence+(data.confidence or 0); o.maxConfidence=math.max(o.maxConfidence,data.confidence or 0)
                o.avgConfidence=o.totalConfidence/o.seen
                state.observations[system]=o
            end
        end
    end
    function M.learned(state) return state and state.observations or {} end
    return M
end
