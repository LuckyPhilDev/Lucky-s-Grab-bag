-- Lucky's Grab-bag: Rank 5 curios sit a tier above Epic, but Blizzard maps that
-- rarity (EpicTier2) back to Epic. Colours them Legendary instead.
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.LegendaryCurios = {}

local LegendaryCurios = LuckyGrabbag.LegendaryCurios

local TOP_CURIO_RANK = 5
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
    if not db.legendaryCurios then return end
    if CurioRarity(button.data.configID, button.data.entryID) == Enum.CurioRarity.EpicTier2 then
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
        local rank = tooltip.lines[i].leftText and tonumber(tooltip.lines[i].leftText:match("(%d+)/%d+"))
        if rank then return rank end
    end
end

-- Only a match is cached: bags first draw before item data has loaded, and a
-- miss remembered then would stick until the next reload.
local function IsTopCurio(link)
    if isTopCurioByLink[link] then return true end
    if not C_Item.IsCurioItem(link) or C_Item.GetItemQualityByID(link) ~= Enum.ItemQuality.Epic then return false end

    local tooltip = C_TooltipInfo.GetHyperlink(link)
    local rank = tooltip and TooltipRank(tooltip)
    if not rank or rank < TOP_CURIO_RANK then return false end

    isTopCurioByLink[link] = true
    return true
end

local function ButtonItemLink(button)
    if button.GetBagID then
        return C_Container.GetContainerItemLink(button:GetBagID(), button:GetID())
    end
    return button.BGR and button.BGR.itemLink
end

local recoloring = false

-- Recolours the moment Blizzard colours, rather than after SetItemButtonQuality
-- returns: skins such as EllesmereUI copy the colour onto their own border from
-- a hook that runs before any of ours could.
local function RecolorQualityTexture(texture)
    if recoloring or not db.legendaryCurios then return end
    local link = ButtonItemLink(texture:GetParent())
    if not link or not IsTopCurio(link) then return end

    recoloring = true
    texture:SetVertexColor(LegendaryRGB())
    recoloring = false
end

local hookedTextures = {}

local function HookTexture(texture)
    if not texture or hookedTextures[texture] then return end
    hookedTextures[texture] = true
    hooksecurefunc(texture, "SetVertexColor", RecolorQualityTexture)
end

-- A curio's quality shows twice: the ring every item has, and the curio frame
-- Blizzard lays over it.
local function HookButton(button)
    HookTexture(button.IconBorder)
    HookTexture(button.IconOverlay)
end

-- Bag buttons come from a pool on every rebuild of the bag's slots, so each
-- one is hooked as it is handed out.
local function HookContainerFrame(frame)
    hooksecurefunc(frame, "AcquireNewItemButton", function(self)
        HookButton(self.Items[#self.Items])
    end)
end

-- Every frame, not Blizzard's enumerator: it lists only the combined or the
-- separate bags, whichever the setting picked at the time.
local function HookContainerFrames()
    HookContainerFrame(ContainerFrameCombinedBags)
    for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do
        HookContainerFrame(frame)
    end
end

local function HookBaganatorButton(details)
    if details.regionType == "ItemButton" then HookButton(details.region) end
end

local function HookBaganator()
    for _, details in ipairs(Baganator.API.Skins.GetAllFrames()) do
        HookBaganatorButton(details)
    end
    Baganator.API.Skins.RegisterListener(HookBaganatorButton)
end

function LegendaryCurios:Init(database)
    db = database
    HookContainerFrames()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_DelvesCompanionConfiguration", HookCompanionUI)
    EventUtil.ContinueOnAddOnLoaded("Baganator", HookBaganator)
end
