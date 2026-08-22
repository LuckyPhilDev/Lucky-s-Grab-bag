-- Lucky's Grab-bag: Auction House search for profession quest turn-in items
LuckyGrabbag = LuckyGrabbag or {}

LuckyGrabbag.QuestShopping = {}

local PROFESSION_TAG_ID = 267
local MAX_OBJECTIVES    = 20
local CALLER_ID         = "Lucky's Grab-bag"

local db
local button
local wanted = {}
local nextIndex = 1
local searched = false
local signature = ""
local awaiting   -- a quote asked for but not yet priced
local quote      -- the server's firm price, waiting on a click to confirm

local DevLog = LuckyGrabbag.Logger("QuestShopping")

-- ─── Reading the quest log ───────────────────────────────────────────────────

-- A line reads "0/1 Dawn Crystal |A:professions-icon-quality-12-tier1-questobjective:14:26:0:1|a".
-- Atlas markup cannot occur in a real item name, so stripping it leaves the
-- Auction House search term, in any locale.
local function ItemNameFrom(text)
    local name = text:gsub("^%s*%d+%s*/%s*%d+%s*", "")
    name = name:gsub("|A.-|a", "")
    return (name:match("^%s*(.-)%s*$"))
end

-- Crafting quality the quest asks for, taken from the atlas that draws the icon.
-- Blizzard spells that atlas several ways and does not keep the case consistent
-- between them, so the match is lowercased and allows for the "12" pair used by
-- items that come in two qualities rather than three. Nil widens the search
-- rather than filtering on a guess.
local function TierFrom(text)
    local atlas = text:lower()
    local tier = atlas:match("quality%-12%-tier(%d)") or atlas:match("quality%-tier(%d)")
    if not tier then
        DevLog("No quality read from: " .. (text:gsub("|", "||")))
        return nil
    end
    return tonumber(tier)
end

local function Collect()
    local found = {}
    for entry = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(entry)
        local tag = info and not info.isHeader and C_QuestLog.GetQuestTagInfo(info.questID)
        if tag and tag.tagID == PROFESSION_TAG_ID then
            for objective = 1, MAX_OBJECTIVES do
                local text, objectiveType, finished, fulfilled, required =
                    GetQuestObjectiveInfo(info.questID, objective, false)
                if not text then break end
                if objectiveType == "item" and not finished then
                    local item = {
                        quest   = info.title,
                        text    = text,
                        name    = ItemNameFrom(text),
                        tier    = TierFrom(text),
                        missing = (required or 1) - (fulfilled or 0),
                    }
                    table.insert(found, item)
                    DevLog(info.title .. " needs " .. item.missing .. "x " .. item.name ..
                        " at tier " .. tostring(item.tier))
                end
            end
        end
    end
    return found
end

local function Signature(items)
    local parts = {}
    for _, item in ipairs(items) do
        table.insert(parts, item.name .. tostring(item.tier) .. item.missing)
    end
    return table.concat(parts, ";")
end

-- ─── Searching ───────────────────────────────────────────────────────────────

-- Auctionator searches an exact name at an exact crafting quality, and takes the
-- whole list in one go. Blizzard's own browse filters cover item rarity but not
-- crafting quality, so without Auctionator the best on offer is one name at a time.
local function HasAuctionator()
    return Auctionator ~= nil and Auctionator.API ~= nil and Auctionator.API.v1 ~= nil
        and Auctionator.API.v1.MultiSearchAdvanced ~= nil
end

local function AuctionatorSearch()
    local terms = {}
    for _, item in ipairs(wanted) do
        table.insert(terms, {
            searchString = item.name,
            categoryKey  = "",
            isExact      = true,
            tier         = item.tier,
            quantity     = item.missing,
        })
    end
    Auctionator.API.v1.MultiSearchAdvanced(CALLER_ID, terms)
end

