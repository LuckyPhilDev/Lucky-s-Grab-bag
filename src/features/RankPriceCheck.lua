LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.RankPriceCheck = {}

local RankPriceCheck = LuckyGrabbag.RankPriceCheck

local WARNING_ICON_SIZE = 14
local WARNING_TEXTURE = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"
-- An inline icon's vertical offset shifts with the rest of the row's text, so the
-- text only reserves the room and a real texture is drawn over it.
local WARNING_SPACER = ("|TInterface\\Common\\spacer:%d:%d|t "):format(WARNING_ICON_SIZE, WARNING_ICON_SIZE)
local POPUP = "LUCKYGB_RANK_PRICE_CONFIRM"
local INCOMPLETE_LIFETIME = 0.5

local db
local cheaperByItemID
local expiresAt
local blizzardHooked = false
local auctionatorHooked = false

local DevLog = LuckyGrabbag.Logger("RankPriceCheck")

local function Rank(itemID)
    return C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
        or C_TradeSkillUI.GetItemCraftedQualityByItemInfo(itemID)
end

-- Blizzard bakes the rank icon into some item names and not others.
local function PlainName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    return name and (name:gsub("%s*|A.-|a", ""))
end

-- listings: { { itemID, name, rank, price }, ... }
-- Returns itemID -> the cheapest listing of the same name at a higher rank that costs no more.
function RankPriceCheck.CheaperHigherRanks(listings)
    local byName = {}
    for _, listing in ipairs(listings) do
        byName[listing.name] = byName[listing.name] or {}
        table.insert(byName[listing.name], listing)
    end

    local cheaper = {}
    for _, ranks in pairs(byName) do
        for _, low in ipairs(ranks) do
            for _, high in ipairs(ranks) do
                local best = cheaper[low.itemID]
                if high.rank > low.rank and high.price <= low.price
                    and (not best or high.price < best.price
                        or (high.price == best.price and high.rank > best.rank)) then
                    cheaper[low.itemID] = high
                end
            end
        end
    end
    return cheaper
end

-- Every rank of an item shares its name, so a name search already holds the
-- siblings and their prices: no second Auction House query is needed.
-- ponytail: compares each rank's cheapest listing, not the price of the quantity
-- being bought, and only sees ranks in the current browse results.
local function Listings()
    local listings, complete = {}, true
    local currentExpansion = GetExpansionLevel()
    for _, result in ipairs(C_AuctionHouse.GetBrowseResults()) do
        local itemID = result.itemKey.itemID
        local rank = Rank(itemID)
        if rank and result.minPrice > 0 then
            local name = PlainName(itemID)
            local expansion = select(15, C_Item.GetItemInfo(itemID))
            if not (name and expansion) then
                complete = false
            elseif expansion == currentExpansion then
                table.insert(listings, { itemID = itemID, name = name, rank = rank, price = result.minPrice })
            end
        end
    end
    return listings, complete
end

function RankPriceCheck:CheaperRankFor(itemID)
    if not cheaperByItemID or (expiresAt and GetTime() > expiresAt) then
        local listings, complete = Listings()
        cheaperByItemID = RankPriceCheck.CheaperHigherRanks(listings)
        -- Item data still loading would otherwise be cached as "nothing cheaper".
        expiresAt = not complete and GetTime() + INCOMPLETE_LIFETIME or nil
    end
    return cheaperByItemID[itemID]
end

-- Clicks pass through so the row underneath still selects.
local function WarningIcon(cell)
    if cell.luckyRankWarning then return cell.luckyRankWarning end

    local hover = CreateFrame("Frame", nil, cell)
    hover:SetSize(WARNING_ICON_SIZE, WARNING_ICON_SIZE)
    local icon = hover:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    icon:SetTexture(WARNING_TEXTURE)
    hover:EnableMouse(true)
    hover:SetMouseClickEnabled(false)
    hover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(LuckyGrabbag.Strings.rankPriceCheck.tooltip:format(
            GetMoneyString(self.cheaper.price, true)))
        GameTooltip:Show()
    end)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    cell.luckyRankWarning = hover
    return hover
