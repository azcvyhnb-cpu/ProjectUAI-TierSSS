-- Graph budget regression: deterministic edge cap and explicit partial-result metadata.
package.path = "test/?.lua;test/mock/?.lua;" .. package.path

local luau = require("luau")
local file = assert(io.open("src/analyzer/graph.lua", "rb"))
local source = file:read("*a")
file:close()
local factory, compileError = luau.load(source, "analyzer/graph")
assert(factory, compileError)
local module = factory()({})
local passed = 0
local function check(label, ok)
    assert(ok, label)
    passed = passed + 1
    print("  ok   " .. label)
end

local smallSnapshot = { nodes = {
    { id = "stage", name = "Stage", path = "Workspace/Stage", className = "Folder" },
    { id = "wave", name = "Wave1", path = "Workspace/Stage/Wave1", parentPath = "Workspace/Stage" },
    { id = "enemy", name = "Enemy1", path = "Workspace/Stage/Enemy1", parentPath = "Workspace/Stage" },
} }
local smallEntities = { stage = { type = "Stage", confidence = .9 }, wave = { type = "Wave", confidence = .8 }, enemy = { type = "Enemy", confidence = .8 } }
local small = module.update(module.new(), smallSnapshot, smallEntities)
check("small graph remains complete", small.truncated == false and small.edgeCount == #small.edges)
check("edge count metadata matches actual edges", small.edgeCount == #small.edges)

local nodes, entities = {
    { id = "stage", name = "Stage", path = "Workspace/Stage" },
}, { stage = { type = "Stage", confidence = .9 } }
for i = 1, 100 do
    local id = "wave" .. i
    nodes[#nodes + 1] = { id = id, name = id, path = "Workspace/Stage/" .. id, parentPath = "Workspace/Stage" }
    entities[id] = { type = "Wave", confidence = .8 }
end
for i = 1, 20 do
    local id = "enemy" .. i
    nodes[#nodes + 1] = { id = id, name = id, path = "Workspace/Stage/" .. id, parentPath = "Workspace/Stage" }
    entities[id] = { type = "Enemy", confidence = .8 }
end
local bounded = module.update(module.new(), { nodes = nodes }, entities, { maxEdges = 150 })
check("edge budget stops graph expansion", #bounded.edges <= 150 and bounded.edgeCount <= 150)
check("budget exhaustion marks the graph truncated", bounded.truncated == true)
check("truncation reports at least one omitted edge", bounded.omittedEdgesLowerBound >= 1)
check("reported edge limit is clamped to request", bounded.edgeLimit == 150)

local again = module.update(module.new(), { nodes = nodes }, entities, { maxEdges = 150 })
local function signature(graph)
    local out = {}
    for _, e in ipairs(graph.edges) do out[#out + 1] = e.from .. ">" .. e.to .. ":" .. e.type end
    return table.concat(out, "|")
end
check("truncated output is deterministic", signature(bounded) == signature(again))
check("global hard ceiling is exposed", module.MAX_GRAPH_EDGES == 12000)

print(string.format("Analyzer graph: %d checks passed", passed))
