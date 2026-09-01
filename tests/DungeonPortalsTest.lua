-- luacheck: globals C_ChallengeMode C_SpellBook LuckyGrabbag strtrim print

-- Covers how a dungeon on the map is matched to its teleport. The match runs on
-- the names the client hands back rather than on any ID we store, so the shapes
-- that have to survive are the mega-dungeons, where the journal and the
-- challenge modes disagree about what the place is called.
--
-- Run from the addon root: lua tests/DungeonPortalsTest.lua

strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local challengeModeNames = {
    [503] = "Ara-Kara, City of Echoes",
    [525] = "Operation: Floodgate",
    [227] = "Return to Karazhan: Lower",
    [234] = "Return to Karazhan: Upper",
    [391] = "Tazavesh: Streets of Wonder",
    [392] = "Tazavesh: So'leah's Gambit",
    [369] = "Mechagon: Junkyard",
    [370] = "Mechagon: Workshop",
    [353] = "Siege of Boralus",
}
C_ChallengeMode = { GetMapUIInfo = function(id) return challengeModeNames[id] end }

local known = {}
C_SpellBook = { IsSpellInSpellBook = function(spellID) return known[spellID] == true end }

LuckyGrabbag = { Logger = function() return function() end end }
dofile("src/features/DungeonPortalsData.lua")
dofile("src/features/DungeonPortals.lua")

local function TeleportFor(name) return LuckyGrabbag.DungeonPortals.TeleportFor(nil, name) end
local RaidTeleportFor = LuckyGrabbag.DungeonPortals.TeleportFor

local function learn(...)
    known = {}
    for _, spellID in ipairs({ ... }) do known[spellID] = true end
end

learn(445417, 373262, 367416, 1216786, 373274, 464256)

assert(TeleportFor("Ara-Kara, City of Echoes") == 445417, "a name that matches outright")
assert(TeleportFor("  ara-kara, CITY of Echoes ") == 445417, "case and padding should not matter")

-- The journal knows one Karazhan; the challenge modes know its two wings.
assert(TeleportFor("Return to Karazhan") == 373262, "a journal name the wings start with")

-- Tazavesh is the dungeon this deliberately gives up on: its two names share
-- only a word, and reaching it would also read "Operation: Mechagon" as
-- "Operation: Floodgate" whenever the wings are not named after the journal.
assert(TeleportFor("Tazavesh, the Veiled Market") == nil, "a name sharing only its first word")
assert(TeleportFor("Operation: Floodgate") == 1216786, "Floodgate still matches itself outright")
assert(TeleportFor("Operation: Mechagon") == nil, "and never answers for its neighbour")

assert(TeleportFor("Freehold") == nil, "a dungeon whose teleport is not indexed")
assert(TeleportFor("The Deadmines") == nil, "a dungeon with no teleport at all")
assert(TeleportFor(nil) == nil, "a pin with no name")
assert(TeleportFor("") == nil, "an empty name must not match the first dungeon it finds")

-- Siege of Boralus has a teleport per faction and the player only ever knows one.
assert(TeleportFor("Siege of Boralus") == 464256, "the faction teleport the player has")
learn(445418)
assert(TeleportFor("Siege of Boralus") == 445418, "the other faction's teleport")
learn()
assert(TeleportFor("Siege of Boralus") == nil, "neither faction teleport earned")

-- Raids resolve off the journal instance ID the pin carries, ignoring the name.
learn(1226482)
assert(RaidTeleportFor(1296, "Liberation of Undermine") == 1226482, "a raid the player has the teleport for")
assert(RaidTeleportFor(1296, nil) == 1226482, "the raid path needs no name at all")
learn()
assert(RaidTeleportFor(1296, "Liberation of Undermine") == nil, "a raid teleport not yet earned")
assert(RaidTeleportFor(1273, "Nerub-ar Palace") == nil, "a raid with no teleport spell")

-- The class teleport table is pure data; what can rot is a typo'd coordinate
-- or a spell ID pasted twice, so that is what gets checked.
local seenSpell = {}
for class, entries in pairs(LuckyGrabbag.CLASS_TELEPORTS) do
    for i, entry in ipairs(entries) do
        local where = class .. " entry " .. i
        assert(type(entry.map) == "number", where .. " has a destination map")
        assert(entry.x > 0 and entry.x < 1 and entry.y > 0 and entry.y < 1,
            where .. " lands inside its map")
        for _, list in ipairs({ entry.teleport, entry.portal }) do
            for _, spellID in ipairs(type(list) == "table" and list or { list }) do
                assert(not seenSpell[spellID], "spell " .. spellID .. " appears once")
                seenSpell[spellID] = true
            end
        end
    end
end

print("DungeonPortals: all checks passed")
