-- luacheck: globals CreateFrame GetInventoryItemDurability INVSLOT_FIRST_EQUIPPED INVSLOT_LAST_EQUIPPED
-- luacheck: globals LuckyGrabbag LuckyReminders print
-- luacheck: globals C_Housing C_Container C_Item C_PerksActivities C_PerksProgram C_WeeklyRewards GetInventoryItemLink
-- luacheck: globals GetMaxLevelForPlayerExpansion HasNewMail NUM_BAG_SLOTS UnitLevel
-- luacheck: globals INVSLOT_HEAD INVSLOT_SHOULDER INVSLOT_CHEST INVSLOT_LEGS INVSLOT_FEET
-- luacheck: globals INVSLOT_FINGER1 INVSLOT_FINGER2 INVSLOT_MAINHAND INVSLOT_OFFHAND
-- luacheck: globals HEADSLOT SHOULDERSLOT CHESTSLOT LEGSSLOT FEETSLOT FINGER0SLOT_UNIQUE FINGER1SLOT_UNIQUE
-- luacheck: globals MAINHANDSLOT SECONDARYHANDSLOT
--
-- Run from the addon root: lua tests/RemindersTest.lua

INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED = 1, 19
INVSLOT_HEAD, INVSLOT_SHOULDER, INVSLOT_CHEST, INVSLOT_LEGS, INVSLOT_FEET = 1, 3, 5, 7, 8
INVSLOT_FINGER1, INVSLOT_FINGER2, INVSLOT_MAINHAND, INVSLOT_OFFHAND = 11, 12, 16, 17
HEADSLOT, SHOULDERSLOT, CHESTSLOT, LEGSSLOT, FEETSLOT = "Head", "Shoulders", "Chest", "Legs", "Feet"
FINGER0SLOT_UNIQUE, FINGER1SLOT_UNIQUE, MAINHANDSLOT, SECONDARYHANDSLOT = "Finger 1", "Finger 2", "Main Hand", "Off Hand"
NUM_BAG_SLOTS = 4

local level, links, sockets, gems, equipLocs = 90, {}, {}, {}, {}
function UnitLevel() return level end
function GetMaxLevelForPlayerExpansion() return 90 end
function GetInventoryItemLink(_, slot) return links[slot] end
C_Item = {
    GetItemNumSockets = function(link) return sockets[link] end,
    GetItemGem = function(link, index) return gems[link] and gems[link][index] end,
    GetItemInfoInstant = function(link) return 1, "", "", equipLocs[link] end,
}

local vaultWaiting, chestRewards, chestRequests, mail = false, {}, 0, false
C_WeeklyRewards = { HasAvailableRewards = function() return vaultWaiting end }
C_PerksProgram = {
    GetPendingChestRewards = function() return chestRewards end,
    RequestPendingChestRewards = function() chestRequests = chestRequests + 1 end,
}
local perksActivities = {
    activities = { { completed = true, thresholdContributionAmount = 500 }, { completed = false, thresholdContributionAmount = 500 } },
    thresholds = { { requiredContributionAmount = 250 }, { requiredContributionAmount = 1000 } },
}
C_PerksActivities = { GetPerksActivitiesInfo = function() return perksActivities end }
function HasNewMail() return mail end

