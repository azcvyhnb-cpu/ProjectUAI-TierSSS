-- Converts normalized nodes into conservative semantic entities.
return function(env)
    local M = {}
    local function lower(s) return tostring(s or ""):lower() end
    local function has(s, terms) for _,t in ipairs(terms) do if lower(s):find(t,1,true) then return true end end return false end
    local function attr(n, names) for _,k in ipairs(names) do if n.attributes[k] ~= nil or n.attributes[lower(k)] ~= nil then return true end end return false end
    local function classify(n)
        local text = lower(n.name.." "..n.path)
        if attr(n,{"IsBoss","Boss","BossType"}) or has(text,{"boss","raidboss","worldboss"}) then return "Boss",0.82 end
        if attr(n,{"EnemyType","MobType","NPCType"}) or has(text,{"enemy","enemies","mob","mobs","monster","monsters"}) then return "Enemy",0.78 end
        if has(text,{"character","characters","unit","units","hero","heroes"}) then return "Character",0.70 end
        if has(text,{"stage","stages","chapter","chapters"}) then return "Stage",0.70 end
        if has(text,{"wave","waves"}) then return "Wave",0.72 end
        if has(text,{"quest","quests","mission","missions"}) then return "Quest",0.68 end
        if has(text,{"shop","store","vendor","merchant"}) then return "Shop",0.68 end
        if has(text,{"inventory","backpack"}) then return "Inventory",0.68 end
        return nil,0
    end
    function M.build(snapshot)
        local out={}
        for _,n in ipairs(snapshot.nodes or {}) do
            local t,c=classify(n)
            if t then local id=tostring(n.id or n.path or n.name); out[id]={id=id,type=t,confidence=c,name=n.name,path=n.path,className=n.className,attributes=n.attributes,source=n.source} end
        end
        return out
    end
    return M
end