local function NativeSearch(name)
    if AuctionHouseFrame:SetSearchText(name) then ---@diagnostic disable-line: undefined-global
        AuctionHouseFrame.SearchBar:StartSearch() ---@diagnostic disable-line: undefined-global
        return
    end
    C_AuctionHouse.SendBrowseQuery({
        searchString     = name,
        sorts            = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } },
        filters          = {},
        itemClassFilters = {},
    })
end

-- ─── Buying ──────────────────────────────────────────────────────────────────

-- Blizzard prices a commodity purchase in two stages: ask for a quote, then
-- confirm the exact total it answers with. One click each, so the price is always
-- on screen before any gold moves, and a quote that goes stale is thrown away
-- rather than confirmed blind.
local function Say(message)
    print(LuckyGrabbag.Strings.addon.prefix .. " " .. message)
end

local function Describe(quantity, name)
    return quantity .. "x " .. name
end

-- Auctionator's result rows are the only place the searched item's id is on offer,
-- which is where CraftSim reads it from too. Matching on name and quality rather
-- than taking the top row means a slow search cannot sell us the wrong thing.
local function ListedItemID(item)
    local listing = AuctionatorShoppingFrame and AuctionatorShoppingFrame.ResultsListing ---@diagnostic disable-line: undefined-global
    local provider = listing and listing.dataProvider
    if not provider then return nil end

    for index = 1, provider:GetCount() do
        local row = provider:GetEntryAt(index)
        local itemID = row and row.itemKey and row.itemKey.itemID
        if itemID and C_Item.GetItemNameByID(itemID) == item.name
            and (item.tier == nil
                or C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID) == item.tier) then
            return itemID, row.purchaseQuantity
        end
    end
end

local function CancelQuote()
    if (awaiting or quote) and LuckyGrabbag.Quickbuy:IsAuctionHouseOpen() then
        C_AuctionHouse.CancelCommoditiesPurchase()
    end
    awaiting, quote = nil, nil
end

-- COMMODITY_PRICE_UPDATED carries the unit and total price, not the item, so the
-- pending request is what says which item was priced.
local function OnCommodityEvent(event, unitPrice, totalPrice)
    local S = LuckyGrabbag.Strings.questShopping

    if event == "COMMODITY_PRICE_UPDATED" then
        if not awaiting then return end
        quote = {
            itemID     = awaiting.itemID,
            quantity   = awaiting.quantity,
            name       = awaiting.name,
            totalPrice = totalPrice or (unitPrice or 0) * awaiting.quantity,
        }
        awaiting = nil
        Say(S.priced:format(Describe(quote.quantity, quote.name),
            GetMoneyString(quote.totalPrice, true)))

    elseif event == "COMMODITY_PRICE_UNAVAILABLE" then
        Say(S.priceUnavailable:format(awaiting and awaiting.name or ""))
        CancelQuote()

    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" or event == "COMMODITY_PURCHASE_FAILED" then
        awaiting, quote = nil, nil
    end
end

local function RequestQuote()
    local item = wanted[1]
    local itemID, offered = ListedItemID(item)
    if not itemID then
        Say(LuckyGrabbag.Strings.questShopping.noListing:format(item.name))
        return false
    end

    local quantity = math.min(item.missing, offered or item.missing)
    awaiting = { itemID = itemID, quantity = quantity, name = item.name }
    DevLog("Asking for a price on " .. Describe(quantity, item.name))
    C_AuctionHouse.StartCommoditiesPurchase(itemID, quantity)
    return true
end

local function ConfirmQuote()
    local S = LuckyGrabbag.Strings.questShopping
    local description = Describe(quote.quantity, quote.name)

    if quote.totalPrice > GetMoney() then
        Say(S.notEnoughGold:format(description))
        CancelQuote()
        return
    end

    DevLog("Confirming " .. description)
    C_AuctionHouse.ConfirmCommoditiesPurchase(quote.itemID, quote.quantity)
    awaiting, quote = nil, nil
end

