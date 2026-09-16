-- luacheck: globals C_DelvesUI C_Spell C_Timer C_Traits CreateFrame Enum GetSpecialization
-- luacheck: globals GetSpecializationInfo GetSpecializationInfoByID InCombatLockdown LuckyGrabbag
-- luacheck: globals LuckyStrings print
--
-- Covers the delve companion loadout memory. The shape that has to survive is a
-- config that reads back empty, which is the bug the feature exists for: it must
-- refill the slots rather than record the emptiness.
--
-- Run from the addon root: lua tests/DelveCompanionTest.lua

Enum = { CurioType = { Combat = 1, Utility = 2 } }

local trees = {
    [900] = { role = 10, combat = 11, utility = 12, flavor = 13 },
    [901] = { role = 20, combat = 21, utility = 22, flavor = 0 },
}
local entryIDs = {
    [10] = { 1, 2 }, [11] = { 3, 4 }, [12] = { 5, 6 }, [13] = { 7, 8 },
    [20] = { 1, 2 }, [21] = { 3, 4 }, [22] = { 5, 6 },
}

local treeID, specIndex, active, staged, pending, commits, commitOK

local function reset()
    treeID, specIndex, active = 900, 1, {}
    staged, pending, commits, commitOK = false, {}, 0, true
end

C_DelvesUI = {
    GetTraitTreeForCompanion = function() return treeID end,
    GetRoleNodeForCompanion = function() return trees[treeID].role end,
    GetCurioNodeForCompanion = function(curioType)
        return curioType == Enum.CurioType.Combat and trees[treeID].combat or trees[treeID].utility
    end,
    GetFlavorNodeForCompanion = function() return trees[treeID].flavor end,
}

C_Traits = {
    GetConfigIDByTreeID = function(id) return trees[id] and id + 5000 or nil end,
    GetNodeInfo = function(_, nodeID)
        if not entryIDs[nodeID] then return nil end
        return {
            ID = nodeID,
            entryIDs = entryIDs[nodeID],
            activeEntry = active[nodeID] and { entryID = active[nodeID] } or nil,
        }
    end,
    ConfigHasStagedChanges = function() return staged end,
    SetSelection = function(_, nodeID, entryID) pending[nodeID] = entryID return true end,
    IsReadyForCommit = function() return true end,
    CommitConfig = function()
        commits = commits + 1
        if not commitOK then return false end
        for nodeID, entryID in pairs(pending) do active[nodeID] = entryID end
        pending = {}
        return true
    end,
    RollbackConfig = function() pending = {} end,
    GetEntryInfo = function(_, entryID) return { definitionID = entryID } end,
    GetDefinitionInfo = function(id) return { overrideName = "Choice " .. id } end,
}

C_Spell = { GetSpellLink = function() return nil end }
C_Timer = { After = function(_, fn) fn() end }
InCombatLockdown = function() return false end
GetSpecialization = function() return specIndex end
GetSpecializationInfo = function(index) return 250 + index end
GetSpecializationInfoByID = function(id) return id, "Spec " .. id end

local fired
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, fn) fired = fn end,
    }
end

