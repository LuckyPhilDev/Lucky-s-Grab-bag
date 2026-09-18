-- luacheck: globals LuckyGrabbag C_Container C_Bank C_Timer ItemLocation Enum NUM_BAG_SLOTS

-- Covers AutoDepositUtils.DepositableOnly: a deposit queue keeps only what the
-- Warband Bank will take, so a soulbound item is never queued and retried on
-- every bank open.
--
-- Run from the addon root: lua tests/AutoDepositUtilsTest.lua

NUM_BAG_SLOTS = 0
Enum = { BankType = { Account = 2 }, BagIndex = { ReagentBag = 5 } }
C_Timer = { After = function() end }

-- Bag 0 slot contents; bound stacks are the ones the bank refuses.
local slots = {
    { itemID = 1, stackCount = 20, bound = true },   -- soulbound only
    { itemID = 2, stackCount = 5, bound = true },    -- mixed
    { itemID = 2, stackCount = 3 },
    { itemID = 3, stackCount = 4 },                  -- free to move
    { itemID = 4, stackCount = 2 },                  -- vetoed by a slot filter
}

C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #slots or 0 end,
    GetContainerItemInfo = function(bag, slot) return bag == 0 and slots[slot] or nil end,
}
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
C_Bank = {
    IsItemAllowedInBankType = function(_, loc) return not slots[loc.slot].bound end,
}

dofile("src/AutoDepositUtils.lua")
local Utils = LuckyGrabbag.AutoDepositUtils

local passed = 0
local function check(cond, label)
    if not cond then error(label, 2) end
    passed = passed + 1
end

local queue = Utils.DepositableOnly({
    { itemID = 1, amount = 20 },
    { itemID = 2, amount = 8 },
    { itemID = 3, amount = 4 },
    { itemID = 4, amount = 2, slotFilter = function() return false end },
})

local byID = {}
for _, entry in ipairs(queue) do byID[entry.itemID] = entry end

check(byID[1] == nil, "an item with only soulbound copies is never queued")
check(byID[2] and byID[2].amount == 3, "a mixed item is capped at the copies the bank takes")
check(byID[3] and byID[3].amount == 4, "a free item keeps its amount")
check(byID[4] == nil, "an item whose every stack is vetoed by its slot filter is dropped")
check(queue[1].itemID == 2 and queue[2].itemID == 3, "queue order is kept")

print(string.format("%d AutoDepositUtils tests passed", passed))
