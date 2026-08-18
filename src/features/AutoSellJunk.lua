-- Lucky's Grab-bag: Auto-sell grey-quality junk at vendors
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.AutoSellJunk = {}

local db

local POOR_QUALITY = (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor) or 0
local REAGENT_BAG  = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5

local DevLog = LuckyGrabbag.Logger("AutoSellJunk")

-- Backpack + carried bags, plus the reagent bag when one is equipped.
local function GetBagIDs()
    local ids = {}
    for bag = 0, NUM_BAG_SLOTS do table.insert(ids, bag) end
    local slots = C_Container.GetContainerNumSlots(REAGENT_BAG)
    if type(slots) == "number" and slots > 0 then
        table.insert(ids, REAGENT_BAG)
    end
    return ids
end

local FormatCost = LuckyUtils.FormatMoney

local function SellJunk()
    if not db.autoSellJunk then return end

    local soldCount = 0
    local soldValue = 0

    for _, bag in ipairs(GetBagIDs()) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == POOR_QUALITY and not info.hasNoValue and not info.isLocked then
                local stack = info.stackCount or 1
                local sellPrice = select(11, GetItemInfo(info.itemID)) or 0
                soldCount = soldCount + 1
                soldValue = soldValue + (sellPrice * stack)
                C_Container.UseContainerItem(bag, slot)
            end
        end
    end

    if soldCount == 0 then
        DevLog("No junk to sell")
        return
    end

    local S = LuckyGrabbag.Strings.autoSellJunk
    local msg = (soldCount == 1) and string.format(S.soldOne, FormatCost(soldValue))
        or string.format(S.soldMany, soldCount, FormatCost(soldValue))
    print(LuckyGrabbag.PREFIX .. " " .. msg)
    DevLog("Sold " .. soldCount .. " items for " .. FormatCost(soldValue))
end

function LuckyGrabbag.AutoSellJunk:Init(database)
    db = database
    DevLog("Init called")

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:SetScript("OnEvent", function(_, event)
        DevLog("Event: " .. event)
        SellJunk()
    end)
end
