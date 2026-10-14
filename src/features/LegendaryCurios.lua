-- Lucky's Grab-bag: Rank 5 curios sit a tier above Epic, but Blizzard maps that
-- rarity (EpicTier2) back to Epic. Colours them Legendary instead.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.LegendaryCurios = {}

local LegendaryCurios = LuckyGrabbag.LegendaryCurios

local TOP_CURIO_RANK = 5
local CURIO_ITEM_LEVEL = 1
local RANK_LINE_SEARCH_DEPTH = 4

local db
local isTopCurioByLink = {}

local function LegendaryRGB()
    return ColorManager.GetColorDataForItemQuality(Enum.ItemQuality.Legendary).color:GetRGB()
end

local function CurioRarity(configID, entryID)
    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
    if not entryInfo then return end
    for _, conditionID in ipairs(entryInfo.conditionIDs) do
        local conditionInfo = C_Traits.GetConditionInfo(configID, conditionID, true)
        if conditionInfo and conditionInfo.traitCondAccountElementID then
            return C_DelvesUI.GetCurioRarityByTraitCondAccountElementID(conditionInfo.traitCondAccountElementID)
        end
    end
end

local function RecolorCurioOption(_, button)
    local data = button.data
    if not db.legendaryCurios or not data or not data.entryID then return end
    if CurioRarity(data.configID, data.entryID) == Enum.CurioRarity.EpicTier2 then
        button.Border:SetVertexColor(LegendaryRGB())
    end
end

local function HookCompanionUI()
    local slots = DelvesCompanionConfigurationFrame.CompanionSlots
    for _, slot in ipairs({ slots.CompanionCombatTrinketSlot, slots.CompanionUtilityTrinketSlot }) do
        ScrollUtil.AddInitializedFrameCallback(slot.OptionsList.ScrollBox, RecolorCurioOption, LegendaryCurios, true)
    end
end

local function TooltipRank(tooltip)
    for i = 2, math.min(#tooltip.lines, RANK_LINE_SEARCH_DEPTH) do
        local rank = tooltip.lines[i].leftText and tonumber(tooltip.lines[i].leftText:match("^%D*(%d+)/%d+$"))
        if rank then return rank end
    end
end

-- Curios are item level 1, which keeps max-upgraded gear ("Hero 6/6") out of
-- the rank match without depending on the client's language.
-- Only a match is cached: bags first draw before item data has loaded, and a
-- miss remembered then would stick until the next reload.
local function IsTopCurio(link)
    if isTopCurioByLink[link] then return true end
    if C_Item.GetDetailedItemLevelInfo(link) ~= CURIO_ITEM_LEVEL then return false end

    local tooltip = C_TooltipInfo.GetHyperlink(link)
    local rank = tooltip and TooltipRank(tooltip)
    if not rank or rank < TOP_CURIO_RANK then return false end

    isTopCurioByLink[link] = true
    return true
end

local function RecolorBagItem(button, quality, itemIDOrLink)
    if not db.legendaryCurios or quality ~= Enum.ItemQuality.Epic or type(itemIDOrLink) ~= "string" then return end
    if IsTopCurio(itemIDOrLink) then
        SetItemButtonBorderVertexColor(button, LegendaryRGB())
    end
end

-- Baganator calls each button's own SetItemButtonQuality method, which the
-- global hook never sees.
local function HookBaganatorButton(details)
    local button = details.region
    if details.regionType == "ItemButton" and button.SetItemButtonQuality then
        hooksecurefunc(button, "SetItemButtonQuality", RecolorBagItem)
    end
end

local function HookBaganator()
    for _, details in ipairs(Baganator.API.Skins.GetAllFrames()) do
        HookBaganatorButton(details)
    end
    Baganator.API.Skins.RegisterListener(HookBaganatorButton)
end

function LegendaryCurios:Init(database)
    db = database
    hooksecurefunc("SetItemButtonQuality", RecolorBagItem)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_DelvesCompanionConfiguration", HookCompanionUI)
    EventUtil.ContinueOnAddOnLoaded("Baganator", HookBaganator)
end
