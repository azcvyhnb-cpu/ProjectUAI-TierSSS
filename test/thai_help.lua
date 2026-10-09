-- Thai UI-help localization tests. Menu/control identifiers remain English.
package.path = "test/?.lua;test/mock/?.lua;" .. package.path
io.stdout:setvbuf("no")
local envMock = require("env")
local h = envMock.new()
h.setViewport(844, 390)
local app = assert(h.boot("dist/uai.lua"))
h.settle(1)

local thai = app.env.require("ui/thai_help")
local registry = app.env.require("agent/registry")
registry.load()
local passed = 0
local function check(label, value)
	assert(value, label)
	passed = passed + 1
	print("ok " .. label)
end

check("settings explanation is Thai", thai.text("Layout follows the viewport by default. Pin it if you would rather it did not."):find("หน้าต่าง", 1, true) ~= nil)
check("tool group explanation is Thai", thai.group("remotes"):find("Remote", 1, true) ~= nil)
check("unknown tool groups still get a Thai explanation", thai.group("custom_group"):find("เครื่องมือ", 1, true) ~= nil)
local research = assert(registry.get("research_search"), "research_search is registered")
check("research tool card explanation is Thai", thai.tool(research):find("ค้นหาบันทึกความรู้", 1, true) ~= nil)
check("tool schemas retain their English identifiers", research.name == "research_search")
check("unmapped technical text falls back safely", thai.text("unknown technical phrase") == "unknown technical phrase")

print(string.format("Thai UI help: %d passed, 0 failed", passed))
