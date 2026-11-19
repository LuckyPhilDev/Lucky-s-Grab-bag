-- luacheck: globals CreateFrame LuckyGrabbag LuckyUtils LuckyStrings LibStub print
-- luacheck: globals LOCALIZED_CLASS_NAMES_MALE LOCALIZED_CLASS_NAMES_FEMALE RAID_CLASS_COLORS GetQuestDifficultyColor
--
-- Run from the addon root: lua tests/FriendsOverlayTest.lua

function CreateFrame()
    return { RegisterEvent = function() end, SetScript = function() end, UnregisterAllEvents = function() end }
end
LuckyStrings = { New = function(_, t) return t end }
LOCALIZED_CLASS_NAMES_MALE = { DRUID = "Druid" }
LOCALIZED_CLASS_NAMES_FEMALE = { DRUID = "Druid" }
RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.49, b = 0.04, colorStr = "ffff7c0a" } }
function GetQuestDifficultyColor() return { r = 0, g = 1, b = 0 } end

dofile("src/Strings.lua")
dofile("src/features/FriendsOverlay.lua")
local FO = LuckyGrabbag.FriendsOverlay

local db = {
    friendsOverlayShowLevel = true, friendsOverlayShowClass = true, friendsOverlayShowFaction = true,
    friendsOverlayShowLocation = true, friendsOverlayShowGame = true,
    friendsOverlayClassColors = false, friendsOverlayWholeLineClass = false,
    friendsOverlayFactionColors = false, friendsOverlayLevelColors = false,
}
FO:Init(db)

local bnet = { account = "CptQuail", name = "Anna Morph", level = 56, class = "Druid",
    faction = "Alliance", area = "Blackrock Depths", game = "Retail" }

local text, lineColor = FO.FormatFriend(bnet)
assert(text == "CptQuail - Anna Morph, 56 Druid, A, Blackrock Depths, Retail", text)
assert(not lineColor, "no line colour without whole-line class colour")

text = FO.FormatFriend({ name = "Golmund", level = 29, class = "Hunter", faction = "Alliance", area = "Redridge" })
assert(text == "Golmund, 29 Hunter, A, Redridge", text)

text = FO.FormatFriend({ account = "Sunna", game = "Overwatch 2" })
assert(text == "Sunna, Overwatch 2", text)

db.friendsOverlayShowLevel, db.friendsOverlayShowLocation, db.friendsOverlayShowGame = false, false, false
assert(FO.FormatFriend(bnet) == "CptQuail - Anna Morph, Druid, A", FO.FormatFriend(bnet))

db.friendsOverlayShowLevel = true
db.friendsOverlayClassColors, db.friendsOverlayFactionColors, db.friendsOverlayLevelColors = true, true, true
text = FO.FormatFriend(bnet)
assert(text == "CptQuail - |cffff7c0aAnna Morph|r, |cff00ff0056|r |cffff7c0aDruid|r, |cff4a8cffA|r", text)

db.friendsOverlayWholeLineClass = true
text, lineColor = FO.FormatFriend(bnet)
assert(text == "CptQuail - Anna Morph, 56 Druid, A", text)
assert(lineColor == RAID_CLASS_COLORS.DRUID, "whole line takes the class colour")

local function names(list)
    local out = {}
    for i, friend in ipairs(list) do out[i] = friend.name end
    return table.concat(out, " ")
end
local online = { { name = "a" }, { name = "b", favorite = true }, { name = "c" }, { name = "d", favorite = true } }
assert(names(FO.Limit(online, 2)) == "b d", "favourites claim places first")
assert(names(FO.Limit(online, 3)) == "a b d", "kept friends stay in order")
assert(names(FO.Limit(online, 6)) == "a b c d", "short lists are untouched")

local sharedFonts = { ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF", ["Expressway"] = "Interface\\Expressway.ttf" }
function LibStub()
    return {
        List = function() return { "Friz Quadrata TT", "Expressway" } end,
        Fetch = function(_, _, name) return sharedFonts[name] end,
    }
end
local fontLabels = {}
for _, font in ipairs(FO.FontOptions()) do fontLabels[#fontLabels + 1] = font.label end
assert(table.concat(fontLabels, ", ") == "Friz Quadrata, Arial Narrow, Skurri, Morpheus, Expressway",
    table.concat(fontLabels, ", "))

print("FriendsOverlayTest: all passed")
