-- luacheck: globals LuckyGrabbag LuckyStrings C_TradeSkillUI C_Item C_AuctionHouse
-- luacheck: globals GetExpansionLevel GetTime StaticPopupDialogs YES NO CreateFrame C_AddOns

-- Covers features/RankPriceCheck.lua: which listings count as a pricier lower
-- rank, that only current expansion items are compared, and that item data still
-- loading is not remembered as "nothing cheaper".
--
-- Run from the addon root: lua tests/RankPriceCheckTest.lua

local CURRENT, OLD = 11, 10

local items = {
    [1] = { name = "Enchant Weapon - Zeal", rank = 1, expansion = CURRENT },
    [2] = { name = "Enchant Weapon - Zeal", rank = 2, expansion = CURRENT },
    [3] = { name = "Enchant Weapon - Zeal", rank = 3, expansion = CURRENT },
    [4] = { name = "Old Potion", rank = 1, expansion = OLD },
    [5] = { name = "Old Potion", rank = 2, expansion = OLD },
    [6] = { name = "Plain Cloth", expansion = CURRENT },
    [7] = { name = "Dawn Crystal |A:Professions-Icon-Quality-Tier1:17:17|a", crafted = 1, expansion = CURRENT },
    [8] = { name = "Dawn Crystal", crafted = 2, expansion = CURRENT },
}

local now = 0
local results = {}

function GetTime() return now end
function GetExpansionLevel() return CURRENT end

C_TradeSkillUI = {
    GetItemReagentQualityByItemInfo = function(itemID) return items[itemID].rank end,
    GetItemCraftedQualityByItemInfo = function(itemID) return items[itemID].crafted end,
}
C_Item = {
    GetItemNameByID = function(itemID) return items[itemID].name end,
    GetItemInfo = function(itemID)
        local expansion = items[itemID].expansion
        if not expansion then return nil end
        return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, expansion
    end,
}
C_AuctionHouse = { GetBrowseResults = function() return results end }

StaticPopupDialogs = {}
YES, NO = "Yes", "No"

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")
LuckyGrabbag.Logger = function() return function() end end
dofile("src/features/RankPriceCheck.lua")

local Check = LuckyGrabbag.RankPriceCheck

local eventFrame
function CreateFrame()
    eventFrame = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.onEvent = fn end }
    return eventFrame
end
C_AddOns = { IsAddOnLoaded = function() return false end }

Check:Init({ rankPriceFlag = false, rankPriceConfirm = true })

local function Browse(prices)
    results = {}
    for itemID, price in pairs(prices) do
        table.insert(results, { itemKey = { itemID = itemID }, minPrice = price })
    end
    eventFrame.onEvent(eventFrame, "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
end

-- ─── The comparison itself ───────────────────────────────────────────────────

local cheaper = Check.CheaperHigherRanks({
    { itemID = 1, name = "Zeal", rank = 1, price = 500 },
    { itemID = 2, name = "Zeal", rank = 2, price = 300 },
    { itemID = 3, name = "Zeal", rank = 3, price = 200 },
    { itemID = 9, name = "Other", rank = 3, price = 1 },
})
assert(cheaper[1].itemID == 3, "the cheapest higher rank should be the one named")
assert(cheaper[2].itemID == 3, "rank 2 is undercut by rank 3 as well")
assert(cheaper[3] == nil, "the top rank has nothing above it")

cheaper = Check.CheaperHigherRanks({
    { itemID = 1, name = "Zeal", rank = 1, price = 200 },
    { itemID = 2, name = "Zeal", rank = 2, price = 200 },
    { itemID = 3, name = "Zeal", rank = 3, price = 900 },
})
assert(cheaper[1].itemID == 2, "at an equal price the higher rank is the better buy")
assert(cheaper[2] == nil, "a pricier higher rank is the normal order of things")

-- ─── Reading the browse results ──────────────────────────────────────────────

Browse({ [1] = 500, [3] = 200, [4] = 500, [5] = 100, [6] = 50, [7] = 400, [8] = 300 })
assert(Check:CheaperRankFor(1).rank == 3, "rank 3 undercuts rank 1")
assert(Check:CheaperRankFor(4) == nil, "old expansion items are left alone")
assert(Check:CheaperRankFor(6) == nil, "an item with no rank has nothing to compare")
assert(Check:CheaperRankFor(7).itemID == 8, "crafted quality counts, and a rank icon in the name must not split siblings")

Browse({ [1] = 500, [3] = 0 })
assert(Check:CheaperRankFor(1) == nil, "a rank with nothing listed has no price to beat")

-- Item data arrives after the rows are first drawn, so an early "nothing cheaper"
-- must not outlive the load.
Browse({ [1] = 500, [3] = 200 })
items[3].expansion = nil
assert(Check:CheaperRankFor(1) == nil, "an item whose data has not loaded cannot be judged yet")
items[3].expansion = CURRENT
now = now + 1
assert(Check:CheaperRankFor(1).rank == 3, "once the data lands the answer must be worked out again")

print("RankPriceCheck: all checks passed")
