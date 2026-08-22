-- luacheck: globals CreateFrame GameTooltip C_QuestLog GetQuestObjectiveInfo
-- luacheck: globals AuctionHouseFrame C_AuctionHouse Enum LuckyStrings LuckyGrabbag print
-- luacheck: globals Auctionator

-- Covers features/QuestShopping.lua: which quests count as shopping-worthy, the
-- search term recovered from an objective line, and the crafting quality read off
-- the icon at the end of it. Blizzard draws that icon from an atlas whose name it
-- spells several ways in several cases, and the quest log's own spelling is the
-- lowercase one, so every spelling is pinned here.
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

C_AuctionHouse = { SendBrowseQuery = function() error("should have used the search box") end }
Enum = { AuctionHouseSortOrder = { Price = 0 } }

local function Widget()
    local w = { shown = false, points = {} }
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:IsShown() return self.shown end
    function w:SetSize() end
    function w:SetScript(_, fn) self.onClick = fn end
    function w:ClearAllPoints() self.points = {} end
    function w:SetPoint(...) self.points = { ... } end
    function w:SetNormalTexture() end
    function w:SetHighlightTexture() end
    function w:GetHighlightTexture() return { SetBlendMode = function() end } end
    function w:RegisterEvent() end
    function w:RegisterDraggable() end
    return w
end

function CreateFrame() return Widget() end

GameTooltip = {
    lines = {},
    SetText = function(self, text) self.lines = { text } end,
    AddLine = function(self, text) table.insert(self.lines, text) end,
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

local QS = LuckyGrabbag.QuestShopping
local db = { questShopping = true }
QS:Init(db)

local function Names()
    local names = {}
    for _, item in ipairs(QS:GetWanted()) do table.insert(names, item.name) end
    return names
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
local button = QS:GetButton()
button.onClick()
button.onClick()
button.onClick()
assert(table.concat(searches, "|") == "Dawn Crystal|Weavercloth|Dawn Crystal",
    "clicks should walk the list and wrap, got " .. table.concat(searches, "|"))

-- The tooltip shows the raw objective text, so the quality icon renders in game.
button.tooltip()
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
Auctionator = { API = { v1 = {
    MultiSearchAdvanced = function(callerID, terms) sent = { callerID = callerID, terms = terms } end,
} } }

QS:ApplySetting()

searches = {}
QS:GetButton().onClick()
assert(#searches == 0, "with Auctionator present the search box should be left alone")
assert(sent and #sent.terms == 2,
    "one click should send every outstanding item, got " .. tostring(sent and #sent.terms))
assert(sent.terms[1].searchString == "Dawn Crystal", "the name should go over stripped of its icon")
assert(sent.terms[1].isExact and sent.terms[1].tier == 1 and sent.terms[1].quantity == 1,
    "the crystal should go over exact, tier 1, and one short")
assert(sent.terms[2].tier == nil and sent.terms[2].quantity == 5,
    "a line with no quality should carry no tier filter and still know the shortfall")

GameTooltip.lines = {}
QS:GetButton().tooltip()
assert(GameTooltip.lines[#GameTooltip.lines] == LuckyGrabbag.Strings.questShopping.tooltipAuctionator,
    "the tooltip should swap the cycling hint for the Auctionator one")

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

print("QuestShopping: all checks passed")
