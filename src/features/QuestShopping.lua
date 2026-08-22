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
local bought = {}  -- bought since the quest log last moved, so clicks walk on
local pendingKey   -- what a confirmed purchase was for, until it settles
local standDown    -- the whole list has been bought, so the button retires

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

local function KeyFor(item)
    return item.name .. tostring(item.tier)
end

-- Buying does not show up in the quest log straight away, so without a record of
-- what has already gone through, click after click would keep buying the first
-- item on the list. Anything bought steps aside until the log catches up.
local function NextWanted()
    for _, item in ipairs(wanted) do
        if not bought[KeyFor(item)] then return item end
    end
end

local function RequestQuote()
    local item = NextWanted()
    if not item then
        DevLog("Everything on the list has been bought once already")
        return false
    end

    local itemID, offered = ListedItemID(item)
    if not itemID then
        Say(LuckyGrabbag.Strings.questShopping.noListing:format(item.name))
        return false
    end

    local quantity = math.min(item.missing, offered or item.missing)
    awaiting = { itemID = itemID, quantity = quantity, name = item.name, key = KeyFor(item) }
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
    pendingKey = quote.key
    bought[quote.key] = true
    C_AuctionHouse.ConfirmCommoditiesPurchase(quote.itemID, quote.quantity)
    awaiting, quote = nil, nil
end

-- Auctionator names the list this button drives after the caller, so the same name
-- it was created under is the one to take away again.
local function DeleteList()
    local manager = Auctionator and Auctionator.Shopping and Auctionator.Shopping.ListManager
    if not manager then return end

    local listName = CALLER_ID .. " (" .. (AUCTIONATOR_L_TEMPORARY_LOWER_CASE or "temporary") .. ")" ---@diagnostic disable-line: undefined-global
    if manager:GetIndexForName(listName) then
        DevLog("Deleting " .. listName)
        manager:Delete(listName)
    end
end

-- Once everything owed has been through the till, the list and the button both go
-- away until the Auction House is opened afresh. A button that cannot be clicked
-- is a purchase that cannot be made twice.
local function Finish()
    standDown = true
    DeleteList()
    if button then button:Hide() end
    Say(LuckyGrabbag.Strings.questShopping.allBought)
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
            key        = awaiting.key,
            totalPrice = totalPrice or (unitPrice or 0) * awaiting.quantity,
        }
        awaiting = nil

        local description = Describe(quote.quantity, quote.name)
        local price = GetMoneyString(quote.totalPrice, true)

        if db.questShoppingAutoBuy then
            Say(S.buying:format(description, price))
            ConfirmQuote()
            return
        end

        Say(S.priced:format(description, price))

    elseif event == "COMMODITY_PRICE_UNAVAILABLE" then
        Say(S.priceUnavailable:format(awaiting and awaiting.name or ""))
        CancelQuote()

    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        pendingKey = nil
        awaiting, quote = nil, nil
        if not NextWanted() then Finish() end

    elseif event == "COMMODITY_PURCHASE_FAILED" then
        -- Nothing was bought, so let the next click try that item again.
        if pendingKey then bought[pendingKey] = nil end
        pendingKey = nil
        awaiting, quote = nil, nil
    end
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

-- ─── Automating the quests themselves ────────────────────────────────────────

-- The tag lookup works on any quest id, in the log or merely being offered, which
-- is what keeps this to profession quests and nothing else on the same NPC.
local function IsProfessionQuest(questID)
    local tag = questID and questID ~= 0 and C_QuestLog.GetQuestTagInfo(questID)
    return tag ~= nil and tag.tagID == PROFESSION_TAG_ID
end

local function OfferedQuestIsProfession()
    return IsProfessionQuest(GetQuestID())
end

-- Quests picked out of a gossip window this visit. An NPC reopens its gossip
-- after each selection, so without this a quest that cannot be taken, a full log
-- being the usual reason, would be selected over and over.
local gossipTried = {}

