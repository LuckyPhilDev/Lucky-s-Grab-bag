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

-- ponytail: without Auctionator it is one item per click, cycling. A dropdown is
-- four times the code for a list that is nearly always one line long.
local function OnClick()
    if #wanted == 0 then return end

    if HasAuctionator() then
        DevLog("Sending " .. #wanted .. " item(s) to Auctionator")
        AuctionatorSearch()
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
    local hint = HasAuctionator() and S.tooltipAuctionator
        or #wanted > 1 and S.tooltipCycle
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
    nextIndex = 1

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
    eventFrame:SetScript("OnEvent", function()
        if LuckyGrabbag.Quickbuy:IsAuctionHouseOpen() then
            LuckyGrabbag.QuestShopping:ApplySetting()
        end
    end)
end
