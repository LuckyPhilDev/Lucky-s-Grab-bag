-- luacheck: globals GetNumGroupMembers GetRaidRosterInfo LuckyGrabbag
--
-- Run from the addon root: lua tests/AssignTanksTest.lua

local roster = {
    { "Stonewall", "maintank", "TANK" },
    { "Bulwark-Draenor", nil, "TANK" },
    { "Healbot", nil, "HEALER" },
    { "Offtank", "MAINASSIST", "TANK" },
    { "Stabby", "MAINTANK", "DAMAGER" },
}
GetNumGroupMembers = function() return #roster end
GetRaidRosterInfo = function(i)
    local r = roster[i]
    return r[1], nil, nil, nil, nil, nil, nil, nil, nil, r[2], nil, r[3]
end

dofile("src/features/AssignTanks.lua")
local AT = LuckyGrabbag.AssignTanks

local names = AT.UnassignedTanks()
assert(#names == 2, "only tanks without main tank, whatever the assignment's case")
assert(names[1] == "Bulwark-Draenor" and names[2] == "Offtank")
assert(AT.Macro(names) == "/maintank Bulwark-Draenor\n/maintank Offtank")
assert(AT.Macro({}) == "", "nothing to assign runs nothing")

io.write("AssignTanksTest passed\n")