-- An NPC with a shop or a trainer tab opens gossip rather than the quest itself,
-- so the quest has to be picked off that list first. Selecting one raises the
-- QUEST_DETAIL or QUEST_PROGRESS that the handler below answers.
local function OnGossipShow()
    local function Pick(quests, select, what)
        for _, quest in ipairs(quests or {}) do
            if not gossipTried[quest.questID] and IsProfessionQuest(quest.questID) then
                gossipTried[quest.questID] = true
                DevLog("Selecting " .. what .. " quest " .. quest.questID .. " from the gossip list")
                select(quest.questID)
                return true
            end
        end
    end

    -- Finished quests first, so a weekly can be handed back and taken again in one
    -- visit rather than needing the window reopened.
    if db.professionQuestAutoTurnIn then
        local finished = {}
        for _, quest in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if quest.isComplete then table.insert(finished, quest) end
        end
        if Pick(finished, C_GossipInfo.SelectActiveQuest, "finished") then return end
    end

    if db.professionQuestAutoAccept then
        Pick(C_GossipInfo.GetAvailableQuests(), C_GossipInfo.SelectAvailableQuest, "offered")
    end
end

local function OnQuestDialog(event)
    if not (db.professionQuestAutoAccept or db.professionQuestAutoTurnIn) then return end

    local questID = GetQuestID()
    local tag = questID and questID ~= 0 and C_QuestLog.GetQuestTagInfo(questID)
    DevLog(event .. ": questID=" .. tostring(questID) ..
        " tagID=" .. tostring(tag and tag.tagID) ..
        " tagName=" .. tostring(tag and tag.tagName))

    if not OfferedQuestIsProfession() then return end
    local S = LuckyGrabbag.Strings.questShopping

    if event == "QUEST_DETAIL" then
        if db.professionQuestAutoAccept then
            DevLog("Accepting quest " .. tostring(questID))
            AcceptQuest()
        end
        return
    end

    if not db.professionQuestAutoTurnIn then return end

    if event == "QUEST_PROGRESS" then
        -- Handing over gold is a decision, not a formality.
        if GetQuestMoneyToGet() > 0 then
            Say(S.questCostsGold)
        elseif IsQuestCompletable() then
            DevLog("Completing quest " .. tostring(GetQuestID()))
            CompleteQuest()
        end

    elseif event == "QUEST_COMPLETE" then
        local choices = GetNumQuestChoices() or 0
        if choices > 1 then
            Say(S.questRewardChoice)
            return
        end
        -- Index 0 when there is nothing to choose between, 1 when there is one.
        DevLog("Taking the reward for quest " .. tostring(GetQuestID()))
        GetQuestReward(choices)
    end
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
            hint = db.questShoppingAutoBuy and S.tooltipPriceAuto or S.tooltipPrice
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
        bought = {}
        CancelQuote()
    end

    if #wanted > 0 and not standDown then
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
    eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:RegisterEvent("COMMODITY_PRICE_UPDATED")
    eventFrame:RegisterEvent("COMMODITY_PRICE_UNAVAILABLE")
    eventFrame:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
    eventFrame:RegisterEvent("COMMODITY_PURCHASE_FAILED")
    eventFrame:RegisterEvent("QUEST_DETAIL")
    eventFrame:RegisterEvent("QUEST_PROGRESS")
    eventFrame:RegisterEvent("QUEST_COMPLETE")
    eventFrame:RegisterEvent("GOSSIP_SHOW")
    eventFrame:RegisterEvent("GOSSIP_CLOSED")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "GOSSIP_SHOW" then
            if db.professionQuestAutoAccept or db.professionQuestAutoTurnIn then
                OnGossipShow()
            end
        elseif event == "GOSSIP_CLOSED" then
            gossipTried = {}
        elseif event:sub(1, 6) == "QUEST_" and event ~= "QUEST_LOG_UPDATE" then
            OnQuestDialog(event)
        elseif event == "AUCTION_HOUSE_SHOW" then
            -- A fresh visit is the one thing that puts a stood-down button back.
            -- Quickbuy's own handler runs first and would have left it hidden.
            standDown = false
            bought = {}
            LuckyGrabbag.QuestShopping:ApplySetting()
        elseif event == "QUEST_LOG_UPDATE" then
            if LuckyGrabbag.Quickbuy:IsAuctionHouseOpen() then
                LuckyGrabbag.QuestShopping:ApplySetting()
            end
        else
            OnCommodityEvent(event, ...)
        end
    end)
end
