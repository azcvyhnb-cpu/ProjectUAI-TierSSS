-- Semantic detectors. They only inspect normalized discovery records.
-- No writes, remote invocation, hooks, or server access are performed here.
return function(env)
    local evidence = env.require("analyzer/evidence")
    local M = {}

    local function hasText(s, terms)
        s = string.lower(tostring(s or ""))
        for _, term in ipairs(terms) do if string.find(s, term, 1, true) then return true, term end end
        return false
    end

    local function attr(node, names)
        for _, name in ipairs(names) do
            if node.attributes[name] ~= nil or node.attributes[string.lower(name)] ~= nil then return true, name end
        end
        return false
    end

    local function prop(node, names)
        for _, name in ipairs(names) do
            if node.properties[name] ~= nil or node.properties[string.lower(name)] ~= nil then return true, name end
        end
        return false
    end

    function M.run(snapshot, ledger)
        local nodes = snapshot.nodes or {}
        local counts = {}
        local function count(name) counts[name] = (counts[name] or 0) + 1 end

        local systemTerms = {
            Enemy = {"enemy", "enemies", "mob", "mobs", "monster", "monsters"},
            Boss = {"boss", "raidboss", "worldboss"},
            Character = {"character", "characters", "unit", "units", "hero", "heroes"},
            Inventory = {"inventory", "backpack", "items"},
            Shop = {"shop", "store", "vendor", "merchant"},
            Quest = {"quest", "quests", "mission", "missions"},
            Stage = {"stage", "stages", "level", "levels", "chapter", "chapters"},
            Wave = {"wave", "waves"},
            Upgrade = {"upgrade", "upgrades", "enhance", "enhancement"},
            Gacha = {"gacha", "summon", "summons", "roll", "rolling", "banner", "banners"},
            Currency = {"currency", "currencies", "money", "coins", "cash", "gems"},
            Crafting = {"craft", "crafting", "recipe", "recipes", "forge", "fusing"},
            Trading = {"trade", "trading", "exchange"},
            Rebirth = {"rebirth", "prestige", "reset"},
        }

        for _, node in ipairs(nodes) do
            for system, terms in pairs(systemTerms) do
                local ok, term = hasText(node.name, terms)
                if not ok then ok, term = hasText(node.path, terms) end
                if ok then
                    count(system)
                    evidence.add(ledger, system, node.nameLower == term and 0.82 or 0.46,
                        "name/path contains '" .. term .. "'", "instance", node.path)
                end
            end

            local hp, hpName = attr(node, {"Health", "MaxHealth", "HP", "HealthValue"})
            if not hp then hp, hpName = prop(node, {"Health", "MaxHealth", "HealthDisplayDistance"}) end
            local enemyType, enemyTypeName = attr(node, {"EnemyType", "MobType", "NPCType"})
            if hp then evidence.add(ledger, "Combat", 0.35, "health-like field: " .. hpName, "property/attribute", node.path) end
            if enemyType then evidence.add(ledger, "Enemy", 0.72, "enemy-type field: " .. enemyTypeName, "attribute", node.path) end

            local boss, bossName = attr(node, {"IsBoss", "Boss", "BossType"})
            if boss then evidence.add(ledger, "Boss", 0.88, "boss marker: " .. bossName, "attribute", node.path) end

            if node.className == "Humanoid" then
                evidence.add(ledger, "Character", 0.35, "Humanoid instance", "class", node.path)
                evidence.add(ledger, "Combat", 0.28, "Humanoid instance", "class", node.path)
            end

            if node.className == "RemoteEvent" or node.className == "RemoteFunction" then
                evidence.add(ledger, "Network", 0.55, "remote endpoint discovered", "class", node.path)
            end
        end

        -- Structural patterns are stronger than names alone.
        local function repeatedRoot(terms, system, weight, reason)
            local hits = 0
            for _, node in ipairs(nodes) do
                local ok = hasText(node.path, terms)
                if ok and (node.family == "model" or node.family == "container") then hits = hits + 1 end
            end
            if hits >= 2 then evidence.add(ledger, system, weight, reason .. "; repeated matching structure", "structure", nil) end
        end

        repeatedRoot({"story", "chapter"}, "Stage", 0.55, "story/chapter hierarchy")
        repeatedRoot({"wave"}, "Wave", 0.65, "wave hierarchy")
        repeatedRoot({"enemy", "enemies", "mob", "mobs"}, "Enemy", 0.62, "enemy container hierarchy")
        repeatedRoot({"shop", "store"}, "Shop", 0.58, "shop container hierarchy")

        return counts
    end

    return M
end
