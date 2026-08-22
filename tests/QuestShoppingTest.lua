-- luacheck: globals CreateFrame GameTooltip C_QuestLog GetQuestObjectiveInfo
-- luacheck: globals AuctionHouseFrame C_AuctionHouse Enum LuckyStrings LuckyGrabbag print
-- luacheck: globals Auctionator AuctionatorShoppingFrame C_Item C_TradeSkillUI
-- luacheck: globals GetMoney GetMoneyString GetQuestID IsQuestCompletable
-- luacheck: globals GetNumQuestChoices GetQuestMoneyToGet AcceptQuest CompleteQuest
-- luacheck: globals GetQuestReward C_GossipInfo IsShiftKeyDown

-- Covers features/QuestShopping.lua: which quests count as shopping-worthy, the
-- search term and crafting quality recovered from an objective line, and the
-- two-stage commodity purchase. Blizzard prices a commodity before it sells it,
-- so the buy path has to ask, wait, and only then confirm, and must never confirm
-- a quote it did not ask for.
--
-- Run from the addon root: lua tests/QuestShoppingTest.lua

local PROFESSION = 267

-- Exactly as the quest log sends it, lowercase and all.
local ATLAS_QUEST = "|A:professions-icon-quality-12-tier1-questobjective:14:26:0:1|a"
local ATLAS_CHAT  = "|A:Professions-ChatIcon-Quality-Tier2:17:15::1|a"
local ATLAS_SMALL = "|A:Professions-Icon-Quality-Tier3-Small:17:17|a"

-- ─── Stubbed world ───────────────────────────────────────────────────────────

local quests = {}
local searches = {}

C_QuestLog = {
    GetNumQuestLogEntries = function() return #quests end,
    GetInfo = function(index)
        local quest = quests[index]
        if quest then
            return { questID = index, title = quest.title, isHeader = quest.isHeader }
        end
    end,
    GetQuestTagInfo = function(questID)
        local tagID = quests[questID] and quests[questID].tagID
        if tagID then return { tagID = tagID, tagName = "Professions" } end
    end,
}

function GetQuestObjectiveInfo(questID, index)
    local objective = quests[questID] and quests[questID].objectives
        and quests[questID].objectives[index]
    if not objective then return nil end
    return objective[1], objective[2], objective[3], objective[4], objective[5]
end

AuctionHouseFrame = {
    SetSearchText = function(_, text) table.insert(searches, text) return true end,
    SearchBar = { StartSearch = function() end },
}

Enum = { AuctionHouseSortOrder = { Price = 0 } }

-- Two qualities of one reagent, so a tier mismatch has something to be wrong about.
local items = {
    [1001] = { name = "Dawn Crystal", tier = 1 },
    [1002] = { name = "Dawn Crystal", tier = 2 },
    [1003] = { name = "Weavercloth" },
}

C_Item = { GetItemNameByID = function(itemID) return items[itemID] and items[itemID].name end }
C_TradeSkillUI = {
    GetItemReagentQualityByItemInfo = function(itemID) return items[itemID] and items[itemID].tier end,
}

local money = 1000000
function GetMoney() return money end
function GetMoneyString(amount) return amount .. "c" end

local ah = { started = nil, confirmed = nil, cancelled = 0 }
C_AuctionHouse = {
    SendBrowseQuery = function() error("should have used the search box") end,
    StartCommoditiesPurchase = function(itemID, quantity) ah.started = { itemID, quantity } end,
    ConfirmCommoditiesPurchase = function(itemID, quantity) ah.confirmed = { itemID, quantity } end,
    CancelCommoditiesPurchase = function() ah.cancelled = ah.cancelled + 1 end,
}

local rows = {}
AuctionatorShoppingFrame = {
    ResultsListing = {
        dataProvider = {
            GetCount = function() return #rows end,
            GetEntryAt = function(_, index) return rows[index] end,
        },
    },
}

