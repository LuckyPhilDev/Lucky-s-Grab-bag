LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Reminders = {}

local db

local DevLog = LuckyGrabbag.Logger("Reminders")

local REPAIR_BELOW = 0.5
local BAG_SLOTS_FREE_BELOW = 5
local MAX_SLOTS_NAMED = 3

local ICONS = {
    repair      = "Interface\\Icons\\Trade_BlackSmithing",
    enchants    = "Interface\\Icons\\Trade_Engraving",
    sockets     = "Interface\\Icons\\INV_Misc_Gem_01",
    greatVault  = "Interface\\Icons\\INV_Misc_Lockbox_1",
    tradingPost = "Interface\\Icons\\INV_Misc_Coin_02",
    house       = "Interface\\Icons\\INV_Misc_Key_03",
    bags        = "Interface\\Icons\\INV_Misc_Bag_08",
    mail        = "Interface\\Icons\\INV_Letter_15",
}

-- The slots Midnight has enchants for. key is what the ignore list saves, and
-- name is the global holding the slot's name. Revisit when an expansion
-- changes which slots take an enchant.
local ENCHANT_SLOTS = {
    { key = "head",     slot = INVSLOT_HEAD,     name = "HEADSLOT" },
    { key = "shoulder", slot = INVSLOT_SHOULDER, name = "SHOULDERSLOT" },
    { key = "chest",    slot = INVSLOT_CHEST,    name = "CHESTSLOT" },
    { key = "legs",     slot = INVSLOT_LEGS,     name = "LEGSSLOT" },
    { key = "feet",     slot = INVSLOT_FEET,     name = "FEETSLOT" },
    { key = "finger1",  slot = INVSLOT_FINGER1,  name = "FINGER0SLOT_UNIQUE" },
    { key = "finger2",  slot = INVSLOT_FINGER2,  name = "FINGER1SLOT_UNIQUE" },
    { key = "mainHand", slot = INVSLOT_MAINHAND, name = "MAINHANDSLOT" },
    { key = "offHand",  slot = INVSLOT_OFFHAND,  name = "SECONDARYHANDSLOT" },
}

-- An off hand only takes an enchant when it is a weapon, not a shield or a
-- held item.
local OFFHAND_WEAPONS = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true }

local function Strings()
    return LuckyGrabbag.Strings.reminders
end

local function LowestDurability()
    local lowest
    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 then
            lowest = math.min(lowest or 1, current / maximum)
        end
    end
    return lowest
end

local function RepairRow()
    local lowest = LowestDurability()
    if not lowest or lowest >= REPAIR_BELOW then return end
    return { icon = ICONS.repair, text = Strings().repair, detail = Strings().repairDetail:format(lowest * 100) }
end

-- Levelling gear is replaced too fast to be worth enchanting or gemming.
local function AtMaxLevel()
    return UnitLevel("player") >= GetMaxLevelForPlayerExpansion()
end

local function TakesEnchant(slot, link)
    if slot ~= INVSLOT_OFFHAND then return true end
    return OFFHAND_WEAPONS[select(4, C_Item.GetItemInfoInstant(link))] == true
end

local function IsEnchanted(link)
    local enchantID = link:match("item:%d+:(%d*)")
    return enchantID ~= nil and enchantID ~= "" and enchantID ~= "0"
end

