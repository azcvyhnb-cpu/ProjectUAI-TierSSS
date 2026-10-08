-- Universal Game Analyzer: normalize client-visible discovery records.
-- Read-only. This module does not access or mutate Roblox instances.
return function(env)
    local M = {}

    local function lower(v)
        return string.lower(tostring(v or ""))
    end

    local function copyMap(src)
        local out = {}
        if type(src) == "table" then
            for k, v in pairs(src) do out[k] = v end
        end
        return out
    end

    local function pathParts(path)
        local out = {}
        for part in string.gmatch(tostring(path or ""), "[^%.]+") do
            out[#out + 1] = part
        end
        return out
    end

    local function classFamily(className)
        local c = lower(className)
        if c == "model" then return "model" end
        if c == "folder" then return "container" end
        if c == "part" or c == "meshpart" or c == "unionoperation" then return "part" end
        if c == "remoteevent" or c == "remotefunction" or c == "bindableevent" or c == "bindablefunction" then return "signal" end
        if c == "moduleScript" or c == "modulescript" or c == "localscript" or c == "script" then return "script" end
        if c == "tool" then return "tool" end
        if c == "humanoid" then return "humanoid" end
        if c == "player" then return "player" end
        if c == "screenGui" or c == "screengui" or c == "frame" or c == "textlabel" or c == "imagelabel" then return "gui" end
        return "instance"
    end

    function M.node(raw)
        raw = raw or {}
        local attrs = copyMap(raw.attributes or raw.Attributes)
        local props = copyMap(raw.properties or raw.Properties)
        local tags = raw.tags or raw.Tags or {}
        local path = tostring(raw.path or raw.displayPath or raw.fullName or "")
        local name = tostring(raw.name or raw.Name or "")
        local className = tostring(raw.className or raw.ClassName or "Instance")
        local parts = pathParts(path)
        local parent = raw.parentPath or raw.parent or ""
        if parent == "" and #parts > 1 then
            table.remove(parts)
            parent = table.concat(parts, ".")
        end
        return {
            id = raw.id or raw.instanceId or raw.identity,
            name = name,
            nameLower = lower(name),
            className = className,
            family = classFamily(className),
            path = path,
            pathLower = lower(path),
            parentPath = tostring(parent),
            properties = props,
            attributes = attrs,
            tags = tags,
            hasChildren = raw.hasChildren == true,
            childCount = tonumber(raw.childCount) or 0,
            sourceCapable = raw.sourceCapable == true,
            sourceAvailable = raw.sourceAvailable == true,
            observedAt = raw.observedAt,
            source = raw.source or "discovery",
        }
    end

    function M.snapshot(records)
        local nodes, byId, byPath = {}, {}, {}
        for _, raw in ipairs(records or {}) do
            local n = M.node(raw)
            nodes[#nodes + 1] = n
            if n.id then byId[tostring(n.id)] = n end
            if n.path ~= "" then byPath[n.pathLower] = n end
        end
        return { nodes = nodes, byId = byId, byPath = byPath, count = #nodes }
    end

    return M
end
