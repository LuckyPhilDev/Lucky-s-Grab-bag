-- Lucky's Grab-bag: Trovehunter's Bounty button in delves
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.DelveMap = {}

-- One map item per season; the bag scan accepts any of them.
local BOUNTY_MAP_ITEM_IDS = {
    [252415] = true, -- Trovehunter's Bounty Map (Midnight Season 1)
    [274374] = true, -- Trovehunter's Bounty (Midnight Season 2)
}
local DELVE_DIFFICULTY_ID = 208
local BUTTON_SIZE = 42

-- Widget IDs used by the scenario header to display the current delve tier.
-- C_GossipInfo.GetActiveDelveGossip and C_DelvesUI.GetCurrentDelveTier do not exist in 12.0.5+.
local DELVE_WIDGET_IDS = { 6183, 6184, 6185 }

local db
local button
local foundMapID = 274374 -- the map last seen in bags, for the tooltip

local DevLog = LuckyGrabbag.Logger("DelveMap")

-- Returns true + tier number if the player is in a delve, false otherwise.
-- Tier is read from the scenario header widget (the same source Blizzard uses on screen).
-- Returns 0 if the widget data is not yet available.
local function GetDelveInfo()
    local _, _, difficultyID = GetInstanceInfo()
    if difficultyID ~= DELVE_DIFFICULTY_ID then
        return false, 0
    end

    if C_UIWidgetManager and C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo then
        for _, widgetID in ipairs(DELVE_WIDGET_IDS) do
            local info = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(widgetID)
            if info and info.shownState ~= 0 then
                local t = info.tierText
                if type(t) == "number" then t = tostring(t) end
                if type(t) == "string" then
                    t = t:gsub("^%s+", ""):gsub("%s+$", "")
                    local tier = tonumber(t)
                    if tier then
                        DevLog("Tier from widget " .. widgetID .. ": " .. tier)
                        return true, tier
                    end
                end
            end
        end
    end

    DevLog("In delve but tier unknown (widget not ready)")
    return true, 0
end

-- Scans bags for a Trovehunter's Bounty map from any season.
local function HasBountyMap()
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and BOUNTY_MAP_ITEM_IDS[info.itemID] then
                foundMapID = info.itemID
                return true, info.itemName, info.iconFileID
            end
        end
    end
    return false
end

local function CreateButton()
    local btn = LuckyGrabbag.CreateIconButton({
        parent   = UIParent,
        name     = "LGB_DelveMapButton",
        template = "SecureActionButtonTemplate",
        size     = BUTTON_SIZE,
        tooltip  = function()
            GameTooltip:SetItemByID(foundMapID)
        end,
    })
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:SetAttribute("type", "item")
    btn:SetFrameStrata("HIGH")
    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:RegisterForDrag("RightButton")
    btn:SetScript("OnDragStart", btn.StartMoving)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        db.delveMapPos = { point = point, relPoint = relPoint, x = x, y = y }
        DevLog("Saved position")
    end)
    btn:Hide()
    return btn
end

local function RestorePosition()
    local pos = db.delveMapPos
    if pos then
        button:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        button:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
end

local function Refresh()
    -- Show and Hide are protected on a secure button; PLAYER_REGEN_ENABLED re-runs this.
    if InCombatLockdown() then return end

    if not db.showDelveMap then
        if button then button:Hide() end
        return
    end

    local inDelve, tier = GetDelveInfo()
    local minLevel = db.delveMapMinLevel or 8
    local meetsLevel = (tier == 0) or (tier >= minLevel)
    local hasMap, itemName, iconFileID = HasBountyMap()

    DevLog("Refresh: inDelve=" .. tostring(inDelve) .. " tier=" .. tier
        .. " minLevel=" .. minLevel .. " meetsLevel=" .. tostring(meetsLevel)
        .. " hasMap=" .. tostring(hasMap))

    if inDelve and meetsLevel and hasMap then
        button:SetAttribute("item", itemName)
        if iconFileID then
            button:SetNormalTexture(iconFileID)
        end
        button:Show()
    else
        button:Hide()
    end
end

function LuckyGrabbag.DelveMap:ApplySetting()
    if button then
        Refresh()
    end
end

function LuckyGrabbag.DelveMap:Init(database)
    db = database

    button = CreateButton()
    RestorePosition()

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("ACTIVE_DELVE_DATA_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            -- GetInstanceInfo() is often not ready yet when these fire during
            -- a loading screen. Refresh immediately (may catch it), then retry
            -- after a short delay to cover the late-availability case.
            Refresh()
            C_Timer.After(1, Refresh)
        else
            Refresh()
        end
    end)

    DevLog("Initialized")
end
