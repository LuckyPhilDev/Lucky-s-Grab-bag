LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.DundunFinder = {}

local DELVE_DIFFICULTY_ID = 208
local BOUNTIFUL_ATLAS = "delves-bountiful"
-- Delver's Journey rank that unlocks the Shrine of Abundance (Midnight Season 2).
local UNLOCK_RENOWN = 3
local ICON = 647701 -- inv_pet_mouse
local BUTTON_SIZE = 42
-- Square crop of the icon's texture around the mouse's eyes.
local EYES_CROP = { left = 0.24, right = 0.80, top = 0.13, bottom = 0.69 }
local ZOOM_IN, ZOOM_HOLD, ZOOM_OUT = 0.12, 0.6, 0.3

local MACRO = [[
/cleartarget
/tar Dundun
/stopmacro [noexists]
/ping [@target]
/tm 1]]

local db
local button
local zoomElapsed

local DevLog = LuckyGrabbag.Logger("DundunFinder")

-- Nothing inside a delve says it is bountiful, so the zone map's entrance pin is checked instead.
local function InBountifulDelve()
    local instanceName, _, difficultyID = GetInstanceInfo()
    if difficultyID ~= DELVE_DIFFICULTY_ID then return false end

    local mapInfo = C_Map.GetMapInfo(C_Map.GetBestMapForUnit("player") or 0)
    while mapInfo and mapInfo.parentMapID and mapInfo.parentMapID ~= 0 do
        local zoneMapID = mapInfo.parentMapID
        for _, poiID in ipairs(C_AreaPoiInfo.GetDelvesForMap(zoneMapID) or {}) do
            local poi = C_AreaPoiInfo.GetAreaPOIInfo(zoneMapID, poiID)
            if poi and poi.name == instanceName then
                return poi.atlasName == BOUNTIFUL_ATLAS
            end
        end
        mapInfo = C_Map.GetMapInfo(zoneMapID)
    end
    DevLog("No entrance pin found for " .. tostring(instanceName))
    return false
end

local function HasUnlocked()
    local factionID = C_DelvesUI.GetDelvesFactionForSeason()
    return factionID and (C_MajorFactions.GetCurrentRenownLevel(factionID) or 0) >= UNLOCK_RENOWN
end

local function SetZoom(texture, amount)
    texture:SetTexCoord(
        EYES_CROP.left * amount, 1 - (1 - EYES_CROP.right) * amount,
        EYES_CROP.top * amount, 1 - (1 - EYES_CROP.bottom) * amount)
end

local function ZoomAmount(elapsed)
    if elapsed < ZOOM_IN then return elapsed / ZOOM_IN end
    elapsed = elapsed - ZOOM_IN - ZOOM_HOLD
    if elapsed < 0 then return 1 end
    return math.max(0, 1 - elapsed / ZOOM_OUT)
end

-- A plain driver frame, so no script is ever set on the secure button.
local zoomDriver = CreateFrame("Frame")
zoomDriver:Hide()
zoomDriver:SetScript("OnUpdate", function(self, delta)
    zoomElapsed = zoomElapsed + delta
    local amount = ZoomAmount(zoomElapsed)
    SetZoom(button:GetNormalTexture(), amount)
    if amount == 0 then self:Hide() end
end)

-- The macro clears the target first, so any target afterwards is Dundun.
local function OnPostClick()
    if not UnitExists("target") then return end
    zoomElapsed = 0
    zoomDriver:Show()
end

local function CreateButton()
    local S = LuckyGrabbag.Strings.dundunFinder
    local btn = LuckyGrabbag.CreateIconButton({
        parent   = UIParent,
        name     = "LGB_DundunFinderButton",
        template = "SecureActionButtonTemplate",
        size     = BUTTON_SIZE,
        texture  = ICON,
        tooltip  = function()
            GameTooltip:SetText(S.tooltipTitle)
            GameTooltip:AddLine(S.tooltipBody, 1, 1, 1, true)
        end,
    })
    btn:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", MACRO)
    btn:HookScript("PostClick", OnPostClick)
    btn:SetFrameStrata("HIGH")
    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:RegisterForDrag("RightButton")
    btn:SetScript("OnDragStart", btn.StartMoving)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        db.dundunFinderPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    local pos = db.dundunFinderPos
    if pos then
        btn:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        btn:SetPoint("CENTER", UIParent, "CENTER", BUTTON_SIZE + 8, 200)
    end
    btn:Hide()
    return btn
end

local function Refresh()
    -- Show and Hide are protected on a secure button; PLAYER_REGEN_ENABLED re-runs this.
    if InCombatLockdown() then return end
    local show = db.showDundunFinder and HasUnlocked() and InBountifulDelve()
    DevLog("Refresh: show=" .. tostring(show))
    button:SetShown(show)
end

function LuckyGrabbag.DundunFinder:ApplySetting()
    if button then Refresh() end
end

function LuckyGrabbag.DundunFinder:Init(database)
    db = database
    button = CreateButton()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED")
    eventFrame:SetScript("OnEvent", function(_, event)
        Refresh()
        -- GetInstanceInfo() often lags the loading screen.
        if event ~= "PLAYER_REGEN_ENABLED" then C_Timer.After(1, Refresh) end
    end)
end