end

local function FlagCell(cell, itemID)
    local cheaper = db.rankPriceFlag and itemID and cell.Text
        and RankPriceCheck:CheaperRankFor(itemID) or nil
    if not cheaper then
        if cell.luckyRankWarning then cell.luckyRankWarning:Hide() end
        return
    end

    local lead, text, leadWidth = LuckyGrabbag.EnchantStats.QualityLead(cell, cell.Text:GetText() or "")
    cell.Text:SetText(lead .. WARNING_SPACER .. text)
    local hover = WarningIcon(cell)
    hover:SetPoint("LEFT", cell.Text, "LEFT", leadWidth, 0)
    hover.cheaper = cheaper
    hover:Show()
end

local function RefreshBrowseList()
    local list = AuctionHouseFrame
        and AuctionHouseFrame.BrowseResultsFrame
        and AuctionHouseFrame.BrowseResultsFrame.ItemList
    if list and list:IsShown() and list.RefreshScrollFrame then
        list:RefreshScrollFrame()
    end
end

StaticPopupDialogs[POPUP] = {
    text         = "%s",
    button1      = YES,
    button2      = NO,
    OnAccept     = function(dialog) dialog.data() end,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
}

-- The popup has to come before Blizzard's own price dialog, and a post-hook cannot
-- hold a click back, so the Buy button's handler is wrapped rather than hooked.
local function WrapBuyButton()
    local display = AuctionHouseFrame.CommoditiesBuyFrame.BuyDisplay
    local startPurchase = display.BuyButton:GetScript("OnClick")

    display.BuyButton:SetScript("OnClick", function(button, ...)
        local itemID = display:GetItemID()
        local cheaper = db.rankPriceConfirm and itemID and RankPriceCheck:CheaperRankFor(itemID)
        if not cheaper then
            return startPurchase(button, ...)
        end

        DevLog("Rank " .. cheaper.rank .. " of item " .. itemID .. " costs no more, asking first")
        local message = LuckyGrabbag.Strings.rankPriceCheck.confirm:format(
            GetMoneyString(cheaper.price, true), GetMoneyString(display.UnitPrice:GetAmount(), true))
        local dialog = StaticPopup_Show(POPUP, message)
        if dialog then dialog.data = function() startPurchase(button) end end
    end)
end

local function HookBlizzard()
    if blizzardHooked then return end
    blizzardHooked = true
    hooksecurefunc(AuctionHouseTableCellItemDisplayMixin, "UpdateDisplay", function(cell, itemKey)
        FlagCell(cell, itemKey and itemKey.itemID)
    end)
    WrapBuyButton()
end

-- Auctionator copies the mixin's methods onto each cell as it builds them, so
-- the hook has to be in place when Auctionator loads, before any cell exists.
local function HookAuctionator()
    if auctionatorHooked or not C_AddOns.IsAddOnLoaded("Auctionator") then return end
    if not (AuctionatorItemKeyCellTemplateMixin and AuctionatorItemKeyCellTemplateMixin.Populate) then return end
    auctionatorHooked = true
    hooksecurefunc(AuctionatorItemKeyCellTemplateMixin, "Populate", function(cell, rowData)
        FlagCell(cell, rowData.itemKey and rowData.itemKey.itemID)
    end)
end

function RankPriceCheck:ApplySetting()
    RefreshBrowseList()
end

function RankPriceCheck:Init(database)
    db = database

    HookAuctionator()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    eventFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    eventFrame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
    eventFrame:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" then
            if name == "Auctionator" then HookAuctionator() end
        elseif event == "AUCTION_HOUSE_SHOW" then
            HookBlizzard()
            HookAuctionator()
        else
            cheaperByItemID = nil
            -- Blizzard may have drawn the rows before this handler ran, against the old prices.
            if db.rankPriceFlag then RefreshBrowseList() end
        end
    end)
end
