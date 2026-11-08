-- luacheck: globals C_CVar CreateFrame LuckyGrabbag wipe print
--
-- Run from the addon root: lua tests/ForeverGraphicsTest.lua

local cvars = { farclip = "7000", sunShafts = "1", gone = nil }
C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, value) cvars[name] = tostring(value) end,
    GetCVarDefault = function(name) return cvars[name] and "0" or nil end,
}
function wipe(t) for k in pairs(t) do t[k] = nil end end

local onEvent
function CreateFrame()
    return {
        RegisterEvent = function() end,
        UnregisterAllEvents = function() end,
        SetScript = function(_, _, fn) onEvent = fn end,
    }
end

dofile("src/features/ForeverGraphics.lua")
local FG = LuckyGrabbag.ForeverGraphics
local db = { foreverGraphics = {} }
FG:Init(db)

FG.Set("farclip", 10000)
FG.Set("farclip", 15000)
assert(cvars.farclip == "15000", "the CVar takes the new value")
assert(db.foreverGraphics.farclip.original == "7000", "the value it replaced is kept from the first change")

FG.Set("sunShafts", 1)
assert(not db.foreverGraphics.sunShafts, "setting the value already there saves nothing")

cvars.farclip = "5000"
db.foreverGraphics.gone = { value = 1, original = "0" }
onEvent()
assert(cvars.farclip == "15000", "login puts saved values back over Blizzard's sliders")
assert(cvars.gone == nil, "a CVar this build dropped is not recreated")

FG.Restore()
assert(cvars.farclip == "7000", "Restore puts back what was there before")
assert(next(db.foreverGraphics) == nil, "and forgets every saved value")

print("ForeverGraphics: all checks passed")