local function Row(itemID, purchaseQuantity)
    return { itemKey = { itemID = itemID }, purchaseQuantity = purchaseQuantity }
end

local function Widget()
    local w = { shown = false, points = {}, scripts = {} }
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:IsShown() return self.shown end
    function w:SetSize() end
    function w:SetScript(name, fn) self.scripts[name] = fn end
    function w:ClearAllPoints() self.points = {} end
    function w:SetPoint(...) self.points = { ... } end
    function w:SetNormalTexture() end
    function w:SetHighlightTexture() end
    function w:GetHighlightTexture() return { SetBlendMode = function() end } end
    function w:RegisterEvent() end
    function w:RegisterDraggable() end
    return w
end

-- Only Init calls CreateFrame, so the last one made is the event frame.
local eventFrame
function CreateFrame()
    eventFrame = Widget()
    return eventFrame
end

local function Fire(event, ...)
    eventFrame.scripts.OnEvent(eventFrame, event, ...)
end

GameTooltip = {
    lines = {},
    SetText = function(self, text) self.lines = { text } end,
    AddLine = function(self, text) table.insert(self.lines, text) end,
}

local realPrint = print
local printed = {}
function print(message) table.insert(printed, message) end

-- The quest giver's dialog, as the accept and hand-in path sees it.
local dialog = { questID = 0, completable = true, choices = 0, moneyToGet = 0,
                 accepted = 0, completed = 0, rewarded = nil }

function GetQuestID() return dialog.questID end
function IsQuestCompletable() return dialog.completable end
function GetNumQuestChoices() return dialog.choices end
function GetQuestMoneyToGet() return dialog.moneyToGet end
function AcceptQuest() dialog.accepted = dialog.accepted + 1 end
function CompleteQuest() dialog.completed = dialog.completed + 1 end
function GetQuestReward(index) dialog.rewarded = index end

local shiftHeld = false
function IsShiftKeyDown() return shiftHeld end

-- The gossip window an NPC with a shop or a trainer tab opens instead.
local gossip = { available = {}, active = {}, selected = {} }
C_GossipInfo = {
    GetAvailableQuests = function() return gossip.available end,
    GetActiveQuests    = function() return gossip.active end,
    SelectAvailableQuest = function(questID) table.insert(gossip.selected, "available:" .. questID) end,
    SelectActiveQuest    = function(questID) table.insert(gossip.selected, "active:" .. questID) end,
}

-- ─── Load ────────────────────────────────────────────────────────────────────

LuckyStrings = { New = function(_, tbl) return tbl end }
dofile("src/Strings.lua")

LuckyGrabbag.Logger = function() return function() end end
LuckyGrabbag.CreateIconButton = function(opts)
    local btn = Widget()
    btn.tooltip = opts.tooltip
    return btn
end

local container = Widget()
local lowestButton
LuckyGrabbag.Quickbuy = {
    GetContainer        = function() return container end,
    GetLowestButton     = function() return lowestButton end,
    IsAuctionHouseOpen  = function() return true end,
}

dofile("src/features/QuestShopping.lua")

local S = LuckyGrabbag.Strings.questShopping
local QS = LuckyGrabbag.QuestShopping
local db = { questShopping = true }
QS:Init(db)

local function Names()
    local names = {}
    for _, item in ipairs(QS:GetWanted()) do table.insert(names, item.name) end
    return names
end

local function Click() QS:GetButton().scripts.OnClick() end

