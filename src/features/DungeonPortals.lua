-- Lucky's Grab-bag: teleport button on the world map's dungeon entrances
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.DungeonPortals = {}

local BUTTON_SIZE = 20
local TOGGLE_SIZE = 32
local BADGE_ICON = "portal"

-- The four diagonals give the glyph a one pixel dark edge, which is what keeps
-- it legible over painted map art without a second piece of art to bake.
local OUTLINE_OFFSETS = { { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }

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

-- The same flat portal glyph on every teleport, whatever it casts: the pin
-- underneath already says where it goes, so spell art only adds noise.
local lastBadgeClick = 0
local function NoteBadgeClick() lastBadgeClick = GetTime() end

local function CreateBadge(opts)
    local btn = LuckyGrabbag.CreateIconButton({
        parent   = opts.parent,
        template = opts.template,
        size     = opts.size,
        tooltip  = opts.tooltip,
    })
    btn:SetHitRectInsets(-2, -2, -2, -2)

    local icon = LuckyIcon(BADGE_ICON)
    if opts.outline then
        for _, offset in ipairs(OUTLINE_OFFSETS) do
            local edge = btn:CreateTexture(nil, "BACKGROUND")
            edge:SetTexture(icon)
            edge:SetVertexColor(0, 0, 0, 0.85)
            edge:SetPoint("TOPLEFT", offset[1], offset[2])
            edge:SetPoint("BOTTOMRIGHT", offset[1], offset[2])
        end
    end

    btn:SetNormalTexture(icon)
    local gold = LuckyUI.C.goldIcon
    btn:GetNormalTexture():SetVertexColor(gold[1], gold[2], gold[3])
    -- The square highlight the helper sets would frame a round glyph, so the
    -- glyph lights itself up instead.
    btn:SetHighlightTexture(icon, "ADD")
    btn:GetHighlightTexture():SetAlpha(0.35) ---@diagnostic disable-line: undefined-field

    if opts.template then btn:SetScript("PostClick", NoteBadgeClick) end
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
        outline  = true,
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
    local spellID = db.dungeonPortals and db.dungeonPortalsDungeons and TeleportForPin(pin)
    if not spellID then
        if pin.luckyPortal then pin.luckyPortal:Hide() end
        return
    end

    local btn = PortalButton(pin)
    btn.spellID = spellID
    btn:SetAttribute("spell", spellID)
    btn:Show()
end

local TRAVEL_TOY = LuckyGrabbag.ABUNDANCE_TRAVEL_TOY_ID
-- The active Abundance event's POI pin gets Dundun's Abundant Travel Method,
-- a toy rather than a spell, so the badge casts through /use.
local function EventButton(pin)
    if pin.luckyAbundance then return pin.luckyAbundance end

    local btn = CreateBadge({
        parent   = pin,
        template = "InsecureActionButtonTemplate",
        size     = BUTTON_SIZE,
        outline  = true,
        tooltip  = function()
            if PlayerHasToy(TRAVEL_TOY) then
                GameTooltip:SetToyByItemID(TRAVEL_TOY)
            else
                GameTooltip:SetItemByID(TRAVEL_TOY)
            end
        end,
    })
    -- The event pin's art runs well past a dungeon pin's, so sit further out.
    btn:SetPoint("CENTER", pin, "TOPRIGHT", 2, 2)
    btn:SetFrameLevel(pin:GetFrameLevel() + 3)
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", "/use item:" .. TRAVEL_TOY)
    btn:RegisterForClicks("AnyUp", "AnyDown")

    pin.luckyAbundance = btn
    return btn
end

local QUELTHALAS_CONTINENT = 2537

local function EventPoiID(pin)
    return pin.areaPoiID or (pin.poiInfo and pin.poiInfo.areaPoiID)
end

-- Zone maps give the same event a different POI ID than the continent map, so
-- IDs alone cannot carry the match. The continent IDs are stable though, so
-- the active site's atlas is read from there once and zone pins match on it.
local abundanceAtlas
local function AbundanceAtlas()
    if abundanceAtlas then return abundanceAtlas end
    for poiID in pairs(LuckyGrabbag.ABUNDANCE_POI_IDS) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(QUELTHALAS_CONTINENT, poiID)
        if info and info.atlasName then
            abundanceAtlas = info.atlasName
            DevLog("Abundance atlas: " .. abundanceAtlas)
            break
        end
    end
    return abundanceAtlas
end

local function IsAbundancePoi(pin, poiID)
    if LuckyGrabbag.ABUNDANCE_POI_IDS[poiID] then return true end
    local atlas = pin.poiInfo and pin.poiInfo.atlasName
    return atlas ~= nil and atlas == AbundanceAtlas()
end

local function UpdateEventPin(pin)
    local poiID = EventPoiID(pin)
    local show = db.dungeonPortals and db.dungeonPortalsToys
        and poiID and IsAbundancePoi(pin, poiID)
        and (PlayerHasToy(TRAVEL_TOY) or C_Item.GetItemCount(TRAVEL_TOY) > 0)
    if not show then
        if pin.luckyAbundance then pin.luckyAbundance:Hide() end
        return false
    end

    EventButton(pin):Show()
    return true
end

local CLASS_BADGE_SIZE = 24

local classTeleports -- this class's LuckyGrabbag.CLASS_TELEPORTS list, nil for classes without one
local classPins = {}

-- Where the teleport lands on the open map, or nothing when it lands off it.
-- Projecting through world coordinates lets one landing point serve the city
-- map, its zone, the continent and the Azeroth map alike.
local function ClassMapPosition(entry, mapID)
    local instance, world = C_Map.GetWorldPosFromMapPos(entry.map, CreateVector2D(entry.x, entry.y))
    if not instance then return end
    local pos = select(2, C_Map.GetMapPosFromWorldPos(instance, world, mapID))
    if not pos then return end
    local x, y = pos:GetXY()
    if x <= 0 or x >= 1 or y <= 0 or y >= 1 then return end
    return x, y
end

-- The holder rides the canvas so its spot follows pan and zoom; the badge on
-- it is counter-scaled to stay the same size on screen.
local function ClassPin(entry)
    local holder = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer.Child)
    holder:SetSize(1, 1)

    local btn = CreateBadge({
        parent   = holder,
        template = "InsecureActionButtonTemplate",
        size     = CLASS_BADGE_SIZE,
        outline  = true,
        tooltip  = function(self)
            GameTooltip:SetSpellByID(self.spellID)
            if self.portalID then
                GameTooltip:AddLine(LuckyGrabbag.Strings.dungeonPortals.portalHint, 0.91, 0.86, 0.78)
            end
        end,
    })
    btn:SetPoint("CENTER", holder, "CENTER")
    btn:SetFrameStrata("HIGH")
    btn:SetAttribute("type", "spell")
    btn:RegisterForClicks("AnyUp", "AnyDown")

    local pin = { holder = holder, btn = btn }
    classPins[entry] = pin
    return pin
