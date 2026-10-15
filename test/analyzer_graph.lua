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

-- Deterministic growth benchmark: many Wave/Enemy siblings create a large
-- cross-product, which must stop at the hard edge ceiling rather than expanding
-- quadratically without a bound. Time is reported for comparison, not asserted.
local largeNodes, largeEntities = {
    { id = "large-stage", name = "Stage", path = "Workspace/LargeStage" },
}, { ["large-stage"] = { type = "Stage", confidence = .9 } }
for i = 1, 200 do
    local id = "large-wave-" .. i
    largeNodes[#largeNodes + 1] = { id = id, name = id, path = "Workspace/LargeStage/" .. id, parentPath = "Workspace/LargeStage" }
    largeEntities[id] = { type = "Wave", confidence = .8 }
end
for i = 1, 100 do
    local id = "large-enemy-" .. i
    largeNodes[#largeNodes + 1] = { id = id, name = id, path = "Workspace/LargeStage/" .. id, parentPath = "Workspace/LargeStage" }
    largeEntities[id] = { type = "Enemy", confidence = .8 }
end
local started = os.clock()
local large = module.update(module.new(), { nodes = largeNodes }, largeEntities)
local elapsedMs = (os.clock() - started) * 1000
check("large graph stays under the hard edge ceiling", large.edgeCount <= module.MAX_GRAPH_EDGES)
check("large graph exposes partial coverage", large.truncated == true and large.omittedEdgesLowerBound >= 1)
print(string.format("graph_benchmark\\tlarge\\tnodes=%d\\tedges=%d\\tlimit=%d\\ttruncated=%s\\tms=%.3f",
    large.nodeCount, large.edgeCount, large.edgeLimit, tostring(large.truncated), elapsedMs))

print(string.format("Analyzer graph: %d checks passed", passed))