local function Hint()
    GameTooltip.lines = {}
    QS:GetButton().tooltip()
    return GameTooltip.lines[#GameTooltip.lines]
end

-- ─── Which quests count ──────────────────────────────────────────────────────

quests = {
    { title = "A Ray of Sunlight", tagID = PROFESSION,
      objectives = { { "0/1 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 1 } } },
    { title = "Lost Animals",
      objectives = { { "0/6 Stray cat found", "item", false, 0, 6 } } },
    { title = "Professions header", isHeader = true, tagID = PROFESSION },
    { title = "Tailoring Services Requested", tagID = PROFESSION,
      objectives = { { "3/3 Weavercloth", "item", true, 3, 3 } } },
    { title = "Fieldwork", tagID = PROFESSION,
      objectives = { { "0/1 Speak to Shallisya", "monster", false, 0, 1 } } },
}
QS:ApplySetting()

local names = Names()
assert(#names == 1, "only the unfinished profession item objective should count, got " .. #names)
assert(names[1] == "Dawn Crystal", "expected Dawn Crystal, got " .. tostring(names[1]))
assert(QS:GetWanted()[1].missing == 1, "should still need one")
assert(QS:GetButton().shown, "with something to buy the button should show")

-- ─── Reading the name and the quality off the line ───────────────────────────

quests = {
    { title = "Quest log spelling", tagID = PROFESSION,
      objectives = { { "0/1 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 1 } } },
    { title = "Chat icon spelling", tagID = PROFESSION,
      objectives = { { "0/1 Dawn Crystal " .. ATLAS_CHAT, "item", false, 0, 1 } } },
    { title = "Small icon spelling", tagID = PROFESSION,
      objectives = { { "0/1 Dawn Crystal " .. ATLAS_SMALL, "item", false, 0, 1 } } },
    { title = "No icon at all", tagID = PROFESSION,
      objectives = { { "5/10 Weavercloth", "item", false, 5, 10 } } },
    { title = "Non-English name", tagID = PROFESSION,
      objectives = { { "0/1 Кристалл зари " .. ATLAS_QUEST, "item", false, 0, 1 } } },
}
QS:ApplySetting()

names = Names()
assert(names[1] == "Dawn Crystal", "the quest log's own spelling should strip, got " .. tostring(names[1]))
assert(names[4] == "Weavercloth", "a plain line should survive, got " .. tostring(names[4]))
assert(names[5] == "Кристалл зари", "a Cyrillic name should survive, got " .. tostring(names[5]))

local wanted = QS:GetWanted()
assert(wanted[1].tier == 1, "the two-quality quest atlas should read as tier 1, got " .. tostring(wanted[1].tier))
assert(wanted[2].tier == 2, "the chat icon atlas should read as tier 2, got " .. tostring(wanted[2].tier))
assert(wanted[3].tier == 3, "the small icon atlas should read as tier 3, got " .. tostring(wanted[3].tier))
assert(wanted[4].tier == nil, "a line with no icon asks for no particular quality")
assert(wanted[5].tier == 1, "a non-English line should still give up its quality")
assert(wanted[4].missing == 5, "10 required less 5 held is 5 short")

-- ─── Clicking cycles when Auctionator is absent ──────────────────────────────

quests = {
    { title = "A Ray of Sunlight", tagID = PROFESSION,
      objectives = { { "0/1 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 1 } } },
    { title = "Tailoring Services Requested", tagID = PROFESSION,
      objectives = { { "5/10 Weavercloth", "item", false, 5, 10 } } },
}
QS:ApplySetting()

searches = {}
Click()
Click()
Click()
assert(table.concat(searches, "|") == "Dawn Crystal|Weavercloth|Dawn Crystal",
    "clicks should walk the list and wrap, got " .. table.concat(searches, "|"))

-- The tooltip shows the raw objective text, so the quality icon renders in game.
GameTooltip.lines = {}
QS:GetButton().tooltip()
assert(GameTooltip.lines[2] == "0/1 Dawn Crystal " .. ATLAS_QUEST,
    "the tooltip should carry the unstripped line, got " .. tostring(GameTooltip.lines[2]))

-- ─── Stacking under the other Auction House buttons ──────────────────────────

QS:ApplySetting()
assert(QS:GetButton().points[2] == container,
    "with no other buttons shown it should sit at the top of the group")

lowestButton = Widget()
QS:ApplySetting()
assert(QS:GetButton().points[2] == lowestButton,
    "it should hang below whichever button is already showing")
lowestButton = nil

-- ─── Auctionator takes the whole list at once ────────────────────────────────

local sent
local lists = {}
Auctionator = {
    API = { v1 = {
        MultiSearchAdvanced = function(callerID, terms)
            sent = { callerID = callerID, terms = terms }
            lists[callerID .. " (temporary)"] = true
        end,
    } },
    Shopping = { ListManager = {
        GetIndexForName = function(_, name) return lists[name] and 1 or nil end,
        Delete = function(_, name) lists[name] = nil end,
    } },
}

QS:ApplySetting()

searches = {}
Click()
assert(#searches == 0, "with Auctionator present the search box should be left alone")
assert(sent and #sent.terms == 2,
    "one click should send every outstanding item, got " .. tostring(sent and #sent.terms))
assert(sent.terms[1].searchString == "Dawn Crystal", "the name should go over stripped of its icon")
assert(sent.terms[1].isExact and sent.terms[1].tier == 1 and sent.terms[1].quantity == 1,
    "the crystal should go over exact, tier 1, and one short")
assert(sent.terms[2].tier == nil and sent.terms[2].quantity == 5,
    "a line with no quality should carry no tier filter and still know the shortfall")

-- ─── Asking for a price, then confirming it ──────────────────────────────────

quests = {
    { title = "A Ray of Sunlight", tagID = PROFESSION,
      objectives = { { "0/2 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 2 } } },
}
-- The wrong quality sits above the right one, so taking the top row would be wrong.
rows = { Row(1002, 2), Row(1001, 2) }
QS:ApplySetting()

ah.started, ah.confirmed, sent = nil, nil, nil
assert(Hint() == S.tooltipAuctionator, "a fresh list should offer the search")

Click()
assert(ah.started == nil, "the first click must search, never start a purchase")
assert(sent ~= nil, "the first click should send the list")
assert(Hint() == S.tooltipPrice, "after searching the next click should price up")

Click()
assert(ah.started ~= nil, "the second click should ask the Auction House for a price")
assert(ah.started[1] == 1001, "it should price the tier the quest asked for, got " .. tostring(ah.started[1]))
assert(ah.started[2] == 2, "it should price both that are owed, got " .. tostring(ah.started[2]))
assert(ah.confirmed == nil, "asking a price must not buy anything")

-- A click while the server has not answered yet must not buy either.
Click()
assert(ah.confirmed == nil, "a click while waiting on the price must not buy")

Fire("COMMODITY_PRICE_UPDATED", 500, 1000)
assert(Hint() == S.tooltipConfirm:format("2x Dawn Crystal", "1000c"),
    "once priced the tooltip should name the item and the total, got " .. tostring(Hint()))

Click()
assert(ah.confirmed ~= nil, "the click after the price should buy")
assert(ah.confirmed[1] == 1001 and ah.confirmed[2] == 2,
    "it should buy exactly what was priced")
Fire("COMMODITY_PURCHASE_SUCCEEDED")

-- ─── When it must not buy ────────────────────────────────────────────────────

-- A price the player cannot afford is dropped, not confirmed.
quests[1].objectives[1] = { "0/4 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 4 }
QS:ApplySetting()
Click()
Click()
ah.confirmed = nil
money = 10
Fire("COMMODITY_PRICE_UPDATED", 500, 1000)
Click()
assert(ah.confirmed == nil, "a total beyond the player's gold must not be confirmed")
money = 1000000

-- A quote the Auction House withdraws is cancelled, and a later click starts over.
quests[1].objectives[1] = { "0/5 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 5 }
QS:ApplySetting()
Click()
Click()
local cancelledBefore = ah.cancelled
Fire("COMMODITY_PRICE_UNAVAILABLE")
assert(ah.cancelled > cancelledBefore, "an unavailable price should be cancelled")
ah.confirmed = nil
Click()
assert(ah.confirmed == nil, "with no live quote a click must not buy")

-- A request left in flight blocks further clicks until the server answers, so
-- clear it before the next case rather than letting it swallow them.
Fire("COMMODITY_PURCHASE_FAILED")

-- Nothing listed at the quality the quest wants: search again rather than buy.
rows = { Row(1002, 2) }
quests[1].objectives[1] = { "0/6 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 6 }
QS:ApplySetting()
ah.started, sent = nil, nil
Click()
Click()
assert(ah.started == nil, "with no matching listing nothing should be priced")
assert(sent ~= nil, "it should fall back to searching again")
rows = { Row(1002, 2), Row(1001, 2) }

-- A changed shortfall drops any live quote, so the next click re-searches.
quests[1].objectives[1] = { "0/7 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 7 }
QS:ApplySetting()
Click()
Click()
Fire("COMMODITY_PRICE_UPDATED", 500, 1000)
quests[1].objectives[1] = { "1/7 Dawn Crystal " .. ATLAS_QUEST, "item", false, 1, 7 }
QS:ApplySetting()
ah.confirmed, sent = nil, nil
Click()
assert(ah.confirmed == nil, "a stale quote must not survive a change in what is owed")
assert(sent.terms[1].quantity == 6, "the new search should ask only for what is still owed")

-- ─── Buying without the confirming click ─────────────────────────────────────

db.questShoppingAutoBuy = true
-- A different shortfall, so the button starts from a clean search state.
quests[1].objectives[1] = { "0/3 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 3 }
QS:ApplySetting()
assert(Hint() == S.tooltipAuctionator, "a fresh list should still offer the search first")

ah.started, ah.confirmed = nil, nil
Click()
assert(ah.started == nil and ah.confirmed == nil, "the first click must still only search")
assert(Hint() == S.tooltipPriceAuto, "the hint should warn that the next click buys outright")

Click()
assert(ah.started ~= nil, "the second click should still ask for a price")
assert(ah.confirmed == nil, "nothing is bought until the price comes back")

Fire("COMMODITY_PRICE_UPDATED", 500, 500)
assert(ah.confirmed ~= nil, "the price arriving should buy without another click")
assert(ah.confirmed[1] == 1001, "it should still buy the quality the quest asked for")

-- The gold check survives the skipped confirmation.
QS:ApplySetting()
Click()
ah.confirmed = nil
money = 10
Fire("COMMODITY_PRICE_UPDATED", 500, 500)
assert(ah.confirmed == nil, "auto buying must still stop at a total the player cannot afford")
money = 1000000

db.questShoppingAutoBuy = false
Fire("COMMODITY_PURCHASE_FAILED")

-- An idle quest log tick must not throw away a live quote.
quests[1].objectives[1] = { "0/8 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 8 }
QS:ApplySetting()
Click()
Click()
Fire("COMMODITY_PRICE_UPDATED", 500, 500)
QS:ApplySetting()
ah.confirmed = nil
Click()
assert(ah.confirmed ~= nil, "an unchanged list should keep the quote alive")

-- ─── Buying walks down the list ──────────────────────────────────────────────

-- The quest log lags a purchase, so what has been bought has to step aside under
-- its own steam or every click buys the same thing again.
quests = {
    { title = "A Ray of Sunlight", tagID = PROFESSION,
      objectives = { { "0/2 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 2 } } },
    { title = "Tailoring Services Requested", tagID = PROFESSION,
      objectives = { { "0/5 Weavercloth", "item", false, 0, 5 } } },
}
rows = { Row(1001, 2), Row(1003, 5) }
QS:ApplySetting()

Click()                                     -- search
Click()                                     -- price the crystal
assert(ah.started[1] == 1001, "the first item should be priced first")
Fire("COMMODITY_PRICE_UPDATED", 500, 1000)
Click()                                     -- buy it
assert(ah.confirmed[1] == 1001, "the first item should be the one bought")
Fire("COMMODITY_PURCHASE_SUCCEEDED")

-- The quest log has not caught up, but the next click must move on regardless.
Click()
assert(ah.started[1] == 1003,
    "after buying, the next click should price the second item, got " .. tostring(ah.started[1]))
Fire("COMMODITY_PRICE_UPDATED", 100, 500)
Click()
assert(ah.confirmed[1] == 1003, "the second item should be the one bought now")
Fire("COMMODITY_PURCHASE_SUCCEEDED")

-- With the whole list bought the button stands down and takes its list with it.
assert(not QS:GetButton().shown, "the button should go away once everything is bought")
assert(lists["Lucky's Grab-bag (temporary)"] == nil, "the shopping list should be deleted too")

-- A quest log tick must not bring it back, only a fresh visit to the Auction House.
QS:ApplySetting()
assert(not QS:GetButton().shown, "a quest log tick should not revive the button")

Fire("AUCTION_HOUSE_SHOW")
assert(QS:GetButton().shown, "reopening the Auction House should bring the button back")

-- A purchase that fails leaves its item available to try again.
QS:ApplySetting()
quests[1].objectives[1] = { "0/3 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 3 }
QS:ApplySetting()
Click()
Click()
Fire("COMMODITY_PRICE_UPDATED", 500, 1500)
Click()
Fire("COMMODITY_PURCHASE_FAILED")
ah.started = nil
Click()
assert(ah.started and ah.started[1] == 1001,
    "a failed purchase should leave that item next in line, got " .. tostring(ah.started and ah.started[1]))
Fire("COMMODITY_PURCHASE_FAILED")

Auctionator = nil

-- ─── Nothing to buy, and switched off ────────────────────────────────────────

quests = {}
QS:ApplySetting()
assert(not QS:GetButton().shown, "with an empty quest log the button should hide")

quests = {
    { title = "A Ray of Sunlight", tagID = PROFESSION,
      objectives = { { "0/1 Dawn Crystal " .. ATLAS_QUEST, "item", false, 0, 1 } } },
}
db.questShopping = false
QS:ApplySetting()
assert(not QS:GetButton().shown, "disabled, the button should stay hidden")

-- ─── Accepting and handing in, profession quests only ───────────────────────

quests = {
    { title = "A Ray of Sunlight", tagID = PROFESSION },
    { title = "Lost Animals" },
}
db.questShopping = true

local function Offer(event, questID)
    dialog.questID = questID
    Fire(event)
end

-- Switched off, the dialogs are left alone.
dialog.accepted, dialog.completed = 0, 0
Offer("QUEST_DETAIL", 1)
Offer("QUEST_PROGRESS", 1)
assert(dialog.accepted == 0 and dialog.completed == 0, "off, it should touch nothing")

db.professionQuestAutoAccept = true
Offer("QUEST_DETAIL", 1)
assert(dialog.accepted == 1, "a profession quest should be accepted")

Offer("QUEST_DETAIL", 2)
assert(dialog.accepted == 1, "an ordinary quest must be left alone")

-- Accepting and handing in are separate switches.
Offer("QUEST_PROGRESS", 1)
assert(dialog.completed == 0, "handing in is off, so nothing should be completed")

db.professionQuestAutoTurnIn = true
Offer("QUEST_PROGRESS", 1)
assert(dialog.completed == 1, "a profession quest should be handed in")

Offer("QUEST_PROGRESS", 2)
assert(dialog.completed == 1, "an ordinary quest must still be left alone")

-- One that wants gold, or that has something to choose, stays the player's call.
dialog.moneyToGet = 5000
Offer("QUEST_PROGRESS", 1)
assert(dialog.completed == 1, "a quest asking for gold must not be handed in")
dialog.moneyToGet = 0

dialog.completable = false
Offer("QUEST_PROGRESS", 1)
assert(dialog.completed == 1, "a quest you cannot yet complete must not be forced")
dialog.completable = true

dialog.choices = 2
Offer("QUEST_COMPLETE", 1)
assert(dialog.rewarded == nil, "a choice of rewards must be left to the player")

dialog.choices = 1
Offer("QUEST_COMPLETE", 1)
assert(dialog.rewarded == 1, "a single reward should be taken at index 1")

dialog.choices, dialog.rewarded = 0, nil
Offer("QUEST_COMPLETE", 1)
assert(dialog.rewarded == 0, "no reward to choose should take index 0")

dialog.rewarded = nil
Offer("QUEST_COMPLETE", 2)
assert(dialog.rewarded == nil, "an ordinary quest's reward must not be taken")

-- ─── Picking the quest out of a gossip window ───────────────────────────────

-- quests[1] is the profession quest, quests[2] an ordinary one.
gossip.available = { { questID = 2 }, { questID = 1 } }
gossip.active = {}
gossip.selected = {}
Fire("GOSSIP_SHOW")
assert(gossip.selected[1] == "available:1",
    "it should pick the profession quest out of the list, got " .. tostring(gossip.selected[1]))
assert(#gossip.selected == 1, "one selection per gossip window is enough")

-- The NPC reopens gossip after a selection, so an untakeable quest must not loop.
Fire("GOSSIP_SHOW")
assert(#gossip.selected == 1, "a quest already tried should not be selected again")

Fire("GOSSIP_CLOSED")
Fire("GOSSIP_SHOW")
assert(#gossip.selected == 2, "a fresh visit to the NPC should try again")

-- A finished quest is handed back before a new one is taken.
gossip.selected = {}
gossip.active = { { questID = 1, isComplete = true } }
Fire("GOSSIP_CLOSED")
Fire("GOSSIP_SHOW")
assert(gossip.selected[1] == "active:1", "a finished profession quest should go first")

-- An unfinished one is left where it is.
gossip.selected = {}
gossip.active = { { questID = 1, isComplete = false } }
gossip.available = {}
Fire("GOSSIP_CLOSED")
Fire("GOSSIP_SHOW")
assert(#gossip.selected == 0, "a quest that is not finished should be left alone")

-- Ordinary quests are never touched, whichever list they are in.
gossip.active = { { questID = 2, isComplete = true } }
gossip.available = { { questID = 2 } }
Fire("GOSSIP_CLOSED")
Fire("GOSSIP_SHOW")
assert(#gossip.selected == 0, "an ordinary quest must be left alone in gossip too")

-- ─── Holding Shift stands it down ────────────────────────────────────────────

gossip.selected = {}
gossip.available = { { questID = 1 } }
gossip.active = {}
dialog.accepted, dialog.completed = 0, 0
shiftHeld = true

Fire("GOSSIP_CLOSED")
Fire("GOSSIP_SHOW")
assert(#gossip.selected == 0, "with Shift held the gossip window should be left alone")

Offer("QUEST_DETAIL", 1)
assert(dialog.accepted == 0, "with Shift held a quest should not be accepted")

Offer("QUEST_PROGRESS", 1)
assert(dialog.completed == 0, "with Shift held a quest should not be handed in")

-- Letting go puts it straight back to work.
shiftHeld = false
Offer("QUEST_DETAIL", 1)
assert(dialog.accepted == 1, "releasing Shift should accept again")

-- Switched off, gossip is left alone entirely.
db.professionQuestAutoAccept, db.professionQuestAutoTurnIn = false, false
gossip.available = { { questID = 1 } }
Fire("GOSSIP_CLOSED")
Fire("GOSSIP_SHOW")
assert(#gossip.selected == 0, "off, it should not touch the gossip window")

realPrint("QuestShopping: all checks passed")