end

local function ApplyClassScale()
    local scale = WorldMapFrame:GetCanvasScale()
    if not scale or scale <= 0 then return end
    for _, pin in pairs(classPins) do
        pin.btn:SetScale(1 / scale)
    end
end

local function UpdateClassPins()
    if not classTeleports then return end
    local mapID = WorldMapFrame:GetMapID()
    local show = db.dungeonPortals and db.dungeonPortalsClass and mapID
    for _, entry in ipairs(classTeleports) do
        local spellID, x, y
        if show then
            spellID = KnownSpell(entry.teleport)
            if spellID then x, y = ClassMapPosition(entry, mapID) end
        end

        local pin = classPins[entry]
        if x then
            pin = pin or ClassPin(entry)
            local canvas = WorldMapFrame.ScrollContainer.Child
            pin.holder:SetPoint("CENTER", canvas, "TOPLEFT", x * canvas:GetWidth(), -y * canvas:GetHeight())
            pin.btn.spellID = spellID
            pin.btn.portalID = entry.portal and KnownSpell(entry.portal)
            pin.btn:SetAttribute("spell1", spellID)
            pin.btn:SetAttribute("spell2", pin.btn.portalID)
            pin.holder:Show()
        elseif pin then
            pin.holder:Hide()
        end
    end
    ApplyClassScale()
end

local mapToggle

local CATEGORY_KEYS = { "dungeonPortalsDungeons", "dungeonPortalsClass", "dungeonPortalsToys" }

local function AnyCategoryShown()
    for _, key in ipairs(CATEGORY_KEYS) do
        if db[key] then return true end
    end
    return false
end

-- Every category unticked is the feature off, however the master is set.
local function IsEnabled()
    return db.dungeonPortals and AnyCategoryShown()
end

local function UpdateMapToggle()
    if not mapToggle then return end
    -- The glyph's art is white and takes its colour from the vertex tint, so
    -- desaturating the texture would change nothing; the tint has to go grey.
    local gold = LuckyUI.C.goldIcon
    local on = IsEnabled()
    mapToggle:GetNormalTexture():SetVertexColor(
        on and gold[1] or 0.45, on and gold[2] or 0.45, on and gold[3] or 0.45)
