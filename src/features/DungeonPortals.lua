-- Lucky's Grab-bag: teleport button on the world map's dungeon entrances
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.DungeonPortals = {}

local BUTTON_SIZE = 20
local TOGGLE_SIZE = 24
local TOGGLE_ICON = "Interface/Icons/Spell_Arcane_PortalDalaran"
local ICON_INSET = 1
local FALLBACK_ICON = 134400

local db
local spellsByDungeonName

local DevLog = LuckyGrabbag.Logger("DungeonPortals")

local function Normalize(name)
    if not name then return nil end
    local lowered = name:lower():gsub("%s+", " ")
    return strtrim(lowered)
end

-- The dungeon name is read back from the client in the player's own language,
-- so nothing here has to know how a dungeon is spelled.
local function EnsureNameIndex()
    if spellsByDungeonName then return end

    local index, found = {}, 0
    for challengeModeID, spells in pairs(LuckyGrabbag.DUNGEON_PORTAL_SPELLS) do
        local name = C_ChallengeMode.GetMapUIInfo(challengeModeID)
        if name then
            index[Normalize(name)] = spells
            found = found + 1
        end
    end

    if found == 0 then return end -- challenge mode data not up yet, try again on the next refresh

    spellsByDungeonName = index
    DevLog("Indexed " .. found .. " dungeon teleports")
end

-- The journal names a mega-dungeon once where the challenge modes name each
-- wing, so "Return to Karazhan" has to reach "Return to Karazhan: Lower".
local function MatchByStartOfName(key)
    for name, spells in pairs(spellsByDungeonName) do
        if name:find(key, 1, true) == 1 then return spells end
    end
end

local function SpellsForDungeon(dungeonName)
    local key = Normalize(dungeonName)
    if not key or key == "" then return nil end -- an empty key starts every name

    -- Matching on the first word or two as well would pick up the last
    -- mega-dungeon whose two names share nothing but a word, Tazavesh, at the
    -- price of reading "Operation: Mechagon" as "Operation: Floodgate". A
    -- missing button costs the player a click; a wrong one costs them the
    -- teleport and its cooldown, so an unrecognised dungeon simply gets none.
    return spellsByDungeonName[key] or MatchByStartOfName(key)
end

local function KnownSpell(spells)
    if type(spells) == "number" then
        return C_SpellBook.IsSpellInSpellBook(spells) and spells or nil
    end
    for _, spellID in ipairs(spells) do
        if C_SpellBook.IsSpellInSpellBook(spellID) then return spellID end
    end
end

--- The teleport the player knows for an instance. Raids resolve straight off
--- the journal ID; dungeons through the name, the way the client spells it.
---@param journalInstanceID number|nil
---@param instanceName string|nil
---@return number|nil spellID
function LuckyGrabbag.DungeonPortals.TeleportFor(journalInstanceID, instanceName)
    local raidSpells = journalInstanceID and LuckyGrabbag.RAID_PORTAL_SPELLS[journalInstanceID]
    if raidSpells then return KnownSpell(raidSpells) end

    EnsureNameIndex()
    if not spellsByDungeonName then return nil end

    local spells = SpellsForDungeon(instanceName)
    return spells and KnownSpell(spells)
end

local function TeleportForPin(pin)
    local journalInstanceID = pin.journalInstanceID
    if not journalInstanceID then return nil end

    return LuckyGrabbag.DungeonPortals.TeleportFor(journalInstanceID, EJ_GetInstanceInfo(journalInstanceID))
end