local function EnchantsRow()
    if not AtMaxLevel() then return end
    local missing = {}
    for _, entry in ipairs(ENCHANT_SLOTS) do
        local link = not db.remindEnchantsIgnore[entry.key] and GetInventoryItemLink("player", entry.slot)
        if link and TakesEnchant(entry.slot, link) and not IsEnchanted(link) then
            missing[#missing + 1] = _G[entry.name]
        end
    end
    if #missing == 0 then return end
    local detail = #missing <= MAX_SLOTS_NAMED and table.concat(missing, ", ")
        or Strings().slotCount:format(#missing)
    return { icon = ICONS.enchants, text = Strings().enchants, detail = detail }
end

local function EmptySockets(link)
    local empty = 0
    for index = 1, C_Item.GetItemNumSockets(link) or 0 do
        if not C_Item.GetItemGem(link, index) then empty = empty + 1 end
    end
    return empty
end

local function SocketsRow()
    if not AtMaxLevel() then return end
    local empty = 0
    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local link = GetInventoryItemLink("player", slot)
        if link then empty = empty + EmptySockets(link) end
    end
    if empty == 0 then return end
    return { icon = ICONS.sockets, text = Strings().sockets, detail = tostring(empty) }
end

local function GreatVaultRow()
    if not C_WeeklyRewards.HasAvailableRewards() then return end
    return { icon = ICONS.greatVault, text = Strings().greatVault }
end

local function TradingPostRow()
    local pending = C_PerksProgram.GetPendingChestRewards()
    if not pending or #pending == 0 then return end
    return { icon = ICONS.tradingPost, text = Strings().tradingPost }
end

local function FreeBagSlots()
    local free = 0
    for bag = 0, NUM_BAG_SLOTS do
        local slots, family = C_Container.GetContainerNumFreeSlots(bag)
        -- Family 0 is a general bag; a profession bag's space is no use for loot.
        if family == 0 then free = free + slots end
    end
    return free
end

local function BagsRow()
    local free = FreeBagSlots()
    if free >= BAG_SLOTS_FREE_BELOW then return end
    return { icon = ICONS.bags, text = Strings().bags, detail = Strings().bagsDetail:format(free) }
end

local function MailRow()
    if not HasNewMail() then return end
    return { icon = ICONS.mail, text = Strings().mail }
end

-- Names by house GUID, from the owned-house list.
local neighborhoodNames = {}

local function RememberNeighborhoods(houses)
    for _, house in ipairs(houses or {}) do
        if house.houseGUID then neighborhoodNames[house.houseGUID] = house.neighborhoodName end
    end
end

-- houseGUID to the last { houseLevel, houseFavor } the server sent for it. The
-- client holds neither until asked: the house list answers with the GUIDs, and
-- each GUID's level and House XP then arrive in an event of their own.
local houseProgress = {}

local function OnHouseEvent(event, payload)
    if event == "PLAYER_HOUSE_LIST_UPDATED" then
        RememberNeighborhoods(payload)
        for _, house in ipairs(payload or {}) do
            if house.houseGUID then C_Housing.GetCurrentHouseLevelFavor(house.houseGUID) end
        end
    elseif event == "HOUSE_LEVEL_FAVOR_UPDATED" then
        if payload and payload.houseGUID then houseProgress[payload.houseGUID] = payload end
    elseif event == "HOUSE_LEVEL_CHANGED" then
        C_Housing.GetPlayerOwnedHouses()
    end
end

local function HouseUpgradeRow()
    local maxLevel = C_Housing.GetMaxHouseLevel()
    for houseGUID, progress in pairs(houseProgress) do
        local nextLevel = progress.houseLevel + 1
        local needed = nextLevel <= maxLevel and C_Housing.GetHouseLevelFavorForLevel(nextLevel)
        DevLog("House level " .. progress.houseLevel .. " xp=" .. progress.houseFavor .. " next=" .. tostring(needed))
        if needed and progress.houseFavor >= needed then
            return { icon = ICONS.house, text = Strings().houseUpgrade, detail = neighborhoodNames[houseGUID] }
        end
    end
end

-- To add a reminder: a setting that switches it on, a function returning its
-- row while there is something to do and nil otherwise, and the events that
-- can change the answer. onLogin asks the server for anything the row reads
-- that the client does not hold yet, and onEvent sees every watched event
-- before the window redraws, for a reminder that has to keep what one carries.
local REMINDERS = {
    { setting = "remindRepair", row = RepairRow, events = { "UPDATE_INVENTORY_DURABILITY" } },
    { setting = "remindEnchants", row = EnchantsRow, events = { "PLAYER_EQUIPMENT_CHANGED" } },
    { setting = "remindSockets", row = SocketsRow, events = { "PLAYER_EQUIPMENT_CHANGED" } },
    { setting = "remindGreatVault", row = GreatVaultRow, events = { "WEEKLY_REWARDS_UPDATE" } },
    {
        setting = "remindTradingPost",
        row     = TradingPostRow,
        events  = { "CHEST_REWARDS_UPDATED_FROM_SERVER" },
        onLogin = function() C_PerksProgram.RequestPendingChestRewards() end,
    },
    {
        setting = "remindHouseUpgrade",
        row     = HouseUpgradeRow,
        events  = { "PLAYER_HOUSE_LIST_UPDATED", "HOUSE_LEVEL_FAVOR_UPDATED", "HOUSE_LEVEL_CHANGED" },
        onLogin = function() C_Housing.GetPlayerOwnedHouses() end,
        onEvent = OnHouseEvent,
    },
    { setting = "remindBags", row = BagsRow, events = { "BAG_UPDATE_DELAYED" } },
    { setting = "remindMail", row = MailRow, events = { "UPDATE_PENDING_MAIL" } },
}

local function Rows()
    local rows = {}
    if not db.reminders then return rows end
    for _, reminder in ipairs(REMINDERS) do
        if db[reminder.setting] then rows[#rows + 1] = reminder.row() end
    end
    return rows
end

--- The enchantable slots as { key, label } options for the settings panel.
function LuckyGrabbag.Reminders.EnchantSlotOptions()
    local options = {}
    for i, entry in ipairs(ENCHANT_SLOTS) do
        options[i] = { key = entry.key, label = _G[entry.name] }
    end
    return options
end

function LuckyGrabbag.Reminders:Init(database)
    db = database
    LuckyReminders:Register("grabbag", { order = 10, rows = Rows })

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    for _, reminder in ipairs(REMINDERS) do
        for _, event in ipairs(reminder.events) do eventFrame:RegisterEvent(event) end
    end
    local function Each(field, ...)
        for _, reminder in ipairs(REMINDERS) do
            if reminder[field] and db.reminders and db[reminder.setting] then reminder[field](...) end
        end
    end
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- ponytail: an answer slower than the window's two second login delay
            -- misses that opening and waits for the next rest area.
            Each("onLogin")
        else
            Each("onEvent", event, ...)
            LuckyReminders:Refresh()
        end
    end)
end