local messages = {}
print = function(msg) messages[#messages + 1] = msg end

LuckyStrings = { New = function(_, tbl) return tbl end }
LuckyGrabbag = { Logger = function() return function() end end }
dofile("src/Strings.lua")
LuckyGrabbag.PREFIX = LuckyGrabbag.Strings.addon.prefix
dofile("src/features/DelveCompanion.lua")

local DelveCompanion = LuckyGrabbag.DelveCompanion
local db, charDB

local function fresh()
    reset()
    messages = {}
    db, charDB = { delveCompanionPerSpec = true }, {}
    DelveCompanion:Init(db, charDB)
end

local function memoryFor(tree, spec)
    return charDB.delveCompanionBySpec[tree .. ":" .. spec]
end

-- A loadout the player picked is remembered against the spec they picked it in.
fresh()
active = { [10] = 1, [11] = 3, [12] = 5, [13] = 7 }
DelveCompanion.Snapshot()
local saved = memoryFor(900, 251)
assert(saved[10] == 1 and saved[11] == 3 and saved[12] == 5 and saved[13] == 7,
    "every selection slot is recorded")

-- The bug: the delve hands the loadout back empty. That must not be recorded.
active = {}
DelveCompanion.Snapshot()
saved = memoryFor(900, 251)
assert(saved[10] == 1 and saved[13] == 7, "an empty config never clears the memory")

DelveCompanion.Restore()
assert(active[10] == 1 and active[11] == 3 and active[12] == 5 and active[13] == 7,
    "restore refills every emptied slot")
assert(commits == 1, "one commit for the whole loadout")
assert(#messages == 1 and messages[1]:find("Choice 1", 1, true), "the chat message names what came back")

-- Nothing to do means nothing is committed and nothing is said.
messages = {}
DelveCompanion.Restore()
assert(commits == 1 and #messages == 0, "a matching loadout is left alone")

-- A second spec keeps its own loadout.
specIndex = 2
DelveCompanion.Restore()
assert(commits == 1, "a spec with no memory yet has nothing to restore")
DelveCompanion.Snapshot()
assert(memoryFor(900, 252)[10] == 1, "first visit adopts what is loaded as the baseline")
active[10] = 2
DelveCompanion.Snapshot()
specIndex = 1
DelveCompanion.Restore()
assert(active[10] == 1, "switching back restores the first spec's choice")
assert(memoryFor(900, 252)[10] == 2, "and the second spec's choice is still remembered")

-- The player is mid-edit at the Delver's Supplies: leave their staged work alone.
fresh()
active = { [10] = 1, [11] = 3, [12] = 5, [13] = 7 }
DelveCompanion.Snapshot()
active, staged = {}, true
DelveCompanion.Restore()
assert(commits == 0, "a config with staged changes is not touched")

-- A failed commit is rolled back and reported rather than left half applied.
fresh()
active = { [10] = 1, [11] = 3, [12] = 5, [13] = 7 }
DelveCompanion.Snapshot()
active, commitOK = {}, false
DelveCompanion.Restore()
assert(next(active) == nil and next(pending) == nil, "nothing is left staged after a failed commit")
assert(#messages == 1 and messages[1]:find("Set it manually", 1, true), "the failure is reported")

-- Next season's companion is a different tree, with node IDs that mean nothing
-- to the old one. It starts its own memory instead of inheriting.
fresh()
active = { [10] = 1, [11] = 3, [12] = 5, [13] = 7 }
DelveCompanion.Snapshot()
treeID, active = 901, { [20] = 2, [21] = 4, [22] = 6 }
DelveCompanion.Snapshot()
assert(memoryFor(901, 251)[20] == 2, "the new companion records against its own tree")
assert(memoryFor(900, 251)[10] == 1, "and the old companion's memory is untouched")

-- A companion with no flavour slot reports node 0, which is not a node.
fresh()
treeID, active = 901, { [20] = 1, [21] = 3, [22] = 5 }
DelveCompanion.Snapshot()
saved = memoryFor(901, 251)
assert(saved[0] == nil, "an absent slot is skipped rather than stored as node 0")

-- Events run the whole sync: restore what is missing, then record what is there.
fresh()
active = { [10] = 1, [11] = 3, [12] = 5, [13] = 7 }
DelveCompanion.Snapshot()
active = {}
fired(nil, "PLAYER_ENTERING_WORLD")
assert(active[10] == 1, "zoning in refills an emptied loadout")

-- Combat blocks the commit, and leaving combat picks it up.
fresh()
active = { [10] = 1, [11] = 3, [12] = 5, [13] = 7 }
DelveCompanion.Snapshot()
active = {}
InCombatLockdown = function() return true end
fired(nil, "PLAYER_ENTERING_WORLD")
assert(next(active) == nil, "no config is committed in combat")
InCombatLockdown = function() return false end
fired(nil, "PLAYER_REGEN_ENABLED")
assert(active[10] == 1, "the sync blocked by combat runs when combat ends")

print("DelveCompanion: all assertions passed")
io.write(messages[#messages], "\n")