-- A round gold-ringed button in the map's own language: the icon fills the
-- circle out to a thin gold ring, over a dark backing for the masked edge.
local function CreateBadge(opts)
    local btn = LuckyGrabbag.CreateIconButton({
        parent   = opts.parent,
        template = opts.template,
        size     = opts.size,
        tooltip  = opts.tooltip,
    })
    -- Clicks land out to the gold ring and a hair beyond, not just the icon.
    btn:SetHitRectInsets(-2, -2, -2, -2)

    -- Texture:SetMask no longer does anything in the live client, so each
    -- texture is rounded with its own MaskTexture instead.
    local function Rounded(texture)
        local mask = btn:CreateMaskTexture()
        mask:SetAllPoints(texture)
        mask:SetTexture("Interface/CharacterFrame/TempPortraitAlphaMask",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        texture:AddMaskTexture(mask)
    end

    local ring = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
    ring:SetAllPoints()
    ring:SetColorTexture(0.85, 0.65, 0.25, 1)
    Rounded(ring)
    btn.ring = ring

    local rim = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    rim:SetPoint("TOPLEFT", 1, -1)
    rim:SetPoint("BOTTOMRIGHT", -1, 1)
    rim:SetColorTexture(0.08, 0.07, 0.05, 1)
    Rounded(rim)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", ICON_INSET, -ICON_INSET)
    icon:SetPoint("BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
    -- Crop the icon's baked-in border so the circle edge stays clean.
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Rounded(icon)
    btn.icon = icon

    -- Same round hover glow as the minimap button; plain it draws its black
    -- backing as an opaque square, so force ADD.
    btn:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")
    btn:GetHighlightTexture():SetBlendMode("ADD") ---@diagnostic disable-line: undefined-field

    return btn
end

local function PortalButton(pin)
    if pin.luckyPortal then return pin.luckyPortal end

    -- InsecureActionButtonTemplate casts without the combat lockdown a secure
    -- button brings, which is free here: no teleport is castable in combat.
    local btn = CreateBadge({
        parent   = pin,
        template = "InsecureActionButtonTemplate",
        size     = BUTTON_SIZE,
        tooltip  = function(self) GameTooltip:SetSpellByID(self.spellID) end,
    })
    btn:SetPoint("CENTER", pin, "TOPRIGHT", -4, -4)
    btn:SetFrameLevel(pin:GetFrameLevel() + 3)
    btn:SetAttribute("type", "spell")
    btn:RegisterForClicks("AnyUp", "AnyDown")

    pin.luckyPortal = btn
    return btn
end

-- Pins are pooled and handed to whichever dungeon needs one next, so every
-- refresh re-reads the pin rather than trusting the button already on it.
local function UpdatePin(pin)
    local spellID = db.dungeonPortals and TeleportForPin(pin)
    if not spellID then
        if pin.luckyPortal then pin.luckyPortal:Hide() end
        return
    end

    local btn = PortalButton(pin)
    local info = C_Spell.GetSpellInfo(spellID)
    btn.spellID = spellID
    btn:SetAttribute("spell", spellID)
    btn.icon:SetTexture(info and info.iconID or FALLBACK_ICON)
    btn:Show()
end

local mapToggle

local function UpdateMapToggle()
    if not mapToggle then return end
    local on = db.dungeonPortals
    mapToggle.icon:SetDesaturated(not on)
    mapToggle.ring:SetColorTexture(on and 0.85 or 0.4, on and 0.65 or 0.4, on and 0.25 or 0.4, 1)
end

local function Refresh()
    UpdateMapToggle()
    for pin in WorldMapFrame:EnumeratePinsByTemplate("DungeonEntrancePinTemplate") do
        UpdatePin(pin)
    end
end

-- The same badge, sat in the map's top-right corner as the on/off switch.
local function CreateMapToggle()
    local S = LuckyGrabbag.Strings.dungeonPortals

    local btn = CreateBadge({
        parent  = WorldMapFrame.ScrollContainer,
        size    = TOGGLE_SIZE,
        tooltip = function()
            GameTooltip:AddLine(S.toggleTitle)
            GameTooltip:AddLine(S.toggleDesc, 0.91, 0.86, 0.78, true)
            GameTooltip:AddLine(db.dungeonPortals and S.stateOn or S.stateOff)
        end,
    })
    -- Below Blizzard's own Map Pin button, found the way Krowi's map button
    -- library finds it: overlay frames carry no names, only their mixin.
    local pinButton
    for _, f in ipairs(WorldMapFrame.overlayFrames or {}) do
        if WorldMapTrackingPinButtonMixin and f.OnLoad == WorldMapTrackingPinButtonMixin.OnLoad then
            pinButton = f
            break
        end
    end
    if pinButton then
        btn:SetPoint("TOP", pinButton, "BOTTOM", 0, -4)
    else
        btn:SetPoint("TOPRIGHT", WorldMapFrame.ScrollContainer, "TOPRIGHT", -8, -8)
    end
    btn:SetFrameStrata("HIGH")
    btn.icon:SetTexture(TOGGLE_ICON)
    btn:SetScript("OnClick", function(self)
        db.dungeonPortals = not db.dungeonPortals
        Refresh()
        -- Redo the tooltip so the Shown/Hidden line follows the click.
        self:GetScript("OnEnter")(self)
    end)

    return btn
end

function LuckyGrabbag.DungeonPortals:ApplySetting()
    if WorldMapFrame:IsShown() then Refresh() end
end

function LuckyGrabbag.DungeonPortals:Init(database)
    db = database

    mapToggle = CreateMapToggle()
    UpdateMapToggle()

    WorldMapFrame:HookScript("OnShow", Refresh)
    hooksecurefunc(WorldMapFrame, "RefreshAllDataProviders", function()
        -- Pins are acquired during the refresh, so let it finish first.
        C_Timer.After(0, Refresh)
    end)

    DevLog("Initialized")
end