-- ponytail: without Auctionator it is one item per click, cycling. A dropdown is
-- four times the code for a list that is nearly always one line long.
local function OnClick()
    if #wanted == 0 then return end

    if HasAuctionator() then
        if quote then
            ConfirmQuote()
        elseif awaiting then
            DevLog("Still waiting on a price")
        elseif searched then
            -- Pricing only ever follows a search this button ran, so a stray click
            -- at a freshly opened Auction House cannot start a purchase.
            if not RequestQuote() then
                AuctionatorSearch()
            end
        else
            DevLog("Sending " .. #wanted .. " item(s) to Auctionator")
            AuctionatorSearch()
            searched = true
        end
        return
    end

    if nextIndex > #wanted then nextIndex = 1 end
    local item = wanted[nextIndex]
    nextIndex = nextIndex + 1
    DevLog("Searching for " .. item.name)
    NativeSearch(item.name)
end

-- ─── Button ──────────────────────────────────────────────────────────────────

local function BuildTooltip()
    local S = LuckyGrabbag.Strings.questShopping
    GameTooltip:SetText(S.tooltip)
    for _, item in ipairs(wanted) do
        -- The raw objective text is used verbatim so the quality icon renders.
        GameTooltip:AddLine(item.text, 0.91, 0.86, 0.78)
    end
    local hint
    if HasAuctionator() then
        if quote then
            hint = S.tooltipConfirm:format(Describe(quote.quantity, quote.name),
                GetMoneyString(quote.totalPrice, true))
        elseif searched then
            hint = S.tooltipPrice
        else
            hint = S.tooltipAuctionator
        end
    elseif #wanted > 1 then
        hint = S.tooltipCycle
    end
    if hint then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(hint, 0.54, 0.49, 0.42)
    end
end

local function CreateButton()
    if button then return end

    button = LuckyGrabbag.CreateIconButton({
        parent  = LuckyGrabbag.Quickbuy:GetContainer(),
        texture = "Interface\\Icons\\INV_Scroll_11",
        tooltip = BuildTooltip,
    })
    button:SetScript("OnClick", OnClick)

    LuckyGrabbag.Quickbuy:GetContainer():RegisterDraggable(button)
end

local function AnchorButton()
    local above = LuckyGrabbag.Quickbuy:GetLowestButton()
    button:ClearAllPoints()
    if above then
        button:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -5)
    else
        button:SetPoint("TOPLEFT", LuckyGrabbag.Quickbuy:GetContainer(), "TOPLEFT", 0, 0)
    end
end

-- ─── Public API ──────────────────────────────────────────────────────────────

function LuckyGrabbag.QuestShopping:ApplySetting()
    if not db then return end

    local active = db.questShopping and LuckyGrabbag.Quickbuy:IsAuctionHouseOpen()
    wanted = active and Collect() or {}

    -- The quest log ticks over constantly, so only a real change in what is owed
    -- rewinds the cycle or drops back out of buying. Buying one of a stack does
    -- change it, which is what puts the smaller shortfall into the next search.
    local current = Signature(wanted)
    if current ~= signature then
        signature = current
        nextIndex = 1
        searched = false
        CancelQuote()
    end

    if #wanted > 0 then
        CreateButton()
        AnchorButton()
        button:Show()
    elseif button then
        button:Hide()
    end
end

function LuckyGrabbag.QuestShopping:GetWanted()
    return wanted
end

function LuckyGrabbag.QuestShopping:GetButton()
    return button
end

-- ─── Init ────────────────────────────────────────────────────────────────────

function LuckyGrabbag.QuestShopping:Init(database)
    db = database

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:RegisterEvent("COMMODITY_PRICE_UPDATED")
    eventFrame:RegisterEvent("COMMODITY_PRICE_UNAVAILABLE")
    eventFrame:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
    eventFrame:RegisterEvent("COMMODITY_PURCHASE_FAILED")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "QUEST_LOG_UPDATE" then
            if LuckyGrabbag.Quickbuy:IsAuctionHouseOpen() then
                LuckyGrabbag.QuestShopping:ApplySetting()
            end
        else
            OnCommodityEvent(event, ...)
        end
    end)
end
