-- Lucky's Grab-bag: Auto-Deposit Utilities
-- Shared infrastructure for depositing items to the warband bank.
-- Used by ReagentMains, WarboundAutoDeposit, and other auto-deposit features.

LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.AutoDepositUtils = {}

local Utils = LuckyGrabbag.AutoDepositUtils

-- Deposit pacing — same values as Warband Stockist's bank pipeline.
Utils.pickupDelay  = 0.1
Utils.placeDelay   = 0.05
Utils.depositDelay = 0.1
Utils.perItemDelay = 0.25

local REAGENT_BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5

function Utils.GetAllPlayerBagIDs()
    local ids = {}
    for bag = 0, NUM_BAG_SLOTS do table.insert(ids, bag) end
    local ok = pcall(function() return C_Container.GetContainerNumSlots(REAGENT_BAG) end)
    if ok then
        local slots = C_Container.GetContainerNumSlots(REAGENT_BAG)
        if type(slots) == "number" and slots > 0 then
            table.insert(ids, REAGENT_BAG)
        end
    end
    return ids
end

function Utils.ScanInventory()
    local inventory = {}  -- itemID → total count in player bags
    for _, bag in ipairs(Utils.GetAllPlayerBagIDs()) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                inventory[info.itemID] = (inventory[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    return inventory
end

function Utils.FindStackableBankSlot(itemID)
    local function slotMax(bag, slot)
        if ItemLocation and ItemLocation.CreateFromBagAndSlot then
            local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if loc and C_Item.DoesItemExist(loc) then
                local m = C_Item.GetItemMaxStackSize(loc)
                if m and m > 0 then return m end
            end
        end
        return select(8, C_Item.GetItemInfo(itemID))
    end
    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    if type(tabIDs) ~= "table" then return nil, nil end
    for _, bagID in ipairs(tabIDs) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info and info.itemID == itemID then
                local maxStack = slotMax(bagID, slot)
                if maxStack and (info.stackCount or 0) < maxStack then
                    return bagID, slot
                end
            end
        end
    end
    return nil, nil
end

function Utils.FindEmptyBankSlot()
    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    if type(tabIDs) ~= "table" then return nil, nil end
    for _, bankBag in ipairs(tabIDs) do
        local freeSlots = C_Container.GetContainerFreeSlots(bankBag)
        if freeSlots and #freeSlots > 0 then
            return bankBag, freeSlots[1]
        end
    end
    return nil, nil
end

function Utils.TryDepositItem(itemID, amountToDeposit, callback)
    local bagSlots = {}

    for _, bag in ipairs(Utils.GetAllPlayerBagIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                if C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, loc) then
                    table.insert(bagSlots, { bag = bag, slot = slot, count = info.stackCount })
                end
            end
        end
    end

    local function depositNext(index, remaining)
        if index > #bagSlots or remaining <= 0 then
            if callback then callback() end
            return
        end

        local entry = bagSlots[index]
        local bag, slot, stackCount = entry.bag, entry.slot, entry.count
        local toMove = math.min(stackCount, remaining)

        C_Timer.After(Utils.pickupDelay, function()
            ClearCursor()
            local lockInfo = select(3, C_Container.GetContainerItemInfo(bag, slot))
            if lockInfo == true then
                depositNext(index + 1, remaining)
                return
            end

            if toMove < stackCount then
                C_Container.SplitContainerItem(bag, slot, toMove)
                C_Timer.After(Utils.placeDelay, function()
                    if GetCursorInfo() ~= "item" then
                        C_Timer.After(Utils.perItemDelay, function() depositNext(index + 1, remaining) end)
                        return
                    end
                    local destBag, destSlot = Utils.FindStackableBankSlot(itemID)
                    if not destBag then destBag, destSlot = Utils.FindEmptyBankSlot() end
                    if destBag and destSlot then
                        C_Container.PickupContainerItem(destBag, destSlot)
                        C_Timer.After(Utils.perItemDelay, function() depositNext(index + 1, remaining - toMove) end)
                    else
                        C_Container.PickupContainerItem(bag, slot)
                        C_Timer.After(Utils.perItemDelay, function() depositNext(index + 1, remaining) end)
                    end
                end)
            else
                C_Container.PickupContainerItem(bag, slot)
                C_Timer.After(Utils.depositDelay, function()
                    local destBag, destSlot = Utils.FindStackableBankSlot(itemID)
                    if not destBag then destBag, destSlot = Utils.FindEmptyBankSlot() end
                    if destBag and destSlot then
                        C_Container.PickupContainerItem(destBag, destSlot)
                    else
                        ClearCursor()
                    end
                    C_Timer.After(Utils.perItemDelay, function() depositNext(index + 1, remaining - toMove) end)
                end)
            end
        end)
    end

    depositNext(1, amountToDeposit)
end

function Utils.ProcessQueue(queue, index)
    if index > #queue then return end
    local entry = queue[index]
    Utils.TryDepositItem(entry.itemID, entry.amount, function()
        C_Timer.After(Utils.perItemDelay, function() Utils.ProcessQueue(queue, index + 1) end)
    end)
end