end

local function Refresh()
    UpdateMapToggle()
    for pin in WorldMapFrame:EnumeratePinsByTemplate("DungeonEntrancePinTemplate") do
        UpdatePin(pin)
    end

    -- Event POIs have moved between pin templates across patches, so match on
    -- the POI ID over every pin instead of trusting a template name.
    WorldMapFrame:ExecuteOnAllPins(function(pin)
        if EventPoiID(pin) then
            UpdateEventPin(pin)
        end
    end)

    UpdateClassPins()
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
            GameTooltip:AddLine(S.toggleRightClick, 0.54, 0.49, 0.42)
            GameTooltip:AddLine(IsEnabled() and S.stateOn or S.stateOff)
        end,
    })
    -- The round backing and ring Blizzard's own map buttons wear, at the sizes
    -- its Map Pin button uses, so the two read as a pair.
    local backing = btn:CreateTexture(nil, "BACKGROUND")
    backing:SetTexture("Interface/Minimap/UI-Minimap-Background")
    backing:SetSize(25, 25)
    backing:SetPoint("TOPLEFT", 3, -4)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    for _, tex in ipairs({ btn:GetNormalTexture(), btn:GetHighlightTexture() }) do
        tex:ClearAllPoints()
        tex:SetSize(20, 20)
        tex:SetPoint("TOPLEFT", 7, -6)
    end

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
        -- Both buttons carry the same padding inside their frame, so edge to
        -- edge here is the gap Blizzard leaves between the circles themselves.
        btn:SetPoint("TOP", pinButton, "BOTTOM", 0, 0)
    else
        btn:SetPoint("TOPRIGHT", WorldMapFrame.ScrollContainer, "TOPRIGHT", -8, -8)
    end
    btn:SetFrameStrata("HIGH")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, mouseBtn)
        if mouseBtn == "RightButton" then
            LuckyGrabbag.DungeonPortals:OpenCategoryMenu(self)
            return
        end
        if IsEnabled() then
            db.dungeonPortals = false
        else
            -- Switching on with nothing ticked brings every category back;
            -- a master switch that lights up an empty feature helps nobody.
            db.dungeonPortals = true
            if not AnyCategoryShown() then
                for _, key in ipairs(CATEGORY_KEYS) do db[key] = true end
            end
        end
        Refresh()
        -- Redo the tooltip so the Shown/Hidden line follows the click.
        self:GetScript("OnEnter")(self)
    end)

    return btn
end

--- The category toggles as a context menu, for the map button's right-click.
function LuckyGrabbag.DungeonPortals:OpenCategoryMenu(owner)
    local SS = LuckyGrabbag.Strings.settings
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(LuckyGrabbag.Strings.dungeonPortals.toggleTitle)
        for _, key in ipairs(CATEGORY_KEYS) do
            root:CreateCheckbox(SS[key].label,
                function() return db[key] end,
                function()
                    db[key] = not db[key]
                    self:ApplySetting()
                end)
        end
    end)
end

function LuckyGrabbag.DungeonPortals:ApplySetting()
    if WorldMapFrame:IsShown() then Refresh() end
end

function LuckyGrabbag.DungeonPortals:Init(database)
    db = database
    classTeleports = LuckyGrabbag.CLASS_TELEPORTS[select(2, UnitClass("player"))]

    mapToggle = CreateMapToggle()
    UpdateMapToggle()

    -- A teleport is a long cast, invisible behind the map. Closing the map
    -- when the cast starts puts the cast bar in view, which is the feedback
    -- a click needs; a cast that fails leaves the map where it was.
    local caster = CreateFrame("Frame")
    caster:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    caster:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    caster:SetScript("OnEvent", function()
        if GetTime() - lastBadgeClick < 0.5 and WorldMapFrame:IsShown() then
            HideUIPanel(WorldMapFrame)
        end
    end)

    if classTeleports then
        hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", ApplyClassScale)
    end

    WorldMapFrame:HookScript("OnShow", Refresh)
    -- Navigating between maps re-acquires pins without a full provider
    -- refresh, so the map change needs its own hook.
    hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
        C_Timer.After(0, Refresh)
    end)
    hooksecurefunc(WorldMapFrame, "RefreshAllDataProviders", function()
        -- Pins are acquired during the refresh, so let it finish first.
        C_Timer.After(0, Refresh)
    end)

    DevLog("Initialized")
end