local favorRequests, houseListRequests = {}, 0
C_Housing = {
    GetPlayerOwnedHouses = function() houseListRequests = houseListRequests + 1 end,
    GetCurrentHouseLevelFavor = function(guid) favorRequests[#favorRequests + 1] = guid end,
    GetMaxHouseLevel = function() return 5 end,
    GetHouseLevelFavorForLevel = function(houseLevel) return houseLevel * 1000 end,
}

local freeSlots = {}
C_Container = { GetContainerNumFreeSlots = function(bag)
    local entry = freeSlots[bag] or { 0, 0 }
    return entry[1], entry[2]
end }

local durability = {}
function GetInventoryItemDurability(slot)
    local d = durability[slot]
    if d then return d[1], d[2] end
end

local registered, refreshes, events, onEvent = nil, 0, {}, nil
LuckyReminders = {
    Register = function(_, id, source) registered = { id = id, source = source } end,
    Refresh = function() refreshes = refreshes + 1 end,
}
function CreateFrame()
    return {
        RegisterEvent = function(_, event) events[event] = true end,
        SetScript = function(_, _, fn) onEvent = fn end,
    }
end

LuckyGrabbag = {
    Logger = function() return function() end end,
    Strings = { reminders = {
        repair = "Repair your gear", repairDetail = "%d%%",
        houseUpgrade = "Upgrade your house",
        enchants = "Missing enchants", slotCount = "%d slots", sockets = "Empty gem sockets",
        greatVault = "Open the Great Vault", tradingPost = "Collect your Trader's Tender",
        bags = "Bags nearly full", bagsDetail = "%d free", mail = "You have mail",
    } },
}
dofile("src/features/Reminders.lua")

local passed = 0
local function check(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
    passed = passed + 1
end

local db = {
    reminders = true, remindRepair = true, remindEnchantsIgnore = {},
}
LuckyGrabbag.Reminders:Init(db)
local rows = registered.source.rows

-- Repair -----------------------------------------------------------------------
check(registered.id, "grabbag", "registers a source")
check(#rows(), 0, "nothing equipped, nothing to repair")

durability = { [1] = { 80, 100 }, [5] = { 60, 100 }, [16] = { 0, 0 } }
check(#rows(), 0, "gear above half durability is left alone")

durability[5] = { 35, 100 }
check(#rows(), 1, "a piece below half durability asks for a repair")
check(rows()[1].detail, "35%", "showing the most worn piece")

db.remindRepair = false
check(#rows(), 0, "unless the reminder is switched off")

check(events.UPDATE_INVENTORY_DURABILITY, true, "watches durability")
onEvent(nil, "UPDATE_INVENTORY_DURABILITY")
check(refreshes, 1, "and redraws the window when it changes")

-- Each of the rest is checked alone, with every other reminder off.
local function only(setting)
    for key in pairs(db) do db[key] = nil end
    db.reminders, db[setting], db.remindEnchantsIgnore = true, true, {}
end

-- Enchants ---------------------------------------------------------------------
only("remindEnchants")
links = {
    [1] = "item:100:7:::", [3] = "item:101::::", [5] = "item:102:0:::", [2] = "item:103::::",
    [16] = "item:104:9:::", [17] = "item:105::::",
}
check(rows()[1].detail, "Shoulders, Chest", "unenchanted slots are named, and a neck is not asked for")

equipLocs["item:105::::"] = "INVTYPE_WEAPONOFFHAND"
check(rows()[1].detail, "Shoulders, Chest, Off Hand", "an off-hand weapon counts, a shield does not")

links[7], links[8] = "item:106::::", "item:107::::"
check(rows()[1].detail, "5 slots", "a long list is counted instead")

db.remindEnchantsIgnore = { shoulder = true, chest = true, offHand = true }
check(rows()[1].detail, "Legs, Feet", "ignored slots are left out")
db.remindEnchantsIgnore.legs, db.remindEnchantsIgnore.feet = true, true
check(#rows(), 0, "and with every bare slot ignored the reminder clears")
db.remindEnchantsIgnore = {}

local options = LuckyGrabbag.Reminders.EnchantSlotOptions()
check(#options, 9, "the settings panel is offered every enchantable slot")
check(options[6].label, "Finger 1", "with the two rings told apart")

level = 85
check(#rows(), 0, "nothing while levelling")
level = 90

-- Sockets ----------------------------------------------------------------------
only("remindSockets")
check(#rows(), 0, "no sockets, no reminder")
sockets["item:100:7:::"], sockets["item:103::::"] = 2, 1
gems["item:100:7:::"] = { "Gem" }
check(rows()[1].detail, "2", "empty sockets are counted across every slot")
gems["item:100:7:::"], gems["item:103::::"] = { "Gem", "Gem" }, { "Gem" }
check(#rows(), 0, "and the reminder clears once they are filled")

-- Great Vault and Trading Post -------------------------------------------------
only("remindGreatVault")
check(#rows(), 0, "an empty vault is left alone")
vaultWaiting = true
check(rows()[1].text, "Open the Great Vault", "a waiting reward reminds")

only("remindTradingPost")
check(#rows(), 0, "nothing in the Collector's Cache")
chestRewards = { { rewardAmount = 500 } }
check(rows()[1].text, "Collect your Trader's Tender", "tender waiting reminds")
onEvent(nil, "PLAYER_ENTERING_WORLD")
check(chestRequests, 1, "and login asks the server what is waiting")
db.remindTradingPostFullTrack = true
check(#rows(), 0, "an unfinished monthly track holds the reminder")
perksActivities.activities[2].completed = true
check(rows()[1].text, "Collect your Trader's Tender", "a finished track reminds")

-- House upgrade ----------------------------------------------------------------
only("remindHouseUpgrade")
onEvent(nil, "PLAYER_ENTERING_WORLD")
check(houseListRequests, 1, "login asks for the house list")
check(#rows(), 0, "nothing known yet")

onEvent(nil, "PLAYER_HOUSE_LIST_UPDATED", { { houseGUID = "House-1", neighborhoodName = "Founder's Point" }, { plotID = 3 } })
check(favorRequests[1], "House-1", "each owned house is asked for its level")
check(#favorRequests, 1, "and an entry with no house is skipped")

onEvent(nil, "HOUSE_LEVEL_FAVOR_UPDATED", { houseGUID = "House-1", houseLevel = 2, houseFavor = 2900 })
check(#rows(), 0, "short of the next level")

onEvent(nil, "HOUSE_LEVEL_FAVOR_UPDATED", { houseGUID = "House-1", houseLevel = 2, houseFavor = 3000 })
check(rows()[1].text, "Upgrade your house", "enough House XP reminds")
check(rows()[1].detail, "Founder's Point", "naming the neighborhood to go to")

onEvent(nil, "HOUSE_LEVEL_CHANGED")
check(houseListRequests, 2, "an upgrade asks again")
onEvent(nil, "HOUSE_LEVEL_FAVOR_UPDATED", { houseGUID = "House-1", houseLevel = 5, houseFavor = 99999 })
check(#rows(), 0, "and a house at the top level has nothing to upgrade to")

-- Bags and mail ----------------------------------------------------------------
only("remindBags")
freeSlots = { [0] = { 3, 0 }, [1] = { 4, 0 }, [2] = { 20, 8 } }
check(#rows(), 0, "room in the general bags")
freeSlots[1] = { 1, 0 }
check(rows()[1].detail, "4 free", "a profession bag's space does not count")

only("remindMail")
check(#rows(), 0, "no mail")
mail = true
check(rows()[1].text, "You have mail", "unread mail reminds")

-- Master toggle ----------------------------------------------------------------
only("remindRepair")
db.remindRepair = true
check(#rows(), 1, "reminders on")
db.reminders = false
check(#rows(), 0, "the master toggle silences every reminder")
db.remindHouseUpgrade = true
onEvent(nil, "PLAYER_ENTERING_WORLD")
check(houseListRequests, 2, "and asks the server for nothing")

print(passed .. " Reminders tests passed")
