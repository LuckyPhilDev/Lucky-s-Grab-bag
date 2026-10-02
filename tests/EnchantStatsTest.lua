-- luacheck: globals LuckyGrabbag

-- Covers features/EnchantStats.lua: the quality icon is lifted out of the name
-- so it can sit in its own column.
--
-- Run from the addon root: lua tests/EnchantStatsTest.lua

LuckyGrabbag = { EnchantStatsData = {}, Logger = function() return function() end end }
dofile("src/features/EnchantStats.lua")

local Without = LuckyGrabbag.EnchantStats.WithoutQualityIcon
local ICON = "|A:Professions-ChatIcon-Quality-Tier3:17:15::1|a"

local text, found = Without("|cff0070ddEnchant Helm|r " .. ICON, ICON)
assert(text == "|cff0070ddEnchant Helm|r" and found)

text, found = Without("Enchant Helm", "")
assert(text == "Enchant Helm" and not found)

text, found = Without("Enchant Helm", ICON)
assert(text == "Enchant Helm" and not found)

-- With the icon on the left, anything else put in front of the name goes after it.
local Lead = LuckyGrabbag.EnchantStats.QualityLead
local SPACER = "|TInterface\\Common\\spacer:14:20|t"

local lead, rest, width = Lead({ luckyQualitySide = "left" }, SPACER .. "Enchant Helm")
assert(lead == SPACER and rest == "Enchant Helm" and width == 20)

lead, rest, width = Lead({ luckyQualitySide = "right" }, "Enchant Helm")
assert(lead == "" and rest == "Enchant Helm" and width == 0)

lead, rest, width = Lead({}, "Plain Cloth")
assert(lead == "" and rest == "Plain Cloth" and width == 0)

dofile("src/features/EnchantStatsData.lua")
local Data = LuckyGrabbag.EnchantStatsData
local SLOT = "Interface\\AddOns\\Luckys_Grab_Bag\\media\\icons\\enchant-slots\\"

assert(Data:SlotIcon(nil, "Enchant Ring - Thalassian Haste |A:Professions-ChatIcon-Quality-Tier3:17:15::1|a") == SLOT .. "ring")
assert(Data:SlotIcon(nil, "Sunfire Silk Spellthread") == SLOT .. "legs")
assert(Data:SlotIcon(nil, "Forest Hunter's Armor Kit") == SLOT .. "legs")
assert(Data:SlotIcon(nil, "Enchant Cloak - Anything") == nil)
assert(Data:SlotIcon(nil, "Quick Peridot") == nil)

print("EnchantStatsTest passed")
