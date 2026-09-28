LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.AssignTanks = {}

function LuckyGrabbag.AssignTanks.UnassignedTanks()
    local names = {}
    for i = 1, GetNumGroupMembers() do
        local name, _, _, _, _, _, _, _, _, assignment, _, combatRole = GetRaidRosterInfo(i)
        if name and combatRole == "TANK" and (assignment or ""):upper() ~= "MAINTANK" then
            names[#names + 1] = name
        end
    end
    return names
end

-- SetPartyAssignment is protected, so the assignment has to run as a macro from a secure click.
function LuckyGrabbag.AssignTanks.Macro(names)
    local lines = {}
    for i, name in ipairs(names) do
        lines[i] = "/maintank " .. name
    end
    return table.concat(lines, "\n")
end
