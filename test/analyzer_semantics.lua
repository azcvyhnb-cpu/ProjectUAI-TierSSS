-- Static semantic fixture for the Game Analyzer pipeline.
-- This test documents expected normalization/classification behavior without touching Roblox.
local function assertEq(a,b,msg) if a~=b then error((msg or "assertion failed")..": "..tostring(a).." ~= "..tostring(b)) end end
local function assertTrue(v,msg) if not v then error(msg or "expected truthy") end end

-- Fixture shape mirrors the records accepted by analyzer/normalizer.
local records={
 {id="s1",name="Stage1",className="Folder",path="Workspace.Map.Stage1",attributes={}},
 {id="w1",name="Wave1",className="Folder",path="Workspace.Map.Stage1.Wave1",attributes={}},
 {id="e1",name="Goblin",className="Model",path="Workspace.Map.Stage1.Wave1.Goblin",attributes={EnemyType="Normal",Health=100}},
 {id="b1",name="DragonBoss",className="Model",path="Workspace.Map.Stage1.Wave1.DragonBoss",attributes={IsBoss=true,Health=10000}},
}

return {name="analyzer semantics fixture",records=records,checks=function(model)
 assertTrue(model.stats.nodes==4,"node count")
 assertTrue(model.classification.primary=="Tower Defense" or model.classification.primary=="Adventure","classification should detect stage/wave/enemy")
 assertTrue(model.entities["e1"] and model.entities["e1"].type=="Enemy","enemy entity")
 assertTrue(model.entities["b1"] and model.entities["b1"].type=="Boss","boss entity")
 assertTrue(#model.graph.edges>0,"graph edges")
end}
